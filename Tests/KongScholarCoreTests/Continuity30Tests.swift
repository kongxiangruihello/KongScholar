import XCTest
@testable import KongScholarCore

final class Continuity30Tests: XCTestCase {
    let token = "KS29-0123456789ABCDEF0123456789ABCDEF"
    func library(_ records: [[String: Any]] = []) throws -> String {
        let value: [String: Any] = ["profile": ["field": "TEST ONLY", "method": "TEST", "writing": "TEST", "teaching": "TEST"], "questions": [], "sources": [], "drafts": [], "lessons": [], "notes": [], "deliveries": records, "meta": ["minimumReader": 30]]
        return String(data: try JSONSerialization.data(withJSONObject: value), encoding: .utf8)!
    }
    func entry() -> [String: Any] {
        let chapter: [String: Any] = ["id": "TEST ONLY chapter", "title": "TEST ONLY Chapter", "writing": ["body": "TEST ONLY manuscript", "citations": []]]
        let record: [String: Any] = ["id": "TEST ONLY delivery", "title": "TEST ONLY Export", "deliveryToken29": token, "chapters": [chapter], "feedback": [], "projectIDs": ["TEST ONLY project"]]
        return ["token": token, "payload": ["title": "TEST ONLY Export", "deliveryToken29": token], "deliveryRecord30": record]
    }
    func withFolder(_ action: (URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("KongScholar30Tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }; try action(dir)
    }
    func testPreparedIntentSurvivesCrashBeforeSavedMarkerAndRequiresActualFile() throws {
        try withFolder { dir in
            let target = dir.appendingPathComponent("TEST ONLY.docx"), output = Data("TEST ONLY EXPORTED BYTES".utf8)
            try ExportOutbox30.prepare(entry: entry(), output: output, destination: target, root: dir, proof: [:])
            XCTAssertEqual(try ExportOutbox30.list(root: dir).first?["state"] as? String, "unverified")
            try output.write(to: target)
            XCTAssertEqual(try ExportOutbox30.list(root: dir).first?["state"] as? String, "saved")
            let receipt = dir.appendingPathComponent("export-outbox/" + token + ".json")
            XCTAssertEqual((try JSONSerialization.jsonObject(with: Data(contentsOf: receipt)) as? [String: Any])?["state"] as? String, "saved")
        }
    }
    func testAcknowledgementRequiresExactPersistedSnapshotAndIsIdempotent() throws {
        try withFolder { dir in
            let target = dir.appendingPathComponent("TEST ONLY.docx"), bytes = Data("TEST ONLY".utf8), e = entry()
            try ExportOutbox30.prepare(entry: e, output: bytes, destination: target, root: dir, proof: [:]); try bytes.write(to: target)
            XCTAssertThrowsError(try ExportOutbox30.acknowledge(token: token, root: dir, library: library()))
            var changed = e["deliveryRecord30"] as! [String: Any]; changed["title"] = "TEST wrong snapshot"
            XCTAssertThrowsError(try ExportOutbox30.acknowledge(token: token, root: dir, library: library([changed])))
            XCTAssertEqual(try ExportOutbox30.list(root: dir).count, 1)
            let saved = try library([e["deliveryRecord30"] as! [String: Any]])
            try ExportOutbox30.acknowledge(token: token, root: dir, library: saved)
            try ExportOutbox30.acknowledge(token: token, root: dir, library: saved)
            XCTAssertTrue(try ExportOutbox30.list(root: dir).isEmpty)
        }
    }
    func testChangedMovedAndSymlinkFileNeverBecomeVerified() throws {
        try withFolder { dir in
            let target = dir.appendingPathComponent("TEST ONLY.docx"), bytes = Data("TEST ONLY ORIGINAL".utf8)
            try ExportOutbox30.prepare(entry: entry(), output: bytes, destination: target, root: dir, proof: [:]); try bytes.write(to: target)
            try ExportOutbox30.markSaved(token: token, root: dir)
            try Data("TEST ONLY MODIFIED".utf8).write(to: target)
            XCTAssertEqual(try ExportOutbox30.list(root: dir).first?["state"] as? String, "unverified")
            let moved = dir.appendingPathComponent("TEST moved.docx"); try FileManager.default.moveItem(at: target, to: moved)
            try bytes.write(to: moved); try FileManager.default.createSymbolicLink(at: target, withDestinationURL: moved)
            XCTAssertEqual(try ExportOutbox30.list(root: dir).first?["state"] as? String, "unverified")
        }
    }
    func testInvalidIntentAndCorruptReceiptDoNotOverwriteExistingEvidence() throws {
        try withFolder { dir in
            let target = dir.appendingPathComponent("TEST.docx"), bytes = Data("TEST ONLY".utf8)
            var invalid = entry(); invalid["token"] = "../../TEST"
            XCTAssertThrowsError(try ExportOutbox30.prepare(entry: invalid, output: bytes, destination: target, root: dir, proof: [:]))
            try ExportOutbox30.prepare(entry: entry(), output: bytes, destination: target, root: dir, proof: [:])
            XCTAssertThrowsError(try ExportOutbox30.prepare(entry: entry(), output: bytes, destination: target, root: dir, proof: [:]))
            let receipt = dir.appendingPathComponent("export-outbox/" + token + ".json"), damaged = Data("TEST ONLY DAMAGED".utf8)
            try damaged.write(to: receipt)
            XCTAssertThrowsError(try ExportOutbox30.list(root: dir))
            XCTAssertEqual(try Data(contentsOf: receipt), damaged)
        }
    }
    func testProofDistinguishesPreparedAuthorFromActuallyWrittenAuthorAndMatchesFileHash() throws {
        var layout = WordLayout(); layout.author = "TEST ONLY AUTHOR"; layout.titlePage = false; layout.abstract = "TEST ONLY ABSTRACT"; layout.keywords = "TEST ONLY KEYWORDS"; layout.appendix = "TEST ONLY APPENDIX"
        let request = WordExportRequest(title: "TEST ONLY Proof", chapters: [WordChapter(title: "TEST ONLY Chapter", body: "TEST ONLY Body [^ks-1] [^ks-missing]", citations: [WordCitation(id: "ks-1", text: "TEST ONLY footnote")]), WordChapter(title: "参考文献", body: "TEST ONLY Bibliography", citations: [])], layout: layout, deliveryToken29: token)
        let report = try WordProof30.inspect(request), rows = report["items"] as! [[String: Any]]
        XCTAssertEqual(rows.first { $0["name"] as? String == "作者信息" }?["present"] as? Bool, false)
        for name in ["摘要", "关键词", "附录", "参考文献", "页下注"] { XCTAssertEqual(rows.first { $0["name"] as? String == name }?["present"] as? Bool, true, name) }
        XCTAssertEqual(report["missingNotes"] as? Int, 1); XCTAssertEqual(report["footnotes"] as? Int, 1)
        XCTAssertEqual(report["sha256"] as? String, ScholarArchive.digest(try WordExport.generate(request)))
    }
    func testStorageSevenPreservesParagraphIdentitiesRepairHistoryAndPreUpgradeBackup() throws {
        try withFolder { dir in
            let store = try ScholarStore(directory: dir), initial = try library(); try store.write(initial); store.releaseVersion = "3.0.0"
            var root = try JSONSerialization.jsonObject(with: Data(initial.utf8)) as! [String: Any]
            root["chapters"] = [["id": "TEST ONLY Chapter", "title": "TEST ONLY", "paragraphs30": [["id": "TEST ONLY Paragraph", "text": "TEST ONLY", "offset": 0]]]]
            root["bookmarks"] = [["id": "TEST ONLY Bookmark", "title": "TEST ONLY", "anchor30": ["chapterID": "TEST ONLY Chapter", "paragraphID": "TEST ONLY Paragraph", "field": "anchorText", "text": "TEST ONLY"], "anchorRepairs30": [["at": "TEST ONLY", "reason": "TEST ONLY", "before": ["text": "TEST OLD"], "after": ["text": "TEST NEW"]]]]]
            let text = String(data: try JSONSerialization.data(withJSONObject: root), encoding: .utf8)!; try store.write(text)
            let index = try JSONSerialization.jsonObject(with: Data(contentsOf: store.dataURL)) as! [String: Any]
            XCTAssertEqual((index["_archiveStorage"] as? [String: Any])?["version"] as? Int, 7)
            XCTAssertEqual(try JSONSerialization.jsonObject(with: Data(store.read()!.utf8)) as? NSDictionary, root as NSDictionary)
            let receipt = try UpgradeProtection.protect(store, version: "3.0.0")
            XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("upgrades/" + (receipt["file"] as! String))), Data(initial.utf8))
        }
    }
}
