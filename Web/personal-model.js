'use strict';
const workspaceDefaults26=[
 {id:'book',title:'书稿写作',pages:['home','writer','chapterDesk26','health25','quotes26','terms26','styles25','layout26']},
 {id:'paper',title:'论文研究',pages:['projectDesk','questions','sources','arguments','writer','repeats26','styles25']},
 {id:'teaching',title:'教学',pages:['home','calendar25','semesters24','seminars','lessons']},
 {id:'guidance',title:'学生指导',pages:['supervisions24','guidance25','files26','drafts26']}
];
const layoutDefaults26={font:'Songti SC',size:12,lineSpacing:1.5,marginTop:2.54,marginBottom:2.54,marginLeft:2.54,marginRight:2.54,footnoteSize:10,titlePage:false,author:'',abstract:'',keywords:'',appendix:''};
const templateTypes26=['sources','references','responses','arguments','feedback','notes'];
function validateLayout26(v){
 if(!v||typeof v!=='object'||Array.isArray(v))throw Error('交稿预设无效');
 const x={...layoutDefaults26,...v};
 if(!['Songti SC','SimSun','STSong','PingFang SC','Times New Roman'].includes(x.font)||typeof x.titlePage!=='boolean')throw Error('字体或扉页设置无效');
 for(const[k,min,max]of [['size',9,18],['lineSpacing',1,3],['footnoteSize',8,14],...['marginTop','marginBottom','marginLeft','marginRight'].map(k=>[k,1.5,4])])if(typeof x[k]!=='number'||!Number.isFinite(x[k])||x[k]<min||x[k]>max)throw Error('字号、行距或页边距超出范围');
 for(const[k,limit]of [['author',500],['abstract',10000],['keywords',1000],['appendix',200000]])if(typeof x[k]!=='string'||x[k].length>limit)throw Error('交稿附加内容过长');return x;
}
function normalizePersonal26(out){
 const m=out.meta;
 if(m.workspaces26!==undefined){if(!Array.isArray(m.workspaces26)||m.workspaces26.length<1||m.workspaces26.length>20||new Set(m.workspaces26.map(x=>x.id)).size!==m.workspaces26.length)throw Error('工作区设置无效');for(const x of m.workspaces26)if(typeof x.id!=='string'||!x.id||typeof x.title!=='string'||!x.title.trim()||x.title.length>50||!Array.isArray(x.pages)||x.pages.length>150||x.pages.some(p=>typeof p!=='string')||new Set(x.pages).size!==x.pages.length)throw Error('工作区页面无效')}
 if(m.templates26!==undefined){if(!Array.isArray(m.templates26)||m.templates26.length>100||new Set(m.templates26.map(x=>x.id)).size!==m.templates26.length)throw Error('录入模板无效');for(const x of m.templates26){if(typeof x.id!=='string'||!x.id||typeof x.title!=='string'||!x.title.trim()||x.title.length>80||!templateTypes26.includes(x.type)||!x.fields||typeof x.fields!=='object'||Array.isArray(x.fields))throw Error('模板内容无效');for(const[k,v]of Object.entries(x.fields))if(!(schema[x.type].some(([key,,kind])=>key===k&&!['sources','projectLinks'].includes(kind))||x.type==='sources'&&['printedPage','folioNote'].includes(k))||['folio','writing','id'].includes(k)||typeof v!=='string'||v.length>10000)throw Error('模板字段无效')}}
 for(const key of ['projectCitations26','projectLayouts26'])if(m[key]!==undefined){if(!m[key]||typeof m[key]!=='object'||Array.isArray(m[key])||Object.keys(m[key]).length>2000)throw Error('项目预设无效');for(const v of Object.values(m[key]))key==='projectCitations26'?validateCitation25(v):validateLayout26(v)}
 if(m.termRules26!==undefined&&(!Array.isArray(m.termRules26)||m.termRules26.length>500||m.termRules26.some(r=>typeof r.canonical!=='string'||!r.canonical.trim()||r.canonical.length>100||!Array.isArray(r.variants)||r.variants.length>50||r.variants.some(v=>typeof v!=='string'||!v.trim()||v.length>100))))throw Error('术语规则无效');
 for(const key of ['quoteDecisions26','revisionDecisions26','reuseDecisions26'])if(m[key]!==undefined&&(!Array.isArray(m[key])||m[key].length>2000||m[key].some(x=>typeof x.key!=='string'||typeof x.reason!=='string'||x.reason.length>5000||typeof x.at!=='string')))throw Error('复核记录无效');
 for(const ch of out.chapters)if(ch.quotedSpans26!==undefined&&(!Array.isArray(ch.quotedSpans26)||ch.quotedSpans26.length>100||ch.quotedSpans26.some(x=>typeof x!=='string'||x.length>20000)))throw Error('引文排除范围无效');
 return out;
}
function configWorkspaces26(){return data.meta.workspaces26||workspaceDefaults26}
function projectCitation26(pid=activeProject()){return data.meta.projectCitations26?.[pid]||data.meta.citationStyle25||defaultCitation25}
function projectLayout26(pid=activeProject()){return validateLayout26(data.meta.projectLayouts26?.[pid]||layoutDefaults26)}
function textKey26(text){let h=2166136261;for(let i=0;i<text.length;i++){h^=text.charCodeAt(i);h=Math.imul(h,16777619)}return text.length+':'+(h>>>0).toString(16)}
function authorMask26(ch){
 const body=chapterWriting(ch).body,chars=body.split('');const mask=(start,end)=>{for(let i=start;i<end;i++)if(chars[i]!=='\n')chars[i]=' '};
 const re=/「[^」]*」|『[^』]*』|“[^”]*”|"[^"\n]*"|^>[^\n]*|\[\^ks-[\w-]+\]/gm;let m;while((m=re.exec(body)))mask(m.index,m.index+m[0].length);
 for(const q of ch.quotedSpans26||[]){if(!q)continue;let i=-1;while((i=body.indexOf(q,i+1))>=0)mask(i,i+q.length)}return chars.join('');
}
function termRules26(){return [...(data.meta.termRules26||[]),...data.authorities.map(a=>({canonical:a.title,variants:(a.aliases||'').split('\n').map(x=>x.trim()).filter(Boolean)}))].filter(r=>r.canonical&&r.variants.length)}
function termIssues26(chapters=projectRecords('chapters')){const rows=[];for(const ch of chapters){const masked=authorMask26(ch),body=chapterWriting(ch).body;for(const r of termRules26())for(const v of r.variants){if(v===r.canonical)continue;let i=-1;while((i=masked.indexOf(v,i+1))>=0){rows.push({chapterID:ch.id,title:ch.title,offset:i,variant:v,canonical:r.canonical,context:body.slice(Math.max(0,i-40),i+v.length+40)});if(rows.length>=1000)return{rows,truncated:true}}}}return{rows,truncated:false}}
function quoteState26(ch,n){const s=find('sources',n.sourceID);let old=null;try{const a=JSON.parse(n.signature);if(Array.isArray(a))old={body:a[9]?.text??a[0]??'',citation:a[1]||'',printedPage:a[2]||'',physicalPage:a[3]||''}}catch{}return{chapter:ch,note:n,source:s,before:old,after:s?{body:typeof layerText28==='function'?layerText28(s):s.body||'',citation:s.citation||'',printedPage:s.printedPage||'',physicalPage:physicalFor(s)||''}:null,changed:!s||n.signature!==citationSignature(s),quotePresent:!!s&&(!n.quote||(typeof layerText28==='function'?layerText28(s):s.body||'').includes(n.quote))}}
function repeatParagraphs26(){
 const rows=[],seen=new Set();let skipped=0,total=0;
 for(const ch of data.chapters){const projects=(ch.projectIDs||[]).filter(id=>!!find('projects',id));if(!projects.length)continue;for(const p of paragraphs25(ch)){const raw=p.text.replace(/\[\^ks-[\w-]+\]/g,''),norm=raw.replace(/[\s\p{P}\p{S}]/gu,'');if(norm.length<30)continue;if(norm.length>5000||rows.length>=1500||total+norm.length>1000000){skipped++;continue}total+=norm.length;const grams=new Set();for(let i=0;i<norm.length-2;i++)grams.add(norm.slice(i,i+3));rows.push({chapterID:ch.id,title:ch.title,offset:p.offset,text:p.text,norm,grams,projects})}}
 const index=new Map(),matches=[];let checks=0,truncated=skipped>0;
 outer:for(let i=0;i<rows.length;i++){const a=rows[i],candidates=new Set();for(const gram of a.grams)for(const j of index.get(gram)||[])candidates.add(j);
  for(const j of candidates){const b=rows[j];if(a.chapterID===b.chapterID||!a.projects.some(p=>b.projects.some(q=>p!==q)))continue;if(++checks>15000){truncated=true;break outer}const ratio=Math.min(a.norm.length,b.norm.length)/Math.max(a.norm.length,b.norm.length);if(ratio<.8)continue;let shared=0;for(const g of a.grams)if(b.grams.has(g))shared++;const score=a.norm===b.norm?1:2*shared/(a.grams.size+b.grams.size);if(score<.85)continue;
   const key=[a.chapterID,a.offset,textKey26(a.text),b.chapterID,b.offset,textKey26(b.text)].join('|');if(!seen.has(key)){seen.add(key);matches.push({a,b,score,key});if(matches.length>=200){truncated=true;break outer}}
  }
  for(const gram of a.grams){if(!index.has(gram))index.set(gram,[]);index.get(gram).push(i)}
 }
 return{matches,checkedParagraphs:rows.length,checks,skipped,truncated};
}
