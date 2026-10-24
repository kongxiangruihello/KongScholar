import Foundation

public struct WordExportRequest: Codable {
    public var title: String
    public var chapters: [WordChapter]
    public init(title: String, chapters: [WordChapter]) { self.title = title; self.chapters = chapters }
}
public struct WordChapter: Codable {
    public var title: String
    public var body: String
    public var citations: [WordCitation]
    public init(title: String, body: String, citations: [WordCitation]) { self.title = title; self.body = body; self.citations = citations }
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
        var body = "<w:p><w:pPr><w:pStyle w:val=\"Title\"/></w:pPr>\(run(request.title))</w:p>"
        var notes = "<w:footnote w:type=\"separator\" w:id=\"-1\"><w:p><w:r><w:separator/></w:r></w:p></w:footnote><w:footnote w:type=\"continuationSeparator\" w:id=\"0\"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:footnote>"
        var noteID = 0
        let marker = try NSRegularExpression(pattern: #"\[\^(ks-[a-zA-Z0-9-]+)\]"#)
        for (index, chapter) in request.chapters.enumerated() {
            var lookup: [String: String] = [:]
            for citation in chapter.citations {
                guard citation.id.range(of: "^ks-[a-zA-Z0-9-]+$", options: .regularExpression) != nil, lookup[citation.id] == nil else { throw WordExportError.invalid }
                lookup[citation.id] = citation.text
            }
            if index > 0 || chapter.title != request.title { body += "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/>\(index > 0 ? "<w:pageBreakBefore/>" : "")</w:pPr>\(run(chapter.title))</w:p>" }
            for line in chapter.body.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n") {
                let text = line as NSString
                var content = "", cursor = 0
                for match in marker.matches(in: line, range: NSRange(location: 0, length: text.length)) {
                    content += run(text.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
                    let id = text.substring(with: match.range(at: 1))
                    if let note = lookup[id] {
                        noteID += 1
                        content += "<w:r><w:rPr><w:rStyle w:val=\"FootnoteReference\"/></w:rPr><w:footnoteReference w:id=\"\(noteID)\"/></w:r>"
                        notes += "<w:footnote w:id=\"\(noteID)\"><w:p><w:pPr><w:pStyle w:val=\"FootnoteText\"/></w:pPr><w:r><w:rPr><w:rStyle w:val=\"FootnoteReference\"/></w:rPr><w:footnoteRef/></w:r>\(run(" " + note))</w:p></w:footnote>"
                    } else { content += run("【缺失脚注 \(id)】") }
                    cursor = NSMaxRange(match.range)
                }
                content += run(text.substring(from: cursor)); body += "<w:p>\(content)</w:p>"
            }
        }
        body += "<w:sectPr><w:footnotePr><w:pos w:val=\"pageBottom\"/><w:numFmt w:val=\"decimal\"/><w:numRestart w:val=\"continuous\"/></w:footnotePr><w:pgSz w:w=\"11906\" w:h=\"16838\"/><w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\"/></w:sectPr>"
        let styles = """
        <w:styles xmlns:w="\(ns)"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="Songti SC"/><w:color w:val="000000"/><w:sz w:val="24"/><w:lang w:val="zh-CN" w:eastAsia="zh-CN"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="360" w:lineRule="auto"/><w:widowControl/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:after="300"/><w:keepNext/></w:pPr><w:rPr><w:b/><w:sz w:val="36"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="240" w:after="180"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="FootnoteText"><w:name w:val="footnote text"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:after="60" w:line="240" w:lineRule="auto"/></w:pPr><w:rPr><w:sz w:val="20"/></w:rPr></w:style><w:style w:type="character" w:styleId="FootnoteReference"><w:name w:val="footnote reference"/><w:rPr><w:vertAlign w:val="superscript"/></w:rPr></w:style></w:styles>
        """
        return [
            "[Content_Types].xml": "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/><Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/><Override PartName=\"/word/footnotes.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml\"/></Types>",
            "_rels/.rels": "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>",
            "word/document.xml": "<w:document xmlns:w=\"\(ns)\"><w:body>\(body)</w:body></w:document>",
            "word/styles.xml": styles,
            "word/footnotes.xml": "<w:footnotes xmlns:w=\"\(ns)\">\(notes)</w:footnotes>",
            "word/_rels/document.xml.rels": "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes\" Target=\"footnotes.xml\"/></Relationships>"
        ]
    }
    public static func generate(_ request: WordExportRequest) throws -> Data { archive(try parts(request).mapValues { Data($0.utf8) }) }
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
