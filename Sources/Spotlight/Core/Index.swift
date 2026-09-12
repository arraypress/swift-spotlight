//
//  Index.swift
//  Spotlight
//
//  Created by David Sherlock on 2026.
//
//  Asking macOS's own file index a question.
//
//  NOTHING HERE BUILDS AN INDEX. Spotlight has been indexing this machine since it was set
//  up and keeps doing it whether anything asks or not, so the entire job is phrasing a
//  question and reading the answer. That is why a content search over a whole home directory
//  comes back in under a second where `grep -r` takes minutes: the work was already done.
//
//  THE RUN LOOP IS NOT OPTIONAL AND THAT IS THE AWKWARD PART. `NSMetadataQuery` reports
//  through notifications, so a caller that starts one and returns gets nothing. It works in a
//  plain command-line process with no GUI — verified before any of this was written — but
//  only if something pumps the run loop until the gathering notification arrives. That pump
//  is what ``search(_:)`` is: it is synchronous from the outside and a run loop on the inside.
//
//  DO NOT CALL `enableUpdates()` BEFORE STARTING. It reads like the right way to say "I want
//  a snapshot, not a live feed" — pair it with `disableUpdates()` and the results stop moving.
//  What it actually does is stop the gathering notification ever arriving, so every query
//  times out. Written that way once, on reasoning rather than measurement, and it cost a
//  thirty-second timeout on a search that takes a tenth of a second.
//
//  WHAT SPOTLIGHT CANNOT SEE, and it matters more than it sounds:
//
//  - **Group Containers are not indexed.** `~/Library/Group Containers` is outside the index
//    entirely — `mdutil` reports "unknown indexing state" for it. Measured: a file written
//    there is unfindable by name or content, while the same file in `~/Library/Application
//    Support` is found in seconds. That is where sandboxed apps keep their data, so Notes'
//    database, Mail's store and the rest are invisible to this. Nothing here can fix that;
//    walking the filesystem is the only way in.
//  - Anything the user added to Spotlight's privacy list.
//  - Content of files whose type has no importer — the NAME is still indexed, the inside
//    is not.
//

import Foundation

/// Questions for the file index.
public enum Index {

    /// How long to wait for an answer before giving up.
    public static let defaultTimeout: Double = 30

    /// Run a query and return what it found.
    ///
    /// Synchronous, and a run loop underneath. See the file note: `NSMetadataQuery` answers
    /// through notifications, so somebody has to pump.
    ///
    /// - Parameters:
    ///   - query: what to look for.
    ///   - timeout: seconds to wait. A big scope on a machine that is still indexing is the
    ///     case this exists for.
    /// - Returns: the matches, ordered as ``Query/sort`` asks.
    /// - Throws: ``SpotlightError``.
    public static func search(_ query: Query, timeout: Double = defaultTimeout) throws -> [Match] {
        for scope in query.scopes where !scope.hasPrefix("kMDQueryScope") {
            var directory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: scope, isDirectory: &directory),
                  directory.boolValue else {
                throw SpotlightError.badScope(scope)
            }
        }

        let predicate = try query.predicate()
        let metadata = NSMetadataQuery()
        metadata.predicate = predicate
        metadata.searchScopes = query.scopes
        metadata.sortDescriptors = query.sort.descriptors
        let collector = Collector()
        // The notification fires from the run loop this function is pumping, on this thread,
        // so there is no concurrency here — but the closure is typed `@Sendable` and
        // `NSMetadataQuery` is not, hence the explicit escape rather than a lock that would
        // guard nothing.
        nonisolated(unsafe) let box = metadata
        let token = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering, object: metadata, queue: nil
        ) { _ in
            box.stop()
            collector.finish(with: Index.harvest(box, query: query))
        }
        defer { NotificationCenter.default.removeObserver(token) }

        guard metadata.start() else {
            throw SpotlightError.queryRefused("the index would not start the query")
        }

        let deadline = Date().addingTimeInterval(timeout)
        while collector.result == nil, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        guard let result = collector.result else {
            metadata.stop()
            throw SpotlightError.timedOut(seconds: timeout)
        }
        return result
    }

    /// Turn a finished query's items into matches, stopping at the limit.
    static func harvest(_ metadata: NSMetadataQuery, query: Query) -> [Match] {
        let wanted = query.limit ?? Int.max
        var matches: [Match] = []
        matches.reserveCapacity(min(metadata.resultCount, wanted == .max ? 128 : wanted))

        for index in 0..<metadata.resultCount where matches.count < wanted {
            guard let item = metadata.result(at: index) as? NSMetadataItem else { continue }
            matches.append(match(from: item, extras: query.includeAllAttributes))
        }
        return matches
    }

    /// One item, narrowed to the fields every file has.
    static func match(from item: NSMetadataItem, extras: Bool) -> Match {
        func string(_ key: String) -> String? { item.value(forAttribute: key) as? String }

        var attributes: [String: String] = [:]
        if extras {
            for key in item.attributes {
                guard let value = item.value(forAttribute: key) else { continue }
                attributes[key] = Index.describe(value)
            }
        }
        let path = string(NSMetadataItemPathKey) ?? ""
        return Match(path: path,
                     name: string(NSMetadataItemFSNameKey) ?? (path as NSString).lastPathComponent,
                     size: (item.value(forAttribute: NSMetadataItemFSSizeKey) as? Int) ?? 0,
                     contentType: string(NSMetadataItemContentTypeKey),
                     kind: string(NSMetadataItemKindKey),
                     modified: item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date,
                     created: item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date,
                     attributes: attributes)
    }

    /// An attribute value as text.
    ///
    /// Spotlight hands back strings, numbers, dates and arrays of any of them. Rendering them
    /// here keeps ``Match/attributes`` a flat `[String: String]`, which encodes to JSON and
    /// to a table without a caller writing a type switch for a field they have never seen.
    static func describe(_ value: Any) -> String {
        switch value {
        case let text as String: return text
        case let date as Date: return ISO8601DateFormatter().string(from: date)
        case let number as NSNumber: return number.stringValue
        case let list as [Any]: return list.map(describe).joined(separator: ", ")
        default: return String(describing: value)
        }
    }
}

/// Somewhere for the notification to put its answer.
///
/// A class because the notification block has to write where the waiting loop can read, and
/// both run on the same thread — the block fires from the run loop this is pumping, so there
/// is no concurrency here to guard against.
private final class Collector: @unchecked Sendable {
    var result: [Match]?
    func finish(with matches: [Match]) { result = matches }
}
