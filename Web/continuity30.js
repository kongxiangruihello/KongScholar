'use strict';
const saveBefore30=save;
save=function(){
 const old=data.meta.minimumReader;
 try{syncContinuity30(data);data.meta.minimumReader=Math.max(30,data.meta.minimumReader||0);const ok=saveBefore30();if(!ok)data.meta.minimumReader=old;return ok}
 catch(e){data.meta.minimumReader=old;storageAvailable=false;toast(e.message);return false}
};
const captureBefore30=captureFormDraft26;
captureFormDraft26=function(){if(formJournal26&&formJournalDirty26&&$('dialog').open&&(data.meta.minimumReader||0)<30&&!save())return false;return captureBefore30()};
const bookmarkBefore30=bookmarkLocation;bookmarkLocation=function(r){const state=bookmarkBefore30(r);return state.offset>=0&&anchorContext30(r,find('chapters',r.chapter),'anchorText')?{offset:-1,state:'段落上下文已变化，请在正文关联与修复中核对'}:state};
const roleBefore30=roleLocation25;roleLocation25=function(r){const state=roleBefore30(r);return state.offset>=0&&anchorContext30(r,find('chapters',r.chapter),'anchorText')?{offset:-1,state:'段落上下文已变化，请在正文关联与修复中核对'}:state};

const areas30=[
 {id:'daily',title:'今日工作',pages:['home','review30','journal29','tasks','dependencies25']},
 {id:'book',title:'书稿',pages:['outline','writer','chapterDesk26','anchors30','exportProof30','freezes']},
 {id:'paper',title:'论文',pages:['projectDesk','questions','arguments','writer','revision29','exportProof30']},
 {id:'materials',title:'资料',pages:['sources','references','pdf25','folio','images24','figures29']},
 {id:'teaching',title:'教学与指导',pages:['calendar25','seminars','lessons','supervisions24','meetings29','teaching29']}
];
let area30='daily',personalWorkspace30='';
const goBefore30=go;go=function(destination){if(!areas30.find(a=>a.id===area30)?.pages.includes(destination)){const choices=areas30.filter(a=>a.pages.includes(destination)),kind=find('projects',activeProject())?.projectKind,preferred=kind==='论文'?'paper':kind==='书稿'?'book':'';if(choices.length)area30=(choices.find(a=>a.id===preferred)||choices[0]).id}return goBefore30(destination)};
studioNavigation=function(){
 const area=areas30.find(x=>x.id===area30)||areas30[0],spaces=configWorkspaces26();
 $('nav').innerHTML=areas30.map(a=>`<button data-area30="${a.id}" class="${a.id===area.id?'active':''}">${esc(a.title)}</button>`).join('')+`<details><summary>个人工作区与所有工具</summary><label class="field">已有个人工作区<select id="workspace30"><option value="">选择工作区…</option>${spaces.map(s=>`<option value="${esc(s.id)}">${esc(s.title)}</option>`).join('')}</select></label><button data-page="workspaces26">自定义工作区</button><label class="field">查找工具<input id="toolsSearch26" placeholder="输入页面名称"><select id="allTools26"><option value="">选择页面…</option>${nav.map(n=>`<option value="${esc(n[0])}">${esc(n[2])}</option>`).join('')}</select></label><button data-page="outbox30">导出记录恢复</button><button data-page="drafts26">表单草稿恢复</button><button data-page="health27">启动自检</button></details><div id="personalPages30"></div>`;
 const bar=document.createElement('section');bar.className='panel studio-tabs';bar.innerHTML=`<label class="field">当前项目<select id="studioScope"><option value="">全部项目</option>${(typeof academicProjects35==='function'?academicProjects35():data.projects).map(p=>`<option value="${esc(p.id)}" ${activeProject()===p.id?'selected':''}>${esc(p.title)}</option>`).join('')}</select></label><div class="toolbar">${area.pages.filter(id=>nav.some(n=>n[0]===id)).map(id=>`<button data-page="${esc(id)}" class="${page===id?'primary':''}">${esc(nav.find(n=>n[0]===id)[2])}</button>`).join('')}</div>`;$('#app').prepend(bar);
 $('#studioScope').onchange=e=>switchProject(e.target.value,page);
 $$('[data-area30]').forEach(b=>b.onclick=()=>{if(!writerFlush())return;area30=b.dataset.area30;go(areas30.find(a=>a.id===area30).pages[0])});
 const showPersonal=()=>{const space=spaces.find(s=>s.id===personalWorkspace30);$('#workspace30').value=personalWorkspace30;$('#personalPages30').innerHTML=space?'<p class="tiny">'+esc(space.title)+'</p>'+space.pages.filter(id=>nav.some(n=>n[0]===id)).map(id=>`<button data-page="${esc(id)}">${esc(nav.find(n=>n[0]===id)[2])}</button>`).join(''):'';bind()};
 $('#workspace30').onchange=e=>{personalWorkspace30=e.target.value;showPersonal()};showPersonal();
 $('#toolsSearch26').oninput=()=>{$('#allTools26').innerHTML='<option value="">选择页面…</option>'+nav.filter(n=>n[2].toLowerCase().includes($('#toolsSearch26').value.toLowerCase())).map(n=>`<option value="${esc(n[0])}">${esc(n[2])}</option>`).join('')};$('#allTools26').onchange=e=>{if(e.target.value)go(e.target.value)};
 $('#breadcrumb').textContent=area.title+' / '+(nav.find(n=>n[0]===page)?.[2]||'资料详情');$('.owner').innerHTML='私人学术工作台<br><small>'+esc(find('projects',activeProject())?.title||'全部学术项目')+'</small>';bind();
};

