const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),{webcrypto}=require('node:crypto');
const code=['Web/workflow-model.js','Web/projects-model.js','Web/rhythm-model.js','Web/discovery-model.js','Web/progress-model.js','Web/revision-model.js','Web/desktop.js','Web/app.js','Web/folio.js','Web/references.js','Web/workflow.js','Web/publication.js'].map(p=>fs.readFileSync(p,'utf8')).join('\n');
function setup(){const nodes=new Map();let disk=null,fail=false;const get=s=>{if(!nodes.has(s))nodes.set(s,{value:'',innerHTML:'',textContent:'',style:{},checked:true,tagName:'',classList:{toggle(){}},querySelectorAll:()=>[],querySelector:get,showModal(){this.open=true},close(){this.open=false},prepend(){}});return nodes.get(s)};const ctx={document:{querySelector:get,querySelectorAll:()=>[],createElement:()=>({innerHTML:''})},window:{KongScholarDesktop:{initialData:null},prompt:(action,value)=>{if(action==='KONGSCHOLAR_WRITE'){if(fail)return 'error:quota';disk=value;return 'ok'}return null}},crypto:webcrypto,TextEncoder,Uint8Array,FormData,console,setTimeout(){},clearTimeout(){},alert(){},confirm:()=>true};vm.createContext(ctx);vm.runInContext(code,ctx);return {run:s=>vm.runInContext(s,ctx),get,put:(name,value)=>ctx[name]=value,fail:()=>fail=true,disk:()=>disk}}

const r=setup();
r.run("data.references=[{id:'r',title:'测试篇名',author:'佚名',year:'1890',issue:'卷一'}];data.sources=[{id:'s',title:'测试史料',referenceID:'r',body:'测试摘录',printedPage:'三叶正面',physicalPage:'2',interpretation:'个人解释'}]");
assert.equal(r.run("citationState(data.sources[0])"),'待核对');
r.run("verifyCitation('s')");assert.equal(r.run("citationState(data.sources[0])"),'已核对');
r.run("data.sources[0].interpretation='改写个人解释'");assert.equal(r.run("citationState(data.sources[0])"),'已核对');
r.run("data.references[0].issue='卷二'");assert.equal(r.run("citationState(data.sources[0])"),'需复核');
r.run("verifyCitation('s');data.sources[0].printedPage='四叶'");assert.equal(r.run("citationState(data.sources[0])"),'需复核');
r.run("verifyCitation('s');data.sources[0].body='更新摘录'");assert.equal(r.run("citationState(data.sources[0])"),'需复核');
assert.equal(r.run("referringRecords('references','r').length"),1);
r.run("data.chapters=[{id:'ch',title:'第一章'}];data.arguments=[{id:'a',title:'判断',chapter:'ch',support:['s'],against:['s']}]");assert.equal(r.run("sourcesForChapter('ch').length"),1);
assert(r.run("citationReport(data.sources,'清单')").includes('PDF 物理页码：2'));
r.run("round=normalize(JSON.parse(JSON.stringify(data)))");assert.equal(r.run('round.references.length'),1);assert.equal(r.run('round.sources[0].verification.signature'),r.run('data.sources[0].verification.signature'));
r.run("delete round.references;old=normalize(round)");assert.equal(r.run('old.references.length'),0);
assert.throws(()=>r.run("normalize({...data,references:[{id:'r',title:'x',author:123}]})"));
const f=setup();f.run("data.sources=[{id:'s',title:'x',body:'q',printedPage:'1'}]");f.run("verifyCitation('s')");assert.equal(f.run('data.sources[0].verification'),undefined);
const fail=setup();fail.run("data.references=[{id:'r',title:'t',author:'a',year:'1',issue:'1'}];data.sources=[{id:'s',title:'s',referenceID:'r',body:'q',printedPage:'1'}]");fail.fail();fail.run("verifyCitation('s')");assert.equal(fail.run('data.sources[0].verification'),undefined);
console.log('通过：核对生命周期、解释独立保留、文献删除保护、章节去重、清单导出、旧备份、无效字段拒绝、失败回退');
