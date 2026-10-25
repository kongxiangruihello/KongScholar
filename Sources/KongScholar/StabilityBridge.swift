import AppKit
import UniformTypeIdentifiers
import KongScholarCore

extension AppDelegate {
    private var release27:String {Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "2.7.0"}
    private func releaseStatus27()throws->[String:Any]{
        guard let bundled=Bundle.main.resourceURL?.appendingPathComponent("release-status.json"),let base=try JSONSerialization.jsonObject(with:Data(contentsOf:bundled)) as? [String:Any] else{throw ScholarStoreError.invalidData};let verified=try ReleaseStatus.validate(base,release:release27)
        let local=store.directory.appendingPathComponent("release-state/source-receipt.json");if FileManager.default.fileExists(atPath:local.path),let v=try? JSONSerialization.jsonObject(with:Data(contentsOf:local)) as? [String:Any],let r=try? ReleaseStatus.validate(v,release:release27,manifest:verified["manifestSHA256"] as? String){return r};return verified
    }
    func stabilityPrompt(_ prompt:String,text:String?,completion:@escaping(String?)->Void)->Bool {
        if prompt=="KONGSCHOLAR_PREPARE_DAMAGED_RESTORE" {do{let r=try UpgradeProtection.protect(store,version:release27,allowDamaged:true);completion(jsonString(["ready":true,"state":r["state"] ?? "unknown"]))}catch{completion("error:"+error.localizedDescription)};return true}
        if prompt=="KONGSCHOLAR_STARTUP_HEALTH" {let root=Bundle.main.resourceURL?.appendingPathComponent("Web");researchWork("检查本机资料与升级备份",completion:completion){var r=StartupHealth.inspect(self.store,resources:root);r["release"]=self.release27;return r};return true}
        if prompt=="KONGSCHOLAR_RELEASE_STATUS" {do{completion(jsonString(try releaseStatus27()))}catch{completion("error:"+error.localizedDescription)};return true}
        if prompt=="KONGSCHOLAR_RELEASE_RECEIPT" {
            let panel=NSOpenPanel();panel.title="选择源码发布工具生成的回执";panel.allowedContentTypes=[.json];panel.beginSheetModal(for:window){r in guard r == .OK,let url=panel.url else{completion(nil);return};do{guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max)<=1024*1024 else{throw ScholarStoreError.tooLarge};let expected=try self.releaseStatus27(),v=try JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any] ?? [:],valid=try ReleaseStatus.validate(v,release:self.release27,manifest:expected["manifestSHA256"] as? String),folder=self.store.directory.appendingPathComponent("release-state");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700]);let path=folder.appendingPathComponent("source-receipt.json");try JSONSerialization.data(withJSONObject:valid,options:[.sortedKeys]).write(to:path,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path.path);completion(self.jsonString(valid))}catch{completion("error:"+error.localizedDescription)}};return true
        }
        if prompt=="KONGSCHOLAR_DRAFT_READ" {do{guard let v=try JSONSerialization.jsonObject(with:Data((text ?? "{}").utf8)) as? [String:String],let key=v["key"] else{throw ScholarStoreError.invalidData};completion(jsonString(try EditingDrafts.read(key:key,root:store.directory)))}catch{completion("error:"+error.localizedDescription)};return true}
        if prompt=="KONGSCHOLAR_WORKING_EXPORT" {
            do{guard let p=try JSONSerialization.jsonObject(with:Data((text ?? "{}").utf8)) as? [String:Any],let full=p["text"] as? String,let include=p["includeDrafts"] as? Bool else{throw ScholarStoreError.invalidData};let panel=NSSavePanel();panel.title="保存工作备份包";panel.allowedContentTypes=[.zip];panel.nameFieldStringValue="KongScholar-工作备份.zip";panel.beginSheetModal(for:window){r in guard r == .OK,let url=panel.url else{completion(nil);return};self.researchWork("校验并保存工作备份",completion:completion){let drafts=include ? try EditingDrafts.portable(root:self.store.directory):nil,bytes=try WorkingBackup.generate(text:full,drafts:drafts),check=try WorkingBackup.inspect(bytes);try bytes.write(to:url,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path);guard try Data(contentsOf:url)==bytes else{throw ScholarStoreError.invalidData};return["path":url.path,"draftCount":check.count,"bytes":bytes.count]}}}catch{completion("error:"+error.localizedDescription)};return true
        }
        if prompt=="KONGSCHOLAR_WORKING_READ" {
            let panel=NSOpenPanel();panel.title="预览工作备份包（不会替换资料）";panel.allowedContentTypes=[.zip];panel.beginSheetModal(for:window){r in guard r == .OK,let url=panel.url else{completion(nil);return};self.researchWork("核对工作备份",completion:completion){guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max)<=ScholarStore.limit else{throw ScholarStoreError.tooLarge};let bytes=try Data(contentsOf:url),p=try WorkingBackup.inspect(bytes),token=UUID().uuidString;self.stagedWorkingDrafts27=p.drafts;self.stagedWorkingToken27=token;return["name":url.lastPathComponent,"text":p.text,"draftCount":p.count,"draftsIncluded":p.drafts != nil,"token":token]}};return true
        }
        if prompt=="KONGSCHOLAR_WORKING_DRAFTS_IMPORT" {do{guard text==stagedWorkingToken27,let drafts=stagedWorkingDrafts27 else{throw ScholarStoreError.invalidData};let count=try EditingDrafts.importPortable(drafts,root:store.directory);stagedWorkingDrafts27=nil;stagedWorkingToken27="";completion(jsonString(["count":count]))}catch{completion("error:"+error.localizedDescription)};return true}
        return false
    }
}
