import Foundation
import XCTest
@testable import KongScholarCore

final class Studio38Tests:XCTestCase {
    let sh=TimeZone(identifier:"Asia/Shanghai")!
    func event(_ body:String)->String {"BEGIN:VEVENT\r\n"+body+"\r\nEND:VEVENT"}
    func inspect(_ body:String,zone:TimeZone?=nil)throws->[String:Any] {try CalendarICS37.inspect(Data(("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"+body+"\r\nEND:VCALENDAR\r\n").utf8),localTimeZone:zone ?? sh)}
    func rows(_ body:String,zone:TimeZone?=nil)throws->[[String:Any]] {try inspect(body,zone:zone)["events"] as! [[String:Any]]}
    func testWeeklyFiniteRuleAndExdateKeepStableOccurrenceUID()throws {
        let base="UID:TEST-series38\r\nDTSTART;TZID=Asia/Shanghai:20261026T140000\r\nDTEND;TZID=Asia/Shanghai:20261026T150000\r\nRRULE:FREQ=WEEKLY;COUNT=4\r\nSUMMARY:TEST ONLY weekly",all=try rows(event(base)),excluded=try rows(event(base+"\r\nEXDATE;TZID=Asia/Shanghai:20261102T140000"))
        XCTAssertEqual(all.count,4);XCTAssertEqual(excluded.count,3);XCTAssertEqual(all[2]["date36"] as? String,"2026-11-09");XCTAssertEqual(excluded[1]["uid"] as? String,all[2]["uid"] as? String);XCTAssertEqual(excluded[1]["seriesID38"] as? String,all[0]["seriesID38"] as? String);XCTAssertEqual(all[1]["occurrence38"] as? String,"2026-11-02")
    }
    func testMonthlySkipsMissingDaysWithoutChangingToMonthEnd()throws {
        let r=try rows(event("UID:month38\r\nDTSTART;VALUE=DATE:20260131\r\nDTEND;VALUE=DATE:20260201\r\nRRULE:FREQ=MONTHLY;COUNT=3\r\nSUMMARY:TEST ONLY monthly"));XCTAssertEqual(r.compactMap{$0["date36"] as? String},["2026-01-31","2026-03-31","2026-05-31"])
    }
    func testWeeklyMultipleDaysAndIntervalUseMondayWeekStart()throws {
        let r=try rows(event("UID:days38\r\nDTSTART;VALUE=DATE:20261028\r\nRRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=4"));XCTAssertEqual(r.compactMap{$0["date36"] as? String},["2026-10-28","2026-11-09","2026-11-11","2026-11-23"])
    }
    func testUntilIsInclusiveAndFinite()throws {
        let r=try rows(event("UID:until38\r\nDTSTART;VALUE=DATE:20261026\r\nRRULE:FREQ=DAILY;UNTIL=20261028"));XCTAssertEqual(r.count,3);XCTAssertEqual(r.last?["date36"] as? String,"2026-10-28")
    }
    func testOverrideMovesOneOccurrenceAndPreservesItsIdentity()throws {
        let main=event("UID:override38\r\nDTSTART;TZID=Asia/Shanghai:20261026T140000\r\nDTEND;TZID=Asia/Shanghai:20261026T150000\r\nRRULE:FREQ=WEEKLY;COUNT=3\r\nSUMMARY:TEST main"),original=try rows(main)
        let exception=event("UID:override38\r\nRECURRENCE-ID;TZID=Asia/Shanghai:20261102T140000\r\nDTSTART;TZID=Asia/Shanghai:20261103T160000\r\nDTEND;TZID=Asia/Shanghai:20261103T170000\r\nSEQUENCE:1\r\nSUMMARY:TEST moved only once"),r=try rows(main+"\r\n"+exception)
        XCTAssertEqual(r.count,3);XCTAssertEqual(r[1]["date36"] as? String,"2026-11-03");XCTAssertEqual(r[1]["uid"] as? String,original[1]["uid"] as? String);XCTAssertEqual(r[1]["occurrence38"] as? String,"2026-11-02");XCTAssertEqual(r[2]["date36"] as? String,"2026-11-09")
    }
    func testCancelledOverrideWithoutStartIsRetainedAsCancelledInstance()throws {
        let main=event("UID:cancel38\r\nDTSTART;VALUE=DATE:20261026\r\nRRULE:FREQ=WEEKLY;COUNT=2"),exception=event("UID:cancel38\r\nRECURRENCE-ID;VALUE=DATE:20261102\r\nSTATUS:CANCELLED\r\nSUMMARY:TEST cancelled")
        let r=try rows(main+"\r\n"+exception);XCTAssertEqual(r.count,2);XCTAssertEqual(r[1]["dateState36"] as? String,"已取消")
    }
    func testDSTPreservesWallStartAndInvalidOccurrencesDoNotConsumeCount()throws {
        let ny=TimeZone(identifier:"America/New_York")!,main=event("UID:dst38\r\nDTSTART;TZID=America/New_York:20260307T023000\r\nDTEND;TZID=America/New_York:20260307T033000\r\nRRULE:FREQ=DAILY;COUNT=3"),r=try rows(main,zone:ny)
        XCTAssertEqual(r.compactMap{$0["date36"] as? String},["2026-03-07","2026-03-09","2026-03-10"]);XCTAssertTrue(r.allSatisfy{$0["startTime36"] as? String=="02:30"})
    }
    func testUnknownAndInfiniteRulesOrInvalidExceptionSkipWholeSeries()throws {
        let rules=["FREQ=WEEKLY","FREQ=YEARLY;COUNT=3","FREQ=MONTHLY;BYDAY=1MO;COUNT=3","FREQ=WEEKLY;COUNT=201","FREQ=WEEKLY;COUNT=3;UNTIL=20261231","FREQ=WEEKLY;COUNT=2;WKST=SU","FREQ=DAILY;COUNT=3;BYHOUR=12"]
        for rule in rules {let x=try inspect(event("UID:bad38\r\nDTSTART;VALUE=DATE:20261026\r\nRRULE:"+rule));XCTAssertEqual((x["events"] as! [[String:Any]]).count,0,rule);XCTAssertEqual((x["skipped"] as! [[String:Any]]).count,1,rule)}
        let x=try inspect(event("UID:bad-ex38\r\nDTSTART;VALUE=DATE:20261026\r\nRRULE:FREQ=WEEKLY;COUNT=2\r\nEXDATE;VALUE=DATE:20270101"));XCTAssertEqual((x["events"] as! [[String:Any]]).count,0)
    }
    func testExpansionLimitCannotPartiallyImportLargeFile()throws {
        let body=(0..<3).map{event("UID:limit38-\($0)\r\nDTSTART;VALUE=DATE:20261026\r\nRRULE:FREQ=DAILY;COUNT=200")}.joined(separator:"\r\n");XCTAssertThrowsError(try inspect(body))
    }
    func testArchive14IndependentRestoreKeepsNewCollectionsAndLegacy()throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("KS38-"+UUID().uuidString);defer{try? FileManager.default.removeItem(at:folder)}
        let source="""
        {"meta":{"minimumReader":38,"desk38":{"order":["project"],"collapsed":["project"],"focus":["project"],"day":"2026-10-26"}},"profile":{"field":"TEST","method":"TEST","writing":"TEST","teaching":"TEST historical"},"questions":[],"sources":[],"drafts":[],"notes":[],"lessons":[{"id":"old","title":"TEST old teaching"}],"projects":[{"id":"project","title":"TEST project"}],"progress38":[{"id":"log","title":"TEST log","body":"TEST research progress"}],"researchlines38":[{"id":"line","title":"TEST line","sourceIds":[]}],"chapterpacks38":[{"id":"pack","title":"TEST pack","body":"TEST core question"}],"calendarseries38":[{"id":"series","title":"TEST series","instanceIDs38":["d1","d2"]}],"calendarmoves38":[{"id":"move","title":"TEST move","before38":[{"type":"academicdates36","id":"d1","fields":{"date36":"2026-10-26"}}],"after38":[{"type":"academicdates36","id":"d1","fields":{"date36":"2026-10-27"}}]}],"reviews":[{"id":"review","title":"TEST report","reviewSources38":"TEST FROZEN SOURCE38"}]}
        """
        let store=try ScholarStore(directory:folder);try store.write(source);let index=try JSONSerialization.jsonObject(with:Data(contentsOf:store.dataURL)) as! [String:Any];XCTAssertEqual((index["_archiveStorage"] as? [String:Any])?["version"] as? Int,14);XCTAssertFalse(String(decoding:try Data(contentsOf:store.dataURL),as:UTF8.self).contains("TEST FROZEN SOURCE38"));XCTAssertEqual(try Migration34.canonical(XCTUnwrap(store.read())),try Migration34.canonical(source));let result=try BackupVerification34.rehearse(Data(source.utf8),parent:folder);XCTAssertEqual(try Migration34.canonical(XCTUnwrap(result["text"] as? String)),try Migration34.canonical(source))
        for type in ["progress38","researchlines38","chapterpacks38","calendarmoves38","calendarseries38"] {var root=try JSONSerialization.jsonObject(with:Data(source.utf8)) as! [String:Any];root[type]=[["id":"dup","title":"TEST"],["id":"dup","title":"TEST"]];XCTAssertThrowsError(try ScholarStore.validate(String(data:JSONSerialization.data(withJSONObject:root),encoding:.utf8)!))}
    }
}
