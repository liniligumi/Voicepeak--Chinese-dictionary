@echo off
chcp 65001 >nul
cd /d %~dp0
echo 正在切换到【中文模式】：重新启用中文字典。
echo （需要管理员权限，脚本会自行请求；请先关闭 VoicePeak）
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0VoicepeakDictToggle.ps1" -Mode cn
echo.
pause
