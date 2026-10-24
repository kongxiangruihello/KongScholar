import XCTest
@testable import KongScholarCore

final class FolioTargetTests:XCTestCase {
    func testVersionsExcludeOldSameNamedApps() {
        XCTAssertFalse(FolioApplicationTarget.isModernVersion("0.5.0"));XCTAssertFalse(FolioApplicationTarget.isModernVersion("0.4.0"));XCTAssertTrue(FolioApplicationTarget.isModernVersion("0.22.0"));XCTAssertTrue(FolioApplicationTarget.isModernVersion("0.22.1"));XCTAssertFalse(FolioApplicationTarget.isModernVersion(""))
    }
    func testModernManifestIdentityWithoutReadingPDF() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:dir)}
        let id=UUID().uuidString,manifest=try JSONSerialization.data(withJSONObject:["archive":["scholarDocumentID":id],"blobs":[:]])
        var bytes=Data("KONGFOLIO-PROJECT\n".utf8);var length=UInt64(manifest.count).bigEndian;withUnsafeBytes(of:&length){bytes.append(contentsOf:$0)};bytes.append(manifest);bytes.append(Data("unused binary PDF body".utf8));let file=dir.appendingPathComponent("modern.kongfolio");try bytes.write(to:file);XCTAssertEqual(try FolioOrigin.projectID(at:file),id)
        try Data("KONGFOLIO-PROJECT\n\0\0\0\0\0\0\0\u{7f}".utf8).write(to:file);XCTAssertThrowsError(try FolioOrigin.projectID(at:file))
    }
}
