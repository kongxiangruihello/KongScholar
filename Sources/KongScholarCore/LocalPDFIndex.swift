import Foundation
import PDFKit

public enum LocalPDFIndex {
    public static func build(bytes:Data) throws -> [String:Any] {
        guard bytes.count <= 256*1024*1024,let document=PDFDocument(data:bytes),!document.isLocked,document.pageCount<=2000 else {throw ScholarStoreError.invalidData}
        var pages=[[String:Any]](),total=0
        for i in 0..<document.pageCount {
            let text=document.page(at:i)?.string ?? "";total += text.utf8.count
            guard text.count<=100000,total<=12*1024*1024 else {throw ScholarStoreError.tooLarge}
            pages.append(["page":i+1,"text":text,"textKind":text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "无文字层":"PDF文字层（来源未核）"])
        }
        return ["sha256":ScholarArchive.digest(bytes),"pageCount":document.pageCount,"pages":pages]
    }
}
