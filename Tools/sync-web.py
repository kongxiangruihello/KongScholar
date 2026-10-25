from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
source=root.parent/'sites'/'shixu'/'dist'
if not (source/'app.js').exists():
    if all((root/'Web'/name).exists() for name in ['index.html','app.js','style.css','desktop.js']):
        print('使用归档内已生成的 Web 资源')
        raise SystemExit(0)
    raise SystemExit('缺少界面资源')
for name in ['index.html','style.css','app.js']:
    text=(source/name).read_text().replace('kongscholar','KongScholar')
    if name=='index.html':
        text=text.replace('<link rel="stylesheet" href="style.css">','<link rel="stylesheet" href="style.css"><link rel="stylesheet" href="folio.css"><link rel="stylesheet" href="neutral.css">')
        text=text.replace('<script src="app.js"></script>','<script src="workflow-model.js"></script><script src="projects-model.js"></script><script src="rhythm-model.js"></script><script src="discovery-model.js"></script><script src="progress-model.js"></script><script src="revision-model.js"></script><script src="depth-model.js"></script><script src="advanced-model.js"></script><script src="research-model.js"></script><script src="personal-model.js"></script><script src="stability-model.js"></script><script src="material-model28.js"></script><script src="finish-model29.js"></script><script src="continuity-model30.js"></script><script src="studio-model31.js"></script><script src="review-model32.js"></script><script src="desktop.js"></script><script src="app.js"></script><script src="folio.js"></script><script src="references.js"></script><script src="workflow.js"></script><script src="publication.js"></script><script src="reliability.js"></script><script src="research.js"></script><script src="projects.js"></script><script src="rhythm.js"></script><script src="discovery.js"></script><script src="studio.js"></script><script src="progress.js"></script><script src="revision.js"></script><script src="depth.js"></script><script src="manuscripts.js"></script><script src="recovery.js"></script><script src="sessions.js"></script><script src="advanced.js"></script><script src="exchange.js"></script><script src="scholarship.js"></script><script src="analysis24.js"></script><script src="teaching24.js"></script><script src="workbench25.js"></script><script src="evidence25.js"></script><script src="writing25.js"></script><script src="continuity25.js"></script><script src="workspace26.js"></script><script src="forms26.js"></script><script src="writing26.js"></script><script src="stability27.js"></script><script src="drafts27.js"></script><script src="performance27.js"></script><script src="materials28.js"></script><script src="writing29.js"></script><script src="teaching29.js"></script><script src="continuity30.js"></script><script src="studio31.js"></script><script src="review32.js"></script>')
        text=text.replace('<label class="import">恢复备份<input id="restore" type="file" accept=".json" hidden></label>','<button class="import" id="restoreNative" onclick="nativeImportBackup()">导入备份…</button><input id="restore" type="file" hidden>')
        text=text.replace('◌ 仅本人访问 <b>本机保存</b>', '◌ 离线 Mac 版 <b>本机文件保存</b>')
        text=text.replace('内容保存在当前浏览器，建议定期备份','内容保存在此 Mac，建议定期导出备份')
    if name=='app.js':
        text=text.replace('localStorage.', 'scholarStorage.')
        start=text.index('function download('); end=text.index('\nconst filename=',start)
        text=text[:start]+"function download(name,text,type='text/markdown;charset=utf-8'){return nativeDownload(name,text,type)}"+text[end:]
        text=text.replace('bind();backupNotice()}', 'bind();backupNotice();desktopRefresh()}')
        text=text.replace("if($('#backupFile'))", "if($('#backupFile'))")
        text=text.replace("$('#backup').onclick=exportBackup;", "$('#backup').onclick=exportBackup;")
        text=text.replace("download('KongScholar-备份-", "if(download('KongScholar-备份-")
        text=text.replace("JSON.stringify(d,null,2),'application/json');data.meta.lastBackupAt", "JSON.stringify(d,null,2),'application/json')===false)return toast('已取消导出');data.meta.lastBackupAt")
        text=text.replace("download('KongScholar-恢复前原始数据.json',scholarStorage.getItem(key)||'{}','application/json')", "if(download('KongScholar-恢复前原始数据.json',scholarStorage.getItem(key)||'{}','application/json')===false)return")
        text=text.replace("else download('KongScholar-恢复前快照.json',JSON.stringify(data,null,2),'application/json');", "else if(download('KongScholar-恢复前快照.json',JSON.stringify(data,null,2),'application/json')===false)return;")
        text=text.replace('已发起备份下载，请确认文件已保存','备份文件已保存')
        text=text.replace('恢复完成，恢复前快照已发起下载','恢复完成，恢复前快照已保存')
        text=text.replace('下载恢复前快照并恢复','保存恢复前快照并恢复').replace('恢复前会下载当前快照','恢复前会让您保存当前快照').replace('先下载当前数据的恢复前快照','先保存当前数据的恢复前快照')
        text=text.replace('本版仍在当前浏览器保存记录','本版在此 Mac 的独立数据文件中保存记录')
        text=text.replace('记录保存在当前浏览器','记录保存在此 Mac').replace('上次发起备份下载','上次成功导出备份')
        text=text.replace('。请自行确认文件下载成功。','。').replace('下载完整 JSON 备份','导出完整 JSON 备份…').replace('下载备份','导出备份…')
        text=text.replace('浏览器保存失败。当前修改只在本次页面内，请立即导出备份，勿关闭页面。','本机数据文件保存失败。当前修改尚未写入磁盘，请立即导出备份，勿关闭应用。')
        text=text.replace('修改尚未写入浏览器，请导出备份','修改尚未写入文件，请导出备份')
        text=text.replace('原有数据未能读取，已停止写入以保护原记录。请先导出原始数据并在备份中心恢复。','原有数据未能读取，已停止写入以保护原记录。请先导出原始数据并在备份中心恢复。')
    if name=='app.js':
        text=text.replace("let data=emptyData(),loadError=false","let loadErrorReason27='';let data=emptyData(),loadError=false").replace('catch{loadError=true}',"catch(e){loadError=true;loadErrorReason27=e.message||'资料读取未通过'}")
        text=text.replace('25*1024*1024','256*1024*1024').replace('25 MB','256 MB')
        text=text.replace('function normalize(raw){', "function normalize(raw){if(raw?._archiveStorage||raw?._archiveReadError)throw Error('这是拆分存储索引或归档读取失败，请使用完整JSON备份恢复');")
        text=text.replace("const types={questions:", "const types={readings:'阅读计划',authorities:'名称规范',provenances:'来源与转引链',freezes:'整稿冻结版',deliveries:'交付历史',feedback:'同行意见',inbox:'资料收件箱',reviews:'项目回顾',milestones:'项目里程碑',projects:'学术项目',concepts:'历史概念卡',textpairs:'文本与回应对读',seminars:'史料研读课',tasks:'研究任务',responses:'人物与文本回应',references:'文献档案',questions:")
        text=text.replace("const fields=schema;", """schema.references=[['title','文献 / 篇名'],['author','署名作者'],['journal','刊物 / 丛书'],['year','出版年 / 原纪年'],['issue','卷期'],['edition','版本 / 出版信息'],['translator','译者 / 编译者'],['attribution','作者归属：证据、判断与可信程度','area'],['project','原项目 / 馆藏 / 档号'],['body','文献说明与待核事项','area']];
 schema.projects=[['title','项目名称'],['projectKind','项目类型','projectKind'],['stage','当前阶段'],['deadline','截止日期（可空）','date'],['target','近期目标','area'],['next','下一步行动','area'],['body','项目说明','area']];
 schema.concepts=[['title','概念卡标题'],['term','称谓 / 概念'],['actor','使用者'],['historicalDate','公历年代（可空）'],['dateNote','原纪年 / 日期依据'],['quote','具体用语与原文','area'],['body','语境与在此处的含义','area'],['counter','其他解释 / 与其他用例的差别','area'],['sourceIds','出处史料','sources'],['chapter','关联章节','chapter']];
 schema.textpairs=[['title','对读标题'],['left','林乐知文本史料','source'],['responseID','士人回应记录','responseLink'],['wording','措辞保留、替换与省略','area'],['body','双方共同讨论的问题','area'],['counter','语境差异、解释限度与待查事项','area'],['chapter','关联章节','chapter']];
 schema.seminars=[['title','课程 / 课次'],['audience','授课对象'],['duration','课时 / 时长'],['body','教学目标与背景说明','area'],['sourceIds','研读材料（保存后可调整顺序）','sources'],['questions','讨论问题（每行一题）','area'],['sequence','课堂流程与阅读指引','area'],['assignment','课后任务','area'],['teacherNotes','教师提示与讨论要点（学生版不包含）','area']];
 schema.tasks=[['title','任务名称'],['body','待处理事项','area'],['progress','进度（待办 / 进行中 / 已完成）'],['chapter','关联章节','chapter'],['sourceIds','关联史料','sources'],['responseID','关联回应编号']];
 schema.responses=[['title','回应记录标题'],['actor','发言者 / 回应者'],['target','回应对象 / 文本'],['historicalDate','公历日期（YYYY / YYYY-MM / YYYY-MM-DD，可空）'],['venue','发表处 / 交往场合'],['responseKind','回应类型','responseKind'],['terms','身份称谓 / 关键词'],['body','回应内容与解释','area'],['sourceIds','证据史料','sources'],['counter','证据限度 / 竞争解释','area']];
 schema.references.push(['referenceKind','文献类型','referenceKind']);
 schema.sources.push(['referenceID','所属文献','reference'],['physicalPage','PDF 物理页码（手工来源可填）'],['verificationNote','核对依据 / 差异记录','area']);
 schema.readings=[['title','阅读对象 / 篇名'],['referenceID','所属文献','reference'],['sourceID','KongFolio定位史料','sourceOptional'],['targetPages','计划阅读范围（页码或卷期）'],['readPages','已读范围'],['nextPage','下次开始的PDF物理页码'],['readingStatus','阅读状态','readingStatus'],['body','阅读疑问与下一步','area']];
 schema.authorities=[['title','规范名称'],['entityKind','名称类型','entityKind'],['aliases','别名 / 旧称（每行一项）','area'],['foreignNames','外文名（每行一项）','area'],['body','考证依据与辨析','area'],['sourceIds','考证史料','sources']];
 schema.provenances=[['title','来源关系标题'],['left','上游史料','source'],['right','下游史料','source'],['relationKind','关系类型','provenanceKind'],['body','原刊、译载、节录或转引的依据','area'],['counter','不确定之处 / 文本差异','area']];
 schema.freezes=[['title','冻结稿名称']];schema.deliveries=[['title','稿次名称'],['actor','接收对象（仅记录，不发送）'],['body','交付备注','area']];
 schema.questions.push(['_evolutionReason','修改问题的理由（修改已有问题时填写）','area'],['_evolutionSources','促成变化的史料','sources']);
 for(const t of ['sources','events','responses','concepts'])schema[t].push(['datePrecision','日期精度','datePrecision'],['dateStart','起始公历年 / 年月 / 年月日'],['dateEnd','结束公历年 / 年月 / 年月日'],['dateBasis','范围、换算或推定依据（原纪年可填入日期说明）','area']);
 schema.feedback=[['title','意见标题'],['reviewer','意见人'],['reviewedAt','讨论日期','date'],['roundLabel','对应稿次 / 讨论场合'],['feedbackKind','意见分类','feedbackKind'],['body','意见原话（与作者判断分开）','area'],['counter','您的判断','area'],['decision','处理决定','feedbackDecision'],['reason','接受、暂缓或不采纳的理由','area'],['chapter','对应章节','chapter'],['argumentID','对应论点','argumentRef'],['versionID','对应章节版本','feedbackVersion'],['sourceIds','对应史料','sources'],['feedbackStatus','回应状态','feedbackStatus'],['resolution','对外修改说明 / 回应','area']];
 schema.inbox=[['title','收件标题'],['body','临时摘录 / 想法','area'],['citation','原始出处'],['note','来源批注 / 临时备注','area'],['actor','人物 / 使用者'],['historicalDate','公历年代（可空）'],['inboxState','整理状态','inboxState']];
 schema.reviews=[['title','回顾标题'],['periodStart','开始日期','date'],['periodEnd','结束日期','date'],['summary','已有记录摘要（生成时快照，可编辑）','area'],['body','本周判断与收获','area'],['counter','尚未解决的问题','area'],['next','下周准备推进什么','area']];
 schema.milestones=[['title','节点名称'],['targetDate','目标日期','date'],['milestoneProgress','节点进度','milestoneProgress'],['body','完成标准 / 说明','area'],['completedDate','完成日期','date'],['completionNote','完成说明','area']];
 schema.feedback.push(['freezeID','对应整稿冻结版','freezeRef']);
 schema.tasks.push(['feedbackID','关联同行意见','feedbackRef'],['completionNote','修改完成说明（修订任务完成时填写）','area']);
 schema.tasks.push(['milestoneID','关联里程碑','milestoneRef']);
 schema.tasks.push(['workKind','工作类型','workKind'],['deadline','截止日期','date'],['scheduledDate','安排日期','date']);
 configureAdvancedSchema(types,schema);configureResearchSchema(types,schema);configureMaterial28(types,schema);configureFinish29(types,schema);if(typeof configureStudio31==='function')configureStudio31(types,schema);if(typeof configureReview32==='function')configureReview32(types,schema);\n for(const t of Object.keys(types))if(t!=='projects')schema[t].push(['projectIDs','项目归属（可多选，共享资料无需重复录入）','projectLinks']);
 const fields=schema;""")
        text=text.replace("sub={questions:", "sub={responses:'区分接触、转述、赞同、质疑与实践变化，每条判断关联证据。',references:'统一保存作者、版本、卷期和作者归属依据，再关联具体摘录。',questions:")
        text=text.replace("x.gaps,x.status].join", "x.gaps,x.status,x.author,x.journal,x.year,x.issue,x.edition,x.translator,x.attribution,x.project].join")
    if name=='app.js':
        text=text.replace("meta:{schemaVersion:2}}}", "meta:{schemaVersion:2},importHistory:[]}}")
        text=text.replace("out.meta={schemaVersion:2", "out.importHistory=validateImportHistory(raw.importHistory);out.settings.citationTemplates=validateTemplates(raw.settings?.citationTemplates);for(const ch of out.chapters){if(ch.writing!==undefined)validateWriting(ch.writing);validateVersions(ch);}out.meta={schemaVersion:2")
    if name=='app.js':
        text=text.replace('out.meta.schemaVersion=2;return out;', 'out.meta.schemaVersion=2;revisionRawSettings=raw.settings||{};const result30=normalizeFinish29(normalizeMaterial28(normalizeStability27(normalizePersonal26(normalizeResearch25(normalizeAdvanced(normalizeDepth(normalizeRevision(normalizeProjects(out,raw)))))))));if(typeof normalizeContinuity30===\'function\')normalizeContinuity30(result30);if(typeof normalizeStudio31===\'function\')normalizeStudio31(result30);return typeof normalizeReview32===\'function\'?normalizeReview32(result30):result30;')
        text=text.replace("if(kind==='sources')", "if(['sources','projectLinks'].includes(kind))")
        text=text.replace("const rows=data[t].filter", "const rows=projectRecords(t).filter")
        text=text.replace("kind==='source'?sourceText(v)", "kind==='projectLinks'?v.map(id=>label('projects',id)).join('、'):kind==='source'?sourceText(v)")
        for fn in ['chapters','comparisons','timeline','chronologicalRows']:
            lines=text.splitlines()
            for i,line in enumerate(lines):
                if line.startswith('function '+fn+'('):
                    for collection in ['chapters','arguments','comparisons','events','sources']:
                        line=line.replace('data.'+collection, "projectRecords('"+collection+"')")
                    lines[i]=line
            text='\n'.join(lines)+'\n'
    (root/'Web'/name).write_text(text)
with (root/'Web'/'style.css').open('a') as out:
    out.write('\nbody{overscroll-behavior:none}button{-webkit-user-select:none;user-select:none}.import{border:0}header{user-select:none}input,textarea{-webkit-user-select:text;user-select:text}\n')
