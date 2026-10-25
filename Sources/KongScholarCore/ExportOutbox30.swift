import Foundation

/// Durable local export intent. Persist before writing the external file; never infer
/// success from a save-panel response. A prepared entry is recovered only by its hash.
public enum ExportOutbox30 {
    private static let maximum = 64 * 1024 * 1024
    public static func pendingCount(root: URL) throws -> Int {
        let dir = try folder(root)
        guard FileManager.default.fileExists(atPath: dir.path) else { return 0 }
        let count = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }.count
        guard count <= 100 else { throw ScholarStoreError.tooLarge }; return count
    }
    private static func folder(_ root: URL) throws -> URL {
        let url = root.appendingPathComponent("export-outbox", isDirectory: true)
        if FileManager.default.fileExists(atPath: url.path) {
            guard try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw ScholarStoreError.invalidData }
        }
        return url
    }
    private static func validToken(_ token: String) throws {
        guard token.range(of: "^KS29-[A-F0-9]{32}$", options: .regularExpression) != nil else { throw ScholarStoreError.invalidData }
    }
    private static func file(_ token: String, root: URL) throws -> URL {
        try validToken(token); return try folder(root).appendingPathComponent(token + ".json")
    }
    private static func read(_ url: URL) throws -> [String: Any] {
        let attrs = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
        guard attrs.isSymbolicLink != true, (attrs.fileSize ?? Int.max) <= maximum,
              let r = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
              r["format"] as? String == "KongScholar-ExportOutbox30", r["version"] as? Int == 1,
              let token = r["token"] as? String, url.lastPathComponent == token + ".json",
              let entry = r["entry"] as? [String: Any], entry["token"] as? String == token,
              let record = entry["deliveryRecord30"] as? [String: Any], record["deliveryToken29"] as? String == token,
              let hash = r["sha256"] as? String, hash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
              let size = r["bytes"] as? Int, size >= 0, size <= ScholarStore.limit,
              r["path"] is String, ["prepared", "saved"].contains(r["state"] as? String ?? "") else { throw ScholarStoreError.invalidData }
        try validToken(token); return r
    }
    private static func write(_ value: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        guard data.count <= maximum else { throw ScholarStoreError.tooLarge }
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        guard try Data(contentsOf: url) == data else { throw ScholarStoreError.invalidData }
    }
    public static func prepare(entry: [String: Any], output: Data, destination: URL, root: URL, proof: [String: Any]) throws {
        guard let token = entry["token"] as? String,
              let payload = entry["payload"] as? [String: Any], payload["deliveryToken29"] as? String == token,
              let record = entry["deliveryRecord30"] as? [String: Any], record["deliveryToken29"] as? String == token,
              record["id"] is String, let chapters = record["chapters"] as? [[String: Any]], !chapters.isEmpty,
              record["title"] as? String == payload["title"] as? String,
              record["projectIDs"] is [String], record["feedback"] is [[String: Any]],
              output.count <= ScholarStore.limit, destination.isFileURL else { throw ScholarStoreError.invalidData }
        let dir = try folder(root), target = try file(token, root: root)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard !FileManager.default.fileExists(atPath: target.path) else { throw ScholarStoreError.invalidData }
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]).filter { $0.pathExtension == "json" }
        let bytes = try JSONSerialization.data(withJSONObject: entry).count
        guard files.count < 100, try files.reduce(bytes, { try $0 + ($1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? maximum) }) <= ScholarStore.limit else { throw ScholarStoreError.tooLarge }
        try write(["format": "KongScholar-ExportOutbox30", "version": 1, "token": token, "state": "prepared", "entry": entry,
                   "path": destination.path, "sha256": ScholarArchive.digest(output), "bytes": output.count, "proof30": proof], to: target)
        _ = try read(target)
    }
    /// Explicit reinspection also handles a crash between file write and marking saved.
    public static func list(root: URL) throws -> [[String: Any]] {
        let dir = try folder(root)
        guard FileManager.default.fileExists(atPath: dir.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard files.count <= 100 else { throw ScholarStoreError.tooLarge }
        var result = [[String: Any]](), receiptBytes = 0, checkedBytes = 0
        for url in files {
            receiptBytes += try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? maximum
            guard receiptBytes <= ScholarStore.limit else { throw ScholarStoreError.tooLarge }
            var r = try read(url)
            let path = URL(fileURLWithPath: r["path"] as! String), size = r["bytes"] as! Int
            do {
                let attrs = try path.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard attrs.isRegularFile == true, attrs.isSymbolicLink != true, attrs.fileSize == size, checkedBytes + size <= 512 * 1024 * 1024 else { throw ScholarStoreError.invalidData }
                checkedBytes += size
                guard ScholarArchive.digest(try Data(contentsOf: path)) == r["sha256"] as? String else { throw ScholarStoreError.invalidData }
                if r["state"] as? String != "saved" { r["state"] = "saved"; try write(r, to: url) }
                r["detail"] = "导出文件内容与回执指纹一致，可补记当时交稿快照。"
            } catch {
                r["state"] = "unverified"; r["detail"] = "文件缺失、移动、内容改变或本轮核对达到上限；请保留回执并核对原文件。"
            }
            result.append(r)
        }
        return result
    }
    public static func markSaved(token: String, root: URL) throws {
        let url = try file(token, root: root), row = try read(url)
        let target = URL(fileURLWithPath: row["path"] as! String)
        guard try target.resourceValues(forKeys: [.fileSizeKey]).fileSize == row["bytes"] as? Int,
              ScholarArchive.digest(try Data(contentsOf: target)) == row["sha256"] as? String else { throw ScholarStoreError.invalidData }
        var value = row; value["state"] = "saved"; try write(value, to: url)
    }
    public static func acknowledge(token: String, root: URL, library: String) throws {
        let url = try file(token, root: root)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let row = try read(url), entry = row["entry"] as! [String: Any], expected = entry["deliveryRecord30"] as! [String: Any]
        let bytes = try ScholarStore.validate(library)
        guard let data = try JSONSerialization.jsonObject(with: bytes) as? [String: Any], let records = data["deliveries"] as? [[String: Any]],
              let actual = records.first(where: { $0["deliveryToken29"] as? String == token }),
              expected.allSatisfy({ key, value in
                  guard let other = actual[key] else { return false }
                  return (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])) == (try? JSONSerialization.data(withJSONObject: other, options: [.sortedKeys, .fragmentsAllowed]))
              }) else { throw ScholarStoreError.invalidData }
        try FileManager.default.removeItem(at: url)
    }
}
