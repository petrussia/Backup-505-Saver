# backup-companion.ps1
# ---------------------------------------------
# 1) Остановить Companion (если запущен как служба)
#    & sc.exe stop CompanionServiceName
#    -- или если запускаете вручную, уберите этот шаг

# 2) Путь к исходному конфигу Companion
$SourceConfig = "C:\Users\user\Учёба\3 курс\ВидеоТехнологии\Backups\backup-505-saver\backup-companion.ps1"

# 3) Папка локального git-репозитория для бэкапов
$RepoPath     = "C:\Users\user\Учёба\3 курс\ВидеоТехнологии\Backups\backup-505-saver\"    # <– измени на свой путь
Set-Location $RepoPath

# 4) Имя бэкап-файла с меткой времени
$ts           = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupName   = "operator-2-pi_$ts.companionconfig"

# 5) Копируем файл
Copy-Item -Path $SourceConfig -Destination "$RepoPath\$BackupName" -Force

# 6) Фиксируем изменения в git
git add --all
git commit -m "Автобэкап CompanionConfig $ts"
# (если нет изменений — git commit вернёт ошибку, её можно игнорировать)
git push origin main

# 7) Запустить Companion обратно (если останавливался выше)
#    & sc.exe start CompanionServiceName
