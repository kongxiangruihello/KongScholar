'use strict';
nav.splice(nav.findIndex(x=>x[0]==='chapters')+1,0,['writer','✍','章节写作台']);
nav.splice(nav.findIndex(x=>x[0]==='folio')+1,0,['history','↶','导入历史']);
let writerChapter='',writerBuffer=null,writerTimer=null,historyPreview=null;
function writerIsDirty(){return !!writerBuffer?.dirty}
function chapterWriting(ch){return ch?.writing?scholarlyClone(ch.writing):{body:'',citations:[]}}
function writerFlush(){
 if(!writerIsDirty())return true;
 const ch=find('chapters',writerBuffer.id);if(!ch){toast('章节已不存在，未保存的正文仍保留在窗口');return false}
 const previous=scholarlyClone(data);ch.writing={...writerBuffer.writing,updated:new Date().toISOString()};ch.updated=new Date().toISOString();
 if(!save()){data=previous;$('#writerSaveState').textContent='保存失败，请保留窗口并重试';return false}
 writerBuffer.dirty=false;if($('#writerSaveState'))$('#writerSaveState').textContent='正文已保存到本机';return true;
}
function stageWriting(w){if(!writerBuffer)return;writerBuffer.writing=w;writerBuffer.dirty=true;$('#writerSaveState').textContent='正在保存…';clearTimeout(writerTimer);writerTimer=setTimeout(writerFlush,400)}
function footnoteText(s){const r=referenceFor(s);return (r?referenceLine(r):(s.citation||'【出处待补】'))+'，'+(s.printedPage?'印刷页码 '+s.printedPage:'【印刷页码待核】')+(physicalFor(s)?'（PDF 物理第 '+physicalFor(s)+' 页）':'')+'。'}
function citationWarnings(c){const s=find('sources',c.sourceID);if(!s)return ['关联史料已缺失，保留插入时快照'];const warnings=[];if(c.signature!==citationSignature(s))warnings.push('原文 / 出处已变化，需复核脚注快照');if(citationState(s)!=='已核对')warnings.push('当前史料'+citationState(s));if(citationIssues(s).length)warnings.push(...citationIssues(s));return [...new Set(warnings)]}
function writingExport(ch,w=chapterWriting(ch)){
 const used=w.citations.filter(c=>w.body.includes('[^'+c.id+']'));
 const defs=used.map(c=>'[^'+c.id+']: '+c.citation.replace(/\n/g,' ')+' '+(citationWarnings(c).length?'【'+citationWarnings(c).join('；')+'】':''));
 const known=new Set(used.map(c=>c.id));const missing=[...w.body.matchAll(/\[\^(ks-[\w-]+)\]/g)].map(m=>m[1]).filter(id=>!known.has(id));
 return '# '+ch.title+'\n\n'+w.body+(defs.length?'\n\n'+defs.join('\n\n'):'')+(missing.length?'\n\n【待补脚注：'+[...new Set(missing)].join('、')+'】':'')+'\n';
}
function insertSourceCitation(id,quote=true){
 const s=find('sources',id),editor=$('#chapterBody');if(!s||!writerBuffer||!editor)return;
 const w=scholarlyClone(writerBuffer.writing);let ordinal=1;while(w.citations.some(c=>c.id==='ks-'+ordinal)||w.body.includes('[^ks-'+ordinal+']'))ordinal++;const note={id:'ks-'+ordinal,sourceID:s.id,quote:typeof layerText28==='function'?layerText28(s):(s.body||''),citation:footnoteText(s),signature:citationSignature(s),state:citationState(s)};
 const marker='[^'+note.id+']',text=(quote?((typeof layerText28==='function'?layerText28(s):s.body)||'【原文待补】'):'')+marker;
 const start=editor.selectionStart??editor.value.length,end=editor.selectionEnd??start;
 w.body=editor.value.slice(0,start)+text+editor.value.slice(end);w.citations.push(note);editor.value=w.body;editor.focus();editor.setSelectionRange(start+text.length,start+text.length);stageWriting(w);drawWriterFootnotes();
}
function drawWriterFootnotes(){const target=$('#writerFootnotes');if(!target||!writerBuffer)return;const notes=writerBuffer.writing.citations.filter(c=>writerBuffer.writing.body.includes('[^'+c.id+']'));target.innerHTML=notes.length?notes.map((c,i)=>`<details class="writer-note"><summary>脚注 ${i+1} · ${esc(citationWarnings(c).join('；')||'来源已核对')}</summary><p>${esc(c.citation)}</p><label class="field">脚注草稿（可编辑）<textarea data-note-text="${esc(c.id)}">${esc(c.citation)}</textarea></label><p class="tiny">来源与文字保留插入时快照。若需更新，可在正文删除标记后重新插入。</p></details>`).join(''):'<p class="tiny">将光标放在正文，再从右侧插入摘录或脚注。</p>';$$('[data-note-text]').forEach(t=>t.oninput=()=>{const w=scholarlyClone(writerBuffer.writing);w.citations.find(c=>c.id===t.dataset.noteText).citation=t.value;stageWriting(w)})}
function writerView(){
 let ch=projectRecords('chapters').find(c=>c.id===writerChapter)||projectRecords('chapters')[0];writerChapter=ch?.id||'';
 if(ch&&(!writerBuffer||writerBuffer.id!==ch.id))writerBuffer={id:ch.id,writing:chapterWriting(ch),dirty:false};
 $('#app').innerHTML=headline('章节写作台','沿着论证组织正文，保留引文与出处的核对痕迹。','<button data-new="chapters">＋ 新建章节</button>')+`<div class="writer-layout"><section class="panel writer-outline"><h2>章节提纲</h2>${projectRecords('chapters').map(c=>`<button class="${c.id===writerChapter?'selected':''}" data-writer-chapter="${esc(c.id)}">${esc(c.title)}</button>`).join('')||'<p class="tiny">先建立章节，再开始写作。</p>'}${ch?`<p class="tiny">本节问题</p><p>${esc(ch.body||'待填写')}</p><button data-edit="${esc(ch.id)}" data-type="chapters">编辑章节问题</button>`:''}</section><section class="panel writer-main">${ch?`<h2>${esc(ch.title)}</h2><div class="actions"><button id="writerSave" class="primary">保存正文</button><button id="writerExport">导出正文与脚注</button></div><p class="tiny" id="writerSaveState">正文自动保存到本机</p><textarea id="chapterBody" aria-label="章节正文" placeholder="从这一节要回答的问题写起…">${esc(writerBuffer.writing.body)}</textarea><h3>脚注草稿</h3><div id="writerFootnotes"></div>`:'<p>建立第一章后，正文与引文会保存在对应章节中。</p>'}</section><section class="panel writer-evidence"><h2>论证与史料</h2>${ch?`<label class="field">材料范围<select id="writerScope"><option value="chapter">本章支持与反证</option><option value="all">全部史料</option></select></label><input id="writerSearch" aria-label="检索写作史料" placeholder="检索史料标题或原文…"><div id="writerArguments"></div><div id="writerSources"></div>`:'<p class="tiny">章节确定后显示关联材料。</p>'}</section></div>`;
 bind();$$('[data-writer-chapter]').forEach(b=>b.onclick=()=>{if(!writerFlush())return;writerChapter=b.dataset.writerChapter;writerBuffer=null;render()});
 if(!ch)return;
 $('#chapterBody').oninput=e=>{stageWriting({...writerBuffer.writing,body:e.target.value});drawWriterFootnotes()};
 $('#writerSave').onclick=()=>{if(writerFlush())toast('正文已保存')};$('#writerExport').onclick=()=>{if(writerFlush())download(filename(ch.title)+'-正文与脚注.md',writingExport(ch,writerBuffer.writing))};drawWriterFootnotes();
 $('#writerArguments').innerHTML=projectRecords('arguments').filter(a=>a.chapter===ch.id).map(a=>`<details><summary>${esc(a.title)} · ${esc(a.status||'待检验')}</summary><p>${esc(a.body||'解释待写')}</p><p>竞争解释：${esc(a.counter||'待写')}</p><button data-edit="${esc(a.id)}" data-type="arguments">编辑论证</button></details>`).join('')||'<p class="tiny">本章尚未关联论证；可先查看全部史料。</p>';
 const draw=()=>{const q=$('#writerSearch').value.toLowerCase(),rows=($('#writerScope').value==='all'?data.sources:sourcesForChapter(ch.id)).filter(s=>(s.title+' '+s.body).toLowerCase().includes(q));$('#writerSources').innerHTML=rows.map(s=>`<article><span class="tag">${citationState(s)}</span><h3>${esc(s.title)}</h3><p>${esc(typeof layerText28==='function'?layerText28(s):s.body||'原文待补')}</p><p class="tiny">${typeof layerKey28==='function'?esc('新引用文本层：'+textLayers28[layerKey28(s)]):''}</p><details><summary>个人解释与出处</summary><p>${esc(s.interpretation||'个人解释待写')}</p><p class="tiny">${esc(citationSummary(s))}</p></details><div class="actions"><button data-insert-quote="${esc(s.id)}">插入摘录＋脚注</button><button data-insert-note="${esc(s.id)}">仅插入脚注</button>${validFolio(s)?`<button data-folio-open="${esc(s.id)}">返回原文</button>`:''}</div></article>`).join('')||'<p class="tiny">暂无匹配史料，可切换到全部史料。</p>';bind();$$('[data-insert-quote]').forEach(b=>b.onclick=()=>insertSourceCitation(b.dataset.insertQuote));$$('[data-insert-note]').forEach(b=>b.onclick=()=>insertSourceCitation(b.dataset.insertNote,false))};$('#writerScope').onchange=draw;$('#writerSearch').oninput=draw;draw();
}
function recordFolioBatch(previous,candidate,preview,selected){
 const keys=new Set(selected.map(i=>i.key));const entries=candidate.sources.filter(s=>keys.has(s.folio?.importKey)).map(s=>({id:s.id,before:previous.sources.find(x=>x.id===s.id)||null,after:s}));
 candidate.importHistory.unshift(scholarlyClone({id:crypto.randomUUID(),name:preview.pkg.document.title,at:new Date().toISOString(),file:preview.name,entries}));
}
function laterBatchTouches(batch,id){const i=data.importHistory.findIndex(b=>b.id===batch.id);return data.importHistory.slice(0,i).some(b=>!b.undoneAt&&b.entries.some(e=>e.id===id))}
function undoFolioPlan(batch){
 if(batch.undoneAt)throw Error('此批次已处理撤销');const candidate=scholarlyClone(data),actions=[];
 for(const e of batch.entries){const current=candidate.sources.find(s=>s.id===e.id);if(!current){actions.push({id:e.id,title:e.after.title,kind:'保留现状',reason:'卡片已删除'});continue}
 if(laterBatchTouches(batch,e.id)){actions.push({id:e.id,title:current.title,kind:'保留现状',reason:'存在更新的导入批次，请先处理后续批次'});continue}
 if(!e.before){const unchanged=scholarlyEqual({...current,updated:''},{...e.after,updated:''}),refs=referringRecords('sources',e.id);if(unchanged&&!refs.length){candidate.sources=candidate.sources.filter(s=>s.id!==e.id);actions.push({id:e.id,title:current.title,kind:'删除新增卡片',reason:'导入后未修改且未被引用'})}else actions.push({id:e.id,title:current.title,kind:'保留新增卡片',reason:refs.length?'已进入论证、教学或章节写作':'导入后已有独立修改'});continue}
 const changes=importFieldDiff(e.before,e.after).filter(d=>['title','body','folioNote','printedPage','citation','folio'].includes(d.path[0]));let restored=0,preserved=0;
 for(const d of changes){if(scholarlyEqual(readHistoryPath(current,d.path),d.after)){writeHistoryPath(current,d.path,d.before);restored++}else preserved++}
 if(restored)current.updated=new Date().toISOString();actions.push({id:e.id,title:current.title,kind:restored?'恢复来源字段':'保留现状',reason:`恢复 ${restored} 项；保留之后改写的 ${preserved} 项`});
 }
 return {candidate,actions,signature:stableValue(data),batchID:batch.id,blocked:batch.entries.some(e=>laterBatchTouches(batch,e.id))};
}
function applyFolioUndo(plan){if(plan.blocked)throw Error('请先处理后续相关批次，再重新预览撤销');if(plan.signature!==stableValue(data))throw Error('预览后记录有变化，请重新预览撤销');const previous=data;const candidate=plan.candidate,b=candidate.importHistory.find(x=>x.id===plan.batchID);if(!b||b.undoneAt)throw Error('批次已不存在或已经撤销');b.undoneAt=new Date().toISOString();b.undoSummary=plan.actions.map(a=>a.kind+'：'+a.title+'；'+a.reason);data=candidate;if(!save()){data=previous;throw Error('撤销未写入，原记录已保留')}return plan.actions}
const historyFieldNames={body:'原文',title:'标题',folioNote:'来源批注',printedPage:'印刷页码',citation:'出处',folio:'原文定位'};
function historyDiffHTML(e){const diff=importFieldDiff(e.before||{},e.after).filter(d=>['body','title','folioNote','printedPage','citation','folio'].includes(d.path[0])&&!d.path.includes('bookmarkData'));return diff.map(d=>`<div class="history-diff"><strong>${esc(historyFieldNames[d.path[0]]||d.path[0])} ${esc(d.path.slice(1).join(' / '))}</strong><div class="compare-grid"><p>导入前<br>${esc(d.before.exists?typeof d.before.value==='string'?d.before.value:JSON.stringify(d.before.value):'无')}</p><p>导入后<br>${esc(d.after.exists?typeof d.after.value==='string'?d.after.value:JSON.stringify(d.after.value):'无')}</p></div></div>`).join('')}
function historyView(){
 $('#app').innerHTML=headline('导入历史','每批保留来源前后快照。撤销前先预览，之后独立写入的解释与已引用卡片会保留。')+`<p class="tiny">历史从 1.3 开始记录，包含在完整备份中。来源恢复以字段为单位；已修改字段保留，后续批次优先处理。</p><div id="undoPreview"></div>${data.importHistory.map(b=>`<section class="panel history-batch"><div class="panelhead"><div><h2>${esc(b.name)}</h2><p class="tiny">${esc(new Date(b.at).toLocaleString('zh-CN'))} · ${b.entries.length} 条 · ${esc(b.file||'')}</p></div><span class="tag">${b.undoneAt?'已处理撤销':'已导入'}</span></div>${b.undoneAt?`<p class="tiny">${esc((b.undoSummary||[]).join('\n'))}</p>`:`<button data-undo-preview="${esc(b.id)}">预览撤销此批</button>`}<details><summary>查看 ${b.entries.length} 条记录的差异</summary>${b.entries.map(e=>`<details><summary>${e.before?'更新':'新增'} · ${esc(e.after.title)}</summary>${historyDiffHTML(e)}</details>`).join('')}</details></section>`).join('')||'<p class="empty">尚无导入历史。下一次导入会同时记录快照。</p>'}`;
 $$('[data-undo-preview]').forEach(b=>b.onclick=()=>{try{historyPreview=undoFolioPlan(data.importHistory.find(x=>x.id===b.dataset.undoPreview));$('#undoPreview').innerHTML=`<section class="panel"><h2>撤销前预览 · 尚未写入</h2>${historyPreview.actions.map(a=>`<p><strong>${esc(a.kind)}</strong> · ${esc(a.title)}<br><span class="tiny">${esc(a.reason)}</span></p>`).join('')}<div class="actions"><button id="undoApply" class="primary" ${historyPreview.blocked?'disabled':''}>确认按预览撤销</button><button id="undoCancel">取消</button></div></section>`;$('#undoApply').onclick=()=>{try{applyFolioUndo(historyPreview);historyPreview=null;render();toast('已处理撤销；独立修改和被引用卡片已保留')}catch(error){alert(error.message)}};$('#undoCancel').onclick=()=>{historyPreview=null;$('#undoPreview').innerHTML=''}}catch(error){alert(error.message)}});
}
const workflowRefs=referringRecords;referringRecords=function(type,id){const refs=workflowRefs(type,id);if(type==='sources')for(const ch of data.chapters)if(ch.writing?.citations.some(c=>c.sourceID===id&&ch.writing.body.includes('[^'+c.id+']')))refs.push('章节写作：'+ch.title);return refs};
const workflowGo=go;go=function(p){if(!writerFlush())return;workflowGo(p)};
const workflowForm=openForm;openForm=function(...args){if(!writerFlush())return;workflowForm(...args)};
const workflowRender=render;render=function(){if(!writerFlush())return;if(['writer','history'].includes(page)){const target=page;page='home';workflowRender();page=target;$('#breadcrumb').textContent='工作台 / '+(target==='writer'?'章节写作台':'导入历史');$$('nav button').forEach(b=>b.classList.toggle('active',b.dataset.page===target));if(target==='writer')writerView();else historyView()}else workflowRender()};
const workflowMarkdown=recordMarkdown;recordMarkdown=function(type,x){return type==='chapters'&&x.writing?workflowMarkdown(type,x)+'\n\n'+writingExport(x):workflowMarkdown(type,x)};
const workflowMissing=missingLinks;missingLinks=function(d){return workflowMissing(d)+d.chapters.reduce((n,ch)=>n+(ch.writing?.citations||[]).filter(c=>ch.writing.body.includes('[^'+c.id+']')&&!d.sources.some(s=>s.id===c.sourceID)).length,0)};
// Flush before backup/recovery so the last typed sentence is included.
const workflowBackup=exportBackup;exportBackup=function(){if(writerFlush())workflowBackup()};$('#backup').onclick=exportBackup;
const workflowRestore=applyRestore;applyRestore=function(){if(!writerFlush())return;workflowRestore();writerBuffer=null};
render();
