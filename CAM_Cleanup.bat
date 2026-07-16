@echo off
chcp 65001 >nul
title CapabilityAccessManager スリム化ツール

:: ===== 管理者権限チェック & 自己昇格 =====
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 管理者権限が必要です。確認ダイアログで「はい」を押してください...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "CAMDIR=%ProgramData%\Microsoft\Windows\CapabilityAccessManager"

echo ============================================================
echo   CapabilityAccessManager スリム化ツール
echo ============================================================
echo.

:: ===== 現在のファイルサイズを表示 =====
echo 【処理前のファイルサイズ】
powershell -NoProfile -Command "Get-ChildItem '%CAMDIR%\CapabilityAccessManager.db*' -ErrorAction SilentlyContinue | ForEach-Object { '{0,-40} {1,12:N1} MB' -f $_.Name, ($_.Length/1MB) }"
echo.

:: ===== camsvc サービス停止 =====
echo Capability Access Manager サービスを停止しています...
sc stop camsvc >nul 2>&1

:: 停止完了を最大30秒待機
set /a COUNT=0
:WAIT_STOP
sc query camsvc | find "STOPPED" >nul
if %errorlevel% equ 0 goto STOPPED
set /a COUNT+=1
if %COUNT% geq 30 (
    echo.
    echo [エラー] サービスを停止できませんでした。
    echo PCを再起動してから、もう一度このツールを実行してください。
    echo.
    pause
    exit /b 1
)
timeout /t 1 /nobreak >nul
goto WAIT_STOP

:STOPPED
echo サービスを停止しました。
echo.

:: ===== 肥大化ファイルの削除 =====
echo データベースファイルを削除しています...
del /f /q "%CAMDIR%\CapabilityAccessManager.db-wal" 2>nul
del /f /q "%CAMDIR%\CapabilityAccessManager.db-shm" 2>nul
del /f /q "%CAMDIR%\CapabilityAccessManager.db"     2>nul

:: 削除できたか確認(wal が残っていたら失敗扱い)
if exist "%CAMDIR%\CapabilityAccessManager.db-wal" (
    echo.
    echo [エラー] ファイルを削除できませんでした。
    echo PCを再起動してから、もう一度このツールを実行してください。
    echo.
    sc start camsvc >nul 2>&1
    pause
    exit /b 1
)
echo 削除が完了しました。
echo.

:: ===== camsvc サービス再開 =====
echo サービスを再開しています...
sc start camsvc >nul 2>&1
timeout /t 3 /nobreak >nul

echo.
echo 【処理後のファイルサイズ】
powershell -NoProfile -Command "$f = Get-ChildItem '%CAMDIR%\CapabilityAccessManager.db*' -ErrorAction SilentlyContinue; if ($f) { $f | ForEach-Object { '{0,-40} {1,12:N1} MB' -f $_.Name, ($_.Length/1MB) } } else { '(ファイルは再作成待ちです。Windows が自動的に作り直します)' }"
echo.
echo ============================================================
echo   処理が完了しました。このウィンドウは閉じて構いません。
echo ============================================================
echo.
pause
