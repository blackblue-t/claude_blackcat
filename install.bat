@echo off
chcp 65001 >nul
cd /d "%~dp0"

where bash >nul 2>nul
if errorlevel 1 (
    echo [ERROR] 找不到 bash。請先安裝 Git for Windows: https://git-scm.com/download/win
    pause
    exit /b 1
)

bash install.sh
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
