import XCTest
import AppKit
import PDFKit
@testable import KongScholarCore

final class AdvancedStorageTests: XCTestCase {
    var temp: URL!
    override func setUpWithError() throws { temp = FileManager.default.temporaryDirectory.appendingPathComponent("KongScholar24Tests-" + UUID().uuidString); try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true) }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: temp) }
    func payload(history: String = "Frozen original") throws -> String {
        let root: [String: Any] = ["questions": [], "sources": [], "drafts": [], "lessons": [], "notes": [], "profile": ["field":"TEST","method":"TEST","writing":"TEST","teaching":"TEST"], "freezes": [["id":"f","title":"TEST frozen","snapshot":["body":history]]], "chapters": [["id":"c","title":"TEST chapter","versions":[["id":"v","title":"TEST version","body":"OLD VERSION"]]]]]
        return String(data: try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]), encoding: .utf8)!
    }
    func object(_ string: String) throws -> NSDictionary { try JSONSerialization.jsonObject(with: Data(string.utf8)) as! NSDictionary }
    func testColdStoragePortableReadAndSnapshot() throws {
        let store = try ScholarStore(directory: temp), text = try payload(); try store.write(text)
        let index = try String(contentsOf: store.dataURL, encoding: .utf8)
        XCTAssertTrue(index.contains("_archiveStorage")); XCTAssertTrue(index.contains("_archiveIndexOnly")); XCTAssertFalse(index.contains("Frozen original"))
        XCTAssertEqual(try object(XCTUnwrap(store.read())), try object(text))
        let backup = try XCTUnwrap(store.snapshotIfNeeded(force: true, label: "manual"))
        XCTAssertEqual(try object(store.backupText(named: backup.lastPathComponent)), try object(text))
        let independent = try ScholarStore(directory: temp.appendingPathComponent("restored")); try independent.write(store.backupText(named: backup.lastPathComponent)); XCTAssertEqual(try object(XCTUnwrap(independent.read())), try object(text))
    }
    func testNewCollectionsProtectAgainstOlderAppWriters() throws {
        var root = try JSONSerialization.jsonObject(with: Data(payload().utf8)) as! [String: Any]
        root.removeValue(forKey: "freezes"); root.removeValue(forKey: "chapters"); root["timebudgets"] = [["id":"b","title":"TEST budget","hours":"3"]]
        let bytes = try JSONSerialization.data(withJSONObject: root), store = try ScholarStore(directory: temp)
        try store.write(String(data: bytes, encoding: .utf8)!)
        let index = try JSONSerialization.jsonObject(with: Data(contentsOf: store.dataURL)) as! [String: Any]
        XCTAssertNil((index["profile"] as? [String: Any])?["field"])
        XCTAssertEqual(try object(XCTUnwrap(store.read())), root as NSDictionary)
    }
    func testColdHistoryExceedsOldLimitWithoutInflatingIndex() throws {
        let store = try ScholarStore(directory: temp), text = try payload(history: String(repeating: "X", count: 26 * 1024 * 1024)); try store.write(text)
        XCTAssertGreaterThan(try XCTUnwrap(store.read()).utf8.count, 25 * 1024 * 1024)
        XCTAssertLessThan(try Data(contentsOf: store.dataURL).count, 4096)
    }
    func testMissingAndCorruptChunksFailClosedAndKeepBackups() throws {
        let store = try ScholarStore(directory: temp); try store.write(payload()); let backup = try XCTUnwrap(store.snapshotIfNeeded(force: true, label: "manual"))
        let chunks = try FileManager.default.contentsOfDirectory(at: temp.appendingPathComponent("archives"), includingPropertiesForKeys: nil)
        try Data("CORRUPT".utf8).write(to: chunks[0]); XCTAssertThrowsError(try store.read()); XCTAssertTrue(try XCTUnwrap(store.readForInterface()).contains("_archiveReadError")); XCTAssertNoThrow(try store.backupText(named: backup.lastPathComponent))
        try FileManager.default.removeItem(at: chunks[0]); XCTAssertThrowsError(try store.read()); XCTAssertThrowsError(try ScholarStore.validate(String(contentsOf: store.dataURL)))
        try store.write(store.backupText(named: backup.lastPathComponent)); XCTAssertTrue(try XCTUnwrap(store.read()).contains("Frozen original"))
    }
    func testUnchangedArchivesAreDeduplicatedAndOldRevisionSurvives() throws {
        let store = try ScholarStore(directory: temp); try store.write(payload()); let folder = temp.appendingPathComponent("archives")
        let first = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        try store.write(payload()); XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).count, first.count)
        try store.write(payload(history: "NEW FROZEN")); for file in first { XCTAssertTrue(FileManager.default.fileExists(atPath: file.path)) }
        XCTAssertTrue(try String(contentsOf: store.recoveryURL.appendingPathComponent("previous-data.json")).contains("Frozen original"))
    }
    func testMirrorReadbackAndDisconnectedFolder() throws {
        let chosen = temp.appendingPathComponent("removable"); try FileManager.default.createDirectory(at: chosen, withIntermediateDirectories: true)
        let text = try payload(), first = try BackupMirror.copy(text, into: chosen), second = try BackupMirror.copy(text, into: chosen)
        XCTAssertEqual(first,second); XCTAssertEqual(try object(String(contentsOf: first)), try object(text))
        try FileManager.default.removeItem(at: chosen); XCTAssertThrowsError(try BackupMirror.copy(text, into: chosen)); XCTAssertFalse(FileManager.default.fileExists(atPath: chosen.path))
    }
    func testBackupHealthShowsPortableLatest() throws {
        let store = try ScholarStore(directory: temp); try store.write(payload(history:String(repeating:"HISTORY",count:1000))); try store.snapshotIfNeeded(force: true,label:"manual")
        let health = try BackupMirror.health(store); XCTAssertEqual(health["restorable"] as? Bool,true); XCTAssertGreaterThan(health["archiveCount"] as? Int ?? 0,0); XCTAssertLessThan(health["indexBytes"] as? Int ?? Int.max,health["liveBytes"] as? Int ?? 0)
    }
    func testArchiveIndexDetectsRemovedHistoryPointers() throws {
        let bytes = try ScholarArchive.encode(Data(payload().utf8), directory: temp)
        var root = try JSONSerialization.jsonObject(with: bytes) as! [String:Any], storage = root["_archiveStorage"] as! [String:Any]
        storage["pointers"] = []; root["_archiveStorage"] = storage
        XCTAssertThrowsError(try ScholarArchive.decode(JSONSerialization.data(withJSONObject: root), directory: temp))
    }
    func testArchiveRejectsPointerTraversalAndDuplicatePaths() throws {
        let bytes = try ScholarArchive.encode(Data(payload().utf8), directory: temp)
        var root = try JSONSerialization.jsonObject(with: bytes) as! [String:Any],storage = root["_archiveStorage"] as! [String:Any], pointers = storage["pointers"] as! [[String:Any]]
        pointers[0]["sha256"] = "../outside"; storage["pointers"] = pointers; root["_archiveStorage"] = storage
        XCTAssertThrowsError(try ScholarArchive.decode(JSONSerialization.data(withJSONObject:root),directory:temp))
    }
    func testCropBoundsAndLocalRecognition() throws {
        let image = NSImage(size:NSSize(width:800,height:300));image.lockFocus();NSColor.white.setFill();NSRect(x:0,y:0,width:800,height:300).fill();("TEST SCHOLAR OCR 2026" as NSString).draw(at:NSPoint(x:30,y:100),withAttributes:[.font:NSFont.systemFont(ofSize:40),.foregroundColor:NSColor.black]);image.unlockFocus()
        let png = try EvidenceImage.png(image,crop:CGRect(x:0,y:0,width:1,height:1));XCTAssertFalse(png.isEmpty)
        XCTAssertThrowsError(try EvidenceImage.png(image,crop:CGRect(x:-0.1,y:0,width:1,height:1)))
        let result = try EvidenceImage.recognize(png.base64EncodedString());XCTAssertTrue((result["text"] as? String ?? "").contains("SCHOLAR"))
    }
    func testFolioPDFContainerReadAndIdentityGuard() throws {
        let document=PDFDocument(),image=NSImage(size:NSSize(width:100,height:100));image.lockFocus();NSColor.white.setFill();NSRect(x:0,y:0,width:100,height:100).fill();image.unlockFocus();document.insert(PDFPage(image:image)!,at:0);let pdf=try XCTUnwrap(document.dataRepresentation()),id=UUID().uuidString
        let manifest=try JSONSerialization.data(withJSONObject:["archive":["scholarDocumentID":id],"blobs":["pdf":["offset":0,"length":pdf.count]]]),magic=Data("KONGFOLIO-PROJECT\n".utf8)
        var bytes=magic,length=UInt64(manifest.count).bigEndian;withUnsafeBytes(of:&length){bytes.append(contentsOf:$0)};bytes.append(manifest);bytes.append(pdf)
        let file=temp.appendingPathComponent("test.kongfolio");try bytes.write(to:file)
        XCTAssertEqual(try EvidenceImage.pdfData(at:file,expectedID:id),pdf);XCTAssertThrowsError(try EvidenceImage.pdfData(at:file,expectedID:UUID().uuidString))
    }
}
