const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),{webcrypto}=require('node:crypto');
const code=['Web/workflow-model.js','Web/projects-model.js','Web/rhythm-model.js','Web/discovery-model.js','Web/progress-model.js','Web/revision-model.js','Web/desktop.js','Web/app.js','Web/folio.js','Web/references.js','Web/workflow.js','Web/publication.js','Web/reliability.js','Web/research.js','Web/projects.js','Web/rhythm.js','Web/discovery.js','Web/studio.js','Web/progress.js'].map(p=>fs.readFileSync(p,'utf8')).join('\n');
function setup(){const nodes=new Map();let disk=null,fail=false;const get=s=>{if(!nodes.has(s))nodes.set(s,{value:'',innerHTML:'',textContent:'',style:{},checked:true,tagName:'',classList:{toggle(){}},querySelectorAll:()=>[],querySelector:get,showModal(){this.open=true},close(){this.open=false},prepend(){},append(){}});return nodes.get(s)};const ctx={document:{querySelector:get,querySelectorAll:()=>[],createElement:()=>({innerHTML:''})},window:{KongScholarDesktop:{initialData:null},prompt:(action,value)=>{if(action==='KONGSCHOLAR_WRITE'){if(fail)return 'error:quota';disk=value;return 'ok'}return null}},crypto:webcrypto,TextEncoder,Uint8Array,FormData,console,setTimeout(){},clearTimeout(){},alert(){},confirm:()=>true};vm.createContext(ctx);vm.runInContext(code,ctx);return {run:s=>vm.runInContext(s,ctx),get,put:(name,value)=>ctx[name]=value,fail:()=>fail=true,disk:()=>disk}}








const r=setup();
r.run("pid='project-heyiweishi';data.meta.activeProjectID=pid;data.chapters=['a','b','c','d'].map(id=>({id,title:'章节'+id,body:'本节问题'+id,projectIDs:[pid],writing:{body:'正文'+id+'[^ks-1]',citations:[{id:'ks-1',sourceID:'s',quote:'原文',citation:'保留手工注'+id,signature:'old',state:'待核对'}]},gaps:'待补材料'+id}));data.sources=[{id:'s',title:'共同史料',body:'同一原文',citation:'出处',projectIDs:[pid,'project-paper']},{id:'other',title:'另一摘录',body:'同一原文',projectIDs:[pid]}];data.arguments=[{id:'arg',title:'核心论点',chapter:'a',body:'解释过程',support:['s'],against:['missing'],counter:'不能推定影响',gaps:'补查反证',projectIDs:[pid]}];save()");
assert(r.run("reparentOutline(pid,'b','a')"));assert(r.run("reparentOutline(pid,'c','b')"));assert.equal(r.run("orderedOutline(pid).find(n=>n.chapterID==='c').number"),'1.1.1');
assert(r.run("moveOutline(pid,'a',1)"));assert.equal(r.run("orderedOutline(pid).map(n=>n.chapterID).join(',')"),'d,a,b,c');assert.equal(r.run("projectRecords('chapters').map(c=>c.id).join(',')"),'d,a,b,c');
r.run('before=stableValue(data)');assert.equal(r.run("reparentOutline(pid,'a','c')"),false);assert.equal(r.run('stableValue(data)'),r.run('before'));
assert(r.run("setOutlineStatus(pid,'b','修改中')"));assert.equal(r.run("normalize(JSON.parse(JSON.stringify(data))).projects.find(p=>p.id===pid).outline.find(n=>n.chapterID==='b').status"),'修改中');
assert.throws(()=>r.run("validateProjectOutline([{chapterID:'a',parentID:'missing'}])"));assert.throws(()=>r.run("validateProjectOutline([{chapterID:'a',parentID:''},{chapterID:'a',parentID:''}])"));
assert.equal(r.run("matrixRows(pid).find(n=>n.chapterID==='a').args[0].counter"),'不能推定影响');assert(r.run("matrixMarkdown(pid)").includes('关联史料已缺失'));
r.run("saveProjectUseNote('s',pid,'书稿解释','书稿限度');saveProjectUseNote('s','project-paper','论文解释','论文限度');preview=buildStagePackage(pid)");
assert.equal(r.run("data.sources[0].body"),'同一原文');assert.equal(r.run("projectUseNote('s','project-paper').body"),'论文解释');assert.equal(r.run("normalize(JSON.parse(JSON.stringify(data))).sources[0].projectUseNotes.length"),2);
assert(r.run("sourceProjectContexts('s').some(c=>c.projectID==='project-paper')"));assert(r.run("referringRecords('projects','project-paper').some(s=>s.includes('使用说明'))"));
assert.equal(r.run('preview.chapterCount'),4);assert.equal(r.run('preview.files.length'),7);assert(r.run("preview.files.find(f=>f.name==='06-本项目材料使用.md').text.includes('书稿解释')"));assert(!r.run("preview.files.find(f=>f.name==='06-本项目材料使用.md').text.includes('论文解释')"));
assert(r.run("preview.files.find(f=>f.name==='02-正文.md').text.includes('[^ks-c1-ks-1]: 保留手工注d')"));assert(r.run("preview.files.find(f=>f.name==='02-正文.md').text.includes('[^ks-c2-ks-1]: 保留手工注a')"));assert.equal(r.run('preview.manuscript.chapters[1].title'),'1 章节d');assert.equal(r.run('preview.manuscript.chapters[3].title'),'2.1 章节b');assert.equal(r.run('preview.manuscript.chapters[2].citations[0].text.startsWith("保留手工注a")'),true);
r.run("data.projects.find(p=>p.id===pid).target='后来修改'");assert.throws(()=>r.run('exportStagePackage(preview)'));
r.run("saveProjectUseNote('other',pid,'另一解释','另一限度');applyMerge(mergePlan('sources','s','other'))");assert(r.run("projectUseNote('s',pid).body.includes('另一解释')"));assert.equal(r.run("data.sources[0].body"),'同一原文');
r.run("data.sources[0].projectUseNotes.push({projectID:'missing-project',body:'待保留',counter:'',updated:''});round=normalize(JSON.parse(JSON.stringify(data)))");assert(r.run("missingAssociations().some(x=>x.detail.includes('使用说明'))"));
const f=setup();f.run("data.sources=[{id:'s',title:'史料',body:'原文'}];allocationBuffer={sourceID:'s',projectID:'project-paper',body:'未写入',counter:'',dirty:true};page='allocation'");f.fail();assert.equal(f.run("go('home')"),false);assert.equal(f.run('page'),'allocation');assert.equal(f.run('allocationBuffer.dirty'),true);assert.equal(f.run('data.sources[0].projectUseNotes'),undefined);
r.run("preview=buildStagePackage(pid);window.prompt=(action)=>action==='KONGSCHOLAR_STAGE_EXPORT'?'saved':null;exportStagePackage(preview)");assert(r.run('!!preview.exportedAt'));r.run("openMaterial('sources','s')");
fs.mkdirSync('/private/tmp/KongScholar21-StageQA',{recursive:true});fs.writeFileSync('/private/tmp/KongScholar21-StageQA/payload.json',r.run('JSON.stringify({title:preview.title,files:preview.files,manuscript:preview.manuscript})'));
console.log('通过：目录嵌套与整支移动、循环拒绝及回滚、同项目排序与独立状态、证据缺失提示、项目解释隔离与备份、合并保留说明、成果包顺序与脚注编号、预览过期保护、保存失败保留缓冲并阻止离开。');
