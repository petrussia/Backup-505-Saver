#Requires -Version 5.1
<#
  Раздельный бэкап Bitfocus Companion 3.x
  – git pull (+ auto-stash, если есть локальные изменения)
  – создаёт / очищает подпапки: connections, buttons, surfaces, triggers, customVariables
  – скачивает каждый раздел в формате ZIP (.companionconfig)
  – git add → commit → push
#>

$CompanionHost = "172.18.191.23:8000"                       # IP:port Companion
$RepoPath      = Split-Path -Parent $MyInvocation.MyCommand.Definition  # папка скрипта

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
$Sections = 'connections','buttons','surfaces','triggers','customVariables'

# ── 0. Быстрая HTTP-проверка (не критично) ───────────────────────────────
try { Invoke-WebRequest "http://$CompanionHost/status" -Method Head -TimeoutSec 3 -UseBasicParsing | Out-Null }
catch { Write-Warning "$CompanionHost not reachable via HTTP, continuing…" }

Set-Location -Path $RepoPath

# ── 1. git pull с авто-stash ─────────────────────────────────────────────
if (Test-Path '.git') {
    if (git status --porcelain) {
        git stash push -u -m "auto-stash before pull" | Out-Null
        $stashed = $true
    }
    git pull --quiet --rebase
    if ($stashed) { git stash pop --quiet | Out-Null }
}

# ── 2. Создание / очистка подпапок ───────────────────────────────────────
foreach ($s in $Sections) {
    $folder = Join-Path -Path $RepoPath -ChildPath $s
    if (Test-Path $folder) {
        Remove-Item -Path "$folder\*" -Recurse -Force
    } else {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }
}

# ── 3. Скачивание ZIP-бэкапов ────────────────────────────────────────────
foreach ($s in $Sections) {
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $file  = Join-Path -Path (Join-Path -Path $RepoPath -ChildPath $s) -ChildPath "${s}_${stamp}.companionconfig"
    $url   = "http://$CompanionHost/int/export/custom?${s}=1&format=zip&filename=$s"
    Write-Host "--> $s"
    Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
}

# ── 4. git commit + push (если каталог — репозиторий) ────────────────────
if (Test-Path '.git') {
    git add --all
    if (git status --porcelain) {
        git commit -m ("Backup per-section {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm')) --quiet
        git push --quiet
        Write-Host "Backup committed & pushed."
    } else {
        Write-Host "No changes to commit."
    }
} else {
    Write-Host "INFO: '$RepoPath' is not a git repo - commit/push skipped."
}
