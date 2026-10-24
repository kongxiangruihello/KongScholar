const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),{webcrypto}=require('node:crypto');
const code=['Web/workflow-model.js','Web/projects-model.js','Web/rhythm-model.js','Web/discovery-model.js','Web/progress-model.js','Web/revision-model.js','Web/desktop.js','Web/app.js','Web/folio.js','Web/references.js','Web/workflow.js','Web/publication.js','Web/reliability.js','Web/research.js','Web/projects.js','Web/rhythm.js','Web/discovery.js','Web/studio.js'].map(p=>fs.readFileSync(p,'utf8')).join('\n');
function setup(){const nodes=new Map();let disk=null,fail=false;const get=s=>{if(!nodes.has(s))nodes.set(s,{value:'',innerHTML:'',textContent:'',style:{},checked:true,tagName:'',classList:{toggle(){}},querySelectorAll:()=>[],querySelector:get,showModal(){this.open=true},close(){this.open=false},prepend(){}});return nodes.get(s)};const ctx={document:{querySelector:get,querySelectorAll:()=>[],createElement:()=>({innerHTML:''})},window:{KongScholarDesktop:{initialData:null},prompt:(action,value)=>{if(action==='KONGSCHOLAR_WRITE'){if(fail)return 'error:quota';disk=value;return 'ok'}return null}},crypto:webcrypto,TextEncoder,Uint8Array,FormData,console,setTimeout(){},clearTimeout(){},alert(){},confirm:()=>true};vm.createContext(ctx);vm.runInContext(code,ctx);return {run:s=>vm.runInContext(s,ctx),get,put:(name,value)=>ctx[name]=value,fail:()=>fail=true,disk:()=>disk}}







const r=setup();
assert.equal(r.run('studioGroups.length'),6);
assert(r.run("nav.every(n=>studioGroups.some(g=>g[1].includes(n[0])))"));
r.run("toggleStudioFavorite('sources');round=normalize(JSON.parse(JSON.stringify(data)))");assert(r.run("round.meta.uiFavorites.includes('sources')"));
r.run("data.sources=Array.from({length:120},(_,i)=>({id:'s'+i,title:'资料'+i,body:i===119?'稀有词':'正文',projectIDs:[]}));page='sources';render()");
assert.equal((r.get('#results').innerHTML.match(/查看完整资料/g)||[]).length,40);
r.get('#search').value='稀有词';r.get('#search').oninput();assert(r.get('#results').innerHTML.includes('资料119'));assert(!r.get('#results').innerHTML.includes('资料118'));
r.run("homeCalls=0;studioViews.home=()=>homeCalls++;page='searchAll';render()");assert.equal(r.run('homeCalls'),0);
r.run("data.sources=[{id:'s',title:'<script>资料</script>',body:'原文',interpretation:'我的解释',citation:'人工出处',projectIDs:[]}];openMaterial('sources','s')");assert(r.get('#app').innerHTML.includes('我的解释'));assert(!r.get('#app').innerHTML.includes('<script>资料'));
r.run("data.meta.lastWritingChapter={'project-heyiweishi':'c'};data.chapters=[{id:'c',title:'章节',projectIDs:['project-heyiweishi'],resume:{where:'旧位置',next:'下段',gap:'缺口',sourceIds:[]}}];data.meta.activeProjectID='project-heyiweishi';page='projectDesk';render()");
assert(r.run("normalize(JSON.parse(JSON.stringify(data))).meta.lastWritingChapter['project-heyiweishi']==='c'"));
r.run("beforePage=page;writerFlush=()=>false;go('home')");assert.equal(r.run('page'),r.run('beforePage'));
const f=setup();f.fail();assert.equal(f.run("toggleStudioFavorite('sources')"),false);assert.equal(f.run('studioFavorites().length'),0);assert(f.get('#status').textContent.includes('保存失败'));
console.log('通过：五栏与工具导航覆盖全部入口、常用页面与最近章节备份往返、120条列表分批显示及全范围检索、直接路由不绘制首页、资料详情转义与解释保留、失败禁止离开与偏好回滚。');
