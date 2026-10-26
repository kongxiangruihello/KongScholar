import Foundation

/// Read-only post-migration verification. Never launches an application or rewrites links.
public enum Migration39 {
    public static func check(_ text:String)throws->[String:Any] {
        guard let root=try JSONSerialization.jsonObject(with:ScholarStore.validate(text)) as? [String:Any] else {throw ScholarStoreError.invalidData}
        let refs=Migration34.references(root)
        guard refs.count<=2000 else {throw ScholarStoreError.tooLarge}
        let links=refs.map{r in AttachmentLink(key:r.key,kind:r.link.kind,path:r.link.path,bookmark:r.link.bookmark,sha256:r.link.sha256,documentID:r.link.documentID)}
        let inspected=AttachmentHealth.inspect(links)
        let rows=zip(refs,inspected).map {ref,status -> [String:Any] in var row=status;row["title"]=ref.title;row["kind"]=ref.link.kind;return row}
        return ["rows":rows,"checkedAt":ISO8601DateFormatter().string(from:Date())]
    }
}
