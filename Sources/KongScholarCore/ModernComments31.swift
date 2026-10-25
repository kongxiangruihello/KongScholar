import Foundation

// MS-DOCX CT_CommentEx / CT_CommentId / CT_CommentExtensible. Extension
// attributes add linkage and status; they never substitute for comment text.
enum ModernComments31 {
    static func enrich(_ input:[[String:String]],documentAnchors:[String:[String]],zip:BoundedZip)throws->([[String:Any]],[String],[String:String]) {
        var extensions=[String:[String:String]](),ids=[String:String](),extra=[String:[String:String]](),status=[String:String](),warnings=[String]()
        for(name,element)in [("word/commentsExtended.xml","commentEx"),("word/commentsIds.xml","commentId"),("word/commentsExtensible.xml","commentExtensible")]{
            guard zip.members.contains(where:{$0.name==name}) else{status[name]="文件中未提供";continue}
            let bytes=try zip.read(name,limit:4*1024*1024),rows=try parse(bytes,element:element);status[name]="已读取\(rows.count)条扩展记录"
            for row in rows{
                if element=="commentEx"{guard let p=row["paraId"],p.range(of:"^[A-Fa-f0-9]{8}$",options:.regularExpression) != nil,extensions[p.uppercased()]==nil,row["done"].map({["0","1","true","false","on","off"].contains($0.lowercased())}) ?? true,row["paraIdParent"].map({$0.range(of:"^[A-Fa-f0-9]{8}$",options:.regularExpression) != nil}) ?? true else{throw ScholarStoreError.invalidData};extensions[p.uppercased()]=row}
                if element=="commentId"{guard let p=row["paraId"],let d=row["durableId"],p.range(of:"^[A-Fa-f0-9]{8}$",options:.regularExpression) != nil,let n=UInt32(d,radix:16),n>0,n<0x7fffffff,ids[p.uppercased()]==nil,!ids.values.contains(d.uppercased()) else{throw ScholarStoreError.invalidData};ids[p.uppercased()]=d.uppercased()}
                if element=="commentExtensible"{guard let d=row["durableId"],extra[d.uppercased()]==nil else{throw ScholarStoreError.invalidData};extra[d.uppercased()]=row}
            }
        }
        var byPara=[String:String]()
        for row in input{if let p=row["paraID31"],!p.isEmpty{guard byPara[p.uppercased()]==nil else{throw ScholarStoreError.invalidData};byPara[p.uppercased()]=row["commentID"]}}
        let byID=Dictionary(uniqueKeysWithValues:input.map{($0["commentID"]!, $0)}),parents=Dictionary(uniqueKeysWithValues:input.map{row ->(String,String) in let p=row["paraID31"]?.uppercased() ?? "",parent=extensions[p]?["paraIdParent"]?.uppercased();return(row["commentID"]!,parent.flatMap{byPara[$0]} ?? "")})
        func root(_ id:String)throws->String{var seen=Set<String>(),next=id;while let p=parents[next],!p.isEmpty{guard seen.insert(next).inserted,seen.count<=2000 else{throw ScholarStoreError.invalidData};next=p};return next}
        var result=[[String:Any]]()
        for row in input{
            let id=row["commentID"]!,p=row["paraID31"]?.uppercased() ?? "",e=extensions[p] ?? [:],thread=try root(id),parent=parents[id] ?? "",durable=ids[p] ?? "",rootPara=byID[thread]?["paraID31"]?.uppercased() ?? "",done=e["done"] ?? extensions[rootPara]?["done"] ?? "0"
            if let raw=e["paraIdParent"],!raw.isEmpty,parent.isEmpty{warnings.append("批注\(id)的上级回复未匹配，保留为待核，不推断所属线程。")}
            var value:[String:Any]=row;value["anchor"]=(documentAnchors[id] ?? documentAnchors[thread] ?? []).joined(separator:"\n");value["parentID31"]=parent;value["threadID31"]=thread;value["done31"]=["1","true","on"].contains(done.lowercased());value["durableID31"]=durable;value["dateUTC31"]=extra[durable]?["dateUtc"] ?? "";value["modern31"] = !e.isEmpty || !durable.isEmpty
            result.append(value)
        }
        if !extensions.isEmpty&&extensions.keys.contains(where:{byPara[$0]==nil}){warnings.append("部分扩展记录没有对应批注正文，仅保留可读取的批注；请对照原Word。")}
        return(result,warnings,status)
    }
    private static func parse(_ bytes:Data,element:String)throws->[[String:String]]{
        guard let text=String(data:bytes,encoding:.utf8),!text.localizedCaseInsensitiveContains("<!DOCTYPE"),!text.localizedCaseInsensitiveContains("<!ENTITY") else{throw ScholarStoreError.invalidData}
        let delegate=ExtensionXML31(element:element),parser=XMLParser(data:bytes);parser.shouldResolveExternalEntities=false;parser.shouldProcessNamespaces=true;parser.delegate=delegate
        guard parser.parse(),!delegate.invalid else{throw ScholarStoreError.invalidData};return delegate.rows
    }
}
private final class ExtensionXML31:NSObject,XMLParserDelegate {
    let element:String;var rows=[[String:String]](),invalid=false
    init(element:String){self.element=element}
    func parser(_ parser:XMLParser,didStartElement name:String,namespaceURI:String?,qualifiedName:String?,attributes:[String:String]){
        guard name.split(separator:":").last.map(String.init)==element else{return}
        let expected=["commentEx":"http://schemas.microsoft.com/office/word/2012/wordml","commentId":"http://schemas.microsoft.com/office/word/2016/wordml/cid","commentExtensible":"http://schemas.microsoft.com/office/word/2018/wordml/cex"][element]
        guard namespaceURI==expected else{invalid=true;parser.abortParsing();return}
        guard rows.count<2000,attributes.count<=30,attributes.values.allSatisfy({$0.utf8.count<=1000}) else{invalid=true;parser.abortParsing();return}
        rows.append(Dictionary(attributes.map{(String($0.key.split(separator:":").last!),$0.value)},uniquingKeysWith:{$1}))
    }
}
