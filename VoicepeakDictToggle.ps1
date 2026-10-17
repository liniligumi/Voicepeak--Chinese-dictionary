<#
VoicePeak 词典开关 (VoicepeakDictToggle.ps1)  v2

用法:
    powershell -ExecutionPolicy Bypass -File VoicepeakDictToggle.ps1 -Mode ja
    powershell -ExecutionPolicy Bypass -File VoicepeakDictToggle.ps1 -Mode cn
    powershell -ExecutionPolicy Bypass -File VoicepeakDictToggle.ps1 -Mode status
#>
param([ValidateSet('ja','cn','status')][string]$Mode = 'status')
$ErrorActionPreference = 'Stop'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-Paths {
    $root = Join-Path $env:LOCALAPPDATA 'Dreamtonics\Voicepeak'
    [pscustomobject]@{
        UserDict = Join-Path $env:ProgramData 'Dreamtonics\Voicepeak\user-dictionary'
        Settings = Join-Path $root 'settings'
        Disabled = Join-Path $root 'dict-disabled'
        Master   = Join-Path $root 'dict-master'
    }
}

function Test-ValidDict($path) {
    try {
        $data = (Get-Content -LiteralPath $path -Raw -Encoding UTF8) | ConvertFrom-Json
        return ($null -ne $data -and @($data).Count -gt 0)
    } catch { return $false }
}

function Get-ValidDicts($dir) {
    if (-not (Test-Path $dir)) { return @() }
    @(Get-ChildItem $dir -Filter '*-dic.json' -File -ErrorAction SilentlyContinue |
        Where-Object { Test-ValidDict $_.FullName })
}

function Clear-Compiled($p) {
    foreach ($name in 'user.csv','user.dic') {
        $f = Join-Path $p.Settings $name
        if (Test-Path $f) {
            try { Remove-Item $f -Force; Write-Host "  已删除编译产物 $name" }
            catch { Write-Warning "无法删除 $name -- 请先关闭 VoicePeak 再试。" }
        }
    }
}

function Save-Master($p) {
    New-Item -ItemType Directory -Force -Path $p.Master | Out-Null
    $existing = @(Get-ChildItem $p.Master -Filter '*-dic.json' -File -ErrorAction SilentlyContinue |
                  Where-Object { Test-ValidDict $_.FullName })
    if ($existing.Count -gt 0) { return }
    $src = Get-ValidDicts $p.UserDict
    if ($src.Count -eq 0) { return }
    foreach ($j in $src) {
        Copy-Item $j.FullName (Join-Path $p.Master $j.Name) -Force
        Write-Host "  已保存词典母本 $($j.Name)（不会被覆盖）"
    }
}

function Show-Status {
    $p = Get-Paths
    $active   = Get-ValidDicts $p.UserDict
    $master   = Get-ValidDicts $p.Master
    $disabled = @(Get-ChildItem $p.Disabled -Filter '*-dic.json' -File -ErrorAction SilentlyContinue)
    $compiled = @('user.csv','user.dic') | Where-Object { Test-Path (Join-Path $p.Settings $_) }
    Write-Host "词典目录     : $($p.UserDict)"
    Write-Host "母本备份     : $($p.Master)  ($($master.Count) 个)"
    Write-Host "已停用       : $($disabled.Count) 个"
    Write-Host "启用中的词典 : $($active.Count) 个"
    foreach ($j in $active) { Write-Host ("    {0}  {1:N0} 字节" -f $j.Name, $j.Length) }
    Write-Host "编译产物     : $(if ($compiled) { $compiled -join ', ' } else { '无' })"
    if ($active.Count -gt 0) { Write-Host "当前状态     : 中文模式（词典生效）" -ForegroundColor Cyan }
    else                     { Write-Host "当前状态     : 日文模式（词典已停用）" -ForegroundColor Cyan }
}

function Switch-ToJapanese {
    $p = Get-Paths
    New-Item -ItemType Directory -Force -Path $p.Disabled | Out-Null
    Save-Master $p
    $jsons = @(Get-ChildItem $p.UserDict -Filter '*-dic.json' -File -ErrorAction SilentlyContinue)
    if ($jsons.Count -eq 0) { Write-Host "已经是日文模式，无需切换。" }
    foreach ($j in $jsons) {
        Move-Item $j.FullName (Join-Path $p.Disabled $j.Name) -Force
        Write-Host "  移走 $($j.Name)"
    }
    Clear-Compiled $p
    Write-Host ""
    Write-Host "已切换到日文模式：中文字典停用，日文汉字按日语读音。" -ForegroundColor Green
    Write-Host "词典母本保留在 $($p.Master)，可随时切回。"
}

function Switch-ToChinese {
    $p = Get-Paths
    Save-Master $p
    foreach ($j in @(Get-ChildItem $p.UserDict -Filter '*-dic.json' -File -ErrorAction SilentlyContinue)) {
        if (-not (Test-ValidDict $j.FullName)) {
            $size = $j.Length
            Remove-Item $j.FullName -Force
            Write-Host "  清理空词典 $($j.Name)（$size 字节）"
        }
    }
    $master = Get-ValidDicts $p.Master
    if ($master.Count -eq 0) {
        Write-Warning "没有找到词典母本：$($p.Master)。请重新导入 词典库_中文.vdc2。"
        return
    }
    foreach ($j in $master) {
        Copy-Item $j.FullName (Join-Path $p.UserDict $j.Name) -Force
        Write-Host ("  恢复 {0}  ({1:N0} 字节)" -f $j.Name, $j.Length)
    }
    Clear-Compiled $p
    Write-Host ""
    Write-Host "已切换到中文模式：下次启动 VoicePeak 会自动重建词典。" -ForegroundColor Green
}

if ($Mode -ne 'status' -and -not (Test-Admin)) {
    Write-Host "需要管理员权限，正在重新以管理员身份启动..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"",'-Mode',$Mode)
    exit
}

switch ($Mode) {
    'ja'     { Switch-ToJapanese }
    'cn'     { Switch-ToChinese }
    'status' { Show-Status }
}
