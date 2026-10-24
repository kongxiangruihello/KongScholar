import XCTest
@testable import KongScholarCore

final class FolioOriginTests:XCTestCase {
    func origin(path:String="/private/tmp/测试 & 100%.kongfolio") throws -> FolioOrigin {
        let obj:[String:Any] = ["documentID":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","annotationID":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","physicalPage":2,"filePath":path,"fingerprint":String(repeating:"a",count:64)]
        return try JSONDecoder().decode(FolioOrigin.self,from:JSONSerialization.data(withJSONObject:obj))
    }
    func testLinkRoundtripEscapesPathsAndKeepsIDs() throws {
        let x=try origin();let url=try x.deepLink(fileURL:URL(fileURLWithPath:x.filePath));let q=URLComponents(url:url,resolvingAgainstBaseURL:false)!.queryItems!;XCTAssertEqual(q.first{$0.name=="file"}!.value,x.filePath);XCTAssertEqual(q.first{$0.name=="page"}!.value,"2");XCTAssertEqual(url.scheme,"kongfolio")
    }
    func testMissingFileReturnsNil() throws {XCTAssertNil(try origin(path:"/private/tmp/"+UUID().uuidString+".kongfolio").resolvedFileURL())}
    func testProjectIdentityValidation() throws {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".kongfolio");defer{try? FileManager.default.removeItem(at:url)}
        try Data("{}".utf8).write(to:url);XCTAssertThrowsError(try FolioOrigin.projectID(at:url))
        let id=UUID().uuidString;try JSONSerialization.data(withJSONObject:["scholarDocumentID":id]).write(to:url);XCTAssertEqual(try FolioOrigin.projectID(at:url),id)
    }
    func testRejectInvalidPageAndNonProjectTargets() throws {
        var x=try origin();x.physicalPage=0;XCTAssertThrowsError(try x.validate());x.physicalPage=2
        XCTAssertThrowsError(try x.deepLink(fileURL:URL(fileURLWithPath:"/private/tmp/file.pdf")))
        x.annotationID="not-an-id";XCTAssertThrowsError(try x.validate())
    }
    func testBookmarkFollowsRenamedProject() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("FolioBookmark-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:dir)}
        let original=dir.appendingPathComponent("original.kongfolio"),moved=dir.appendingPathComponent("renamed.kongfolio")
        try Data("{}".utf8).write(to:original)
        var x=try origin(path:original.path);x.bookmarkData=try original.bookmarkData(options:.minimalBookmark,includingResourceValuesForKeys:nil,relativeTo:nil).base64EncodedString()
        try FileManager.default.moveItem(at:original,to:moved)
        XCTAssertEqual(x.resolvedFileURL()?.standardizedFileURL.path,moved.standardizedFileURL.path)
    }

}
