import AppKit
import KongScholarCore

extension AppDelegate{
    func reviewPrompt32(_ action:String,text:String?,completion:@escaping(String?)->Void)->Bool{
        guard action=="KONGSCHOLAR_OCR_WORDS32" else{return false}
        do{let bytes=Data((text ?? "{}").utf8);guard bytes.count<=12*1024*1024,let p=try JSONSerialization.jsonObject(with:bytes) as? [String:Any],let image=p["imageData"] as? String,let words=p["words"] as? [String],!words.isEmpty else{throw ScholarStoreError.invalidData};_ = try EvidenceImage.validateWords32(words);researchWork("按所选识读词表生成候选",completion:completion){try EvidenceImage.recognize(image,customWords:words)}}catch{completion("error:"+error.localizedDescription)};return true
    }
}
