import AppKit
import UniformTypeIdentifiers
import KongScholarCore

extension AppDelegate {
    func checkExternalBackup(force: Bool = false) {
        guard let bookmark = UserDefaults.standard.data(forKey: "KongScholar.ExtraBackupBookmark") else { return }
        let now = Date()
        if !force {
            if let last = UserDefaults.standard.object(forKey: "KongScholar.ExtraBackupSuccess") as? Date, now.timeIntervalSince(last) < Double(store.backupPreferences().interval * 60) { return }
            if let attempt = UserDefaults.standard.object(forKey: "KongScholar.ExtraBackupAttempt") as? Date, now.timeIntervalSince(attempt) < 60 { return }
        }
        UserDefaults.standard.set(now, forKey: "KongScholar.ExtraBackupAttempt")
        do {
            var stale = false
            let folder = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
            guard !stale, let text = try store.read() else { throw ScholarStoreError.invalidData }
            let output = try BackupMirror.copy(text, into: folder)
            UserDefaults.standard.set("已校验：" + output.path, forKey: "KongScholar.ExtraBackupStatus")
            UserDefaults.standard.set(ISO8601DateFormatter().string(from: now), forKey: "KongScholar.ExtraBackupAt")
            UserDefaults.standard.set(now, forKey: "KongScholar.ExtraBackupSuccess")
        } catch { UserDefaults.standard.set("等待重试：" + error.localizedDescription, forKey: "KongScholar.ExtraBackupStatus") }
    }
    private func extraDescriptor() -> [String: Any] {
        ["enabled": UserDefaults.standard.data(forKey: "KongScholar.ExtraBackupBookmark") != nil,
         "status": UserDefaults.standard.string(forKey: "KongScholar.ExtraBackupStatus") ?? "尚未选择额外备份位置",
         "at": UserDefaults.standard.string(forKey: "KongScholar.ExtraBackupAt") ?? ""]
    }
    func advancedPrompt(_ prompt: String, text: String?, completion: @escaping (String?) -> Void) -> Bool {
        if researchPrompt(prompt, text: text, completion: completion) { return true }
        if prompt == "KONGSCHOLAR_BACKUP_HEALTH" {
            do { var report = try BackupMirror.health(store); report["extra"] = extraDescriptor(); completion(jsonString(report)) } catch { completion(jsonString(["error": error.localizedDescription, "extra": extraDescriptor()])) }; return true
        }
        if prompt == "KONGSCHOLAR_EXTRA_BACKUP" {
            if text == "choose" {
                let panel = NSOpenPanel(); panel.title = "选择额外本机或移动硬盘备份位置"; panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
                panel.beginSheetModal(for: window) { response in
                    if response == .OK, let url = panel.url { do { let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil); UserDefaults.standard.set(bookmark, forKey: "KongScholar.ExtraBackupBookmark"); self.checkExternalBackup(force: true) } catch { UserDefaults.standard.set(error.localizedDescription, forKey: "KongScholar.ExtraBackupStatus") } }
                    completion(self.jsonString(self.extraDescriptor()))
                }
            } else { if text == "disable" { UserDefaults.standard.removeObject(forKey: "KongScholar.ExtraBackupBookmark"); UserDefaults.standard.set("额外备份已停用，已有备份保留", forKey: "KongScholar.ExtraBackupStatus") }; if text == "now" { checkExternalBackup(force: true) }; completion(jsonString(extraDescriptor())) }; return true
        }
        if prompt == "KONGSCHOLAR_TEXT_IMPORT" {
            let panel = NSOpenPanel(); panel.title = "读取书目交换文件"; panel.allowedContentTypes = ["ris", "bib", "txt"].map { UTType(filenameExtension: $0) ?? .plainText }
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { completion(nil); return }
                do { guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 10 * 1024 * 1024 else { throw ScholarStoreError.tooLarge }; let value = try String(contentsOf: url, encoding: .utf8); completion(self.jsonString(["name": url.lastPathComponent, "text": value])) } catch { completion("error:" + error.localizedDescription) }
            }; return true
        }
        if prompt == "KONGSCHOLAR_ATTACHMENT_CHOOSE" {
            let panel = NSOpenPanel(); panel.title = "关联学生论文稿件（保留原文件）"; panel.allowedContentTypes = ["pdf", "docx", "md", "txt"].map { UTType(filenameExtension: $0) ?? .data }
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { completion(nil); return }
                do { let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0; guard size <= 64 * 1024 * 1024 else { throw ScholarStoreError.tooLarge }; let bytes = try Data(contentsOf: url); let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil); completion(self.jsonString(["name":url.lastPathComponent,"path":url.path,"bookmark":bookmark.base64EncodedString(),"sha256":ScholarArchive.digest(bytes),"size":size])) } catch { completion("error:" + error.localizedDescription) }
            }; return true
        }
        if prompt == "KONGSCHOLAR_ATTACHMENT_OPEN" {
            do { guard let p = try JSONSerialization.jsonObject(with: Data((text ?? "").utf8)) as? [String: Any], let name = p["path"] as? String, name.hasPrefix("/"), let hash = p["sha256"] as? String else { throw ScholarStoreError.invalidData }
                var url = URL(fileURLWithPath: name); if let b = p["bookmark"] as? String, let bytes = Data(base64Encoded: b) { var stale = false; if let resolved = try? URL(resolvingBookmarkData: bytes, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale) { url = resolved } }
                guard ["pdf","docx","md","txt"].contains(url.pathExtension.lowercased()), (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 64 * 1024 * 1024 else { throw ScholarStoreError.invalidData }
                let changed = ScholarArchive.digest(try Data(contentsOf: url)) != hash
                NSWorkspace.shared.open(url); completion(jsonString(["opened":true,"changed":changed]))
            } catch { completion("error:" + error.localizedDescription) }; return true
        }
        if prompt == "KONGSCHOLAR_CAPTURE" {
            if let bytes = text?.data(using: .utf8), let p = try? JSONDecoder().decode(FolioOrigin.self, from: bytes) {
                do { let (image, changed) = try EvidenceImage.pageImage(origin: p); captureEvidence(image, changed: changed, completion: completion) } catch { completion("error:" + error.localizedDescription) }
            } else {
                let panel = NSOpenPanel(); panel.title = "选择原文影像"; panel.allowedContentTypes = [.png, .jpeg, .tiff]
                panel.beginSheetModal(for: window) { response in
                    guard response == .OK, let url = panel.url else { completion(nil); return }
                    do { guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= EvidenceImage.maximum, let image = NSImage(contentsOf: url), image.size.width <= 6000, image.size.height <= 6000 else { throw ScholarStoreError.tooLarge }; self.captureEvidence(image, changed: false, completion: completion) } catch { completion("error:" + error.localizedDescription) }
                }
            }; return true
        }
        if prompt == "KONGSCHOLAR_OCR" {
            let input = text ?? ""
            let progress = NSPanel(contentRect: NSRect(x:0,y:0,width:380,height:110),styleMask:[.titled],backing:.buffered,defer:false)
            progress.title = "本机OCR识别"
            let label = NSTextField(labelWithString:"正在读取影像中的文字，结果仍须人工校订。")
            label.frame = NSRect(x:24,y:56,width:340,height:24)
            let spinner = NSProgressIndicator(frame:NSRect(x:178,y:18,width:24,height:24));spinner.style = .spinning;spinner.startAnimation(nil)
            progress.contentView?.addSubview(label);progress.contentView?.addSubview(spinner)
            window.beginSheet(progress)
            DispatchQueue.global(qos: .userInitiated).async { let output: String?; do { output = self.jsonString(try EvidenceImage.recognize(input)) } catch { output = "error:" + error.localizedDescription }; DispatchQueue.main.async { self.window.endSheet(progress); progress.orderOut(nil); completion(output) } }; return true
        }
        return false
    }
    private func captureEvidence(_ image: NSImage, changed: Bool, completion: @escaping (String?) -> Void) {
        let crop = EvidenceCropView(image: image), alert = NSAlert(); alert.messageText = "选择原文影像区域"; alert.informativeText = "在页面上拖动框选，未选择时保存整页。" + (changed ? "项目PDF与摘录时不同，请核对页序。" : "")
        alert.accessoryView = crop; alert.addButton(withTitle: "保存所选影像"); alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { completion(nil); return }
        do { let rect = crop.normalizedSelection, bytes = try EvidenceImage.png(image, crop: rect)
            completion(jsonString(["imageData":bytes.base64EncodedString(),"sha256":ScholarArchive.digest(bytes),"region":[rect.minX,rect.minY,rect.width,rect.height],"changed":changed,"at":ISO8601DateFormatter().string(from: Date())]))
        } catch { completion("error:" + error.localizedDescription) }
    }
}
