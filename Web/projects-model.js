'use strict';
const defaultProjectID='project-heyiweishi';
function localDay(date=new Date()){return [date.getFullYear(),String(date.getMonth()+1).padStart(2,'0'),String(date.getDate()).padStart(2,'0')].join('-')}
function normalizeProjects(out,raw){
 const legacy=raw.meta?.projectSchema!==1;
 if(legacy){
  if(!out.projects.length)out.projects=[{id:defaultProjectID,title:out.profile.field||'何以为士：林乐知与晚清士大夫的重塑',projectKind:'书稿',stage:'进行中',target:'',next:'',body:'原有学术资料归入此项目，可按实际需要重新归属。'},{id:'project-book-two',title:'第二部书稿（待命名）',projectKind:'书稿',stage:'待规划'},{id:'project-paper',title:'论文（待命名）',projectKind:'论文',stage:'待规划'},{id:'project-other',title:'其他学术工作',projectKind:'综合',stage:'进行中'}];
  const primary=out.projects[0].id;
  for(const t of Object.keys(types))if(t!=='projects')for(const x of out[t])if(x.projectIDs===undefined)x.projectIDs=[primary];
 }
 for(const t of Object.keys(types))for(const x of out[t]){
  if(x.projectIDs!==undefined&&(!Array.isArray(x.projectIDs)||x.projectIDs.some(id=>typeof id!=='string'||!id)||new Set(x.projectIDs).size!==x.projectIDs.length))throw Error('项目归属格式不正确');
  if(t==='tasks'||t==='projects')for(const k of ['deadline','scheduledDate'])if(x[k]!==undefined&&(typeof x[k]!=='string'||(x[k]&&(!/^\d{4}-\d{2}-\d{2}$/.test(x[k])||!validDate(x[k])))))throw Error('任务或项目日期格式不正确');
 }
 const plan=raw.todayPlan;
 if(plan!==undefined&&(!plan||typeof plan.date!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(plan.date)||!validDate(plan.date)||!Array.isArray(plan.ids)||plan.ids.some(id=>typeof id!=='string')||new Set(plan.ids).size!==plan.ids.length))throw Error('今日安排格式不正确');
 out.todayPlan=plan?scholarlyClone(plan):{date:localDay(),ids:[]};out.meta.projectSchema=1;
 if(out.meta.activeProjectID&&!out.projects.some(p=>p.id===out.meta.activeProjectID))out.meta.activeProjectID='';return normalizeRhythm(out,raw);
}
function activeProject(){return data.meta.activeProjectID||''}
function projectIDsForLinks(x={}){if(Array.isArray(x.projectIDs))return [...x.projectIDs];const ids=new Set();for(const [type,key]of [['chapters','chapter'],['questions','question'],['responses','responseID']]){const item=data[type]?.find(r=>r.id===x[key]);for(const id of item?.projectIDs||[])ids.add(id)}if(!ids.size&&activeProject())ids.add(activeProject());return [...ids]}
function projectRecords(type,id=activeProject()){return !id||type==='projects'?data[type]:data[type].filter(x=>(x.projectIDs||[]).includes(id))}
function todayTasks(day=localDay()){const rows=data.tasks.filter(t=>t.scheduledDate===day),order=data.todayPlan?.date===day?data.todayPlan.ids:[];return rows.sort((a,b)=>{const ia=order.indexOf(a.id),ib=order.indexOf(b.id);return (ia<0?Number.MAX_SAFE_INTEGER:ia)-(ib<0?Number.MAX_SAFE_INTEGER:ib)})}
