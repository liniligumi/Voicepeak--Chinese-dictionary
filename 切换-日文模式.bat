@echo off
chcp 65001 >nul
cd /d %~dp0
echo 正在切换到【日文模式】：停用中文字典，日文汉字按日语读音。
echo （需要管理员权限，脚本会自行请求；请先关闭 VoicePeak）
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0VoicepeakDictToggle.ps1" -Mode ja
echo.
pause
