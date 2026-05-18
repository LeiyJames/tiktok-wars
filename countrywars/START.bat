@echo off
title Country Wars - TikTok LIVE Mock Dashboard
color 0A

echo ============================================
echo   COUNTRY WARS - TikTok LIVE Overlay
echo ============================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found. Please install Python 3.11+ from python.org
    pause
    exit /b 1
)

REM Install dependencies if needed
echo [1/3] Checking dependencies...
pip install -r requirements.txt --quiet

echo.
echo ============================================
echo   SELECT RUN MODE
echo ============================================
echo   [1] 🎮 PURE MOCK / DEMO MODE (Recommended for offline local testing)
echo   [2] 📡 REAL TIKTOK LIVE CONNECTION
echo ============================================
echo.
set /p MODE_CHOICE="Choose option [1 or 2, default is 1]: "

if "%MODE_CHOICE%"=="2" (
    echo.
    echo [📡] REAL TIKTOK LIVE CONNECTION SELECTED
    set /p TIKTOK_USERNAME="Enter your TikTok username (e.g. hellsing_90): "
    set MOCK_MODE=false
) else (
    echo.
    echo [🎮] MOCK / DEMO MODE SELECTED (No TikTok account needed)
    set TIKTOK_USERNAME=demo_user
    set MOCK_MODE=true
)

echo.
echo [2/3] Starting backend server...
echo [3/3] Configuration complete!
echo.
echo ============================================
echo   🎮 MOCK & CONTROL PANEL URL:
echo   http://localhost:3000/
echo.
echo   ⚔️ OBS BROWSER SOURCE URL:
echo   http://localhost:3000/overlay
echo   Width: 420  Height: 700
echo ============================================
echo.
echo Press Ctrl+C to stop the server.
echo.

cd backend
python app.py
pause
