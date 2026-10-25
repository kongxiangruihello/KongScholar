import Foundation

public enum UpgradeProtection {
    public static func protect(_ store:ScholarStore,version:String,allowDamaged:Bool=false) throws -> [String:Any] {
        guard version.range(of:"^[0-9]+\\.[0-9]+\\.[0-9]+$",options:.regularExpression) != nil else{throw ScholarStoreError.invalidData}
        let fm=FileManager.default,folder=store.directory.appendingPathComponent("upgrades",isDirectory:true),receipt=folder.appendingPathComponent("release-"+version+".json")
        if fm.fileExists(atPath:receipt.path){
            guard let r=try JSONSerialization.jsonObject(with:Data(contentsOf:receipt)) as? [String:Any],r["version"] as? String==version else{throw ScholarStoreError.invalidData}
            if r["state"] as? String=="new-library" {return r}
            guard let file=r["file"] as? String,file==URL(fileURLWithPath:file).lastPathComponent,let expected=r["sha256"] as? String else{throw ScholarStoreError.invalidData}
            let backup=folder.appendingPathComponent(file);guard (try backup.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max)<=ScholarStore.limit else{throw ScholarStoreError.tooLarge};let bytes=try Data(contentsOf:backup);guard bytes.count<=ScholarStore.limit,ScholarArchive.digest(bytes)==expected else{throw ScholarStoreError.invalidData};if r["state"] as? String != "raw-preserved" {guard let value=String(data:bytes,encoding:.utf8) else{throw ScholarStoreError.invalidData};_ = try ScholarStore.validate(value)};return r
        }
        try fm.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        var report:[String:Any]=["version":version,"at":ISO8601DateFormatter().string(from:Date())]
        if fm.fileExists(atPath:store.dataURL.path){
            let bytes:Data,damaged:Bool
            do{guard let value=try store.read() else{throw ScholarStoreError.invalidData};bytes=try ScholarStore.validate(value);damaged=false}
            catch{guard allowDamaged else{throw error};guard (try store.dataURL.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max)<=ScholarStore.limit else{throw ScholarStoreError.tooLarge};bytes=try Data(contentsOf:store.dataURL);damaged=true}
            let hash=ScholarArchive.digest(bytes),name=(damaged ? "unreadable-before-":"before-")+version+"-"+hash+(damaged ? ".bin":".json"),file=folder.appendingPathComponent(name)
            if !fm.fileExists(atPath:file.path){try bytes.write(to:file,options:.atomic);try fm.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)}
            guard try Data(contentsOf:file)==bytes else{throw ScholarStoreError.invalidData}
            report["state"]=damaged ? "raw-preserved":"verified";report["file"]=name;report["sha256"]=hash;report["bytes"]=bytes.count
        }else{report["state"]="new-library"}
        try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys]).write(to:receipt,options:.atomic);try fm.setAttributes([.posixPermissions:0o600],ofItemAtPath:receipt.path)
        guard let loaded=try JSONSerialization.jsonObject(with:Data(contentsOf:receipt)) as? NSDictionary,loaded==report as NSDictionary else{throw ScholarStoreError.invalidData};return report
    }
}
