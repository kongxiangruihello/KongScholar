import XCTest
@testable import KongScholarCore
final class Personal26Tests:XCTestCase {
    var temp:URL!
    override func setUpWithError() throws {temp=FileManager.default.temporaryDirectory.appendingPathComponent("KongScholar26Tests-"+UUID().uuidString);try FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)}
    override func tearDownWithError() throws {try? FileManager.default.removeItem(at:temp)}
    func testJournalRoundtripUpdateRemoveAndIsolation() throws {
        let v:[String:Any]=["key":"sources:../TEST","type":"sources","at":"2026-10-24","fields":[["title","TEST ONLY DRAFT"],["body","未提交合成草稿"]]]
        try EditingDrafts.save(v,root:temp);XCTAssertEqual(try EditingDrafts.list(root:temp).count,1);XCTAssertFalse(FileManager.default.fileExists(atPath:temp.appendingPathComponent("scholar-data.json").path))
        var next=v;next["fields"]=[["title","UPDATED TEST"]];try EditingDrafts.save(next,root:temp);XCTAssertEqual(try EditingDrafts.list(root:temp).count,1)
        let file=try XCTUnwrap(FileManager.default.contentsOfDirectory(at:temp.appendingPathComponent("editing-drafts"),includingPropertiesForKeys:nil).first);XCTAssertEqual((try FileManager.default.attributesOfItem(atPath:file.path)[.posixPermissions] as? NSNumber)?.intValue,0o600)
        try EditingDrafts.remove(key:"sources:../TEST",root:temp);XCTAssertTrue(try EditingDrafts.list(root:temp).isEmpty)
    }
    func testJournalRejectsOversizedAndMalformedPayload() throws {
        XCTAssertThrowsError(try EditingDrafts.save(["key":"x","type":"sources","at":"now","fields":[["bad"]]],root:temp))
        XCTAssertThrowsError(try EditingDrafts.save(["key":"x","type":"sources","at":"now","fields":[["body",String(repeating:"a",count:4*1024*1024)]]],root:temp))
        XCTAssertThrowsError(try EditingDrafts.remove(key:"",root:temp))
    }
    func testMovedAttachmentFoundByContentAndChangedCandidateRejected() throws {
        let bytes=Data("TEST ONLY attachment".utf8),folder=temp.appendingPathComponent("moved");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);let file=folder.appendingPathComponent("renamed.txt");try bytes.write(to:file)
        let link=AttachmentLink(key:"draft:a",kind:"attachment",path:temp.appendingPathComponent("missing.txt").path,sha256:ScholarArchive.digest(bytes))
        XCTAssertEqual(AttachmentHealth.inspect([link])[0]["state"] as? String,"待处理")
        let report=try AttachmentHealth.search([link],folder:folder),rows=try XCTUnwrap(report["candidates"] as? [[String:Any]]);XCTAssertEqual(rows.count,1);XCTAssertEqual(URL(fileURLWithPath:try XCTUnwrap(rows[0]["path"] as? String)).resolvingSymlinksInPath(),file.resolvingSymlinksInPath())
        try Data("CHANGED".utf8).write(to:file);XCTAssertThrowsError(try AttachmentHealth.verify(link,at:file));XCTAssertEqual((try AttachmentHealth.search([link],folder:folder)["candidates"] as? [[String:Any]])?.count,0)
    }
    func testRejectsSymlinkAndMissingIdentity() throws {
        let file=temp.appendingPathComponent("test.txt"),alias=temp.appendingPathComponent("alias.txt");let bytes=Data("TEST".utf8);try bytes.write(to:file);try FileManager.default.createSymbolicLink(at:alias,withDestinationURL:file)
        XCTAssertThrowsError(try AttachmentHealth.verify(.init(key:"a",kind:"attachment",path:file.path,sha256:ScholarArchive.digest(bytes)),at:alias))
        XCTAssertThrowsError(try AttachmentHealth.verify(.init(key:"a",kind:"attachment",path:file.path),at:file))
    }
    func testProjectLayoutInWordAndOptionalSections() throws {
        let json="""
        {"title":"TEST ONLY 交稿验收","chapters":[{"title":"第一章 合成文字","body":"本段仅用于验证排版预设。正文采用十四磅，双倍行距。[^ks-1]\\n\\n第二段验证中文、标点与连续页下注。","citations":[{"id":"ks-1","text":"合成作者：《合成文献》，测试版本，第3页。"}]}],"layout":{"font":"Songti SC","size":14,"lineSpacing":2,"marginTop":3,"marginBottom":3,"marginLeft":3,"marginRight":3,"footnoteSize":11,"titlePage":true,"author":"TEST ONLY 作者","abstract":"这是一段用于验证摘要输出与中文字体的合成文字。","keywords":"合成验收；交稿预设","appendix":"附录内容仅用于验证可选章节。"}}
        """
        let request=try JSONDecoder().decode(WordExportRequest.self,from:Data(json.utf8)),parts=try WordExport.parts(request),doc=parts["word/document.xml"]!,styles=parts["word/styles.xml"]!
        XCTAssertTrue(styles.contains("w:sz w:val=\"28\""));XCTAssertTrue(styles.contains("w:line=\"480\""));XCTAssertTrue(styles.contains("w:sz w:val=\"22\""));XCTAssertTrue(doc.contains("w:top=\"1701\""));XCTAssertTrue(doc.contains("TEST ONLY 作者"));XCTAssertTrue(doc.contains("摘要"));XCTAssertTrue(doc.contains("附录内容"));XCTAssertTrue(doc.contains("footnoteReference w:id=\"1\""))
        if let path=ProcessInfo.processInfo.environment["KONGSCHOLAR_QA_OUTPUT"] {try FileManager.default.createDirectory(atPath:path,withIntermediateDirectories:true);try WordExport.generate(request).write(to:URL(fileURLWithPath:path).appendingPathComponent("TEST-2.6-layout.docx"))}
        var noSections=request;noSections.layout=WordLayout();let simple=try WordExport.parts(noSections)["word/document.xml"]!;XCTAssertFalse(simple.contains("摘要"));XCTAssertFalse(simple.contains("TEST ONLY 作者"))
        var invalid=request;invalid.layout?.marginTop=0;XCTAssertThrowsError(try WordExport.generate(invalid));invalid=request;invalid.layout?.font="<bad>";XCTAssertThrowsError(try WordExport.generate(invalid))
    }
    func testReader26ArchiveVersionAndPortableMeta() throws {
        let root:[String:Any]=["profile":["field":"TEST","method":"TEST","writing":"TEST","teaching":"TEST"],"questions":[],"sources":[],"drafts":[],"lessons":[],"notes":[],"evidenceimages":[],"meta":["minimumReader":26,"workspaces26":[["id":"test","title":"TEST","pages":["home"]]]]]
        let text=String(data:try JSONSerialization.data(withJSONObject:root),encoding:.utf8)!,store=try ScholarStore(directory:temp);try store.write(text)
        let index=try JSONSerialization.jsonObject(with:Data(contentsOf:store.dataURL)) as! [String:Any];XCTAssertEqual((index["_archiveStorage"] as? [String:Any])?["version"] as? Int,3)
        XCTAssertEqual(try JSONSerialization.jsonObject(with:Data(XCTUnwrap(store.read()).utf8)) as? NSDictionary,root as NSDictionary)
        XCTAssertThrowsError(try ScholarStore.validate(String(data:try Data(contentsOf:store.dataURL),encoding:.utf8)!))
    }
}
