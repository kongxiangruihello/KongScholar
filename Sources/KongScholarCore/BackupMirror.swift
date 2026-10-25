import Foundation

public enum BackupMirror {
    /// The user-selected directory must already exist, so disconnected volumes cannot be recreated locally.
    @discardableResult public static func copy(_ text: String, into chosen: URL, now: Date = Date()) throws -> URL {
        let bytes = try ScholarStore.validate(text)
        let attributes = try FileManager.default.attributesOfItem(atPath: chosen.path)
        guard chosen.isFileURL, attributes[.type] as? FileAttributeType == .typeDirectory, FileManager.default.isWritableFile(atPath: chosen.path) else { throw ScholarStoreError.invalidData }
        let folder = chosen.appendingPathComponent("KongScholar-backups", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let hash = ScholarArchive.digest(bytes)
        let target = folder.appendingPathComponent("backup-" + hash + ".json")
        if !FileManager.default.fileExists(atPath: target.path) { try bytes.write(to: target, options: .atomic); try FileManager.default.setAttributes([.posixPermissions: 0o600, .modificationDate: now], ofItemAtPath: target.path) }
        let check = try Data(contentsOf: target)
        guard ScholarArchive.digest(check) == hash, let readback = String(data: check, encoding: .utf8) else { throw ScholarStoreError.invalidData }
        _ = try ScholarStore.validate(readback)
        return target
    }
    public static func health(_ store: ScholarStore) throws -> [String: Any] {
        let files = try store.backupFiles(), latest = files.first
        var total = 0
        for file in files { total += (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 }
        var result: [String: Any] = ["count": files.count, "bytes": total, "checkedAt": ISO8601DateFormatter().string(from: Date()), "latest": latest?.lastPathComponent ?? ""]
        if let latest { let text = try store.backupText(named: latest.lastPathComponent), bytes = try ScholarStore.validate(text); let root = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
            result["restorable"] = true; result["sha256"] = ScholarArchive.digest(bytes)
            result["records"] = root.filter { !["activityLog", "importHistory", "mergeHistory"].contains($0.key) }.values.compactMap { $0 as? [[String: Any]] }.reduce(0) { $0 + $1.count }
        } else { result["restorable"] = false }
        let live = try store.read() ?? ""; result["liveBytes"] = live.utf8.count
        result["indexBytes"] = (try? store.dataURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let archive = store.directory.appendingPathComponent("archives")
        let chunks = (try? FileManager.default.contentsOfDirectory(at: archive, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        result["archiveBytes"] = chunks.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        result["archiveCount"] = chunks.count
        return result
    }
}
