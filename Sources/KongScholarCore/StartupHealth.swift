import Foundation

public enum StartupHealth {
    public static func inspect(_ store:ScholarStore,resources:URL?=nil,initialText:String?=nil)->[String:Any] {
        let resolved=Result<String?,Error>{if let text=initialText{return text};return try store.read()}
        var checks=[[String:Any]]()
        func check(_ title:String,_ action:()throws->String){do{checks.append(["title":title,"state":"通过","detail":try action()])}catch{checks.append(["title":title,"state":"未通过","detail":error.localizedDescription])}}
        check("资料索引"){
            guard FileManager.default.fileExists(atPath:store.dataURL.path) else{return"尚无资料库"}
            let bytes=try Data(contentsOf:store.dataURL);guard bytes.count<=ScholarStore.limit,var root=try JSONSerialization.jsonObject(with:bytes) as? [String:Any] else{throw ScholarStoreError.invalidData}
            if var storage=root["_archiveStorage"] as? [String:Any]{guard [1,2,3,4,5,6,7,8,9,10,11].contains(storage["version"] as? Int ?? 0),let expected=storage.removeValue(forKey:"indexSHA256") as? String else{throw ScholarStoreError.invalidData};root["_archiveStorage"]=storage;guard ScholarArchive.digest(try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys]))==expected else{throw ScholarStoreError.invalidData}}
            else{guard let text=String(data:bytes,encoding:.utf8) else{throw ScholarStoreError.invalidData};_ = try ScholarStore.validate(text)};return"索引结构及其校验值通过"
        }
        check("历史归档与完整资料"){
            guard let value=try resolved.get() else{return"尚无资料库，可新建资料"};_ = try ScholarStore.validate(value);return"索引、归档内容校验值与必要记录结构通过"
        }
        check("个人偏好与项目预设结构"){
            guard let value=try resolved.get(),let r=try JSONSerialization.jsonObject(with:Data(value.utf8)) as? [String:Any] else{return"尚无资料库"}
            let m=r["meta"] as? [String:Any] ?? [:];for key in ["projectCitations26","projectLayouts26"] where m[key] != nil {guard m[key] is [String:Any] else{throw ScholarStoreError.invalidData}}
            return"本机结构检查通过；字段内容由界面另行检查"
        }
        check("独立草稿与历史"){"共\(try EditingDrafts.list(root:store.directory,summary:true).count)份待提交草稿"}
        check("独立写作窗口草稿"){"共\(try WindowDrafts31.list(root:store.directory).count)份待恢复窗口草稿"}
        var pendingExports30 = -1
        check("导出记录回执"){pendingExports30 = try ExportOutbox30.pendingCount(root:store.directory);return "\(pendingExports30)份待核对回执；文件内容在打开导出记录恢复时另行核对"}
        check("升级专用备份"){
            let folder=store.directory.appendingPathComponent("upgrades"),fm=FileManager.default;guard fm.fileExists(atPath:folder.path) else{return"尚未建立；新版本首次写入前自动建立并校验"}
            let receipts=try fm.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil).filter{$0.lastPathComponent.hasPrefix("release-") && $0.pathExtension=="json"};guard receipts.count<=1000 else{throw ScholarStoreError.tooLarge}
            for p in receipts {guard let r=try JSONSerialization.jsonObject(with:Data(contentsOf:p)) as? [String:Any],let version=r["version"] as? String else{throw ScholarStoreError.invalidData};let verified=try UpgradeProtection.protect(store,version:version);if verified["state"] as? String=="raw-preserved"{throw NSError(domain:"KongScholar",code:27,userInfo:[NSLocalizedDescriptionKey:"存在已保全的损坏原件；其校验值通过，但不是可恢复的完整JSON。原归档仍保留，请另外保留数据文件夹。"])} };return"\(receipts.count)份升级回执及其备份核验通过"
        }
        if let root=resources{check("界面资源"){
            let html=try String(contentsOf:root.appendingPathComponent("index.html"),encoding:.utf8),re=try NSRegularExpression(pattern:"(?:src|href)=\"([^\"]+\\.(?:js|css))\"")
            let n=html as NSString;for m in re.matches(in:html,range:NSRange(location:0,length:n.length)){let name=n.substring(with:m.range(at:1));guard !name.contains("/"),FileManager.default.fileExists(atPath:root.appendingPathComponent(name).path) else{throw NSError(domain:"KongScholar",code:27,userInfo:[NSLocalizedDescriptionKey:"界面资源缺失："+name])}};return"脚本和样式文件齐全；运行错误在界面中另列"
        }}
        return["at":ISO8601DateFormatter().string(from:Date()),"checks":checks,"ok":checks.allSatisfy{$0["state"] as? String=="通过"},"pendingExports30":pendingExports30]
    }
}
