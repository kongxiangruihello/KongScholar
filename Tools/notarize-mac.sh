#!/bin/bash
# Copies to a new output directory; requires credentials already stored in Keychain.
set -euo pipefail
if [ "$#" -ne 4 ]; then
  echo '用法：notarize-mac.sh 已构建.app Developer-ID证书标识 钥匙串公证配置名 新输出目录' >&2
  exit 2
fi
INPUT="$1"
IDENTITY="$2"
PROFILE="$3"
DEST="$4"
[ -d "$INPUT/Contents" ] || { echo '未找到完整APP' >&2; exit 1; }
[ ! -e "$DEST" ] || { echo '输出目录已存在，未覆盖' >&2; exit 1; }
security find-identity -v -p codesigning | /usr/bin/grep -F "\"$IDENTITY\"" >/dev/null || { echo '没有找到指定的有效Developer ID签名证书，未提交公证' >&2; exit 1; }
[[ "$IDENTITY" == 'Developer ID Application:'* ]] || { echo '须使用Developer ID Application证书' >&2; exit 1; }
# History probes the saved profile without extracting or printing credentials.
xcrun notarytool history --keychain-profile "$PROFILE" --output-format json >/dev/null || { echo '公证配置尚不可用，未签名或提交' >&2; exit 1; }
mkdir -p "$DEST"
APP="$DEST/KongScholar.app"
ditto "$INPUT" "$APP"
codesign --force --timestamp --options runtime --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --keepParent "$APP" "$DEST/notarization-upload.zip"
xcrun notarytool submit "$DEST/notarization-upload.zip" --keychain-profile "$PROFILE" --wait --output-format json > "$DEST/notarization-receipt.json"
/usr/bin/python3 - "$DEST/notarization-receipt.json" <<'PY'
import json,sys
if json.load(open(sys.argv[1])).get('status')!='Accepted':raise SystemExit('Apple尚未接受公证，未生成通过标识')
PY
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose "$APP"
ditto -c -k --keepParent "$APP" "$DEST/KongScholar-notarized.app.zip"
echo '签名、公证、票据与系统评估已通过；原本机签名包保留。'
