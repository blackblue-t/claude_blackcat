@echo off
chcp 65001 >nul
cd /d "%~dp0"

rem 尋找 Git Bash。不能用 where bash：System32 的 bash.exe 是 WSL 的入口，
rem 沒裝 WSL 發佈版時會報「沒有已安裝的發佈」。
set "GITBASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "GITBASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined GITBASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "GITBASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined GITBASH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "GITBASH=%LocalAppData%\Programs\Git\bin\bash.exe"
if not defined GITBASH for /f "delims=" %%G in ('where git 2^>nul') do if not defined GITBASH if exist "%%~dpG..\bin\bash.exe" set "GITBASH=%%~dpG..\bin\bash.exe"

if not defined GITBASH (
    echo [ERROR] 找不到 Git Bash。請先安裝 Git for Windows: https://git-scm.com/download/win
    echo         注意：System32 的 bash.exe 是 WSL，不適用本安裝。
    pause
    exit /b 1
)
echo 使用 Git Bash: %GITBASH%
echo.

"%GITBASH%" install.sh
if errorlevel 1 (
    echo [ERROR] 安裝失敗，請看上方訊息
    pause
    exit /b 1
)

rem 把 %USERPROFILE%\.claude\bin 加入使用者 PATH（安全 append，不動系統 PATH）
powershell -NoProfile -Command "$bin=Join-Path $env:USERPROFILE '.claude\bin'; $p=[Environment]::GetEnvironmentVariable('Path','User'); if(-not $p){$p=''}; if($p -notlike ('*'+$bin+'*')){[Environment]::SetEnvironmentVariable('Path',($p.TrimEnd(';')+';'+$bin),'User'); Write-Host '已將 .claude\bin 加入 PATH（重開 cmd 生效）'} else { Write-Host 'PATH 已包含 .claude\bin' }"

echo.
echo ✅ 完成！重開 cmd 後，在任何專案目錄可用：
echo    cat --lean      安裝快速迭代工作流
echo    cat --strict    安裝正式產品工作流
echo    cat --list      看全部選項
pause
