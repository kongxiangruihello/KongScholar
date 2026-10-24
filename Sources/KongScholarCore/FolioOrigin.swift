import Foundation

public struct FolioOrigin: Codable {
    public var documentID: String
    public var annotationID: String?
    public var filePath: String
    public var bookmarkData: String?
    public var physicalPage: Int
    public var fingerprint: String?
    public var quoteHash: String?
    public var legacy: Bool?

    public func validate() throws {
        guard (legacy == true || UUID(uuidString: documentID) != nil), filePath.isEmpty || filePath.hasPrefix("/"),
              (1...1_000_000).contains(physicalPage),
              annotationID == nil || annotationID == "" || UUID(uuidString: annotationID!) != nil,
              (bookmarkData?.utf8.count ?? 0) <= 131072 else { throw ScholarStoreError.invalidData }
        for value in [fingerprint, quoteHash].compactMap({ $0 }) where !value.isEmpty {
            guard value.range(of: "^[a-fA-F0-9]{64}$", options: .regularExpression) != nil else { throw ScholarStoreError.invalidData }
        }
    }
    public func resolvedFileURL() -> URL? {
        if let string = bookmarkData, let bytes = Data(base64Encoded: string) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bytes, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale),
               url.isFileURL, url.pathExtension.lowercased() == "kongfolio", FileManager.default.fileExists(atPath: url.path) { return url.standardizedFileURL }
        }
        guard filePath.hasPrefix("/") else { return nil }
        let url = URL(fileURLWithPath: filePath).standardizedFileURL
        return url.pathExtension.lowercased() == "kongfolio" && FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    public func deepLink(fileURL: URL) throws -> URL {
        try validate()
        guard UUID(uuidString: documentID) != nil, fileURL.isFileURL, fileURL.pathExtension.lowercased() == "kongfolio" else { throw ScholarStoreError.invalidData }
        var parts = URLComponents(); parts.scheme = "kongfolio"; parts.host = "open"
        parts.queryItems = [URLQueryItem(name: "file", value: fileURL.path), URLQueryItem(name: "document", value: documentID),
                           URLQueryItem(name: "annotation", value: annotationID ?? ""), URLQueryItem(name: "page", value: String(physicalPage)),
                           URLQueryItem(name: "fingerprint", value: fingerprint ?? ""), URLQueryItem(name: "quoteHash", value: quoteHash ?? "")]
        guard let url = parts.url else { throw ScholarStoreError.invalidData }; return url
    }
    public static func projectID(at url: URL) throws -> String {
        guard url.isFileURL, url.pathExtension.lowercased() == "kongfolio" else { throw ScholarStoreError.invalidData }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let magic = Data("KONGFOLIO-PROJECT\n".utf8)
        let prefix = try handle.read(upToCount: magic.count + 8) ?? Data()
        let root: [String: Any]?
        if prefix.starts(with: magic), prefix.count == magic.count + 8 {
            let length = prefix.suffix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            guard length > 0, length <= 16 * 1024 * 1024 else { throw ScholarStoreError.invalidData }
            let bytes = try handle.read(upToCount: Int(length)) ?? Data()
            guard bytes.count == Int(length) else { throw ScholarStoreError.invalidData }
            let manifest = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
            root = manifest?["archive"] as? [String: Any]
        } else {
            guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 512 * 1024 * 1024 else { throw ScholarStoreError.tooLarge }
            try handle.seek(toOffset: 0)
            root = try JSONSerialization.jsonObject(with: handle.readToEnd() ?? Data()) as? [String: Any]
        }
        guard let id = root?["scholarDocumentID"] as? String, UUID(uuidString:id) != nil else {
            throw NSError(domain: "KongScholar", code: 20, userInfo: [NSLocalizedDescriptionKey: "请选择由 KongFolio 0.22.1 联动补丁保存、带有稳定文档编号的项目。"])
        }
        return id
    }
}
