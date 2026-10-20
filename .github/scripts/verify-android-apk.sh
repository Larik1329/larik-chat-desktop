#!/usr/bin/env bash
set -euo pipefail
mkdir -p /tmp/android-verification
adb install -r /tmp/larik-chat.apk
adb shell dumpsys package org.larik.chat.android > /tmp/android-verification/package.txt
grep -q 'versionName=0.1.0' /tmp/android-verification/package.txt
adb shell pm verify-app-links --re-verify org.larik.chat.android
sleep 10
adb shell pm get-app-links org.larik.chat.android > /tmp/android-verification/app-links.txt
cat /tmp/android-verification/app-links.txt
adb shell am start -W -n org.larik.chat.android/.ChatLauncherActivity > /tmp/android-verification/launch.txt
cat /tmp/android-verification/launch.txt
sleep 8
# The disposable emulator may show Chrome onboarding; handle only its explicit buttons.
for attempt in 1 2 3 4 5; do
  adb shell uiautomator dump /sdcard/larik-onboarding.xml >/dev/null || true
  adb pull /sdcard/larik-onboarding.xml /tmp/android-verification/onboarding.xml >/dev/null 2>&1 || true
  tap=$(python3 - <<'PYCODE'
import xml.etree.ElementTree as E,re
try: nodes=list(E.parse('/tmp/android-verification/onboarding.xml').iter('node'))
except Exception: nodes=[]
for label in ['Use without an account','Accept & continue','No thanks','Got it']:
 for n in nodes:
  if n.get('package')=='com.android.chrome' and n.get('text')==label:
   bounds=[int(v) for v in re.findall(r'\d+',n.get('bounds',''))]
   if len(bounds)==4: print((bounds[0]+bounds[2])//2,(bounds[1]+bounds[3])//2);raise SystemExit
PYCODE
)
  if [ -z "$tap" ]; then break; fi
  adb shell input tap $tap
  sleep 3
done
sleep 10
adb shell uiautomator dump /sdcard/larik-launch.xml || true
adb pull /sdcard/larik-launch.xml /tmp/android-verification/launch.xml || true
adb shell screencap -p /sdcard/larik-launch.png
adb pull /sdcard/larik-launch.png /tmp/android-verification/launch.png
adb logcat -d > /tmp/android-verification/logcat.txt
if grep -qE 'FATAL EXCEPTION.*|Process: org.larik.chat.android,' /tmp/android-verification/logcat.txt; then
  if grep -q 'Process: org.larik.chat.android,' /tmp/android-verification/logcat.txt; then echo 'Larik Android process crashed'; exit 1; fi
fi
adb shell am start -W -a android.intent.action.VIEW -d 'https://chat.larik.org/' -p org.larik.chat.android > /tmp/android-verification/deep-link.txt
grep -q 'Status: ok' /tmp/android-verification/deep-link.txt
echo ANDROID_APK_INSTALL_AND_LAUNCH_PASS
python3 - <<'PYCODE'
from pathlib import Path
xml=Path('/tmp/android-verification/launch.xml').read_text()
if 'С возвращением!' not in xml: raise SystemExit('Chat login page not visible; inspect launch screenshot')
print('ANDROID_TWA_CHAT_LOGIN_VISIBLE_PASS')
PYCODE
if grep -q 'chat.larik.org: verified' /tmp/android-verification/app-links.txt; then echo ANDROID_VERIFIED_APP_LINK_PASS; else echo 'Domain verification pending; inspect app-links.txt'; fi
