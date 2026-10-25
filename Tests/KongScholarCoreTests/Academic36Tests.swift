import XCTest
@testable import KongScholarCore

final class Academic36Tests: XCTestCase {
    func fixture() throws -> String {
        let source="TEST ORIGINAL LECTURE36", sources="[{\"id\":\"outcome\",\"title\":\"TEST confirmed\"}]"
        let root: [String: Any] = ["questions": [], "sources": [], "drafts": [], "lessons": [["id": "legacy", "title": "TEST lesson", "body": "TEST KEEP LEGACY36"]], "notes": [], "profile": ["field": "TEST", "method": "TEST", "writing": "TEST", "teaching": "TEST legacy", "name36": "TEST author"], "meta": ["minimumReader": 36, "pinnedProjects36": ["paper"]], "guidancedrafts": [], "projects": [["id": "paper", "title": "TEST paper", "stageHistory36": [["at": "2026-10-25T00:00:00Z", "before": "写作", "after": "返修", "note": "TEST STAGE HISTORY36"]]]], "submissions": [["id": "sub", "title": "TEST journal", "statusHistory36": [["at": "2026-10-25T00:00:00Z", "before": ["submissionStatus": "已投", "body": "TEST SUBMISSION HISTORY36"]]]]], "talks35": [["id": "talk", "title": "TEST talk", "script35": source]], "continuations36": [["id": "link", "title": "TEST link", "snapshot36": ["id": "talk", "script35": source], "basis36": "TEST FROZEN BASIS36"]], "outcomes36": [["id": "outcome", "title": "TEST confirmed"]], "cvdrafts36": [["id": "cv", "title": "TEST CV", "body": "TEST editable CV36", "cvSources36": sources, "basis36": sources]], "academicdates36": [["id": "date", "title": "TEST calendar", "date36": "2026-10-25"]]]
        return String(data: try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]), encoding: .utf8)!
    }
    func testArchiveTwelveKeepsAllCollectionsAndDetachesHistories() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("KS36Archive-"+UUID().uuidString)
        defer {try? FileManager.default.removeItem(at: folder)}
        let store=try ScholarStore(directory: folder), source=try fixture()
        try store.write(source)
        let bytes=try Data(contentsOf: store.dataURL), index=try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        let metadata=try XCTUnwrap(index["_archiveStorage"] as? [String: Any])
        XCTAssertEqual(metadata["version"] as? Int, 12)
        let text=String(decoding: bytes, as: UTF8.self)
        XCTAssertFalse(text.contains("TEST STAGE HISTORY36"))
        XCTAssertFalse(text.contains("TEST SUBMISSION HISTORY36"))
        XCTAssertFalse(text.contains("TEST FROZEN BASIS36"))
        XCTAssertEqual(try Migration34.canonical(XCTUnwrap(store.read())), try Migration34.canonical(source))
        let report=StartupHealth.inspect(store)
        let checks=try XCTUnwrap(report["checks"] as? [[String: Any]])
        XCTAssertEqual(checks.first(where: {$0["title"] as? String == "历史归档与完整资料"})?["state"] as? String, "通过")
    }
    func testCompleteBackupAndIndependentRestoreKeepAcademicAndLegacyRecords() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("KS36Restore-"+UUID().uuidString)
        defer {try? FileManager.default.removeItem(at: folder)}
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let source=try fixture(), result=try BackupVerification34.rehearse(Data(source.utf8), parent: folder)
        let restored=try XCTUnwrap(result["text"] as? String), report=try XCTUnwrap(result["report"] as? [String: Any]),counts=try XCTUnwrap(report["counts"] as? [String: Int])
        XCTAssertEqual(try Migration34.canonical(restored), try Migration34.canonical(source))
        for type in ["outcomes36","cvdrafts36","continuations36","academicdates36","lessons"] {XCTAssertEqual(counts[type],1)}
        XCTAssertEqual(report["storageRoundTrip"] as? Bool,true)
    }
    func testNewCollectionsRejectDuplicateAndMalformedRows() throws {
        let source=try fixture()
        for type in ["outcomes36","cvdrafts36","continuations36","academicdates36"] {
            var root=try JSONSerialization.jsonObject(with: Data(source.utf8)) as! [String: Any]
            root[type] = [["id": "duplicate", "title": "TEST"], ["id": "duplicate", "title": "TEST"]]
            XCTAssertThrowsError(try ScholarStore.validate(String(data: JSONSerialization.data(withJSONObject: root), encoding: .utf8)!))
            root[type] = "INVALID"
            XCTAssertThrowsError(try ScholarStore.validate(String(data: JSONSerialization.data(withJSONObject: root), encoding: .utf8)!))
        }
    }
}
