import XCTest
@testable import KongScholarCore
final class Materials28Tests:XCTestCase {
    func fixture()throws->String{
        let source:[String:Any] = ["id":"s","title":"TEST ONLY source","body":"TEST ORIGINAL","punctuated28":"TEST punctuated","citeLayer28":"标点整理稿","layerReason28":"TEST evidence","excerpt28":["indexID":"pdf","sha256":String(repeating:"a",count:64),"pages":[["page":1,"printed":"i","region":[0.1,0.2,0.3,0.4]],["page":2,"printed":"1","region":NSNull()]],"at":"2026-10-25","path":"/private/tmp/TEST.pdf","documentID":"","indexTitle":"TEST ONLY PDF"]]
        var root:[String:Any] = ["profile":["field":"TEST ONLY","method":"TEST","writing":"TEST","teaching":"TEST"],"questions":[],"sources":[source],"drafts":[],"lessons":[],"notes":[],"evidenceimages":[],"meta":["minimumReader":28,"pdfPositions28":["pdf":2]],"pdfindexes":[["id":"pdf","title":"TEST PDF","pages":[["page":1,"text":"TEST ONE"],["page":2,"text":"TEST TWO"]]]]]
        for type in ["pagemaps28","alignments28","versionchoices28","reliability28","searchleads28","searchattempts28"] {root[type] = [["id":type,"title":"TEST ONLY "+type,"body":"TEST immutable evidence"]]}
        return String(data:try JSONSerialization.data(withJSONObject:root,options:.sortedKeys),encoding:.utf8)!
    }
    func testArchiveFiveAndPortableBackupRetainAllNewFields()throws{
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("Materials28-"+UUID().uuidString);defer{try? FileManager.default.removeItem(at:dir)}
        let store=try ScholarStore(directory:dir),text=try fixture();store.releaseVersion="2.8.0";try store.write(text)
        let index=try JSONSerialization.jsonObject(with:Data(contentsOf:store.dataURL)) as! [String:Any]
        XCTAssertEqual((index["_archiveStorage"] as? [String:Any])?["version"] as? Int,5)
        let restored=try XCTUnwrap(store.read());XCTAssertEqual(try ScholarArchive.digest(ScholarStore.validate(restored)),try ScholarArchive.digest(ScholarStore.validate(text)))
        let report=StartupHealth.inspect(store,resources:nil);let checks=report["checks"] as? [[String:Any]];XCTAssertEqual(checks?.first{($0["title"] as? String)=="资料索引"}?["state"] as? String,"通过")
        let zip=try WorkingBackup.generate(text:restored,drafts:nil),inspected=try WorkingBackup.inspect(zip)
        XCTAssertEqual(inspected.text,restored)
    }
    func testNewCollectionsRejectMalformedAndDuplicateIDs()throws{
        let text=try fixture();var root=try JSONSerialization.jsonObject(with:Data(text.utf8)) as! [String:Any]
        for type in ["pagemaps28","alignments28","versionchoices28","reliability28","searchleads28","searchattempts28"] {
            var bad=root;bad[type] = "TEST malformed";XCTAssertThrowsError(try ScholarStore.validate(String(data:JSONSerialization.data(withJSONObject:bad),encoding:.utf8)!))
            let rows=root[type] as! [[String:Any]];bad[type] = rows+rows;XCTAssertThrowsError(try ScholarStore.validate(String(data:JSONSerialization.data(withJSONObject:bad),encoding:.utf8)!))
        }
        root["meta"] = ["minimumReader":28];XCTAssertNoThrow(try ScholarStore.validate(String(data:JSONSerialization.data(withJSONObject:root),encoding:.utf8)!))
    }
}
