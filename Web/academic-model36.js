'use strict';
const academicTypes36={outcomes36:'个人学术成果',cvdrafts36:'学术履历草稿',continuations36:'讲座转论文接续记录',academicdates36:'个人学术日程'};
const projectStages36={
 '书稿':['构思','史料搜集','提纲设计','初稿写作','修订','出版准备','已出版','暂缓'],
 '论文':['选题','资料整理','写作','投稿准备','已投稿','返修','已录用','已发表','暂缓'],
 '讲座':['拟议','已约定','提纲准备','讲稿准备','材料核对','已报告','整理成果','已完成','已取消'],
 '会议报告':['拟议','已约定','提纲准备','讲稿准备','材料核对','已报告','整理成果','已完成','已取消'],
 '审稿':['待读','审阅中','意见整理','已交意见','已完成'],
 '学术活动':['待规划','准备中','进行中','整理成果','已完成','暂缓']
};
function stagesFor36(kind){return projectStages36[kind]||['待规划','资料搜集','进行中','修改完善','已完成','暂缓'];}
function configureAcademic36(types,schema){
 Object.assign(types,academicTypes36);
 Object.assign(advancedEnums,{outcomeKind36:['著作','论文','讲座与报告'],outcomeState36:['待核','本人已确认'],dateKind36:['交稿','投稿','返修','学术报告','研究安排','其他'],dateState36:['待处理','已完成','已取消']});
 Object.assign(advancedRelations,{talkID36:'talks35',paperID36:'projects',submissionID36:'submissions'});
 schema.projects.push(['blocked36','当前卡点（可空）','area'],['stageNote36','阶段调整说明（可空）','area']);
 schema.talks35.push(['startTime36','开始时间（HH:MM，可空）'],['duration36','持续分钟（有开始时间时填写）']);
 schema.feedback.push(['submissionID36','对应投稿（可空，旧意见不会自动指定）','ref24:submissions']);
 schema.submissions.push(['round36','稿次 / 返修轮次（可空）']);
 schema.outcomes36=[['title','成果题名'],['outcomeKind36','成果类型','choice24:outcomeKind36'],['outcomeState36','核实状态','choice24:outcomeState36'],['authors36','作者 / 报告人'],['date36','出版、发表或举行日期（YYYY / YYYY-MM / YYYY-MM-DD）'],['venue36','出版社、刊物或报告场合'],['volume36','卷期（可空）'],['pages36','页码（可空）'],['identifier36','ISBN / DOI / 其他标识（可空）'],['publicNote36','公开补充说明（可空）'],['freezeID','对应定稿（可空）','freezeRef'],['deliveryID','对应交付文件（可空）','ref24:deliveries'],['talkID36','来源讲座（可空）','ref24:talks35'],['body','个人备注（不进入履历）','area']];
 schema.cvdrafts36=[['title','履历名称'],['body','核对并编辑履历正文','area'],['cvSources36','来源快照','hidden36'],['basis36','来源依据','hidden36']];
 schema.continuations36=[['title','接续名称']];
 schema.academicdates36=[['title','日程名称'],['dateKind36','事项类型','choice24:dateKind36'],['dateState36','处理状态','choice24:dateState36'],['date36','日期','date'],['startTime36','开始时间（HH:MM，可空）'],['endTime36','结束时间（HH:MM，可空）'],['body','安排说明','area']];
}
function timeMinutes36(text){if(typeof text!=='string'||!/^([01]\d|2[0-3]):[0-5]\d$/.test(text))return null;const [h,m]=text.split(':').map(Number);return h*60+m;}
function validStamp36(v){return typeof v==='string'&&Number.isFinite(Date.parse(v));}
function validateSnapshot36(value,max=4*1024*1024){if(typeof value!=='string'||value.length>max)throw Error('来源快照无效或过长');let result;try{result=JSON.parse(value)}catch{throw Error('来源快照无法读取')}return result;}
function outcomePublic36(r){return Object.fromEntries(['id','title','outcomeKind36','outcomeState36','authors36','date36','venue36','volume36','pages36','identifier36','publicNote36'].map(k=>[k,r[k]||'']));}
function outcomeLine36(r){return [r.authors36,r.title,r.venue36,r.date36,r.volume36,r.pages36?'第'+r.pages36+'页':'',r.identifier36,r.publicNote36].filter(Boolean).join('，')+'。';}
function normalizeAcademic36(d){
 for(const [t,limit] of [['outcomes36',5000],['cvdrafts36',300],['continuations36',2000],['academicdates36',5000]])if(!Array.isArray(d[t])||d[t].length>limit)throw Error('学术记录无效或达到容量上限');
 const pins=d.meta.pinnedProjects36;if(pins!==undefined&&(!Array.isArray(pins)||pins.length>50||pins.some(id=>typeof id!=='string')||new Set(pins).size!==pins.length))throw Error('置顶项目设置无效');
 if(d.profile.name36!==undefined&&(typeof d.profile.name36!=='string'||d.profile.name36.length>200))throw Error('姓名或署名无效');
 for(const p of d.projects)if(p.stageHistory36!==undefined){if(!Array.isArray(p.stageHistory36)||p.stageHistory36.length>300)throw Error('项目阶段历史达到300次，请先归档');for(const h of p.stageHistory36)if(!validStamp36(h.at)||!['before','after','beforeKind','afterKind','note'].every(k=>typeof h[k]==='string'))throw Error('项目阶段历史无效');}
 for(const s of d.submissions)if(s.statusHistory36!==undefined){if(!Array.isArray(s.statusHistory36)||s.statusHistory36.length>300)throw Error('投稿历史达到300次，请先归档');for(const h of s.statusHistory36)if(!validStamp36(h.at)||!h.before||typeof h.before!=='object'||Array.isArray(h.before))throw Error('投稿历史无效');}
 for(const t of d.talks35){if(t.startTime36||t.duration36){const start=timeMinutes36(t.startTime36);if(start===null||!/^\d+$/.test(t.duration36||'')||Number(t.duration36)<1||Number(t.duration36)>720||start+Number(t.duration36)>1440)throw Error('报告时间须为HH:MM，持续1—720分钟且不跨日');}}
 for(const r of d.outcomes36){if(r.projectIDs?.length!==1||!d.projects.some(p=>p.id===r.projectIDs[0]&&!historicalRecord35('projects',p,d))||!advancedEnums.outcomeKind36.includes(r.outcomeKind36)||!advancedEnums.outcomeState36.includes(r.outcomeState36)||r.date36&&!validDate(r.date36))throw Error('成果须有有效类型、核实状态、日期及一个个人学术项目');if(r.outcomeState36==='本人已确认'&&(!r.authors36?.trim()||!r.date36||!r.venue36?.trim()))throw Error('确认正式成果前，请填写作者、日期及出版社、刊物或报告场合');for(const k of ['title','authors36','venue36','volume36','pages36','identifier36','publicNote36'])if(r[k]!==undefined&&(typeof r[k]!=='string'||r[k].length>2000))throw Error('成果公开字段过长');}
 for(const r of d.cvdrafts36){if(!r.body?.trim()||r.body.length>500000)throw Error('请填写履历正文，最多50万字符');const sources=validateSnapshot36(r.cvSources36,1024*1024),basis=validateSnapshot36(r.basis36,1024*1024);if(!Array.isArray(sources)||!sources.length||sources.length>500||new Set(sources.map(s=>s.id)).size!==sources.length||sources.some(s=>!s||typeof s.id!=='string'||typeof s.title!=='string'||s.outcomeState36!=='本人已确认')||stableValue(sources)!==stableValue(basis))throw Error('履历来源记录无效');}
 for(const r of d.continuations36){if(typeof r.talkID36!=='string'||!r.talkID36||typeof r.paperID36!=='string'||!r.paperID36||!validStamp36(r.at36)||r.projectIDs?.length!==1||r.projectIDs[0]!==r.paperID36||!r.snapshot36||typeof r.snapshot36!=='object'||Array.isArray(r.snapshot36)||r.snapshot36.id!==r.talkID36||typeof r.snapshot36.script35!=='string'||typeof r.basis36!=='string'||r.basis36.length>4*1024*1024)throw Error('讲座转论文来源记录无效');}
 for(const r of d.academicdates36){if(!r.date36||!fullDayValid(r.date36)||!advancedEnums.dateKind36.includes(r.dateKind36)||r.dateState36&&!advancedEnums.dateState36.includes(r.dateState36)||(r.projectIDs||[]).length>1||(r.projectIDs||[]).some(id=>!d.projects.some(p=>p.id===id&&!historicalRecord35('projects',p,d))))throw Error('日程须有有效日期、类型，最多关联一个个人学术项目');if(r.startTime36||r.endTime36){const start=timeMinutes36(r.startTime36),end=timeMinutes36(r.endTime36);if(start===null||end===null||end<=start)throw Error('日程起止时间须为HH:MM，结束晚于开始且不跨日');}}
 return d;
}
function sortedProjects36(){const pins=data.meta.pinnedProjects36||[];return academicProjects35().slice().sort((a,b)=>{const ai=pins.indexOf(a.id),bi=pins.indexOf(b.id);return (ai<0?10000:ai)-(bi<0?10000:bi);});}
function projectContinuation36(p){const chapters=projectRecords('chapters',p.id),session=data.meta.researchSessions?.[p.id],last=chapters.find(c=>c.id===session?.chapterID)||chapters.find(c=>c.id===data.meta.lastWritingChapter?.[p.id])||chapters.slice().sort((a,b)=>(b.writing?.updated||b.updated||'').localeCompare(a.writing?.updated||a.updated||''))[0],tasks=projectRecords('tasks',p.id).filter(t=>t.progress!=='已完成'),blocked=tasks.filter(t=>blockers25(t).blocked);return {last,tasks,where:last?.resume?.where||last?.title||'尚未记录',next:p.next||last?.resume?.next||tasks[0]?.title||'待明确',gap:p.blocked36||last?.resume?.gap||blocked.map(t=>t.title+'：'+(blockers25(t).reason||'前置事项未完成')).join('；')||'暂未记录卡点',blocked};}
function talkBasis36(id){const t=find('talks35',id);if(!t||historicalRecord35('talks35',t))throw Error('请选择个人学术讲座');const packet=t.packetID34&&find('packets34',t.packetID34),items=packet?packetRows34(packet.id):[];if(items.some(i=>i.sourceID&&!find('sources',i.sourceID)||i.pdfID34&&!find('pdfindexes',i.pdfID34)))throw Error('选材有缺失关联，请先在材料包中核对');if(packet&&historicalRecord35('packets34',packet))throw Error('历史课程材料不进入论文接续');return stableValue({talk:t,packet:packet||null,items,sources:items.map(i=>i.sourceID&&find('sources',i.sourceID)).filter(Boolean).map(s=>({id:s.id,title:s.title,body:s.body,citation:s.citation,referenceID:s.referenceID,physicalPage:s.physicalPage,printedPage:s.printedPage,folio:s.folio,reference:s.referenceID&&find('references',s.referenceID)})),pdfs:items.map(i=>i.pdfID34&&find('pdfindexes',i.pdfID34)).filter(Boolean).map(p=>({id:p.id,title:p.title,sha256:p.sha256,documentID:p.documentID,pageCount:p.pageCount}))});}
function cvSourceState36(r){let sources;try{sources=JSON.parse(r.cvSources36)}catch{return'来源快照待检查'}const now=sources.map(s=>find('outcomes36',s.id));if(now.some(x=>!x))return'来源成果已缺失，保留原履历草稿';return stableValue(now.map(outcomePublic36))===r.basis36?'来源与生成时一致':'成果信息已有变化，原履历草稿保持';}
