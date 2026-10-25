'use strict';
// This file runs before the first data read. Keep validation free of later UI dependencies.
const bootErrors27=[];
if(typeof window.addEventListener==='function')window.addEventListener('error',e=>{if(bootErrors27.length<30)bootErrors27.push({message:String(e.message||'界面运行错误').slice(0,1000),file:String(e.filename||'').split('/').at(-1),line:Number(e.lineno)||0})});
function normalizeStability27(out){if(out.meta.minimumReader!==undefined&&![25,26,27,28,29,30,31,32,34,35,36,37,38].includes(out.meta.minimumReader))throw Error('资料需要更新版本的KongScholar读取');return out}
function backupDiff27(before,after){
 const added=[],changed=[],missing=[],counts=[];
 for(const[type,name]of Object.entries(types)){const current=new Map((before[type]||[]).map(x=>[x.id,x])),incoming=new Map((after[type]||[]).map(x=>[x.id,x]));let a=0,c=0,m=0;
  for(const row of after[type]||[]){const old=current.get(row.id);if(!old){added.push({type,id:row.id,title:row.title,after:row});a++}else if(stableValue(old)!==stableValue(row)){changed.push({type,id:row.id,title:row.title,before:old,after:row});c++}}
  for(const row of before[type]||[])if(!incoming.has(row.id)){missing.push({type,id:row.id,title:row.title,before:row});m++}
  counts.push({type,name,current:current.size,incoming:incoming.size,added:a,changed:c,missing:m});
 }
 const chapters=(after.chapters||[]).map(ch=>{const old=(before.chapters||[]).find(x=>x.id===ch.id);return{id:ch.id,title:ch.title,before:old?.writing?.body?.length||0,after:ch.writing?.body?.length||0}}).filter(x=>x.before!==x.after);
 return{added,changed,missing,counts,chapters,preferences:stableValue(before.profile)!==stableValue(after.profile)||stableValue(before.settings)!==stableValue(after.settings),metadata:stableValue(before.meta)!==stableValue(after.meta)};
}

function localTime27(value){const d=new Date(value);return Number.isNaN(d.getTime())?String(value||'时间未记录'):d.toLocaleString('zh-CN',{hour12:false})}
