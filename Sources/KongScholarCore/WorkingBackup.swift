import Foundation

public enum WorkingBackup {
    public static func generate(text:String,drafts:Data?)throws->Data{
        let full=try ScholarStore.validate(text);var parts=["data.json":full],manifest:[String:Any]=["format":"KongScholar-WorkingBackup","version":1,"dataSHA256":ScholarArchive.digest(full),"draftsIncluded":drafts != nil]
        if let drafts=drafts{let rows=try EditingDrafts.inspectPortable(drafts);parts["editing-drafts.json"]=drafts;manifest["draftsSHA256"]=ScholarArchive.digest(drafts);manifest["draftCount"]=rows.count}
        parts["manifest.json"]=try JSONSerialization.data(withJSONObject:manifest,options:[.sortedKeys]);let out=WordExport.archive(parts);guard out.count<=ScholarStore.limit else{throw ScholarStoreError.tooLarge};return out
    }
    public static func inspect(_ bytes:Data)throws->(text:String,drafts:Data?,count:Int){
        let zip=try BoundedZip(bytes);guard let m=try JSONSerialization.jsonObject(with:zip.read("manifest.json",limit:1024*1024)) as? [String:Any],m["format"] as? String=="KongScholar-WorkingBackup",m["version"] as? Int==1,let included=m["draftsIncluded"] as? Bool else{throw ScholarStoreError.invalidData}
        let data=try zip.read("data.json");guard ScholarArchive.digest(data)==m["dataSHA256"] as? String,let text=String(data:data,encoding:.utf8) else{throw ScholarStoreError.invalidData};_ = try ScholarStore.validate(text)
        var drafts:Data?,count=0
        if included{let d=try zip.read("editing-drafts.json",limit:EditingDrafts.totalLimit);guard ScholarArchive.digest(d)==m["draftsSHA256"] as? String else{throw ScholarStoreError.invalidData};count=try EditingDrafts.inspectPortable(d).count;guard count==m["draftCount"] as? Int else{throw ScholarStoreError.invalidData};drafts=d}
        guard Set(zip.members.map{$0.name})==Set(["manifest.json","data.json"]+(included ? ["editing-drafts.json"] : [])) else{throw ScholarStoreError.invalidData};return(text,drafts,count)
    }
}
