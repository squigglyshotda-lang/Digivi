#!/bin/bash
# Builds the Android APK: Godot export, then add the native helper dex, align and sign.
set -e
cd "$(dirname "$0")"
SDK=${ANDROID_HOME:-/opt/android}
BT=$SDK/build-tools/34.0.0; BT35=$SDK/build-tools/35.0.1
JAR=$SDK/platforms/android-35/android.jar
KS=signing/debug.keystore; [ -f $KS ] || { mkdir -p signing; cp /opt/gd/debug.keystore $KS; }
OUT=build; rm -rf $OUT/native; mkdir -p $OUT/native/classes $OUT/native/dex
javac -g:none -source 8 -target 8 -bootclasspath $JAR -d $OUT/native/classes $(find android_native/src -name '*.java') 2>&1 | grep -v "warning" || true
$BT35/d8 --release --min-api 21 --lib $JAR --output $OUT/native/dex $(find $OUT/native/classes -name '*.class')
godot --headless --path . --export-debug Android $OUT/raw.apk 2>&1 | grep -E "^ERROR|SCRIPT ERROR|Parse Error" || true
# Add the background service and its permissions to the manifest (Godot's template cannot).
rm -rf $OUT/ap
java -jar ${APKTOOL:-/opt/gd/apktool.jar} d -s -f $OUT/raw.apk -o $OUT/ap >/dev/null 2>&1
rm -f $OUT/ap/res/values-anydpi-v26/mipmaps.xml; sed -i '/name="themed_icon"/d' $OUT/ap/res/values/public.xml
python3 - <<PY
p='$OUT/ap/AndroidManifest.xml'
s=open(p).read()
perms=['FOREGROUND_SERVICE','FOREGROUND_SERVICE_LOCATION','FOREGROUND_SERVICE_MICROPHONE','FOREGROUND_SERVICE_HEALTH','FOREGROUND_SERVICE_SPECIAL_USE','ACTIVITY_RECOGNITION','POST_NOTIFICATIONS','INTERNET','REQUEST_INSTALL_PACKAGES']
add=''.join('<uses-permission android:name="android.permission.%s"/>'%x for x in perms if 'android.permission.%s"'%x not in s)
s=s.replace('<application',add+'<application',1)
svc='<service android:name="com.pierrejoshua.digivi.DigiviService" android:exported="false" android:foregroundServiceType="location|microphone|health|specialUse"><property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" android:value="pet senses"/></service>'
prov='<provider android:name="com.pierrejoshua.digivi.Updater\$ApkProvider" android:authorities="com.pierrejoshua.digivi.apk" android:exported="false" android:grantUriPermissions="true"/>'
s=s.replace('</application>',svc+prov+'</application>',1)
open(p,'w').write(s)
PY
java -jar ${APKTOOL:-/opt/gd/apktool.jar} b $OUT/ap -o $OUT/raw2.apk >/dev/null 2>&1 || { echo "apktool build failed"; exit 1; }
mv $OUT/raw2.apk $OUT/raw.apk
python3 - <<PY
import zipfile, shutil
src='$OUT/raw.apk'; dst='$OUT/unsigned.apk'
zin=zipfile.ZipFile(src)
zout=zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED)
for it in zin.infolist():
    if it.filename.startswith('META-INF/'): continue
    data=zin.read(it.filename)
    zi=zipfile.ZipInfo(it.filename, it.date_time); zi.compress_type=zipfile.ZIP_STORED if (it.filename=='resources.arsc') else it.compress_type; zi.external_attr=it.external_attr
    zout.writestr(zi,data)
names=set(zin.namelist()); n=2
while 'classes%d.dex'%n in names: n+=1
zout.write('$OUT/native/dex/classes.dex','classes%d.dex'%n)
zout.close()
PY
$BT/zipalign -f -p 4 $OUT/unsigned.apk $OUT/aligned.apk
$BT/apksigner sign --ks $KS --ks-pass pass:android --ks-key-alias androiddebugkey --out $OUT/digivi.apk $OUT/aligned.apk
rm -f $OUT/raw.apk* $OUT/unsigned.apk $OUT/aligned.apk $OUT/digivi.apk.idsig
ls -la $OUT/digivi.apk
