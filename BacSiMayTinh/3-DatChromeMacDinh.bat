@echo off
title Dat Chrome lam trinh duyet mac dinh
set "CHROME="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"

if not defined CHROME (
    echo May chua cai Chrome. Dang mo trang tai Chrome...
    start "" "https://www.google.com/chrome/"
    echo Cai xong Chrome thi bam lai file nay.
    pause
    exit /b
)

echo Dang mo trang cai dat...
echo.
echo  ==^> Windows 11: bam nut "Set default" o tren cung.
echo  ==^> Windows 10: o muc "Web browser" bam vao chu "e" roi chon Google Chrome.
echo.
start "" "ms-settings:defaultapps?registeredAppUser=Google Chrome"
pause
