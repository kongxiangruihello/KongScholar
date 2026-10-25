import Foundation
import ImageIO

public struct WordBlock31: Codable {
    public var marker: String
    public var kind: String
    public var title: String
    public var caption: String
    public var source: String
    public var png: String?
    public var widthCM: Double?
    public var rows: [[String]]?
    public init(marker:String,kind:String,title:String,caption:String,source:String,png:String?=nil,widthCM:Double?=nil,rows:[[String]]?=nil){self.marker=marker;self.kind=kind;self.title=title;self.caption=caption;self.source=source;self.png=png;self.widthCM=widthCM;self.rows=rows}
}
public struct WordIndexMark31: Codable {
    public var offset: Int
    public var text: String
    public var term: String
    public init(offset:Int,text:String,term:String){self.offset=offset;self.text=text;self.term=term}
}

/// Native OOXML blocks. Images are embedded bytes, never external URLs or paths.
enum WordComponents31 {
    static func valid(_ b:WordBlock31)throws {
        guard b.marker.range(of:"^\\[\\[KS31-(FIG|TABLE):[A-Za-z0-9_-]{1,100}\\]\\]$",options:.regularExpression) != nil,
              ["image","table"].contains(b.kind),!b.title.isEmpty,b.title.count<=500,b.caption.count<=10000,!b.source.isEmpty,b.source.count<=10000 else{throw WordExportError.invalid}
        if b.kind=="image"{_ = try image(b)}else{guard let rows=b.rows,(2...100).contains(rows.count),let count=rows.first?.count,(1...12).contains(count),rows.allSatisfy({$0.count==count&&$0.allSatisfy{$0.count<=5000}}),rows.joined().reduce(0,{$0+$1.utf8.count})<=2*1024*1024 else{throw WordExportError.invalid}}
    }
    static func image(_ b:WordBlock31)throws->(Data,Double,Double){
        guard let encoded=b.png,encoded.utf8.count<=12*1024*1024,let bytes=Data(base64Encoded:encoded),bytes.count<=8*1024*1024,bytes.starts(with:[137,80,78,71,13,10,26,10]),let source=CGImageSourceCreateWithData(bytes as CFData,nil),CGImageSourceGetCount(source)==1,
              let props=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [String:Any],let width=props[kCGImagePropertyPixelWidth as String] as? Int,let height=props[kCGImagePropertyPixelHeight as String] as? Int,width>0,height>0,width<=6000,height<=6000,
              let image=CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldCache:false] as CFDictionary),image.width==width,image.height==height else{throw WordExportError.invalid}
        let cm=b.widthCM ?? 12;guard cm.isFinite,(2...16).contains(cm) else{throw WordExportError.invalid}
        let w=cm*360000,h=w*Double(height)/Double(width);guard h<=22*360000 else{throw WordExportError.invalid};return(bytes,w,h)
    }
    static func render(_ b:WordBlock31,serial:Int,availableCM:Double)throws->String{
        try valid(b);let x=WordExport.xml,run=WordExport.run
        let title="<w:p><w:pPr><w:keepNext/></w:pPr>\(run(b.title))</w:p>"
        let foot=(b.caption.isEmpty ? "":"<w:p><w:pPr><w:keepNext/><w:spacing w:before=\"80\" w:after=\"80\"/></w:pPr>\(run(b.caption))</w:p>")+"<w:p><w:pPr><w:spacing w:before=\"80\" w:after=\"160\"/></w:pPr>\(run("来源："+b.source))</w:p>"
        if b.kind=="image"{
            let(_,w,h)=try image(b),cx=Int(w),cy=Int(h)
            return title+"""
            <w:p><w:pPr><w:jc w:val="center"/><w:keepNext/></w:pPr><w:r><w:drawing><wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" distT="0" distB="0" distL="0" distR="0"><wp:extent cx="\(cx)" cy="\(cy)"/><wp:docPr id="\(serial)" name="\(x(b.title))" descr="\(x(b.caption.isEmpty ? b.title:b.caption))"/><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="\(serial)" name="figure-\(serial).png"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="rIdImage31-\(serial)"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>
            """+foot
        }
        let rows=b.rows!,cols=rows[0].count,width=Int(availableCM*1440/2.54)/cols,borders=["top","left","bottom","right","insideH","insideV"].map{"<w:\($0) w:val=\"single\" w:sz=\"4\" w:color=\"D9D9D9\"/>"}.joined()
        let keepShort=rows.count<=10&&rows.joined().reduce(0,{$0+$1.count})<=2000
        let body=rows.enumerated().map{i,row in "<w:tr>"+"<w:trPr><w:cantSplit/>"+(i==0 ? "<w:tblHeader/>":"")+"</w:trPr>"+row.map{cell in "<w:tc><w:tcPr><w:tcW w:w=\"\(width)\" w:type=\"dxa\"/><w:vAlign w:val=\"center\"/><w:shd w:fill=\"\(i==0 ? "E6E6E6":(i%2==0 ? "F7F7F7":"FFFFFF"))\"/></w:tcPr>"+cell.components(separatedBy:"\n").map{"<w:p><w:pPr>\(keepShort||i==rows.count-1 ? "<w:keepNext/>":"")<w:spacing w:after=\"80\" w:line=\"280\"/></w:pPr>\(run($0))</w:p>"}.joined()+"</w:tc>"}.joined()+"</w:tr>"}.joined()
        return title+"<w:tbl><w:tblPr><w:tblW w:w=\"0\" w:type=\"auto\"/><w:tblBorders>\(borders)</w:tblBorders><w:tblCellMar><w:top w:w=\"120\" w:type=\"dxa\"/><w:left w:w=\"140\" w:type=\"dxa\"/><w:bottom w:w=\"120\" w:type=\"dxa\"/><w:right w:w=\"140\" w:type=\"dxa\"/></w:tblCellMar></w:tblPr><w:tblGrid>\(Array(repeating:"<w:gridCol w:w=\"\(width)\"/>",count:cols).joined())</w:tblGrid>\(body)</w:tbl>"+foot
    }
    static func markedBody(_ chapter:WordChapter)throws->String{
        let text=chapter.body as NSString,marks=chapter.indexMarks31 ?? []
        guard marks.count<=5000,!chapter.body.contains("[[KSI31:") else{throw WordExportError.invalid}
        let protected=try NSRegularExpression(pattern:"\\[\\^ks-[A-Za-z0-9-]+\\]|\\[\\[KS31-[^\\n]*\\]\\]").matches(in:chapter.body,range:NSRange(location:0,length:text.length)).map(\.range)
        var end=0
        for m in marks.sorted(by:{$0.offset<$1.offset}){let n=(m.text as NSString).length;guard !m.text.isEmpty,m.offset>=end,m.offset<=text.length,n<=text.length-m.offset,text.substring(with:NSRange(location:m.offset,length:n))==m.text,!protected.contains(where:{NSIntersectionRange($0,NSRange(location:m.offset,length:n)).length>0}),!m.term.isEmpty,m.term.count<=200,!m.term.contains("\""),!m.term.contains("\\"),!m.term.unicodeScalars.contains(where:{CharacterSet.controlCharacters.contains($0)}) else{throw WordExportError.invalid};end=m.offset+n}
        var value=chapter.body
        for(i,m)in marks.enumerated().sorted(by:{$0.element.offset>$1.element.offset}){let n=m.offset+(m.text as NSString).length,ns=value as NSString;value=ns.substring(to:n)+"[[KSI31:\(i)]]"+ns.substring(from:n)};return value
    }
    static func indexRun(_ text:String,marks:[WordIndexMark31])throws->String{
        let ns=text as NSString,re=try NSRegularExpression(pattern:"\\[\\[KSI31:([0-9]+)\\]\\]");var result="",at=0
        for match in re.matches(in:text,range:NSRange(location:0,length:ns.length)){
            guard let i=Int(ns.substring(with:match.range(at:1))),marks.indices.contains(i) else{throw WordExportError.invalid}
            result+=WordExport.run(ns.substring(with:NSRange(location:at,length:match.range.location-at)))
            result+="<w:fldSimple w:instr=\"\(WordExport.xml(" XE \""+marks[i].term+"\" "))\"><w:r><w:rPr><w:vanish/></w:rPr><w:t/></w:r></w:fldSimple>";at=NSMaxRange(match.range)
        };return result+WordExport.run(ns.substring(from:at))
    }
}
