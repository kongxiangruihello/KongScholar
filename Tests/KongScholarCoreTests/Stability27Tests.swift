import XCTest
@testable import KongScholarCore
final class Stability27Tests:XCTestCase {
    var temp:URL!
    override func setUpWithError()throws{temp=FileManager.default.temporaryDirectory.appendingPathComponent("KongScholar27Tests-"+UUID().uuidString);try FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)}
    override func tearDownWithError()throws{try? FileManager.default.removeItem(at:temp)}
    func sample(_ title:String="TEST ONLY ORIGINAL",reader:Int=26)throws->String{
        let root:[String:Any]=["profile":["field":"TEST ONLY","method":"TEST","writing":"TEST","teaching":"TEST"],"questions":[],"sources":[["id":"source","title":title,"body":"TEST ONLY 合成原文"]],"drafts":[],"lessons":[],"notes":[],"evidenceimages":[],"meta":["minimumReader":reader]];return String(data:try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys]),encoding:.utf8)!
    }
    func draft(_ value:String,at:String="2026-10-25T00:00:00Z")->[String:Any]{["key":"sources:test","type":"sources","at":at,"title":"TEST ONLY Draft","fields":[["title","TEST ONLY"],["body",value]],"id":"source","projectID":"test","baseline":"TEST baseline"]}
    func testUpgradeBackupIsExactPortableAndSeparateFromRetention()throws{
        let store=try ScholarStore(directory:temp),old=try sample();try store.write(old);store.releaseVersion="2.7.0";try store.write(sample("TEST NEW",reader:27));let folder=temp.appendingPathComponent("upgrades"),receipt=try UpgradeProtection.protect(store,version:"2.7.0"),name=try XCTUnwrap(receipt["file"] as? String)
        XCTAssertEqual(try String(contentsOf:folder.appendingPathComponent(name)),old);XCTAssertEqual(receipt["state"] as? String,"verified");XCTAssertTrue((try store.read())!.contains("TEST NEW"));let index=try JSONSerialization.jsonObject(with:Data(contentsOf:store.dataURL)) as! [String:Any];XCTAssertEqual((index["_archiveStorage"] as? [String:Any])?["version"] as? Int,4)
        for i in 0..<35{_ = try store.snapshotIfNeeded(force:true,now:Date(timeIntervalSince1970:Double(i*7200)))};XCTAssertTrue(FileManager.default.fileExists(atPath:folder.appendingPathComponent(name).path))
    }
    func testFailedUpgradeBackupNeverReplacesLiveIndex()throws{
        let store=try ScholarStore(directory:temp);try store.write(sample());let original=try Data(contentsOf:store.dataURL);try Data("BLOCKED TEST DIRECTORY".utf8).write(to:temp.appendingPathComponent("upgrades"));store.releaseVersion="2.7.0";XCTAssertThrowsError(try store.write(sample("CHANGED",reader:27)));XCTAssertEqual(try Data(contentsOf:store.dataURL),original)
    }
    func testCorruptUpgradeBackupBlocksFreshSessionWrite()throws{
        let store=try ScholarStore(directory:temp);try store.write(sample());let r=try UpgradeProtection.protect(store,version:"2.7.0"),file=try XCTUnwrap(r["file"] as? String);try Data("CORRUPT TEST".utf8).write(to:temp.appendingPathComponent("upgrades/"+file));let reopened=try ScholarStore(directory:temp);reopened.releaseVersion="2.7.0";let old=try Data(contentsOf:store.dataURL);XCTAssertThrowsError(try reopened.write(sample("CHANGED")));XCTAssertEqual(try Data(contentsOf:store.dataURL),old)
    }
    func testNewLibraryAndDifferentLibraryHaveIndependentUpgradeReceipts()throws{
        let fresh=try ScholarStore(directory:temp.appendingPathComponent("fresh"));fresh.releaseVersion="2.7.0";try fresh.write(sample(reader:27));XCTAssertEqual(try UpgradeProtection.protect(fresh,version:"2.7.0")["state"] as? String,"new-library")
        let other=try ScholarStore(directory:temp.appendingPathComponent("other"));try other.write(sample());other.releaseVersion="2.7.0";try other.write(sample("NEW"));XCTAssertEqual(try UpgradeProtection.protect(other,version:"2.7.0")["state"] as? String,"verified")
    }
    func testExplicitDamagedRecoveryPreservesRawIndexBeforeReplacement()throws{
        let store=try ScholarStore(directory:temp),raw=Data("{broken TEST ONLY".utf8);try raw.write(to:store.dataURL);store.releaseVersion="2.7.0";XCTAssertThrowsError(try store.write(sample()));let r=try UpgradeProtection.protect(store,version:"2.7.0",allowDamaged:true);XCTAssertEqual(r["state"] as? String,"raw-preserved");let file=try XCTUnwrap(r["file"] as? String);XCTAssertEqual(try Data(contentsOf:temp.appendingPathComponent("upgrades/"+file)),raw);try store.write(sample(reader:27));XCTAssertEqual(try store.read(),try sample(reader:27))
    }
    func testDraftHistoryPreservesVersionsAndSummaryIsSmall()throws{
        for i in 0..<25{try EditingDrafts.save(draft("TEST ONLY VERSION \(i)",at:"2026-10-25T00:00:\(i)Z"),root:temp)}
        let v=try EditingDrafts.read(key:"sources:test",root:temp),history=try XCTUnwrap(v["history27"] as? [[String:Any]]);XCTAssertEqual(history.count,20);XCTAssertEqual((history[0]["fields"] as? [[String]])?.last?.last,"TEST ONLY VERSION 23");XCTAssertEqual((history.last?["fields"] as? [[String]])?.last?.last,"TEST ONLY VERSION 4")
        try EditingDrafts.save(draft("TEST ONLY VERSION 24"),root:temp);XCTAssertEqual((try EditingDrafts.read(key:"sources:test",root:temp)["history27"] as? [Any])?.count,20)
        let summary=try EditingDrafts.list(root:temp,summary:true);XCTAssertNil(summary[0]["fields"]);XCTAssertNil(summary[0]["history27"]);XCTAssertEqual(summary[0]["historyCount"] as? Int,20)
    }
    func testWorkingBackupIncludesOptedInHistoryAndImportsAsCopies()throws{
        try EditingDrafts.save(draft("TEST ONLY FIRST"),root:temp);try EditingDrafts.save(draft("TEST ONLY SECOND"),root:temp);let portable=try EditingDrafts.portable(root:temp),backup=try WorkingBackup.generate(text:sample(),drafts:portable),inspection=try WorkingBackup.inspect(backup);XCTAssertEqual(inspection.count,1);XCTAssertNotNil(inspection.drafts)
        XCTAssertEqual(try EditingDrafts.importPortable(XCTUnwrap(inspection.drafts),root:temp),1);let rows=try EditingDrafts.list(root:temp);XCTAssertEqual(rows.count,2);XCTAssertEqual(Set(rows.compactMap{$0["key"] as? String}).count,2);XCTAssertTrue(rows.allSatisfy{($0["history27"] as? [Any])?.count==1})
        let omitted=try WorkingBackup.inspect(WorkingBackup.generate(text:sample(),drafts:nil));XCTAssertNil(omitted.drafts);XCTAssertEqual(omitted.count,0)
    }
    func testTamperedWorkingBackupAndInvalidDraftHistoryRejected()throws{
        let p=try WorkingBackup.generate(text:sample(),drafts:nil),zip=try BoundedZip(p);var parts=try Dictionary(uniqueKeysWithValues:zip.members.map{($0.name,try zip.read($0.name))});parts["data.json"]=Data(try sample("CHANGED").utf8);XCTAssertThrowsError(try WorkingBackup.inspect(WordExport.archive(parts)))
        parts["data.json"]=try zip.read("data.json");parts["unexpected"]=Data();XCTAssertThrowsError(try WorkingBackup.inspect(WordExport.archive(parts)))
        var invalid=draft("TEST");invalid["history27"]=[["versionID":"bad","at":"today","fields":[["body","TEST"]]]];XCTAssertThrowsError(try EditingDrafts.save(invalid,root:temp))
    }
    func testStartupDiagnosesBrokenArchiveAndMissingResourceWithoutWriting()throws{
        let store=try ScholarStore(directory:temp);var r=try JSONSerialization.jsonObject(with:Data(sample(reader:27).utf8)) as! [String:Any];r["evidenceimages"]=[["id":"image","title":"TEST ONLY","imageData":"TEST ARCHIVE"]];try store.write(String(data:try JSONSerialization.data(withJSONObject:r),encoding:.utf8)!)
        let original=try Data(contentsOf:store.dataURL),index=try JSONSerialization.jsonObject(with:original) as! [String:Any],pointer=((index["_archiveStorage"] as! [String:Any])["pointers"] as! [[String:Any]])[0],hash=pointer["sha256"] as! String;try Data("CORRUPT".utf8).write(to:temp.appendingPathComponent("archives/"+hash+".json"))
        let report=StartupHealth.inspect(store,resources:temp.appendingPathComponent("missing-resources"));XCTAssertEqual(report["ok"] as? Bool,false);let checks=report["checks"] as! [[String:Any]];XCTAssertTrue(checks.contains{$0["title"] as? String=="界面资源" && $0["state"] as? String=="未通过"});XCTAssertEqual(try Data(contentsOf:store.dataURL),original)
    }
    func testReleaseReceiptRequiresMatchingManifestAndVerifiedCommit()throws{
        var v:[String:Any]=["format":"KongScholar-SourceRelease","version":1,"release":"2.7.0","repository":"kongxiangruihello/KongScholar","branch":"main","state":"pending","manifestSHA256":String(repeating:"a",count:64),"files":100]
        XCTAssertNoThrow(try ReleaseStatus.validate(v,release:"2.7.0"));XCTAssertThrowsError(try ReleaseStatus.validate(v,release:"2.6.0"));XCTAssertThrowsError(try ReleaseStatus.validate(v,release:"2.7.0",manifest:String(repeating:"b",count:64)))
        v["state"]="verified";XCTAssertThrowsError(try ReleaseStatus.validate(v,release:"2.7.0"));v["commit"]=String(repeating:"b",count:40);v["tree"]=String(repeating:"c",count:40);v["verifiedAt"]="2026-10-25";XCTAssertNoThrow(try ReleaseStatus.validate(v,release:"2.7.0"))
    }
}
