#!/usr/bin/env python3
"""Print a reviewable GitHub tree manifest containing only this app's source and docs."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
files=[root/'Package.swift',root/'README.md',root/'.gitignore']
for folder in ['Sources','Tests','Tools','Web']:
    files.extend(p for p in (root/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
for name in ['使用说明.html','folio-protocol.md','release-2.2.md','release-2.3.md','release-2.4.md','release-2.5.md','release-2.6.md','release-2.7.md','release-2.8.md','release-2.9.md','release-3.0.md','release-3.1.md','release-3.2.md','release-3.3.md','release-3.4.md','release-3.5.md','release-3.6.md','release-3.7.md']:
    p=root/'Documentation'/name
    if p.exists():files.append(p)
entries=[]
for p in sorted(set(files)):
    path=p.relative_to(root).as_posix()
    if p.is_symlink() or any(x.startswith('.') for x in p.relative_to(root).parts) and path!='.gitignore':
        continue
    if p.suffix in ['.zip','.dmg','.app','.json','.pdf','.docx','.pyc'] or p.name=='.DS_Store':
        continue
    text=p.read_text(encoding='utf-8')
    if re.search(r'gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{40,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',text):
        raise SystemExit('疑似凭证，已停止生成源码清单：'+path)
    entries.append({'path':path,'mode':'100755' if path in ['Tools/build-mac.sh','Tools/prepare-source-sync.py','Tools/publish-source.py','Tools/notarize-mac.sh'] else '100644','type':'blob','content':text})
print(json.dumps(entries,ensure_ascii=False))
