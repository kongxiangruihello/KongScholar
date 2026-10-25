import AppKit
import KongScholarCore

extension AppDelegate {
    func personalPrompt(_ prompt:String,text:String?,completion:@escaping(String?)->Void)->Bool {
        if deliveryPrompt34(prompt,text:text,completion:completion){return true}
        if reviewPrompt32(prompt,text:text,completion:completion){return true}
        if studioPrompt31(prompt,text:text,completion:completion){return true}
        if continuityPrompt30(prompt,text:text,completion:completion){return true}
        if stabilityPrompt(prompt,text:text,completion:completion){return true}
        let actions=["KONGSCHOLAR_DRAFT_LIST","KONGSCHOLAR_DRAFT_SAVE","KONGSCHOLAR_DRAFT_REMOVE","KONGSCHOLAR_FILES_CHECK","KONGSCHOLAR_FILES_SEARCH","KONGSCHOLAR_FILES_VERIFY"]
        guard actions.contains(prompt) else{return false}
        do {
            if prompt=="KONGSCHOLAR_DRAFT_LIST" {completion(jsonString(["drafts":try EditingDrafts.list(root:store.directory,summary:true)]));return true}
            let bytes=Data((text ?? "{}").utf8);guard bytes.count<=16*1024*1024 else{throw ScholarStoreError.tooLarge}
            if prompt=="KONGSCHOLAR_DRAFT_SAVE" {guard let v=try JSONSerialization.jsonObject(with:bytes) as? [String:Any] else{throw ScholarStoreError.invalidData};try EditingDrafts.save(v,root:store.directory);completion(jsonString(["saved":true]));return true}
            if prompt=="KONGSCHOLAR_DRAFT_REMOVE" {guard let v=try JSONSerialization.jsonObject(with:bytes) as? [String:String],let key=v["key"] else{throw ScholarStoreError.invalidData};try EditingDrafts.remove(key:key,root:store.directory);completion(jsonString(["removed":true]));return true}
            let links=try JSONDecoder().decode([AttachmentLink].self,from:bytes);guard links.count<=2000,Set(links.map(\.key)).count==links.count else{throw ScholarStoreError.invalidData}
            if prompt=="KONGSCHOLAR_FILES_VERIFY" {let rows=try links.map{try AttachmentHealth.verify($0,at:URL(fileURLWithPath:$0.path))};completion(jsonString(["rows":rows]));return true}
            if prompt=="KONGSCHOLAR_FILES_CHECK" {researchWork("检查附件位置",completion:completion){["rows":AttachmentHealth.inspect(links)]};return true}
            let panel=NSOpenPanel();panel.title="选择查找搬移文件的目录（仅检查此目录）";panel.canChooseFiles=false;panel.canChooseDirectories=true
            panel.beginSheetModal(for:window){r in guard r == .OK,let url=panel.url else{completion(nil);return};self.researchWork("查找内容一致的附件",completion:completion){try AttachmentHealth.search(links,folder:url)}}
        }catch{completion("error:"+error.localizedDescription)}
        return true
    }
}