function reviewRows30(){
 const rows=new Map(),add=(key,kind,type,r,detail,extra={})=>{if(!r)return;const projects=[...new Set([...(r.projectIDs||[]),...(find('chapters',r.chapter)?.projectIDs||[])])],due=projects.map(id=>find('projects',id)?.deadline||'').filter(Boolean).sort()[0]||'';rows.set(key,{key,kind,type,id:r.id,title:r.title,detail,projectIDs:projects,due,...extra})};
 for(const ch of data.chapters)for(const issue of proofIssues([ch]))add('proof:'+ch.id+':'+(issue.note||issue.offset)+':'+issue.title,'引文与正文','chapters',ch,issue.title+'：'+issue.detail,{issue});
 for(const row of anchorRows30())if(row.state!=='可定位')add('anchor:'+row.key,'正文关联',row.type,row.record,row.state,{anchorKey:row.key,projectIDs:row.projectIDs});
 for(const f of data.feedback)if(f.feedbackStatus!=='已回应')add('feedback:'+f.id,'同行意见','feedback',f,f.decision||'待判断');
 for(const c of data.countercases29){const state=counterState29(c);if(!['已解释','已调整判断'].includes(state)&&!rows.has('anchor:countercases29:'+c.id))add('counter:'+c.id,'反证处理','countercases29',c,state)}
 for(const impact of data.sourceimpacts)for(const t of impact.targets||[])if(!t.checkedAt)add('impact:'+impact.id+':'+t.type+':'+t.id,'来源变更','sourceimpacts',impact,t.title+'：变更后尚未复核');
 for(const r of missingAssociations())add('missing:'+r.type+':'+r.id+':'+r.detail,'缺失关联',r.type,find(r.type,r.id),r.detail);
 for(const t of data.tasks)if(t.progress!=='已完成'&&t.deadline&&t.deadline<localDay())add('task:'+t.id,'逾期任务','tasks',t,'截止：'+t.deadline,{due:t.deadline});
 for(const p of data.projects)for(const component of handoffParts29){const r=data.handoffchecks29.filter(r=>r.projectIDs?.includes(p.id)&&r.component29===component).sort((a,b)=>(b.updated||b.at||'').localeCompare(a.updated||a.at||''))[0];if(r&&r.basis29!==handoffState29(component,p.id).basis)add('handoff:'+p.id+':'+component,'交稿核验','handoffchecks29',r,component+'：核验后材料变化')}
 return [...rows.values()].sort((a,b)=>(a.due||'9999').localeCompare(b.due||'9999')||a.kind.localeCompare(b.kind,'zh-CN')||a.key.localeCompare(b.key));
}
let reviewProject30='',reviewKind30='',reviewOffset30=0;
function review30View(){
 const all=reviewRows30(),filtered=all.filter(r=>(!reviewProject30||r.projectIDs.includes(reviewProject30))&&(!reviewKind30||r.kind===reviewKind30));reviewOffset30=Math.min(reviewOffset30,Math.max(0,Math.floor((filtered.length-1)/50)*50));const visible=filtered.slice(reviewOffset30,reviewOffset30+50);
 $('#app').innerHTML=headline('跨项目待核清单','按现有记录汇总；由您决定处理顺序，解决原问题后清单随之更新。这里的项目筛选独立于上方当前项目。')+`<section class="panel"><label class="field">项目<select id="reviewProject30"><option value="">全部项目</option>${(typeof academicProjects35==='function'?academicProjects35():data.projects).map(p=>`<option value="${esc(p.id)}" ${p.id===reviewProject30?'selected':''}>${esc(p.title)}</option>`).join('')}</select></label><label class="field">事项类别<select id="reviewKind30"><option value="">全部类别</option>${[...new Set(all.map(r=>r.kind))].map(k=>`<option ${k===reviewKind30?'selected':''}>${esc(k)}</option>`).join('')}</select></label><p>当前筛选${filtered.length}项；每页50项，优先显示较近的任务或项目截止日期。同一处不同性质的检查可能分别出现。</p>${visible.map((r,i)=>`<article class="proof-row"><h2>${esc(r.title)}</h2><p>${esc(r.kind+' · '+(r.projectIDs.map(id=>label('projects',id)).join('、')||'未分配项目'))}${r.due?' · '+esc(r.due):''}</p><p>${esc(r.detail)}</p><button data-review-open30="${i}">打开处理位置</button></article>`).join('')||'<p>本次筛选没有待核项。</p>'}<button id="reviewPrev30" ${reviewOffset30?'':'disabled'}>上一页</button><button id="reviewNext30" ${reviewOffset30+50<filtered.length?'':'disabled'}>下一页</button></section>`;
 for(const[id,key]of [['reviewProject30','project'],['reviewKind30','kind']])$('#'+id).onchange=e=>{if(key==='project')reviewProject30=e.target.value;else reviewKind30=e.target.value;reviewOffset30=0;render()};
 $('#reviewPrev30').onclick=()=>{reviewOffset30-=50;render()};$('#reviewNext30').onclick=()=>{reviewOffset30+=50;render()};
 $$('[data-review-open30]').forEach(b=>b.onclick=advancedGuard(()=>{const r=visible[Number(b.dataset.reviewOpen30)];if(!writerFlush())return;if(activeProject()&&!r.projectIDs.includes(activeProject())&&!switchProject(r.projectIDs[0]||'','review30'))return;if(r.anchorKey){anchorPick30=r.anchorKey;go('anchors30')}else if(r.issue)openProofIssue(r.issue);else openRecord25(r.type,r.id)}));bind();
}

