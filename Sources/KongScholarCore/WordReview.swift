import Foundation

public enum WordReview {
    public static func read(_ bytes: Data) throws -> [String: Any] {
        let zip = try BoundedZip(bytes,limit:64*1024*1024)
        guard zip.members.contains(where:{$0.name == "word/document.xml"}) else { throw ScholarStoreError.invalidData }
        let xml=try zip.read("word/document.xml",limit:12*1024*1024)
        let revisions=try WordRevisions32.read(xml)
        let document = try parse(xml, comments:false)
        guard zip.members.contains(where:{$0.name == "word/comments.xml"}) else { return revisions.merging(["sha256":ScholarArchive.digest(bytes),"comments":[],"deliveryTokens29":document.deliveryTokens29.sorted(),"message":"此文件没有可读取的Word批注正文；可另到修订痕迹工作台查看已识别的文字增删。"],uniquingKeysWith:{$1}) }
        let comments = try parse(zip.read("word/comments.xml",limit:4*1024*1024),comments:true)
        guard comments.rows.count <= 2000 else { throw ScholarStoreError.tooLarge }
        let(rows,warnings,status)=try ModernComments31.enrich(comments.rows,documentAnchors:document.anchors,zip:zip)
        return revisions.merging(["sha256":ScholarArchive.digest(bytes),"comments":rows,"deliveryTokens29":document.deliveryTokens29.sorted(),"warnings31":warnings,"parts31":status,"message":"读取批注正文及文件中可识别的回复、解决状态和稳定编号；扩展缺失时明确提示。正文、脚注、附件及提及不写入；文字增删另到修订痕迹工作台接续。"],uniquingKeysWith:{$1})
    }
    private static func parse(_ bytes:Data, comments:Bool) throws -> ReviewXML {
        guard let text = String(data:bytes,encoding:.utf8), !text.localizedCaseInsensitiveContains("<!DOCTYPE"), !text.localizedCaseInsensitiveContains("<!ENTITY") else { throw ScholarStoreError.invalidData }
        let delegate = ReviewXML(comments:comments), parser = XMLParser(data:bytes);parser.shouldResolveExternalEntities = false;parser.delegate = delegate
        guard parser.parse(), !delegate.invalid else { throw ScholarStoreError.invalidData };return delegate
    }
}
private final class ReviewXML:NSObject,XMLParserDelegate {
    let isComments:Bool; var rows=[[String:String]](), anchors=[String:[String]](), invalid=false
    var anchorBytes=0
    var deliveryTokens29=Set<String>()
    var current=[String:String](), paragraph="", active=Set<String>(), paragraphIDs=Set<String>(), textDepth=0, deletedDepth=0
    init(comments:Bool){isComments=comments}
    func key(_ s:String)->String{String(s.split(separator:":").last ?? Substring(s))}
    func parser(_ parser:XMLParser,didStartElement name:String,namespaceURI:String?,qualifiedName:String?,attributes:[String:String]) {
        let n=key(name);let a=Dictionary(attributes.map{(key($0.key),$0.value)},uniquingKeysWith:{$1})
        if n == "del" {deletedDepth += 1}
        if n == "comment" {current=["commentID":a["id"] ?? "","author":a["author"] ?? "","date":a["date"] ?? "","body":""]}
        if n == "p" {paragraph="";paragraphIDs=active;if isComments{current["paraID31"]=a["paraId"] ?? ""}}
        if !isComments && n == "commentRangeStart",let id=a["id"] {active.insert(id);paragraphIDs.insert(id)}
        if !isComments && ["commentReference","commentRangeEnd"].contains(n),let id=a["id"] {paragraphIDs.insert(id);if n == "commentRangeEnd" {active.remove(id)}}
        if n == "t" && deletedDepth == 0 {textDepth += 1}
        if n == "tab" {paragraph += "\t"};if n == "br" {paragraph += "\n"}
        if paragraph.count > 100000 || active.count > 2000 || paragraphIDs.count > 2000 || paragraphIDs.contains(where:{$0.utf8.count>64}) {invalid=true;parser.abortParsing()}
    }
    func parser(_ parser:XMLParser,foundCharacters string:String){if textDepth > 0 {paragraph += string;if paragraph.utf8.count>100000 {invalid=true;parser.abortParsing()}}}
    func parser(_ parser:XMLParser,didEndElement name:String,namespaceURI:String?,qualifiedName:String?) {
        let n=key(name)
        if n == "t" && textDepth>0 {textDepth -= 1};if n == "del" {deletedDepth -= 1}
        if n == "p" {
            if !isComments,paragraph.range(of:"^稿次标识：KS29-[A-F0-9]{32}$",options:.regularExpression) != nil {deliveryTokens29.insert(String(paragraph.dropFirst(5)));if deliveryTokens29.count>50{invalid=true;parser.abortParsing();return}}
            if isComments {current["body",default:""] += (current["body",default:""].isEmpty ? "":"\n")+paragraph}
            else {for id in paragraphIDs where !(anchors[id] ?? []).contains(paragraph) {anchorBytes += paragraph.utf8.count;if anchorBytes>12*1024*1024 || anchors.count>2000 {invalid=true;parser.abortParsing();return};anchors[id,default:[]].append(paragraph)}}
        }
        if n == "comment" {if rows.count>=2000 {invalid=true;parser.abortParsing();return};if current["commentID"]?.isEmpty != false || rows.contains(where:{$0["commentID"]==current["commentID"]}) {invalid=true;parser.abortParsing()};rows.append(current);current=[:]}
    }
}
