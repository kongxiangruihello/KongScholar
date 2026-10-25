import XCTest
@testable import KongScholarCore

final class Academic35Tests: XCTestCase {
    func fixture() throws -> String {
        let root: [String: Any] = ["questions": [], "sources": [], "drafts": [], "lessons": [["id": "legacy", "title": "TEST lesson", "body": "TEST KEEP EXACT"]], "notes": [], "profile": ["field": "TEST research", "method": "TEST", "writing": "TEST", "teaching": "TEST legacy preference"], "meta": ["minimumReader": 35], "talks35": [["id": "talk", "title": "TEST report", "script35": "TEST manuscript", "projectIDs": ["academic"]]], "meetingactions34": [], "guidancedrafts": [], "projects": [["id": "academic", "title": "TEST academic project", "projectKind": "会议报告"]]]
        return String(data: try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]), encoding: .utf8)!
    }
    func testArchiveElevenRoundTripKeepsTalkAndLegacyRecords() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("KS35Tests-"+UUID().uuidString)
        defer {try? FileManager.default.removeItem(at: folder)}
        let store=try ScholarStore(directory: folder), source=try fixture()
        try store.write(source)
        let index=try JSONSerialization.jsonObject(with: Data(contentsOf: store.dataURL)) as! [String: Any]
        XCTAssertEqual((try XCTUnwrap(index["_archiveStorage"] as? [String: Any]))["version"] as? Int, 11)
        XCTAssertEqual(try Migration34.canonical(XCTUnwrap(store.read())), try Migration34.canonical(source))
        var invalid=try JSONSerialization.jsonObject(with: Data(source.utf8)) as! [String: Any]
        invalid["talks35"]=[["id": "duplicate", "title": "TEST"], ["id": "duplicate", "title": "TEST"]]
        XCTAssertThrowsError(try ScholarStore.validate(String(data: JSONSerialization.data(withJSONObject: invalid), encoding: .utf8)!))
    }
    func testIndependentRestoreRetainsTalkAndHistoricalTeaching() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("KS35Restore-"+UUID().uuidString)
        defer {try? FileManager.default.removeItem(at: folder)}
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let source=try fixture(), result=try BackupVerification34.rehearse(Data(source.utf8), parent: folder)
        let report=result["report"] as! [String: Any]
        XCTAssertEqual(report["storageRoundTrip"] as? Bool, true)
        let restored=try XCTUnwrap(result["text"] as? String)
        // The verifier persists a portable JSON next to its independent trial store.
        XCTAssertEqual(try Migration34.canonical(restored), try Migration34.canonical(source))
        XCTAssertEqual((report["counts"] as? [String: Int])?["talks35"], 1)
        XCTAssertEqual((report["counts"] as? [String: Int])?["lessons"], 1)
        XCTAssertNoThrow(try ScholarStore.validate(source))
    }
}
