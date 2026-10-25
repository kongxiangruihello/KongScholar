'use strict';
const pageAliases36={today25:'home',projectQuick:'projects',submissions24:'paperDesk36',migration25:'migration34',sourceSync:'release27'};
for(let i=nav.length-1;i>=0;i--)if(Object.hasOwn(pageAliases36,nav[i][0]))nav.splice(i,1);
for(const n of nav){if(n[0]==='home')n[2]='个人学术工作台';if(n[0]==='outline')n[2]='著作与论文目录';if(n[0]==='release27')n[2]='源码同步与版本回执';}
const spacesBefore36=configWorkspaces26;configWorkspaces26=function(){return spacesBefore36().map(s=>({...s,pages:[...new Set(s.pages.map(p=>pageAliases36[p]||p))]}));};
areas30.find(a=>a.id==='daily').pages=['home','projects','outcomes36','calendar36','cv36','tasks','review30','journal29'];
areas30.find(a=>a.id==='paper').pages=['paperDesk36','writer','revision29','revisions32','replies32','exportProof30','outcomes36'];
areas30.find(a=>a.id==='talks').pages=['talks35','continue36','packets34','meetingactions34','outcomes36'];
iconPaths33.calendar='M4 5h16v17H4z M4 10h16 M8 2v6 M16 2v6 M8 14h2 M14 14h2 M8 18h2';
const iconBefore36=pageIcon33;pageIcon33=function(id){return id==='calendar36'?'calendar':id==='outcomes36'?'star':id==='cv36'?'paper':id==='continue36'?'link':iconBefore36(id);};
function toolGroup36(id){
 if(['home','projects','tasks','week','calendar36','outcomes36','cv36','reviews','journal29','review30','dependencies25','milestones','milestones25','inbox','searchAll'].includes(id))return'日常工作与成果';
 if(['paperDesk36','feedback','revisionPlan','revisionPackage','word25','revisions32','replies32','peerreviews24'].includes(id))return'论文与审稿';
 if(['talks35','continue36','packets34','meetingactions34'].includes(id))return'讲座与学术交流';
 if(['backups','profile','release27','migration34','verify34','outbox30','historyAcademic35','health27','storage24','recycle24','working27','workspaces26','drafts26','files26','commands24','linkSettings','history'].includes(id))return'备份与设置';
 const group=studioGroups.find(g=>g[1].includes(id))?.[0];return group==='写作'||['outline','projectDesk','health25','gaps25','anchors30','exportProof30','sets31','windows31','layout26','styles25','stagePackage','structure29'].includes(id)?'著作与写作':'研究资料';
}
function toolsOptions36(query=''){
 const q=query.trim().toLowerCase(),groups=['日常工作与成果','著作与写作','论文与审稿','讲座与学术交流','研究资料','备份与设置'];
 return '<option value="">选择工具…</option>'+groups.map(group=>{const rows=nav.filter(n=>toolGroup36(n[0])===group&&n[2].toLowerCase().includes(q));return rows.length?`<optgroup label="${esc(group)}">${rows.map(n=>`<option value="${esc(n[0])}">${esc(n[2])}</option>`).join('')}</optgroup>`:'';}).join('');
}
const navigationBefore36=studioNavigation;studioNavigation=function(){navigationBefore36();const search=$('#toolsSearch26'),list=$('#allTools26');if(list)list.innerHTML=toolsOptions36(search?.value||'');if(search)search.oninput=()=>{list.innerHTML=toolsOptions36(search.value);};};
const goBefore36=go;go=function(destination){return goBefore36(pageAliases36[destination]||destination);};
const actionsBefore36=actions;actions=function(record,type){const html=actionsBefore36(record,type);return type==='sources'?html.replace(/<button data-sheet="[^"]*">[^<]*<\/button>/g,''):html;};
const reviewBefore36=reviewRows30;reviewRows30=function(){return reviewBefore36().filter(r=>!historicalRecord35(r.type,find(r.type,r.id)));};
commandRows24=function(query){
 const commands=nav.map(([id,,title])=>({title:'打开：'+title,run:()=>go(id)}));
 for(const type of ['projects','tasks','questions','sources','references','arguments','notes','feedback','readings','talks35','outcomes36','academicdates36','submissions','peerreviews'])commands.push({title:'新建：'+(type==='submissions'?'论文投稿记录':types[type]),run:()=>openForm(type)});
 commands.push({title:'从成果生成学术履历',run:()=>go('cv36')});
 for(const type of ['chapters','sources','references','projects'])for(const r of type==='projects'?academicProjects35():projectRecords(type))commands.push({title:types[type]+'：'+r.title,run:()=>{if(type==='projects')quickSwitchProject(r.id);else if(type==='chapters')openProgressChapter(r.id);else openMaterial(type,r.id);}});
 return commands.filter(r=>r.title.toLowerCase().includes(query.trim().toLowerCase()));
};
const talksBefore36=studioViews.talks35;studioViews.talks35=function(){talksBefore36();const box=document.createElement('section');box.className='panel';box.innerHTML='<h2>从报告继续研究</h2><p>讲稿与讨论可以接续为独立论文；原讲座、原稿和来源关系会保留。</p><button data-page="continue36">讲座转论文</button><button data-page="outcomes36">核对已完成的报告成果</button><button data-page="calendar36">查看报告日期与时间冲突</button>';$('#app').prepend(box);bind();};
render();
