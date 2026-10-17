# dsh-sleep-send 一键恢复脚本
#
# 用途：DSH 升级（或 pnpm 重装依赖）后，若插件被回退到旧版——症状是
#       输入框旁出现齿轮按钮、且「定时」按钮变灰点不动——运行本脚本恢复。
#
# 原理：profile 以 `github:<user>/dsh-sleep-send` 方式安装时，pnpm 会按
#       pnpm-lock.yaml 里锁定的 commit 重新拉取。若 lock 指向旧 commit，
#       DSH 升级后就会把插件覆盖成旧版。本脚本把仓库里的正确版本复制回去。
#
# 用法：pwsh -File restore-sleep-send.ps1

$ErrorActionPreference = "Stop"

$src = Join-Path $PSScriptRoot "client.js"
$dstDir = Join-Path $env:USERPROFILE ".dsh\profiles\desktop\node_modules\dsh-sleep-send"
$dst = Join-Path $dstDir "client.js"

Write-Host "=== dsh-sleep-send 恢复 ===" -ForegroundColor Cyan

if (-not (Test-Path $src)) {
    Write-Host "❌ 源文件不存在: $src" -ForegroundColor Red
    Write-Host "   请先克隆: git clone https://github.com/qiyeren/dsh-sleep-send.git"
    exit 1
}
if (-not (Test-Path $dst)) {
    Write-Host "❌ 部署目标不存在: $dst" -ForegroundColor Red
    Write-Host "   插件可能未安装到 desktop profile。"
    exit 1
}

# 归一化换行后再比较，避免 CRLF/LF 差异导致误判
function Get-NormalizedHash([string]$path) {
    $t = [System.IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $b = [System.Text.Encoding]::UTF8.GetBytes($t)
    # 兼容 Windows PowerShell 5.1（无 [Convert]::ToHexString）
    return (($sha.ComputeHash($b) | ForEach-Object { $_.ToString("x2") }) -join "")
}

$srcHash = Get-NormalizedHash $src
$dstHash = Get-NormalizedHash $dst

Write-Host ("  源:   " + (Get-Item $src).Length + " 字节  " + $srcHash.Substring(0, 12))
Write-Host ("  部署: " + (Get-Item $dst).Length + " 字节  " + $dstHash.Substring(0, 12))

if ($srcHash -eq $dstHash) {
    Write-Host "`n✅ 内容一致，无需恢复。" -ForegroundColor Green
    exit 0
}

# 备份当前（旧版）文件，便于回溯
$bak = "$dst.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $dst $bak -Force
Write-Host "`n  已备份旧版到: $(Split-Path $bak -Leaf)"

Copy-Item $src $dst -Force

if ((Get-NormalizedHash $dst) -eq $srcHash) {
    Write-Host "`n✅ 恢复成功！请硬刷新页面 (Ctrl+Shift+R)。" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ 恢复后校验失败，请手动检查。" -ForegroundColor Red
    exit 1
}
