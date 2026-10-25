import AppKit
import QuickLookUI
import UniformTypeIdentifiers
import KongScholarCore

extension AppDelegate {
    func continuityPrompt30(_ prompt: String, text: String?, completion: @escaping (String?) -> Void) -> Bool {
        let actions = ["KONGSCHOLAR_PROOF30", "KONGSCHOLAR_OUTBOX_LIST30", "KONGSCHOLAR_OUTBOX_ACK30", "KONGSCHOLAR_WORD_EXPORT", "KONGSCHOLAR_STAGE_EXPORT"]
        guard actions.contains(prompt) else { return false }
        do {
            if prompt == "KONGSCHOLAR_OUTBOX_LIST30" {
                researchWork("核对导出回执", completion: completion) { ["rows": try ExportOutbox30.list(root: self.store.directory)] }; return true
            }
            let bytes = Data((text ?? "{}").utf8)
            guard bytes.count <= ScholarStore.limit, let raw = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw ScholarStoreError.invalidData }
            if prompt == "KONGSCHOLAR_OUTBOX_ACK30" {
                guard let token = raw["token"] as? String, let library = try store.read() else { throw ScholarStoreError.invalidData }
                try ExportOutbox30.acknowledge(token: token, root: store.directory, library: library)
                completion(jsonString(["acknowledged": true])); return true
            }
            if prompt == "KONGSCHOLAR_PROOF30" {
                guard let payload = raw["payload"] as? [String: Any], let show = raw["show"] as? Bool else { throw ScholarStoreError.invalidData }
                let request = try JSONDecoder().decode(WordExportRequest.self, from: JSONSerialization.data(withJSONObject: payload))
                let report = try WordProof30.inspect(request)
                if show { try showWordProof30(request) }
                completion(jsonString(report)); return true
            }
            // Keep the old bridge available to older UI resources; current UI always
            // provides a full, source-local delivery snapshot before opening Save.
            guard let entry = raw["deliveryEntry30"] as? [String: Any] else { return false }
            let request: WordExportRequest, output: Data, isStage = prompt == "KONGSCHOLAR_STAGE_EXPORT"
            if isStage {
                let stage = try JSONDecoder().decode(StageExportRequest.self, from: bytes)
                request = stage.manuscript; output = try StageExport.generate(stage)
            } else {
                request = try JSONDecoder().decode(WordExportRequest.self, from: bytes); output = try WordExport.generate(request)
            }
            guard let token = request.deliveryToken29, token == entry["token"] as? String else { throw ScholarStoreError.invalidData }
            let proof = try WordProof30.inspect(request), panel = NSSavePanel()
            panel.title = "保存已生成的交稿文件"
            panel.allowedContentTypes = [isStage ? .zip : (UTType(filenameExtension: "docx") ?? .data)]
            panel.nameFieldStringValue = request.title.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_") + (isStage ? ".zip" : ".docx")
            panel.canCreateDirectories = true
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { completion(nil); return }
                do {
                    var captured = entry
                    guard var record = captured["deliveryRecord30"] as? [String: Any] else { throw ScholarStoreError.invalidData }
                    record["exportFile30"] = ["path": url.path, "sha256": ScholarArchive.digest(output), "bytes": output.count, "proof30": proof]
                    captured["deliveryRecord30"] = record
                    _ = try UpgradeProtection.protect(self.store, version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.0.0")
                    try ExportOutbox30.prepare(entry: captured, output: output, destination: url, root: self.store.directory, proof: proof)
                    try output.write(to: url, options: .atomic)
                    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                    // If this marker write fails, the already durable prepared intent
                    // is recoverable by rehashing the saved file on the next launch.
                    try? ExportOutbox30.markSaved(token: token, root: self.store.directory)
                    completion(self.jsonString(["saved": true, "entry30": captured]))
                } catch { completion("error:" + error.localizedDescription) }
            }
        } catch { completion("error:" + error.localizedDescription) }
        return true
    }
    private func showWordProof30(_ request: WordExportRequest) throws {
        let output = try WordExport.generate(request), directory = store.directory.appendingPathComponent("export-previews", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        guard files.count < 100, try files.reduce(output.count, { try $0 + ($1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? ScholarStore.limit) }) <= ScholarStore.limit else { throw ScholarStoreError.tooLarge }
        let url = directory.appendingPathComponent(ScholarArchive.digest(output) + ".docx")
        try output.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        proofWindow30?.close()
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 900, height: 760), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.title = "交稿文件预览 · " + request.title; panel.isReleasedWhenClosed = false
        guard let preview = QLPreviewView(frame: NSRect(x: 0, y: 0, width: 900, height: 760), style: .normal) else { throw ScholarStoreError.invalidData }
        preview.autoresizingMask = [.width, .height]; preview.previewItem = url as NSURL
        panel.contentView = preview; panel.center(); proofWindow30 = panel; panel.makeKeyAndOrderFront(nil)
    }
}
