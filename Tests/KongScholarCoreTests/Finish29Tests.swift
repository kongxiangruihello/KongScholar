import XCTest
@testable import KongScholarCore
final class Finish29Tests:XCTestCase {
    let token="KS29-0123456789ABCDEF0123456789ABCDEF"
    func testDeliveryTokenRoundTripWithAndWithoutComments()throws{
        let request=WordExportRequest(title:"TEST ONLY Export",chapters:[WordChapter(title:"TEST ONLY Chapter",body:"TEST ONLY manuscript [^ks-1]",citations:[WordCitation(id:"ks-1",text:"TEST ONLY footnote")])],deliveryToken29:token)
        var parts=try WordExport.parts(request);XCTAssertTrue(parts["word/document.xml"]!.contains("稿次标识："+token));XCTAssertTrue(parts["word/footnotes.xml"]!.contains("TEST ONLY footnote"))
        let plain=try WordReview.read(WordExport.generate(request));XCTAssertEqual(plain["deliveryTokens29"] as? [String],[token]);XCTAssertEqual((plain["comments"] as? [Any])?.count,0)
        parts["word/comments.xml"]="<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:comment w:id=\"0\" w:author=\"TEST\"><w:p><w:r><w:t>TEST COMMENT</w:t></w:r></w:p></w:comment></w:comments>"
        let commented=try WordReview.read(WordExport.archive(parts.mapValues{Data($0.utf8)}));XCTAssertEqual(commented["deliveryTokens29"] as? [String],[token]);XCTAssertEqual((commented["comments"] as? [[String:Any]])?.first?["body"] as? String,"TEST COMMENT")
    }
    func testLegacyWordRemainsUnmarkedAndMalformedTokenIsRejected()throws{
        var request=WordExportRequest(title:"TEST ONLY",chapters:[WordChapter(title:"TEST",body:"TEST",citations:[])])
        let result=try WordReview.read(WordExport.generate(request));XCTAssertEqual(result["deliveryTokens29"] as? [String],[])
        request.deliveryToken29="TEST INVALID TOKEN";XCTAssertThrowsError(try WordExport.generate(request))
    }
    func testDeletedMarkersAndOrdinaryMentionAreNotTreatedAsDeliveryIdentity()throws{
        let xml="<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:del><w:r><w:t>稿次标识：\(token)</w:t></w:r></w:del></w:p><w:p><w:r><w:t>TEST quote 稿次标识：\(token)</w:t></w:r></w:p></w:body></w:document>"
        let result=try WordReview.read(WordExport.archive(["word/document.xml":Data(xml.utf8)]));XCTAssertEqual(result["deliveryTokens29"] as? [String],[])
    }
    func testAmbiguousMarkerBombIsBounded()throws{
        let text=(0..<51).map{i in "<w:p><w:r><w:t>稿次标识：KS29-"+String(format:"%032X",i)+"</w:t></w:r></w:p>"}.joined()
        let xml="<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>\(text)</w:body></w:document>"
        XCTAssertThrowsError(try WordReview.read(WordExport.archive(["word/document.xml":Data(xml.utf8)])))
    }
    func testArchiveSixAndWorkingBackupPreserveFixedReferencesAndPublicAgenda()throws{
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("Finish29-"+UUID().uuidString);defer{try? FileManager.default.removeItem(at:dir)}
        let old:[String:Any]=["title":"TEST OLD","at":"2026-10-25","writing":["body":"TEST FIXED MANUSCRIPT","citations":[]]]
        var root:[String:Any]=["profile":["field":"TEST ONLY","method":"TEST","writing":"TEST","teaching":"TEST"],"questions":[],"sources":[],"drafts":[],"lessons":[],"notes":[],"evidenceimages":[],"meta":["minimumReader":29],"revisionrounds29":[["id":"revision","title":"TEST ONLY Round","reference29":old]],"teachingchecks29":[["id":"teaching","title":"TEST ONLY Check","snapshot29":"TEST SOURCE SNAPSHOT"]],"meetingplans29":[["id":"meeting","title":"TEST ONLY Agenda","agendaBasis29":"TEST PUBLIC ADVICE"]]]
        for type in ["questionlinks29","countercases29","handoffchecks29","figures29"]{root[type] = [["id":type,"title":"TEST ONLY "+type]]}
        let bytes=try JSONSerialization.data(withJSONObject:root,options:.sortedKeys),text=String(data:bytes,encoding:.utf8)!,store=try ScholarStore(directory:dir);store.releaseVersion="2.9.0";try store.write(text)
        let index=try JSONSerialization.jsonObject(with:Data(contentsOf:store.dataURL)) as! [String:Any],storage=index["_archiveStorage"] as! [String:Any];XCTAssertEqual(storage["version"] as? Int,6);XCTAssertGreaterThanOrEqual((storage["pointers"] as? [Any])!.count,3)
        let full=try XCTUnwrap(store.read());XCTAssertEqual(full,text);let working=try WorkingBackup.inspect(WorkingBackup.generate(text:full,drafts:nil));XCTAssertEqual(working.text,full)
        let health=StartupHealth.inspect(store),checks=health["checks"] as! [[String:Any]];XCTAssertEqual(checks.first{$0["title"] as? String=="资料索引"}?["state"] as? String,"通过")
        for type in ["questionlinks29","countercases29","revisionrounds29","handoffchecks29","figures29","teachingchecks29","meetingplans29"]{var invalid=root;invalid[type]="INVALID";XCTAssertThrowsError(try ScholarStore.validate(String(data:JSONSerialization.data(withJSONObject:invalid),encoding:.utf8)!))}
    }
}
