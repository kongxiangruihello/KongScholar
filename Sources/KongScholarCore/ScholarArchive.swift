import Foundation
import CryptoKit

/// Only immutable, content-addressed archive files are referenced by the atomic live index.
/// Portable exports and backups are always reassembled into ordinary, standalone JSON.
public enum ScholarArchive {
    public static let indexLimit = 64 * 1024 * 1024
    private static let rootKeys = ["importHistory", "mergeHistory"]
    private static let recordKeys: [String: [String]] = ["freezes": ["snapshot"], "deliveries": ["chapters", "feedback", "exportBlocks31"], "chapters": ["versions"], "questions": ["evolution"], "evidenceimages": ["imageData", "ocrHistory"], "collations": ["witnesses"], "pdfindexes": ["pages"], "sourceimpacts": ["before", "after"], "draftcomparisons": ["beforeText", "afterText"], "revisionrounds29": ["reference29"], "teachingchecks29": ["snapshot29"], "meetingplans29": ["agendaBasis29"], "indexentries31": ["reviewBasis31"], "replies32": ["snapshot32", "basis32", "history32"], "packetversions34": ["snapshot34", "basis34"], "meetingactions34": ["history34"], "continuations36": ["snapshot36", "basis36"], "cvdrafts36": ["cvSources36", "basis36"], "projects": ["stageHistory36"], "submissions": ["statusHistory36"]]
    public static func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
    public static func encode(_ bytes: Data, directory: URL) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any], root["_archiveStorage"] == nil else { throw ScholarStoreError.invalidData }
        let folder = directory.appendingPathComponent("archives", isDirectory: true)
        var pointers = [[String: Any]]()
        func detach(_ value: Any, path: [String]) throws {
            let chunk = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
            let hash = digest(chunk), target = folder.appendingPathComponent(hash + ".json")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            if FileManager.default.fileExists(atPath: target.path) {
                guard try target.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw ScholarStoreError.invalidData }
                let existing = try Data(contentsOf: target)
                if digest(existing) != hash {
                    let recovery = directory.appendingPathComponent("recovery", isDirectory: true)
                    try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                    let damaged = recovery.appendingPathComponent("damaged-" + UUID().uuidString + ".json")
                    try existing.write(to: damaged, options: .atomic)
                    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: damaged.path)
                    try chunk.write(to: target, options: .atomic)
                }
            } else { try chunk.write(to: target, options: .atomic); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path) }
            guard digest(try Data(contentsOf: target)) == hash else { throw ScholarStoreError.invalidData }
            pointers.append(["path": path, "sha256": hash])
        }
        for key in rootKeys { if let rows = root[key] as? [Any], !rows.isEmpty { try detach(rows, path: [key]); root[key] = [] } }
        if var meta = root["meta"] as? [String: Any], let rows = meta["recycleBin"] as? [Any], !rows.isEmpty { try detach(rows, path: ["meta", "recycleBin"]); meta["recycleBin"] = []; root["meta"] = meta }
        for (type, fields) in recordKeys {
            guard var rows = root[type] as? [[String: Any]] else { continue }
            for i in rows.indices { for field in fields { if let value = rows[i][field] {
                if let a = value as? [Any], a.isEmpty { continue }
                if let s = value as? String, s.isEmpty { continue }
                guard let id = rows[i]["id"] as? String else { throw ScholarStoreError.invalidData }
                try detach(value, path: [type, id, field]); rows[i].removeValue(forKey: field)
            } } }
            root[type] = rows
        }
        let advancedKeys = ["timebudgets", "bookmarks", "crossrefs", "collections", "evidenceimages", "collations", "submissions", "peerreviews", "semesters", "courseweeks", "supervisions", "guidancemeetings", "guidancedrafts"]
        if pointers.isEmpty && !advancedKeys.contains(where: { root[$0] != nil }) { guard bytes.count <= indexLimit else { throw ScholarStoreError.tooLarge }; return bytes }
        guard let profile = root["profile"] as? [String: Any] else { throw ScholarStoreError.invalidData }
        // Older app versions must enter protected recovery mode instead of dropping unknown collections.
        root["profile"] = ["_archiveIndexOnly": true]
        let reader = (root["meta"] as? [String: Any])?["minimumReader"] as? Int ?? 0
        let storageVersion = reader >= 36 ? 12 : reader >= 35 ? 11 : reader >= 34 ? 10 : reader >= 32 ? 9 : reader >= 31 ? 8 : reader >= 30 ? 7 : reader >= 29 ? 6 : reader >= 28 ? 5 : reader >= 27 ? 4 : reader >= 26 ? 3 : reader == 25 ? 2 : 1
        var storage: [String: Any] = ["version": storageVersion, "pointers": pointers, "profile": profile]
        root["_archiveStorage"] = storage
        storage["indexSHA256"] = digest(try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]))
        root["_archiveStorage"] = storage
        let index = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        guard index.count <= indexLimit else { throw ScholarStoreError.tooLarge }
        return index
    }
    public static func decode(_ bytes: Data, directory: URL) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw ScholarStoreError.invalidData }
        guard let storage = root.removeValue(forKey: "_archiveStorage") else { return bytes }
        guard let metadata = storage as? [String: Any], [1,2,3,4,5,6,7,8,9,10,11,12].contains(metadata["version"] as? Int ?? 0), let pointers = metadata["pointers"] as? [[String: Any]], pointers.count <= 100_000 else { throw ScholarStoreError.invalidData }
        guard let expected = metadata["indexSHA256"] as? String else { throw ScholarStoreError.invalidData }
        var unsigned = metadata, check = root
        unsigned.removeValue(forKey: "indexSHA256"); check["_archiveStorage"] = unsigned
        guard digest(try JSONSerialization.data(withJSONObject: check, options: [.sortedKeys])) == expected else { throw ScholarStoreError.invalidData }
        guard let profile = metadata["profile"] as? [String: Any], ["field", "method", "writing", "teaching"].allSatisfy({ profile[$0] is String }),
              let sentinel = root["profile"] as? [String: Any], sentinel.count == 1, sentinel["_archiveIndexOnly"] as? Bool == true else { throw ScholarStoreError.invalidData }
        root["profile"] = profile
        var used = Set<[String]>()
        var total = bytes.count
        for p in pointers {
            guard let path = p["path"] as? [String], used.insert(path).inserted, let hash = p["sha256"] as? String,
                  hash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { throw ScholarStoreError.invalidData }
            let rootPath = path.count == 1 && rootKeys.contains(path[0])
            let metaPath = path == ["meta", "recycleBin"]
            let rowPath = path.count == 3 && (recordKeys[path[0]] ?? []).contains(path[2])
            guard rootPath || metaPath || rowPath else { throw ScholarStoreError.invalidData }
            let file = directory.appendingPathComponent("archives/" + hash + ".json")
            guard try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw ScholarStoreError.invalidData }
            guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= ScholarStore.limit - total else { throw ScholarStoreError.tooLarge }
            let chunk = try Data(contentsOf: file); total += chunk.count
            guard total <= ScholarStore.limit, digest(chunk) == hash else { throw ScholarStoreError.invalidData }
            let value = try JSONSerialization.jsonObject(with: chunk, options: [.fragmentsAllowed])
            if rootPath { guard root[path[0]] is [Any], value is [Any] else { throw ScholarStoreError.invalidData }; root[path[0]] = value }
            else if metaPath { guard var meta = root["meta"] as? [String: Any], value is [Any] else { throw ScholarStoreError.invalidData }; meta["recycleBin"] = value; root["meta"] = meta }
            else { guard var rows = root[path[0]] as? [[String: Any]], let i = rows.firstIndex(where: { $0["id"] as? String == path[1] }), rows[i][path[2]] == nil else { throw ScholarStoreError.invalidData }; rows[i][path[2]] = value; root[path[0]] = rows }
        }
        let output = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]); guard output.count <= ScholarStore.limit else { throw ScholarStoreError.tooLarge }; return output
    }
}
