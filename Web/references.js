'use strict';
nav.splice(nav.findIndex(x=>x[0]==='sources'),0,['references','▣','文献档案'],['citations','✓','引文核对']);
const referenceField=formField;
formField=function(k,n,kind,obj){return kind==='reference'?`<label class="field">${esc(n)}<select name="${k}">${chooseList('references',obj[k]||'','待关联文献')}</select></label>`:referenceField(k,n,kind,obj)};
function referenceFor(s){return data.references.find(r=>r.id===s.referenceID)}
function physicalFor(s){return validFolio(s)?String(s.folio.physicalPage):String(s.physicalPage||'')}
function citationSignature(s){const r=referenceFor(s);return JSON.stringify([s.body||'',s.citation||'',s.printedPage||'',physicalFor(s),s.referenceID||'',r?schema.references.filter(([k])=>k!=='projectIDs'&&(k!=='referenceKind'||r.referenceKind)).map(([k])=>r[k]||''):null,s.verificationNote||'',s.folio?.fingerprint||'',s.folio?.annotationID||''])}
function citationIssues(s){const r=referenceFor(s),issues=[];if(!r)issues.push(s.referenceID?'关联文献已缺失':'尚未关联文献');if(r&&!r.author?.trim())issues.push('署名作者待核（佚名请明确填写）');if(r&&!r.year?.trim())issues.push('年代待核');if(r&&!r.edition?.trim()&&!r.issue?.trim())issues.push('版本 / 卷期待补');if(!s.body?.trim())issues.push('原文摘录待补');if(!s.printedPage?.trim())issues.push('印刷页码待核（无页码请注明定位方式）');return issues}
function citationState(s){if(!s.verification)return '待核对';return s.verification.signature===citationSignature(s)&&!citationIssues(s).length?'已核对':'需复核'}
function verifyCitation(id){const s=find('sources',id);if(!s)return;const issues=citationIssues(s);if(issues.length){alert('请先补齐：\n'+issues.join('\n'));return}if(!confirm('确认已对照原文核对摘录、文献信息和印刷页码？此状态由您人工确认。'))return;const previous=JSON.parse(JSON.stringify(data));s.verification={signature:citationSignature(s),at:new Date().toISOString()};if(!save()){data=previous;return}render();toast('已记录人工核对；相关来源变化后将提示复核')}
function resetCitation(id){const previous=JSON.parse(JSON.stringify(data)),s=find('sources',id);if(!s)return;delete s.verification;if(!save()){data=previous;return}render()}
function referenceLine(r){return r?[r.author,r.title,r.journal,r.year,r.issue,r.edition,r.translator&&'译 / 编：'+r.translator].filter(Boolean).join('，'):'文献待关联'}
function citationSummary(s){return `${referenceLine(referenceFor(s))}\n印刷页码：${s.printedPage||'待核'}；PDF 物理页码：${physicalFor(s)||'未填写'}\n核对状态：${citationState(s)}${s.verification?.at?'；上次人工核对：'+s.verification.at:''}`}
function sourcesForChapter(id){if(!id)return projectRecords('sources');const ids=new Set(data.arguments.filter(a=>a.chapter===id).flatMap(a=>[...(a.support||[]),...(a.against||[])]));return data.sources.filter(s=>ids.has(s.id))}
function citationReport(rows,title){return '# '+title+'\n\n'+rows.map(s=>'## '+s.title+'\n\n'+citationSummary(s)+'\n\n'+s.body+'\n\n核对依据：'+(s.verificationNote||'未记录')+'\n\n待补：'+(citationIssues(s).join('；')||'字段齐备；仍需人工对照原文')).join('\n\n')}
function citationView(){
 $('#app').innerHTML=headline('引文核对','对照原文逐条核对。物理页码与印刷页码分别记录，核对标记由您确认。')+`<section class="panel"><div class="toolbar"><select id="citationChapter" aria-label="筛选章节">${chooseList('chapters','','全部史料')}</select><select id="citationStatus" aria-label="核对状态"><option value="">全部状态</option><option>待核对</option><option>需复核</option><option>已核对</option></select><button id="citationExport">导出核对清单</button></div><p class="tiny">章节清单包含该章论证的支持与反证史料，同一史料只列一次。文献、原文、页码或来源文件变化会自动提示复核。</p><div id="citationRows"></div></section>`;
 const rows=()=>sourcesForChapter($('#citationChapter').value).filter(s=>!$('#citationStatus').value||citationState(s)===$('#citationStatus').value);
 const draw=()=>{$('#citationRows').innerHTML=rows().map(s=>`<article class="citation-row"><div class="panelhead"><h3>${esc(s.title)}</h3><span class="tag">${citationState(s)}</span></div><p class="citation-text">${esc(citationSummary(s))}</p><p class="tiny">${esc(citationIssues(s).join('；')||'字段齐备，请对照原文核对')}</p><p>${esc((s.body||'').slice(0,320))}</p><div class="actions"><button data-edit="${esc(s.id)}" data-type="sources">编辑资料与页码</button>${validFolio(s)?`<button data-folio-open="${esc(s.id)}">返回原文 ↗</button>`:''}<button data-verify="${esc(s.id)}">确认已核对</button>${s.verification?`<button data-unverify="${esc(s.id)}">撤销核对标记</button>`:''}</div></article>`).join('')||'<p class="empty">暂无匹配史料。先录入史料并关联文献。</p>';bind()};
 $('#citationChapter').onchange=draw;$('#citationStatus').onchange=draw;$('#citationExport').onclick=()=>download('KongScholar-引文核对清单.md',citationReport(rows(),$('#citationChapter').value?label('chapters',$('#citationChapter').value)+' · 引文核对清单':'引文核对清单'));draw();
}
const referenceCard=card;card=function(x,t){const html=referenceCard(x,t);if(t==='references')return html.replace('<div class="actions">',`<p class="citation-text">${esc(referenceLine(x))}</p><p>${esc(x.attribution||'作者归属依据待核')}</p><p class="tiny">${esc(x.project||'项目 / 馆藏待补')}</p><div class="actions">`);return t==='sources'?html.replace('<div class="actions">',`<section class="citation-info"><span class="tag">${citationState(x)}</span><p class="tiny citation-text">${esc(citationSummary(x))}</p></section><div class="actions">`):html};
const referenceBind=bind;bind=function(){referenceBind();$$('[data-verify]').forEach(b=>b.onclick=()=>verifyCitation(b.dataset.verify));$$('[data-unverify]').forEach(b=>b.onclick=()=>resetCitation(b.dataset.unverify))};
const referenceRefs=referringRecords;referringRecords=function(type,id){return type==='references'?data.sources.filter(s=>s.referenceID===id).map(s=>'史料：'+s.title):referenceRefs(type,id)};
const referenceMarkdown=recordMarkdown;recordMarkdown=function(t,x){return referenceMarkdown(t,x)+(t==='sources'?'\n## 文献与人工核对\n\n'+citationSummary(x)+'\n':'')};
const referenceMissing=missingLinks;missingLinks=function(d){return referenceMissing(d)+d.sources.filter(s=>s.referenceID&&!d.references.some(r=>r.id===s.referenceID)).length};
const referenceRender=render;render=function(){if(page==='citations'){page='home';referenceRender();page='citations';$('#breadcrumb').textContent='工作台 / 引文核对';$$('nav button').forEach(b=>b.classList.toggle('active',b.dataset.page==='citations'));citationView()}else referenceRender()};
render();

const citationSubmit=$('#form').onsubmit;
$('#form').onsubmit=function(e){
 if(editing?.type==='restore')return citationSubmit(e);
 e.preventDefault();const {type,id}=editing;let v;try{v=recordFromForm(type,e.target)}catch(error){alert(error.message);return}
 const previous=JSON.parse(JSON.stringify(data));v.id=id||crypto.randomUUID();v.updated=new Date().toISOString();
 if(id)data[type]=data[type].map(x=>x.id===id?{...x,...v}:x);else data[type].unshift(v);
 if(!save()){data=previous;return} $('dialog').close();render();toast('已保存'+types[type]);
};
