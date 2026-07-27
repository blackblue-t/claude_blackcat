@echo off
cd /d "%~dp0"

rem Find Git Bash. Do NOT use "where bash": System32 bash.exe is the WSL stub
rem and fails with "no installed distributions" when WSL has no distro.
set "GITBASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "GITBASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined GITBASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "GITBASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined GITBASH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "GITBASH=%LocalAppData%\Programs\Git\bin\bash.exe"
if not defined GITBASH for /f "delims=" %%G in ('where git 2^>nul') do if not defined GITBASH if exist "%%~dpG..\bin\bash.exe" set "GITBASH=%%~dpG..\bin\bash.exe"

if not defined GITBASH (
    echo [ERROR] Git Bash not found. Install Git for Windows: https://git-scm.com/download/win
    pause
    exit /b 1
)
echo Using Git Bash: %GITBASH%
echo.

"%GITBASH%" install.sh
if errorlevel 1 (
    echo [ERROR] install.sh failed. See messages above.
    pause
    exit /b 1
)

rem Append %USERPROFILE%\.claude\bin to user PATH (safe append, user scope only)
powershell -NoProfile -Command "$bin=Join-Path $env:USERPROFILE '.claude\bin'; $p=[Environment]::GetEnvironmentVariable('Path','User'); if(-not $p){$p=''}; if($p -notlike ('*'+$bin+'*')){[Environment]::SetEnvironmentVariable('Path',($p.TrimEnd(';')+';'+$bin),'User'); Write-Host 'PATH updated (restart your terminal to take effect)'} else { Write-Host 'PATH already contains .claude\bin' }"

echo.
echo Done! Open a NEW terminal, then in any project folder:
echo    cmd:        cat --lean       or  cat --strict
echo    PowerShell: blackcat --lean  ("cat" is taken by Get-Content alias)
pause
