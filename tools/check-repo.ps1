# Проверка локального репозитория FluidX
# Запуск: powershell -ExecutionPolicy Bypass -File tools\check-repo.ps1

$ErrorActionPreference = "Continue"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git) {
    $candidate = "C:\Program Files\Git\cmd\git.exe"
    if (Test-Path $candidate) { $git = $candidate }
}
if (-not $git) {
    Write-Host "[!!] git не найден. Переустанови Git или добавь его в PATH." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path ".git")) {
    Write-Host "[!!] Папка не является git-репозиторием." -ForegroundColor Red
    exit 1
}

Write-Host "=== Ветка и последние коммиты ===" -ForegroundColor Cyan
& $git branch --show-current
& $git log --oneline -3

Write-Host "`n=== Удалённый репозиторий ===" -ForegroundColor Cyan
$remote = & $git remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0 -and $remote) {
    Write-Host "[OK] origin: $remote" -ForegroundColor Green
} else {
    Write-Host "[!!] origin не настроен — код ещё не привязан к GitHub" -ForegroundColor Yellow
}

Write-Host "`n=== Незакоммиченные изменения ===" -ForegroundColor Cyan
$status = & $git status --short
if ($status) {
    Write-Host "[!!] есть изменения:" -ForegroundColor Yellow
    $status
} else {
    Write-Host "[OK] рабочая копия чистая" -ForegroundColor Green
}

Write-Host "`n=== Файлы, без которых сборка не пройдёт ===" -ForegroundColor Cyan
$required = @(
    "Tweak.x",
    "Makefile",
    "control",
    ".github/workflows/build.yml",
    "prefs/Makefile",
    "layout/Library/PreferenceLoader/Preferences/FluidX.plist",
    "layout/Library/PreferenceBundles/FluidXPrefs.bundle/Root.plist",
    "layout/Library/PreferenceBundles/FluidXPrefs.bundle/Info.plist"
)
$missing = 0
foreach ($file in $required) {
    if (Test-Path $file) {
        Write-Host ("[OK] " + $file) -ForegroundColor Green
    } else {
        Write-Host ("[!!] " + $file) -ForegroundColor Red
        $missing++
    }
}

Write-Host "`n=== Не отправлено на GitHub ===" -ForegroundColor Cyan
if ($remote) {
    $ahead = & $git log --oneline "origin/main..HEAD" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "       ветка origin/main ещё не существует (первый push не сделан)" -ForegroundColor Yellow
    } elseif ($ahead) {
        Write-Host "[!!] есть локальные коммиты без push:" -ForegroundColor Yellow
        $ahead
    } else {
        Write-Host "[OK] всё отправлено" -ForegroundColor Green
    }
} else {
    Write-Host "       сначала настрой origin" -ForegroundColor Yellow
}

Write-Host ""
if ($missing -eq 0) {
    Write-Host "ИТОГ: проект выглядит целым." -ForegroundColor Green
} else {
    Write-Host ("ИТОГ: не хватает файлов: " + $missing) -ForegroundColor Red
}
