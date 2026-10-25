import Foundation

public enum BackupVerification34 {
    public static func rehearse(_ bytes:Data,parent:URL)throws->[String:Any] {
        guard bytes.count<=ScholarStore.limit else {throw ScholarStoreError.tooLarge}
        var result:[String:Any],kind="完整JSON",draftCount=0
        if bytes.starts(with:Data([0x50,0x4b])) {
            let zip=try BoundedZip(bytes);guard let m=try JSONSerialization.jsonObject(with:zip.read("manifest.json",limit:1024*1024)) as? [String:Any] else {throw ScholarStoreError.invalidData}
            if m["format"] as? String=="KongScholar-Migration" {kind="迁移包";result=try (m["version"] as? Int==2 ? Migration34.rehearse(bytes,parent:parent):MigrationPackage.rehearse(bytes,parent:parent))}
            else if m["format"] as? String=="KongScholar-WorkingBackup" {let value=try WorkingBackup.inspect(bytes);kind="工作备份";draftCount=value.count;result=try plain(value.text,parent:parent,drafts:value.drafts)}
            else {throw ScholarStoreError.invalidData}
        } else {guard let text=String(data:bytes,encoding:.utf8) else {throw ScholarStoreError.invalidData};result=try plain(text,parent:parent,drafts:nil)}
        guard let text=result["text"] as? String,let folder=result["folder"] as? String,let root=try JSONSerialization.jsonObject(with:ScholarStore.validate(text)) as? [String:Any] else {throw ScholarStoreError.invalidData}
        var embeddedFiles=0
        for version in root["packetversions34"] as? [[String:Any]] ?? [] {guard let snapshot=version["snapshot34"] as? [String:Any],let files=snapshot["files"] as? [[String:Any]] else {throw ScholarStoreError.invalidData};embeddedFiles += try Delivery34.parts(files).count}
        var counts=[String:Int]();for(k,v) in root {if let rows=v as? [[String:Any]] {counts[k]=rows.count}}
        let chapters=root["chapters"] as? [[String:Any]] ?? [],chapterProof=chapters.map { row -> [String:Any] in let w=row["writing"] as? [String:Any] ?? [:],body=w["body"] as? String ?? "";return["id":row["id"] ?? "","bodySHA256":ScholarArchive.digest(Data(body.utf8)),"footnotes":(w["citations"] as? [[String:Any]] ?? []).count] }
        let report:[String:Any]=["format":"KongScholar-BackupVerification","version":1,"at":ISO8601DateFormatter().string(from:Date()),"kind":kind,"backupSHA256":ScholarArchive.digest(bytes),"counts":counts,"chapters":chapterProof,"attachments":result["attachments"] ?? 0,"excludedAttachments":result["excludedAttachments"] ?? Migration34.references(root).count,"draftCount":draftCount,"embeddedPacketFiles":embeddedFiles,"storageRoundTrip":true]
        let file=URL(fileURLWithPath:folder).appendingPathComponent("恢复验证报告.json");try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys,.prettyPrinted]).write(to:file,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
        result["report"]=report;result["reportPath"]=file.path;return result
    }
    private static func plain(_ text:String,parent:URL,drafts:Data?)throws->[String:Any] {
        let data=try ScholarStore.validate(text),expected=try Migration34.canonical(text),folder=parent.appendingPathComponent("KongScholar-恢复验证-"+UUID().uuidString,isDirectory:true);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700]);var success=false;defer{if !success {try? FileManager.default.removeItem(at:folder)}}
        let store=try ScholarStore(directory:folder.appendingPathComponent("trial-store"));try store.write(text);guard let restored=try store.read(),try Migration34.canonical(restored)==expected else {throw ScholarStoreError.invalidData}
        if let drafts=drafts {_ = try EditingDrafts.importPortable(drafts,root:store.directory)}
        let file=folder.appendingPathComponent("已验证-完整资料.json");try data.write(to:file,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path);success=true;return["text":restored,"folder":folder.path,"file":file.path,"attachments":0]
    }
}
