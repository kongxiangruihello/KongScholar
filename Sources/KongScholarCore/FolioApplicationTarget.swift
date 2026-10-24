import Foundation

public enum FolioApplicationTarget {
    public static func isModernVersion(_ version: String) -> Bool {
        let values = version.split(separator: ".").map { Int($0) ?? -1 }
        guard !values.isEmpty, values.allSatisfy({ $0 >= 0 }) else { return false }
        return version.compare("0.22.0", options: .numeric) != .orderedAscending
    }
    public static func descriptor(at url: URL) -> [String: Any] {
        let bundle = Bundle(url: url), version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let id = bundle?.bundleIdentifier ?? ""
        let bridge = bundle?.object(forInfoDictionaryKey: "KongFolioScholarBridgeVersion") as? Int ?? 0
        return ["path":url.path, "version":version, "bundleID":id, "modern":isModernVersion(version), "supported":isModernVersion(version) && bridge >= 1, "bridge":bridge]
    }
}
