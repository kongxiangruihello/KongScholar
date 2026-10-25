import Foundation

public enum Migration34 {
    public struct Reference { public var key:String;public var title:String;public var link:AttachmentLink;public var size:Int? }
    public static func references(_ root:[String:Any])->[Reference] {
        var out=[Reference]()
        for r in root["guidancedrafts"] as? [[String:Any]] ?? [] {if let id=r["id"] as? String,let a=r["attachment"] as? [String:Any],let path=a["path"] as? String {out.append(Reference(key:"guidancedrafts:"+id,title:r["title"] as? String ?? id,link:AttachmentLink(key:id,kind:"attachment",path:path,bookmark:a["bookmark"] as? String,sha256:a["sha256"] as? String),size:a["size"] as? Int))}}
        for r in root["pdfindexes"] as? [[String:Any]] ?? [] {if let id=r["id"] as? String,let path=r["path"] as? String {out.append(Reference(key:"pdfindexes:"+id,title:r["title"] as? String ?? id,link:AttachmentLink(key:id,kind:"pdf",path:path,bookmark:r["bookmark"] as? String,sha256:r["sha256"] as? String,documentID:r["documentID"] as? String),size:nil))}}
        for r in root["sources"] as? [[String:Any]] ?? [] {if let id=r["id"] as? String,let a=r["folio"] as? [String:Any],let path=a["filePath"] as? String,!path.isEmpty {out.append(Reference(key:"sources:"+id,title:r["title"] as? String ?? id,link:AttachmentLink(key:id,kind:"folio",path:path,bookmark:a["bookmarkData"] as? String,sha256:a["fingerprint"] as? String,documentID:a["documentID"] as? String),size:nil))}}
        for r in root["deliveries"] as? [[String:Any]] ?? [] {if let id=r["id"] as? String,let a=r["exportFile30"] as? [String:Any],let path=a["path"] as? String {out.append(Reference(key:"deliveries:"+id,title:r["title"] as? String ?? id,link:AttachmentLink(key:id,kind:"attachment",path:path,sha256:a["sha256"] as? String),size:a["bytes"] as? Int))}}
        return out
    }
    private static func root(_ text:String)throws->[String:Any] {guard let v=try JSONSerialization.jsonObject(with:ScholarStore.validate(text)) as? [String:Any] else {throw ScholarStoreError.invalidData};return v}
    private static func read(_ ref:Reference)throws->(Data,String) {
        let file=AttachmentHealth.resolved(ref.link),info=try file.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey]),ext=file.pathExtension.lowercased()
        guard info.isRegularFile==true,info.isSymbolicLink != true,["pdf","kongfolio","docx","txt","md","zip"].contains(ext),(info.fileSize ?? Int.max)<=64*1024*1024 else {throw ScholarStoreError.tooLarge}
        _ = try AttachmentHealth.verify(ref.link,at:file)
        let bytes=try Data(contentsOf:file);if let size=ref.size {guard bytes.count==size else {throw ScholarStoreError.invalidData}}
        return(bytes,ext)
    }
    public static func plan(text:String,keys:[String])throws->[String:Any] {
        let full=try root(text),refs=references(full);guard keys.count<=200,Set(keys).count==keys.count else {throw ScholarStoreError.invalidData};var rows=[[String:Any]](),seen=Set<String>(),total=text.utf8.count,valid=true
        for key in keys {guard let ref=refs.first(where:{$0.key==key}) else {throw ScholarStoreError.invalidData};do{let(bytes,ext)=try read(ref),hash=ScholarArchive.digest(bytes),member=hash+"."+ext;if seen.insert(member).inserted {total += bytes.count};rows.append(["key":key,"title":ref.title,"bytes":bytes.count,"sha256":hash,"state":"内容已核对"])}catch{valid=false;rows.append(["key":key,"title":ref.title,"state":"缺失或内容不符","error":error.localizedDescription])}}
        if total>ScholarStore.limit-1024*1024 {valid=false};return["rows":rows,"bytes":total,"canExport":valid,"selected":keys.count,"excluded":refs.count-keys.count]
    }
    public static func generate(text:String,keys:[String])throws->Data {
        let full=try root(text),refs=references(full);guard keys.count<=200,Set(keys).count==keys.count else {throw ScholarStoreError.invalidData};let data=Data(text.utf8);var parts=["data.json":data],items=[[String:Any]](),total=data.count
        for key in keys {guard let ref=refs.first(where:{$0.key==key}) else {throw ScholarStoreError.invalidData};let(bytes,ext)=try read(ref),hash=ScholarArchive.digest(bytes),member="attachments/"+hash+"."+ext;if parts[member]==nil {guard bytes.count<=ScholarStore.limit-1024*1024-total else {throw ScholarStoreError.tooLarge};parts[member]=bytes;total += bytes.count};items.append(["key":key,"member":member,"sha256":hash,"size":bytes.count])}
        parts["manifest.json"]=try JSONSerialization.data(withJSONObject:["format":"KongScholar-Migration","version":2,"dataSHA256":ScholarArchive.digest(data),"attachments":items],options:[.sortedKeys]);let out=WordExport.archive(parts);guard out.count<=ScholarStore.limit else {throw ScholarStoreError.tooLarge};return out
    }
    public static func inspect(_ bytes:Data)throws->(root:[String:Any],items:[[String:Any]],parts:[String:Data]) {
        let zip=try BoundedZip(bytes);guard let m=try JSONSerialization.jsonObject(with:zip.read("manifest.json",limit:1024*1024)) as? [String:Any],m["format"] as? String=="KongScholar-Migration",m["version"] as? Int==2,let items=m["attachments"] as? [[String:Any]],items.count<=200 else {throw ScholarStoreError.invalidData}
        let data=try zip.read("data.json");guard ScholarArchive.digest(data)==m["dataSHA256"] as? String,let text=String(data:data,encoding:.utf8) else {throw ScholarStoreError.invalidData};let full=try root(text),refs=references(full);var parts=[String:Data](),keys=Set<String>()
        // Identity checks for KongFolio require its container; only fixed hash-named temporary files are written.
        let temp=FileManager.default.temporaryDirectory.appendingPathComponent("KS-migration-check-"+UUID().uuidString,isDirectory:true);try FileManager.default.createDirectory(at:temp,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700]);defer{try? FileManager.default.removeItem(at:temp)}
        for item in items {guard let key=item["key"] as? String,keys.insert(key).inserted,let ref=refs.first(where:{$0.key==key}),let member=item["member"] as? String,let hash=item["sha256"] as? String,hash.range(of:"^[a-f0-9]{64}$",options:.regularExpression) != nil,let size=item["size"] as? Int,(0...64*1024*1024).contains(size) else {throw ScholarStoreError.invalidData};let ext=URL(fileURLWithPath:member).pathExtension;guard ["pdf","kongfolio","docx","md","txt","zip"].contains(ext),member=="attachments/"+hash+"."+ext else {throw ScholarStoreError.invalidData};let data=try zip.read(member,limit:64*1024*1024);guard data.count==size,ScholarArchive.digest(data)==hash else {throw ScholarStoreError.invalidData};let file=temp.appendingPathComponent(hash+"."+ext);if parts[member]==nil {try data.write(to:file);parts[member]=data};_ = try AttachmentHealth.verify(ref.link,at:file);if let expected=ref.size {guard data.count==expected else {throw ScholarStoreError.invalidData}}}
        guard Set(zip.members.map(\.name))==Set(["manifest.json","data.json"]+Array(parts.keys)) else {throw ScholarStoreError.invalidData};return(full,items,parts)
    }
    public static func rehearse(_ bytes:Data,parent:URL)throws->[String:Any] {
        var(root,items,parts)=try inspect(bytes);let folder=parent.appendingPathComponent("KongScholar-恢复演练-"+UUID().uuidString,isDirectory:true);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700]);var success=false;defer{if !success {try? FileManager.default.removeItem(at:folder)}}
        if !parts.isEmpty {try FileManager.default.createDirectory(at:folder.appendingPathComponent("attachments"),withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])}
        for(member,data) in parts {let file=folder.appendingPathComponent(member);try data.write(to:file,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path);guard try Data(contentsOf:file)==data else {throw ScholarStoreError.invalidData}}
        for item in items {let key=(item["key"] as! String).split(separator:":",maxSplits:1).map(String.init),member=item["member"] as! String;guard key.count==2,var rows=root[key[0]] as? [[String:Any]],let i=rows.firstIndex(where:{$0["id"] as? String==key[1]}) else {throw ScholarStoreError.invalidData};let file=folder.appendingPathComponent(member),bookmark=try file.bookmarkData(options:.minimalBookmark,includingResourceValuesForKeys:nil,relativeTo:nil).base64EncodedString()
            switch key[0] {case "guidancedrafts":var a=rows[i]["attachment"] as! [String:Any];a["path"]=file.path;a["bookmark"]=bookmark;rows[i]["attachment"]=a
            case "pdfindexes":rows[i]["path"]=file.path;rows[i]["bookmark"]=bookmark
            case "sources":var a=rows[i]["folio"] as! [String:Any];a["filePath"]=file.path;a["bookmarkData"]=bookmark;rows[i]["folio"]=a
            case "deliveries":var a=rows[i]["exportFile30"] as! [String:Any];a["path"]=file.path;rows[i]["exportFile30"]=a
            default:throw ScholarStoreError.invalidData};root[key[0]]=rows
        }
        let full=try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys]),text=String(data:full,encoding:.utf8)!,store=try ScholarStore(directory:folder.appendingPathComponent("trial-store"));try store.write(text);guard let restored=try store.read(),try canonical(restored)==full else {throw ScholarStoreError.invalidData};let portable=folder.appendingPathComponent("已演练-完整资料.json");try full.write(to:portable);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:portable.path);success=true
        return["folder":folder.path,"file":portable.path,"text":text,"attachments":items.count,"excludedAttachments":references(root).count-items.count,"records":root.values.compactMap{$0 as? [[String:Any]]}.reduce(0){$0+$1.count}]
    }
    static func canonical(_ text:String)throws->Data {try JSONSerialization.data(withJSONObject:JSONSerialization.jsonObject(with:Data(text.utf8)),options:[.sortedKeys])}
}
