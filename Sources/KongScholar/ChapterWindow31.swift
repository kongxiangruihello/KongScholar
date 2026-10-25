import AppKit
import KongScholarCore

final class ChapterWindow31:NSObject,NSWindowDelegate,NSTextViewDelegate {
    weak var owner:AppDelegate?
    let panel:NSWindow,editor=NSTextView(),status=NSTextField(labelWithString:"正文标记与脚注编号会保留；此窗口编辑正文，脚注请在主窗口核对。")
    var draft:WindowDraft31,dirty=false,saving=false,pending:DispatchWorkItem?
    init(owner:AppDelegate,draft:WindowDraft31,recovered:Bool){
        self.owner=owner;self.draft=draft;panel=NSWindow(contentRect:NSRect(x:0,y:0,width:900,height:740),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false);super.init()
        panel.title="独立写作 · "+draft.title;panel.delegate=self;panel.isReleasedWhenClosed=false;panel.minSize=NSSize(width:600,height:400)
        let save=NSButton(title:"保存到章节",target:self,action:#selector(saveClick)),copy=NSButton(title:"另存窗口文字…",target:self,action:#selector(exportText)),bar=NSStackView(views:[save,copy]);bar.orientation = .horizontal;bar.spacing=10
        let scroll=NSScrollView();scroll.hasVerticalScroller=true;scroll.borderType = .noBorder;editor.frame=NSRect(x:0,y:0,width:900,height:650);editor.minSize=NSSize(width:0,height:650);editor.maxSize=NSSize(width:Double.greatestFiniteMagnitude,height:Double.greatestFiniteMagnitude);editor.isRichText=false;editor.isAutomaticQuoteSubstitutionEnabled=false;editor.isAutomaticDashSubstitutionEnabled=false;editor.isAutomaticTextReplacementEnabled=false;editor.font = .systemFont(ofSize:16);editor.textContainerInset=NSSize(width:24,height:20);editor.isVerticallyResizable=true;editor.isHorizontallyResizable=false;editor.autoresizingMask=[.width];editor.textContainer?.widthTracksTextView=true;editor.string=draft.body;editor.delegate=self;scroll.documentView=editor
        let content=NSView();panel.contentView=content;for v in [bar,status,scroll] as [NSView]{content.addSubview(v);v.translatesAutoresizingMaskIntoConstraints=false}
        NSLayoutConstraint.activate([bar.topAnchor.constraint(equalTo:content.topAnchor,constant:12),bar.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:12),status.topAnchor.constraint(equalTo:bar.bottomAnchor,constant:10),status.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:12),status.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-12),scroll.topAnchor.constraint(equalTo:status.bottomAnchor,constant:10),scroll.leadingAnchor.constraint(equalTo:content.leadingAnchor),scroll.trailingAnchor.constraint(equalTo:content.trailingAnchor),scroll.bottomAnchor.constraint(equalTo:content.bottomAnchor)])
        dirty=recovered;if recovered{status.stringValue="已载入独立草稿，尚未写入正式章节；主稿变化时会阻止覆盖。"};panel.center()
    }
    func textDidChange(_ notification:Notification){dirty=true;draft.body=editor.string;status.stringValue="独立草稿正在保存；正式章节需点击保存。";pending?.cancel();let work=DispatchWorkItem{[weak self]in _ = self?.keepDraft()};pending=work;DispatchQueue.main.asyncAfter(deadline:.now()+0.6,execute:work)}
    @discardableResult func keepDraft()->Bool{guard let owner else{return false};do{draft.body=editor.string;draft.at=ISO8601DateFormatter().string(from:Date());_ = try UpgradeProtection.protect(owner.store,version:Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "3.1.0");try WindowDrafts31.save(draft,root:owner.store.directory);status.stringValue="独立草稿已保存在本机，尚未写入正式章节。";return true}catch{status.stringValue="独立草稿未保存："+error.localizedDescription;return false}}
    @objc func saveClick(){save{_ in}}
    func save(_ completion:@escaping(Bool)->Void){
        guard dirty else{completion(true);return};guard !saving,let owner else{completion(false);return};pending?.cancel();guard keepDraft() else{completion(false);return};saving=true;editor.isEditable=false
        guard let text=owner.jsonString(["id":draft.chapterID,"body":editor.string,"basis":draft.basis]) else{saving=false;editor.isEditable=true;status.stringValue="文字尚未保存到章节，独立草稿保留。";completion(false);return}
        owner.webView.evaluateJavaScript("saveDetached31(\(text))"){[weak self]result,error in guard let self else{completion(false);return};self.saving=false;self.editor.isEditable=true
            guard error==nil,let r=result as? [String:Any],r["saved"] as? Bool==true,let basis=r["basis"] as? String else{self.status.stringValue=(result as? [String:Any])?["message"] as? String ?? (error.map{"尚未保存到正式章节："+$0.localizedDescription} ?? "尚未保存到正式章节；窗口文字与独立草稿保留。");completion(false);return}
            self.draft.basis=basis;self.dirty=false;do{try WindowDrafts31.remove(key:self.draft.key,root:owner.store.directory);self.status.stringValue="已保存到章节；与主窗口共用同一正式稿。"}catch{self.status.stringValue="正式稿已保存，独立草稿尚未清理。"};completion(true)
        }
    }
    @objc func exportText(){let p=NSSavePanel();p.nameFieldStringValue=draft.title+"-独立窗口.txt";p.beginSheetModal(for:panel){r in guard r == .OK,let url=p.url else{return};do{try self.editor.string.write(to:url,atomically:true,encoding:.utf8)}catch{self.status.stringValue="另存失败："+error.localizedDescription}}}
    func windowShouldClose(_ sender:NSWindow)->Bool{guard dirty else{return true};let a=NSAlert();a.messageText="此独立窗口有未写入章节的修改";a.informativeText="可以保存到章节，或保留本机独立草稿后关闭。";a.addButton(withTitle:"保存到章节");a.addButton(withTitle:"保留草稿并关闭");a.addButton(withTitle:"取消");let choice=a.runModal();if choice == .alertFirstButtonReturn{save{ok in if ok{sender.performClose(nil)}};return false};if choice == .alertSecondButtonReturn{return keepDraft()};return false}
    func windowWillClose(_ notification:Notification){pending?.cancel();owner?.chapterWindows31.removeValue(forKey:draft.chapterID)}
}
extension AppDelegate {
    func flushDetached31(_ completion:@escaping(Bool)->Void){
        let windows=Array(chapterWindows31.values)
        func next(_ i:Int){if i>=windows.count{completion(true);return};windows[i].save{ok in if ok{next(i+1)}else{windows[i].panel.makeKeyAndOrderFront(nil);completion(false)}}};next(0)
    }
    func studioPrompt31(_ action:String,text:String?,completion:@escaping(String?)->Void)->Bool{
        guard ["KONGSCHOLAR_CHAPTER_WINDOW31","KONGSCHOLAR_WINDOW_DRAFTS31","KONGSCHOLAR_WINDOW_RESTORE31","KONGSCHOLAR_SOURCE_WINDOW31"].contains(action) else{return false}
        do{
            if action=="KONGSCHOLAR_WINDOW_DRAFTS31"{let rows=try WindowDrafts31.list(root:store.directory),bytes=try JSONEncoder().encode(rows);completion("{\"rows\":"+String(data:bytes,encoding:.utf8)!+"}");return true}
            let bytes=Data((text ?? "{}").utf8);guard bytes.count<=32*1024*1024,let p=try JSONSerialization.jsonObject(with:bytes) as? [String:Any] else{throw ScholarStoreError.invalidData}
            if action=="KONGSCHOLAR_SOURCE_WINDOW31"{guard let title=p["title"] as? String,let body=p["body"] as? String,body.utf8.count<=8*1024*1024 else{throw ScholarStoreError.invalidData};let editor=NSTextView();editor.isEditable=false;editor.font = .systemFont(ofSize:16);editor.textContainerInset=NSSize(width:20,height:20);editor.string=body;editor.isHorizontallyResizable=false;editor.textContainer?.widthTracksTextView=true;let scroll=NSScrollView(frame:NSRect(x:0,y:0,width:650,height:700));scroll.hasVerticalScroller=true;scroll.documentView=editor;editor.frame=scroll.bounds;editor.minSize=NSSize(width:0,height:0);editor.maxSize=NSSize(width:Double.greatestFiniteMagnitude,height:Double.greatestFiniteMagnitude);editor.isVerticallyResizable=true;editor.autoresizingMask=[.width];let w=NSWindow(contentRect:scroll.bounds,styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false);w.title="资料快照 · "+title;w.isReleasedWhenClosed=false;w.contentView=scroll;w.center();w.makeKeyAndOrderFront(nil);self.sourceWindows31.removeAll{!$0.isVisible};self.sourceWindows31.append(w);completion(jsonString(["opened":true]));return true}
            let draft:WindowDraft31,recovered:Bool
            if action=="KONGSCHOLAR_WINDOW_RESTORE31"{guard let key=p["key"] as? String,let old=try WindowDrafts31.list(root:store.directory).first(where:{$0.key==key}) else{throw ScholarStoreError.invalidData};draft=old;recovered=true}
            else{guard let id=p["id"] as? String,let title=p["title"] as? String,let body=p["body"] as? String,let basis=p["basis"] as? String else{throw ScholarStoreError.invalidData};draft=WindowDraft31(key:UUID().uuidString,chapterID:id,title:title,body:body,basis:basis,at:ISO8601DateFormatter().string(from:Date()));recovered=false}
            if let existing=chapterWindows31[draft.chapterID]{existing.panel.makeKeyAndOrderFront(nil);completion(jsonString(["opened":true,"existing":true]));return true}
            guard chapterWindows31.count<20 else{throw ScholarStoreError.tooLarge};let w=ChapterWindow31(owner:self,draft:draft,recovered:recovered);chapterWindows31[draft.chapterID]=w;w.panel.makeKeyAndOrderFront(nil);completion(jsonString(["opened":true]))
        }catch{completion("error:"+error.localizedDescription)};return true
    }
}
