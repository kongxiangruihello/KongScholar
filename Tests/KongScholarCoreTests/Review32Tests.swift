import XCTest
@testable import KongScholarCore

final class Review32Tests:XCTestCase {
    let ns="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    func document(_ body:String)->Data{Data("<w:document xmlns:w=\"\(ns)\"><w:body>\(body)</w:body></w:document>".utf8)}
    func testTextInsertionsAndDeletionsReconstructLocalParagraphWithoutChangingFile()throws{
        let doc=document("<w:p><w:r><w:t>TEST 起句</w:t></w:r><w:del w:id=\"7\" w:author=\"TEST Reviewer\" w:date=\"2026-10-25T01:00:00Z\"><w:r><w:delText>旧说</w:delText></w:r></w:del><w:ins w:id=\"8\" w:author=\"TEST Reviewer\"><w:r><w:t>新说</w:t><w:tab/><w:t>补充</w:t><w:br/><w:t>末句</w:t></w:r></w:ins><w:r><w:t>。</w:t></w:r></w:p>"),copy=doc
        let report=try WordRevisions32.read(doc),rows=report["revisions32"] as! [[String:Any]]
        XCTAssertEqual(rows.count,2);XCTAssertEqual(rows[0]["kind32"] as? String,"删除");XCTAssertEqual(rows[1]["text"] as? String,"新说\t补充\n末句");XCTAssertEqual(rows[0]["before32"] as? String,"TEST 起句旧说。");XCTAssertEqual(rows[1]["after32"] as? String,"TEST 起句新说\t补充\n末句。");XCTAssertEqual(rows[0]["wordID32"] as? String,"7");XCTAssertEqual(rows[0]["author"] as? String,"TEST Reviewer");XCTAssertEqual(rows[0]["requiresWord32"] as? Bool,false);XCTAssertEqual(doc,copy)
        let file=WordExport.archive(["word/document.xml":doc]),combined=try WordReview.read(file);XCTAssertEqual((combined["comments"] as? [Any])?.count,0);XCTAssertEqual((combined["revisions32"] as? [Any])?.count,2)
    }
    func testUnsupportedFormatTableParagraphMarkAndMovesAreReported()throws{
        let doc=document("<w:p><w:pPr><w:rPr><w:ins w:id=\"3\"/></w:rPr><w:pPrChange/></w:pPr><w:r><w:rPr><w:rPrChange/></w:rPr><w:t>TEST</w:t></w:r><w:moveFrom><w:r><w:t>MOVE</w:t></w:r></w:moveFrom></w:p><w:tbl><w:tr><w:tc><w:p><w:ins w:id=\"9\"><w:r><w:t>TABLE</w:t></w:r></w:ins></w:p></w:tc></w:tr></w:tbl>")
        let r=try WordRevisions32.read(doc),u=r["revisionUnsupported32"] as! [String:Int];XCTAssertEqual((r["revisions32"] as! [Any]).count,0);XCTAssertEqual(u["rPrChange"],1);XCTAssertEqual(u["moveFrom"],1);XCTAssertEqual(u["ins（非可解析的正文文字）"],2)
    }
    func testDrawingAndFootnoteInsideRevisionRequireWordAndTextboxDoesNotCorruptOuterParagraph()throws{
        let doc=document("<w:p><w:r><w:t>TEST 外段</w:t><w:drawing><w:txbxContent><w:p><w:r><w:t>TEXTBOX</w:t></w:r></w:p></w:txbxContent></w:drawing></w:r><w:ins w:id=\"2\"><w:r><w:t>增加</w:t><w:footnoteReference w:id=\"1\"/></w:r></w:ins></w:p>")
        let r=try WordRevisions32.read(doc),rows=r["revisions32"] as! [[String:Any]];XCTAssertEqual(rows.count,1);XCTAssertEqual(rows[0]["requiresWord32"] as? Bool,true);XCTAssertEqual(rows[0]["after32"] as? String,"TEST 外段增加")
    }
    func testForeignNamespaceDoesNotBecomeRevisionAndStrictNamespaceWorks()throws{
        let fake=Data("<x:document xmlns:x=\"urn:TEST\"><x:body><x:p><x:ins><x:r><x:t>TEST</x:t></x:r></x:ins></x:p></x:body></x:document>".utf8);XCTAssertEqual((try WordRevisions32.read(fake)["revisions32"] as! [Any]).count,0)
        let strict=String(data:document("<w:p><w:ins w:id=\"1\"><w:r><w:t>TEST</w:t></w:r></w:ins></w:p>"),encoding:.utf8)!.replacingOccurrences(of:ns,with:"http://purl.oclc.org/ooxml/wordprocessingml/main");XCTAssertEqual((try WordRevisions32.read(Data(strict.utf8))["revisions32"] as! [Any]).count,1)
    }
    func testMalformedEntitiesAndRevisionBoundsReject()throws{
        XCTAssertThrowsError(try WordRevisions32.read(Data("<!DOCTYPE bad [<!ENTITY x SYSTEM 'file:///TEST'>]><bad/>".utf8)));XCTAssertThrowsError(try WordRevisions32.read(Data("<w:document>".utf8)))
        let row="<w:ins w:id=\"1\"><w:r><w:t>TEST</w:t></w:r></w:ins>";XCTAssertThrowsError(try WordRevisions32.read(document("<w:p>"+String(repeating:row,count:2001)+"</w:p>")))
    }
    func testOCRDictionaryRejectsOversizeDuplicatesAndBlankTerms()throws{
        XCTAssertEqual(try EvidenceImage.validateWords32(["林樂知","萬國公報"]),["林樂知","萬國公報"]);XCTAssertThrowsError(try EvidenceImage.validateWords32(["TEST","TEST"]));XCTAssertThrowsError(try EvidenceImage.validateWords32(["\n"]));XCTAssertThrowsError(try EvidenceImage.validateWords32([String(repeating:"字",count:81)]));XCTAssertThrowsError(try EvidenceImage.validateWords32((0...500).map{"TEST-\($0)"}))
    }
    func testArchiveNinePreservesReplyBasesHistoryAndPerQuoteLayerSnapshot()throws{
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("TEST-Review32-"+UUID().uuidString);defer{try? FileManager.default.removeItem(at:dir)};let store=try ScholarStore(directory:dir)
        let value:[String:Any]=["profile":["field":"TEST","method":"TEST","writing":"TEST","teaching":"TEST"],"questions":[],"sources":[],"drafts":[],"lessons":[],"notes":[],"meta":["minimumReader":32],"replies32":[["id":"reply","title":"TEST","snapshot32":["reply":"TEST"],"basis32":"TEST BASIS","history32":[["body":"TEST OLD"]]]],"ocrterms32":[["id":"term","title":"TEST"]],"editionmaps32":[["id":"pages","title":"TEST","pairs32":"1 | 2"]],"chapters":[["id":"ch","title":"TEST","writing":["body":"TEST[^ks-1]","citations":[["id":"ks-1","layer32":["key":"original","reason":"TEST"],"sourceSnapshot32":["body":"TEST ORIGINAL"]]]]]]]
        let raw=try JSONSerialization.data(withJSONObject:value);try store.write(String(data:raw,encoding:.utf8)!);let index=try JSONSerialization.jsonObject(with:Data(contentsOf:store.dataURL)) as! [String:Any];XCTAssertEqual((index["_archiveStorage"] as! [String:Any])["version"] as? Int,9);XCTAssertEqual(try JSONSerialization.jsonObject(with:Data(store.read()!.utf8)) as? NSDictionary,value as NSDictionary)
    }
}
