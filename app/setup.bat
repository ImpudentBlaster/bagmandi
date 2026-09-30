@echo off
echo Setting up BagMandi Flutter project...
echo.

where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter is not installed or not in PATH.
    echo Please install Flutter from https://docs.flutter.dev/get-started/install
    pause
    exit /b 1
)

flutter create . --org com.bagmandi
flutter pub get

echo.
echo Setup complete!
echo.
echo Next steps:
echo   1. Run: dart pub global activate flutterfire_cli
echo   2. Run: flutterfire configure
echo   3. Run: flutter run          (mobile app)
echo.
pause
