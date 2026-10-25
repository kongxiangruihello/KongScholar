import Foundation

public enum EditingDrafts {
    public static let totalLimit=96*1024*1024
    private static func folder(_ root:URL)->URL{root.appendingPathComponent("editing-drafts",isDirectory:true)}
    private static func file(_ root:URL,_ key:String)throws->URL{guard !key.isEmpty,key.utf8.count<=512 else{throw ScholarStoreError.invalidData};return folder(root).appendingPathComponent(ScholarArchive.digest(Data(key.utf8))+".json")}
    private static func bytes(_ value:[String:Any])throws->Data{try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])}
    private static func validate(_ value:[String:Any])throws->String{
        guard let key=value["key"] as? String,!key.isEmpty,key.utf8.count<=512,let type=value["type"] as? String,!type.isEmpty,type.count<=80,
              value["at"] is String,let fields=value["fields"] as? [[String]],fields.count<=500,fields.allSatisfy({$0.count==2 && $0[0].count<=128}) else{throw ScholarStoreError.invalidData}
        for name in ["id","projectID","baseline","title"] where value[name] != nil {guard value[name] is String else{throw ScholarStoreError.invalidData}}
        var plain=value;plain.removeValue(forKey:"history27");guard try bytes(plain).count<=4*1024*1024 else{throw ScholarStoreError.tooLarge}
        if let history=value["history27"]{guard let rows=history as? [[String:Any]],rows.count<=20,Set(rows.compactMap{$0["versionID"] as? String}).count==rows.count else{throw ScholarStoreError.invalidData};for row in rows{guard let id=row["versionID"] as? String,id.range(of:"^[a-f0-9]{64}$",options:.regularExpression) != nil,row["at"] is String,let f=row["fields"] as? [[String]],f.count<=500,f.allSatisfy({$0.count==2 && $0[0].count<=128}) else{throw ScholarStoreError.invalidData}}}
        return key
    }
    public static func read(key:String,root:URL)throws->[String:Any]{
        let url=try file(root,key),info=try url.resourceValues(forKeys:[.fileSizeKey,.isSymbolicLinkKey]);guard info.isSymbolicLink != true,(info.fileSize ?? Int.max)<=12*1024*1024,let v=try JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any],try validate(v)==key else{throw ScholarStoreError.invalidData};return v
    }
    public static func save(_ value:[String:Any],root:URL)throws{
        let key=try validate(value),target=try file(root,key),fm=FileManager.default;var next=value;next.removeValue(forKey:"history27")
        if fm.fileExists(atPath:target.path){let old=try read(key:key,root:root);var history=old["history27"] as? [[String:Any]] ?? []
            let oldFields=old["fields"] as? [[String]] ?? [],newFields=value["fields"] as? [[String]] ?? []
            if oldFields != newFields {var previous=old;previous.removeValue(forKey:"history27");previous["versionID"]=ScholarArchive.digest(try bytes(previous));history.insert(previous,at:0)}
            history=Array(history.prefix(20));while try bytes(["history":history]).count>8*1024*1024 {history.removeLast()};next["history27"]=history
        }
        let output=try bytes(next);guard output.count<=12*1024*1024 else{throw ScholarStoreError.tooLarge}
        try fm.createDirectory(at:folder(root),withIntermediateDirectories:true,attributes:[.posixPermissions:0o700]);let existing=try fm.contentsOfDirectory(at:folder(root),includingPropertiesForKeys:[.fileSizeKey,.isSymbolicLinkKey]);guard fm.fileExists(atPath:target.path)||existing.count<100 else{throw ScholarStoreError.tooLarge}
        let used=try existing.filter{$0.lastPathComponent != target.lastPathComponent}.reduce(0){total,url in let info=try url.resourceValues(forKeys:[.fileSizeKey,.isSymbolicLinkKey]);guard info.isSymbolicLink != true else{throw ScholarStoreError.invalidData};return total+(info.fileSize ?? 0)};guard used+output.count<=totalLimit else{throw ScholarStoreError.tooLarge}
        try output.write(to:target,options:.atomic);try fm.setAttributes([.posixPermissions:0o600],ofItemAtPath:target.path)
    }
    public static func list(root:URL,summary:Bool=false)throws->[[String:Any]]{
        let fm=FileManager.default;guard fm.fileExists(atPath:folder(root).path) else{return[]};let urls=try fm.contentsOfDirectory(at:folder(root),includingPropertiesForKeys:[.fileSizeKey,.isSymbolicLinkKey]);guard urls.count<=100 else{throw ScholarStoreError.tooLarge}
        var total=0;let rows=try urls.filter{$0.pathExtension=="json"}.map{url->[String:Any] in
            let info=try url.resourceValues(forKeys:[.fileSizeKey,.isSymbolicLinkKey]);total += info.fileSize ?? totalLimit;guard info.isSymbolicLink != true,total<=totalLimit,(info.fileSize ?? Int.max)<=12*1024*1024,let v=try JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any],let key=v["key"] as? String,try file(root,key).lastPathComponent==url.lastPathComponent else{throw ScholarStoreError.invalidData};_ = try validate(v)
            var result=v;result["historyCount"]=((v["history27"] as? [Any]) ?? []).count
            if summary{result.removeValue(forKey:"fields");result.removeValue(forKey:"baseline");result.removeValue(forKey:"history27")};return result
        };return rows.sorted{($0["at"] as? String ?? "")>($1["at"] as? String ?? "")}
    }
    public static func portable(root:URL)throws->Data{let rows=try list(root:root);return try bytes(["format":"KongScholar-EditingDrafts","version":1,"drafts":rows])}
    public static func inspectPortable(_ data:Data)throws->[[String:Any]]{
        guard data.count<=totalLimit,let r=try JSONSerialization.jsonObject(with:data) as? [String:Any],r["format"] as? String=="KongScholar-EditingDrafts",r["version"] as? Int==1,let rows=r["drafts"] as? [[String:Any]],rows.count<=100 else{throw ScholarStoreError.invalidData}
        var keys=Set<String>();for row in rows{guard keys.insert(try validate(row)).inserted,try bytes(row).count<=12*1024*1024 else{throw ScholarStoreError.invalidData}};return rows
    }
    /// Import copies into unique keys. Existing local journals are never overwritten.
    public static func importPortable(_ data:Data,root:URL)throws->Int{
        let rows=try inspectPortable(data),current=try list(root:root);guard current.count+rows.count<=100 else{throw ScholarStoreError.tooLarge}
        let fm=FileManager.default;var prepared=[(URL,Data)](),used=try current.reduce(0){$0+(try bytes($1).count)}
        for var row in rows{row["key"]="import:"+UUID().uuidString;row["importedAt27"]=ISO8601DateFormatter().string(from:Date());let data=try bytes(row);used += data.count;guard used<=totalLimit else{throw ScholarStoreError.tooLarge};prepared.append((try file(root,row["key"] as! String),data))}
        try fm.createDirectory(at:folder(root),withIntermediateDirectories:true,attributes:[.posixPermissions:0o700]);var made=[URL]();do{for(url,bytes)in prepared{try bytes.write(to:url,options:.atomic);made.append(url);try fm.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)}}catch{for url in made{try? fm.removeItem(at:url)};throw error};return rows.count
    }
    public static func remove(key:String,root:URL)throws{let url=try file(root,key);if FileManager.default.fileExists(atPath:url.path){try FileManager.default.removeItem(at:url)}}
}
