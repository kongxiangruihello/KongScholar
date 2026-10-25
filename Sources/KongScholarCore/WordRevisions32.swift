import Foundation

/// Reads paragraph text insertions/deletions only. It never accepts revisions or rewrites a Word file.
public enum WordRevisions32 {
    public static func read(_ bytes:Data)throws->[String:Any]{
        guard bytes.count<=12*1024*1024,let text=String(data:bytes,encoding:.utf8),!text.localizedCaseInsensitiveContains("<!DOCTYPE"),!text.localizedCaseInsensitiveContains("<!ENTITY") else{throw ScholarStoreError.invalidData}
        let delegate=RevisionXML32(),parser=XMLParser(data:bytes);parser.shouldProcessNamespaces=true;parser.shouldResolveExternalEntities=false;parser.delegate=delegate
        guard parser.parse(),!delegate.invalid else{throw ScholarStoreError.invalidData}
        return ["revisions32":delegate.rows,"revisionUnsupported32":delegate.unsupported,"revisionScope32":"仅解析主文档正文段落内的文字插入和删除；局部前后文本不等于完整返回稿。移动、格式、段落标记、表格、页眉页脚、脚注和附件等须回Word核对。不会自动采纳修订或改写正文。"]
    }
}
private final class RevisionXML32:NSObject,XMLParserDelegate {
    struct Change{var kind:String,id:String,author:String,date:String,text="",partial=false,ordinal:Int}
    let wordNS=["http://schemas.openxmlformats.org/wordprocessingml/2006/main","http://purl.oclc.org/ooxml/wordprocessingml/main"]
    var rows=[[String:Any]](),unsupported=[String:Int](),stack=[String](),invalid=false,paragraph=0,bodyDepth=0,tableDepth=0,change:Change?,pending=[Change](),before="",after="",textMode="",textDepth=0,total=0,serial=0
    var inParagraph=false,ignoredDepth=0,rowBytes=0
    func fail(_ p:XMLParser){invalid=true;p.abortParsing()}
    func local(_ s:String)->String{String(s.split(separator:":").last ?? Substring(s))}
    func parser(_ parser:XMLParser,didStartElement name:String,namespaceURI:String?,qualifiedName:String?,attributes:[String:String]){
        guard stack.count<256 else{return fail(parser)};let n=wordNS.contains(namespaceURI ?? "") ? name:"foreign:"+name,parent=stack.last ?? "";stack.append(n)
        if ignoredDepth>0{return};if ["txbxContent","object","drawing"].contains(n){if change != nil{change?.partial=true;unsupported[n,default:0]+=1};ignoredDepth=stack.count;return}
        if n=="body"{bodyDepth+=1};if n=="tbl"{tableDepth+=1}
        if n=="p"&&bodyDepth>0{if inParagraph{return fail(parser)};paragraph+=1;if paragraph>20000{return fail(parser)};inParagraph=true;before="";after="";pending=[]}
        let revision=["ins","del"].contains(n)
        if revision{
            let supported=inParagraph&&tableDepth==0&&change==nil&&["p","hyperlink","smartTag","sdtContent"].contains(parent) && !stack.contains(where:{["moveFrom","moveTo","pPr","rPr"].contains($0)})
            if supported{serial+=1;if serial>2000{return fail(parser)};let a=Dictionary(attributes.map{(local($0.key),$0.value)},uniquingKeysWith:{$1});if a.values.contains(where:{$0.utf8.count>1000}){return fail(parser)};change=Change(kind:n=="ins" ? "插入":"删除",id:a["id"] ?? "",author:a["author"] ?? "",date:a["date"] ?? "",ordinal:serial)}
            else{unsupported[n+"（非可解析的正文文字）",default:0]+=1;change?.partial=true}
        }
        if ["moveFrom","moveTo","pPrChange","rPrChange","tblPrChange","trPrChange","tcPrChange","cellIns","cellDel","numberingChange"].contains(n){unsupported[n,default:0]+=1;change?.partial=true}
        if change != nil&&["drawing","object","footnoteReference","endnoteReference","instrText","fldChar","sym"].contains(n){change?.partial=true;unsupported[n,default:0]+=1}
        if ["t","delText"].contains(n)&&inParagraph{textMode=n;textDepth=stack.count}
        if ["tab","br","cr"].contains(n)&&inParagraph{append(n=="tab" ? "\t":"\n",parser)}
    }
    func append(_ s:String,_ parser:XMLParser){
        total+=s.utf8.count;if total>12*1024*1024{return fail(parser)}
        if change?.kind=="插入"{after+=s;change?.text+=s}else if change?.kind=="删除"{before+=s;change?.text+=s}else if !stack.contains("del") {before+=s;after+=s}
        if before.utf8.count>200000||after.utf8.count>200000||(change?.text.utf8.count ?? 0)>100000{fail(parser)}
    }
    func parser(_ parser:XMLParser,foundCharacters string:String){if textDepth>0&&inParagraph&&ignoredDepth==0{append(string,parser)}}
    func parser(_ parser:XMLParser,didEndElement name:String,namespaceURI:String?,qualifiedName:String?){
        let n=wordNS.contains(namespaceURI ?? "") ? name:"foreign:"+name
        if ignoredDepth>0{if stack.count==ignoredDepth{ignoredDepth=0};if stack.last != n{return fail(parser)};stack.removeLast();return}
        if textDepth==stack.count{textDepth=0;textMode=""}
        if ["ins","del"].contains(n),let c=change,stack.count>=2,["p","hyperlink","smartTag","sdtContent"].contains(stack[stack.count-2]){pending.append(c);change=nil}
        if n=="p"&&inParagraph{
            for c in pending {rowBytes+=c.text.utf8.count+before.utf8.count+after.utf8.count;if rowBytes>12*1024*1024{return fail(parser)};rows.append(["ordinal32":c.ordinal,"wordID32":c.id,"kind32":c.kind,"author":c.author,"date":c.date,"text":c.text,"before32":before,"after32":after,"paragraph32":paragraph,"requiresWord32":c.partial||c.text.isEmpty])};inParagraph=false
        }
        if n=="tbl"{tableDepth-=1};if n=="body"{bodyDepth-=1};if stack.last != n{return fail(parser)};stack.removeLast()
    }
}
