import XCTest
@testable import KongScholarCore

final class StageExportTests: XCTestCase {
    func request(_ names: [String] = ["01-目录.md", "02-正文.md"]) -> StageExportRequest {
        .init(title: "合成测试阶段稿", files: names.map { .init(name: $0, text: "测试内容") }, manuscript: .init(title: "阶段稿", chapters: [.init(title: "1 测试章", body: "第一章[^ks-1]", citations: [.init(id: "ks-1", text: "仅供验收的测试引注")]), .init(title: "1.1 测试节", body: "第二节[^ks-1]", citations: [.init(id: "ks-1", text: "第二节测试引注")])]))
    }
    func testPackageAndTrueFootnotes() throws {
        let r = request(), parts = try StageExport.parts(r)
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(String(data: parts["01-目录.md"]!, encoding: .utf8), "测试内容")
        let word = try WordExport.parts(r.manuscript)
        XCTAssertTrue(word["word/footnotes.xml"]!.contains("第二节测试引注"))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("KongScholar21-StageQA")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let zip = dir.appendingPathComponent("阶段成果包.zip")
        try StageExport.generate(r).write(to: zip)
        try parts["02-正文.docx"]!.write(to: dir.appendingPathComponent("阶段正文.docx"))
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip"); process.arguments = ["-t", zip.path]
        process.standardOutput = Pipe(); process.standardError = Pipe(); try process.run(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }
    func testRejectPathsDuplicatesAndOversize() throws {
        for name in ["../x.md", "/x.md", "x\\y.md", "x:y.md", ".hidden.md", "x\n.md", "02-正文.docx"] { XCTAssertThrowsError(try StageExport.generate(request([name]))) }
        XCTAssertThrowsError(try StageExport.generate(request(["x.md", "x.md"])))
        var r = request(); r.files[0].text = String(repeating: "a", count: ScholarStore.limit + 1)
        XCTAssertThrowsError(try StageExport.generate(r))
    }
    func testPlanningPackageHasNoManuscriptWhenEmpty() throws {
        var r = request(); r.manuscript.chapters = []
        XCTAssertNil(try StageExport.parts(r)["02-正文.docx"])
    }
}
