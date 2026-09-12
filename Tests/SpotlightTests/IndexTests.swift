//
//  IndexTests.swift
//  SpotlightTests
//
//  Created by David Sherlock on 2026.
//
//  The one part that has to touch the real index.
//
//  These search for THIS PACKAGE'S OWN FILES, which is the only ground truth available: the
//  index holds whatever the machine happens to contain, so anything asserting on a count or a
//  filename elsewhere would pass or fail by accident.
//
//  They SKIP rather than fail when the index cannot answer — a machine that is reindexing, or
//  a checkout somewhere Spotlight does not cover, is not a broken library. A test that fails
//  for a reason the code cannot cause teaches the reader to ignore it.
//

import XCTest
@testable import Spotlight

final class IndexTests: XCTestCase {

    /// This package's own directory.
    private var packageRoot: String {
        // #filePath is …/Tests/SpotlightTests/IndexTests.swift
        (((#filePath as NSString).deletingLastPathComponent as NSString)
            .deletingLastPathComponent as NSString).deletingLastPathComponent
    }

    /// Search, or skip if the index has nothing to say about this checkout.
    private func search(_ query: Query) throws -> [Match] {
        do { return try Index.search(query, timeout: 15) }
        catch SpotlightError.timedOut { throw XCTSkip("the index did not answer in time") }
    }

    func testFindsAFileItCanBeSureExists() throws {
        let found = try search(Query(name: "Package.swift", scopes: [packageRoot]))
        try XCTSkipIf(found.isEmpty, "this checkout is not indexed")
        XCTAssertEqual(found.first?.name, "Package.swift")
        XCTAssertGreaterThan(found.first?.size ?? 0, 0)
        XCTAssertTrue(found.first?.path.hasSuffix("/Package.swift") ?? false)
    }

    func testFindsTextInsideAFileRatherThanInItsName() throws {
        // The whole reason the library exists: no file here is CALLED this.
        let needle = "enableUpdates"
        let found = try search(Query(content: needle, scopes: [packageRoot]))
        try XCTSkipIf(found.isEmpty, "this checkout is not content-indexed")
        XCTAssertTrue(found.contains { $0.name == "Index.swift" })
        XCTAssertFalse(found.contains { $0.name.contains(needle) }, "matched a name, not content")
    }

    func testTheLimitIsHonoured() throws {
        let all = try search(Query(name: "*.swift", scopes: [packageRoot]))
        try XCTSkipIf(all.count < 3, "not enough indexed files to limit")
        XCTAssertEqual(try search(Query(name: "*.swift", scopes: [packageRoot], limit: 2)).count, 2)
    }

    func testSortingByNameIsActuallySorted() throws {
        let found = try search(Query(name: "*.swift", scopes: [packageRoot], sort: .name))
        try XCTSkipIf(found.count < 2, "not enough indexed files to sort")
        XCTAssertEqual(found.map(\.name), found.map(\.name).sorted())
    }

    func testExtraAttributesAreOffByDefault() throws {
        let plain = try search(Query(name: "Package.swift", scopes: [packageRoot], limit: 1))
        try XCTSkipIf(plain.isEmpty, "this checkout is not indexed")
        XCTAssertTrue(plain[0].attributes.isEmpty)

        let full = try search(Query(name: "Package.swift", scopes: [packageRoot],
                                    limit: 1, includeAllAttributes: true))
        XCTAssertGreaterThan(full[0].attributes.count, 10)
        XCTAssertNotNil(full[0].attributes["kMDItemFSName"])
    }

    func testAScopeThatIsNotADirectoryIsRefusedBeforeSearching() {
        XCTAssertThrowsError(try Index.search(Query(name: "x", scopes: ["/nope/nothing/here"]))) {
            XCTAssertEqual($0 as? SpotlightError, .badScope("/nope/nothing/here"))
        }
        // A file is not a scope either.
        XCTAssertThrowsError(try Index.search(Query(name: "x", scopes: [#filePath])))
    }

    func testSpotlightsOwnScopeConstantsAreNotCheckedAsPaths() throws {
        // They are not paths, so the directory check has to let them past. Searching for a
        // name nothing has keeps this fast and independent of what the machine holds.
        let found = try search(Query(name: "zz-no-such-file-zz-*", scopes: Scope.home, limit: 1))
        XCTAssertTrue(found.isEmpty)
    }

    func testAGroupContainerIsSearchableAndSimplyNeverMatches() throws {
        // Documented hole, and worth a test so it is noticed if Apple ever changes it:
        // ~/Library/Group Containers is outside the index, so a query there is valid and
        // always empty. `mdutil` reports "unknown indexing state" for that path.
        let container = Scope.path("~/Library/Group Containers")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: container), "no group containers")
        let found = try search(Query(name: "*.sqlite", scopes: [container]))
        XCTAssertTrue(found.isEmpty, "Spotlight has started indexing Group Containers — update the docs")
    }
}
