import XCTest
import Foundation
import GRDB
@testable import PlayaDB

/// Live search feeds `matching(searchText:)` a partial query on every keystroke, so the
/// FTS5 pattern must match *prefixes* — whole-token matching is all-or-nothing ("tem"
/// finds nothing, then "temple" finds everything at once). These tests pin the prefix
/// behaviour, the `prefix=` index option on the FTS tables, and the migration that
/// installs that option on databases created by the old schema (including seed restores).
final class FTSPrefixSearchTests: XCTestCase {
    private var playaDB: PlayaDBImpl!
    private var tempDBPath: String!

    private var dbQueue: any DatabaseWriter { playaDB.dbQueue }

    override func setUp() async throws {
        try await super.setUp()
        tempDBPath = NSTemporaryDirectory() + "FTSPrefixSearchTests-\(UUID().uuidString).sqlite"
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)
        try await seedObjects(into: playaDB)
    }

    override func tearDown() async throws {
        playaDB = nil
        if let tempDBPath {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: tempDBPath + suffix)
            }
        }
        tempDBPath = nil
        try await super.tearDown()
    }

    // MARK: - Fixtures

    private func seedObjects(into db: PlayaDBImpl) async throws {
        try await db.dbQueue.write { db in
            var temple = ArtObject(
                uid: "art-temple",
                name: "Temple of Reflections",
                year: 2026,
                description: "A quiet wooden sanctuary"
            )
            try temple.insert(db)

            var beacon = ArtObject(
                uid: "art-beacon",
                name: "Luminous Beacon",
                year: 2026,
                description: "Tall glowing sculpture"
            )
            try beacon.insert(db)

            var library = CampObject(
                uid: "camp-library",
                name: "Desert Library",
                year: 2026,
                description: "Mobile library with workshops"
            )
            try library.insert(db)

            var pancakes = CampObject(
                uid: "camp-pancakes",
                name: "Pancake Playhouse",
                year: 2026,
                description: "Breakfast all night"
            )
            try pancakes.insert(db)
        }
    }

    private func artUIDs(matching text: String) async throws -> Set<String> {
        try await dbQueue.read { db in
            Set(try ArtObject.all()
                .matching(searchText: text)
                .select(ArtObject.Columns.uid, as: String.self)
                .fetchAll(db))
        }
    }

    private func campUIDs(matching text: String) async throws -> Set<String> {
        try await dbQueue.read { db in
            Set(try CampObject.all()
                .matching(searchText: text)
                .select(CampObject.Columns.uid, as: String.self)
                .fetchAll(db))
        }
    }

    // MARK: - Prefix matching

    func testTwoAndThreeLetterPrefixesMatch() async throws {
        for prefix in ["te", "tem", "temp", "templ", "temple"] {
            let uids = try await artUIDs(matching: prefix)
            XCTAssertTrue(
                uids.contains("art-temple"),
                "Prefix \"\(prefix)\" should match \"Temple of Reflections\""
            )
        }

        for prefix in ["de", "des", "desert"] {
            let uids = try await campUIDs(matching: prefix)
            XCTAssertTrue(
                uids.contains("camp-library"),
                "Prefix \"\(prefix)\" should match \"Desert Library\""
            )
        }
    }

    /// Prefix matching must still discriminate — an incremental query is not a wildcard.
    func testPrefixesStillExcludeNonMatches() async throws {
        let uids = try await artUIDs(matching: "tem")
        XCTAssertFalse(uids.contains("art-beacon"), "\"tem\" must not match \"Luminous Beacon\"")

        let none = try await campUIDs(matching: "zzq")
        XCTAssertTrue(none.isEmpty, "A prefix matching nothing should return nothing")
    }

    /// Every token is prefixed, not just the last: users don't finish typing earlier words
    /// of a multi-word query either.
    func testMultiWordQueriesMatchAllTokens() async throws {
        let complete = try await campUIDs(matching: "desert library")
        XCTAssertEqual(complete, ["camp-library"])

        let partial = try await campUIDs(matching: "des lib")
        XCTAssertEqual(partial, ["camp-library"], "Both tokens should match as prefixes")

        let trailingPartial = try await campUIDs(matching: "desert lib")
        XCTAssertEqual(trailingPartial, ["camp-library"])

        let unmatchedSecondToken = try await campUIDs(matching: "des zzq")
        XCTAssertTrue(unmatchedSecondToken.isEmpty, "All tokens must match (AND semantics)")
    }

    /// The tables are tokenized with `porter`, so indexed terms are stems. A prefix of the
    /// word is also a prefix of its (suffix-stripped) stem, so both the typed-in-progress
    /// word and the fully typed inflected form must resolve.
    func testStemmingAndPrefixesCoexist() async throws {
        for query in ["reflect", "reflection", "reflections"] {
            let uids = try await artUIDs(matching: query)
            XCTAssertTrue(uids.contains("art-temple"), "\"\(query)\" should match \"Reflections\"")
        }
        for query in ["workshop", "workshops", "worksho"] {
            let uids = try await campUIDs(matching: query)
            XCTAssertTrue(uids.contains("camp-library"), "\"\(query)\" should match the description")
        }
    }

    // MARK: - Schema

    func testFTSTablesCarryPrefixIndex() async throws {
        let definitions = try await dbQueue.read { db in
            try String.fetchAll(db, sql: """
                SELECT sql FROM sqlite_master
                WHERE type = 'table' AND name LIKE '%_fts'
                """)
        }
        XCTAssertEqual(definitions.count, 4)
        for sql in definitions {
            XCTAssertTrue(sql.contains("prefix='2 3 4'"), "Missing prefix index in: \(sql)")
        }
    }

    // MARK: - Migration from the pre-prefix schema

    /// Rewinds this database to the pre-`prefix=` FTS schema (what every existing install
    /// and every pre-baked seed zip carries), then reopens it. The v7 migration must drop
    /// the stale tables, `setupFTS5Tables` must recreate them with the prefix option, and
    /// the rebuilt index must still find the seeded rows — by prefix and in full.
    func testMigrationRebuildsLegacyFTSTablesWithPrefixIndex() async throws {
        try await dbQueue.write { db in
            // Recreate the FTS tables exactly as the old schema did: no `prefix=`.
            let legacy: [(String, String)] = [
                ("art_objects", "name,\ndescription,\nartist,\nhometown,\ncategory"),
                ("camp_objects", "name,\ndescription,\nlandmark,\nhometown"),
                ("event_objects", "name,\ndescription,\nevent_type_label,\nprint_description"),
                ("mv_objects", "name,\ndescription,\nartist,\nhometown,\ntags_text"),
            ]
            for (table, columns) in legacy {
                try db.execute(sql: "DROP TABLE IF EXISTS \(table)_fts")
                try db.execute(sql: """
                    CREATE VIRTUAL TABLE \(table)_fts USING fts5(
                        uid UNINDEXED,
                        \(columns),
                        content=\(table),
                        content_rowid=rowid,
                        tokenize='porter unicode61'
                    )
                """)
                try db.execute(sql: "INSERT INTO \(table)_fts(\(table)_fts) VALUES('rebuild')")
            }
            // Pretend the prefix migration never ran on this install.
            try db.execute(sql: "DELETE FROM grdb_migrations WHERE identifier = 'v7-fts-prefix-index'")
        }

        // Sanity: the legacy schema really is in place. Note prefix *queries* still work
        // here — FTS5 answers `des*` without a prefix index by scanning the term
        // dictionary. The migration is about how that query is served, not whether it is.
        let legacyDefinition = try await dbQueue.read { db in
            try XCTUnwrap(String.fetchOne(db, sql: """
                SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'camp_objects_fts'
                """))
        }
        XCTAssertFalse(legacyDefinition.contains("prefix="), "Legacy table should have no prefix index")

        // Reopen — this is what an app upgrade does.
        playaDB = nil
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)

        let applied = try await dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations")
        }
        XCTAssertTrue(applied.contains("v7-fts-prefix-index"), "Migration should re-run on the legacy DB")

        let definitions = try await dbQueue.read { db in
            try String.fetchAll(db, sql: """
                SELECT sql FROM sqlite_master WHERE type = 'table' AND name LIKE '%_fts'
                """)
        }
        for sql in definitions {
            XCTAssertTrue(sql.contains("prefix='2 3 4'"), "Migration left a legacy FTS table: \(sql)")
        }

        // The rebuilt index must contain the pre-existing content, searchable both ways.
        let prefixHits = try await campUIDs(matching: "des")
        XCTAssertEqual(prefixHits, ["camp-library"])
        let phraseHits = try await campUIDs(matching: "desert library")
        XCTAssertEqual(phraseHits, ["camp-library"])
        let artHits = try await artUIDs(matching: "tem")
        XCTAssertTrue(artHits.contains("art-temple"))

        // …and the sync triggers must still be wired to the recreated tables.
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE camp_objects SET name = ? WHERE uid = ?",
                arguments: ["Quixotic Zeppelin Lounge", "camp-library"]
            )
        }
        let renamedHits = try await campUIDs(matching: "quix")
        XCTAssertEqual(renamedHits, ["camp-library"])
        let staleHits = try await campUIDs(matching: "des")
        XCTAssertTrue(staleHits.isEmpty, "Stale terms should be gone")
        try await dbQueue.write { db in
            try db.execute(sql: "INSERT INTO camp_objects_fts(camp_objects_fts) VALUES('integrity-check')")
        }
    }
}
