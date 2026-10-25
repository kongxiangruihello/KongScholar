import Foundation
import PDFKit

/// Builds an explicitly selected, shareable packet; research-library JSON is never a member.
public enum Delivery34 {
    public static let limit = 32 * 1024 * 1024
    public static func prepare(files: [[String:String]], selections: [[String:Any]]) throws -> [[String:Any]] {
        guard !files.isEmpty, files.count <= 4, selections.count <= 50 else { throw ScholarStoreError.invalidData }
        var result = [[String:Any]](), names = Set<String>(), total = 0, pages = 0
        func append(_ name:String,_ bytes:Data) throws {
            guard safe(name), names.insert(name).inserted, bytes.count <= limit-total else { throw ScholarStoreError.tooLarge }
            total += bytes.count; result.append(["name":name,"base64":bytes.base64EncodedString(),"sha256":ScholarArchive.digest(bytes),"bytes":bytes.count])
        }
        for file in files { guard let name=file["name"],name.hasSuffix(".md"),let text=file["text"],text.utf8.count<=2*1024*1024 else { throw ScholarStoreError.invalidData };try append(name,Data(text.utf8)) }
        for (i,p) in selections.enumerated() {
            guard let path=p["path"] as? String,path.hasPrefix("/"),let hash=p["sha256"] as? String,hash.range(of:"^[a-f0-9]{64}$",options:.regularExpression) != nil,
                  let first=p["first"] as? Int,let last=p["last"] as? Int,first>=1,last>=first,last<=2000,last-first<200 else { throw ScholarStoreError.invalidData }
            pages += last-first+1;guard pages<=200 else {throw ScholarStoreError.tooLarge}
            let link=AttachmentLink(key:"selection",kind:"pdf",path:path,bookmark:p["bookmark"] as? String,sha256:hash,documentID:p["documentID"] as? String)
            let file=AttachmentHealth.resolved(link),info=try file.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey,.isSymbolicLinkKey]);guard info.isRegularFile==true,info.isSymbolicLink != true,(info.fileSize ?? Int.max)<=64*1024*1024 else {throw ScholarStoreError.tooLarge}
            let bytes:Data
            if let id=link.documentID,!id.isEmpty {bytes=try EvidenceImage.pdfData(at:file,expectedID:id)}else {guard file.pathExtension.lowercased()=="pdf" else {throw ScholarStoreError.invalidData};bytes=try Data(contentsOf:file)}
            guard ScholarArchive.digest(bytes)==hash,let doc=PDFDocument(data:bytes),!doc.isLocked,last<=doc.pageCount else {throw ScholarStoreError.invalidData}
            let output=PDFDocument();for page in first...last {guard let source=doc.page(at:page-1),let copy=source.copy() as? PDFPage else {throw ScholarStoreError.invalidData};for annotation in copy.annotations {copy.removeAnnotation(annotation)};output.insert(copy,at:output.pageCount)}
            guard let data=output.dataRepresentation(),let check=PDFDocument(data:data),check.pageCount==last-first+1 else {throw ScholarStoreError.invalidData}
            try append(String(format:"%02d-PDF-%d-%d.pdf",i+1,first,last),data)
        }
        return result
    }
    public static func safe(_ name:String)->Bool { !name.isEmpty && name.utf8.count<=180 && !name.hasPrefix(".") && !name.contains("/") && !name.contains("\\") && !name.contains(":") && !name.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains) && name != "manifest.json" }
    public static func parts(_ files:[[String:Any]]) throws -> [String:Data] {
        guard !files.isEmpty,files.count<=54 else {throw ScholarStoreError.invalidData};var parts=[String:Data](),total=0
        for file in files {guard let name=file["name"] as? String,safe(name),["md","pdf"].contains(URL(fileURLWithPath:name).pathExtension),parts[name]==nil,let encoded=file["base64"] as? String,encoded.utf8.count<=limit*4/3+8,let data=Data(base64Encoded:encoded),data.count==file["bytes"] as? Int,ScholarArchive.digest(data)==file["sha256"] as? String,data.count<=limit-total else {throw ScholarStoreError.invalidData};if name.hasSuffix(".pdf") {guard let doc=PDFDocument(data:data),!doc.isLocked,(1...200).contains(doc.pageCount) else {throw ScholarStoreError.invalidData}} else {guard data.count<=2*1024*1024,String(data:data,encoding:.utf8) != nil else {throw ScholarStoreError.invalidData}};total += data.count;parts[name]=data}
        return parts
    }
    public static func generate(_ files:[[String:Any]]) throws -> Data {
        var parts=try parts(files);parts["manifest.json"]=try JSONSerialization.data(withJSONObject:["format":"KongScholar-SelectedPacket","version":1,"files":files.map { ["name":$0["name"]!,"sha256":$0["sha256"]!,"bytes":$0["bytes"]!] }],options:[.sortedKeys]);let output=WordExport.archive(parts);guard output.count<=limit+1024*1024 else {throw ScholarStoreError.tooLarge};return output
    }
}
