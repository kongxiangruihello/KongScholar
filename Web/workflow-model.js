'use strict';
const scholarlyClone=x=>JSON.parse(JSON.stringify(x));
function stableValue(x){if(x===undefined)return 'undefined';if(x===null||typeof x!=='object')return JSON.stringify(x);if(Array.isArray(x))return '['+x.map(stableValue).join(',')+']';return '{'+Object.keys(x).sort().map(k=>JSON.stringify(k)+':'+stableValue(x[k])).join(',')+'}'}
const scholarlyEqual=(a,b)=>stableValue(a)===stableValue(b);
function safeTree(x,depth=0){if(depth>30)throw Error('记录嵌套过深');if(x&&typeof x==='object')for(const k of Object.keys(x)){if(['__proto__','prototype','constructor'].includes(k))throw Error('记录含无效字段');safeTree(x[k],depth+1)}}
function validateWriting(w){
 if(!w||typeof w!=='object'||typeof w.body!=='string'||!Array.isArray(w.citations)||w.citations.length>10000)throw Error('章节正文或脚注格式不正确');
 const ids=new Set();for(const c of w.citations){if(!c||typeof c.id!=='string'||!/^ks-[a-zA-Z0-9-]+$/.test(c.id)||ids.has(c.id)||!['sourceID','quote','citation','signature','state'].every(k=>typeof c[k]==='string'))throw Error('章节脚注格式不正确');ids.add(c.id)}safeTree(w);return w;
}
function validateImportHistory(value){
 if(value===undefined)return [];if(!Array.isArray(value))throw Error('导入历史格式不正确');const ids=new Set();
 for(const b of value){if(!b||typeof b.id!=='string'||!b.id||ids.has(b.id)||typeof b.name!=='string'||typeof b.at!=='string'||!Array.isArray(b.entries))throw Error('导入批次格式不正确');ids.add(b.id);const sourceIDs=new Set();for(const e of b.entries){if(!e||typeof e.id!=='string'||sourceIDs.has(e.id)||!e.after||e.after.id!==e.id||typeof e.after.title!=='string'||(e.before!==null&&(!e.before||e.before.id!==e.id||typeof e.before.title!=='string')))throw Error('历史快照格式不正确');sourceIDs.add(e.id)}safeTree(b)}return scholarlyClone(value);
}
function importFieldDiff(before,after,path=[]){
 if(scholarlyEqual(before,after))return [];
 if(before&&after&&typeof before==='object'&&typeof after==='object'&&!Array.isArray(before)&&!Array.isArray(after))return [...new Set([...Object.keys(before),...Object.keys(after)])].filter(k=>k!=='updated').flatMap(k=>importFieldDiff(before[k],after[k],[...path,k]));
 return [{path,before:before===undefined?{exists:false}:{exists:true,value:before},after:after===undefined?{exists:false}:{exists:true,value:after}}];
}
function readHistoryPath(obj,path){for(const k of path){if(!obj||!Object.hasOwn(obj,k))return {exists:false};obj=obj[k]}return {exists:true,value:obj}}
function writeHistoryPath(obj,path,snapshot){let target=obj;for(const k of path.slice(0,-1)){if(!target[k]||typeof target[k]!=='object')target[k]={};target=target[k]}if(snapshot.exists)target[path.at(-1)]=scholarlyClone(snapshot.value);else delete target[path.at(-1)]}
const citationTemplateDefaults={book:'{author}：《{title}》，{edition}，{year}，{pageLabel}。',journal:'{author}：《{title}》，《{journal}》{year}，{issue}，{pageLabel}。',archive:'{author}：《{title}》，{project}，{year}，{pageLabel}。'};
function validateTemplates(value){if(value===undefined)return {...citationTemplateDefaults};if(!value||typeof value!=='object')throw Error('引注模板格式不正确');const out={};for(const k of Object.keys(citationTemplateDefaults)){if(typeof value[k]!=='string'||!value[k].trim()||value[k].length>2000)throw Error('引注模板需填写且不超过 2000 字');out[k]=value[k]}return out}
function validateVersions(ch){if(ch.versions===undefined)return;if(!Array.isArray(ch.versions))throw Error('章节版本格式不正确');const ids=new Set();for(const v of ch.versions){if(!v||typeof v.id!=='string'||ids.has(v.id)||!['name','at','title'].every(k=>typeof v[k]==='string'))throw Error('章节版本记录无效');ids.add(v.id);validateWriting(v.writing)}safeTree(ch.versions)}
