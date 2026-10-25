#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/ModuleCache"
VERSION="3.5.0"
OUTPUT="${KONGSCHOLAR_BUILD_OUTPUT:-$ROOT/../outputs/KongScholar}"
mkdir -p "$OUTPUT"
FINAL_DMG="$OUTPUT/KongScholar-$VERSION-universal.dmg"
if [ -e "$FINAL_DMG" ]; then
    echo "产物已存在；请先选择新版本号，避免覆盖交付文件。" >&2
    exit 1
fi
WORK=$(mktemp -d /private/tmp/KongScholar-build.XXXXXX)
APP="$WORK/KongScholar.app"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
/usr/bin/python3 Tools/sync-web.py
for ARCH in arm64 x86_64; do
    swift build -c release --arch "$ARCH" --scratch-path .build --disable-sandbox --product KongScholar
    BIN_DIR=$(swift build -c release --arch "$ARCH" --scratch-path .build --disable-sandbox --show-bin-path)
    cp "$BIN_DIR/KongScholar" "$WORK/KongScholar-$ARCH"
done
lipo -create "$WORK/KongScholar-arm64" "$WORK/KongScholar-x86_64" -output "$APP/Contents/MacOS/KongScholar"
cp -R Web "$APP/Contents/Resources/Web"
cp Documentation/使用说明.html "$APP/Contents/Resources/使用说明.html"
/usr/bin/python3 Tools/publish-source.py --output "$APP/Contents/Resources/release-status.json"
if [ -n "${KONGSCHOLAR_SOURCE_RECEIPT:-}" ]; then
    /usr/bin/python3 - "$APP/Contents/Resources/release-status.json" "$KONGSCHOLAR_SOURCE_RECEIPT" <<'PYRECEIPT'
import json,sys
from pathlib import Path
a=Path(sys.argv[1]);base=json.loads(a.read_text());receipt=json.loads(Path(sys.argv[2]).read_text())
for key in ['format','version','release','repository','branch','manifestSHA256','files']:
    if receipt.get(key)!=base.get(key):raise SystemExit('源码回执与当前构建不一致，已停止')
if receipt.get('state') not in ['pending','blocked','verified']:raise SystemExit('回执状态无效')
if receipt['state']=='verified' and (len(receipt.get('commit',''))!=40 or len(receipt.get('tree',''))!=40):raise SystemExit('回执缺少核验提交')
a.write_text(json.dumps(receipt,ensure_ascii=False,sort_keys=True))
PYRECEIPT
fi
rm "$APP/Contents/Resources/source-queue.json"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>KongScholar</string>
<key>CFBundleDisplayName</key><string>KongScholar</string>
<key>CFBundleExecutable</key><string>KongScholar</string>
<key>CFBundleIdentifier</key><string>com.kongxiangrui.KongScholar</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>32</string>
<key>CFBundleURLTypes</key><array><dict><key>CFBundleURLName</key><string>KongFolio import</string><key>CFBundleURLSchemes</key><array><string>kongscholar</string></array></dict></array>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>© 2026 孔祥瑞</string>
</dict></plist>
PLIST
swiftc -module-cache-path "$CLANG_MODULE_CACHE_PATH" Tools/make-icon.swift -o "$WORK/make-icon"
"$WORK/make-icon" "$WORK/icon.png"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" "$WORK/icon.png" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE*2))
    sips -z "$DOUBLE" "$DOUBLE" "$WORK/icon.png" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
xattr -cr "$APP"
codesign --force --sign - --options runtime "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
plutil -lint "$APP/Contents/Info.plist"
mkdir -p "$WORK/dmg"
cp -R "$APP" "$WORK/dmg/"
cp Documentation/使用说明.html "$WORK/dmg/使用说明.html"
ln -s /Applications "$WORK/dmg/Applications"
hdiutil create -volname "KongScholar $VERSION" -srcfolder "$WORK/dmg" -format UDZO "$FINAL_DMG"
hdiutil verify "$FINAL_DMG"
cp -R "$APP" "$OUTPUT/KongScholar-$VERSION.app"
ditto -c -k --keepParent "$APP" "$OUTPUT/KongScholar-$VERSION-universal.app.zip"
echo "KongScholar 构建完成：$FINAL_DMG"
