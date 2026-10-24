import XCTest
@testable import KongScholarCore

final class WordExportTests: XCTestCase {
    func testTrueFootnotesAndEscaping() throws {
        let payload = WordExportRequest(title: "何以为士", chapters: [WordChapter(title: "知识与责任", body: "正文 & <文本>[^ks-1]\n第二段[^ks-1]", citations: [WordCitation(id: "ks-1", text: "作者：《篇名》，第 3 页。")])])
        let parts = try WordExport.parts(payload)
        XCTAssertTrue(parts["word/document.xml"]!.contains("&amp; &lt;文本&gt;"))
        XCTAssertTrue(parts["word/document.xml"]!.contains("footnoteReference w:id=\"1\""))
        XCTAssertTrue(parts["word/document.xml"]!.contains("footnoteReference w:id=\"2\""))
        XCTAssertTrue(parts["word/footnotes.xml"]!.contains("作者：《篇名》"))
        XCTAssertTrue(parts["word/footnotes.xml"]!.contains("w:id=\"-1\""))
        XCTAssertTrue(parts["word/footnotes.xml"]!.contains("w:id=\"0\""))
        XCTAssertTrue(parts["word/document.xml"]!.contains("w:val=\"pageBottom\""))
        XCTAssertTrue(parts["word/_rels/document.xml.rels"]!.contains("Target=\"footnotes.xml\""))
    }
    func testChaptersUseGlobalNumberingAndShowMissingNotes() throws {
        let chapters = [WordChapter(title: "第一章", body: "甲[^ks-1]", citations: [.init(id: "ks-1", text: "甲注")]), WordChapter(title: "第二章", body: "乙[^ks-1] 丙[^ks-missing]", citations: [.init(id: "ks-1", text: "乙注")])]
        let parts = try WordExport.parts(.init(title: "文稿", chapters: chapters))
        XCTAssertTrue(parts["word/document.xml"]!.contains("footnoteReference w:id=\"2\""))
        XCTAssertTrue(parts["word/document.xml"]!.contains("【缺失脚注 ks-missing】"))
        XCTAssertTrue(parts["word/document.xml"]!.contains("pageBreakBefore"))
        XCTAssertThrowsError(try WordExport.parts(.init(title: "", chapters: chapters)))
        XCTAssertThrowsError(try WordExport.parts(.init(title: "t", chapters: [.init(title: "c", body: "", citations: [.init(id: "bad", text: "x")])])))
    }
    func testArchiveIntegrityAndQAOutput() throws {
        let text = (1...24).map { "第\($0)段：本段用于验证中文正文与页下注的分页效果。材料中的知识主张、身份语言与实践变化需要分别考察，不能仅凭时间先后推定影响关系。" }.joined(separator: "\n\n")
        let payload = WordExportRequest(title: "何以为士写作功能验证", chapters: [.init(title: "第一章 知识与责任", body: "本文稿用于检验正文和页下注的实际显示。第一条引注[^ks-1]与第二条引注[^ks-2]。\n\n" + text, citations: [.init(id: "ks-1", text: "测试作者：《功能验证书籍》，模拟版本，1890（测试），印刷页码三叶正面。"), .init(id: "ks-2", text: "测试作者：《功能验证文章》，《模拟刊物》1891（测试），第一卷，印刷页码五。")])])
        let bytes = try WordExport.generate(payload)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("KongScholar14-WordQA")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("Word导出验证.docx"); try bytes.write(to: file)
        let p = Process();p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip");p.arguments = ["-t", file.path];let pipe = Pipe();p.standardOutput = pipe;p.standardError = pipe;try p.run();p.waitUntilExit();XCTAssertEqual(p.terminationStatus, 0)
    }
}
