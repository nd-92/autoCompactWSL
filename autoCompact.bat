@echo off
setlocal enabledelayedexpansion

:: =====================================================
:: Auto-compact WSL2 VHDX files using diskpart
:: Now locates distros via the WSL registry key
:: =====================================================

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script requires Administrator privileges. Restarting...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo Shutting down all WSL instances...
wsl --shutdown

:: Temporary list file
set "listfile=%TEMP%\wsl_vhdx_list.txt"
if exist "%listfile%" del "%listfile%"

:: Enumerate WSL distros from the registry
echo Reading WSL distribution paths from the registry...
for /f "tokens=*" %%K in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss" /s /v BasePath 2^>nul ^| findstr /i "BasePath"') do (
    :: The line looks like: BasePath    REG_SZ    \\?\D:\WSL\Ubuntu
    for /f "tokens=2*" %%A in ('echo %%K') do (
        set "basePath=%%B"
        :: BasePath may begin with \\?\ ; strip it for diskpart compatibility
        set "basePath=!basePath:\\?\=!"
        set "vhdx=!basePath!\ext4.vhdx"
        if exist "!vhdx!" (
            echo !vhdx!>> "%listfile%"
        )
    )
)

:: Count files
set "count=0"
for /f "usebackq delims=" %%F in ("%listfile%") do set /a count+=1

if %count% equ 0 (
    echo No ext4.vhdx files found via the registry. Exiting.
    if exist "%listfile%" del "%listfile%"
    exit /b
)

echo.
echo Found the following VHDX files:
set "idx=0"
for /f "usebackq delims=" %%F in ("%listfile%") do (
    set /a idx+=1
    echo   !idx!: %%F
)

set /p confirm=Proceed with compaction? (y/n): 
if /i not "%confirm%"=="y" (
    echo Cancelled.
    if exist "%listfile%" del "%listfile%"
    exit /b
)

:: Process each file
set "total=%count%"
set "current=0"
set "success=0"
set "fail=0"

for /f "usebackq delims=" %%F in ("%listfile%") do (
    set /a current+=1
    set "vhd=%%F"
    echo.
    echo [!current!/!total!] Compacting: !vhd!

    :: Create temporary diskpart script
    set "diskpartScript=%TEMP%\compact_!random!.txt"
    (
        echo select vdisk file="!vhd!"
        echo attach vdisk readonly
        echo compact vdisk
        echo detach vdisk
        echo exit
    ) > "!diskpartScript!"

    :: Run diskpart and capture output
    set "logfile=%TEMP%\compact_!random!.log"
    diskpart /s "!diskpartScript!" > "!logfile!" 2>&1
    set "dpError=!errorlevel!"

    :: Determine success
    set "successFlag=0"
    if !dpError! equ 0 (
        findstr /i /c:"successfully compacted" "!logfile!" >nul
        if not errorlevel 1 set "successFlag=1"

        if !successFlag! equ 0 (
            findstr /i /c:"error" "!logfile!" >nul
            if errorlevel 1 set "successFlag=1"
        )
    )

    if !successFlag! equ 1 (
        echo   -^> Compacted successfully.
        set /a success+=1
    ) else (
        echo   -^> Failed. Error output:
        type "!logfile!"
        set /a fail+=1
    )

    :: Clean up temporary files
    del "!diskpartScript!" >nul 2>&1
    del "!logfile!" >nul 2>&1
)

:: Summary
echo.
echo === Summary ===
echo Total files found: %total%
echo Successfully compacted: %success%
echo Failed: %fail%

:: Cleanup
if exist "%listfile%" del "%listfile%"

pause