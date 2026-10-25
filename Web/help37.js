'use strict';
let helpQuery37='',helpTopic37='welcome';
function helpSearch37(query=''){const q=query.trim().toLocaleLowerCase();return helpTopics37.filter(t=>!q||[t.title,t.summary,...t.steps,...t.notes,...t.questions.flatMap(f=>[f.q,f.a])].join('\n').toLocaleLowerCase().includes(q));}
function helpTopicForPage37(id){return helpTopics37.find(t=>t.pages.includes(id))?.id||'welcome';}
function openHelp37(topic=''){if($('dialog')?.open){advancedCall('KONGSCHOLAR_HELP_OPEN37');return;}helpTopic37=helpTopics37.some(t=>t.id===topic)?topic:helpTopicForPage37(topic||page);helpQuery37='';go('help37');}
function bindHelp37(){$$('[data-help37]').forEach(b=>b.onclick=advancedGuard(()=>openHelp37(b.dataset.help37)));}
function helpDetail37(t){return `<article class="panel help-article37" aria-labelledby="helpTitle37"><p class="tiny">KongScholar 3.8 · 离线帮助</p><h2 id="helpTitle37" tabindex="-1">${esc(t.title)}</h2><p>${esc(t.summary)}</p><ol>${t.steps.map(s=>'<li>'+esc(s)+'</li>').join('')}</ol>${t.notes.length?'<h3>使用提示</h3>'+t.notes.map(s=>'<p>'+esc(s)+'</p>').join(''):''}${t.questions.length?'<h3>常见问题</h3>'+t.questions.map(f=>'<details><summary>'+esc(f.q)+'</summary><p>'+esc(f.a)+'</p></details>').join(''):''}<div class="toolbar">${t.pages.filter(p=>nav.some(n=>n[0]===p)).map(p=>`<button data-page="${esc(p)}">打开${esc(nav.find(n=>n[0]===p)[2])}</button>`).join('')}</div></article>`;}
function drawHelpResults37(){
 const topics=helpSearch37(helpQuery37),current=topics.find(t=>t.id===helpTopic37)||topics[0];if(current)helpTopic37=current.id;
 $('#helpCount37').textContent=topics.length+'个主题';$('.help-toc37').innerHTML=topics.map(t=>`<button data-topic37="${esc(t.id)}" ${current?.id===t.id?'aria-current="page" class="active"':''}>${esc(t.title)}</button>`).join('')||'<p>未找到匹配主题，请缩短关键词。</p>';
 $('#helpArticle37').innerHTML=current?helpDetail37(current):'<section class="panel"><h2>没有匹配的说明</h2><p>可搜索“日历”“备份”“投稿”等关键词。</p></section>';
 $$('[data-topic37]').forEach(b=>b.onclick=()=>{helpTopic37=b.dataset.topic37;drawHelpResults37();$('#helpTitle37')?.focus();});bind();
}
function help37View(){
 const topics=helpSearch37(helpQuery37),current=topics.find(t=>t.id===helpTopic37)||topics[0];if(current)helpTopic37=current.id;
 $('#app').innerHTML=headline('帮助说明','从日常接续到引用、交稿与备份，按实际学术工作查找。全部说明随应用离线提供。')+`<section class="panel"><label class="field">搜索帮助<input id="helpSearch37" type="search" placeholder="例如：日历、KongFolio、备份、返修" value="${esc(helpQuery37)}" autocomplete="off"></label><p id="helpCount37" class="tiny" aria-live="polite">${topics.length}个主题</p><button id="helpWindow37">在独立帮助窗口中阅读</button></section><div class="help-layout37"><nav class="panel help-toc37" aria-label="帮助主题">${topics.map(t=>`<button data-topic37="${esc(t.id)}" ${current?.id===t.id?'aria-current="page" class="active"':''}>${esc(t.title)}</button>`).join('')||'<p>未找到匹配主题，请缩短关键词。</p>'}</nav><div id="helpArticle37">${current?helpDetail37(current):'<section class="panel"><h2>没有匹配的说明</h2><p>可搜索“日历”“备份”“投稿”等关键词。</p></section>'}</div></div>`;
 const input=$('#helpSearch37');input.oninput=()=>{helpQuery37=input.value;drawHelpResults37();};$$('[data-topic37]').forEach(b=>b.onclick=()=>{helpTopic37=b.dataset.topic37;help37View();$('#helpTitle37')?.focus();});$('#helpWindow37').onclick=advancedGuard(()=>advancedCall('KONGSCHOLAR_HELP_OPEN37'));bind();
}
addAdvancedPage('设置与工具','help37','帮助说明',help37View);
const groupBefore37=toolGroup36;toolGroup36=function(id){return id==='help37'?'备份与设置':['calendarImport37','calendarExport37'].includes(id)?'日常工作与成果':groupBefore37(id);};
iconPaths33.help='M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20 M9 8a3 3 0 1 1 5 2c-2 1-2 2-2 3 M12 17v1';
const iconBefore37=pageIcon33;pageIcon33=function(id){return id==='help37'?'help':['calendarImport37','calendarExport37'].includes(id)?'calendar':iconBefore37(id);};
const navigationBefore37=studioNavigation;studioNavigation=function(){navigationBefore37();const button=document.createElement('button');button.className='help-entry37';button.setAttribute?.('aria-label','打开帮助说明');button.innerHTML='ⓘ 帮助说明';button.onclick=advancedGuard(()=>openHelp37(page));$('nav').append(button);};
const bindBeforeHelp37=bind;bind=function(){bindBeforeHelp37();bindHelp37();};
render();
