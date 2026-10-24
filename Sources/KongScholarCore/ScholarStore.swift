import Foundation

public enum ScholarStoreError: LocalizedError {
    case tooLarge, invalidData, alreadyRunning
    public var errorDescription: String? {
        switch self {
        case .tooLarge: return "数据超过 25 MB，未写入。请先导出备份并精简过长摘录。"
        case .invalidData: return "数据格式无效，原文件未被替换。"
        case .alreadyRunning: return "KongScholar 已在另一个进程中打开。请使用已有窗口，避免同时写入。"
        }
    }
}

public final class ScholarStore {
    public let directory: URL
    public var dataURL: URL { directory.appendingPathComponent("scholar-data.json") }
    public var recoveryURL: URL { directory.appendingPathComponent("recovery", isDirectory: true) }
    public static let limit = 25 * 1024 * 1024
    private let manager = FileManager.default

    public init(directory: URL) throws {
        self.directory = directory
        try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
    }

    public func read() throws -> String? {
        guard manager.fileExists(atPath: dataURL.path) else { return nil }
        let bytes = try Data(contentsOf: dataURL)
        guard let string = String(data: bytes, encoding: .utf8) else { throw ScholarStoreError.invalidData }
        // Preserve malformed JSON for the UI's protected recovery mode; never replace on load.
        return string
    }

    public static func validate(_ string: String) throws -> Data {
        let bytes = Data(string.utf8)
        guard bytes.count <= limit else { throw ScholarStoreError.tooLarge }
        guard let root = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let profile = root["profile"] as? [String: Any],
              ["field", "method", "writing", "teaching"].allSatisfy({ profile[$0] is String }) else {
            throw ScholarStoreError.invalidData
        }
        let required = ["questions", "sources", "drafts", "lessons", "notes"]
        let optional = ["arguments", "chapters", "comparisons", "events", "references", "responses", "tasks", "concepts", "textpairs", "seminars", "projects", "milestones", "inbox", "reviews", "feedback"]
        for key in required + optional {
            if root[key] == nil && optional.contains(key) { continue }
            guard let items = root[key] as? [[String: Any]] else { throw ScholarStoreError.invalidData }
            var seen = Set<String>()
            for item in items {
                guard let id = item["id"] as? String, !id.isEmpty,
                      item["title"] is String, seen.insert(id).inserted else { throw ScholarStoreError.invalidData }
                for field in ["support", "against", "sourceIds", "projectIDs"] where item[field] != nil {
                    guard item[field] is [String] else { throw ScholarStoreError.invalidData }
                }
            }
        }
        return bytes
    }

    public func write(_ string: String) throws {
        let bytes = try Self.validate(string)
        // Keep an independent last-good copy before replacing the live data.
        // An invalid live file is preserved as a recovery snapshot as well.
        if manager.fileExists(atPath: dataURL.path) {
            let existing = try Data(contentsOf: dataURL)
            if existing != bytes {
                try manager.createDirectory(at: recoveryURL, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
                let destination = recoveryURL.appendingPathComponent("previous-data.json")
                try existing.write(to: destination, options: .atomic)
                try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            }
        }
        if let text = try read(), (try? Self.validate(text)) != nil { try snapshotIfNeeded() }
        try bytes.write(to: dataURL, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dataURL.path)
    }

    public var backupURL: URL { directory.appendingPathComponent("backups", isDirectory: true) }

    public func backupPreferences() -> (interval: Int, retention: Int) {
        guard let text = try? read(), let bytes = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let settings = root["settings"] as? [String: Any] else { return (60, 60) }
        let interval = settings["backupIntervalMins"] as? Int ?? 60
        let retention = settings["backupRetentionCount"] as? Int ?? 60
        return ([15, 30, 60, 120].contains(interval) ? interval : 60,
                [30, 60, 120].contains(retention) ? retention : 60)
    }

    @discardableResult public func snapshotIfNeeded(force: Bool = false, label: String = "auto", now: Date = Date()) throws -> URL? {
        guard !label.isEmpty, label.range(of: "^[a-zA-Z0-9.-]+$", options: .regularExpression) != nil else { throw ScholarStoreError.invalidData }
        guard let text = try read() else { return nil }
        let bytes = try Self.validate(text)
        try manager.createDirectory(at: backupURL, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let files = try backupFiles()
        if label == "auto", let latest = files.first, (try? Data(contentsOf: latest)) == bytes { return nil }
        if !force, let last = files.first,
           let date = try last.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           now.timeIntervalSince(date) < Double(backupPreferences().interval * 60) { return nil }
        let name = "snapshot-" + String(Int(now.timeIntervalSince1970)) + "-" + label + "-" + UUID().uuidString + ".json"
        let url = backupURL.appendingPathComponent(name)
        try bytes.write(to: url, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600, .modificationDate: now], ofItemAtPath: url.path)
        _ = try Self.validate(String(contentsOf: url, encoding: .utf8))
        // Keep the configured number of automatic snapshots; named upgrade/manual snapshots remain.
        let autos = try backupFiles().filter { $0.lastPathComponent.contains("-auto-") }
        for old in autos.dropFirst(backupPreferences().retention) { try manager.removeItem(at: old) }
        return url
    }
    public func backupFiles() throws -> [URL] {
        guard manager.fileExists(atPath: backupURL.path) else { return [] }
        return try manager.contentsOfDirectory(at: backupURL, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "json" && !$0.hasDirectoryPath }
            .sorted { a, b in
                let ad = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let bd = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return ad == bd ? a.lastPathComponent > b.lastPathComponent : ad > bd
            }
    }
    public func backupText(named name: String) throws -> String {
        guard let file = try backupFiles().first(where: { $0.lastPathComponent == name }) else { throw ScholarStoreError.invalidData }
        let text = try String(contentsOf: file, encoding: .utf8)
        _ = try Self.validate(text)
        return text
    }

    public static func javascriptLiteral(_ text: String?) -> String {
        guard let text, let encoded = try? JSONSerialization.data(withJSONObject: text, options: [.fragmentsAllowed]),
              let json = String(data: encoded, encoding: .utf8) else { return "null" }
        return json.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}
