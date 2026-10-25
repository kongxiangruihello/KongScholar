import Foundation
import AppKit
import PDFKit
import Vision

public enum EvidenceImage {
    public static let maximum = 8 * 1024 * 1024
    public static func pdfData(at file: URL, expectedID: String) throws -> Data {
        guard try FolioOrigin.projectID(at: file).lowercased() == expectedID.lowercased() else { throw ScholarStoreError.invalidData }
        let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
        let magic = Data("KONGFOLIO-PROJECT\n".utf8), prefix = try handle.read(upToCount: magic.count + 8) ?? Data()
        if prefix.starts(with: magic), prefix.count == magic.count + 8 {
            let length = prefix.suffix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            guard (1...16 * 1024 * 1024).contains(length) else { throw ScholarStoreError.invalidData }
            let bytes = try handle.read(upToCount: Int(length)) ?? Data()
            guard let manifest = try JSONSerialization.jsonObject(with: bytes) as? [String: Any], let blobs = manifest["blobs"] as? [String: [String: Any]],
                  let pdf = blobs["pdf"], let offset = pdf["offset"] as? Int, let count = pdf["length"] as? Int, offset >= 0, count > 0, count <= 256 * 1024 * 1024 else { throw ScholarStoreError.invalidData }
            let start = magic.count + 8 + Int(length) + offset
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard start >= 0, start <= size, count <= size - start else { throw ScholarStoreError.invalidData }
            try handle.seek(toOffset: UInt64(start)); let output = try handle.read(upToCount: count) ?? Data()
            guard output.count == count else { throw ScholarStoreError.invalidData }; return output
        }
        try handle.seek(toOffset: 0)
        guard let root = try JSONSerialization.jsonObject(with: handle.readToEnd() ?? Data()) as? [String: Any], let encoded = root["pdf"] as? String,
              let output = Data(base64Encoded: encoded), output.count <= 256 * 1024 * 1024 else { throw ScholarStoreError.invalidData }
        return output
    }
    public static func pageImage(origin: FolioOrigin) throws -> (NSImage, Bool) {
        try origin.validate(); guard let file = origin.resolvedFileURL() else { throw ScholarStoreError.invalidData }
        let bytes = try pdfData(at: file, expectedID: origin.documentID)
        guard let doc = PDFDocument(data: bytes), !doc.isLocked, let page = doc.page(at: origin.physicalPage - 1) else { throw ScholarStoreError.invalidData }
        let bounds = page.bounds(for: .cropBox), ratio = min(1800 / max(1, bounds.width), 2400 / max(1, bounds.height))
        return (page.thumbnail(of: NSSize(width: bounds.width * ratio, height: bounds.height * ratio), for: .cropBox), !(origin.fingerprint ?? "").isEmpty && origin.fingerprint != ScholarArchive.digest(bytes))
    }
    public static func png(_ image: NSImage, crop: CGRect) throws -> Data {
        guard [crop.minX, crop.minY, crop.width, crop.height].allSatisfy({ $0.isFinite }), crop.minX >= 0, crop.minY >= 0, crop.width > 0, crop.height > 0, crop.maxX <= 1.00001, crop.maxY <= 1.00001,
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw ScholarStoreError.invalidData }
        let rect = CGRect(x: crop.minX * CGFloat(cg.width), y: crop.minY * CGFloat(cg.height), width: crop.width * CGFloat(cg.width), height: crop.height * CGFloat(cg.height)).integral.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard rect.width >= 4, rect.height >= 4, let cut = cg.cropping(to: rect), let bytes = NSBitmapImageRep(cgImage: cut).representation(using: .png, properties: [:]), bytes.count <= maximum else { throw ScholarStoreError.tooLarge }
        return bytes
    }
    public static func validateWords32(_ words:[String])throws->[String]{
        guard words.count<=500,Set(words).count==words.count,words.allSatisfy({!$0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty&&$0.count<=80 && !$0.contains("\n") && !$0.contains("\r")}),words.joined().utf8.count<=32000 else{throw ScholarStoreError.invalidData};return words
    }
    public static func recognize(_ base64: String, customWords:[String]=[]) throws -> [String: Any] {
        let words=try validateWords32(customWords)
        guard let bytes = Data(base64Encoded: base64), bytes.count <= maximum, let image = NSImage(data: bytes), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil), cg.width <= 6000, cg.height <= 6000 else { throw ScholarStoreError.invalidData }
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.recognitionLanguages = ["zh-Hant", "zh-Hans", "en-US"]; request.usesLanguageCorrection = !words.isEmpty; request.customWords=words; request.usesCPUOnly = true
        try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
        let rows = (request.results ?? []).compactMap { item -> [String: Any]? in guard let candidate = item.topCandidates(1).first else { return nil }; return ["text": candidate.string, "confidence": Double(candidate.confidence), "region": [Double(item.boundingBox.minX), Double(1-item.boundingBox.maxY), Double(item.boundingBox.width), Double(item.boundingBox.height)]] }
        return ["customWords32":words,"languageCorrection32":!words.isEmpty,"text": rows.compactMap { $0["text"] as? String }.joined(separator: "\n"), "lines": rows]
    }
}
