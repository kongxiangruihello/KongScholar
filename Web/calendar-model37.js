'use strict';
function configureCalendar37(types,schema){schema.academicdates36.push(['endDate37','结束日期（跨日时填写，全天为最后一天）','date'],['location37','地点（可空）'],['timeZone37','时区（可空，默认当前Mac时区）']);}
function spanDays37(a,b=a){return Math.round((Date.parse(b+'T12:00:00Z')-Date.parse(a+'T12:00:00Z'))/86400000);}
function calendarFields37(r){return Object.fromEntries(['title','dateKind36','dateState36','date36','endDate37','startTime36','endTime36','timeZone37','location37','body'].map(k=>[k,k==='endDate37'?(r[k]||r.date36):k==='dateState36'?(r[k]||'待处理'):(r[k]||'')]));}
function calendarUID37(row){if(row.type==='academicdates36'){const d=find(row.type,row.id);if(d?.ical37?.uid)return d.ical37.uid;}return data.meta.calendarLibraryID37?'ks-'+data.meta.calendarLibraryID37+'-'+encodeURIComponent(row.key)+'@kongscholar.local':'';}
function normalizeCalendar37(d){
 if(d.meta.calendarLibraryID37!==undefined&&(typeof d.meta.calendarLibraryID37!=='string'||!/^[a-f0-9-]{36}$/.test(d.meta.calendarLibraryID37)))throw Error('日历资料库标识无效');
 const uids=new Set();for(const r of d.academicdates36){const end=r.endDate37||r.date36;if(!fullDayValid(end)||end<r.date36||spanDays37(r.date36,end)>365)throw Error('日程结束日期须不早于开始，跨度最多366天');for(const [k,max]of [['title',2000],['location37',2000],['body',50000],['timeZone37',100]])if(r[k]!==undefined&&(typeof r[k]!=='string'||r[k].length>max))throw Error('日程文字无效或过长');if(r.timeZone37&&!/^[A-Za-z0-9_+./:-]+$/.test(r.timeZone37))throw Error('时区格式无效，请使用Asia/Shanghai等名称');if((r.startTime36||r.endTime36)&&end===r.date36&&timeMinutes36(r.endTime36)<=timeMinutes36(r.startTime36))throw Error('同日结束时间须晚于开始');
  if(r.ical37!==undefined){const x=r.ical37;if(!x||typeof x!=='object'||Array.isArray(x)||typeof x.uid!=='string'||!x.uid||x.uid.length>1024||/[\r\n\0]/.test(x.uid)||uids.has(x.uid)||!Number.isInteger(x.sequence)||x.sequence<0||x.sequence>2147483647||typeof x.basis!=='string'||x.basis.length>300000||typeof x.incoming!=='string'||x.incoming.length>300000)throw Error('导入日历标识、版本或来源依据无效');uids.add(x.uid);}
  if(r.icalHistory37!==undefined&&(!Array.isArray(r.icalHistory37)||r.icalHistory37.length>100||r.icalHistory37.some(h=>!validStamp36(h.at)||!h.fields||typeof h.fields!=='object'||Array.isArray(h.fields))))throw Error('日历变更历史无效或达到100次');
 }return d;
}
function calendarRange37(from,to,includeCompleted=false){
 const result=[];for(const row of calendarRows36(includeCompleted)){
  const record=row.type==='academicdates36'?find(row.type,row.id):null,endDate=record?.endDate37||row.date,last=endDate>row.date&&row.end===0?dayOffset(endDate,-1):endDate;
  if(row.date>to||last<from)continue;
  let day=row.date<from?from:row.date,limit=last>to?to:last;for(let count=0;day<=limit&&count<366;count++,day=dayOffset(day,1)){
   const timed=row.start!==null&&row.end!==null,start=timed?(day===row.date?row.start:0):null,end=timed?(day===endDate?row.end:1440):null;
   if(timed&&end<=start)continue;result.push({...row,sourceKey37:row.key,key:row.key+':'+day,date:day,start,end,deadline:row.deadline&&day===last,range37:row.date===endDate?'':row.date+'—'+endDate});
  }
 }return result.sort((a,b)=>a.date.localeCompare(b.date)||(a.start??-1)-(b.start??-1)||a.title.localeCompare(b.title,'zh-CN'));
}
function importRecord37(e){return {...calendarFields37(e),projectIDs:[]};}
function planCalendarImport37(input,pid=''){
 if(!input||!Array.isArray(input.events)||input.events.length>500||!Array.isArray(input.skipped))throw Error('日历检查结果无效');if(pid&&!academicProjects35().some(p=>p.id===pid))throw Error('请选择有效个人学术项目');
 const rows=calendarRows36(true),seen=new Set(),items=[];
 for(const e of input.events){if(typeof e.uid!=='string'||!e.uid||seen.has(e.uid))throw Error('日历文件内有重复或无效标识');seen.add(e.uid);const value=importRecord37(e),signature=stableValue(calendarFields37(value)),old=data.academicdates36.find(r=>r.ical37?.uid===e.uid),linked=old?null:rows.find(r=>calendarUID37(r)===e.uid);let state='新增',mode='create',reason='';
  if(linked){state='已有项目事项';mode='skip';reason='保留原项目事项；如需改期，请从原记录调整';}
  else if(old){if(signature===old.ical37.incoming){state='重复';mode='skip';reason='源文件内容未变，本机记录保持';}else if(e.sequence<old.ical37.sequence){state='旧版本';mode='skip';reason='文件版本序号早于上次导入';}else if(stableValue(calendarFields37(old))!==old.ical37.basis){state='本机有修改';mode='skip';reason='本机内容与上次导入不同，可选择另存新日程';}else{state='可更新';mode='skip';reason='源事件有变化，可勾选更新；原值会进入变更历史';}}
  items.push({event:e,value,signature,oldID:old?.id||'',state,mode,reason});
 }
 return {items,input,pid,basis:stableValue(data)};
}
function applyCalendarImport37(plan,modes){
 if(!writerFlush())return false;if(!plan||plan.basis!==stableValue(data))throw Error('预览后资料已有变化，请重新检查日历文件');if(!Array.isArray(modes)||modes.length!==plan.items.length)throw Error('请核对导入选择');let count=0;
 const selected=plan.items.map((item,i)=>({...item,mode:modes[i]}));for(const item of selected){const allowed=item.state==='新增'?['create','skip']:item.state==='可更新'?['update','copy','skip']:item.state==='本机有修改'?['copy','skip']:['skip'];if(!allowed.includes(item.mode))throw Error('此条目不支持所选处理方式');if(item.mode!=='skip')count++;}if(!count)throw Error('尚未选择需要写入的日程');
 if(!projectMutation(()=>{for(const item of selected){if(item.mode==='skip')continue;const at=new Date().toISOString(),old=item.oldID&&find('academicdates36',item.oldID),value=scholarlyClone(item.value),copy=item.mode==='copy',uid=copy?crypto.randomUUID()+'@kongscholar.local':item.event.uid;
  const ical37={uid,sequence:item.event.sequence||0,stamp:item.event.stamp||'',basis:stableValue(calendarFields37({...value,title:copy?value.title+'（导入副本）':value.title})),incoming:item.signature,sourceName:plan.input.name||'',sourceTimeZone:item.event.sourceTimeZone||'',at};
  if(item.mode==='update'){if(!old)throw Error('原日程已缺失');const history=scholarlyClone(old.icalHistory37||[]);if(history.length>=100)throw Error('日程历史达到100次，请先备份归档');history.push({at,reason:'iCalendar更新',fields:calendarFields37(old),ical:scholarlyClone(old.ical37)});Object.assign(old,value,{projectIDs:old.projectIDs||[],ical37,icalHistory37:history,updated:at});}
  else data.academicdates36.push({...value,id:crypto.randomUUID(),title:copy?value.title+'（导入副本）':value.title,projectIDs:plan.pid?[plan.pid]:[],ical37,updated:at});
 }}))return false;return count;
}
function calendarExportEvents37(keys,includeNotes=false){
 const rows=calendarRows36(true).filter(r=>keys.includes(r.key));if(!rows.length)throw Error('此范围没有日程');return rows.map(row=>{const r=find(row.type,row.id),manual=row.type==='academicdates36',uid=calendarUID37(row);if(!uid)throw Error('日历标识尚未保存');let start=row.start,end=row.end,endDate=manual?(r.endDate37||row.date):row.date;if(end===1440){end=0;endDate=dayOffset(endDate,1);}const fmt=n=>String(Math.floor(n/60)).padStart(2,'0')+':'+String(n%60).padStart(2,'0');return {uid,title:row.title,date36:row.date,endDate37:endDate,startTime36:start===null?'':fmt(start),endTime36:end===null?'':fmt(end),timeZone37:manual?r.timeZone37||'':'',dateState36:row.state||'待处理',dateKind36:manual?r.dateKind36:row.type==='talks35'?'学术报告':row.deadline?'交稿':'研究安排',location37:manual?r.location37||'':row.type==='talks35'?r.venue35||'':'',body:includeNotes&&manual?r.body||'':'',sequence:manual?r.ical37?.sequence||0:0};});
}
