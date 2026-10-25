import Foundation

public struct WindowDraft31:Codable {
    public var key:String
    public var chapterID:String
    public var title:String
    public var body:String
    public var basis:String
    public var at:String
    public init(key:String,chapterID:String,title:String,body:String,basis:String,at:String){self.key=key;self.chapterID=chapterID;self.title=title;self.body=body;self.basis=basis;self.at=at}
}
public enum WindowDrafts31 {
    static func directory(_ root:URL)throws->URL{let path=root.appendingPathComponent("window-drafts31",isDirectory:true);if FileManager.default.fileExists(atPath:path.path){guard try path.resourceValues(forKeys:[.isSymbolicLinkKey]).isSymbolicLink != true else{throw ScholarStoreError.invalidData}};return path}
    static func validate(_ draft:WindowDraft31)throws{guard UUID(uuidString:draft.key) != nil,!draft.chapterID.isEmpty,draft.chapterID.count<=200,draft.title.count<=500,draft.body.utf8.count<=8*1024*1024,draft.basis.utf8.count<=16*1024*1024,!draft.at.isEmpty else{throw ScholarStoreError.invalidData}}
    public static func list(root:URL)throws->[WindowDraft31]{let dir=try directory(root);guard FileManager.default.fileExists(atPath:dir.path) else{return[]};let files=try FileManager.default.contentsOfDirectory(at:dir,includingPropertiesForKeys:[.fileSizeKey]).filter{$0.pathExtension=="json"};guard files.count<=50 else{throw ScholarStoreError.tooLarge};var rows=[WindowDraft31](),total=0
        for url in files{let attrs=try url.resourceValues(forKeys:[.fileSizeKey,.isSymbolicLinkKey]);guard attrs.isSymbolicLink != true,(attrs.fileSize ?? Int.max)<=32*1024*1024 else{throw ScholarStoreError.invalidData};total += attrs.fileSize ?? 0;guard total<=96*1024*1024 else{throw ScholarStoreError.tooLarge};let row=try JSONDecoder().decode(WindowDraft31.self,from:Data(contentsOf:url));try validate(row);guard url.lastPathComponent==row.key+".json" else{throw ScholarStoreError.invalidData};rows.append(row)};return rows.sorted{$0.at>$1.at}
    }
    public static func save(_ draft:WindowDraft31,root:URL)throws{try validate(draft);let prior=try list(root:root),next=prior.filter{$0.key != draft.key}+[draft],total=try next.reduce(0){try $0+JSONEncoder().encode($1).count};guard next.count<=50,total<=96*1024*1024 else{throw ScholarStoreError.tooLarge};let dir=try directory(root);try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700]);let bytes=try JSONEncoder().encode(draft),file=dir.appendingPathComponent(draft.key+".json");try bytes.write(to:file,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path);guard try Data(contentsOf:file)==bytes else{throw ScholarStoreError.invalidData}}
    public static func remove(key:String,root:URL)throws{guard UUID(uuidString:key) != nil else{throw ScholarStoreError.invalidData};let file=try directory(root).appendingPathComponent(key+".json");if FileManager.default.fileExists(atPath:file.path){try FileManager.default.removeItem(at:file)}}
}
