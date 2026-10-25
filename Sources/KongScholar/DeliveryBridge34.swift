import AppKit
import UniformTypeIdentifiers
import KongScholarCore

extension AppDelegate {
    func deliveryPrompt34(_ action:String,text:String?,completion:@escaping(String?)->Void)->Bool {
        guard ["KONGSCHOLAR_PACKET_PREPARE34","KONGSCHOLAR_PACKET_EXPORT34","KONGSCHOLAR_MIGRATION_PLAN34","KONGSCHOLAR_MIGRATION_EXPORT34","KONGSCHOLAR_VERIFY_FILE34","KONGSCHOLAR_VERIFY_SNAPSHOT34"].contains(action) else {return false}
        do {
            if action=="KONGSCHOLAR_VERIFY_FILE34" || action=="KONGSCHOLAR_VERIFY_SNAPSHOT34" {
                func chooseFolder(_ bytes:Data){let panel=NSOpenPanel();panel.title="选择恢复验证位置（建立独立目录）";panel.canChooseFiles=false;panel.canChooseDirectories=true;panel.canCreateDirectories=true;panel.beginSheetModal(for:self.window){r in guard r == .OK,let folder=panel.url else {completion(nil);return};self.researchWork("独立恢复并读回核验",completion:completion){try BackupVerification34.rehearse(bytes,parent:folder)}}}
                if action=="KONGSCHOLAR_VERIFY_SNAPSHOT34" {let bytes=Data(try store.backupText(named:text ?? "").utf8);chooseFolder(bytes)}
                else {let panel=NSOpenPanel();panel.title="选择完整JSON、工作备份或迁移ZIP";panel.allowedContentTypes=[.json,.zip];panel.beginSheetModal(for:window){r in guard r == .OK,let file=panel.url else {completion(nil);return};do{guard (try file.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max)<=ScholarStore.limit else {throw ScholarStoreError.tooLarge};chooseFolder(try Data(contentsOf:file))}catch{completion("error:"+error.localizedDescription)}}};return true
            }
            let bytes=Data((text ?? "{}").utf8);guard bytes.count<=ScholarStore.limit,let input=try JSONSerialization.jsonObject(with:bytes) as? [String:Any] else {throw ScholarStoreError.invalidData}
            if action=="KONGSCHOLAR_PACKET_PREPARE34" {guard let files=input["files"] as? [[String:String]],let selections=input["selections"] as? [[String:Any]] else {throw ScholarStoreError.invalidData};researchWork("固定所选文字与PDF原页",completion:completion){["files":try Delivery34.prepare(files:files,selections:selections)]};return true}
            if action=="KONGSCHOLAR_MIGRATION_PLAN34" {guard let full=input["text"] as? String,let keys=input["keys"] as? [String] else {throw ScholarStoreError.invalidData};researchWork("检查所选附件与迁移容量",completion:completion){try Migration34.plan(text:full,keys:keys)};return true}
            let panel=NSSavePanel();panel.allowedContentTypes=[.zip];panel.nameFieldStringValue=action=="KONGSCHOLAR_PACKET_EXPORT34" ? "KongScholar-选定材料包.zip":"KongScholar-完整迁移包.zip";panel.title="保存到本机";panel.beginSheetModal(for:window){r in guard r == .OK,let file=panel.url else {completion(nil);return};self.researchWork("保存并读回核验材料包",completion:completion){let data:Data;if action=="KONGSCHOLAR_PACKET_EXPORT34" {guard let files=input["files"] as? [[String:Any]] else {throw ScholarStoreError.invalidData};data=try Delivery34.generate(files)}else {guard let full=input["text"] as? String,let keys=input["keys"] as? [String] else {throw ScholarStoreError.invalidData};data=try Migration34.generate(text:full,keys:keys);_ = try Migration34.inspect(data)};try data.write(to:file,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path);guard try Data(contentsOf:file)==data else {throw ScholarStoreError.invalidData};return["path":file.path,"sha256":ScholarArchive.digest(data),"bytes":data.count]}}
        } catch {completion("error:"+error.localizedDescription)};return true
    }
}
