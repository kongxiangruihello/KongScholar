#!/usr/bin/env python3
"""Prepare an offline source-only queue or publish it with gh's existing login.
No application data or credentials are read. Never force-pushes.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys, tempfile
from datetime import datetime, timezone

ROOT=Path(__file__).resolve().parents[1]
REPO='kongxiangruihello/KongScholar'

def stamp(): return datetime.now(timezone.utc).isoformat()
def canonical(value): return json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
def manifest():
    result=subprocess.run([sys.executable,str(ROOT/'Tools/prepare-source-sync.py')],cwd=ROOT,capture_output=True,check=True)
    entries=json.loads(result.stdout)
    for e in entries:
        p=e['path']
        if not (p in ['Package.swift','README.md','.gitignore'] or p.startswith(('Sources/','Tests/','Tools/','Web/','Documentation/'))): raise ValueError('源码路径超出白名单')
        if '..' in Path(p).parts or Path(p).is_absolute() or not isinstance(e['content'],str): raise ValueError('源码条目无效')
    return entries

def blob_hash(text):
    b=text.encode();return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()

def api(method,path,payload=None):
    args=['gh','api','--method',method,path]
    if payload is None:
        r=subprocess.run(args,capture_output=True,timeout=90)
    else:
        with tempfile.TemporaryFile() as f:
            f.write(canonical(payload));f.seek(0);r=subprocess.run(args+['--input','-'],stdin=f,capture_output=True,timeout=90)
    if r.returncode:raise RuntimeError('GitHub请求未完成；未获得可核验回执')
    return json.loads(r.stdout)

def verify(entries,tree):
    if tree.get('truncated'):raise RuntimeError('远端源码树不完整，不能确认发布成功')
    rows={r['path']:r for r in tree['tree']}
    if not all(rows.get(e['path'],{}).get('sha')==blob_hash(e['content']) and rows[e['path']].get('mode')==e['mode'] for e in entries):raise RuntimeError('远端源码内容与本机清单不一致')

def publish(entries):
    auth=subprocess.run(['gh','auth','status'],capture_output=True,timeout=20)
    if auth.returncode:raise RuntimeError('GitHub身份尚未登录，未发送源码')
    prefix='repos/'+REPO+'/git/'
    head=api('GET',prefix+'ref/heads/main')['object']['sha'];old=api('GET',prefix+'commits/'+head)
    remote=api('GET',prefix+'trees/'+old['tree']['sha']+'?recursive=1')
    try:verify(entries,remote);return head,old['tree']['sha']
    except RuntimeError:pass
    tree=api('POST',prefix+'trees',{'base_tree':old['tree']['sha'],'tree':entries})['sha']
    commit=api('POST',prefix+'commits',{'message':'Release KongScholar '+release_version()+' source and documentation','tree':tree,'parents':[head]})['sha']
    if api('GET',prefix+'ref/heads/main')['object']['sha']!=head:raise RuntimeError('发布期间远端分支有新提交，已停止更新；请重新核对再重试')
    api('PATCH',prefix+'refs/heads/main',{'sha':commit,'force':False})
    if api('GET',prefix+'ref/heads/main')['object']['sha']!=commit:raise RuntimeError('远端分支回读与发布提交不一致')
    verify(entries,api('GET',prefix+'trees/'+tree+'?recursive=1'))
    return commit,tree

def release_version():
    import re
    return re.search(r'VERSION="([0-9.]+)"',(ROOT/'Tools/build-mac.sh').read_text()).group(1)

def run(output,publish_now=False):
    entries=manifest();digest=hashlib.sha256(canonical(entries)).hexdigest()
    receipt={'format':'KongScholar-SourceRelease','version':1,'release':release_version(),'repository':REPO,'branch':'main','manifestSHA256':digest,'files':len(entries),'state':'pending','preparedAt':stamp(),'reason':'源码清单已生成；尚未提交GitHub。仅含APP源码、合成测试和版本说明。'}
    output=Path(output);output.parent.mkdir(parents=True,exist_ok=True)
    # Queue contents are source text, never research data.
    queue=output.with_name('source-queue.json');queue.write_bytes(canonical({'manifestSHA256':digest,'tree':entries}));queue.chmod(0o600)
    if publish_now:
        try:
            commit,tree=publish(entries);receipt.update(state='verified',commit=commit,tree=tree,verifiedAt=stamp(),reason='远端分支、提交和白名单逐文件内容已回读核验。')
        except (OSError,RuntimeError,subprocess.SubprocessError) as e:
            receipt.update(state='blocked',reason=str(e) if isinstance(e,RuntimeError) else '发布连接或本机工具不可用，远端状态尚未核验。')
    output.write_bytes(canonical(receipt));output.chmod(0o600)
    return receipt

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',required=True);p.add_argument('--publish',action='store_true');a=p.parse_args()
    r=run(a.output,a.publish);print(json.dumps({k:r[k] for k in ['release','state','files','reason']},ensure_ascii=False));sys.exit(1 if r['state']=='blocked' else 0)
