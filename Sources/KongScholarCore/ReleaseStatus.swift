import Foundation
public enum ReleaseStatus {
    public static func validate(_ value:[String:Any],release:String,manifest:String?=nil)throws->[String:Any]{
        guard value["format"] as? String=="KongScholar-SourceRelease",value["version"] as? Int==1,value["release"] as? String==release,value["repository"] as? String=="kongxiangruihello/KongScholar",value["branch"] as? String=="main",let state=value["state"] as? String,["pending","blocked","verified"].contains(state),let hash=value["manifestSHA256"] as? String,hash.range(of:"^[a-f0-9]{64}$",options:.regularExpression) != nil,let files=value["files"] as? Int,files>0,files<10000,(value["reason"] as? String ?? "").count<=2000 else{throw ScholarStoreError.invalidData}
        if let expected=manifest,hash != expected {throw ScholarStoreError.invalidData}
        if state=="verified"{for key in ["commit","tree"]{guard let h=value[key] as? String,h.range(of:"^[a-f0-9]{40}$",options:.regularExpression) != nil else{throw ScholarStoreError.invalidData}};guard let at=value["verifiedAt"] as? String,!at.isEmpty else{throw ScholarStoreError.invalidData}}
        return value
    }
}