let anchorPick30='',anchorQuery30='',anchorOffset30=0;
function applyRepair30(key,text,reason,expected){
 if(!reason.trim()||reason.trim().length>5000)throw Error('请填写修复理由，最多5000字');
 const row=anchorRows30().find(x=>x.key===key);if(!row||repairBasis30(row)!==expected)throw Error('预览后记录或正文已有变化，请重新核对');
 if(anchorState29(row.chapter,text)!=='可定位')throw Error('所选文字须在本章正文中唯一出现；请扩大上下文');
 return projectMutation(()=>{const r=row.record;if((r.anchorRepairs30||[]).length>=100)throw Error('此记录已达100次关联修复，请先备份并归档');const before={chapter:r.chapter,field:row.field,text:r[row.field],paragraphID:r.anchor30?.paragraphID||''};r[row.field]=text;delete r.anchor30;bindAnchor30(row.type,r,data);r.anchorRepairs30=r.anchorRepairs30||[];r.anchorRepairs30.push({at:new Date().toISOString(),reason:reason.trim(),before,after:{chapter:r.chapter,field:row.field,text,paragraphID:r.anchor30?.paragraphID||''}});r.updated=new Date().toISOString()});
}
function anchors30View(){
 const rows=anchorRows30(),row=rows.find(r=>r.key===anchorPick30)||rows.find(r=>r.state!=='可定位')||rows[0];anchorPick30=row?.key||'';const candidates=row?repairCandidates30(row,anchorQuery30):[],expected=row?repairBasis30(row):'';
 $('#app').innerHTML=headline('正文关联与修复','唯一且未改写的段落在同章移动时保留编号。改写、拆分、合并或重复文字须人工重新关联；相似候选只用于寻找位置。')+`<section class="panel"><label class="field">关联记录<select id="anchorPick30">${rows.map(r=>`<option value="${esc(r.key)}" ${r.key===anchorPick30?'selected':''}>${esc(r.state+' · '+types[r.type]+' · '+r.record.title)}</option>`).join('')}</select></label>${row?`<h2>${esc(row.record.title)}</h2><p>${esc(row.chapter?.title||'原章节已缺失')} · ${esc(row.state)}</p><h3>原关联文字</h3><pre>${esc(row.record[row.field])}</pre><p>段落编号：${esc(row.record.anchor30?.paragraphID||'尚未绑定；下次保存时为可定位文字建立')}</p><label class="field">在本章查找文字<input id="anchorQuery30" value="${esc(anchorQuery30)}"></label><button id="anchorSearch30">查找候选段落</button><p>最多列出30个候选，完整章节仍可打开。候选依文字重合排列，不能证明表达或论证相同。</p>${candidates.map((p,i)=>`<details><summary>正文位置${p.offset+1}${p.sameID?' · 原段落编号仍在':''}${!p.unique?' · 重复文字，需补上下文':''}</summary><pre>${esc(p.text)}</pre><button data-anchor-candidate30="${i}">将这段文字载入待确认位置</button></details>`).join('')}<label class="field">确认后的正文原文<textarea id="anchorNew30">${esc(row.record[row.field])}</textarea></label><label class="field">本次修复理由<textarea id="anchorReason30"></textarea></label><button id="anchorApply30">确认新位置并保留修复历史</button>${row.chapter?`<button id="anchorChapter30">打开原章节核对</button>`:''}${openButton25(row.type,row.record.id,'编辑原记录或更换所属章节')}<details><summary>修复历史（${(row.record.anchorRepairs30||[]).length}次）</summary>${(row.record.anchorRepairs30||[]).slice().reverse().map(h=>`<p>${esc(localTime27(h.at)+' · '+h.reason)}</p><div class="compare-grid"><pre>${esc(h.before.text)}</pre><pre>${esc(h.after.text)}</pre></div>`).join('')}</details>`:'<p>尚无带正文定位的记录。</p>'}</section>`;
 $('#anchorPick30').onchange=e=>{anchorPick30=e.target.value;anchorQuery30='';render()};if(row){$('#anchorSearch30').onclick=()=>{anchorQuery30=$('#anchorQuery30').value;render()};$$('[data-anchor-candidate30]').forEach(b=>b.onclick=()=>{$('#anchorNew30').value=candidates[Number(b.dataset.anchorCandidate30)].text});$('#anchorApply30').onclick=advancedGuard(()=>{if(!writerFlush())return;if(applyRepair30(row.key,$('#anchorNew30').value,$('#anchorReason30').value,expected)){render();toast('新位置与修复依据已保存')}});if(row.chapter)$('#anchorChapter30').onclick=()=>{if(activeProject()&&!row.projectIDs.includes(activeProject())&&!switchProject(row.projectIDs[0]||'','anchors30'))return;selectChapter26(row.chapter.id)}}bind();
}

