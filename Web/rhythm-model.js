'use strict';
function fullDayValid(day){return typeof day==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(day)&&validDate(day)}
function normalizeRhythm(out,raw){
 for(const t of out.tasks){if(t.milestoneID!==undefined&&typeof t.milestoneID!=='string')throw Error('里程碑关联格式无效');if(t.scheduleHistory!==undefined){if(!Array.isArray(t.scheduleHistory)||t.scheduleHistory.length>10000)throw Error('安排历史格式无效');const ids=new Set();for(const h of t.scheduleHistory){if(!h||typeof h.id!=='string'||ids.has(h.id)||typeof h.at!=='string'||typeof h.reason!=='string'||typeof h.from!=='string'||typeof h.to!=='string'||(h.from&&!fullDayValid(h.from))||(h.to&&!fullDayValid(h.to)))throw Error('安排历史无效');ids.add(h.id)}}}
 for(const m of out.milestones){for(const k of ['targetDate','completedDate'])if(m[k]&&!fullDayValid(m[k]))throw Error('节点日期无效');if(m.milestoneProgress&&!['待开始','进行中','已完成'].includes(m.milestoneProgress))throw Error('节点进度无效')}
 for(const ch of out.chapters)if(ch.resume!==undefined){const r=ch.resume;if(!r||!['where','next','gap'].every(k=>typeof r[k]==='string')||!Array.isArray(r.sourceIds)||r.sourceIds.some(id=>typeof id!=='string'))throw Error('写作接续卡无效');safeTree(r)}
 const reviews=raw.usageReviews??{};if(!reviews||Array.isArray(reviews)||typeof reviews!=='object')throw Error('资料复核记录无效');safeTree(reviews);for(const r of Object.values(reviews))if(!r||typeof r.signature!=='string'||(r.at!==undefined&&typeof r.at!=='string')||(r.baselineOnly!==undefined&&typeof r.baselineOnly!=='boolean'))throw Error('资料复核标记无效');out.usageReviews=scholarlyClone(reviews);return normalizeDiscovery(out,raw);
}
function dayOffset(day,offset){const [y,m,d]=day.split('-').map(Number),date=new Date(y,m-1,d,12);date.setDate(date.getDate()+offset);return localDay(date)}
function weekDays(anchor=localDay()){const [y,m,d]=anchor.split('-').map(Number),date=new Date(y,m-1,d,12),weekday=(date.getDay()+6)%7;return Array.from({length:7},(_,i)=>dayOffset(anchor,i-weekday))}
function scheduleEntry(from,to,reason){return {id:crypto.randomUUID(),at:new Date().toISOString(),from:from||'',to:to||'',reason}}
