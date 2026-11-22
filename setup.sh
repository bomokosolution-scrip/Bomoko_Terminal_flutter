#!/usr/bin/env bash
# Prépare le projet Android (package com.bomoko.terminal) puis installe les dépendances et l'icône.
set -euo pipefail
cd "$(dirname "$0")"

rm -rf _tmp_create android
flutter create --org com.bomoko --project-name terminal --platforms android _tmp_create
cp -r _tmp_create/android ./android
rm -rf _tmp_create test

python3 tools/prepare_android.py android
flutter pub get
dart run flutter_launcher_icons
echo
echo "Prêt. Lancez :  flutter build apk --release"
echo "APK : build/app/outputs/flutter-apk/app-release.apk"
