'use strict';
const priorSave26=save;
save=function(){const old=data.meta.minimumReader;try{normalizePersonal26(data);data.meta.minimumReader=Math.max(26,data.meta.minimumReader||0);const ok=priorSave26();if(!ok)data.meta.minimumReader=old;return ok}catch(e){data.meta.minimumReader=old;storageAvailable=false;toast(e.message);return false}};
let workspaceEdit26='';
studioNavigation=function(){
 const spaces=configWorkspaces26(),current=spaces.find(x=>x.id===data.meta.activeWorkspace26)||spaces[0],pages=current.pages.filter(id=>nav.some(n=>n[0]===id));
 $('nav').innerHTML=`<label class="field">个人工作区<select id="workspacePick26">${spaces.map(s=>`<option value="${esc(s.id)}" ${s.id===current.id?'selected':''}>${esc(s.title)}</option>`).join('')}</select></label>${pages.map(id=>`<button data-page="${esc(id)}" class="${page===id?'active':''}">${esc(nav.find(n=>n[0]===id)[2])}</button>`).join('')}<button data-page="workspaces26">自定义工作区</button><label class="field">所有工具<input id="toolsSearch26" placeholder="搜索页面名称" aria-label="搜索工具"><select id="allTools26" aria-label="打开所有工具"><option value="">选择页面…</option>${nav.map(([id,,name])=>`<option value="${esc(id)}">${esc(name)}</option>`).join('')}</select></label>`;
 const bar=document.createElement('section');bar.className='panel studio-tabs';bar.innerHTML=`<label class="field">当前项目<select id="studioScope"><option value="">全部项目</option>${data.projects.map(p=>`<option value="${esc(p.id)}" ${activeProject()===p.id?'selected':''}>${esc(p.title)}</option>`).join('')}</select></label><p class="tiny">${esc(current.title)} · ${esc(nav.find(n=>n[0]===page)?.[2]||'资料详情')} <button data-page="drafts26">表单草稿恢复</button></p>`;$('#app').prepend(bar);
 $('#studioScope').onchange=e=>switchProject(e.target.value,page);
 $('#workspacePick26').onchange=advancedGuard(e=>{if(!writerFlush())return;const id=e.target.value;if(projectMutation(()=>data.meta.activeWorkspace26=id))render()});
 const fill=()=>{const q=$('#toolsSearch26').value.toLowerCase();$('#allTools26').innerHTML='<option value="">选择页面…</option>'+nav.filter(n=>n[2].toLowerCase().includes(q)).map(([id,,name])=>`<option value="${esc(id)}">${esc(name)}</option>`).join('')};$('#toolsSearch26').oninput=fill;$('#allTools26').onchange=e=>{if(e.target.value)go(e.target.value)};
 $('#breadcrumb').textContent=current.title+' / '+(nav.find(n=>n[0]===page)?.[2]||'资料详情');$('.owner').innerHTML='私人学术工作台<br><small>'+esc(find('projects',activeProject())?.title||'全部学术项目')+'</small>';bind();
};
function workspaces26View(){
 const spaces=configWorkspaces26(),current=spaces.find(s=>s.id===workspaceEdit26)||spaces[0];workspaceEdit26=current.id;
 $('#app').innerHTML=headline('自定义个人工作区','保存常用页面与先后顺序；全部页面始终可以从左侧“所有工具”打开。')+`<section class="panel"><label class="field">编辑工作区<select id="wsEdit26">${spaces.map(s=>`<option value="${esc(s.id)}" ${s.id===current.id?'selected':''}>${esc(s.title)}</option>`).join('')}</select></label><label class="field">名称<input id="wsName26" maxlength="50" value="${esc(current.title)}"></label><button id="wsRename26">保存名称</button><button id="wsAdd26">新增工作区</button><button id="wsDelete26" ${spaces.length<2?'disabled':''}>删除此工作区</button><h2>已选页面 · 从上至下排列</h2>${current.pages.map((id,i)=>`<p>${esc(nav.find(n=>n[0]===id)?.[2]||id)} <button data-ws-up26="${i}" ${i?'':'disabled'}>上移</button><button data-ws-down26="${i}" ${i===current.pages.length-1?'disabled':''}>下移</button><button data-ws-remove26="${i}">移出工作区</button></p>`).join('')}<label class="field">添加页面<select id="wsPage26">${nav.filter(n=>!current.pages.includes(n[0])).map(n=>`<option value="${esc(n[0])}">${esc(n[2])}</option>`).join('')}</select></label><button id="wsPageAdd26">添加到末尾</button><button id="wsActivate26">使用此工作区</button></section>`;
 const mutate=fn=>{if(projectMutation(()=>{const originals=scholarlyClone(data.meta.workspaces26||workspaceDefaults26),visible=scholarlyClone(spaces);fn(visible.find(s=>s.id===current.id),visible);data.meta.workspaces26=typeof mergeWorkspaces35==='function'?mergeWorkspaces35(originals,spaces,visible):visible}))render()};
 $('#wsEdit26').onchange=e=>{workspaceEdit26=e.target.value;render()};$('#wsRename26').onclick=advancedGuard(()=>mutate(s=>s.title=$('#wsName26').value.trim()));
 $('#wsAdd26').onclick=advancedGuard(()=>mutate((s,all)=>{if(all.length>=20)throw Error('最多20个工作区');const n={id:crypto.randomUUID(),title:'新工作区',pages:['home']};all.push(n);workspaceEdit26=n.id}));
 $('#wsDelete26').onclick=()=>{if(spaces.length<2||!confirm('删除此工作区设置？'))return;mutate((s,all)=>all.splice(all.findIndex(x=>x.id===s.id),1))};
 $('#wsActivate26').onclick=()=>mutate(s=>data.meta.activeWorkspace26=s.id);$('#wsPageAdd26').onclick=()=>mutate(s=>{const id=$('#wsPage26').value;if(id&&!s.pages.includes(id))s.pages.push(id)});
 for(const[selector,prop,delta]of [['[data-ws-up26]','wsUp26',-1],['[data-ws-down26]','wsDown26',1]])$$(selector).forEach(b=>b.onclick=()=>mutate(s=>{const i=Number(b.dataset[prop]),j=i+delta;if(j>=0&&j<s.pages.length)[s.pages[i],s.pages[j]]=[s.pages[j],s.pages[i]]}));
 $$('[data-ws-remove26]').forEach(b=>b.onclick=()=>mutate(s=>s.pages.splice(Number(b.dataset.wsRemove26),1)));bind();
}
function attachmentLinks26(){
 const links=[];
 for(const r of data.guidancedrafts)if(r.attachment)links.push({key:'guidancedrafts:'+r.id,title:r.title,kind:'attachment',...r.attachment});
 for(const r of data.pdfindexes)links.push({key:'pdfindexes:'+r.id,title:r.title,kind:'pdf',path:r.path,bookmark:r.bookmark,sha256:r.sha256,documentID:r.documentID||''});
 for(const r of data.sources)if(r.folio?.filePath)links.push({key:'sources:'+r.id,title:r.title,kind:'folio',path:r.folio.filePath,bookmark:r.folio.bookmarkData,sha256:r.folio.fingerprint||'',documentID:r.folio.documentID});
 if(links.length>2000)throw Error('本轮最多检查2000个附件关联，请先归档项目');return links;
}
let filesReport26=null,filesSignature26='',filesCandidates26=null;
function applyRelinks26(chosen){
 if(filesSignature26!==stableValue(attachmentLinks26()))throw Error('附件关联已有变化，请重新检查');
 if(!chosen.length)throw Error('请选择要重新关联的文件');
 if(new Set(chosen.map(r=>r.key)).size!==chosen.length)throw Error('同一记录只能选择一个候选位置');
 const original=new Map(attachmentLinks26().map(l=>[l.key,l]));
 const links=chosen.map(r=>{const old=original.get(r.key);if(!old)throw Error('记录已不存在');return{...old,path:r.path,bookmark:''}});
 const checked=advancedCall('KONGSCHOLAR_FILES_VERIFY',links);if(!checked?.rows||checked.rows.length!==links.length)throw Error('文件复核未完成，本次未修改关联');
 return projectMutation(()=>{for(const row of checked.rows){const [type,id]=[row.key.slice(0,row.key.indexOf(':')),row.key.slice(row.key.indexOf(':')+1)],r=find(type,id);if(!r)throw Error('关联记录已缺失');if(type==='sources'){r.folio.filePath=row.path;r.folio.bookmarkData=row.bookmark}else if(type==='pdfindexes'){r.path=row.path;r.bookmark=row.bookmark}else{r.attachment.path=row.path;r.attachment.bookmark=row.bookmark;r.attachment.name=row.path.split('/').at(-1)}}});
}
function files26View(){
 const links=attachmentLinks26(),valid=filesSignature26===stableValue(links),report=valid?filesReport26:null,candidates=valid?filesCandidates26:null;
 $('#app').innerHTML=headline('附件位置检查与重新关联','检查PDF索引、KongFolio项目和指导稿附件；搜索只发生在您选择的本机目录。')+`<section class="panel"><p>共${links.length}个关联。候选必须通过原内容指纹核验；KongFolio同时核对稳定文档编号。没有旧指纹时会明确提示仅核对文档编号。每轮最多遍历20000个目录项、读取512MB文件、展示2000个候选；原文件均保留。</p><button id="filesCheck26">检查已有位置</button><button id="filesSearch26">选择目录查找候选…</button>${!valid&&filesReport26?'<p>资料已变化，请重新检查。</p>':''}${report?report.rows.map(r=>`<p>${esc(links.find(l=>l.key===r.key)?.title||r.key)} · ${esc(r.state)}<br>${esc(r.path)}<br>${esc(r.error||r.proof)}</p>`).join(''):''}${candidates?`<h2>候选位置预览</h2><p>已遍历${candidates.visited}项，${candidates.unreadable||0}处目录无法读取。${candidates.truncated?'达到上限；结果不完整，请选择更小的目录继续。':''}</p>${candidates.candidates.map((r,i)=>`<p><label><input type="checkbox" data-file-candidate26="${i}">${esc(links.find(l=>l.key===r.key)?.title||r.key)}</label><br>原：${esc(links.find(l=>l.key===r.key)?.path)}<br>候选：${esc(r.path)}<br>${esc(r.proof)}</p>`).join('')||'<p>此目录中没有找到一致的候选。</p>'}<button id="filesApply26">复核并更新所选关联</button>`:''}</section>`;
 $('#filesCheck26').onclick=advancedGuard(()=>{if(!writerFlush())return;const value=attachmentLinks26(),r=advancedCall('KONGSCHOLAR_FILES_CHECK',value);if(r){filesReport26=r;filesSignature26=stableValue(value);filesCandidates26=null;render()}});
 $('#filesSearch26').onclick=advancedGuard(()=>{if(!writerFlush())return;const value=attachmentLinks26(),r=advancedCall('KONGSCHOLAR_FILES_SEARCH',value);if(r){filesCandidates26=r;filesSignature26=stableValue(value);render()}});
 if(candidates)$('#filesApply26').onclick=advancedGuard(()=>{const selected=$$('[data-file-candidate26]').filter(e=>e.checked).map(e=>candidates.candidates[Number(e.dataset.fileCandidate26)]);if(applyRelinks26(selected)){filesReport26=null;filesCandidates26=null;render();toast('已核验并更新所选位置')}});bind();
}
addAdvancedPage('设置与工具','workspaces26','自定义工作区',workspaces26View);
addAdvancedPage('设置与工具','files26','附件位置与重新关联',files26View);
