//
//  QueryTests.swift
//  SpotlightTests
//
//  Created by David Sherlock on 2026.
//
//  Building a question, and refusing the ones that cannot mean anything.
//
//  Most of this needs no index: a predicate is a value, and what it says can be read back.
//  That matters because the index is not a fixture — it holds whatever this machine happens
//  to contain — so anything asserting on real results would pass or fail by accident.
//

import XCTest
@testable import Spotlight

final class QueryTests: XCTestCase {

    private func format(_ query: Query) throws -> String {
        try query.predicate().predicateFormat
    }

    func testAnEmptyQueryIsRefused() {
        // It would match every file on the machine, which is never what anybody meant and is
        // a slow way to find that out.
        XCTAssertTrue(Query().isEmpty)
        XCTAssertThrowsError(try Query().predicate()) { error in
            XCTAssertEqual(error as? SpotlightError, .queryRefused("nothing to search for"))
        }
    }

    func testNameMatchesAsAGlob() throws {
        // LIKE, not MATCHES: Spotlight takes globs, and translating a regex would work for
        // the easy half of the syntax and fail silently on the rest.
        let text = try format(Query(name: "*.swift"))
        XCTAssertTrue(text.contains("LIKE"))
        XCTAssertTrue(text.contains("kMDItemFSName"))
        XCTAssertFalse(text.contains("MATCHES"))
    }

    func testContentSearchesInsideFiles() throws {
        let text = try format(Query(content: "blockQuoteLevel"))
        XCTAssertTrue(text.contains("kMDItemTextContent"))
        XCTAssertTrue(text.contains("CONTAINS"))
    }

    func testTypeMatchesTheTreeSoASubtypeCounts() throws {
        // kMDItemContentTypeTree, not kMDItemContentType — otherwise asking for `public.image`
        // finds nothing, because a PNG's type is `public.png`.
        let text = try format(Query(type: Kind.image.identifier))
        XCTAssertTrue(text.contains("kMDItemContentTypeTree"))
        XCTAssertFalse(text.contains("kMDItemContentType =="))
    }

    func testPartsCombineWithAnd() throws {
        let query = Query(name: "*.png", content: "invoice", type: "public.image",
                          changedAfter: Date(timeIntervalSince1970: 0), largerThan: 1024)
        let text = try format(query)
        for fragment in ["kMDItemFSName", "kMDItemTextContent", "kMDItemContentTypeTree",
                         "kMDItemFSContentChangeDate", "kMDItemFSSize"] {
            XCTAssertTrue(text.contains(fragment), "missing \(fragment)")
        }
        XCTAssertTrue(text.contains("AND"))
    }

    func testASingleConstraintIsNotWrappedInACompound() throws {
        XCTAssertFalse(try format(Query(name: "x")).contains("AND"))
    }

    func testARawPredicateHasToNameAnAttribute() {
        // A bare word is what somebody types when they meant --content. Passing it to
        // NSPredicate(format:) would trap, so it is refused with the reason instead.
        XCTAssertThrowsError(try Query(raw: "invoice").predicate())
        XCTAssertThrowsError(try Query(raw: "").predicate())
        XCTAssertNoThrow(try Query(raw: "kMDItemFSName == 'x'").predicate())
    }

    func testARawPredicateJoinsTheRest() throws {
        let text = try format(Query(name: "*.jpg", raw: "kMDItemPixelWidth > 1000"))
        XCTAssertTrue(text.contains("kMDItemPixelWidth"))
        XCTAssertTrue(text.contains("kMDItemFSName"))
    }

    func testSortOrdersByWhatItSays() {
        XCTAssertEqual(Query.Sort.newest.descriptors.first?.key, NSMetadataItemFSContentChangeDateKey)
        XCTAssertEqual(Query.Sort.newest.descriptors.first?.ascending, false)
        XCTAssertEqual(Query.Sort.oldest.descriptors.first?.ascending, true)
        XCTAssertEqual(Query.Sort.name.descriptors.first?.key, NSMetadataItemFSNameKey)
        XCTAssertEqual(Query.Sort.largest.descriptors.first?.key, NSMetadataItemFSSizeKey)
        XCTAssertTrue(Query.Sort.none.descriptors.isEmpty)
    }
}

final class KindTests: XCTestCase {

    func testTheNamedKindsMapToTreeTypes() {
        XCTAssertEqual(Kind.named("photo"), .image)
        XCTAssertEqual(Kind.named("movies"), .video)
        XCTAssertEqual(Kind.named("music"), .audio)
        XCTAssertEqual(Kind.named("slides"), .presentation)
        XCTAssertEqual(Kind.image.identifier, "public.image")
    }

    func testAnUnknownWordPassesStraightThrough() {
        // The escape hatch: hundreds of UTIs exist and wrapping them all would be a worse
        // copy of the type system Apple already ships.
        XCTAssertEqual(Kind.named("com.apple.notes.note"), .other("com.apple.notes.note"))
        XCTAssertEqual(Kind.named("com.apple.notes.note").identifier, "com.apple.notes.note")
    }

    func testEveryAdvertisedNameResolvesToSomethingOtherThanItself() {
        for name in Kind.names {
            XCTAssertNotEqual(Kind.named(name), .other(name), "\(name) is advertised but unmapped")
        }
    }
}

final class ScopeTests: XCTestCase {

    func testATildeIsExpanded() {
        XCTAssertEqual(Scope.path("~/Documents"), NSHomeDirectory() + "/Documents")
    }

    func testARelativePathIsResolvedAgainstTheWorkingDirectory() {
        let resolved = Scope.path("Sources")
        XCTAssertTrue(resolved.hasPrefix("/"))
        XCTAssertTrue(resolved.hasSuffix("/Sources"))
    }

    func testAnAbsolutePathIsTidiedAndKept() {
        XCTAssertEqual(Scope.path("/tmp/../tmp/x"), "/tmp/x")
        XCTAssertEqual(Scope.path("/usr/local"), "/usr/local")
    }
}

final class AttributeRenderingTests: XCTestCase {

    func testEachValueKindBecomesText() {
        // Spotlight returns strings, numbers, dates and arrays of them. Flattening here keeps
        // `attributes` a [String: String] so it encodes without a caller writing a type switch.
        XCTAssertEqual(Index.describe("text"), "text")
        XCTAssertEqual(Index.describe(NSNumber(value: 42)), "42")
        XCTAssertEqual(Index.describe(["a", "b"]), "a, b")
        XCTAssertEqual(Index.describe(Date(timeIntervalSince1970: 0)), "1970-01-01T00:00:00Z")
    }
}

final class MatchTests: XCTestCase {

    func testItDerivesItsDirectoryAndExtension() {
        let match = Match(path: "/Users/x/Pictures/Shot.PNG", name: "Shot.PNG")
        XCTAssertEqual(match.directory, "/Users/x/Pictures")
        XCTAssertEqual(match.fileExtension, "png")
        XCTAssertEqual(match.id, match.path)
    }

    func testAFileWithNoExtensionHasNone() {
        XCTAssertNil(Match(path: "/usr/bin/swift", name: "swift").fileExtension)
    }
}
