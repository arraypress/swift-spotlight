//
//  Query.swift
//  Spotlight
//
//  Created by David Sherlock on 2026.
//
//  What to ask the index for.
//
//  BUILT FROM PARTS RATHER THAN TAKING A PREDICATE STRING, because the raw form is
//  `kMDItemContentTypeTree == "public.image"` and nobody should have to know that to find a
//  picture. Every part is optional and they combine with AND, so a caller adds only the
//  constraints they mean. ``raw`` is the escape hatch for a question this shape cannot ask.
//
//  NAME MATCHING IS A GLOB, not a regular expression — `*.swift`, `Screenshot*`. That is what
//  Spotlight's `LIKE` takes, and pretending otherwise by translating a regex would work for
//  the easy half of the syntax and fail silently on the rest.
//

import Foundation

/// A question for the index.
public struct Query: Equatable, Sendable {

    /// How to order the answer.
    public enum Sort: String, Equatable, Sendable, CaseIterable, Codable {
        /// Most recently changed first — what "what was I just working on" means.
        case newest
        case oldest
        case name
        case largest
        /// Whatever order the index returns, which is the fastest and is not stable.
        case none

        var descriptors: [NSSortDescriptor] {
            switch self {
            case .newest: return [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)]
            case .oldest: return [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: true)]
            case .name: return [NSSortDescriptor(key: NSMetadataItemFSNameKey, ascending: true)]
            case .largest: return [NSSortDescriptor(key: NSMetadataItemFSSizeKey, ascending: false)]
            case .none: return []
            }
        }
    }

    /// A filename glob: `*.swift`, `Screenshot*`, `notes.*`.
    public var name: String?

    /// Words to find INSIDE files.
    ///
    /// The reason this library exists. Spotlight has already read every file it can open, so
    /// this answers in under a second where `grep -r` walks the disk for minutes. It only
    /// sees file types with a content importer; for the rest the name is indexed and the
    /// inside is not.
    public var content: String?

    /// A uniform type to match, including subtypes — `public.image` catches PNG and JPEG both.
    public var type: String?

    /// Only files changed at or after this.
    public var changedAfter: Date?

    /// Only files changed at or before this.
    public var changedBefore: Date?

    /// Only files of at least this many bytes.
    public var largerThan: Int?

    /// A raw `kMDItem…` predicate, ANDed with everything above.
    ///
    /// For the questions this type has no field for — camera model, audio bit rate, the
    /// dozens of attributes only some files carry. Malformed input throws rather than
    /// returning nothing, because a silent empty result reads exactly like "no matches".
    public var raw: String?

    /// Where to look. Empty means everywhere indexed.
    ///
    /// A path, or one of Spotlight's own scope constants. Note that a path outside the index
    /// — a Group Container, say — is a valid directory and will simply never match.
    public var scopes: [String]

    /// At most this many matches.
    public var limit: Int?

    public var sort: Sort

    /// Collect every attribute Spotlight holds, not just the common ones.
    public var includeAllAttributes: Bool

    public init(name: String? = nil, content: String? = nil, type: String? = nil,
                changedAfter: Date? = nil, changedBefore: Date? = nil, largerThan: Int? = nil,
                raw: String? = nil, scopes: [String] = [], limit: Int? = nil,
                sort: Sort = .newest, includeAllAttributes: Bool = false) {
        self.name = name
        self.content = content
        self.type = type
        self.changedAfter = changedAfter
        self.changedBefore = changedBefore
        self.largerThan = largerThan
        self.raw = raw
        self.scopes = scopes
        self.limit = limit
        self.sort = sort
        self.includeAllAttributes = includeAllAttributes
    }

    /// Whether anything at all was asked for.
    ///
    /// An empty query matches every file on the machine, which is never what somebody meant
    /// and is a slow way to find that out.
    public var isEmpty: Bool {
        name == nil && content == nil && type == nil && changedAfter == nil
            && changedBefore == nil && largerThan == nil && raw == nil
    }

    /// The parts, combined with AND.
    ///
    /// - Throws: ``SpotlightError/queryRefused(_:)`` when nothing was asked, or when ``raw``
    ///   will not parse.
    public func predicate() throws -> NSPredicate {
        guard !isEmpty else {
            throw SpotlightError.queryRefused("nothing to search for")
        }
        var parts: [NSPredicate] = []

        if let name {
            parts.append(NSPredicate(format: "kMDItemFSName LIKE[cd] %@", name))
        }
        if let content {
            parts.append(NSPredicate(format: "kMDItemTextContent CONTAINS[cd] %@", content))
        }
        if let type {
            // The TREE, not the type: `public.image` then matches a PNG, which IS one.
            parts.append(NSPredicate(format: "kMDItemContentTypeTree == %@", type))
        }
        if let changedAfter {
            parts.append(NSPredicate(format: "kMDItemFSContentChangeDate >= %@", changedAfter as NSDate))
        }
        if let changedBefore {
            parts.append(NSPredicate(format: "kMDItemFSContentChangeDate <= %@", changedBefore as NSDate))
        }
        if let largerThan {
            parts.append(NSPredicate(format: "kMDItemFSSize >= %d", largerThan))
        }
        if let raw {
            // NSPredicate(format:) traps on malformed input rather than returning nil, so
            // this cannot be validated by trying it. What it CAN do is refuse the obvious
            // mistake — a bare word — which is what somebody types when they meant --content.
            guard raw.contains("kMDItem") else {
                throw SpotlightError.queryRefused(
                    "a raw predicate has to name an attribute, as in kMDItemFSName == \"x\"")
            }
            parts.append(NSPredicate(format: raw))
        }
        return parts.count == 1 ? parts[0] : NSCompoundPredicate(andPredicateWithSubpredicates: parts)
    }
}
