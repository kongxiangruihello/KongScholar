import XCTest
import AppKit
@testable import KongScholarCore

final class Studio31Tests:XCTestCase {
    func png()throws->Data{let image=NSImage(size:NSSize(width:640,height:240));image.lockFocus();NSColor.white.setFill();NSRect(x:0,y:0,width:640,height:240).fill();NSColor.darkGray.setStroke();let border=NSBezierPath(rect:NSRect(x:5,y:5,width:630,height:230));border.lineWidth=4;border.stroke();("TEST ONLY 3.1 IMAGE" as NSString).draw(at:NSPoint(x:30,y:90),withAttributes:[.font:NSFont.systemFont(ofSize:38),.foregroundColor:NSColor.black]);image.unlockFocus();return try EvidenceImage.png(image,crop:CGRect(x:0,y:0,width:1,height:1))}
    func request()throws->WordExportRequest{
        let figure=WordBlock31(marker:"[[KS31-FIG:TEST-FIG]]",kind:"image",title:"图1 合成影像",caption:"TEST ONLY 用于核对图像嵌入",source:"TEST ONLY 合成资料",png:try png().base64EncodedString(),widthCM:12)
        let table=WordBlock31(marker:"[[KS31-TABLE:TEST-TABLE]]",kind:"table",title:"表1 合成比较",caption:"TEST ONLY 表格说明",source:"TEST ONLY 数据来源",rows:[["人物","称谓","依据"],["合成人物甲","士人","TEST ONLY 材料一"],["合成人物乙","学人","TEST ONLY 材料二"]])
        return WordExportRequest(title:"TEST ONLY 图表与索引验收",chapters:[WordChapter(title:"TEST ONLY 正文章节",body:"林乐知这一名称仅用作索引匹配示例。[^ks-test]\n\n"+figure.marker+"\n\n"+table.marker+"\n\n第二段仍可检索林乐知。",citations:[WordCitation(id:"ks-test",text:"TEST ONLY 合成来源，第1页。")],blocks31:[figure,table],indexMarks31:[WordIndexMark31(offset:0,text:"林乐知",term:"林乐知")])])
    }
    func testEmbeddedImageEditableTableFootnoteAndIndexFieldsAreInsideActualWord()throws{
        let r=try request(),bytes=try WordExport.generate(r),z=try BoundedZip(bytes),xml=String(data:try z.read("word/document.xml"),encoding:.utf8)!,rels=String(data:try z.read("word/_rels/document.xml.rels"),encoding:.utf8)!
        XCTAssertTrue(xml.contains("<w:drawing>"));XCTAssertTrue(xml.contains("<w:tbl>"));XCTAssertTrue(xml.contains("<w:tblHeader/>"));XCTAssertTrue(xml.contains("D9D9D9"));XCTAssertTrue(xml.contains("<w:footnoteReference"));XCTAssertTrue(xml.contains(" XE &quot;林乐知&quot; "));XCTAssertTrue(xml.contains(" INDEX "));XCTAssertFalse(xml.contains("[[KS31-"));XCTAssertFalse(xml.contains("[[KSI31:"));XCTAssertTrue(rels.contains("media/figure-1.png"))
        XCTAssertEqual(try z.read("word/media/figure-1.png"),Data(base64Encoded:r.chapters[0].blocks31![0].png!))
        let report=try WordProof30.inspect(r);XCTAssertEqual(report["sha256"] as? String,ScholarArchive.digest(bytes));let items=report["items"] as! [[String:Any]];XCTAssertEqual(items.first{$0["name"] as? String=="图像与表格"}?["present"] as? Bool,true)
        let package=try StageExport.generate(StageExportRequest(title:"TEST ONLY",files:[StageTextFile(name:"TEST.md",text:"TEST ONLY")],manuscript:r));let stage=try BoundedZip(package),word=try BoundedZip(stage.read("02-正文.docx"));XCTAssertTrue(word.members.contains{$0.name=="word/media/figure-1.png"})
        if let dir=ProcessInfo.processInfo.environment["KONGSCHOLAR_QA_OUTPUT"]{let folder=URL(fileURLWithPath:dir);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);try bytes.write(to:folder.appendingPathComponent("TEST-3.1-图表索引.docx"));try png().write(to:folder.appendingPathComponent("TEST-3.1-image.png"))}
    }
    func testInvalidImageTableMarkersAndOversizeWidthFailBeforeExport()throws{
        var r=try request();r.chapters[0].blocks31![0].png=Data("TEST ONLY NOT PNG".utf8).base64EncodedString();XCTAssertThrowsError(try WordExport.generate(r))
        r=try request();r.chapters[0].blocks31![1].rows=[["A","B"],["C"]];XCTAssertThrowsError(try WordExport.generate(r))
        r=try request();r.chapters[0].blocks31![0].widthCM=16;XCTAssertThrowsError(try WordExport.generate(r))
        r=try request();r.chapters[0].body += "\n[[KS31-FIG:missing]]";XCTAssertThrowsError(try WordExport.generate(r))
        r=try request();r.chapters[0].body=r.chapters[0].body.replacingOccurrences(of:"\n\n[[KS31-FIG:",with:"inline [[KS31-FIG:");XCTAssertThrowsError(try WordExport.generate(r))
    }
    func testRepeatedImageGetsDistinctRelationshipsAndIndexRangeValidation()throws{
        var r=try request();r.chapters[0].body += "\n[[KS31-FIG:TEST-FIG]]";let z=try BoundedZip(WordExport.generate(r));XCTAssertTrue(z.members.contains{$0.name=="word/media/figure-3.png"})
        r.chapters[0].indexMarks31=[WordIndexMark31(offset:0,text:"并非正文原文",term:"TEST")];XCTAssertThrowsError(try WordExport.generate(r))
        r.chapters[0].indexMarks31=[WordIndexMark31(offset:0,text:"林乐知",term:"bad\"field")];XCTAssertThrowsError(try WordExport.generate(r))
    }
    func modernParts(parent:String="00000001")->[String:Data]{
        let doc="<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:commentRangeStart w:id=\"0\"/><w:r><w:t>TEST ONLY 锚点</w:t></w:r><w:commentRangeEnd w:id=\"0\"/></w:p></w:body></w:document>"
        let comments="<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:comment w:id=\"0\" w:author=\"TEST Reviewer\"><w:p w14:paraId=\"11111111\"><w:r><w:t>TEST FIRST PARA</w:t></w:r></w:p><w:p w14:paraId=\"00000001\"><w:r><w:t>TEST ROOT</w:t></w:r></w:p></w:comment><w:comment w:id=\"1\" w:author=\"TEST Reply\"><w:p w14:paraId=\"00000002\"><w:r><w:t>TEST REPLY</w:t></w:r></w:p></w:comment></w:comments>"
        let ext="<w15:commentsEx xmlns:w15=\"http://schemas.microsoft.com/office/word/2012/wordml\"><w15:commentEx w15:paraId=\"00000001\" w15:done=\"1\"/><w15:commentEx w15:paraId=\"00000002\" w15:paraIdParent=\"\(parent)\"/></w15:commentsEx>"
        let ids="<c:commentsIds xmlns:c=\"http://schemas.microsoft.com/office/word/2016/wordml/cid\"><c:commentId c:paraId=\"00000001\" c:durableId=\"00000010\"/><c:commentId c:paraId=\"00000002\" c:durableId=\"00000020\"/></c:commentsIds>"
        let cex="<c:commentsExtensible xmlns:c=\"http://schemas.microsoft.com/office/word/2018/wordml/cex\"><c:commentExtensible c:durableId=\"00000010\" c:dateUtc=\"2026-10-25T01:00:00Z\"/></c:commentsExtensible>"
        return ["word/document.xml":Data(doc.utf8),"word/comments.xml":Data(comments.utf8),"word/commentsExtended.xml":Data(ext.utf8),"word/commentsIds.xml":Data(ids.utf8),"word/commentsExtensible.xml":Data(cex.utf8)]
    }
    func testModernReplyUsesLastParagraphIDRootAnchorDurableIDAndResolvedState()throws{
        let report=try WordReview.read(WordExport.archive(modernParts())),rows=report["comments"] as! [[String:Any]]
        XCTAssertEqual(rows.count,2);XCTAssertEqual(rows[1]["parentID31"] as? String,"0");XCTAssertEqual(rows[1]["threadID31"] as? String,"0");XCTAssertEqual(rows[1]["anchor"] as? String,"TEST ONLY 锚点");XCTAssertEqual(rows[0]["done31"] as? Bool,true);XCTAssertEqual(rows[1]["done31"] as? Bool,true);XCTAssertEqual(rows[1]["durableID31"] as? String,"00000020");XCTAssertEqual(rows[0]["dateUTC31"] as? String,"2026-10-25T01:00:00Z")
    }
    func testModernUnknownParentWarnsAndMalformedOrCyclicExtensionsReject()throws{
        let unknown=try WordReview.read(WordExport.archive(modernParts(parent:"DEADBEEF")));XCTAssertFalse((unknown["warnings31"] as! [String]).isEmpty)
        var parts=modernParts();parts["word/commentsExtended.xml"]=Data("<!DOCTYPE bad [<!ENTITY x SYSTEM 'file:///TEST'>]><comments/>".utf8);XCTAssertThrowsError(try WordReview.read(WordExport.archive(parts)))
        parts=modernParts(parent:"00000002");XCTAssertThrowsError(try WordReview.read(WordExport.archive(parts)))
        parts=modernParts();parts.removeValue(forKey:"word/commentsExtended.xml");XCTAssertEqual((try WordReview.read(WordExport.archive(parts))["comments"] as? [Any])?.count,2)
    }
    func testIndependentWindowDraftsSurviveRestartAndProtectCorruptOriginal()throws{
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("Studio31Draft-"+UUID().uuidString);defer{try? FileManager.default.removeItem(at:dir)}
        let key=UUID().uuidString,row=WindowDraft31(key:key,chapterID:"TEST chapter",title:"TEST ONLY",body:"TEST ONLY UNSUBMITTED",basis:"TEST BASE",at:"2026-10-25T01:00:00Z")
        try WindowDrafts31.save(row,root:dir);XCTAssertEqual(try WindowDrafts31.list(root:dir).first?.body,row.body)
        let file=dir.appendingPathComponent("window-drafts31/"+key+".json"),bad=Data("TEST ONLY DAMAGED".utf8);try bad.write(to:file);XCTAssertThrowsError(try WindowDrafts31.save(row,root:dir));XCTAssertEqual(try Data(contentsOf:file),bad)
        var invalid=row;invalid.key="../../TEST";XCTAssertThrowsError(try WindowDrafts31.save(invalid,root:dir))
    }
    func testStorageEightPreservesFixedMediaAndIndexReviewBasis()throws{
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("Studio31Store-"+UUID().uuidString);defer{try? FileManager.default.removeItem(at:dir)};let store=try ScholarStore(directory:dir)
        let value:[String:Any]=["profile":["field":"TEST ONLY","method":"TEST","writing":"TEST","teaching":"TEST"],"questions":[],"sources":[],"drafts":[],"lessons":[],"notes":[],"meta":["minimumReader":31],"researchsets31":[["id":"set","title":"TEST ONLY"]],"tables31":[["id":"table","title":"TEST ONLY"]],"indexentries31":[["id":"idx","title":"TEST ONLY","reviewBasis31":"TEST ONLY FIXED BASIS"]],"deliveries":[["id":"d","title":"TEST ONLY","exportBlocks31":[["png":"TEST ONLY SNAPSHOT"]]]]]
        let bytes=try JSONSerialization.data(withJSONObject:value);try store.write(String(data:bytes,encoding:.utf8)!);let index=try JSONSerialization.jsonObject(with:Data(contentsOf:store.dataURL)) as! [String:Any];XCTAssertEqual((index["_archiveStorage"] as! [String:Any])["version"] as? Int,8);XCTAssertEqual(try JSONSerialization.jsonObject(with:Data(store.read()!.utf8)) as? NSDictionary,value as NSDictionary)
    }
}
