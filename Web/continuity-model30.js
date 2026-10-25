'use strict';
// Loaded before the first read. IDs track exact paragraphs, never scholarly meaning.
function paragraphText30(body) {
 const rows=[],re=/[^\n]+(?:\n(?!\s*\n)[^\n]+)*/g;let m;
 while((m=re.exec(body)))if(m[0].trim())rows.push({text:m[0],offset:m.index});
 return rows;
}
function anchorField30(type,r){return typeof r.anchorText==='string'?'anchorText':type==='feedback'&&typeof r.wordAnchor==='string'?'wordAnchor':''}
function normalizeContinuity30(out){
 for(const ch of out.chapters)if(ch.paragraphs30!==undefined){
  if(!Array.isArray(ch.paragraphs30)||ch.paragraphs30.length>20000)throw Error('段落标识超过上限');
  const ids=new Set();for(const p of ch.paragraphs30){if(!p||typeof p.id!=='string'||!p.id||ids.has(p.id)||typeof p.text!=='string'||!Number.isInteger(p.offset)||p.offset<0)throw Error('段落标识无效');ids.add(p.id)}
 }
 for(const type of Object.keys(types))for(const r of out[type]){
  if(r.anchor30!==undefined){const a=r.anchor30;if(!a||typeof a.chapterID!=='string'||typeof a.paragraphID!=='string'||typeof a.text!=='string'||!['anchorText','wordAnchor'].includes(a.field))throw Error('段落关联无效')}
  if(r.anchorRepairs30!==undefined&&(!Array.isArray(r.anchorRepairs30)||r.anchorRepairs30.length>100||r.anchorRepairs30.some(h=>!h||typeof h.at!=='string'||typeof h.reason!=='string'||!h.reason.trim()||h.reason.length>5000||!h.before||!h.after)))throw Error('关联修复记录无效');
  if(type==='deliveries'&&r.exportFile30!==undefined){const f=r.exportFile30;if(!f||typeof f.path!=='string'||f.path.length>8192||!/^[a-f0-9]{64}$/.test(f.sha256||'')||!Number.isInteger(f.bytes)||f.bytes<0||f.bytes>256*1024*1024||!Array.isArray(f.proof30?.items)||f.proof30.items.length>50||f.proof30.items.some(i=>!i||typeof i.name!=='string'||typeof i.detail!=='string'||typeof i.present!=='boolean'))throw Error('交稿文件回执无效')}
 }
 return out;
}
function syncParagraphs30(ch){
 const next=paragraphText30(ch.writing?.body||''),old=ch.paragraphs30||[];
 if(next.length>20000)throw Error('单章超过20000段，请分小节保存');
 if(next.length===old.length&&next.every((p,i)=>p.text===old[i].text)){ch.paragraphs30=next.map((p,i)=>({...p,id:old[i].id}));return}
 const oldBy=new Map(),newCount=new Map();for(const p of old){const a=oldBy.get(p.text)||[];a.push(p);oldBy.set(p.text,a)}for(const p of next)newCount.set(p.text,(newCount.get(p.text)||0)+1);
 // Only unique, byte-for-byte unchanged paragraphs inherit their identity after an edit.
 // Rewrites/splits/merges/duplicates get new IDs and require explicit relinking.
 ch.paragraphs30=next.map(p=>({...p,id:oldBy.get(p.text)?.length===1&&newCount.get(p.text)===1?oldBy.get(p.text)[0].id:crypto.randomUUID()}));
}
function bindAnchor30(type,r,d){
 const field=anchorField30(type,r);if(!field||!r.chapter||!r[field]?.trim())return;
 const prior=r.anchor30;if(prior&&prior.chapterID===r.chapter&&prior.field===field&&prior.text===r[field])return;
 const ch=d.chapters.find(c=>c.id===r.chapter),text=r[field],body=ch?.writing?.body||'',at=body.indexOf(text);
 if(at<0||body.indexOf(text,at+1)>=0){delete r.anchor30;return}
 const matches=(ch.paragraphs30||[]).filter(p=>at>=p.offset&&at+text.length<=p.offset+p.text.length);
 r.anchor30={chapterID:r.chapter,paragraphID:matches.length===1?matches[0].id:'',field,text};
}
function syncContinuity30(d){for(const ch of d.chapters)syncParagraphs30(ch);for(const type of Object.keys(types))for(const r of d[type])bindAnchor30(type,r,d);return normalizeContinuity30(d)}
function anchorContext30(r,ch,field){const a=r.anchor30;return !!a?.paragraphID&&a.chapterID===ch?.id&&a.text===r[field]&&!(ch.paragraphs30||[]).some(p=>p.id===a.paragraphID&&p.text.includes(r[field]))}
function anchorRows30(d=data){const rows=[];for(const type of Object.keys(types))for(const r of d[type]){const field=anchorField30(type,r);if(field&&r.chapter&&r[field]?.trim()){const ch=d.chapters.find(c=>c.id===r.chapter);let state=anchorState29(ch,r[field]);if(state==='可定位'&&anchorContext30(r,ch,field))state='段落上下文已变化，需复核';rows.push({type,record:r,field,chapter:ch,state,key:type+':'+r.id,projectIDs:[...new Set([...(r.projectIDs||[]),...(ch?.projectIDs||[])])]})}}return rows}
function repairBasis30(row){return stableValue({type:row.type,record:row.record,chapter:row.chapter?{id:row.chapter.id,body:row.chapter.writing?.body||'',paragraphs:row.chapter.paragraphs30||[]}:null})}
function repairCandidates30(row,query=''){
 if(!row.chapter)return[];const old=row.record[row.field],words=query.trim(),raw=paragraphText30(row.chapter.writing?.body||''),prior=row.record.anchor30;
 const grams=s=>{const text=s.replace(/\s/g,'').slice(0,4000),set=new Set();for(let i=0;i<text.length-1;i++)set.add(text.slice(i,i+2));return set},a=grams(old);
 return raw.filter(p=>!words||p.text.includes(words)).map(p=>{const b=grams(p.text);let shared=0;for(const x of a)if(b.has(x))shared++;const id=(row.chapter.paragraphs30||[]).find(x=>x.offset===p.offset&&x.text===p.text)?.id||'';return{...p,id,score:2*shared/Math.max(1,a.size+b.size),sameID:!!prior?.paragraphID&&id===prior.paragraphID,unique:(row.chapter.writing.body.indexOf(p.text)===p.offset&&row.chapter.writing.body.indexOf(p.text,p.offset+1)<0)}}).sort((a,b)=>Number(b.sameID)-Number(a.sameID)||b.score-a.score||a.offset-b.offset).slice(0,30);
}
