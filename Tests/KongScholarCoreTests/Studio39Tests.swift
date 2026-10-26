import Foundation
import XCTest
@testable import KongScholarCore

final class Studio39Tests:XCTestCase {
    var folder:URL!
    override func setUpWithError()throws {folder=FileManager.default.temporaryDirectory.appendingPathComponent("KS39-"+UUID().uuidString);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false)}
    override func tearDownWithError()throws {try FileManager.default.removeItem(at:folder)}
    func root()->[String:Any] {["meta":["minimumReader":39],"profile":["field":"TEST","method":"TEST","writing":"TEST","teaching":"TEST legacy"],"questions":[],"sources":[],"drafts":[],"notes":[],"lessons":[["id":"legacy","title":"TEST historical read-only"]],"chapters":[["id":"ch","title":"TEST chapter","writing":["body":"TEST ORIGINAL MANUSCRIPT","citations":[]]]],"projects":[["id":"p","title":"TEST project","archive39":["at":"2026-10-26T00:00:00Z","reason":"TEST archived","stage":"暂缓"]]],"progress38":[["id":"log","title":"TEST log","history39":[["before":["body":"TEST OLD JUDGMENT"],"after":["body":"TEST NEW JUDGMENT"],"reason":"TEST checked original"]]]],"packsnapshots39":[["id":"snap","title":"TEST snapshot","snapshot39":"TEST FROZEN QUOTE"]],"briefs39":[["id":"brief","title":"TEST brief","selected39":"TEST SELECTED SOURCES","body":"TEST public"]]]}
    func text(_ r:[String:Any])throws->String {String(data:try JSONSerialization.data(withJSONObject:r,options:[.sortedKeys]),encoding:.utf8)!}
    func testArchive15RoundtripAndIndependentBackupPreserveSnapshotsHistoryAndLegacy()throws {
        let source=try text(root()),store=try ScholarStore(directory:folder.appendingPathComponent("store"));try store.write(source)
        let index=try JSONSerialization.jsonObject(with:Data(contentsOf:store.dataURL)) as! [String:Any];XCTAssertEqual((index["_archiveStorage"] as! [String:Any])["version"] as? Int,15)
        let raw=try String(contentsOf:store.dataURL);XCTAssertFalse(raw.contains("TEST FROZEN QUOTE"));XCTAssertFalse(raw.contains("TEST OLD JUDGMENT"));XCTAssertFalse(raw.contains("TEST SELECTED SOURCES"));XCTAssertEqual(try Migration34.canonical(XCTUnwrap(store.read())),try Migration34.canonical(source))
        let proof=try BackupVerification34.rehearse(Data(source.utf8),parent:folder);XCTAssertEqual(try Migration34.canonical(proof["text"] as! String),try Migration34.canonical(source))
        for type in ["packsnapshots39","briefs39"] {var bad=root();bad[type]=[["id":"dup","title":"TEST"],["id":"dup","title":"TEST"]];XCTAssertThrowsError(try ScholarStore.validate(text(bad)))}
    }
    func testMigrationPostcheckReportsFullKeysMissingAndChangedFilesWithoutRewriting()throws {
        var r=root();let file=folder.appendingPathComponent("TEST.txt"),bytes=Data("TEST content".utf8);try bytes.write(to:file)
        r["deliveries"]=[["id":"export","title":"TEST file","exportFile30":["path":file.path,"sha256":ScholarArchive.digest(bytes),"bytes":bytes.count]]]
        let source=try text(r),good=try Migration39.check(source)["rows"] as! [[String:Any]];XCTAssertEqual(good[0]["key"] as? String,"deliveries:export");XCTAssertEqual(good[0]["state"] as? String,"可用")
        try Data("TEST CHANGED".utf8).write(to:file);XCTAssertEqual((try Migration39.check(source)["rows"] as! [[String:Any]])[0]["state"] as? String,"待处理")
        try FileManager.default.removeItem(at:file);XCTAssertEqual((try Migration39.check(source)["rows"] as! [[String:Any]])[0]["state"] as? String,"待处理");XCTAssertEqual(try text(r),source)
    }
    func testMigratedAttachmentUsesNewPathAndPassesPostcheck()throws {
        var r=root();let file=folder.appendingPathComponent("TEST.txt"),bytes=Data("TEST content".utf8);try bytes.write(to:file);r["deliveries"]=[["id":"export","title":"TEST file","exportFile30":["path":file.path,"sha256":ScholarArchive.digest(bytes),"bytes":bytes.count]]]
        let zip=try Migration34.generate(text:text(r),keys:["deliveries:export"]),restored=try BackupVerification34.rehearse(zip,parent:folder),rows=try Migration39.check(restored["text"] as! String)["rows"] as! [[String:Any]]
        XCTAssertEqual(rows[0]["state"] as? String,"可用");XCTAssertNotEqual(rows[0]["path"] as? String,file.path);XCTAssertTrue((rows[0]["path"] as! String).contains("attachments/"))
    }
    func testAmbiguousDSTImportExportPreservesExplicitInstant()throws {
        let source="BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:TEST-DST39\r\nDTSTART:20261101T063000Z\r\nDTEND:20261101T071500Z\r\nSUMMARY:TEST second repeated time\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n",zone=TimeZone(identifier:"America/New_York")!,rows=try CalendarICS37.inspect(Data(source.utf8),localTimeZone:zone)["events"] as! [[String:Any]]
        XCTAssertEqual(rows[0]["startTime36"] as? String,"01:30");XCTAssertEqual(rows[0]["startInstant39"] as? String,"2026-11-01T06:30:00Z")
        let output=try CalendarICS37.generate(rows,localTimeZone:zone);XCTAssertTrue(String(decoding:output,as:UTF8.self).contains("DTSTART:20261101T063000Z"))
        var bad=rows[0];bad["startTime36"]="02:30";XCTAssertThrowsError(try CalendarICS37.generate([bad],localTimeZone:zone))
    }
}
