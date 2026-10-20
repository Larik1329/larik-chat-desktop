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
sleep 15
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
if grep -q 'chat.larik.org: verified' /tmp/android-verification/app-links.txt; then echo ANDROID_VERIFIED_APP_LINK_PASS; else echo 'Domain verification pending; inspect app-links.txt'; fi
