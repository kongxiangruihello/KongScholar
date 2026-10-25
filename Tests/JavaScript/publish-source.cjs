const cp=require('node:child_process'),assert=require('node:assert/strict');
const code=String.raw`
import importlib.util,json
from pathlib import Path
from unittest.mock import patch
s=importlib.util.spec_from_file_location('pub',Path('Tools/publish-source.py'));m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
entries=[{'path':'Web/test.js','mode':'100644','type':'blob','content':'TEST ONLY 中文'}]
valid={'tree':[{'path':'Web/test.js','mode':'100644','type':'blob','sha':m.blob_hash('TEST ONLY 中文')}]}
m.verify(entries,valid)
for invalid in [{'tree':[]},{'truncated':True,'tree':valid['tree']}]:
 try:m.verify(entries,invalid);raise AssertionError('Unverified receipt accepted')
 except RuntimeError:pass
with patch.object(m.subprocess,'run',return_value=type('R',(),{'returncode':1})()):
 try:m.publish(entries);raise AssertionError('Unauthenticated publish accepted')
 except RuntimeError as e:assert '未发送源码' in str(e)
# A concurrent remote change must never update the branch.
calls=[]
def api(method,path,payload=None):
 calls.append((method,path,payload))
 if path.endswith('ref/heads/main'):return {'object':{'sha':'a'*40 if len([c for c in calls if c[1].endswith('ref/heads/main')])==1 else 'd'*40}}
 if 'commits/' in path:return {'tree':{'sha':'b'*40}}
 if method=='GET' and 'trees/' in path:return {'tree':[]}
 if method=='POST':return {'sha':'c'*40}
 raise AssertionError('Branch was updated without a fresh-head check')
with patch.object(m.subprocess,'run',return_value=type('R',(),{'returncode':0})()),patch.object(m,'api',side_effect=api):
 try:m.publish(entries);raise AssertionError('Concurrent branch change accepted')
 except RuntimeError as e:assert '新提交' in str(e)
assert not any(c[0]=='PATCH' for c in calls)
print('Passed source publication: exact Git blob hashes, missing/truncated tree rejection, unauthenticated block, concurrent-head guard, no force update.')
`;
const r=cp.spawnSync('/usr/bin/python3',['-c',code],{encoding:'utf8'});if(r.status)throw Error(r.stderr||r.stdout);console.log(r.stdout.trim());
