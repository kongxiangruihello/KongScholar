import XCTest
@testable import KongScholarCore

final class ScholarStoreTests: XCTestCase {
    var temp: URL!
    override func setUpWithError() throws {
        temp = FileManager.default.temporaryDirectory.appendingPathComponent("KongScholarTests-" + UUID().uuidString)
    }
    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: temp.path) { try FileManager.default.removeItem(at: temp) }
    }
    func record(_ title: String) -> String {
        """
        {"questions":[],"sources":[{"id":"s","title":"\(title)","body":"原文"}],"drafts":[],"lessons":[],"notes":[],"profile":{"field":"何以为士","method":"比较","writing":"论证","teaching":"研读"}}
        """
    }
    func testReopenAndRecoveryCopy() throws {
        let store = try ScholarStore(directory: temp)
        XCTAssertNil(try store.read())
        let first = record("第一条")
        try store.write(first)
        XCTAssertEqual(try ScholarStore(directory: temp).read(), first)
        try store.write(record("第二条"))
        XCTAssertEqual(try String(contentsOf: store.recoveryURL.appendingPathComponent("previous-data.json"), encoding: .utf8), first)
        XCTAssertTrue((try store.read())!.contains("第二条"))
    }
    func testInvalidWriteNeverOverwritesGoodData() throws {
        let store = try ScholarStore(directory: temp)
        try store.write(record("原记录"))
        XCTAssertThrowsError(try store.write("{broken"))
        XCTAssertThrowsError(try store.write("{}"))
        XCTAssertEqual(try store.read(), record("原记录"))
    }
    func testCorruptDataIsReturnedWithoutOverwrite() throws {
        let store = try ScholarStore(directory: temp)
        try Data("{broken".utf8).write(to: store.dataURL)
        XCTAssertEqual(try store.read(), "{broken")
        try store.write(record("恢复"))
        XCTAssertEqual(try String(contentsOf: store.recoveryURL.appendingPathComponent("previous-data.json"), encoding: .utf8), "{broken")
    }
    func testRejectDuplicateIDsAndMalformedRelations() throws {
        let good = record("原记录")
        let duplicate = good.replacingOccurrences(of: "\"questions\":[]", with: "\"questions\":[{\"id\":\"x\",\"title\":\"一\"},{\"id\":\"x\",\"title\":\"二\"}]")
        XCTAssertThrowsError(try ScholarStore.validate(duplicate))
        let invalid = good.replacingOccurrences(of: "\"drafts\":[]", with: "\"arguments\":[{\"id\":\"x\",\"title\":\"判断\",\"support\":\"s\"}],\"drafts\":[]")
        XCTAssertThrowsError(try ScholarStore.validate(invalid))
    }
    func testUnicodeAndJavascriptEscapingRoundtrip() throws {
        let text = "引文\"\\\n\u{2028}林乐知</script>"
        let literal = ScholarStore.javascriptLiteral(text)
        let decoded = try JSONSerialization.jsonObject(with: Data(literal.utf8), options: [.fragmentsAllowed]) as? String
        XCTAssertEqual(decoded, text)
        XCTAssertEqual(ScholarStore.javascriptLiteral(nil), "null")
    }
    func testSnapshotsAreValidatedAndPreserveLiveData() throws {
        let store = try ScholarStore(directory: temp)
        try store.write(record("第一条"))
        let first = try XCTUnwrap(store.snapshotIfNeeded(force: true, label: "manual"))
        XCTAssertEqual(try store.backupText(named: first.lastPathComponent), record("第一条"))
        XCTAssertNil(try store.snapshotIfNeeded())
        try store.write(record("第二条"))
        XCTAssertEqual(try store.backupText(named: first.lastPathComponent), record("第一条"))
        XCTAssertEqual(try store.read(), record("第二条"))
        XCTAssertThrowsError(try store.backupText(named: "../scholar-data.json"))
        let corrupt = store.backupURL.appendingPathComponent("corrupt.json")
        try Data("broken".utf8).write(to: corrupt)
        XCTAssertThrowsError(try store.backupText(named: "corrupt.json"))
        XCTAssertEqual(try store.read(), record("第二条"))
    }
    func testSizeLimit() throws {
        XCTAssertThrowsError(try ScholarStore.validate(String(repeating: "x", count: ScholarStore.limit + 1)))
    }
    func testConfiguredBackupCadenceAndDuplicateSuppression() throws {
        let store = try ScholarStore(directory: temp)
        let first = record("初稿").replacingOccurrences(of: "\"questions\":[]", with: "\"settings\":{\"backupIntervalMins\":15,\"backupRetentionCount\":30},\"questions\":[]")
        try store.write(first)
        let date = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertNotNil(try store.snapshotIfNeeded(force: true, now: date))
        XCTAssertNil(try store.snapshotIfNeeded(force: true, now: date.addingTimeInterval(60)))
        // Directly replace the test file so the write hook cannot create an intermediate snapshot.
        try Data(first.replacingOccurrences(of: "初稿", with: "修改稿").utf8).write(to: store.dataURL)
        XCTAssertNil(try store.snapshotIfNeeded(now: date.addingTimeInterval(899)))
        XCTAssertNotNil(try store.snapshotIfNeeded(now: date.addingTimeInterval(901)))
        XCTAssertEqual(store.backupPreferences().interval, 15)
        XCTAssertEqual(store.backupPreferences().retention, 30)
    }
    func testDefaultFifteenMinuteBackupsAndExistingHourlyPreference() throws {
        let store = try ScholarStore(directory: temp)
        XCTAssertEqual(store.backupPreferences().interval, 15)
        try store.write(record("TEST first"))
        let at = Date(timeIntervalSince1970: 2_000_000)
        let first = try XCTUnwrap(store.snapshotIfNeeded(force: true, now: at))
        try Data(record("TEST changed").utf8).write(to: store.dataURL)
        XCTAssertNil(try store.snapshotIfNeeded(now: at.addingTimeInterval(899)))
        let next = try XCTUnwrap(store.snapshotIfNeeded(now: at.addingTimeInterval(901)))
        XCTAssertEqual(try store.backupText(named: next.lastPathComponent), record("TEST changed"))
        XCTAssertEqual(try store.backupText(named: first.lastPathComponent), record("TEST first"))
        let hourly = record("TEST hourly").replacingOccurrences(of: "\"questions\":[]", with: "\"settings\":{\"backupIntervalMins\":60},\"questions\":[]")
        try Data(hourly.utf8).write(to: store.dataURL)
        XCTAssertEqual(store.backupPreferences().interval, 60)
        XCTAssertNil(try store.snapshotIfNeeded(now: at.addingTimeInterval(1802)))
        XCTAssertNotNil(try store.snapshotIfNeeded(now: at.addingTimeInterval(4502)))
    }
    func testConfiguredRetentionPreservesManualSnapshot() throws {
        let store = try ScholarStore(directory: temp)
        let base = record("初稿").replacingOccurrences(of: "\"questions\":[]", with: "\"settings\":{\"backupRetentionCount\":30},\"questions\":[]")
        try store.write(base)
        let manual = try XCTUnwrap(store.snapshotIfNeeded(force: true, label: "manual"))
        for index in 1...35 {
            try Data(base.replacingOccurrences(of: "初稿", with: "稿件\(index)").utf8).write(to: store.dataURL)
            _ = try store.snapshotIfNeeded(force: true, now: Date().addingTimeInterval(Double(index)))
        }
        XCTAssertEqual(try store.backupFiles().filter { $0.lastPathComponent.contains("-auto-") }.count, 30)
        XCTAssertTrue(FileManager.default.fileExists(atPath: manual.path))
        XCTAssertThrowsError(try store.snapshotIfNeeded(force: true, label: "../escape"))
    }
    func testBackupFailurePreservesExistingData() throws {
        let store = try ScholarStore(directory: temp)
        try store.write(record("已有稿件"))
        try Data("not a directory".utf8).write(to: store.backupURL)
        XCTAssertThrowsError(try store.snapshotIfNeeded(force: true))
        XCTAssertEqual(try store.read(), record("已有稿件"))
    }

}
