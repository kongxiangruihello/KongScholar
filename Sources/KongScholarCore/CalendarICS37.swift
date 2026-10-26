import Foundation

/// Bounded, local iCalendar VEVENT exchange. No invitations, attachments, subscriptions or alarms execute.
public enum CalendarICS37 {
    public static let limit = 2 * 1024 * 1024
    public struct Failure: LocalizedError {
        let message: String
        public var errorDescription: String? { message }
        public init(_ message: String) { self.message = message }
    }
    private struct Property { let name: String; let params: [String: String]; let value: String }
    private static func split(_ line: String, separator: Character) -> [String] {
        var result=[String](), part="", quoted=false
        for c in line {if c == "\"" {quoted.toggle()};if c == separator && !quoted {result.append(part);part=""} else {part.append(c)}}
        result.append(part);return result
    }
    private static func property(_ line: String) throws -> Property {
        var quote=false, colon:String.Index?
        for i in line.indices {if line[i] == "\"" {quote.toggle()};if line[i] == ":" && !quote {colon=i;break}}
        guard let colon, !quote else {throw Failure("日历属性缺少分隔符或引号不完整")}
        let header=split(String(line[..<colon]),separator:";"), name=header[0].uppercased()
        guard !name.isEmpty,name.range(of:"^[A-Z0-9-]+$",options:.regularExpression) != nil else {throw Failure("日历属性名称无效")}
        var params=[String:String]()
        for item in header.dropFirst(){let parts=item.split(separator:"=",maxSplits:1,omittingEmptySubsequences:false);guard parts.count==2 else {throw Failure("日历参数无效")};let key=String(parts[0]).uppercased();guard params[key]==nil else {throw Failure("日历参数重复")};var value=String(parts[1]);if value.hasPrefix("\""),value.hasSuffix("\""){value=String(value.dropFirst().dropLast())};params[key]=value}
        return Property(name:name,params:params,value:String(line[line.index(after:colon)...]))
    }
    private static func text(_ raw:String) throws -> String {
        var out="", escape=false
        for c in raw {if escape {switch c {case "n","N":out+="\n";case "\\",",",";":out.append(c);default:throw Failure("日历文字含无法识别的转义")};escape=false} else if c == "\\" {escape=true} else {out.append(c)}}
        guard !escape,!out.unicodeScalars.contains(where:{$0.value<32 && $0 != "\n" && $0 != "\t"}) else {throw Failure("日历文字含无效控制字符")};return out
    }
    private static func escape(_ value:String) throws -> String {
        guard !value.unicodeScalars.contains(where:{$0.value<32 && $0 != "\n" && $0 != "\t" && $0 != "\r"}) else {throw Failure("导出文字含无效控制字符")}
        return value.replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\r",with:"\n").replacingOccurrences(of:"\\",with:"\\\\").replacingOccurrences(of:"\n",with:"\\n").replacingOccurrences(of:";",with:"\\;").replacingOccurrences(of:",",with:"\\,")
    }
    public static func fold(_ line:String) -> String {
        var lines=[String](),part="",bytes=0
        for c in line.unicodeScalars {let n=String(c).utf8.count;if bytes+n>75 {lines.append(part);part=" ";bytes=1};part += String(c);bytes += n}
        lines.append(part);return lines.joined(separator:"\r\n")
    }
    private static func formatter(_ format:String,_ zone:TimeZone) -> DateFormatter {let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.calendar=Calendar(identifier:.gregorian);f.timeZone=zone;f.dateFormat=format;f.isLenient=false;return f}
    private static let utc=TimeZone(secondsFromGMT:0)!
    private static func date(_ value:String,_ format:String,_ zone:TimeZone) throws -> Date {let f=formatter(format,zone);guard let d=f.date(from:value),f.string(from:d)==value else {throw Failure("日历日期或时间无效，或落在夏令时跳时区间")};return d}
    private static func day(_ d:Date,_ zone:TimeZone) -> String {formatter("yyyy-MM-dd",zone).string(from:d)}
    private static func resolveZone(_ name:String) throws -> TimeZone {
        if let zone=TimeZone(identifier:name){return zone}
        if let match=TimeZone.knownTimeZoneIdentifiers.first(where:{name.hasSuffix("/"+$0)}),let zone=TimeZone(identifier:match){return zone}
        throw Failure("时区无法识别："+String(name.prefix(100))+"；未猜测偏移")
    }
    private static func parseDate(_ p:Property,_ local:TimeZone) throws -> (Date,Bool,String) {
        let isDay=p.params["VALUE"] == "DATE" || p.params["VALUE"] == nil && p.value.range(of:"^\\d{8}$",options:.regularExpression) != nil
        if isDay {guard p.params["TZID"]==nil else {throw Failure("全天日期不应带TZID")};return(try date(p.value,"yyyyMMdd",utc),true,"")}
        guard p.params["VALUE"]==nil || p.params["VALUE"]=="DATE-TIME",p.value.range(of:"^\\d{8}T\\d{6}Z?$",options:.regularExpression) != nil else {throw Failure("不支持此日历时间格式")}
        guard p.value.dropLast(p.value.hasSuffix("Z") ? 1:0).hasSuffix("00") else {throw Failure("日程按分钟记录；此事件含非零秒值，未截断导入")}
        let isUTC=p.value.hasSuffix("Z");guard !isUTC || p.params["TZID"]==nil else {throw Failure("UTC时间不能同时声明TZID")}
        let name=p.params["TZID"] ?? (isUTC ? "UTC":local.identifier),zone=isUTC ? utc:try resolveZone(name)
        return(try date(String(p.value.prefix(15)),"yyyyMMdd'T'HHmmss",zone),false,name)
    }
    private static func duration(_ value:String) throws -> TimeInterval {
        let re=try NSRegularExpression(pattern:"^P(?:(\\d+)W|(?:(\\d+)D)?(?:T(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?)?)$")
        let n=value as NSString;guard let m=re.firstMatch(in:value,range:NSRange(location:0,length:n.length)),m.range.length==n.length else {throw Failure("日历时长格式不支持")}
        let units:[Double]=[604800,86400,3600,60,1];var seconds:Double=0
        for i in 1...5 {if m.range(at:i).location != NSNotFound {guard let number=Double(n.substring(with:m.range(at:i))) else{throw Failure("日历时长无效")};seconds += number*units[i-1]}}
        guard seconds>0,seconds<=366*86400,seconds.truncatingRemainder(dividingBy:60)==0 else {throw Failure("日历时长须大于0、按分钟且不超过366天")};return seconds
    }
    /// Expand a finite, explicitly supported rule into stable single-event identities.
    /// Original rule groups are rejected together if any unsupported rule/exception is present.
    private static func expandSeries38(_ master:[Property],exceptions:[[Property]],local:TimeZone) throws -> [[Property]] {
        func one(_ key:String)throws->Property? {let a=master.filter{$0.name==key};guard a.count<=1 else{throw Failure(key+"重复")};return a.first}
        guard let uidProperty=try one("UID"),let startProperty=try one("DTSTART"),let ruleProperty=try one("RRULE") else{throw Failure("重复系列须有UID、DTSTART和一条RRULE")}
        guard !master.contains(where:{["RDATE","EXRULE","RECURRENCE-ID"].contains($0.name)}) else{throw Failure("此重复组合暂不支持，请先导出单次事件")}
        let uid=try text(uidProperty.value),start=try parseDate(startProperty,local)
        guard !uid.isEmpty,uid.count<=1024 else{throw Failure("重复系列UID无效")}
        var rule=[String:String]();for part in ruleProperty.value.uppercased().split(separator:";") {let pair=part.split(separator:"=",maxSplits:1,omittingEmptySubsequences:false);guard pair.count==2,rule[String(pair[0])]==nil else{throw Failure("重复规则参数无效或重复")};rule[String(pair[0])]=String(pair[1])}
        let allowed=Set(["FREQ","INTERVAL","COUNT","UNTIL","BYDAY","BYMONTHDAY","WKST"])
        guard Set(rule.keys).isSubset(of:allowed),let freq=rule["FREQ"],["DAILY","WEEKLY","MONTHLY"].contains(freq),rule["WKST"]==nil||rule["WKST"]=="MO" else{throw Failure("仅支持有限DAILY/WEEKLY/MONTHLY及周一为周首的简单规则")}
        guard let interval=Int(rule["INTERVAL"] ?? "1"),(1...52).contains(interval),!(rule["COUNT"] != nil && rule["UNTIL"] != nil),rule["COUNT"] != nil||rule["UNTIL"] != nil else{throw Failure("重复规则须明确COUNT或UNTIL，间隔1—52；无限规则暂不展开")}
        let count:Int;if let raw=rule["COUNT"] {guard let n=Int(raw),(1...200).contains(n) else{throw Failure("每个重复系列最多200次")};count=n}else{count=200}
        let zone=start.1 ? utc:try resolveZone(start.2),format=start.1 ? "yyyyMMdd":"yyyyMMdd'T'HHmmss",rawStart=formatter(format,zone).string(from:start.0)
        var cal=Calendar(identifier:.gregorian);cal.timeZone=zone;cal.firstWeekday=2
        var weekdays:Set<Int>=[cal.component(.weekday,from:start.0)]
        if let byday=rule["BYDAY"] {guard freq=="WEEKLY" else{throw Failure("BYDAY目前仅支持每周的非序数星期列表")};let map=["SU":1,"MO":2,"TU":3,"WE":4,"TH":5,"FR":6,"SA":7],list=byday.split(separator:",").map(String.init);guard !list.isEmpty,list.count<=7,list.allSatisfy({map[$0] != nil}),Set(list).count==list.count else{throw Failure("BYDAY含不支持的星期规则")};weekdays=Set(list.compactMap{map[$0]});guard weekdays.contains(cal.component(.weekday,from:start.0)) else{throw Failure("DTSTART与每周规则不一致，未猜测展开")}}
        if let monthDay=rule["BYMONTHDAY"] {guard freq=="MONTHLY",Int(monthDay)==cal.component(.day,from:start.0) else{throw Failure("每月仅支持与首次日期相同的正数日号")}}
        let until:Date?;if let raw=rule["UNTIL"] {let isUTC=raw.hasSuffix("Z");if start.1 {guard raw.count==8 else{throw Failure("全天UNTIL须为DATE")}}else{guard raw.count>=15,(!startProperty.value.hasSuffix("Z")&&startProperty.params["TZID"]==nil)||isUTC else{throw Failure("带时区系列的UNTIL须为UTC")}}
            let p=Property(name:"UNTIL",params:start.1 ? ["VALUE":"DATE"]:isUTC ? [:]:startProperty.params,value:raw),u=try parseDate(p,local);guard u.1==start.1,u.0>=start.0 else{throw Failure("UNTIL须不早于开始且类型一致")};until=u.0
        }else{until=nil}
        let horizon=cal.date(byAdding:.year,value:5,to:start.0)!
        if let until,until>horizon {throw Failure("重复系列最多覆盖5年")}
        let endProperty=try one("DTEND"),length=try one("DURATION");guard endProperty==nil||length==nil else{throw Failure("DTEND与DURATION不能同时出现")}
        let seconds:TimeInterval
        if let endProperty {let end=try parseDate(endProperty,local);guard end.1==start.1,end.0>start.0 else{throw Failure("系列起止日期无效")};seconds=end.0.timeIntervalSince(start.0)}
        else if let length {if !start.1 && (length.value.contains("D")||length.value.contains("W")){throw Failure("带时间系列的天/周时长暂不展开，请改为结束时间")};seconds=try duration(length.value)}
        else if start.1 {seconds=86400}else{throw Failure("重复事件缺少结束时间或时长")}
        guard seconds>0,seconds<=366*86400 else{throw Failure("系列单次时长须在366天以内")}
        var excluded=Set<Date>();for p in master.filter({$0.name=="EXDATE"}) {for value in p.value.split(separator:",",omittingEmptySubsequences:false){let d=try parseDate(Property(name:"EXDATE",params:p.params,value:String(value)),local);guard d.1==start.1 else{throw Failure("例外日期类型不一致")};excluded.insert(d.0)}}
        var overrides=[Date:[Property]]();for x in exceptions {let ids=x.filter{$0.name=="RECURRENCE-ID"};guard ids.count==1,ids[0].params["RANGE"]==nil,!x.contains(where:{["RRULE","RDATE","EXRULE","EXDATE"].contains($0.name)}) else{throw Failure("不支持此例外事件规则或RANGE")};let d=try parseDate(ids[0],local);guard d.1==start.1,overrides[d.0]==nil else{throw Failure("例外日期类型不一致或重复")};overrides[d.0]=x}
        var starts=[Date]();let initialWeekday=(cal.component(.weekday,from:start.0)+5)%7,initialDay=cal.component(.day,from:start.0)
        for offset in 0...1900 {
            let candidate:Date
            if freq=="MONTHLY" {let first=cal.date(from:cal.dateComponents([.year,.month],from:start.0))!,month=cal.date(byAdding:.month,value:offset*interval,to:first)!,ym=cal.dateComponents([.year,.month],from:month);var c=cal.dateComponents([.hour,.minute,.second],from:start.0);c.year=ym.year;c.month=ym.month;c.day=initialDay;guard let d=cal.date(from:c),cal.component(.day,from:d)==initialDay else{continue};candidate=d}
            else {guard let d=cal.date(byAdding:.day,value:offset,to:start.0) else{break};candidate=d;if freq=="DAILY"&&offset%interval != 0 {continue};if freq=="WEEKLY"&&((offset+initialWeekday)/7%interval != 0 || !weekdays.contains(cal.component(.weekday,from:d))){continue}}
            if candidate>horizon {break};if let until,candidate>until{break}
            if !start.1&&formatter("HHmmss",zone).string(from:candidate) != String(rawStart.suffix(6)){continue}
            starts.append(candidate);if starts.count>=count {break}
        }
        guard !starts.isEmpty,rule["COUNT"]==nil||starts.count==count else{throw Failure("系列无法在5年与200次的支持范围内完整展开")}
        if rule["COUNT"]==nil,starts.count==200,let last=starts.last,let until,last<until {throw Failure("截至日期内可能超过200次，请拆分规则")}
        guard overrides.keys.allSatisfy({starts.contains($0)}),excluded.allSatisfy({starts.contains($0)}) else{throw Failure("例外日期不在本次支持范围内，未部分导入系列")}
        var result=[[Property]]()
        for original in starts {
            if excluded.contains(original){continue}
            let identifier=formatter(format,zone).string(from:original),stableUID="ks38-"+ScholarArchive.digest(Data(uid.utf8))+"-"+identifier+"@kongscholar.local",seriesID="ics38-"+ScholarArchive.digest(Data(uid.utf8))
            var props=(overrides[original] ?? master).filter{!["RRULE","RECURRENCE-ID","EXDATE","RDATE","EXRULE","UID","X-KONGSCHOLAR-SERIES38","X-KONGSCHOLAR-OCCURRENCE38"].contains($0.name)}
            if overrides[original]==nil {props.removeAll{["DTSTART","DTEND","DURATION"].contains($0.name)};let params=start.1 ? ["VALUE":"DATE"]:[:],formatOut=start.1 ? "yyyyMMdd":"yyyyMMdd'T'HHmmss'Z'",outputZone=start.1 ? zone:utc;props.append(Property(name:"DTSTART",params:params,value:formatter(formatOut,outputZone).string(from:original)));props.append(Property(name:"DTEND",params:params,value:formatter(formatOut,outputZone).string(from:original.addingTimeInterval(seconds))))}
            else if !props.contains(where:{$0.name=="DTSTART"}),props.contains(where:{$0.name=="STATUS"&&$0.value.uppercased()=="CANCELLED"}) {props.append(Property(name:"DTSTART",params:start.1 ? ["VALUE":"DATE"]:[:],value:formatter(start.1 ? "yyyyMMdd":"yyyyMMdd'T'HHmmss'Z'",start.1 ? zone:utc).string(from:original)));props.append(Property(name:"DTEND",params:start.1 ? ["VALUE":"DATE"]:[:],value:formatter(start.1 ? "yyyyMMdd":"yyyyMMdd'T'HHmmss'Z'",start.1 ? zone:utc).string(from:original.addingTimeInterval(seconds))))}
            props.append(Property(name:"UID",params:[:],value:stableUID));props.append(Property(name:"X-KONGSCHOLAR-SERIES38",params:[:],value:seriesID));props.append(Property(name:"X-KONGSCHOLAR-OCCURRENCE38",params:[:],value:formatter("yyyy-MM-dd",zone).string(from:original)));result.append(props)
        }
        return result
    }
    private static func expandRecurrences38(_ originals:[[Property]],local:TimeZone) -> ([[Property]],[[String:String]]) {
        let groups=Dictionary(grouping:originals,by:{$0.first(where:{$0.name=="UID"})?.value ?? ""});var output=[[Property]](),skipped=[[String:String]](),handled=Set<String>()
        for props in originals {
            let uid=props.first(where:{$0.name=="UID"})?.value ?? "",hasRule=props.contains{$0.name=="RRULE"},hasException=props.contains{$0.name=="RECURRENCE-ID"},group=groups[uid] ?? []
            if !hasRule && !hasException {output.append(props);continue}
            if handled.contains(uid){continue};handled.insert(uid)
            do {let masters=group.filter{$0.contains(where:{$0.name=="RRULE"})},exceptions=group.filter{$0.contains(where:{$0.name=="RECURRENCE-ID"})};guard masters.count==1,group.count==masters.count+exceptions.count else{throw Failure("重复系列主事件缺失、重复或含无法匹配的事件")};output += try expandSeries38(masters[0],exceptions:exceptions,local:local)}
            catch {skipped.append(["title":(try? text(props.first(where:{$0.name=="SUMMARY"})?.value ?? "重复系列")) ?? "重复系列","reason":error.localizedDescription])}
        }
        return(output,skipped)
    }
    public static func inspect(_ bytes:Data,localTimeZone:TimeZone = .current,maximumEvents:Int = 500) throws -> [String:Any] {
        guard bytes.count<=limit,let raw=String(data:bytes,encoding:.utf8),!raw.contains("\0") else {throw Failure("请选择2MB以内的UTF-8 .ics日历文件")}
        let clean=raw.replacingOccurrences(of:"\u{FEFF}",with:"").replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\r",with:"\n")
        let physical=clean.components(separatedBy:"\n");guard physical.count<=max(50000,maximumEvents*30) else {throw Failure("日历行数超过上限")}
        var lines=[String]();for line in physical {if line.hasPrefix(" ")||line.hasPrefix("\t"){guard !lines.isEmpty else{throw Failure("折行缺少前行")};lines[lines.count-1]+=line.dropFirst()}else if !line.isEmpty {lines.append(line)}}
        guard lines.first?.uppercased()=="BEGIN:VCALENDAR",lines.last?.uppercased()=="END:VCALENDAR" else {throw Failure("文件不是完整的VCALENDAR日历")}
        var stack=[String](),events=[[Property]](),current=[Property](),method="",version="",ignored=Set<String>()
        for line in lines {
            let p=try property(line)
            if p.name=="BEGIN" {let c=p.value.uppercased();if c=="VCALENDAR" && !stack.isEmpty{throw Failure("日历嵌套无效")};if c=="VEVENT" {guard stack==["VCALENDAR"] else{throw Failure("事件嵌套无效")};current=[]};if ["VTODO","VJOURNAL","VFREEBUSY","VTIMEZONE"].contains(c){ignored.insert(c=="VTIMEZONE" ? "自定义时区规则":"非VEVENT组件（"+c+"）")};stack.append(c);continue}
            if p.name=="END" {guard stack.last==p.value.uppercased() else {throw Failure("日历组件未正确结束")};if stack.last=="VEVENT" {events.append(current);guard events.count<=maximumEvents else{throw Failure("每次最多导入\(maximumEvents)个事件，请拆分文件")}};_ = stack.popLast();continue}
            if stack==["VCALENDAR"] {if p.name=="METHOD" {method=p.value.uppercased()};if p.name=="VERSION" {version=p.value}}
            if stack==["VCALENDAR","VEVENT"] {current.append(p)}else if stack.contains("VALARM"){ignored.insert("提醒")}
        }
        guard stack.isEmpty,version=="2.0" else {throw Failure("仅支持iCalendar 2.0，组件须完整结束")}
        guard ["","PUBLISH"].contains(method) else {throw Failure("此文件是会议邀请或取消消息，请从日历导出普通.ics文件；本应用不处理参会回应")}
        let expanded=expandRecurrences38(events,local:localTimeZone);guard expanded.0.count<=maximumEvents else{throw Failure("展开后事件超过本次上限，请拆分日历文件")}
        var output=[[String:Any]](),skipped=expanded.1,seen=Set<String>()
        for (index,props) in expanded.0.enumerated(){
            let title=(try? text(props.first(where:{$0.name=="SUMMARY"})?.value ?? "")) ?? "事件\(index+1)"
            do {
                func one(_ key:String,required:Bool=false)throws->Property? {let a=props.filter{$0.name==key};guard a.count<=1 else{throw Failure(key+"重复，未猜测使用哪项")};if required&&a.isEmpty{throw Failure("缺少"+key)};return a.first}
                if props.contains(where:{["RRULE","RDATE","EXDATE","RECURRENCE-ID","EXRULE"].contains($0.name)}){throw Failure("重复或例外规则暂不展开，请导出单次事件后导入")}
                let start=try parseDate(try one("DTSTART",required:true)!,localTimeZone),endProperty=try one("DTEND"),length=try one("DURATION")
                guard endProperty==nil || length==nil else{throw Failure("DTEND与DURATION不能同时出现")}
                let end:Date
                if let endProperty {let value=try parseDate(endProperty,localTimeZone);guard value.1==start.1 else{throw Failure("起止日期类型不一致")};end=value.0}
                else if let length {end=start.0.addingTimeInterval(try duration(length.value))}
                else if start.1 {end=start.0.addingTimeInterval(86400)}else{throw Failure("此事件没有结束时间；请补充结束时间或时长后导入")}
                guard end>start.0,end.timeIntervalSince(start.0)<=366*86400 else{throw Failure("事件结束须晚于开始，跨度最多366天")}
                if start.1 {guard formatter("HHmmss",utc).string(from:end)=="000000" else{throw Failure("全天事件时长须为整天")}}
                let summaryValue=try text(try one("SUMMARY")?.value ?? ""),summary=summaryValue.isEmpty ? "未命名学术日程":summaryValue,description=try text(try one("DESCRIPTION")?.value ?? ""),location=try text(try one("LOCATION")?.value ?? ""),status=try one("STATUS")?.value.uppercased() ?? "CONFIRMED"
                guard ["CONFIRMED","TENTATIVE","CANCELLED"].contains(status),summary.count<=2000,description.count<=50000,location.count<=2000 else{throw Failure("事件状态无效或文字过长")}
                var uid=try text(try one("UID")?.value ?? ""),notes=[String]()
                if uid.isEmpty {uid="generated-"+ScholarArchive.digest(Data((summary+"|"+String(start.0.timeIntervalSince1970)+"|"+String(end.timeIntervalSince1970)+"|"+location).utf8))+"@kongscholar.local";notes.append("原事件无UID，使用内容生成标识")}
                guard uid.count<=1024,!uid.contains("\n"),seen.insert(uid).inserted else{throw Failure("UID重复或无效；同标识事件未重复导入")}
                let seqText=try one("SEQUENCE")?.value ?? "0";guard let sequence=Int(seqText),sequence>=0,sequence<=Int(Int32.max) else {throw Failure("事件版本序号无效")}
                let stamp=try one("LAST-MODIFIED")?.value ?? one("DTSTAMP")?.value ?? ""
                let state=try text(try one("X-KONGSCHOLAR-STATE")?.value ?? "")
                if props.contains(where:{["ATTENDEE","ORGANIZER","ATTACH","URL"].contains($0.name)}){notes.append("参会人、附件和链接未导入或打开")}
                let zone=start.1 ? utc:localTimeZone,startDay=day(start.0,zone),endDay=day(start.1 ? end.addingTimeInterval(-86400):end,zone)
                if startDay != endDay {notes.append("跨日事件保留完整起止日期")}
                var event:[String:Any]=["uid":uid,"sequence":sequence,"stamp":stamp,"title":summary,"body":description,"location37":location,"date36":startDay,"endDate37":endDay,"startTime36":start.1 ? "":formatter("HH:mm",zone).string(from:start.0),"endTime36":start.1 ? "":formatter("HH:mm",zone).string(from:end),"timeZone37":start.1 ? "":localTimeZone.identifier,"startInstant39":ISO8601DateFormatter().string(from:start.0),"endInstant39":ISO8601DateFormatter().string(from:end),"sourceTimeZone":start.2,"dateState36":status=="CANCELLED" ? "已取消":["已完成","已发表","已出版","录用","退稿","撤回"].contains(state) ? "已完成":"待处理","dateKind36":"研究安排","notes":notes]
                if let kind=try one("X-KONGSCHOLAR-KIND"),let v=try? text(kind.value),["交稿","投稿","返修","学术报告","研究安排","其他"].contains(v){event["dateKind36"]=v}
                if let series=try one("X-KONGSCHOLAR-SERIES38"),let occurrence=try one("X-KONGSCHOLAR-OCCURRENCE38") {event["seriesID38"]=try text(series.value);event["occurrence38"]=try text(occurrence.value)}
                output.append(event)
            }catch {skipped.append(["title":String(title.prefix(200)),"reason":error.localizedDescription])}
        }
        return ["events":output,"skipped":skipped,"timeZone":localTimeZone.identifier,"warnings":ignored.sorted().map{$0+"不执行、不导入"},"bytes":bytes.count,"sha256":ScholarArchive.digest(bytes)]
    }
    public static func generate(_ events:[[String:Any]],localTimeZone:TimeZone = .current,now:Date = Date()) throws -> Data {
        guard !events.isEmpty,events.count<=5000 else{throw Failure("请选择1—5000项日程导出")}
        var lines=["BEGIN:VCALENDAR","VERSION:2.0","PRODID:-//KongScholar//Academic Calendar 3.7//ZH","CALSCALE:GREGORIAN"],uids=Set<String>()
        for e in events {
            guard let title=e["title"] as? String,!title.isEmpty,title.count<=2000,let uid=e["uid"] as? String,!uid.isEmpty,uid.count<=1024,!uid.unicodeScalars.contains(where:{$0.value<32}),uids.insert(uid).inserted,let dateText=e["date36"] as? String else{throw Failure("导出日程缺少标题、日期或唯一标识")}
            let endText=(e["endDate37"] as? String).flatMap{$0.isEmpty ? nil:$0} ?? dateText,start=e["startTime36"] as? String ?? "",end=e["endTime36"] as? String ?? "",allday=start.isEmpty&&end.isEmpty
            lines += ["BEGIN:VEVENT","UID:"+(try escape(uid)),"DTSTAMP:"+formatter("yyyyMMdd'T'HHmmss'Z'",utc).string(from:now)]
            if allday {let a=try date(dateText,"yyyy-MM-dd",utc),b=try date(endText,"yyyy-MM-dd",utc);guard b>=a,b.timeIntervalSince(a)<366*86400 else{throw Failure("全天日期范围无效或超过366天")};lines += ["DTSTART;VALUE=DATE:"+formatter("yyyyMMdd",utc).string(from:a),"DTEND;VALUE=DATE:"+formatter("yyyyMMdd",utc).string(from:b.addingTimeInterval(86400))]}
            else {
                let zoneText=e["timeZone37"] as? String ?? "",zone=zoneText.isEmpty ? localTimeZone:try resolveZone(zoneText)
                let a:Date,b:Date
                if e["startInstant39"] != nil || e["endInstant39"] != nil {
                    let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
                    func instant(_ key:String)throws->Date {guard let value=e[key] as? String,let result=f.date(from:value) ?? ISO8601DateFormatter().date(from:value) else {throw Failure("明确时刻格式无效")};return result}
                    a=try instant("startInstant39");b=try instant("endInstant39")
                    guard formatter("yyyy-MM-dd HH:mm",zone).string(from:a)==dateText+" "+start,formatter("yyyy-MM-dd HH:mm",zone).string(from:b)==endText+" "+end else {throw Failure("明确时刻与日程日期或时区不一致")}
                } else {a=try date(dateText+" "+start,"yyyy-MM-dd HH:mm",zone);b=try date(endText+" "+end,"yyyy-MM-dd HH:mm",zone)}
                guard b>a,b.timeIntervalSince(a)<=366*86400 else {throw Failure("日程起止时间无效或超过366天")}
                lines += ["DTSTART:"+formatter("yyyyMMdd'T'HHmmss'Z'",utc).string(from:a),"DTEND:"+formatter("yyyyMMdd'T'HHmmss'Z'",utc).string(from:b)]
            }
            lines += ["SUMMARY:"+(try escape(title)),"STATUS:"+((e["dateState36"] as? String)=="已取消" ? "CANCELLED":"CONFIRMED")]
            for (key,property) in [("body","DESCRIPTION"),("location37","LOCATION"),("dateState36","X-KONGSCHOLAR-STATE"),("dateKind36","X-KONGSCHOLAR-KIND")] {if let value=e[key] as? String,!value.isEmpty {guard value.count<=50000 else{throw Failure("日程说明过长")};lines.append(property+":"+(try escape(value)))}}
            if let sequence=e["sequence"] as? Int,sequence>=0,sequence<=Int(Int32.max){lines.append("SEQUENCE:\(sequence)")}
            lines.append("END:VEVENT")
        }
        lines.append("END:VCALENDAR");let bytes=Data((lines.map(fold).joined(separator:"\r\n")+"\r\n").utf8);guard bytes.count<=limit else{throw Failure("导出日历超过2MB，请缩小范围")};return bytes
    }
}
