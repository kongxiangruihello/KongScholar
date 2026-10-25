import Foundation
import XCTest
@testable import KongScholarCore

final class Calendar37Tests:XCTestCase {
    let sh=TimeZone(identifier:"Asia/Shanghai")!
    func file(_ body:String)->Data {Data(("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"+body+"\r\nEND:VCALENDAR\r\n").utf8)}
    func event(_ body:String)->String {"BEGIN:VEVENT\r\n"+body+"\r\nEND:VEVENT"}
    func inspect(_ data:Data)throws->[String:Any] {try CalendarICS37.inspect(data,localTimeZone:sh)}
    func rows(_ data:Data)throws->[[String:Any]] {try inspect(data)["events"] as! [[String:Any]]}
    func base()->[String:Any] {["uid":"TEST37@local","title":"何以为士：林乐知，晚清；研究\\引文\n第二行","date36":"2026-10-25","endDate37":"2026-10-26","dateState36":"待处理","dateKind36":"研究安排","body":"TEST ONLY 说明","location37":"TEST ONLY 上海"]}
    func testChineseTextFoldAndExactRoundTrip()throws {
        var e=base();e["title"]=String(repeating:"中文🙂e\u{301}",count:80);e["body"]="原文，分号；斜杠\\\n换行";let bytes=try CalendarICS37.generate([e],localTimeZone:sh)
        let text=String(decoding:bytes,as:UTF8.self);XCTAssertTrue(text.contains("\r\n "));for l in text.components(separatedBy:"\r\n"){XCTAssertLessThanOrEqual(l.utf8.count,75)}
        let r=try XCTUnwrap(rows(bytes).first);XCTAssertEqual(r["title"] as? String,e["title"] as? String);XCTAssertEqual(r["body"] as? String,e["body"] as? String)
        // A single long combining grapheme must also fold by UTF-8 scalars, not Characters.
        XCTAssertTrue(CalendarICS37.fold("SUMMARY:a"+String(repeating:"\u{301}",count:100)).components(separatedBy:"\r\n").allSatisfy{$0.utf8.count<=75})
    }
    func testAllDayExclusiveEndAndDefaultEnd()throws {
        let bytes=try CalendarICS37.generate([base()],localTimeZone:sh),text=String(decoding:bytes,as:UTF8.self)
        XCTAssertTrue(text.contains("DTEND;VALUE=DATE:20261027"));XCTAssertEqual(try rows(bytes)[0]["endDate37"] as? String,"2026-10-26")
        let day=try rows(file(event("UID:one\r\nDTSTART;VALUE=DATE:20261025")))[0];XCTAssertEqual(day["endDate37"] as? String,"2026-10-25")
    }
    func testUTCConversionCrossMidnightAndLocalZoneExport()throws {
        let input=file(event("UID:utc\r\nDTSTART:20261025T153000Z\r\nDTEND:20261025T170000Z\r\nSUMMARY:TEST UTC")),r=try rows(input)[0]
        XCTAssertEqual(r["date36"] as? String,"2026-10-25");XCTAssertEqual(r["startTime36"] as? String,"23:30");XCTAssertEqual(r["endDate37"] as? String,"2026-10-26");XCTAssertEqual(r["endTime36"] as? String,"01:00");XCTAssertEqual(r["timeZone37"] as? String,"Asia/Shanghai")
        let output=try CalendarICS37.generate([r],localTimeZone:TimeZone(identifier:"America/New_York")!),text=String(decoding:output,as:UTF8.self);XCTAssertTrue(text.contains("DTSTART:20261025T153000Z"));XCTAssertTrue(text.contains("DTEND:20261025T170000Z"))
    }
    func testTZIDQuotedAndFloatingTimeAndDuration()throws {
        let a=try rows(file(event("UID:tz\r\nDTSTART;TZID=\"Asia/Shanghai\":20261025T140000\r\nDURATION:PT90M")))[0];XCTAssertEqual(a["endTime36"] as? String,"15:30")
        let b=try rows(file(event("UID:float\r\nDTSTART:20261025T140000\r\nDTEND:20261025T150000")))[0];XCTAssertEqual(b["startTime36"] as? String,"14:00");XCTAssertEqual(b["sourceTimeZone"] as? String,"Asia/Shanghai")
        let c=try rows(file(event("UID:days\r\nDTSTART;VALUE=DATE:20261025\r\nDURATION:P2D")))[0];XCTAssertEqual(c["endDate37"] as? String,"2026-10-26")
    }
    func testRecurringExceptionsDuplicateUIDAndUnsupportedComponentsAreExplicit()throws {
        let regular=event("UID:one\r\nDTSTART;VALUE=DATE:20261025"),recurring=event("UID:rec\r\nDTSTART;VALUE=DATE:20261025\r\nRRULE:FREQ=DAILY"),exception=event("UID:exc\r\nDTSTART;VALUE=DATE:20261025\r\nRECURRENCE-ID;VALUE=DATE:20261024")
        let result=try inspect(file([regular,regular,recurring,exception,"BEGIN:VTODO\r\nSUMMARY:TEST Todo\r\nEND:VTODO"].joined(separator:"\r\n")))
        XCTAssertEqual((result["events"] as? [[String:Any]])?.count,1);XCTAssertEqual((result["skipped"] as? [[String:Any]])?.count,3);XCTAssertTrue((result["warnings"] as? [String])?.joined().contains("VTODO")==true)
    }
    func testAlarmsLinksAndInvitationsNeverExecute()throws {
        let body="UID:alarm\r\nDTSTART;VALUE=DATE:20261025\r\nURL:https://example.invalid\r\nATTACH:https://example.invalid/private\r\nATTENDEE:mailto:test@example.invalid\r\nBEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT10M\r\nEND:VALARM"
        let r=try inspect(file(event(body)));XCTAssertFalse((r["warnings"] as! [String]).isEmpty);XCTAssertEqual((r["events"] as! [[String:Any]])[0]["notes"] as? [String],["参会人、附件和链接未导入或打开"])
        for method in ["REQUEST","REPLY","CANCEL"] {XCTAssertThrowsError(try inspect(file("METHOD:"+method+"\r\n"+event(body))))}
    }
    func testInvalidDatesUnknownZonesMissingEndNonzeroSecondsAndBadTextSkip()throws {
        let bad=["DTSTART;VALUE=DATE:20260230","DTSTART;TZID=UNKNOWN/ZONE:20261025T140000\r\nDTEND:20261025T150000","DTSTART:20261025T140000Z","DTSTART:20261025T140001Z\r\nDTEND:20261025T150000Z","DTSTART;VALUE=DATE:20261025\r\nSUMMARY:Bad\\z","DTSTART;VALUE=DATE:20261025\r\nDURATION:PT30M","DTSTART;VALUE=DATE:20261025\r\nDTEND;VALUE=DATE:20261026\r\nDURATION:P1D"]
        for (i,value) in bad.enumerated(){let r=try inspect(file(event("UID:bad-\(i)\r\n"+value)));XCTAssertEqual((r["events"] as! [[String:Any]]).count,0,value);XCTAssertEqual((r["skipped"] as! [[String:Any]]).count,1,value)}
    }
    func testDSTGapIsRejectedInsteadOfGuessed()throws {
        let r=try inspect(file(event("UID:gap\r\nDTSTART;TZID=America/New_York:20260308T023000\r\nDTEND;TZID=America/New_York:20260308T040000")));XCTAssertEqual((r["skipped"] as! [[String:Any]]).count,1)
    }
    func testMalformedAndBoundedImport()throws {
        XCTAssertThrowsError(try inspect(Data([0xff,0xfe])));XCTAssertThrowsError(try inspect(Data(repeating:65,count:CalendarICS37.limit+1)));XCTAssertThrowsError(try inspect(file("BEGIN:VEVENT\r\nEND:VTODO")))
        let many=(0...500).map{event("UID:limit-\($0)\r\nDTSTART;VALUE=DATE:20261025")}.joined(separator:"\r\n");XCTAssertThrowsError(try inspect(file(many)))
        XCTAssertEqual((try CalendarICS37.inspect(file(many),localTimeZone:sh,maximumEvents:5000)["events"] as! [[String:Any]]).count,501)
    }
    func testExportInvalidRangeZoneDuplicateOrControlUIDRejected()throws {
        for change in [["endDate37":"2026-10-24"],["startTime36":"14:00","endTime36":"15:00","timeZone37":"UNKNOWN/ZONE"],["uid":"bad\r\nSTATUS:CANCELLED"]] {var e=base();for(k,v)in change{e[k]=v};XCTAssertThrowsError(try CalendarICS37.generate([e],localTimeZone:sh))}
        XCTAssertThrowsError(try CalendarICS37.generate([base(),base()]));XCTAssertThrowsError(try CalendarICS37.generate([]))
    }
    func testCancelledCompletedStateAndStableMissingUID()throws {
        var e=base();e["dateState36"]="已取消";XCTAssertEqual(try rows(CalendarICS37.generate([e],localTimeZone:sh))[0]["dateState36"] as? String,"已取消")
        e["dateState36"]="已完成";XCTAssertEqual(try rows(CalendarICS37.generate([e],localTimeZone:sh))[0]["dateState36"] as? String,"已完成")
        let bytes=file(event("DTSTART;VALUE=DATE:20261025\r\nSUMMARY:TEST No UID"));XCTAssertEqual(try rows(bytes)[0]["uid"] as? String,try rows(bytes)[0]["uid"] as? String)
    }
    func testArchive13AndIndependentBackupRestorePreserveCalendarHistoryAndOldRecords()throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("KS37Test-"+UUID().uuidString);defer{try? FileManager.default.removeItem(at:folder)}
        let source="""
        {"meta":{"minimumReader":37,"calendarLibraryID37":"00000000-0000-4000-8000-000000000037"},"profile":{"field":"TEST","method":"TEST","writing":"TEST","teaching":"TEST historical"},"questions":[],"drafts":[],"sources":[],"notes":[],"lessons":[{"id":"old","title":"TEST ONLY old teaching"}],"academicdates36":[{"id":"date","title":"TEST ONLY new date","date36":"2026-10-25","ical37":{"uid":"TEST-37","sequence":1,"basis":"TEST basis","incoming":"TEST incoming"},"icalHistory37":[{"at":"2026-10-25T00:00:00Z","fields":{"title":"TEST ONLY ORIGINAL37"}}]}]}
        """
        let store=try ScholarStore(directory:folder);try store.write(source);let index=try JSONSerialization.jsonObject(with:Data(contentsOf:store.dataURL)) as! [String:Any];XCTAssertEqual((index["_archiveStorage"] as? [String:Any])?["version"] as? Int,13);XCTAssertFalse(String(decoding:try Data(contentsOf:store.dataURL),as:UTF8.self).contains("TEST ONLY ORIGINAL37"));XCTAssertEqual(try Migration34.canonical(XCTUnwrap(store.read())),try Migration34.canonical(source))
        let restored=try BackupVerification34.rehearse(Data(source.utf8),parent:folder),text=try XCTUnwrap(restored["text"] as? String);XCTAssertEqual(try Migration34.canonical(text),try Migration34.canonical(source))
    }
}
