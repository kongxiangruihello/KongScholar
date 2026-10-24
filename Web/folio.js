'use strict';
// Imported source text and personal interpretation have separate ownership.
const folioUUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const folioSHA=/^[0-9a-f]{64}$/i;
let folioPreview=null,folioQueue=[];
async function folioDigest(text){const bytes=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text));return Array.from(new Uint8Array(bytes),b=>b.toString(16).padStart(2,'0')).join('')}
function folioText(x,name,limit=2_000_000){if(typeof x!=='string'||x.length>limit)throw Error(name+'不是有效文本或过长');return x}
async function parseFolioPackage(text){
 if(typeof text!=='string'||new TextEncoder().encode(text).length>25*1024*1024)throw Error('摘录文件超过 25 MB 或内容无效');
 if(!text.trim().startsWith('{'))return parseFolioMarkdown(text);
 const x=JSON.parse(text),d=x.document;
 if(x.format!=='KongFolioScholar'||x.version!==1||!d||!folioUUID.test(d.id)||!Number.isSafeInteger(d.pageCount)||d.pageCount<1||d.pageCount>1_000_000||!folioSHA.test(d.fingerprint)||!Array.isArray(x.annotations)||x.annotations.length>10000)throw Error('结构化摘录包格式或版本不受支持');
 if(d.bibliography!==undefined&&d.bibliography!==null){for(const k of ['author','title','publisher','year','edition'])folioText(d.bibliography[k],k,4000)}
 folioText(d.title,'文档标题',1000);folioText(d.filePath,'项目路径',10000);
 if(!d.filePath.startsWith('/')||!d.filePath.toLowerCase().endsWith('.kongfolio'))throw Error('摘录包缺少原 KongFolio 项目路径');
 if(d.bookmarkData!==undefined&&d.bookmarkData!==null)folioText(d.bookmarkData,'文件书签',131072);
 const seen=new Set(),rows=[];
 for(const a of x.annotations){
  if(!a||!folioUUID.test(a.id)||seen.has(a.id.toLowerCase())||!Number.isSafeInteger(a.pageIndex)||a.pageIndex<0||a.pageIndex>=d.pageCount||a.physicalPage!==a.pageIndex+1)throw Error('存在重复批注编号或无效页码');
  seen.add(a.id.toLowerCase());for(const k of ['quote','note','kind','printedPage'])folioText(a[k],k,k==='kind'?80:k==='printedPage'?100:2_000_000);
  if(!a.quote.trim()&&!a.note.trim())continue;
  if(a.tags!==undefined&&(!Array.isArray(a.tags)||a.tags.length>50||a.tags.some(t=>typeof t!=='string'||t.length>100)))throw Error('批注标签无效');
  rows.push({...a,id:a.id.toLowerCase(),quoteHash:await folioDigest(a.quote)});
 }
 if(!rows.length)throw Error('摘录包中没有文字摘录或批注');
 return {document:{...d,id:d.id.toLowerCase(),fingerprint:d.fingerprint.toLowerCase()},rows,legacy:false,warnings:[]};
}
async function parseFolioMarkdown(text){
 const normalized=text.replace(/\r\n?/g,'\n');
 if(/^页码按文档当前物理页序编号（此 PDF 未提供不同的印刷页码标签）。/m.test(normalized)||/^“第 N 页”为文档中的物理页序；括号内为 PDF 页码标签/m.test(normalized))return parseModernFolioMarkdown(normalized);
 if(!/^# .+— 批注摘要\s*$/m.test(normalized)||!/^来源文档：/m.test(normalized)||!/^页码按文档当前物理页序编号。/m.test(normalized))throw Error('请选择 KongFolio 导出的“Markdown · 摘录与笔记”，不支持任意 Markdown 文档');
 const title=normalized.match(/^来源文档：(.+?)\s*$/m)[1].trim();folioText(title,'来源文档',1000);
 const documentID='legacy-'+(await folioDigest(title)).slice(0,32),rows=[],seen=new Set();let start=0,maxPage=1;
 for(const match of normalized.matchAll(/^来源页：(\d+)\s*$/gm)){
  const physicalPage=Number(match[1]);if(!Number.isSafeInteger(physicalPage)||physicalPage<1||physicalPage>1_000_000)throw Error('摘要中的来源页码无效');
  const chunk=normalized.slice(start,match.index);start=match.index+match[0].length;
  const lines=chunk.split('\n'),heading=lines.findIndex(s=>/^### .+/.test(s));if(heading<0)throw Error('摘要批注结构不完整，请使用原始导出文件');
  const kind=lines[heading].slice(4).trim(),contents=lines.slice(heading+1),noteIndex=contents.findIndex(s=>s==='笔记：');
  const quote=contents.slice(0,noteIndex<0?contents.length:noteIndex).filter(s=>s.startsWith('>')).map(s=>s.replace(/^> ?/,'')).join('\n');
  const note=noteIndex<0?'':contents.slice(noteIndex+1).join('\n').trim();
  if(!quote.trim()&&!note.trim())continue;
  const id=await folioDigest(JSON.stringify([title,physicalPage,kind,quote,note]));if(seen.has(id))continue;seen.add(id);
  rows.push({id,pageIndex:physicalPage-1,physicalPage,printedPage:'',kind,quote,note,quoteHash:await folioDigest(quote)});maxPage=Math.max(maxPage,physicalPage);
 }
 if(!rows.length||rows.length>10000)throw Error('摘要中没有可用文字摘录，或条数超过限制');
 return {document:{id:documentID,title,filePath:'',fingerprint:'',pageCount:maxPage},rows,legacy:true,warnings:['旧版 Markdown 没有稳定批注编号与文件定位，按文档标题、物理页码和完整文字去重。批注文字变化会作为新摘录；同名文档请人工核对。','印刷页码不会由物理页码推算。返回原文前需手动关联由新版 KongFolio 保存的项目。']};
}
function folioKey(pkg,row){return pkg.document.id+'|'+row.id}
function folioSnapshot(pkg,row){return {quote:row.quote,note:row.note,pageIndex:row.pageIndex,physicalPage:row.physicalPage,printedPage:row.printedPage,kind:row.kind,fingerprint:pkg.document.fingerprint,filePath:pkg.document.filePath,tags:row.tags||[],bibliography:pkg.document.bibliography||null}}
function validFolio(x){const f=x?.folio;return !!f&&typeof f==='object'&&typeof f.importKey==='string'&&typeof f.documentID==='string'&&Number.isSafeInteger(f.physicalPage)&&f.physicalPage>0}
function classifyFolio(pkg,row,sources=data.sources){
 const key=folioKey(pkg,row),existing=sources.filter(x=>validFolio(x)&&x.folio.importKey===key);
 if(existing.length>1)return {kind:'blocked',label:'来源编号重复，需先整理',row,key};
 if(!existing.length)return {kind:'new',label:'新增',row,key};
 const source=existing[0],last=source.folio.lastImported,snapshot=folioSnapshot(pkg,row);
 if(last&&Object.keys(snapshot).every(k=>scholarlyEqual(last[k],snapshot[k])))return {kind:'same',label:'内容相同，跳过',row,key,source};
 const localChanged=!last||source.body!==last.quote||(source.folioNote||'')!==last.note;
 return {kind:localChanged?'conflict':'update',label:localChanged?'本地来源字段已修改':'来源有更新',row,key,source,sourceSignature:JSON.stringify(source)};
}
function prepareFolio(pkg,name){return {pkg,name,items:pkg.rows.map(row=>classifyFolio(pkg,row)),preparedAt:new Date().toISOString()}}
async function nativePreviewFolioPackage(file){
 try{
  if(!file||typeof file.name!=='string')throw Error('没有可读取的摘录文件');
  if(document.querySelector('dialog').open||folioPreview||writerIsDirty()){if(folioQueue.length>=10)throw Error('待处理摘录过多，请先完成当前预览');folioQueue.push(file);toast('已收到摘录，关闭编辑后可在 KongFolio 联动中查看待导入文件');return}
  const pkg=await parseFolioPackage(file.text);folioPreview=prepareFolio(pkg,file.name);go('folio');
 }catch(error){alert('无法导入 KongFolio 摘录：'+error.message)}
}
function openFolioImport(){
 if(document.querySelector('dialog').open)return toast('请先保存或关闭当前编辑');
 if(folioQueue.length&&!folioPreview){nativePreviewFolioPackage(folioQueue.shift());return}
 const result=window.prompt('KONGSCHOLAR_FOLIO_IMPORT','');if(!result)return;
 try{nativePreviewFolioPackage(JSON.parse(result))}catch{alert('所选文件无法读取')}
}
function folioOriginHTML(x){if(!validFolio(x))return '';const f=x.folio;return `<section class="folio-origin"><span class="tag">来自 KongFolio</span><p class="tiny">PDF 物理第 ${f.physicalPage} 页 · 印刷页码：${esc(x.printedPage||'待核')}<br>${esc(f.documentTitle||'来源文档')}<br>来源文件：${esc(f.filePath||'尚未关联项目')}</p>${Array.isArray(f.tags)&&f.tags.length?`<p class="tiny">主题标签：${f.tags.map(esc).join('、')}</p>`:''}${x.folioNote?`<h4>来源批注快照</h4><p>${esc(x.folioNote)}</p>`:''}<button type="button" data-folio-open="${esc(x.id)}">返回原文 ↗</button> <button type="button" data-folio-relink="${esc(x.id)}">重新关联项目…</button></section>`}
function folioOriginPayload(source){const f=source.folio;return {documentID:f.documentID,annotationID:f.annotationID||'',filePath:f.filePath||'',bookmarkData:f.bookmarkData||'',physicalPage:f.physicalPage,fingerprint:f.fingerprint||'',quoteHash:f.quoteHash||'',legacy:!!f.legacy}}
function updateFolioLocation(source,result){
 const documentID=source.folio.documentID,importDoc=source.folio.importDocumentID;
 for(const x of data.sources)if(validFolio(x)&&x.folio.documentID===documentID&&x.folio.importDocumentID===importDoc){x.folio.filePath=result.filePath;x.folio.bookmarkData=result.bookmarkData||'';if(result.documentID)x.folio.documentID=result.documentID}
}
function returnFolioSource(id){const source=find('sources',id);if(!validFolio(source))return;try{const result=window.prompt('KONGSCHOLAR_FOLIO_OPEN',JSON.stringify(folioOriginPayload(source)));if(!result)return;const value=JSON.parse(result);data.meta.lastFolioResult={at:new Date().toLocaleString('zh-CN'),message:value.message||value.status};if(value.status==='opened'&&value.filePath){const previous=JSON.parse(JSON.stringify(data));updateFolioLocation(source,value);if(!save())data=previous}save();toast(value.message||'已请求打开原文')}catch{toast('无法打开原项目，请重新关联或检查 KongFolio 版本')}}
function relinkFolioSource(id){const source=find('sources',id);if(!validFolio(source))return;try{const result=window.prompt('KONGSCHOLAR_FOLIO_RELINK',JSON.stringify(folioOriginPayload(source)));if(!result)return;const value=JSON.parse(result);if(typeof value.filePath!=='string'||!folioUUID.test(value.documentID))throw Error();const previous=JSON.parse(JSON.stringify(data));updateFolioLocation(source,value);if(!save()){data=previous;return}if(document.querySelector('dialog').open)document.querySelector('dialog').close();render();toast('已更新同一来源文档的项目位置')}catch{toast('项目未重新关联')}}
function applyFolioSelection(preview,keys,question='',citation='',deferSave=false){
 if(loadError)throw Error('当前数据处于保护模式，请先处理备份恢复');
 const selected=preview.items.filter(x=>keys.includes(x.key)&&!['same','blocked'].includes(x.kind));if(!selected.length)throw Error('请先勾选要导入的摘录');
 const previous=data,candidate=JSON.parse(JSON.stringify(data));
 for(const item of selected){
  const current=classifyFolio(preview.pkg,item.row,data.sources);
  if(current.kind!==item.kind||(item.sourceSignature&&current.sourceSignature!==item.sourceSignature))throw Error('预览后记录发生变化，请重新导入并检查更新');
  const {row}=item,pkg=preview.pkg,now=new Date().toISOString(),snapshot=folioSnapshot(pkg,row),old=current.source;
  const oldFolio=old?.folio||{};
  const effectivePrinted=old?.printedPage&&old.printedPage!==oldFolio.lastImported?.printedPage?old.printedPage:row.printedPage;
  const generatedTitle=pkg.document.title+' · PDF第'+row.physicalPage+'页 · '+row.kind;
  const generatedCitation=(citation.trim()||pkg.document.title)+'，PDF 物理第 '+row.physicalPage+' 页'+(effectivePrinted?'；印刷页码 '+effectivePrinted:'；印刷页码待核');
  const origin={...oldFolio,importKey:item.key,importDocumentID:pkg.document.id,documentID:oldFolio.legacy&&oldFolio.documentID!==oldFolio.importDocumentID?oldFolio.documentID:pkg.document.id,annotationID:pkg.legacy?'':row.id,documentTitle:pkg.document.title,filePath:pkg.legacy?(oldFolio.filePath||''):pkg.document.filePath,bookmarkData:pkg.legacy?(oldFolio.bookmarkData||''):(pkg.document.bookmarkData||''),physicalPage:row.physicalPage,pageIndex:row.pageIndex,fingerprint:pkg.document.fingerprint,quoteHash:row.quoteHash,legacy:pkg.legacy,bibliography:pkg.document.bibliography||oldFolio.bibliography||null,lastImported:snapshot,tags:row.tags||[],importedAt:now};
  if(old){
   const updated={...old,body:row.quote,folioNote:row.note,folio:origin,updated:now};
   const oldGeneratedTitle=oldFolio.generatedTitle||(oldFolio.documentTitle+' · PDF第'+oldFolio.lastImported?.physicalPage+'页 · '+oldFolio.lastImported?.kind);
   origin.generatedTitle=oldGeneratedTitle;
   if(old.title===oldGeneratedTitle){updated.title=generatedTitle;origin.generatedTitle=generatedTitle}
   if(old.citation===oldFolio.generatedCitation){updated.citation=generatedCitation;origin.generatedCitation=generatedCitation}else origin.generatedCitation=oldFolio.generatedCitation||'';
   if(!old.printedPage||old.printedPage===oldFolio.lastImported?.printedPage)updated.printedPage=row.printedPage;
   candidate.sources=candidate.sources.map(x=>x.id===old.id?updated:x);
  }else candidate.sources.unshift({id:crypto.randomUUID(),title:generatedTitle,body:row.quote,folioNote:row.note,printedPage:row.printedPage,citation:generatedCitation,interpretation:'',question,projectIDs:projectIDsForLinks({question}),folio:{...origin,generatedCitation,generatedTitle},updated:now});
 }
 candidate.meta.lastFolioImport={at:new Date().toLocaleString('zh-CN'),name:preview.name,count:selected.length};recordFolioBatch(previous,candidate,preview,selected);data=candidate;if(!deferSave&&!save()){data=previous;throw Error('写入失败，当前研究记录已保留。请导出备份并检查磁盘。')}
 return selected.length;
}
function finishFolioPreview(){folioPreview=null;if(folioQueue.length){nativePreviewFolioPackage(folioQueue.shift())}else render()}
function folioView(){
 const imported=data.sources.filter(validFolio);
 $('#app').innerHTML=headline('KongFolio 联动','从阅读与批注进入研究论证。导入前预览，个人解释与论证关联始终保留。','<button class="primary" id="folioImport">＋ 导入摘录包 / Markdown…</button>')+`<section class="panel"><h2>阅读 → 史料 → 论证</h2><p>在 KongFolio 0.22.1 的“KongScholar”菜单选择并发送摘录，或导出结构化 JSON 后在此导入。原 PDF 保留在 KongFolio 项目中，不复制进研究备份。</p><p class="tiny">已关联 ${imported.length} 张史料卡片 · 待处理 ${folioQueue.length} 个文件。修改、删除或重排原文页面后，请重新导出并核对引用。</p>${folioQueue.length&&!folioPreview?'<button id="folioQueued">查看待导入文件</button>':''}<button data-page="sources">查看史料卡片 ↗</button></section><div id="folioPreview"></div>`;
 $('#folioImport').onclick=openFolioImport;if($('#folioQueued'))$('#folioQueued').onclick=()=>nativePreviewFolioPackage(folioQueue.shift());
 const p=folioPreview;if(!p){bind();return}
 const counts={new:0,update:0,conflict:0,same:0,blocked:0};p.items.forEach(x=>counts[x.kind]++);
 const missing=imported.filter(s=>s.folio.importDocumentID===p.pkg.document.id&&!p.items.some(x=>x.key===s.folio.importKey)).length;
 $('#folioPreview').innerHTML=`<section class="panel" style="margin-top:24px"><span class="tag rust">导入前预览 · 尚未写入</span><h2>${esc(p.pkg.document.title)}</h2><p class="tiny">${esc(p.name)} · ${p.pkg.legacy?'旧版 Markdown':'结构化摘录包 v1'}</p><p>新增 ${counts.new} · 更新 ${counts.update} · 本地冲突 ${counts.conflict} · 相同跳过 ${counts.same} · 编号重复 ${counts.blocked}</p>${p.pkg.warnings.map(w=>`<p class="gap">${esc(w)}</p>`).join('')}${missing?`<p class="gap">此前导入的 ${missing} 条记录未出现在本次摘录包中，不会自动删除。</p>`:''}<p>更新只替换所选记录的来源原文、来源批注与定位信息。个人解释、研究问题、卡片编号及论证关联保留。本地改写过的来源字段将标记冲突，默认不勾选。</p><label class="field">新增卡片关联研究问题<select id="folioQuestion">${options('')}</select></label><label class="field">新增 / 自动出处的文献信息（可补作者、刊物与卷期）<input id="folioCitation" value="${esc(folioBibliographyText(p.pkg.document.bibliography)||p.pkg.document.title)}"></label><div class="folio-review-list">${p.items.map((item,i)=>{const enabled=!['same','blocked'].includes(item.kind);return `<article class="folio-review"><label><input type="checkbox" name="folioSelection" value="${i}" ${enabled?'':'disabled'} ${['new','update'].includes(item.kind)?'checked':''}> <span class="tag ${item.kind==='conflict'?'rust':''}">${item.label}</span> PDF物理第 ${item.row.physicalPage} 页 · ${esc(item.row.kind)}</label>${item.source?`<p class="tiny">现有卡片：${esc(item.source.title)}</p>`:''}<details ${item.kind==='conflict'?'open':''}><summary>查看来源文字与更新差异</summary><div class="compare-grid">${item.source?`<div><h4>当前卡片的来源字段</h4><p>${esc(item.source.body||'无原文')}</p><p><strong>来源批注：</strong>${esc(item.source.folioNote||'无')}</p><p class="tiny">物理页码：${item.source.folio.physicalPage}</p></div>`:''}<div><h4>此次导入的来源字段</h4><p>${esc(item.row.quote||'无原文')}</p><p><strong>来源批注：</strong>${esc(item.row.note||'无')}</p><p class="tiny">物理页码：${item.row.physicalPage} · 印刷页码：${esc(item.row.printedPage||'待核')}</p></div></div></details></article>`}).join('')}</div><div class="actions"><button class="primary" id="folioApply">导入勾选项</button><button id="folioCancel">关闭本次预览</button></div></section>`;
 $('#folioApply').onclick=()=>{try{const indices=$$('input[name="folioSelection"]:checked').map(x=>Number(x.value));const keys=indices.map(i=>p.items[i]?.key).filter(Boolean);const n=applyFolioSelection(p,keys,$('#folioQuestion').value,$('#folioCitation').value);finishFolioPreview();toast('已导入 / 更新 '+n+' 张史料卡片')}catch(err){alert(err.message)}};
 $('#folioCancel').onclick=finishFolioPreview;bind();
}
// Extend the existing workspace without changing its storage key or existing record IDs.
schema.sources.push(['printedPage','印刷页码（人工核对，不由 PDF 页码推算）'],['folioNote','KongFolio 来源批注快照','area']);
nav.splice(nav.findIndex(x=>x[0]==='sources')+1,0,['folio','⇄','KongFolio 联动']);
const folioBaseCard=card;card=function(x,t){const html=folioBaseCard(x,t);return t==='sources'?html.replace('<div class="actions">',folioOriginHTML(x)+'<div class="actions">'):html};
const folioBaseBind=bind;bind=function(){folioBaseBind();$$('[data-folio-open]').forEach(b=>b.onclick=()=>returnFolioSource(b.dataset.folioOpen));$$('[data-folio-relink]').forEach(b=>b.onclick=()=>relinkFolioSource(b.dataset.folioRelink))};
const folioBaseForm=openForm;openForm=function(type,id,prefill){folioBaseForm(type,id,prefill);if(type==='sources'&&id){const source=find(type,id);if(validFolio(source)){const div=document.createElement('div');div.innerHTML=folioOriginHTML(source);$('#fields').prepend(div);bind()}}};
const folioBaseRender=render;render=function(){if(page==='folio'){page='home';folioBaseRender();page='folio';$('#breadcrumb').textContent='工作台 / KongFolio 联动';$$('nav button').forEach(b=>b.classList.toggle('active',b.dataset.page==='folio'));folioView()}else folioBaseRender()};
render();
function folioBibliographyText(b){if(!b)return '';return [b.author,b.title&&'《'+b.title+'》',b.edition,b.publisher,b.year].filter(Boolean).join('，')}
function folioTargetHTML(info){return `<h3>当前关联的 KongFolio</h3><p class="tiny">${esc(info?.path||'尚未确认路径')}<br>版本：${esc(info?.version||'未找到')} · ${info?.supported?'联动可用':'需要 0.22.1 联动补丁'}</p><button id="chooseFolioApp">选择 KongFolio App…</button>`}
function chooseFolioApplication(){try{const text=window.prompt('KONGSCHOLAR_FOLIO_CHOOSE','');if(text){const info=JSON.parse(text);if($('#folioTarget')){$('#folioTarget').innerHTML=folioTargetHTML(info);$('#chooseFolioApp').onclick=chooseFolioApplication}toast(info.supported?'已固定 KongFolio 路径':'已记住路径，此版本需要联动补丁')}}catch{toast('未更改关联 App')}}
const modernFolioView=folioView;folioView=function(){modernFolioView();const box=document.createElement('section');box.className='panel';box.id='folioTarget';try{const text=window.prompt('KONGSCHOLAR_FOLIO_TARGET','');box.innerHTML=folioTargetHTML(text?JSON.parse(text):null)}catch{box.innerHTML=folioTargetHTML(null)}$('#app').prepend(box);if($('#chooseFolioApp'))$('#chooseFolioApp').onclick=chooseFolioApplication};
async function parseModernFolioMarkdown(text){
 const normalized=text.replace(/\r\n?/g,'\n');const title=normalized.match(/^来源文档：(.+?)\s*$/m)?.[1]?.trim();if(!title||!/^# .+— 批注摘要\s*$/m.test(normalized))throw Error('不是 KongFolio 摘录摘要');
 const markers=[...normalized.matchAll(/^## 第 (\d+) 页(?:（印刷页码 ([^）]+)）)?\s*$|^### (.+)\s*$/gm)],rows=[],seen=new Set();let page=0,printed='',maxPage=1;
 for(let i=0;i<markers.length;i++){const m=markers[i];if(m[1]){page=Number(m[1]);printed=m[2]||'';if(!Number.isSafeInteger(page)||page<1||page>1000000)throw Error('摘要中的页码无效');maxPage=Math.max(maxPage,page);continue}if(!page)throw Error('摘要缺少物理页码');const chunk=normalized.slice(m.index+m[0].length,markers[i+1]?.index??normalized.length);const lines=chunk.split('\n'),noteIndex=lines.indexOf('笔记：'),quote=lines.slice(0,noteIndex<0?lines.length:noteIndex).filter(s=>s.startsWith('>')).map(s=>s.replace(/^> ?/,'')).join('\n');const tail=lines.findIndex(s=>/^(来源页：|引用：)/.test(s));const note=noteIndex<0?'':lines.slice(noteIndex+1,tail>=0?tail:lines.length).join('\n').trim(),kind=m[3].trim();if(!quote.trim()&&!note.trim())continue;const id=await folioDigest(JSON.stringify([title,page,printed,kind,quote,note]));if(seen.has(id))continue;seen.add(id);rows.push({id,pageIndex:page-1,physicalPage:page,printedPage:printed,kind,quote,note,quoteHash:await folioDigest(quote)})}
 if(!rows.length||rows.length>10000)throw Error('摘要没有可用摘录或条数超过限制');return {document:{id:'legacy-'+(await folioDigest(title)).slice(0,32),title,filePath:'',fingerprint:'',pageCount:maxPage},rows,legacy:true,warnings:['已读取 KongFolio 0.22 摘要；印刷页码来自 PDF 页码标签，需人工核对。Markdown 不含稳定批注编号与项目路径，文字变化会成为新摘录；精确返回原文请使用 0.22.1 结构化联动。']};
}
