'use strict';
const studioTypes31={researchsets31:'研究现场组合',tables31:'学术表格',indexentries31:'书稿索引条目'};
function configureStudio31(types,schema){
 Object.assign(types,studioTypes31);Object.assign(advancedEnums,{indexKind31:['人物','刊物','机构','概念','其他']});
 schema.researchsets31=[['title','研究现场名称'],['chapter','写作章节','chapter'],['questionID31','研究问题','ref24:questions'],['argumentID31','论证卡','ref24:arguments'],['sourceIds','资料组合','sources'],['pdfID31','阅读PDF','ref24:pdfindexes'],['page31','PDF物理页'],['body','此现场要继续解决的问题与下一步','area']];
 schema.tables31=[['title','表题'],['number31','本项目表号'],['body','表格内容（用Tab分列，每行一条，第一行为表头）','area'],['caption31','表格说明','area'],['sourceNote31','来源与版本说明','area']];
 schema.indexentries31=[['title','规范索引词'],['indexKind31','索引类别','choice24:indexKind31'],['aliases31','别称或旧称（每行一项）','area'],['body','考证与使用说明','area']];
 schema.figures29.push(['caption31','实际导出图注（与放置计划分开）','area'],['sourceNote31','实际导出来源说明','area'],['width31','导出宽度（厘米，2—16，须能放入页边距）']);
}
function tableRows31(text){const rows=String(text||'').replace(/\r\n?/g,'\n').split('\n');while(rows.length&&rows.at(-1)==='')rows.pop();const matrix=rows.map(r=>r.split('\t'));if(matrix.length<2||matrix.length>100||matrix[0].length>12||matrix.some(r=>r.length!==matrix[0].length||r.some(c=>c.length>5000))||text.length>1000000)throw Error('表格须有表头及至少一行内容，最多100行、12列；每行列数一致，使用Tab分列');return matrix}
function normalizeStudio31(out){
 for(const type of Object.keys(studioTypes31))if(out[type].length>500)throw Error('单类新记录最多500条，请先归档');
 for(const r of out.researchsets31){if(r.projectIDs?.length!==1||!r.body?.trim()||r.page31&&(!/^\d+$/.test(r.page31)||Number(r.page31)<1)||r.position31!==undefined&&(!r.position31||typeof r.position31!=='object'||Array.isArray(r.position31)))throw Error('研究现场须属于一个项目并说明下一步，页码须为正整数');for(const key of ['start','end','scroll','within'])if(r.position31?.[key]!==undefined&&(!Number.isFinite(r.position31[key])||r.position31[key]<0))throw Error('现场位置无效')}
 const nums=new Set();for(const t of out.tables31){if(t.projectIDs?.length!==1||!t.number31?.trim()||t.number31.length>80||!t.sourceNote31?.trim())throw Error('表格须选择一个项目、表号与来源说明');tableRows31(t.body);const k=t.projectIDs[0]+':'+t.number31;if(nums.has(k)||out.figures29.some(f=>f.figureKind29==='表'&&f.projectIDs?.[0]===t.projectIDs[0]&&f.number29===t.number31))throw Error('本项目表号已使用');nums.add(k)}
 const terms=new Map();for(const r of out.indexentries31){if(r.projectIDs?.length!==1||!advancedEnums.indexKind31.includes(r.indexKind31)||r.title.length>200||/["\\\n\r]/.test(r.title)||r.aliases31?.length>10000)throw Error('索引词须选择项目和类别，不能含引号、反斜杠或换行');if(r.excluded31!==undefined&&(!Array.isArray(r.excluded31)||r.excluded31.length>10000||r.excluded31.some(x=>typeof x!=='string')))throw Error('索引排除位置无效');if(r.reviewBasis31!==undefined&&(typeof r.reviewBasis31!=='string'||r.reviewBasis31.length>8000000))throw Error('索引核验依据过大');for(const term of indexVariants31(r)){const key=r.projectIDs[0]+'|'+term;if(terms.has(key)&&terms.get(key)!==r.id)throw Error('索引词或别称重复，请合并同名条目：'+term);terms.set(key,r.id)}}return out;
}
function indexVariants31(r){return [...new Set([r.title,...(r.aliases31||'').split('\n')].map(x=>x.trim()).filter(Boolean))].sort((a,b)=>b.length-a.length)}
function setPosition31(ch,s){const body=ch?.writing?.body||'',start=Math.min(s?.start||0,body.length),end=Math.min(s?.end||start,body.length),p=(ch?.paragraphs30||[]).find(p=>start>=p.offset&&start<=p.offset+p.text.length);return{start,end,scroll:s?.editorScroll||0,paragraphID:p?.id||'',within:p?start-p.offset:0}}
function resolveSetPosition31(r,ch){const p=r.position31||{},paragraph=(ch.paragraphs30||[]).find(x=>x.id===p.paragraphID);if(!paragraph)return{start:0,length:0,scroll:0,changed:!!p.paragraphID};return{start:paragraph.offset+Math.min(p.within||0,paragraph.text.length),length:Math.min(Math.max(0,(p.end||0)-(p.start||0)),Math.max(0,paragraph.text.length-(p.within||0))),scroll:p.scroll||0,changed:false}}
function indexBasis31(r,d=data){return stableValue({title:r.title,aliases:r.aliases31||'',excluded:r.excluded31||[],chapters:(d.chapters||[]).filter(ch=>ch.projectIDs?.includes(r.projectIDs?.[0])).map(ch=>({id:ch.id,title:ch.title,paragraphs:paragraphText30(ch.writing?.body||'').map(p=>(ch.paragraphs30||[]).find(a=>a.offset===p.offset&&a.text===p.text)?.id||'unsaved:'+p.text)}))})}
function scanIndex31(ch,body,entries){
 const rows=[],paragraphs=paragraphText30(body),original=paragraphText30(ch.writing?.body||'');let truncated=false;
 outer:for(let pi=0;pi<paragraphs.length;pi++){const p=paragraphs[pi];if(/^\[\[KS31-/.test(p.text))continue;const old=original[pi],pid=old&&(ch.paragraphs30||[]).find(x=>x.offset===old.offset&&x.text===old.text)?.id||'p'+pi,notes=[...p.text.matchAll(/\[\^ks-[\w-]+\]/g)].map(m=>[m.index,m.index+m[0].length]);
  for(const entry of entries)for(const variant of indexVariants31(entry)){let at=-1,n=0;while((at=p.text.indexOf(variant,at+1))>=0){n++;if(notes.some(([a,b])=>at<b&&at+variant.length>a))continue;const key=[entry.id,ch.id,pid,variant,n].join('|');rows.push({key,entryID:entry.id,chapterID:ch.id,paragraph:pi+1,offset:p.offset+at,text:variant,term:entry.title,excluded:(entry.excluded31||[]).includes(key),context:p.text.slice(Math.max(0,at-35),at+variant.length+35)});if(rows.length>=5000){truncated=true;break outer}}}
 }
 rows.sort((a,b)=>a.offset-b.offset||b.text.length-a.text.length);let end=-1;for(const r of rows){r.overlap=r.offset<end;if(!r.overlap)end=r.offset+r.text.length}return{rows,truncated};
}
function blocksFor31(ch,body,d=data,pid=''){
 const blocks=[],seen=new Set();for(const m of body.matchAll(/^\[\[KS31-(FIG|TABLE):([A-Za-z0-9_-]{1,100})\]\]$/gm)){
  const key=m[0];if(seen.has(key))continue;seen.add(key);const r=(m[1]==='FIG'?d.figures29:d.tables31).find(x=>x.id===m[2]);if(!r||pid&&!r.projectIDs?.includes(pid)||!pid&&!r.projectIDs?.some(id=>ch.projectIDs?.includes(id)))throw Error('正文图表标记的记录缺失或属于其他项目：'+key);
  if(m[1]==='TABLE')blocks.push({marker:key,kind:'table',title:'表'+r.number31+' '+r.title,caption:r.caption31||'',source:r.sourceNote31,rows:tableRows31(r.body)});
  else{const image=d.evidenceimages.find(i=>i.id===r.imageID29),width=Number(r.width31||12);if(!image?.imageData||r.figureKind29==='表'||!r.sourceNote31?.trim()||!Number.isFinite(width)||width<2||width>16)throw Error('请先补齐图像原件、实际导出来源说明与宽度：'+r.title);blocks.push({marker:key,kind:'image',title:(r.figureKind29==='史料影像'?'影像':'图')+r.number29+' '+r.title,caption:r.caption31||'',source:r.sourceNote31,png:image.imageData,widthCM:width})}
 }return blocks;
}
