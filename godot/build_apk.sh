#!/bin/bash
# Builds the Android APK: Godot export, then add the native helper dex, align and sign.
set -e
cd "$(dirname "$0")"
SDK=${ANDROID_HOME:-/opt/android}
BT=$SDK/build-tools/34.0.0
JAR=$SDK/platforms/android-35/android.jar
OUT=build; mkdir -p $OUT/native/classes $OUT/native/dex
javac -source 8 -target 8 -bootclasspath $JAR -d $OUT/native/classes $(find android_native/src -name '*.java') 2>&1 | grep -v "warning" || true
$BT/d8 --release --min-api 21 --lib $JAR --output $OUT/native/dex $(find $OUT/native/classes -name '*.class')
godot --headless --path . --export-debug Android $OUT/raw.apk 2>&1 | grep -E "^ERROR|SCRIPT ERROR|Parse Error" || true
python3 - <<PY
import zipfile, shutil
src='$OUT/raw.apk'; dst='$OUT/unsigned.apk'
zin=zipfile.ZipFile(src)
zout=zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED)
for it in zin.infolist():
    if it.filename.startswith('META-INF/'): continue
    data=zin.read(it.filename)
    zi=zipfile.ZipInfo(it.filename, it.date_time); zi.compress_type=it.compress_type; zi.external_attr=it.external_attr
    zout.writestr(zi,data)
names=set(zin.namelist()); n=2
while 'classes%d.dex'%n in names: n+=1
zout.write('$OUT/native/dex/classes.dex','classes%d.dex'%n)
zout.close()
PY
$BT/zipalign -f -p 4 $OUT/unsigned.apk $OUT/aligned.apk
$BT/apksigner sign --ks /opt/gd/debug.keystore --ks-pass pass:android --ks-key-alias androiddebugkey --out $OUT/digivi.apk $OUT/aligned.apk
rm -f $OUT/raw.apk* $OUT/unsigned.apk $OUT/aligned.apk $OUT/digivi.apk.idsig
ls -la $OUT/digivi.apk
