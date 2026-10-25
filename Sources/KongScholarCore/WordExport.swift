import Foundation

public struct WordExportRequest: Codable {
    public var title: String
    public var chapters: [WordChapter]
    public var layout: WordLayout?
    public var deliveryToken29: String?
    public init(title: String, chapters: [WordChapter], layout: WordLayout? = nil, deliveryToken29: String? = nil) { self.title = title; self.chapters = chapters; self.layout = layout; self.deliveryToken29 = deliveryToken29 }
}
public struct WordLayout: Codable {
    public var font: String?
    public var size: Double?
    public var lineSpacing: Double?
    public var marginTop: Double?
    public var marginBottom: Double?
    public var marginLeft: Double?
    public var marginRight: Double?
    public var footnoteSize: Double?
    public var titlePage: Bool?
    public var author: String?
    public var abstract: String?
    public var keywords: String?
    public var appendix: String?
    public init() {}
    func validate() throws {
        guard ["Songti SC","SimSun","STSong","PingFang SC","Times New Roman"].contains(font ?? "Songti SC"),
              (9...18).contains(size ?? 12),(1...3).contains(lineSpacing ?? 1.5),(8...14).contains(footnoteSize ?? 10),
              [marginTop,marginBottom,marginLeft,marginRight].allSatisfy({(1.5...4).contains($0 ?? 2.54)}),
              (author?.count ?? 0)<=500,(abstract?.count ?? 0)<=10000,(keywords?.count ?? 0)<=1000,(appendix?.count ?? 0)<=200000 else {throw WordExportError.invalid}
    }
}
public struct WordChapter: Codable {
    public var title: String
    public var body: String
    public var citations: [WordCitation]
    public var blocks31: [WordBlock31]?
    public var indexMarks31: [WordIndexMark31]?
    public init(title: String, body: String, citations: [WordCitation], blocks31:[WordBlock31]?=nil, indexMarks31:[WordIndexMark31]?=nil) { self.title = title; self.body = body; self.citations = citations; self.blocks31=blocks31; self.indexMarks31=indexMarks31 }
}
public struct WordCitation: Codable {
    public var id: String
    public var text: String
    public init(id: String, text: String) { self.id = id; self.text = text }
}
public enum WordExportError: LocalizedError {
    case invalid, tooLarge
    public var errorDescription: String? { self == .tooLarge ? "Word 文稿超过导出上限，请分章节导出。" : "Word 文稿或脚注格式无效。" }
}

