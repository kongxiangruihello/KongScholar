const fs=require('node:fs'),vm=require('node:vm'),{webcrypto}=require('node:crypto');
module.exports=function setup(initial=null,receipts=new Map()){
 const nodes=new Map(),calls=[];let disk=initial,fail=false,failAck=false,nativeResult='saved';
 const get=s=>{if(!nodes.has(s))nodes.set(s,{value:'',innerHTML:'',textContent:'',style:{},dataset:{},focus(){},setSelectionRange(a,b){this.selectionStart=a;this.selectionEnd=b},scrollTop:0,checked:false,tagName:'',classList:{toggle(){}},querySelectorAll:()=>[],querySelector:get,showModal(){this.open=true},close(){this.open=false},before(){},prepend(e){this.innerHTML=e.innerHTML+this.innerHTML},append(e){this.innerHTML+=e.innerHTML}});return nodes.get(s)};
 const journal=new Map(),ctx={document:{querySelector:get,querySelectorAll:()=>[],createElement:()=>get('created-'+Math.random())},window:{KongScholarDesktop:{initialData:initial},prompt:(action,value)=>{
  calls.push({action,value});if(action==='KONGSCHOLAR_WRITE'){if(fail)return'error:quota';disk=value;return'ok'}
  if(action==='KONGSCHOLAR_DRAFT_LIST')return JSON.stringify({drafts:[...journal.values()]});
  if(action==='KONGSCHOLAR_DRAFT_SAVE'){if(fail)return'error:quota';const v=JSON.parse(value);journal.set(v.key,v);return JSON.stringify({saved:true})}
  if(action==='KONGSCHOLAR_DRAFT_REMOVE'){journal.delete(JSON.parse(value).key);return JSON.stringify({removed:true})}
  if(action==='KONGSCHOLAR_OUTBOX_LIST30')return JSON.stringify({rows:[...receipts.values()]});
  if(action==='KONGSCHOLAR_OUTBOX_ACK30'){if(failAck)return'error:unavailable';receipts.delete(JSON.parse(value).token);return JSON.stringify({acknowledged:true})}
  if(['KONGSCHOLAR_WORD_EXPORT','KONGSCHOLAR_STAGE_EXPORT'].includes(action)){const v=JSON.parse(value);if(nativeResult==='saved'&&v.deliveryEntry30){const entry=v.deliveryEntry30;entry.deliveryRecord30.exportFile30={path:'/TEST-ONLY/TEST.docx',sha256:'a'.repeat(64),bytes:100,proof30:{items:[]}};receipts.set(entry.token,{state:'saved',entry,sha256:'a'.repeat(64),path:'/TEST-ONLY/TEST.docx'});return JSON.stringify({saved:true,entry30:entry})}return nativeResult}
  if(action==='KONGSCHOLAR_PROOF30')return JSON.stringify({sha256:'a'.repeat(64),items:[],missingNotes:0});return null;
 }},crypto:webcrypto,TextEncoder,Uint8Array,FormData:class{constructor(f){this.rows=f.rows||[]}entries(){return this.rows[Symbol.iterator]()}[Symbol.iterator](){return this.entries()}get(k){return this.rows.find(([key])=>key===k)?.[1]||''}getAll(k){return this.rows.filter(([key])=>key===k).map(([,v])=>v)}},console,setTimeout(){},clearTimeout(){},alert(){},confirm:()=>true};
 vm.createContext(ctx);const html=fs.readFileSync('Web/index.html','utf8');for(const match of html.matchAll(/<script src="([^"]+)"/g)){const p='Web/'+match[1];vm.runInContext(fs.readFileSync(p,'utf8'),ctx,{filename:p})}
 return{run:s=>vm.runInContext(s,ctx),get,put:(k,v)=>ctx[k]=v,calls,receipts,disk:()=>disk,journal,fail:v=>fail=v,failAck:v=>failAck=v,native:v=>nativeResult=v};
};
