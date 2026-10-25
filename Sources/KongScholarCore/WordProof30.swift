import Foundation

public enum WordProof30 {
    public static func inspect(_ request: WordExportRequest) throws -> [String: Any] {
        let parts = try WordExport.parts(request), output = try WordExport.generate(request)
        let document = parts["word/document.xml"] ?? "", notes = parts["word/footnotes.xml"] ?? "", layout = request.layout ?? WordLayout()
        var items = [[String: Any]]()
        func item(_ name: String, _ present: Bool, _ detail: String) { items.append(["name": name, "present": present, "detail": detail]) }
        func contains(_ text: String?) -> Bool { guard let s = text, !s.isEmpty else { return false }; return document.contains(WordExport.xml(s)) }
        item("正文与章节", !request.chapters.isEmpty, "文件写出\(request.chapters.count)个章/节；请人工核对目录顺序与正文。")
        item("作者信息", layout.titlePage == true && contains(layout.author), layout.titlePage != true ? "未启用扉页，作者栏不会输出。" : (layout.author?.isEmpty != false ? "扉页作者栏为空。" : "扉页已写出作者栏。"))
        item("摘要", contains(layout.abstract?.components(separatedBy: "\n").first), layout.abstract?.isEmpty != false ? "本次未设置摘要。" : "摘要已写入文件。")
        item("关键词", contains(layout.keywords), layout.keywords?.isEmpty != false ? "本次未设置关键词。" : "关键词已写入文件。")
        item("参考文献", request.chapters.contains { $0.title == "参考文献" && !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "按实际章节内容检查；空白或待补条目仍须人工处理。")
        item("附录", contains(layout.appendix?.components(separatedBy: "\n").first), layout.appendix?.isEmpty != false ? "本次未设置附录。" : "附录已写入文件。")
        let count = document.components(separatedBy: "<w:footnoteReference ").count - 1
        item("页下注", count > 0 && notes.contains("<w:footnote w:id=\"1\""), "实际写出\(count)处脚注引用；连续编号，最终落页由排版软件决定。")
        let images=document.components(separatedBy:"<w:drawing>").count-1,tables=document.components(separatedBy:"<w:tbl>").count-1
        item("图像与表格", images+tables>0, "实际嵌入\(images)幅图像、\(tables)个可编辑表格，未插入正文标记的目录记录不输出。")
        let marks=request.chapters.reduce(0,{$0+($1.indexMarks31?.count ?? 0)})
        item("索引域", marks>0, "写出\(marks)处已核索引标记；须在Word中更新索引域生成最终页码。")
        return ["sha256": ScholarArchive.digest(output), "bytes": output.count, "items": items, "footnotes": count,
                "missingNotes": document.components(separatedBy: "【缺失脚注 ").count - 1]
    }
}
