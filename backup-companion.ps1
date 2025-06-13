#Requires -Version 5.1
<#
  Раздельный бэкап Bitfocus Companion 3.5
  • git pull (+ auto-stash, если есть изменения)
  • Для КАЖДОГО из двух хостов:
      ─ создаёт / очищает подпапки в каталоге  <Repo>\{local_Bitfocus_configs|172_Bitfocus_configs}\{connections|…}
      ─ скачивает разделы в формате ZIP (.companionconfig)
  • Затем загружает в репу git add → commit → push
#>

$RepoPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$Targets = @(
    @{ Name = 'local_Bitfocus_configs'; Host = '127.0.0.1:8000' },
    @{ Name = '172_Bitfocus_configs'  ; Host = '172.18.191.23:8000' }
)

$Sections = 'connections','buttons','surfaces','triggers','customVariables'
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

Set-Location -Path $RepoPath

# ---- git pull (auto-stash) ----------------------------------------------
if (Test-Path '.git') {
    if (git status --porcelain) {
        git stash push -u -m "auto-stash before pull" | Out-Null
        $stashed = $true
    }
    git pull --quiet --rebase
    if ($stashed) { git stash pop --quiet | Out-Null }
}

# ---- создаём / очищаем каталоги ------------------------------------------
foreach ($t in $Targets) {
    $base = Join-Path -Path $RepoPath -ChildPath $t.Name
    if (-not (Test-Path $base)) { New-Item -ItemType Directory -Path $base | Out-Null }

    foreach ($s in $Sections) {
        $folder = Join-Path -Path $base -ChildPath $s
        if (Test-Path $folder) {
            Remove-Item -Path "$folder\*" -Recurse -Force
        } else {
            New-Item -ItemType Directory -Path $folder | Out-Null
        }
    }
}

# ---- скачиваем ZIP-бэкапы -------------------------------------------------
foreach ($t in $Targets) {
    $base       = Join-Path -Path $RepoPath -ChildPath $t.Name
    $TargetHost = $t.Host

    Write-Host "`n=== Export from $TargetHost → $t.Name ==="

    foreach ($s in $Sections) {
        $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $file  = Join-Path -Path (Join-Path -Path $base -ChildPath $s) -ChildPath "${s}_${stamp}.companionconfig"
        $url   = "http://$TargetHost/int/export/custom?${s}=1&format=zip&filename=$s"

        Write-Host "--> $s"
        Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
    }
}

# ---- git add всех файлов + commit + push ----------------------------------------------------
if (Test-Path '.git') {
    git add --all
    if (git status --porcelain) {
        $msg = "Dual-host backup $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        git commit -m $msg --quiet
        git push --quiet
        Write-Host "`nBackup committed & pushed."
    } else {
        Write-Host "`nNo changes to commit."
    }
} else {
    Write-Host "`nINFO: '$RepoPath' is not a git repo - commit/push skipped."
}
