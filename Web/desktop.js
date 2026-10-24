'use strict';
const scholarStorage = {
 getItem(key) { return key === 'shixu-v1' ? window.KongScholarDesktop.initialData : null; },
 setItem(key,value) {
  if(key!=='shixu-v1')throw Error('未知数据键');
  const result=window.prompt('KONGSCHOLAR_WRITE',value);
  if(result!=='ok')throw Error(result||'数据文件未写入');
  // Keep the startup snapshot current for error recovery exports in this session.
  this.currentData=value;
 }
};
const originalGetItem=scholarStorage.getItem.bind(scholarStorage);
scholarStorage.getItem=function(key){return this.currentData===undefined?originalGetItem(key):this.currentData};
function nativeDownload(name,text,type){
 const result=window.prompt('KONGSCHOLAR_EXPORT',JSON.stringify({name,text,type}));
 if(result==='saved')return true;
 if(result&&result.startsWith('error:'))alert(result.slice(6));
 return false;
}
function nativeImportBackup(){
 if(document.querySelector('dialog').open)return;
 const result=window.prompt('KONGSCHOLAR_IMPORT','');
 if(!result)return;
 try{const file=JSON.parse(result);previewRestore({name:file.name,size:file.size,text:async()=>file.text})}
 catch{alert('无法读取所选备份，请选择有效的 JSON 文件。')}
}
function desktopRefresh(){
 const file=document.querySelector('#backupFile');
 if(file&&file.tagName==='INPUT'){
  const button=document.createElement('button');button.id='backupFile';button.type='button';button.textContent='选择 JSON 备份…';
  file.replaceWith(button);button.onclick=nativeImportBackup;
 }
}
