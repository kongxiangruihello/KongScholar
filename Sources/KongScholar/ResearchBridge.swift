import AppKit
import PDFKit
import UniformTypeIdentifiers
import KongScholarCore

private enum ResearchPDFWindows { static var windows=[NSWindow]() }
extension AppDelegate {
    func researchWork(_ title:String, completion:@escaping(String?)->Void, operation:@escaping() throws -> [String:Any]) {
        let progress=NSPanel(contentRect:NSRect(x:0,y:0,width:380,height:100),styleMask:[.titled],backing:.buffered,defer:false);progress.title=title
        let label=NSTextField(labelWithString:"正在本机处理，请稍候…");label.frame=NSRect(x:24,y:52,width:330,height:24)
        let spinner=NSProgressIndicator(frame:NSRect(x:178,y:16,width:24,height:24));spinner.style = .spinning;spinner.startAnimation(nil);progress.contentView?.addSubview(label);progress.contentView?.addSubview(spinner);window.beginSheet(progress)
        DispatchQueue.global(qos:.userInitiated).async {let result:String?;do {result=self.jsonString(try operation())}catch {result="error:"+error.localizedDescription};DispatchQueue.main.async{self.window.endSheet(progress);progress.orderOut(nil);completion(result)}}
    }
    private func researchInput(_ text:String?) throws -> [String:Any] {
        let bytes=Data((text ?? "").utf8);guard bytes.count<=ScholarStore.limit,let p=try JSONSerialization.jsonObject(with:bytes) as? [String:Any] else {throw ScholarStoreError.invalidData};return p
    }
    func indexedPDF(_ p:[String:Any]) throws -> (URL,Data) {
        guard let path=p["path"] as? String,path.hasPrefix("/"),let hash=p["sha256"] as? String else {throw ScholarStoreError.invalidData}
        var url=URL(fileURLWithPath:path)
        if let value=p["bookmark"] as? String,let b=Data(base64Encoded:value) {var stale=false;if let resolved=try? URL(resolvingBookmarkData:b,options:[.withoutUI,.withoutMounting],relativeTo:nil,bookmarkDataIsStale:&stale){url=resolved}}
        let info=try url.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey]);guard info.isRegularFile==true,(info.fileSize ?? Int.max)<=256*1024*1024 else {throw ScholarStoreError.tooLarge}
        let bytes:Data
        if let id=p["documentID"] as? String,!id.isEmpty {bytes=try EvidenceImage.pdfData(at:url,expectedID:id)}else{guard url.pathExtension.lowercased()=="pdf" else {throw ScholarStoreError.invalidData};bytes=try Data(contentsOf:url)}
        guard ScholarArchive.digest(bytes)==hash else {throw NSError(domain:"KongScholar",code:25,userInfo:[NSLocalizedDescriptionKey:"原PDF与索引时不同，请先重新建立索引；旧检索结果仍保留。"])};return(url,bytes)
    }
    func researchPrompt(_ prompt:String,text:String?,completion:@escaping(String?)->Void)->Bool {
        if materialPrompt28(prompt,text:text,completion:completion) {return true}
        if personalPrompt(prompt,text:text,completion:completion) {return true}
        if prompt == "KONGSCHOLAR_PDF_INDEX" {
            let make:(URL,String)->Void={url,documentID in self.researchWork("建立本机PDF索引",completion:completion){
                let bytes:Data;if documentID.isEmpty {guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max)<=256*1024*1024 else {throw ScholarStoreError.tooLarge};bytes=try Data(contentsOf:url)}else{bytes=try EvidenceImage.pdfData(at:url,expectedID:documentID)}
                var report=try LocalPDFIndex.build(bytes:bytes);report["path"]=url.path;report["name"]=url.lastPathComponent;report["documentID"]=documentID;report["bookmark"]=try url.bookmarkData(options:.minimalBookmark,includingResourceValuesForKeys:nil,relativeTo:nil).base64EncodedString();return report
            }}
            if let text=text,!text.isEmpty {do{let origin=try JSONDecoder().decode(FolioOrigin.self,from:Data(text.utf8));try origin.validate();guard let url=origin.resolvedFileURL() else{throw ScholarStoreError.invalidData};make(url,origin.documentID)}catch{completion("error:"+error.localizedDescription)}}
            else {let panel=NSOpenPanel();panel.title="选择要在本机建立文字索引的PDF";panel.allowedContentTypes=[.pdf];panel.beginSheetModal(for:window){r in guard r == .OK,let url=panel.url else{completion(nil);return};make(url,"")}};return true
        }
        if prompt == "KONGSCHOLAR_PDF_REINDEX" {
            do {let p=try researchInput(text);guard let path=p["path"] as? String,path.hasPrefix("/") else{throw ScholarStoreError.invalidData};var url=URL(fileURLWithPath:path)
                if let value=p["bookmark"] as? String,let b=Data(base64Encoded:value){var stale=false;if let resolved=try? URL(resolvingBookmarkData:b,options:[.withoutUI,.withoutMounting],relativeTo:nil,bookmarkDataIsStale:&stale){url=resolved}}
                let file=url;researchWork("重新建立PDF索引",completion:completion){let id=p["documentID"] as? String ?? "",bytes:Data;if id.isEmpty{guard file.pathExtension.lowercased()=="pdf",(try file.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max)<=256*1024*1024 else{throw ScholarStoreError.tooLarge};bytes=try Data(contentsOf:file)}else{bytes=try EvidenceImage.pdfData(at:file,expectedID:id)};var report=try LocalPDFIndex.build(bytes:bytes);report["path"]=file.path;report["name"]=file.lastPathComponent;report["documentID"]=id;report["bookmark"]=try file.bookmarkData(options:.minimalBookmark,includingResourceValuesForKeys:nil,relativeTo:nil).base64EncodedString();return report}
            }catch{completion("error:"+error.localizedDescription)};return true
        }
        if prompt == "KONGSCHOLAR_PDF_VIEW" {
            do{let p=try researchInput(text),(_,bytes)=try indexedPDF(p);guard let number=p["page"] as? Int,let doc=PDFDocument(data:bytes),let page=doc.page(at:number-1) else{throw ScholarStoreError.invalidData}
                let viewer=PDFView(frame:NSRect(x:0,y:0,width:900,height:760));viewer.autoScales=true;viewer.document=doc;viewer.go(to:page)
                let panel=NSWindow(contentRect:viewer.frame,styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false);panel.title="原文核对 · 物理第\(number)页";panel.isReleasedWhenClosed=false;panel.contentView=viewer;panel.center();panel.makeKeyAndOrderFront(nil);ResearchPDFWindows.windows.removeAll{!$0.isVisible};ResearchPDFWindows.windows.append(panel);completion(jsonString(["opened":true,"page":number]))
            }catch{completion("error:"+error.localizedDescription)};return true
        }
        if prompt == "KONGSCHOLAR_PDF_OCR" {
            do{let p=try researchInput(text);researchWork("识别指定PDF页面",completion:completion){let(_,bytes)=try self.indexedPDF(p);guard let number=p["page"] as? Int,let doc=PDFDocument(data:bytes),let page=doc.page(at:number-1) else{throw ScholarStoreError.invalidData};let box=page.bounds(for:.cropBox),ratio=min(1800/max(1,box.width),2400/max(1,box.height)),image=page.thumbnail(of:NSSize(width:box.width*ratio,height:box.height*ratio),for:.cropBox),png=try EvidenceImage.png(image,crop:CGRect(x:0,y:0,width:1,height:1));var report=try EvidenceImage.recognize(png.base64EncodedString());report["page"]=number;return report}}catch{completion("error:"+error.localizedDescription)};return true
        }
        if prompt == "KONGSCHOLAR_WORD_REVIEW" || prompt == "KONGSCHOLAR_WORD_REVISIONS32" {
            let panel=NSOpenPanel();panel.title=prompt == "KONGSCHOLAR_WORD_REVISIONS32" ? "读取Word返回稿中的文字修订":"读取Word返回稿中的批注";panel.allowedContentTypes=[UTType(filenameExtension:"docx") ?? .data]
            panel.beginSheetModal(for:window){r in guard r == .OK,let url=panel.url else{completion(nil);return};self.researchWork("读取Word批注",completion:completion){guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max)<=64*1024*1024 else{throw ScholarStoreError.tooLarge};var report=try WordReview.read(Data(contentsOf:url));report["name"]=url.lastPathComponent;return report}};return true
        }
        if prompt == "KONGSCHOLAR_MIGRATION_EXPORT" {
            do{let p=try researchInput(text);guard let value=p["text"] as? String,let ids=p["includeIDs"] as? [String] else{throw ScholarStoreError.invalidData};let panel=NSSavePanel();panel.title="保存完整迁移包（仅本机）";panel.nameFieldStringValue="KongScholar-迁移包.zip";panel.allowedContentTypes=[.zip];panel.beginSheetModal(for:window){r in guard r == .OK,let url=panel.url else{completion(nil);return};self.researchWork("校验并保存迁移包",completion:completion){let bytes=try MigrationPackage.generate(text:value,includeIDs:ids);_ = try MigrationPackage.inspect(bytes);try bytes.write(to:url,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path);guard ScholarArchive.digest(try Data(contentsOf:url))==ScholarArchive.digest(bytes) else{throw ScholarStoreError.invalidData};return["path":url.path,"bytes":bytes.count,"attachments":ids.count]}}}catch{completion("error:"+error.localizedDescription)};return true
        }
        if prompt == "KONGSCHOLAR_MIGRATION_TRIAL" {
            let panel=NSOpenPanel();panel.title="选择要检查和演练恢复的KongScholar迁移包";panel.allowedContentTypes=[.zip];panel.beginSheetModal(for:window){r in guard r == .OK,let file=panel.url else{completion(nil);return};let folder=NSOpenPanel();folder.title="选择演练位置（将建立独立新目录）";folder.canChooseFiles=false;folder.canChooseDirectories=true;folder.canCreateDirectories=true;folder.beginSheetModal(for:self.window){r in guard r == .OK,let parent=folder.url else{completion(nil);return};self.researchWork("在独立目录演练恢复",completion:completion){guard (try file.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max)<=ScholarStore.limit else{throw ScholarStoreError.tooLarge};return try MigrationPackage.rehearse(Data(contentsOf:file),parent:parent)}}};return true
        }
        return false
    }
}
