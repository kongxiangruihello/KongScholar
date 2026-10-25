import XCTest
import AppKit
import PDFKit
@testable import KongScholarCore

final class Research25Tests:XCTestCase {
    var temp:URL!
    override func setUpWithError() throws {temp=FileManager.default.temporaryDirectory.appendingPathComponent("KongScholar25Tests-"+UUID().uuidString);try FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)}
    override func tearDownWithError() throws {try FileManager.default.removeItem(at:temp)}
    func root(attachment:Bool=false) throws -> [String:Any] {
        var r:[String:Any]=["questions":[],"sources":[],"drafts":[],"lessons":[],"notes":[],"profile":["field":"TEST ONLY","method":"TEST ONLY","writing":"TEST ONLY","teaching":"TEST ONLY"],"meta":["minimumReader":25],"guidancedrafts":[],"timebudgets":[]]
        if attachment {let bytes=Data("TEST ONLY external draft, no real research".utf8),file=temp.appendingPathComponent("test-draft.txt");try bytes.write(to:file);r["guidancedrafts"]=[["id":"draft","title":"TEST ONLY draft","attachment":["name":file.lastPathComponent,"path":file.path,"bookmark":"","sha256":ScholarArchive.digest(bytes),"size":bytes.count]]]}
        return r
    }
    func text(_ r:[String:Any]) throws -> String {String(data:try JSONSerialization.data(withJSONObject:r,options:.sortedKeys),encoding:.utf8)!}
    func fixture(_ name:String,_ bytes:Data) throws {if let path=ProcessInfo.processInfo.environment["KONGSCHOLAR_QA_OUTPUT"] {let folder=URL(fileURLWithPath:path);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);try bytes.write(to:folder.appendingPathComponent(name))}}
    func testStoredAndDeflatedZipWithCRCAndLimits() throws {
        let archive=WordExport.archive(["test.txt":Data("TEST ONLY stored".utf8)]),reader=try BoundedZip(archive)
        XCTAssertEqual(String(data:try reader.read("test.txt"),encoding:.utf8),"TEST ONLY stored")
        let packed=Data(base64Encoded:"UEsDBBQAAAAIABCcWF1NI8EsGgAAABgAAAAIAAAAdGVzdC50eHQLcQ0OUfD384lUSElNy0ksSVV4smPts2ntAFBLAQIUAxQAAAAIABCcWF1NI8EsGgAAABgAAAAIAAAAAAAAAAAAAACAAQAAAAB0ZXN0LnR4dFBLBQYAAAAAAQABADYAAABAAAAAAAA=")!
        XCTAssertEqual(String(data:try BoundedZip(packed).read("test.txt"),encoding:.utf8),"TEST ONLY deflate 中文")
        XCTAssertThrowsError(try BoundedZip(packed,limit:10));XCTAssertThrowsError(try reader.read("test.txt",limit:3))
        var corrupt=archive;corrupt[38] ^= 1;XCTAssertThrowsError(try BoundedZip(corrupt).read("test.txt"))
    }
    func testZipRejectsTraversalSymlinksAndDuplicates() throws {
        XCTAssertThrowsError(try BoundedZip(WordExport.archive(["../escape":Data()])))
        XCTAssertThrowsError(try BoundedZip(WordExport.archive(["/absolute":Data()])))
        var zip=WordExport.archive(["file.txt":Data("TEST".utf8)])
        let p=try XCTUnwrap(zip.range(of:Data([0x50,0x4b,0x01,0x02]))?.lowerBound)
        // Central-directory Unix file mode: symlink.
        zip[p+38+2]=0xff;zip[p+38+3]=0xa1;XCTAssertThrowsError(try BoundedZip(zip))
        var duplicate=WordExport.archive(["one":Data(),"two":Data()]);let needle=Data("two".utf8)
        while let range=duplicate.range(of:needle){duplicate.replaceSubrange(range,with:Data("one".utf8))};XCTAssertThrowsError(try BoundedZip(duplicate))
    }
    func commentedWord() throws -> Data {
        let document="""
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:commentRangeStart w:id="1"/><w:r><w:t>士人的责任需要考察。</w:t></w:r></w:p><w:p><w:r><w:t>TEST ONLY 第二段锚点。</w:t></w:r><w:commentRangeEnd w:id="1"/><w:r><w:commentReference w:id="1"/></w:r></w:p><w:p><w:r><w:t>TEST ONLY 无批注段。</w:t></w:r></w:p></w:body></w:document>
        """
        let comments="""
        <w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="1" w:author="TEST REVIEWER" w:date="2026-10-24T00:00:00Z"><w:p><w:r><w:t>TEST ONLY 请补足论证。</w:t></w:r></w:p><w:p><w:r><w:t>这是合成验收意见。</w:t></w:r></w:p></w:comment><w:comment w:id="2" w:author="TEST ORPHAN"><w:p><w:r><w:t>TEST ONLY 待定位批注。</w:t></w:r></w:p></w:comment></w:comments>
        """
        var parts=try WordExport.parts(.init(title:"TEST ONLY 返回稿",chapters:[.init(title:"合成正文",body:"TEST",citations:[])]));parts["word/document.xml"]=document;parts["word/comments.xml"]=comments
        return WordExport.archive(parts.mapValues{Data($0.utf8)})
    }
    func testWordCommentsAnchorAndUnlocatedCommentsPreserved() throws {
        let bytes=try commentedWord(),result=try WordReview.read(bytes),rows=try XCTUnwrap(result["comments"] as? [[String:Any]])
        XCTAssertEqual(rows.count,2);XCTAssertEqual(rows[0]["author"] as? String,"TEST REVIEWER");XCTAssertTrue((rows[0]["anchor"] as? String ?? "").contains("第二段锚点"));XCTAssertEqual(rows[1]["anchor"] as? String,"");XCTAssertTrue((rows[0]["body"] as? String ?? "").contains("\n这是合成"))
        try fixture("TEST-returned-comments.docx",bytes)
    }
    func testWordRejectsEntitiesMalformedXMLAndHandlesNoComments() throws {
        let evil=WordExport.archive(["word/document.xml":Data("<!DOCTYPE x [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><x>&x;</x>".utf8)])
        XCTAssertThrowsError(try WordReview.read(evil));XCTAssertThrowsError(try WordReview.read(WordExport.archive(["word/document.xml":Data("<broken>".utf8)])))
        let ordinary=try WordExport.generate(.init(title:"TEST",chapters:[.init(title:"TEST",body:"TEST ONLY",citations:[])]));XCTAssertEqual((try WordReview.read(ordinary)["comments"] as? [[String:Any]])?.count,0)
    }
    func testWordRejectsExcessiveCommentRanges() throws {
        let starts=(0...2000).map{"<w:commentRangeStart w:id=\"\($0)\"/>"}.joined(),document="<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p>"+starts+"<w:r><w:t>TEST ONLY</w:t></w:r></w:p></w:body></w:document>"
        XCTAssertThrowsError(try WordReview.read(WordExport.archive(["word/document.xml":Data(document.utf8)])))
    }
    func makePDF() throws -> Data {
        let output=NSMutableData(),consumer=try XCTUnwrap(CGDataConsumer(data:output));var box=CGRect(x:0,y:0,width:612,height:792);let context=try XCTUnwrap(CGContext(consumer:consumer,mediaBox:&box,nil))
        for text in ["TEST ONLY PDF PAGE ONE scholar evidence","TEST ONLY PDF PAGE TWO teaching"] {context.beginPDFPage(nil);NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:context,flipped:false);(text as NSString).draw(at:NSPoint(x:40,y:680),withAttributes:[.font:NSFont.systemFont(ofSize:18),.foregroundColor:NSColor.black]);NSGraphicsContext.restoreGraphicsState();context.endPDFPage()};context.closePDF();return output as Data
    }
    func testPDFPhysicalPagesTextAndUnverifiedLayerKind() throws {
        let bytes=try makePDF(),index=try LocalPDFIndex.build(bytes:bytes),pages=try XCTUnwrap(index["pages"] as? [[String:Any]])
        XCTAssertEqual(pages.count,2);XCTAssertTrue((pages[1]["text"] as? String ?? "").contains("PAGE TWO"));XCTAssertEqual(pages[0]["textKind"] as? String,"PDF文字层（来源未核）");XCTAssertEqual(index["sha256"] as? String,ScholarArchive.digest(bytes));XCTAssertThrowsError(try LocalPDFIndex.build(bytes:Data("not a PDF".utf8)))
        try fixture("TEST-local-pages.pdf",bytes)
    }
    func testMigrationCopiesChosenAttachmentAndRehearsesIndependentStore() throws {
        let r=try root(attachment:true),original=try text(r),package=try MigrationPackage.generate(text:original,includeIDs:["draft"])
        let inspection=try MigrationPackage.inspect(package);XCTAssertEqual(inspection.items.count,1)
        let report=try MigrationPackage.rehearse(package,parent:temp),restored=try XCTUnwrap(report["text"] as? String),object=try JSONSerialization.jsonObject(with:Data(restored.utf8)) as! [String:Any],draft=(object["guidancedrafts"] as! [[String:Any]])[0],attachment=draft["attachment"] as! [String:Any]
        let path=attachment["path"] as! String;XCTAssertTrue(path.contains("KongScholar-恢复演练-"));XCTAssertTrue(FileManager.default.fileExists(atPath:path));XCTAssertEqual(attachment["sha256"] as? String,ScholarArchive.digest(try Data(contentsOf:URL(fileURLWithPath:path))));XCTAssertEqual(try String(contentsOf:temp.appendingPathComponent("test-draft.txt")),"TEST ONLY external draft, no real research");XCTAssertEqual(inspection.root as NSDictionary,r as NSDictionary)
        try fixture("TEST-migration-with-attachment.zip",package)
    }
    func testMigrationExclusionKeepsOriginalLinksAndReportsExcluded() throws {
        let r=try root(attachment:true),package=try MigrationPackage.generate(text:text(r),includeIDs:[]),report=try MigrationPackage.rehearse(package,parent:temp)
        XCTAssertEqual(report["attachments"] as? Int,0);XCTAssertEqual(report["excludedAttachments"] as? Int,1)
        let object=try JSONSerialization.jsonObject(with:Data((report["text"] as! String).utf8)) as! [String:Any];XCTAssertEqual(object["guidancedrafts"] as? NSArray,r["guidancedrafts"] as? NSArray)
    }
    func testChangedAndMissingAttachmentsAbortWithoutChangingSource() throws {
        let r=try root(attachment:true),source=try text(r);try Data("CHANGED TEST ONLY".utf8).write(to:temp.appendingPathComponent("test-draft.txt"))
        XCTAssertThrowsError(try MigrationPackage.generate(text:source,includeIDs:["draft"]));try FileManager.default.removeItem(at:temp.appendingPathComponent("test-draft.txt"));XCTAssertThrowsError(try MigrationPackage.generate(text:source,includeIDs:["draft"]));XCTAssertNoThrow(try MigrationPackage.generate(text:source,includeIDs:[]));XCTAssertThrowsError(try MigrationPackage.generate(text:source,includeIDs:["missing"]))
    }
    func testMigrationRejectsHashMismatchAndUnexpectedMembers() throws {
        let package=try MigrationPackage.generate(text:text(root()),includeIDs:[]),zip=try BoundedZip(package);var parts=try Dictionary(uniqueKeysWithValues:zip.members.map{($0.name,try zip.read($0.name))});parts["data.json"]=Data("{}".utf8);XCTAssertThrowsError(try MigrationPackage.inspect(WordExport.archive(parts)))
        parts["data.json"]=try zip.read("data.json");parts["unexpected.txt"]=Data("TEST".utf8);XCTAssertThrowsError(try MigrationPackage.inspect(WordExport.archive(parts)))
    }
    func testNewStorageVersionAndPDFPagesArePortableAndProtected() throws {
        var r=try root();r["pdfindexes"]=[["id":"pdf","title":"TEST ONLY","pages":[["page":1,"text":"TEST ONLY INDEXED CONTENT"]]]]
        let original=try text(r),store=try ScholarStore(directory:temp.appendingPathComponent("store"));try store.write(original)
        let index=try JSONSerialization.jsonObject(with:Data(contentsOf:store.dataURL)) as! [String:Any];XCTAssertEqual((index["_archiveStorage"] as? [String:Any])?["version"] as? Int,2);XCTAssertFalse(String(data:try Data(contentsOf:store.dataURL),encoding:.utf8)!.contains("INDEXED CONTENT"));XCTAssertEqual(try JSONSerialization.jsonObject(with:Data(XCTUnwrap(store.read()).utf8)) as? NSDictionary,r as NSDictionary)
        let backup=try XCTUnwrap(store.snapshotIfNeeded(force:true,label:"manual"));let restored=try ScholarStore(directory:temp.appendingPathComponent("restore"));try restored.write(store.backupText(named:backup.lastPathComponent));XCTAssertEqual(try restored.read(),try store.read())
    }
}
