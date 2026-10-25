import AppKit
import UniformTypeIdentifiers
import WebKit
import KongScholarCore

extension AppDelegate {
    func showGuide37() { HelpPanel37.open() }
    func calendarPrompt37(_ action:String,text:String?,completion:@escaping(String?)->Void)->Bool {
        if action=="KONGSCHOLAR_HELP_OPEN37" {showGuide37();completion(jsonString(["opened":true]));return true}
        guard ["KONGSCHOLAR_ICS_IMPORT37","KONGSCHOLAR_ICS_PREPARE37","KONGSCHOLAR_ICS_EXPORT37"].contains(action) else {return false}
        if action=="KONGSCHOLAR_ICS_IMPORT37" {
            let panel=NSOpenPanel();panel.title="选择iCalendar文件（先预览，不写入）";panel.allowedContentTypes=[UTType(filenameExtension:"ics") ?? .plainText,UTType(filenameExtension:"ical") ?? .plainText];panel.allowsMultipleSelection=false
            panel.beginSheetModal(for:window){r in guard r == .OK,let file=panel.url else{completion(nil);return};self.researchWork("检查日历日期、时区与重复标识",completion:completion){guard (try file.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max)<=CalendarICS37.limit else{throw CalendarICS37.Failure("日历文件超过2MB")};var result=try CalendarICS37.inspect(Data(contentsOf:file));result["name"]=file.lastPathComponent;return result}};return true
        }
        do {
            let bytes=Data((text ?? "{}").utf8);guard bytes.count<=8*1024*1024,let input=try JSONSerialization.jsonObject(with:bytes) as? [String:Any] else {throw ScholarStoreError.invalidData}
            if action=="KONGSCHOLAR_ICS_PREPARE37" {guard let events=input["events"] as? [[String:Any]] else {throw ScholarStoreError.invalidData};researchWork("生成并校验iCalendar预览",completion:completion){let bytes=try CalendarICS37.generate(events),check=try CalendarICS37.inspect(bytes,maximumEvents:5000);guard (check["events"] as? [[String:Any]])?.count==events.count,(check["skipped"] as? [[String:Any]])?.isEmpty==true else{throw ScholarStoreError.invalidData};return["text":String(decoding:bytes,as:UTF8.self),"sha256":ScholarArchive.digest(bytes),"bytes":bytes.count,"timeZone":TimeZone.current.identifier,"count":events.count]};return true}
            guard let content=input["text"] as? String,let expected=input["sha256"] as? String else{throw ScholarStoreError.invalidData};let payload=Data(content.utf8);guard payload.count<=CalendarICS37.limit,ScholarArchive.digest(payload)==expected else{throw ScholarStoreError.invalidData};let checked=try CalendarICS37.inspect(payload,maximumEvents:5000);guard !(checked["events"] as? [[String:Any]] ?? []).isEmpty,(checked["skipped"] as? [[String:Any]])?.isEmpty==true else{throw ScholarStoreError.invalidData}
            let panel=NSSavePanel();panel.title="导出已预览的iCalendar日历";panel.nameFieldStringValue="KongScholar-学术日历.ics";panel.allowedContentTypes=[UTType(filenameExtension:"ics") ?? .plainText]
            panel.beginSheetModal(for:window){r in guard r == .OK,let file=panel.url else{completion(nil);return};do{try payload.write(to:file,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path);guard try Data(contentsOf:file)==payload else{throw ScholarStoreError.invalidData};completion(self.jsonString(["path":file.path,"bytes":payload.count,"sha256":expected]))}catch{completion("error:"+error.localizedDescription)}}
        }catch{completion("error:"+error.localizedDescription)}
        return true
    }
}

/// The full offline guide opens independently, so an unfinished editing form remains intact.
final class HelpPanel37: NSWindowController, WKNavigationDelegate {
    private static var instance: HelpPanel37?
    static func open(){if instance==nil {instance=HelpPanel37()};instance?.showWindow(nil);instance?.window?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
    private init(){
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:980,height:780),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false);window.title="KongScholar 帮助说明";window.isReleasedWhenClosed=false;window.center();super.init(window:window)
        let view=WKWebView(frame:window.contentView!.bounds);view.autoresizingMask=[.width,.height];view.navigationDelegate=self;window.contentView=view
        if let file=Bundle.main.resourceURL?.appendingPathComponent("使用说明.html"){view.loadFileURL(file,allowingReadAccessTo:file.deletingLastPathComponent())}
    }
    required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
    func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void){
        guard let url=navigationAction.request.url else{decisionHandler(.cancel);return}
        if url.isFileURL,let root=Bundle.main.resourceURL,url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path+"/"){decisionHandler(.allow)}else if navigationAction.navigationType == .linkActivated,["https","http"].contains(url.scheme ?? ""){NSWorkspace.shared.open(url);decisionHandler(.cancel)}else{decisionHandler(.cancel)}
    }
}
