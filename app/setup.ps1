# BagMandi Setup Script (PowerShell)
Write-Host "BagMandi Setup" -ForegroundColor Green
Write-Host ""

# Check Flutter
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    $commonPaths = @(
        "D:\flutter\bin\flutter.bat",
        "C:\flutter\bin\flutter.bat",
        "$env:LOCALAPPDATA\flutter\bin\flutter.bat",
        "$env:USERPROFILE\flutter\bin\flutter.bat"
    )
    foreach ($p in $commonPaths) {
        if (Test-Path $p) {
            $env:Path = "$(Split-Path $p -Parent);$env:Path"
            $flutter = Get-Command flutter -ErrorAction SilentlyContinue
            break
        }
    }
}

if (-not $flutter) {
    Write-Host "ERROR: Flutter is NOT installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install Flutter first:" -ForegroundColor Yellow
    Write-Host "  1. Download: https://docs.flutter.dev/get-started/install/windows"
    Write-Host "  2. Extract to D:\flutter"
    Write-Host "  3. Add D:\flutter\bin to System PATH"
    Write-Host "  4. Restart terminal and run: flutter doctor"
    Write-Host ""
    exit 1
}

Write-Host "Flutter found: $(flutter --version | Select-Object -First 1)" -ForegroundColor Green
Write-Host ""

Set-Location $PSScriptRoot

Write-Host "Creating platform files..." -ForegroundColor Cyan
flutter create . --org com.bagmandi
flutter pub get

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Run app:" -ForegroundColor Yellow
Write-Host "  flutter run              (mobile app)"
Write-Host ""
