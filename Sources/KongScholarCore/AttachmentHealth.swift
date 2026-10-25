import Foundation

public struct AttachmentLink: Codable {
    public var key:String
    public var kind:String
    public var path:String
    public var bookmark:String?
    public var sha256:String?
    public var documentID:String?
    public init(key:String,kind:String,path:String,bookmark:String?=nil,sha256:String?=nil,documentID:String?=nil){self.key=key;self.kind=kind;self.path=path;self.bookmark=bookmark;self.sha256=sha256;self.documentID=documentID}
}
public enum AttachmentHealth {
    public static func resolved(_ link:AttachmentLink)->URL {
        if let value=link.bookmark,let bytes=Data(base64Encoded:value){var stale=false;if let u=try? URL(resolvingBookmarkData:bytes,options:[.withoutUI,.withoutMounting],relativeTo:nil,bookmarkDataIsStale:&stale){return u}}
        return URL(fileURLWithPath:link.path)
    }
    private static func proof(_ link:AttachmentLink,at url:URL) throws -> [String:Any] {
        guard link.path.hasPrefix("/"),["pdf","folio","attachment"].contains(link.kind),url.isFileURL else{throw ScholarStoreError.invalidData}
        let info=try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey]);guard info.isRegularFile==true,info.isSymbolicLink != true,(info.fileSize ?? Int.max)<=512*1024*1024 else{throw ScholarStoreError.tooLarge}
        let bytes:Data
        if link.kind=="folio" || !(link.documentID ?? "").isEmpty {
            guard try FolioOrigin.projectID(at:url)==link.documentID else{throw ScholarStoreError.invalidData}
            bytes=try EvidenceImage.pdfData(at:url,expectedID:link.documentID!)
        }else{guard link.kind != "pdf" || url.pathExtension.lowercased()=="pdf" else{throw ScholarStoreError.invalidData};bytes=try Data(contentsOf:url)}
        let digest=ScholarArchive.digest(bytes)
        return ["key":link.key,"path":url.path,"bookmark":try url.bookmarkData(options:.minimalBookmark,includingResourceValuesForKeys:nil,relativeTo:nil).base64EncodedString(),"sha256":digest]
    }
    private static func matched(_ value:[String:Any],link:AttachmentLink) throws -> [String:Any] {
        if let hash=link.sha256,!hash.isEmpty {guard value["sha256"] as? String==hash else{throw NSError(domain:"KongScholar",code:26,userInfo:[NSLocalizedDescriptionKey:"文件内容与关联时不同"])} }
        else {guard link.kind=="folio" else{throw ScholarStoreError.invalidData}}
        var result=value;result["key"]=link.key;result["proof"]=(link.sha256 ?? "").isEmpty ? "文档编号一致（原记录无PDF指纹）":"内容指纹一致";return result
    }
    public static func verify(_ link:AttachmentLink,at url:URL) throws -> [String:Any] {try matched(proof(link,at:url),link:link)}
    public static func inspect(_ links:[AttachmentLink])->[[String:Any]] {
        var cache=[String:Result<[String:Any],Error>]()
        return links.map{l in
            let url=resolved(l),key=[url.path,l.kind,l.documentID ?? ""].joined(separator:"|")
            if cache[key]==nil {cache[key]=Result{try proof(l,at:url)}}
            do{var r=try matched(try cache[key]!.get(),link:l);r["state"]="可用";return r}catch{return["key":l.key,"path":l.path,"state":"待处理","error":error.localizedDescription]}
        }
    }
    public static func search(_ links:[AttachmentLink],folder:URL) throws -> [String:Any] {
        var unreadable=0
        guard links.count<=2000,let walker=FileManager.default.enumerator(at:folder,includingPropertiesForKeys:[.isRegularFileKey,.isSymbolicLinkKey],options:[.skipsHiddenFiles],errorHandler:{_,_ in unreadable += 1;return true}) else{throw ScholarStoreError.invalidData}
        var rows=[[String:Any]](),count=0,truncated=false,readBytes=0
        var cache=[String:[String:Any]]()
        for case let url as URL in walker {
            count += 1;if count>20000{truncated=true;break}
            let info=try? url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey]);if info?.isSymbolicLink==true{walker.skipDescendants();continue};guard info?.isRegularFile==true else{continue}
            let ext=url.pathExtension.lowercased();guard ["pdf","kongfolio","docx","md","txt"].contains(ext) else{continue}
            for link in links where (link.kind=="folio" || !(link.documentID ?? "").isEmpty) ? ext=="kongfolio" : ext==URL(fileURLWithPath:link.path).pathExtension.lowercased() {
                let identity=[link.kind,link.documentID ?? "",url.path].joined(separator:"|")
                var result=cache[identity]
                if result==nil {
                    let size=(try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize) ?? Int.max
                    if size>512*1024*1024-readBytes {truncated=true;break};readBytes += size
                    if let value=try? proof(link,at:url){result=value;cache[identity]=value}else{cache[identity]=["failed":true];continue}
                }
                guard let value=result,value["failed"]==nil,let row=try? matched(value,link:link) else{continue};rows.append(row)
                if rows.count>=2000{truncated=true;break}
            }
            if truncated||rows.count>=2000{break}
        }
        return ["candidates":rows,"visited":min(count,20000),"truncated":truncated,"folder":folder.path,"readBytes":readBytes,"unreadable":unreadable]
    }
}
