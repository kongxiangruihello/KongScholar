import Foundation

public enum MigrationPackage {
    public static func generate(text:String, includeIDs:[String]) throws -> Data {
        let data=try ScholarStore.validate(text)
        guard let root=try JSONSerialization.jsonObject(with:data) as? [String:Any],let drafts=root["guidancedrafts"] as? [[String:Any]],Set(includeIDs).count==includeIDs.count else {throw ScholarStoreError.invalidData}
        var parts=["data.json":data],items=[[String:Any]](),total=data.count
        for id in includeIDs {
            guard let d=drafts.first(where:{$0["id"] as? String == id}),let a=d["attachment"] as? [String:Any],let path=a["path"] as? String,let expected=a["sha256"] as? String,let original=a["name"] as? String else {throw ScholarStoreError.invalidData}
            var file=URL(fileURLWithPath:path)
            if let encoded=a["bookmark"] as? String,let b=Data(base64Encoded:encoded) {var stale=false;if let resolved=try? URL(resolvingBookmarkData:b,options:[.withoutUI,.withoutMounting],relativeTo:nil,bookmarkDataIsStale:&stale){file=resolved}}
            let ext=file.pathExtension.lowercased(),info=try file.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey])
            guard ["pdf","docx","md","txt"].contains(ext),info.isRegularFile==true,(info.fileSize ?? Int.max)<=64*1024*1024 else {throw ScholarStoreError.invalidData}
            let bytes=try Data(contentsOf:file),hash=ScholarArchive.digest(bytes)
            guard hash==expected,bytes.count == a["size"] as? Int else {throw ScholarStoreError.invalidData}
            let member="attachments/"+hash+"."+ext
            if parts[member]==nil {guard bytes.count<=ScholarStore.limit-total else {throw ScholarStoreError.tooLarge};parts[member]=bytes;total += bytes.count}
            items.append(["recordID":id,"name":original,"member":member,"sha256":hash,"size":bytes.count])
        }
        parts["manifest.json"]=try JSONSerialization.data(withJSONObject:["format":"KongScholar-Migration","version":1,"dataSHA256":ScholarArchive.digest(data),"attachments":items],options:[.sortedKeys])
        let output=WordExport.archive(parts);guard output.count<=ScholarStore.limit else {throw ScholarStoreError.tooLarge};return output
    }
    public static func inspect(_ bytes:Data) throws -> (root:[String:Any],items:[[String:Any]],parts:[String:Data]) {
        let zip=try BoundedZip(bytes)
        guard let manifest=try JSONSerialization.jsonObject(with:zip.read("manifest.json",limit:1024*1024)) as? [String:Any],manifest["format"] as? String == "KongScholar-Migration",manifest["version"] as? Int == 1,let expected=manifest["dataSHA256"] as? String,let items=manifest["attachments"] as? [[String:Any]],items.count<=10000 else {throw ScholarStoreError.invalidData}
        let bytes=try zip.read("data.json");guard ScholarArchive.digest(bytes)==expected,let text=String(data:bytes,encoding:.utf8),let root=try JSONSerialization.jsonObject(with:ScholarStore.validate(text)) as? [String:Any] else {throw ScholarStoreError.invalidData}
        let drafts=root["guidancedrafts"] as? [[String:Any]] ?? [];var parts=[String:Data](),ids=Set<String>()
        for item in items {
            guard let id=item["recordID"] as? String,ids.insert(id).inserted,let name=item["name"] as? String,!name.isEmpty,let member=item["member"] as? String,let hash=item["sha256"] as? String,let size=item["size"] as? Int,size>=0,size<=64*1024*1024,
                  hash.range(of:"^[a-f0-9]{64}$",options:.regularExpression) != nil,member.hasPrefix("attachments/"+hash+"."),["pdf","docx","md","txt"].contains(URL(fileURLWithPath:member).pathExtension),
                  let draft=drafts.first(where:{$0["id"] as? String == id}),let attachment=draft["attachment"] as? [String:Any],attachment["sha256"] as? String == hash,attachment["size"] as? Int == size else {throw ScholarStoreError.invalidData}
            let data=try zip.read(member,limit:64*1024*1024);guard data.count==size,ScholarArchive.digest(data)==hash else {throw ScholarStoreError.invalidData};parts[member]=data
        }
        guard Set(zip.members.map{$0.name}) == Set(["manifest.json","data.json"]+Array(parts.keys)) else {throw ScholarStoreError.invalidData}
        return(root,items,parts)
    }
    /// Creates a new isolated directory and verifies a fresh split-store read. The user's current library is never replaced.
    public static func rehearse(_ bytes:Data, parent:URL) throws -> [String:Any] {
        var (root,items,parts)=try inspect(bytes)
        let folder=parent.appendingPathComponent("KongScholar-恢复演练-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700]);var success=false
        defer {if !success {try? FileManager.default.removeItem(at:folder)}}
        var drafts=root["guidancedrafts"] as? [[String:Any]] ?? []
        if !parts.isEmpty {try FileManager.default.createDirectory(at:folder.appendingPathComponent("attachments"),withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])}
        for (member,data) in parts {let target=folder.appendingPathComponent(member);try data.write(to:target,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:target.path);guard ScholarArchive.digest(try Data(contentsOf:target))==ScholarArchive.digest(data) else {throw ScholarStoreError.invalidData}}
        for item in items {
            guard let i=drafts.firstIndex(where:{$0["id"] as? String == item["recordID"] as? String}),var a=drafts[i]["attachment"] as? [String:Any],let member=item["member"] as? String else {throw ScholarStoreError.invalidData}
            let target=folder.appendingPathComponent(member);a["path"]=target.path;a["bookmark"]=try target.bookmarkData(options:.minimalBookmark,includingResourceValuesForKeys:nil,relativeTo:nil).base64EncodedString();drafts[i]["attachment"]=a
        }
        root["guidancedrafts"]=drafts
        let full=try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys]);guard let text=String(data:full,encoding:.utf8) else {throw ScholarStoreError.invalidData}
        let trial=try ScholarStore(directory:folder.appendingPathComponent("trial-store"));try trial.write(text)
        guard let restored=try trial.read(),let decoded=restored.data(using:.utf8),try JSONSerialization.data(withJSONObject:JSONSerialization.jsonObject(with:decoded),options:[.sortedKeys])==full else {throw ScholarStoreError.invalidData}
        let portable=folder.appendingPathComponent("已演练-完整资料.json");try full.write(to:portable,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:portable.path)
        success=true
        return ["folder":folder.path,"file":portable.path,"text":text,"attachments":items.count,"excludedAttachments":drafts.filter{$0["attachment"] != nil}.count-items.count,"records":root.values.compactMap{$0 as? [[String:Any]]}.reduce(0){$0+$1.count}]
    }
}