/// Minimal, self-contained OOXML package. No external executable or network required.
public enum WordExport {
    private static let ns = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    static func xml(_ text: String) -> String {
        String(text.unicodeScalars.filter { $0.value == 9 || $0.value == 10 || $0.value == 13 || ($0.value >= 32 && $0.value != 0xFFFE && $0.value != 0xFFFF) })
            .replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    static func run(_ text: String) -> String { "<w:r><w:t xml:space=\"preserve\">\(xml(text))</w:t></w:r>" }
    public static func parts(_ request: WordExportRequest) throws -> [String: String] {
        guard !request.title.isEmpty, !request.chapters.isEmpty, request.chapters.count <= 1000 else { throw WordExportError.invalid }
        guard (try JSONEncoder().encode(request)).count <= ScholarStore.limit else { throw WordExportError.tooLarge }
        let layout=request.layout ?? WordLayout();try layout.validate()
        if let token=request.deliveryToken29 {guard token.range(of:"^KS29-[A-F0-9]{32}$",options:.regularExpression) != nil else{throw WordExportError.invalid}}
        let font=layout.font ?? "Songti SC",size=Int(((layout.size ?? 12)*2).rounded()),line=Int(((layout.lineSpacing ?? 1.5)*240).rounded()),noteSize=Int(((layout.footnoteSize ?? 10)*2).rounded())
        func margin(_ n:Double?)->Int {Int(((n ?? 2.54)*1440/2.54).rounded())}
        var body = "<w:p><w:pPr><w:pStyle w:val=\"Title\"/></w:pPr>\(run(request.title))</w:p>"
        if let token=request.deliveryToken29 {body += "<w:p>\(run("稿次标识："+token))</w:p>"}
        if layout.titlePage==true {
            if let author=layout.author,!author.isEmpty {body += "<w:p>\(run(author))</w:p>"}
            body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
        }
        if let abstract=layout.abstract,!abstract.isEmpty {body += "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr>\(run("摘要"))</w:p>";for text in abstract.components(separatedBy:"\n"){body += "<w:p>\(run(text))</w:p>"}}
        if let keywords=layout.keywords,!keywords.isEmpty {body += "<w:p>\(run("关键词："+keywords))</w:p>"}
        var notes = "<w:footnote w:type=\"separator\" w:id=\"-1\"><w:p><w:r><w:separator/></w:r></w:p></w:footnote><w:footnote w:type=\"continuationSeparator\" w:id=\"0\"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:footnote>"
        var noteID = 0, blockSerial31 = 0, imageRelationships31 = ""
        let marker = try NSRegularExpression(pattern: #"\[\^(ks-[a-zA-Z0-9-]+)\]"#)
        for (index, chapter) in request.chapters.enumerated() {
            var lookup: [String: String] = [:]
            for citation in chapter.citations {
                guard citation.id.range(of: "^ks-[a-zA-Z0-9-]+$", options: .regularExpression) != nil, lookup[citation.id] == nil else { throw WordExportError.invalid }
                lookup[citation.id] = citation.text
            }
            if index > 0 || chapter.title != request.title { body += "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/>\(index > 0 ? "<w:pageBreakBefore/>" : "")</w:pPr>\(run(chapter.title))</w:p>" }
            let blocks31=chapter.blocks31 ?? []
            guard blocks31.count<=100,Set(blocks31.map(\.marker)).count==blocks31.count else{throw WordExportError.invalid}
            for block in blocks31{try WordComponents31.valid(block)}
            for line in try WordComponents31.markedBody(chapter).replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n") {
                if line.contains("[[KS31-") {
                    guard let block=blocks31.first(where:{$0.marker==line}),blockSerial31<100 else{throw WordExportError.invalid}
                    blockSerial31 += 1
                    let available=21-(layout.marginLeft ?? 2.54)-(layout.marginRight ?? 2.54)
                    if block.kind=="image"{guard (block.widthCM ?? 12)<=available else{throw WordExportError.invalid};imageRelationships31 += "<Relationship Id=\"rIdImage31-\(blockSerial31)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/figure-\(blockSerial31).png\"/>"}
                    body += try WordComponents31.render(block,serial:blockSerial31,availableCM:available);continue
                }
                let text = line as NSString
                var content = "", cursor = 0
                for match in marker.matches(in: line, range: NSRange(location: 0, length: text.length)) {
                    content += try WordComponents31.indexRun(text.substring(with: NSRange(location: cursor, length: match.range.location - cursor)),marks:chapter.indexMarks31 ?? [])
                    let id = text.substring(with: match.range(at: 1))
                    if let note = lookup[id] {
                        noteID += 1
                        content += "<w:r><w:rPr><w:rStyle w:val=\"FootnoteReference\"/></w:rPr><w:footnoteReference w:id=\"\(noteID)\"/></w:r>"
                        notes += "<w:footnote w:id=\"\(noteID)\"><w:p><w:pPr><w:pStyle w:val=\"FootnoteText\"/></w:pPr><w:r><w:rPr><w:rStyle w:val=\"FootnoteReference\"/></w:rPr><w:footnoteRef/></w:r>\(run(" " + note))</w:p></w:footnote>"
                    } else { content += run("【缺失脚注 \(id)】") }
                    cursor = NSMaxRange(match.range)
                }
                content += try WordComponents31.indexRun(text.substring(from: cursor),marks:chapter.indexMarks31 ?? []); body += "<w:p>\(content)</w:p>"
            }
        }
        if let appendix=layout.appendix,!appendix.isEmpty {body += "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/><w:pageBreakBefore/></w:pPr>\(run("附录"))</w:p>";for text in appendix.components(separatedBy:"\n"){body += "<w:p>\(run(text))</w:p>"}}
        if request.chapters.contains(where:{!($0.indexMarks31 ?? []).isEmpty}) {
            let instruction=xml(" INDEX \\h ")
            body += "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/><w:pageBreakBefore/></w:pPr>\(run("索引"))</w:p><w:p><w:fldSimple w:instr=\"\(instruction)\">\(run("请在Word中更新此索引域，生成最终页码。"))</w:fldSimple></w:p>"
        }
        body += "<w:sectPr><w:footnotePr><w:pos w:val=\"pageBottom\"/><w:numFmt w:val=\"decimal\"/><w:numRestart w:val=\"continuous\"/></w:footnotePr><w:pgSz w:w=\"11906\" w:h=\"16838\"/><w:pgMar w:top=\"\(margin(layout.marginTop))\" w:right=\"\(margin(layout.marginRight))\" w:bottom=\"\(margin(layout.marginBottom))\" w:left=\"\(margin(layout.marginLeft))\"/></w:sectPr>"
        let styles = """
        <w:styles xmlns:w="\(ns)"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="\(font)"/><w:color w:val="000000"/><w:sz w:val="\(size)"/><w:lang w:val="zh-CN" w:eastAsia="zh-CN"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="\(line)" w:lineRule="auto"/><w:widowControl/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:after="300"/><w:keepNext/></w:pPr><w:rPr><w:b/><w:sz w:val="36"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="240" w:after="180"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="FootnoteText"><w:name w:val="footnote text"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:after="60" w:line="240" w:lineRule="auto"/></w:pPr><w:rPr><w:sz w:val="\(noteSize)"/></w:rPr></w:style><w:style w:type="character" w:styleId="FootnoteReference"><w:name w:val="footnote reference"/><w:rPr><w:vertAlign w:val="superscript"/></w:rPr></w:style></w:styles>
        """
        var result = [
            "[Content_Types].xml": "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/><Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/><Override PartName=\"/word/footnotes.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml\"/></Types>",
            "_rels/.rels": "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>",
            "word/document.xml": "<w:document xmlns:w=\"\(ns)\"><w:body>\(body)</w:body></w:document>",
            "word/styles.xml": styles,
            "word/footnotes.xml": "<w:footnotes xmlns:w=\"\(ns)\">\(notes)</w:footnotes>",
            "word/_rels/document.xml.rels": "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes\" Target=\"footnotes.xml\"/></Relationships>"
        ]
        if !imageRelationships31.isEmpty {
            result["[Content_Types].xml"] = result["[Content_Types].xml"]!.replacingOccurrences(of:"</Types>",with:"<Default Extension=\"png\" ContentType=\"image/png\"/></Types>")
            result["word/_rels/document.xml.rels"] = result["word/_rels/document.xml.rels"]!.replacingOccurrences(of:"</Relationships>",with:imageRelationships31+"</Relationships>")
        }
        return result
    }
    public static func generate(_ request: WordExportRequest) throws -> Data {
        var package=try parts(request).mapValues{Data($0.utf8)},serial=0,total=0
        for ch in request.chapters {for line in ch.body.replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\r",with:"\n").components(separatedBy:"\n") {if let b=ch.blocks31?.first(where:{$0.marker==line}) {serial += 1;if b.kind=="image"{let(bytes,_,_)=try WordComponents31.image(b);total += bytes.count;guard total<=64*1024*1024 else{throw WordExportError.tooLarge};package["word/media/figure-\(serial).png"]=bytes}}}}
        let output=archive(package);guard output.count<=ScholarStore.limit else{throw WordExportError.tooLarge};return output
    }
    static func archive(_ parts: [String: Data]) -> Data {
        var output = Data(), directory = Data()
        func crc(_ bytes: Data) -> UInt32 { var c = UInt32.max; for b in bytes { c ^= UInt32(b); for _ in 0..<8 { c = (c >> 1) ^ (c & 1 == 1 ? 0xedb88320 : 0) } }; return c ^ UInt32.max }
        for name in parts.keys.sorted() {
            let bytes = parts[name]!, filename = Data(name.utf8), checksum = crc(bytes), offset = UInt32(output.count)
            output.le(UInt32(0x04034b50)); output.le(UInt16(20)); output.le(UInt16(0x800)); output.le(UInt16(0)); output.le(UInt16(0)); output.le(UInt16(0x21)); output.le(checksum); output.le(UInt32(bytes.count)); output.le(UInt32(bytes.count)); output.le(UInt16(filename.count)); output.le(UInt16(0)); output.append(filename); output.append(bytes)
            directory.le(UInt32(0x02014b50)); directory.le(UInt16(20)); directory.le(UInt16(20)); directory.le(UInt16(0x800)); directory.le(UInt16(0)); directory.le(UInt16(0)); directory.le(UInt16(0x21)); directory.le(checksum); directory.le(UInt32(bytes.count)); directory.le(UInt32(bytes.count)); directory.le(UInt16(filename.count)); directory.le(UInt16(0)); directory.le(UInt16(0)); directory.le(UInt16(0)); directory.le(UInt16(0)); directory.le(UInt32(0)); directory.le(offset); directory.append(filename)
        }
        let offset = UInt32(output.count); output.append(directory); output.le(UInt32(0x06054b50)); output.le(UInt16(0)); output.le(UInt16(0)); output.le(UInt16(parts.count)); output.le(UInt16(parts.count)); output.le(UInt32(directory.count)); output.le(offset); output.le(UInt16(0)); return output
    }
}
private extension Data { mutating func le<T: FixedWidthInteger>(_ value: T) { var v = value.littleEndian; Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) } } }