let proofPreview30=null;
function proof30View(){
 const pid=activeProject(),p=proofPreview30?.pid===pid?proofPreview30:null,valid=!!p&&p.basis===stableValue(data);
 $('#app').innerHTML=headline('实际交稿文件检查','按当前项目引注和已保存的排版方案生成Word，核对文件中实际写出的部分，并打开这份文件预览。最终分页仍须结合接收方软件检查。')+`<section class="panel"><button id="proofPrepare30" ${pid?'':'disabled'}>生成本项目Word并检查实际内容</button><button data-page="layout26">修改项目排版与附加材料</button><button data-page="handoff29">查看人工材料核验</button>${!pid?'<p>请先选择一个具体项目。</p>':''}${p?`<h2>${esc(p.payload.title)}</h2><p>${valid?'本次预览对应当前资料。':'资料已有变化，请重新生成。'}</p><p>文件指纹：${esc(p.report.sha256)}</p>${p.report.items.map(x=>`<p>${x.present?'☑':'□'} ${esc(x.name+'：'+x.detail)}</p>`).join('')}<p>缺失脚注标记：${p.report.missingNotes}处。只有插入正文标记并补齐资料的图像和表格会嵌入；请对照实际内容检查结果核对。</p><p>系统Quick Look用于快速查看，可能省略页下注和分页；完整排版请保存后用文字处理软件核对。文件检查不等同于内容或分页审核。</p><button id="proofShow30" ${valid?'':'disabled'}>打开这份Word的本机预览</button><button id="proofExport30" ${valid?'':'disabled'}>保存已检查的这份Word</button>`:''}</section>`;
 $('#proofPrepare30').onclick=advancedGuard(()=>{if(!writerFlush())return;if(!projectRecords('chapters',pid).length)throw Error('本项目尚无正文章节');const styled=styledManuscript25(projectCitation26(pid),pid),payload={...styled.payload,layout:projectLayout26(pid),deliveryToken29:'KS29-'+crypto.randomUUID().replace(/-/g,'').toUpperCase()},report=advancedCall('KONGSCHOLAR_PROOF30',{payload,show:false});if(report){proofPreview30={pid,payload,report,basis:stableValue(data)};render()}});
 if(p){const check=()=>{if(!writerFlush())return false;if(p.basis!==stableValue(data))throw Error('资料已有变化，请重新生成交稿检查');return true};$('#proofShow30').onclick=advancedGuard(()=>{if(check())advancedCall('KONGSCHOLAR_PROOF30',{payload:p.payload,show:true})});$('#proofExport30').onclick=advancedGuard(()=>{if(check()&&exportWord26(p.payload)){proofPreview30=null;render()}})}bind();
}

