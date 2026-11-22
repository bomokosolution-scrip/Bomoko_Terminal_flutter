@echo off
cd /d %~dp0
if exist _tmp_create rmdir /s /q _tmp_create
if exist android rmdir /s /q android
call flutter create --org com.bomoko --project-name terminal --platforms android _tmp_create
xcopy /e /i /y _tmp_create\android android >nul
rmdir /s /q _tmp_create
if exist test rmdir /s /q test
python tools\prepare_android.py android
call flutter pub get
call dart run flutter_launcher_icons
echo.
echo Pret. Lancez : flutter build apk --release
