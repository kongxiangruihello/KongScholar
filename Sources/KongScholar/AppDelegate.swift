import AppKit
import WebKit
import UniformTypeIdentifiers
import KongScholarCore
import Darwin

@main
final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var pdfDock28: PDFDock28?
    var proofWindow30: NSWindow?
    var chapterWindows31=[String:ChapterWindow31]()
    var sourceWindows31=[NSWindow]()
    var store: ScholarStore!
    var stagedWorkingDrafts27:Data?
    var stagedWorkingToken27=""
    private var resourceDirectory: URL!
    private var lockFD: Int32 = -1
    private var pendingFolioFiles: [URL] = []
    private var pageReady = false
    private var allowWindowClose = false
    private var backupTimer: Timer?
    private var backupError = "" { didSet { UserDefaults.standard.set(backupError, forKey: "KongScholar.BackupError") } }

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let args = ProcessInfo.processInfo.arguments
            let support: URL
            if let index = args.firstIndex(of: "--data-directory"), args.indices.contains(index + 1) {
                support = URL(fileURLWithPath: args[index + 1], isDirectory: true)
            } else if let path = Bundle.main.object(forInfoDictionaryKey: "KongScholarDataDirectory") as? String {
                support = URL(fileURLWithPath: path, isDirectory: true)
            } else {
                support = try FileManager.default.url(for: .applicationSupportDirectory,
                    in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("KongScholar", isDirectory: true)
            }
            store = try ScholarStore(directory: support)
            lockFD = open(support.appendingPathComponent(".instance-lock").path, O_CREAT | O_RDWR, 0o600)
            guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw ScholarStoreError.alreadyRunning }
            guard let root = Bundle.main.resourceURL?.appendingPathComponent("Web", isDirectory: true),
                  FileManager.default.fileExists(atPath: root.appendingPathComponent("index.html").path) else {
                throw NSError(domain: "KongScholar", code: 1, userInfo: [NSLocalizedDescriptionKey: "应用资源缺失，请重新安装完整的 KongScholar.app。"])
            }
            resourceDirectory = root
            backupError = UserDefaults.standard.string(forKey: "KongScholar.BackupError") ?? ""
            let initial = try store.readForInterface()
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.5.0"
            store.releaseVersion=version
            do {
                if UserDefaults.standard.string(forKey: "KongScholar.BackupVersion") != version {
                    try store.snapshotIfNeeded(force: true, label: "before-" + version)
                    UserDefaults.standard.set(version, forKey: "KongScholar.BackupVersion")
                }
            } catch { backupError = error.localizedDescription }
            backupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                guard let self else { return }
                do { try self.store.snapshotIfNeeded(); self.backupError = "" }
                catch { self.backupError = error.localizedDescription }
                self.checkExternalBackup()
            }
            var startupReport=StartupHealth.inspect(store,resources:root,initialText:initial)
            startupReport["release"]=version
            let startupJSON=jsonString(startupReport)
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .nonPersistent()
            let bootstrap = "window.KongScholarDesktop = Object.freeze({initialData: \(ScholarStore.javascriptLiteral(initial)), dataPath: \(ScholarStore.javascriptLiteral(store.dataURL.path)), startupReportJSON: \(ScholarStore.javascriptLiteral(startupJSON))});"
            config.userContentController.addUserScript(WKUserScript(source: bootstrap, injectionTime: .atDocumentStart, forMainFrameOnly: true))
            webView = WKWebView(frame: .zero, configuration: config)
            webView.navigationDelegate = self
            webView.uiDelegate = self
            webView.allowsBackForwardNavigationGestures = false
            webView.setValue(false, forKey: "drawsBackground")
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 850),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "KongScholar"
            window.delegate = self
            window.minSize = NSSize(width: 880, height: 620)
            window.backgroundColor = NSColor.windowBackgroundColor
            window.contentView = webView
            window.setFrameAutosaveName("KongScholarMainWindow")
            if !window.setFrameUsingName("KongScholarMainWindow") { window.center() }
            installMenu()
            webView.loadFileURL(root.appendingPathComponent("index.html"), allowingReadAccessTo: root)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } catch {
            let alert = NSAlert()
            alert.messageText = "KongScholar 无法启动"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    private func checkAutomaticBackup(force: Bool = false) {
        do { try store.snapshotIfNeeded(force: force); backupError = "" }
        catch { backupError = error.localizedDescription }
        checkExternalBackup(force: force)
    }

    private func flushWriter(_ completion: @escaping (Bool) -> Void) {
        guard pageReady, let webView else { completion(true); return }
        webView.evaluateJavaScript("typeof writerFlush === 'function' ? writerFlush() : true") { result, error in
            if error == nil && (result as? Bool) == true {self.flushDetached31(completion)}else{completion(false)}
        }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if allowWindowClose || !pageReady { return true }
        flushWriter { ok in
            guard ok else { return }
            self.checkAutomaticBackup(force: true)
            self.allowWindowClose = true
            sender.performClose(nil)
            self.allowWindowClose = false
        }
        return false
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if !pageReady { return .terminateNow }
        flushWriter { ok in
            if ok { self.checkAutomaticBackup(force: true) }
            sender.reply(toApplicationShouldTerminate: ok)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD) }
    }

    private func installMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 KongScholar", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 KongScholar", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 KongScholar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = appMenu; menu.addItem(appItem)
        let file = NSMenu(title: "文件")
        file.addItem(withTitle: "新建研究问题", action: #selector(newQuestion), keyEquivalent: "n")
        file.addItem(withTitle: "选择 KongFolio App…", action: #selector(selectFolioApp), keyEquivalent: "")
        file.addItem(withTitle: "导入 KongFolio 摘录…", action: #selector(importFolio), keyEquivalent: "i")
        file.addItem(withTitle: "导入 JSON 备份…", action: #selector(importBackup), keyEquivalent: "o")
        file.addItem(withTitle: "导出完整备份…", action: #selector(exportBackup), keyEquivalent: "s")
        file.addItem(.separator())
        file.addItem(withTitle: "显示数据文件夹", action: #selector(revealData), keyEquivalent: "")
        file.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let fileItem = NSMenuItem(title: "文件", action: nil, keyEquivalent: ""); fileItem.submenu = file; menu.addItem(fileItem)
        let edit = NSMenu(title: "编辑")
        for (title, action, key) in [("撤销", Selector(("undo:")), "z"), ("剪切", #selector(NSText.cut(_:)), "x"), ("复制", #selector(NSText.copy(_:)), "c"), ("粘贴", #selector(NSText.paste(_:)), "v"), ("全选", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        let redo = NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "z"); redo.keyEquivalentModifierMask = [.command, .shift]; edit.insertItem(redo, at: 1)
        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: ""); editItem.submenu = edit; menu.addItem(editItem)
        let view = NSMenu(title: "显示")
        view.addItem(withTitle: "放大文字", action: #selector(zoomIn), keyEquivalent: "+")
        view.addItem(withTitle: "缩小文字", action: #selector(zoomOut), keyEquivalent: "-")
        view.addItem(withTitle: "实际大小", action: #selector(resetZoom), keyEquivalent: "0")
        let viewItem = NSMenuItem(title: "显示", action: nil, keyEquivalent: ""); viewItem.submenu = view; menu.addItem(viewItem)
        let win = NSMenu(title: "窗口")
        win.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        let winItem = NSMenuItem(title: "窗口", action: nil, keyEquivalent: ""); winItem.submenu = win; menu.addItem(winItem)
        NSApp.windowsMenu = win
        let help = NSMenu(title: "帮助")
        help.addItem(withTitle: "KongScholar 使用说明", action: #selector(showHelp), keyEquivalent: "")
        let helpItem = NSMenuItem(title: "帮助", action: nil, keyEquivalent: ""); helpItem.submenu = help; menu.addItem(helpItem)
        NSApp.mainMenu = menu
    }

    private func invoke(_ code: String) { webView?.evaluateJavaScript(code, completionHandler: nil) }
    @objc private func newQuestion() { invoke("if (!document.querySelector('dialog').open) openForm('questions');") }
    @objc private func selectFolioApp() { invoke("chooseFolioApplication();") }
    @objc private func importFolio() { invoke("openFolioImport();") }
    @objc private func importBackup() { invoke("nativeImportBackup();") }
    @objc private func exportBackup() { invoke("if (!document.querySelector('dialog').open) exportBackup();") }
    @objc private func revealData() { NSWorkspace.shared.open(store.directory) }
    @objc private func zoomIn() { webView.pageZoom = min(1.6, webView.pageZoom + 0.1) }
    @objc private func zoomOut() { webView.pageZoom = max(0.8, webView.pageZoom - 0.1) }
    @objc private func resetZoom() { webView.pageZoom = 1 }
    @objc private func about() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "KongScholar", .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0", .version: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "4",
            .credits: NSAttributedString(string: "何以为士：林乐知与晚清士大夫的重塑\n个人学术工作台 · 离线 Mac 版")
        ])
    }
    @objc private func showHelp() {
        if let help = Bundle.main.resourceURL?.appendingPathComponent("使用说明.html") { NSWorkspace.shared.open(help) }
    }

    private func isTrusted(_ frame: WKFrameInfo) -> Bool {
        guard frame.isMainFrame, let url = frame.request.url, url.isFileURL else { return false }
        return url.standardizedFileURL.path.hasPrefix(resourceDirectory.standardizedFileURL.path + "/")
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if url.isFileURL && url.standardizedFileURL.path.hasPrefix(resourceDirectory.standardizedFileURL.path + "/") {
            decisionHandler(.allow)
        } else {
            if action.navigationType == .linkActivated, ["https", "http"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        guard isTrusted(frame) else { completionHandler(nil); return }
        if advancedPrompt(prompt, text: defaultText, completion: completionHandler) { return }
        if prompt == "KONGSCHOLAR_WRITE" {
            do { try store.write(defaultText ?? ""); checkAutomaticBackup(); completionHandler("ok") }
            catch { completionHandler("error:" + error.localizedDescription) }
        } else if prompt == "KONGSCHOLAR_HEALTH" {
            do {
                let bytes = Data((defaultText ?? "[]").utf8)
                guard bytes.count <= ScholarStore.limit else { throw ScholarStoreError.tooLarge }
                let origins = try JSONDecoder().decode([FolioOrigin].self, from: bytes)
                let results = origins.map { origin -> String in
                    do {
                        try origin.validate()
                        guard let file = origin.resolvedFileURL() else { return "项目缺失或已移动" }
                        let id = try FolioOrigin.projectID(at: file)
                        return id.lowercased() == origin.documentID.lowercased() ? "项目可读取且文档编号一致" : "项目文档编号不符"
                    } catch { return error.localizedDescription }
                }
                completionHandler(jsonString(results))
            } catch { completionHandler(jsonString([error.localizedDescription])) }
        } else if prompt == "KONGSCHOLAR_BACKUP_STATUS33" {
            do {
                let files = try store.backupFiles()
                let latest = files.first
                let at = latest.flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
                completionHandler(jsonString(["latestAt": at.map { ISO8601DateFormatter().string(from: $0) } ?? "", "automaticCount": files.filter { $0.lastPathComponent.contains("-auto-") }.count, "error": backupError, "path": store.backupURL.path, "hasData": FileManager.default.fileExists(atPath: store.dataURL.path)]))
            } catch { completionHandler(jsonString(["error": error.localizedDescription])) }
        } else if prompt == "KONGSCHOLAR_BACKUPS" {
            do {
                let files = try store.backupFiles().map { url -> [String: Any] in
                    let text = try? self.store.backupText(named: url.lastPathComponent)
                    return ["name": url.lastPathComponent, "valid": text != nil, "at": (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate).map { ISO8601DateFormatter().string(from: $0) } ?? ""]
                }
                completionHandler(jsonString(["files": files, "error": backupError, "path": store.backupURL.path]))
            } catch { completionHandler(jsonString(["files": [], "error": error.localizedDescription])) }
        } else if prompt == "KONGSCHOLAR_SNAPSHOT" {
            do { try store.snapshotIfNeeded(force: true, label: "manual"); backupError = ""; completionHandler("ok") }
            catch { backupError = error.localizedDescription; completionHandler("error:" + backupError) }
        } else if prompt == "KONGSCHOLAR_SNAPSHOT_READ" {
            do { completionHandler(try store.backupText(named: defaultText ?? "")) }
            catch { completionHandler(nil) }
        } else if prompt == "KONGSCHOLAR_EXPORT" {
            guard let text = defaultText?.data(using: .utf8),
                  let payload = try? JSONSerialization.jsonObject(with: text) as? [String: String],
                  let name = payload["name"], let content = payload["text"] else { completionHandler(nil); return }
            let panel = NSSavePanel()
            panel.title = "导出 KongScholar 文件"
            panel.nameFieldStringValue = URL(fileURLWithPath: name).lastPathComponent
            panel.canCreateDirectories = true
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { completionHandler("cancelled"); return }
                do { try content.write(to: url, atomically: true, encoding: .utf8); completionHandler("saved") }
                catch { completionHandler("error:" + error.localizedDescription) }
            }
        } else if prompt == "KONGSCHOLAR_FOLIO_TARGET" {
            completionHandler(jsonString(FolioApplicationTarget.descriptor(at: targetFolioURL())))
        } else if prompt == "KONGSCHOLAR_FOLIO_CHOOSE" {
            let panel = NSOpenPanel(); panel.title = "选择文稿目录中的 KongFolio App"; panel.allowedContentTypes = [.application]; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { completionHandler(nil); return }
                let info = FolioApplicationTarget.descriptor(at: url)
                guard info["bundleID"] as? String == "com.kongfolio.mac", info["modern"] as? Bool == true else { self.presentError("请选择 KongFolio 0.22 或更新版；此前的 0.4 / 0.5 联动构建不作为目标。"); completionHandler(nil); return }
                UserDefaults.standard.set(url.path, forKey: "KongScholar.FolioApplicationPath")
                if let bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) { UserDefaults.standard.set(bookmark, forKey: "KongScholar.FolioApplicationBookmark") }
                completionHandler(self.jsonString(info))
            }
        } else if prompt == "KONGSCHOLAR_STAGE_EXPORT" {
            do {
                let bytes = Data((defaultText ?? "").utf8)
                guard bytes.count <= ScholarStore.limit else { throw StageExportError.tooLarge }
                let request = try JSONDecoder().decode(StageExportRequest.self, from: bytes)
                let output = try StageExport.generate(request)
                let panel = NSSavePanel(); panel.title = "导出阶段成果包"; panel.allowedContentTypes = [.zip]
                panel.nameFieldStringValue = request.title.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_") + ".zip"
                panel.canCreateDirectories = true
                panel.beginSheetModal(for: window) { response in
                    guard response == .OK, let url = panel.url else { completionHandler(nil); return }
                    do { try output.write(to: url, options: .atomic); completionHandler("saved") }
                    catch { completionHandler("error:" + error.localizedDescription) }
                }
            } catch { completionHandler("error:" + error.localizedDescription) }
        } else if prompt == "KONGSCHOLAR_WORD_EXPORT" {
            do {
                let bytes = Data((defaultText ?? "").utf8)
                guard bytes.count <= ScholarStore.limit else { throw WordExportError.tooLarge }
                let request = try JSONDecoder().decode(WordExportRequest.self, from: bytes)
                let output = try WordExport.generate(request)
                let panel = NSSavePanel(); panel.allowedContentTypes = [UTType(filenameExtension: "docx") ?? .data]
                panel.nameFieldStringValue = request.title.replacingOccurrences(of: "/", with: "_") + ".docx"
                panel.beginSheetModal(for: window) { response in
                    guard response == .OK, let url = panel.url else { completionHandler(nil); return }
                    do { try output.write(to: url, options: .atomic); completionHandler("saved") }
                    catch { completionHandler("error:" + error.localizedDescription) }
                }
            } catch { completionHandler("error:" + error.localizedDescription) }
        } else if prompt == "KONGSCHOLAR_FOLIO_IMPORT" {
            let panel = NSOpenPanel(); panel.title = "导入 KongFolio 摘录包或 Markdown 摘要"
            panel.allowedContentTypes = [.json, UTType(filenameExtension: "md") ?? .plainText]
            panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { completionHandler(nil); return }
                do {
                    let payload = try self.readExchange(url)
                    completionHandler(self.jsonString(payload))
                } catch { self.presentError(error.localizedDescription); completionHandler(nil) }
            }
        } else if prompt == "KONGSCHOLAR_FOLIO_OPEN" {
            do {
                let origin = try JSONDecoder().decode(FolioOrigin.self, from: Data((defaultText ?? "").utf8)); try origin.validate()
                guard let file = origin.resolvedFileURL() else { completionHandler(self.jsonString(["status": "missing", "message": "原项目已移动或尚未关联，请点“重新关联项目”。"])); return }
                let link = try origin.deepLink(fileURL: file)
                guard let app = self.folioApplication() else { completionHandler(self.jsonString(["status":"error", "message":"当前绑定的 KongFolio 尚不支持联动。请使用基于文稿 0.22 的 0.22.1 联动补丁，并通过“选择 KongFolio App…”确认路径。"])); return }
                let launch = NSWorkspace.OpenConfiguration(); launch.createsNewApplicationInstance = false
                var requestedLink = link
                if Bundle.main.object(forInfoDictionaryKey:"KongFolioPeerBundleID") != nil,
                   let types = Bundle(url:app)?.object(forInfoDictionaryKey:"CFBundleURLTypes") as? [[String:Any]],
                   let scheme = (types.first?["CFBundleURLSchemes"] as? [String])?.first,
                   var parts = URLComponents(url:link,resolvingAgainstBaseURL:false) {
                    parts.scheme = scheme; requestedLink = parts.url ?? link
                }
                NSWorkspace.shared.open([requestedLink], withApplicationAt: app, configuration: launch) { _, error in
                    let bookmark = try? file.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                    let result = self.jsonString(["status": error == nil ? "opened" : "error", "message": error?.localizedDescription ?? "已请求 KongFolio 核对并定位原文", "filePath": file.path, "bookmarkData": bookmark?.base64EncodedString() ?? ""])
                    DispatchQueue.main.async { completionHandler(result) }
                }
            } catch { completionHandler(jsonString(["status":"error", "message":error.localizedDescription])) }
        } else if prompt == "KONGSCHOLAR_FOLIO_RELINK" {
            do {
                let origin = try JSONDecoder().decode(FolioOrigin.self, from: Data((defaultText ?? "").utf8)); try origin.validate()
                let panel = NSOpenPanel(); panel.title = "重新关联原 KongFolio 项目"; panel.allowedContentTypes = [UTType(filenameExtension: "kongfolio") ?? .data]; panel.allowsMultipleSelection = false
                panel.beginSheetModal(for: window) { response in
                    guard response == .OK, let url = panel.url else { completionHandler(nil); return }
                    do {
                        let id = try FolioOrigin.projectID(at: url)
                        guard origin.legacy == true || id.lowercased() == origin.documentID.lowercased() else { throw NSError(domain:"KongScholar",code:21,userInfo:[NSLocalizedDescriptionKey:"此项目的文档编号与摘录不符，未修改关联。"] ) }
                        let bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                        completionHandler(self.jsonString(["filePath":url.path,"documentID":id,"bookmarkData":bookmark?.base64EncodedString() ?? ""]))
                    } catch { self.presentError(error.localizedDescription); completionHandler(nil) }
                }
            } catch { completionHandler(nil) }
        } else if prompt == "KONGSCHOLAR_IMPORT" {
            let panel = NSOpenPanel()
            panel.title = "选择 KongScholar / 史序 JSON 备份"
            panel.allowedContentTypes = [.json]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { completionHandler(nil); return }
                do {
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= ScholarStore.limit else { throw ScholarStoreError.tooLarge }
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let payload: [String: Any] = ["name": url.lastPathComponent, "text": content, "size": content.utf8.count]
                    let bytes = try JSONSerialization.data(withJSONObject: payload)
                    completionHandler(String(data: bytes, encoding: .utf8))
                } catch { self.presentError(error.localizedDescription); completionHandler(nil) }
            }
        } else { completionHandler(nil) }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard isTrusted(frame) else { completionHandler(); return }
        let alert = NSAlert(); alert.messageText = "KongScholar"; alert.informativeText = message
        alert.beginSheetModal(for: window) { _ in completionHandler() }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard isTrusted(frame) else { completionHandler(false); return }
        let alert = NSAlert(); alert.messageText = "请确认"; alert.informativeText = message
        alert.addButton(withTitle: "确认"); alert.addButton(withTitle: "取消")
        alert.beginSheetModal(for: window) { response in completionHandler(response == .alertFirstButtonReturn) }
    }
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        guard isTrusted(frame) else { completionHandler(nil); return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { completionHandler($0 == .OK ? panel.urls : nil) }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.scheme?.lowercased() == "kongscholar", parts.host == "import" else { continue }
            let items = parts.queryItems ?? []
            guard items.count == 1, items[0].name == "file", let path = items[0].value, path.hasPrefix("/"), URL(fileURLWithPath: path).pathExtension.lowercased() == "json" else { continue }
            if pendingFolioFiles.count < 10 { pendingFolioFiles.append(URL(fileURLWithPath: path)) }
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        deliverFolioFiles()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true; deliverFolioFiles()
    }
    private func deliverFolioFiles() {
        guard pageReady, !pendingFolioFiles.isEmpty else { return }
        let files = pendingFolioFiles; pendingFolioFiles = []
        for file in files {
            do {
                let payload = try readExchange(file)
                invoke("nativePreviewFolioPackage(" + (jsonString(payload) ?? "null") + ");")
            } catch { presentError(error.localizedDescription) }
        }
    }
    private func readExchange(_ url: URL) throws -> [String: Any] {
        guard url.isFileURL, ["json", "md"].contains(url.pathExtension.lowercased()),
              let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= ScholarStore.limit else { throw ScholarStoreError.tooLarge }
        let text = try String(contentsOf: url, encoding: .utf8)
        if url.pathExtension.lowercased() == "json" {
            guard let value = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any], value["format"] as? String == "KongFolioScholar", value["version"] as? Int == 1 else { throw NSError(domain:"KongScholar",code:22,userInfo:[NSLocalizedDescriptionKey:"这不是 KongFolio 结构化摘录包。完整研究备份请从“导入 JSON 备份”恢复。"] ) }
        }
        return ["name":url.lastPathComponent,"text":text,"size":text.utf8.count]
    }
    func jsonString(_ value: Any) -> String? {
        guard let bytes = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]) else { return nil }
        return String(data: bytes, encoding: .utf8)?.replacingOccurrences(of: "\u{2028}", with: "\\u2028").replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
    private func targetFolioURL() -> URL {
        if let peer = Bundle.main.object(forInfoDictionaryKey: "KongFolioPeerBundleID") as? String,
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == peer })?.bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: peer) { return app }
        if let bytes = UserDefaults.standard.data(forKey: "KongScholar.FolioApplicationBookmark") {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bytes, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale), FileManager.default.fileExists(atPath: url.path) { return url }
        }
        let path = UserDefaults.standard.string(forKey: "KongScholar.FolioApplicationPath")
        return path.map { URL(fileURLWithPath:$0) } ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/KongFolio.app")
    }
    private func folioApplication() -> URL? {
        let url = targetFolioURL(), info = FolioApplicationTarget.descriptor(at:url)
        return info["supported"] as? Bool == true ? url : nil
    }
    private func presentError(_ message: String) {
        let alert = NSAlert(); alert.messageText = "操作未完成"; alert.informativeText = message
        alert.beginSheetModal(for: window)
    }
}