function deliveryRecord30(e){return{id:crypto.randomUUID(),title:e.payload.title,kind:e.kind,projectID:e.pid,projectIDs:e.pid?[e.pid]:[...new Set(e.chapters.flatMap(ch=>ch.projectIDs))],at:e.at,actor:'',body:'',freezeID:e.freezeID||'',deliveryToken29:e.token,manifest:scholarlyClone(e.manifest),chapters:scholarlyClone(e.chapters),feedback:projectRecords('feedback',e.pid).map(f=>({id:f.id,title:f.title,feedbackStatus:f.feedbackStatus||'待处理',decision:f.decision||'待判断'}))}}
inferDeliveryProject=function(chapters){const rows=chapters.filter(ch=>ch.projectIDs?.length);if(!rows.length)return'';const common=rows[0].projectIDs.filter(id=>rows.every(ch=>ch.projectIDs.includes(id)));return common.includes(activeProject())?activeProject():common.length===1?common[0]:''};
const captureExportBefore30=captureExport29;
captureExport29=function(e){
 if(!e.deliveryRecord30)return captureExportBefore30(e);
 const existing=data.deliveries.find(d=>d.deliveryToken29===e.token);if(existing)e.recordedID=existing.id;
 if(!e.recordedID){if(data.deliveries.filter(r=>r.projectID===e.pid).length>=300){alert('文件已保存，交稿历史达到上限；待补记快照保留在本机导出记录恢复中。');return false}if(!projectMutation(()=>data.deliveries.unshift(scholarlyClone(e.deliveryRecord30)))){alert('文件已保存，交稿历史尚未写入；可重新启动后从“导出记录恢复”补记。');return false}e.recordedID=e.deliveryRecord30.id}
 try{advancedCall('KONGSCHOLAR_OUTBOX_ACK30',{token:e.token})}catch(err){toast('交稿记录已保存，待补记回执尚未清理；重开后可再次核对。')}
 return true;
};
let outboxRows30=[],outboxError30='';
function outbox30View(){
 try{const r=advancedCall('KONGSCHOLAR_OUTBOX_LIST30');outboxRows30=r?.rows||[];if(health27)health27.pendingExports30=outboxRows30.length;outboxError30=''}catch(e){outboxError30=e.message}
 $('#app').innerHTML=headline('导出记录恢复','导出前先保存本机回执。交稿历史失败或应用意外退出后，可核对文件指纹并补记当时快照。此回执不上传GitHub。')+`<section class="panel"><button id="outboxReload30">重新核对本机回执与文件</button>${outboxError30?`<p>${esc(outboxError30)}</p>`:''}${outboxRows30.map((r,i)=>`<article class="proof-row"><h2>${esc(r.entry.payload.title)}</h2><p>${esc(localTime27(r.entry.at)+' · '+({saved:'原文件已核对',prepared:'等待核对文件',unverified:'原文件待核对'}[r.state]||'状态待核对'))}</p><p>${esc(r.path)}</p><p>原文件指纹：${esc(r.sha256)}<br>${esc(r.detail||'')}</p><button data-outbox-recover30="${i}" ${r.state==='saved'?'':'disabled'}>补记交稿历史 / 清理已完成回执</button></article>`).join('')||'<p>没有尚待处理的导出回执。</p>'}<p>文件移动、删除或内容改变后不会自动认定成功，请保留回执并核对原文件。回执独立保存于资料目录的export-outbox；普通JSON备份不包含尚待补记的回执。</p></section>`;
 $('#outboxReload30').onclick=()=>render();$$('[data-outbox-recover30]').forEach(b=>b.onclick=advancedGuard(()=>{if(!writerFlush())return;const r=outboxRows30[Number(b.dataset.outboxRecover30)];if(r.state!=='saved')throw Error('本次回执的文件尚未通过核对');if(captureExport29(r.entry)){render();toast('已补记或确认交稿历史')}}));bind();
}
addAdvancedPage('工作台','review30','跨项目待核清单',review30View);
addAdvancedPage('写作','anchors30','正文关联与修复',anchors30View);
addAdvancedPage('写作','exportProof30','实际交稿文件检查',proof30View);
addAdvancedPage('设置与工具','outbox30','导出记录恢复',outbox30View);
const deliveriesBefore30=deliveries29View;deliveries29View=function(){deliveriesBefore30();const rows=projectRecords('deliveries').filter(d=>d.exportFile30),p=document.createElement('section');p.className='panel';p.innerHTML='<h2>已保存文件的当时回执</h2><p>保留导出时路径和内容指纹；文件之后移动或修改不会回写此历史。</p>'+rows.slice(0,20).map(d=>`<details><summary>${esc(d.title+' · '+localTime27(d.at))}</summary><p>${esc(d.exportFile30.path)}</p><p>文件指纹：${esc(d.exportFile30.sha256)} · ${d.exportFile30.bytes}字节</p>${(d.exportFile30.proof30?.items||[]).map(i=>`<p>${i.present?'☑':'□'} ${esc(i.name+'：'+i.detail)}</p>`).join('')}</details>`).join('');$('#app').append(p)};studioViews.deliveries29=deliveries29View;
const homeBefore30=studioViews.home;studioViews.home=function(){homeBefore30();const p=document.createElement('section');p.className='panel';p.innerHTML='<h2>接着处理</h2>'+(health27?.pendingExports30>0?'<p>上次有'+health27.pendingExports30+'份导出回执待核对，可打开导出记录恢复继续处理。</p>':'')+'<button data-page="review30">跨项目待核清单</button><button data-page="anchors30">正文关联与修复</button><button data-page="exportProof30">交稿文件检查</button><button data-page="outbox30">导出记录恢复</button>';$('#app').prepend(p);bind()};
const writerBefore30=writerView;writerView=function(){writerBefore30();const p=document.createElement('section');p.className='toolbar';p.innerHTML='<button data-page="anchors30">检查本次正文关联</button><button data-page="exportProof30">实际交稿文件检查</button>';$('#app').prepend(p);bind()};studioViews.writer=writerView;
render();
