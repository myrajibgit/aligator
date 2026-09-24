@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo           StudyCompete - Quick GitHub Setup & Push Script
echo =====================================================================
echo.

set /p REPO_URL="Enter your GitHub Repository HTTPS URL (e.g. https://github.com/username/studycompete.git): "

if "%REPO_URL%"=="" (
    echo [ERROR] No URL provided. Aborting.
    pause
    exit /b 1
)

echo.
echo [1/5] Initializing Git repository...
git init

echo [2/5] Staging files...
git add .

echo [3/5] Committing initial production release...
git commit -m "feat: complete production StudyCompete Flutter application with CI/CD"

echo [4/5] Configuring remote origin...
git remote remove origin 2>nul
git remote add origin %REPO_URL%
git branch -M main

echo [5/5] Pushing to GitHub...
git push -u origin main

if %ERRORLEVEL% equ 0 (
    echo.
    echo =====================================================================
    echo [SUCCESS] Code successfully pushed to GitHub!
    echo Head over to your repository's 'Actions' tab to see the APK build live!
    echo =====================================================================
) else (
    echo.
    echo [NOTE] Push encountered an issue. Ensure your GitHub credentials/PAT are configured.
)

pause
