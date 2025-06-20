#Requires -Version 5.1
<#
  Раздельный бэкап Bitfocus Companion 3.5
  • git pull с auto-stash
  • Для двух хостов (local + 172):
      ─ создаёт/очищает подпапки connections|buttons|… в каталогах
        <Repo>\local_Bitfocus_configs  и  <Repo>\172_Bitfocus_configs
      ─ скачивает разделы в формате ZIP (.companionconfig)
  • Копирует D:\Animated-Lower-Thirds\lower thirds  →  <Repo>\OBS_configs\
  • git add всей директории → commit → push
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

# ── git pull (auto-stash) ────────────────────────────────────────────────
if (Test-Path '.git') {
    $stashed = $false
    if (git status --porcelain) {
        git stash push -u -m "auto-stash before pull" | Out-Null
        $stashed = $true
    }
    git pull --quiet --rebase
    if ($stashed) { git stash pop --quiet | Out-Null }
}

# ── создаём / очищаем каталоги ────────────────────────────────────────────
foreach ($t in $Targets) {
    $base = Join-Path -Path $RepoPath -ChildPath $t.Name
    if (-not (Test-Path $base)) { New-Item -ItemType Directory -Path $base | Out-Null }

    foreach ($s in $Sections) {
        $folder = Join-Path -Path $base -ChildPath $s
        if (Test-Path $folder) {
            Remove-Item -Path "$folder\*" -Recurse -Force
        }
        else {
            New-Item -ItemType Directory -Path $folder | Out-Null
        }
    }
}

# ── скачиваем ZIP-бэкапы ─────────────────────────────────────────────────
foreach ($t in $Targets) {
    $base       = Join-Path -Path $RepoPath -ChildPath $t.Name
    $TargetHost = $t.Host

    Write-Host "`n=== Export from $TargetHost → $($t['Name']) ==="

    foreach ($s in $Sections) {
        $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $file  = Join-Path -Path (Join-Path -Path $base -ChildPath $s) -ChildPath "${s}_${stamp}.companionconfig"
        $url   = "http://$TargetHost/int/export/custom?${s}=1&format=zip&filename=$s"

        Write-Host "--> $s"
        Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
    }
}

# ── копируем Animated-Lower-Thirds → OBS_configs ─────────────────────────
try {
    $srcDir  = 'D:\Animated-Lower-Thirds\lower thirds'
    $dstRoot = Join-Path -Path $RepoPath -ChildPath 'OBS_configs'
    if (-not (Test-Path $dstRoot)) { New-Item -ItemType Directory -Path $dstRoot | Out-Null }

    $dstDir = Join-Path -Path $dstRoot -ChildPath 'lower thirds'
    if (Test-Path $dstDir) { Remove-Item -Path $dstDir -Recurse -Force }
    Copy-Item -Path $srcDir -Destination $dstRoot -Recurse -Force

    Write-Host "`nAnimated-Lower-Thirds copied → $dstDir"
}
catch {
    Write-Warning "Cannot copy Animated-Lower-Thirds: $_"
}

# ---- git add + commit + push + вывод ошибок --------------------------
if (Test-Path '.git') {
    git add --all

    if (git status --porcelain) {
        $msg = "Dual-host backup $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        git commit -m $msg --quiet
        $proc = Start-Process -FilePath cmd.exe `
                              -ArgumentList '/c', 'git push --quiet >NUL 2>&1' `
                              -NoNewWindow -Wait -PassThru

        if ($proc.ExitCode -ne 0) {
            Write-Error "Git push failed (exit code $($proc.ExitCode))"
            exit $proc.ExitCode
        }
        else {
            Write-Host "`nBackup committed & pushed."
        }
    }
    else {
        Write-Host "`nNo changes to commit."
    }
}
else {
    Write-Host "`nINFO: '$RepoPath' is not a git repo - commit/push skipped."
}
