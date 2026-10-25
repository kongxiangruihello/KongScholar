import Foundation

public enum ScholarStoreError: LocalizedError {
    case tooLarge, invalidData, alreadyRunning
    public var errorDescription: String? {
        switch self {
        case .tooLarge: return "当前资料索引超过64MB或完整资料超过256MB，未写入。请先导出备份并归档暂不用的项目。"
        case .invalidData: return "数据格式无效，原文件未被替换。"
        case .alreadyRunning: return "KongScholar 已在另一个进程中打开。请使用已有窗口，避免同时写入。"
        }
    }
}

public final class ScholarStore {
    public let directory: URL
    public var dataURL: URL { directory.appendingPathComponent("scholar-data.json") }
    public var recoveryURL: URL { directory.appendingPathComponent("recovery", isDirectory: true) }
    public static let limit = 256 * 1024 * 1024
    public var releaseVersion:String?
    private var upgradeChecked=false
    private let manager = FileManager.default

    public init(directory: URL) throws {
        self.directory = directory
        try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
    }

    public func read() throws -> String? {
        guard manager.fileExists(atPath: dataURL.path) else { return nil }
        let raw = try Data(contentsOf: dataURL)
        let bytes: Data
        if (try? JSONSerialization.jsonObject(with: raw) as? [String: Any])?["_archiveStorage"] != nil { bytes = try ScholarArchive.decode(raw, directory: directory) } else { bytes = raw }
        guard let string = String(data: bytes, encoding: .utf8) else { throw ScholarStoreError.invalidData }
        // Preserve malformed JSON for the UI's protected recovery mode; never replace on load.
        return string
    }

    public func readForInterface() throws -> String? {
        do { return try read() } catch {
            guard manager.fileExists(atPath: dataURL.path) else { throw error }
            if let raw = try? Data(contentsOf: dataURL), var root = (try? JSONSerialization.jsonObject(with: raw)) as? [String: Any] {
                root["_archiveReadError"] = true
                if let bytes = try? JSONSerialization.data(withJSONObject: root), let text = String(data: bytes, encoding: .utf8) { return text }
            }
            return "{\"_archiveReadError\":true}"
        }
    }

    public static func validate(_ string: String) throws -> Data {
        let bytes = Data(string.utf8)
        guard bytes.count <= limit else { throw ScholarStoreError.tooLarge }
        guard let root = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let profile = root["profile"] as? [String: Any],
              ["field", "method", "writing", "teaching"].allSatisfy({ profile[$0] is String }) else {
            throw ScholarStoreError.invalidData
        }
        guard root["_archiveStorage"] == nil, root["_archiveReadError"] == nil else { throw ScholarStoreError.invalidData }
        let required = ["questions", "sources", "drafts", "lessons", "notes"]
        let optional = ["arguments", "chapters", "comparisons", "events", "references", "responses", "tasks", "concepts", "textpairs", "seminars", "projects", "milestones", "inbox", "reviews", "feedback", "readings", "authorities", "provenances", "freezes", "deliveries", "timebudgets", "bookmarks", "crossrefs", "collections", "evidenceimages", "collations", "submissions", "peerreviews", "semesters", "courseweeks", "supervisions", "guidancemeetings", "guidancedrafts", "paragraphroles", "personrelations", "folioqueues", "pdfindexes", "sourceimpacts", "draftcomparisons", "pagemaps28", "alignments28", "versionchoices28", "reliability28", "searchleads28", "searchattempts28", "questionlinks29", "countercases29", "revisionrounds29", "handoffchecks29", "figures29", "teachingchecks29", "meetingplans29", "researchsets31", "tables31", "indexentries31", "replies32", "ocrterms32", "editionmaps32", "packets34", "packetitems34", "packetversions34", "meetingactions34"]
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
        if let version=releaseVersion,!upgradeChecked {do{_ = try UpgradeProtection.protect(self,version:version);upgradeChecked=true}catch{throw NSError(domain:"KongScholar",code:27,userInfo:[NSLocalizedDescriptionKey:"升级前备份未通过校验，已阻止写入："+error.localizedDescription])}}
        let existing=try (try? read()).map {Data($0.utf8)} ?? (manager.fileExists(atPath:dataURL.path) ? Data(contentsOf:dataURL) : nil)
        // Keep an independent last-good copy before replacing the live data.
        // An invalid live file is preserved as a recovery snapshot as well.
        if let existing=existing {
            if existing != bytes {
                try manager.createDirectory(at: recoveryURL, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
                let destination = recoveryURL.appendingPathComponent("previous-data.json")
                try existing.write(to: destination, options: .atomic)
                try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            }
        }
        if let existing=existing,let text=String(data:existing,encoding:.utf8),(try? Self.validate(text)) != nil {try snapshotText(text,force:false,label:"auto",now:Date())}
        let index = try ScholarArchive.encode(bytes, directory: directory)
        try index.write(to: dataURL, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dataURL.path)
    }

    public var backupURL: URL { directory.appendingPathComponent("backups", isDirectory: true) }

    public func backupPreferences() -> (interval: Int, retention: Int) {
        guard let text = try? read(), let bytes = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let settings = root["settings"] as? [String: Any] else { return (15, 60) }
        let interval = settings["backupIntervalMins"] as? Int ?? 15
        let retention = settings["backupRetentionCount"] as? Int ?? 60
        return ([15, 30, 60, 120].contains(interval) ? interval : 15,
                [30, 60, 120].contains(retention) ? retention : 60)
    }

    @discardableResult public func snapshotIfNeeded(force: Bool = false, label: String = "auto", now: Date = Date()) throws -> URL? {
        guard !label.isEmpty, label.range(of: "^[a-zA-Z0-9.-]+$", options: .regularExpression) != nil else { throw ScholarStoreError.invalidData }
        guard let text = try read() else { return nil }
        return try snapshotText(text,force:force,label:label,now:now)
    }
    @discardableResult private func snapshotText(_ text:String,force:Bool,label:String,now:Date) throws -> URL? {
        let bytes=try Self.validate(text)
        let settings=((try? JSONSerialization.jsonObject(with:bytes)) as? [String:Any])?["settings"] as? [String:Any] ?? [:]
        let interval=settings["backupIntervalMins"] as? Int ?? 15,retention=settings["backupRetentionCount"] as? Int ?? 60
        try manager.createDirectory(at: backupURL, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let files = try backupFiles()
        if label == "auto", let latest = files.first, (try? Data(contentsOf: latest)) == bytes { return nil }
        if !force, let last = files.first,
           let date = try last.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           now.timeIntervalSince(date) < Double(([15,30,60,120].contains(interval) ? interval : 15) * 60) { return nil }
        let name = "snapshot-" + String(Int(now.timeIntervalSince1970)) + "-" + label + "-" + UUID().uuidString + ".json"
        let url = backupURL.appendingPathComponent(name)
        try bytes.write(to: url, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600, .modificationDate: now], ofItemAtPath: url.path)
        _ = try Self.validate(String(contentsOf: url, encoding: .utf8))
        // Keep the configured number of automatic snapshots; named upgrade/manual snapshots remain.
        let autos = try backupFiles().filter { $0.lastPathComponent.contains("-auto-") }
        for old in autos.dropFirst([30,60,120].contains(retention) ? retention : 60) { try manager.removeItem(at: old) }
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
