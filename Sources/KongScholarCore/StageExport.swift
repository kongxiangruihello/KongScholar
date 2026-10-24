import Foundation

public struct StageTextFile: Codable {
    public var name: String
    public var text: String
    public init(name: String, text: String) { self.name = name; self.text = text }
}
public struct StageExportRequest: Codable {
    public var title: String
    public var files: [StageTextFile]
    public var manuscript: WordExportRequest
    public init(title: String, files: [StageTextFile], manuscript: WordExportRequest) { self.title = title; self.files = files; self.manuscript = manuscript }
}
public enum StageExportError: LocalizedError {
    case invalid, tooLarge
    public var errorDescription: String? { self == .tooLarge ? "阶段成果包超过导出上限，请缩小项目范围或分章节导出。" : "成果包文件名称或内容无效。" }
}
public enum StageExport {
    public static func parts(_ request: StageExportRequest) throws -> [String: Data] {
        guard !request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !request.files.isEmpty, request.files.count <= 30 else { throw StageExportError.invalid }
        guard try JSONEncoder().encode(request).count <= ScholarStore.limit else { throw StageExportError.tooLarge }
        var parts: [String: Data] = [:]
        for file in request.files {
            // Archive member names are flat; never allow a path or override the generated manuscript.
            guard !file.name.isEmpty, file.name.utf8.count <= 180, !file.name.hasPrefix("."), !file.name.contains("/"), !file.name.contains("\\"), !file.name.contains(":"), !file.name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }), file.name.hasSuffix(".md"), parts[file.name] == nil else { throw StageExportError.invalid }
            parts[file.name] = Data(file.text.utf8)
        }
        if !request.manuscript.chapters.isEmpty { parts["02-正文.docx"] = try WordExport.generate(request.manuscript) }
        guard parts.values.reduce(0, { $0 + $1.count }) <= ScholarStore.limit else { throw StageExportError.tooLarge }
        return parts
    }
    public static func generate(_ request: StageExportRequest) throws -> Data {
        let output = WordExport.archive(try parts(request))
        guard output.count <= ScholarStore.limit else { throw StageExportError.tooLarge }
        return output
    }
}
