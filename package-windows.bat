@echo off
setlocal enabledelayedexpansion
REM Packaging script for GameLift Streams IVS Broadcast Sidecar Sample
REM Creates a self-contained distribution package with all dependencies

echo ========================================
echo GameLift Streams IVS Broadcast Sidecar Sample - Windows Packaging
echo ========================================
echo.

REM Check if build exists
if not exist "build-win\gamelift-streams-ivs-broadcast-sidecar-sample.exe" (
    echo ERROR: Build not found. Please run build-windows.bat first.
    exit /b 1
)

REM Detect GStreamer installation
set GST_ROOT=
if exist "C:\gstreamer\1.0\msvc_x86_64" (
    set GST_ROOT=C:\gstreamer\1.0\msvc_x86_64
) else if exist "C:\gstreamer\1.0\x86_64" (
    set GST_ROOT=C:\gstreamer\1.0\x86_64
) else if defined GSTREAMER_1_0_ROOT_MSVC_X86_64 (
    set GST_ROOT=%GSTREAMER_1_0_ROOT_MSVC_X86_64%
) else if defined GSTREAMER_1_0_ROOT_X86_64 (
    set GST_ROOT=%GSTREAMER_1_0_ROOT_X86_64%
)

if "%GST_ROOT%"=="" (
    echo ERROR: GStreamer installation not found.
    echo Please install GStreamer or set GSTREAMER_1_0_ROOT_MSVC_X86_64 environment variable.
    exit /b 1
)
echo [OK] Found GStreamer at: %GST_ROOT%

REM Create package directory structure
set PACKAGE_DIR=gamelift-streams-ivs-broadcast-sidecar-sample-windows
echo.
echo Creating package directory: %PACKAGE_DIR%
if exist %PACKAGE_DIR% rmdir /s /q %PACKAGE_DIR%
mkdir %PACKAGE_DIR%
mkdir %PACKAGE_DIR%\bin
mkdir %PACKAGE_DIR%\gstreamer\bin
mkdir %PACKAGE_DIR%\gstreamer\lib\gstreamer-1.0

REM Copy main executable
echo.
echo [1/6] Copying main executable...
copy /Y build-win\gamelift-streams-ivs-broadcast-sidecar-sample.exe %PACKAGE_DIR%\bin\ >nul
echo       - gamelift-streams-ivs-broadcast-sidecar-sample.exe

REM Copy MSVC Runtime DLLs (required for clean systems)
echo.
echo [2/6] Copying MSVC Runtime DLLs...
set MSVC_REDIST=
REM Try common MSVC redist locations
if exist "C:\Windows\System32\vcruntime140.dll" (
    set MSVC_REDIST=C:\Windows\System32
) else if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT" (
    set MSVC_REDIST=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT
)

REM Copy from GStreamer bin if available (they bundle MSVC runtime)
if exist "%GST_ROOT%\bin\vcruntime140.dll" (
    copy /Y "%GST_ROOT%\bin\vcruntime140.dll" %PACKAGE_DIR%\bin\ >nul 2>&1
    echo       - vcruntime140.dll (from GStreamer)
)
if exist "%GST_ROOT%\bin\vcruntime140_1.dll" (
    copy /Y "%GST_ROOT%\bin\vcruntime140_1.dll" %PACKAGE_DIR%\bin\ >nul 2>&1
    echo       - vcruntime140_1.dll (from GStreamer)
)
if exist "%GST_ROOT%\bin\msvcp140.dll" (
    copy /Y "%GST_ROOT%\bin\msvcp140.dll" %PACKAGE_DIR%\bin\ >nul 2>&1
    echo       - msvcp140.dll (from GStreamer)
)

REM Fallback to system if not in GStreamer
if not exist "%PACKAGE_DIR%\bin\vcruntime140.dll" (
    if exist "C:\Windows\System32\vcruntime140.dll" (
        copy /Y "C:\Windows\System32\vcruntime140.dll" %PACKAGE_DIR%\bin\ >nul 2>&1
        echo       - vcruntime140.dll (from System32)
    )
)
if not exist "%PACKAGE_DIR%\bin\vcruntime140_1.dll" (
    if exist "C:\Windows\System32\vcruntime140_1.dll" (
        copy /Y "C:\Windows\System32\vcruntime140_1.dll" %PACKAGE_DIR%\bin\ >nul 2>&1
        echo       - vcruntime140_1.dll (from System32)
    )
)
if not exist "%PACKAGE_DIR%\bin\msvcp140.dll" (
    if exist "C:\Windows\System32\msvcp140.dll" (
        copy /Y "C:\Windows\System32\msvcp140.dll" %PACKAGE_DIR%\bin\ >nul 2>&1
        echo       - msvcp140.dll (from System32)
    )
)

REM Copy pthread dependencies if available
if exist "C:\pthreads\Pre-built.2\dll\x64\pthreadVC2.dll" (
    copy /Y "C:\pthreads\Pre-built.2\dll\x64\pthreadVC2.dll" %PACKAGE_DIR%\bin\ >nul 2>&1
    echo       - pthreadVC2.dll
)

REM Copy GStreamer core DLLs
echo.
echo [3/6] Copying GStreamer core DLLs...
set GST_BIN=%GST_ROOT%\bin

REM Essential GStreamer core libraries
set CORE_DLLS=gstreamer-1.0-0.dll gstbase-1.0-0.dll gstvideo-1.0-0.dll gstaudio-1.0-0.dll
set CORE_DLLS=%CORE_DLLS% gstapp-1.0-0.dll gstpbutils-1.0-0.dll gstrtp-1.0-0.dll gstrtsp-1.0-0.dll
set CORE_DLLS=%CORE_DLLS% gstsdp-1.0-0.dll gsttag-1.0-0.dll gstfft-1.0-0.dll gstnet-1.0-0.dll
set CORE_DLLS=%CORE_DLLS% gstwebrtc-1.0-0.dll gstwebrtcnice-1.0-0.dll gstsctp-1.0-0.dll
set CORE_DLLS=%CORE_DLLS% gstcodecs-1.0-0.dll gstcodecparsers-1.0-0.dll gstdxva-1.0-0.dll
set CORE_DLLS=%CORE_DLLS% gstd3d11-1.0-0.dll gstgl-1.0-0.dll gstallocators-1.0-0.dll
set CORE_DLLS=%CORE_DLLS% gstcontroller-1.0-0.dll gstriff-1.0-0.dll gstcheck-1.0-0.dll

REM GLib and dependencies
set GLIB_DLLS=glib-2.0-0.dll gobject-2.0-0.dll gmodule-2.0-0.dll gio-2.0-0.dll gthread-2.0-0.dll
set GLIB_DLLS=%GLIB_DLLS% intl-8.dll ffi-7.dll pcre2-8-0.dll z-1.dll

REM Additional required libraries
set EXTRA_DLLS=nice-10.dll opus-0.dll libx264-157.dll orc-0.4-0.dll
set EXTRA_DLLS=%EXTRA_DLLS% libcrypto-1_1-x64.dll libssl-1_1-x64.dll srtp2-1.dll
set EXTRA_DLLS=%EXTRA_DLLS% json-glib-1.0-0.dll libxml2-2.dll

set COPY_COUNT=0
for %%D in (%CORE_DLLS% %GLIB_DLLS% %EXTRA_DLLS%) do (
    if exist "%GST_BIN%\%%D" (
        copy /Y "%GST_BIN%\%%D" %PACKAGE_DIR%\gstreamer\bin\ >nul 2>&1
        set /a COPY_COUNT+=1
    )
)
echo       Copied !COPY_COUNT! essential DLLs

REM Copy ALL DLLs from GStreamer bin to ensure nothing is missing
echo       Copying remaining GStreamer DLLs...
copy /Y "%GST_BIN%\*.dll" %PACKAGE_DIR%\gstreamer\bin\ >nul 2>&1
for /f %%A in ('dir /b "%PACKAGE_DIR%\gstreamer\bin\*.dll" 2^>nul ^| find /c /v ""') do set TOTAL_DLLS=%%A
echo       Total DLLs in gstreamer\bin: !TOTAL_DLLS!

REM Copy GStreamer plugins
echo.
echo [4/6] Copying GStreamer plugins...
set GST_PLUGINS=%GST_ROOT%\lib\gstreamer-1.0

REM Essential plugins for this application
set ESSENTIAL_PLUGINS=gstcoreelements.dll gstd3d12.dll gstd3d11.dll gstwebrtc.dll gstwebrtchttp.dll
set ESSENTIAL_PLUGINS=%ESSENTIAL_PLUGINS% gstx264.dll gstopus.dll gstwasapi.dll gstwasapi2.dll
set ESSENTIAL_PLUGINS=%ESSENTIAL_PLUGINS% gstaudioconvert.dll gstaudioresample.dll gstvideoconvertscale.dll
set ESSENTIAL_PLUGINS=%ESSENTIAL_PLUGINS% gstrtp.dll gstrtpmanager.dll gstudp.dll gsttcp.dll
set ESSENTIAL_PLUGINS=%ESSENTIAL_PLUGINS% gstnice.dll gstsrtp.dll gstdtls.dll gstsctp.dll
set ESSENTIAL_PLUGINS=%ESSENTIAL_PLUGINS% gstplayback.dll gsttypefindfunctions.dll gstautodetect.dll
set ESSENTIAL_PLUGINS=%ESSENTIAL_PLUGINS% gstvideoparsersbad.dll gstaudioparsers.dll
set ESSENTIAL_PLUGINS=%ESSENTIAL_PLUGINS% gstapp.dll gstgio.dll gstdirectsoundsrc.dll
set ESSENTIAL_PLUGINS=%ESSENTIAL_PLUGINS% gstrtmp2.dll gstflv.dll gstlibav.dll

REM Verify essential plugins exist
set MISSING_PLUGINS=
for %%P in (%ESSENTIAL_PLUGINS%) do (
    if not exist "%GST_PLUGINS%\%%P" (
        set MISSING_PLUGINS=!MISSING_PLUGINS! %%P
    )
)

if not "!MISSING_PLUGINS!"=="" (
    echo [WARNING] Some essential plugins not found:!MISSING_PLUGINS!
)

REM Copy ALL plugins to ensure nothing is missing
copy /Y "%GST_PLUGINS%\*.dll" %PACKAGE_DIR%\gstreamer\lib\gstreamer-1.0\ >nul 2>&1
for /f %%A in ('dir /b "%PACKAGE_DIR%\gstreamer\lib\gstreamer-1.0\*.dll" 2^>nul ^| find /c /v ""') do set TOTAL_PLUGINS=%%A
echo       Total plugins copied: !TOTAL_PLUGINS!

REM Verify critical plugins
echo       Verifying critical plugins...
set CRITICAL_OK=1
if not exist "%PACKAGE_DIR%\gstreamer\lib\gstreamer-1.0\gstd3d12.dll" (
    echo       [MISSING] gstd3d12.dll - Screen capture will not work!
    set CRITICAL_OK=0
)
if not exist "%PACKAGE_DIR%\gstreamer\lib\gstreamer-1.0\gstwebrtchttp.dll" (
    echo       [MISSING] gstwebrtchttp.dll - WHIP streaming will not work!
    set CRITICAL_OK=0
)
if not exist "%PACKAGE_DIR%\gstreamer\lib\gstreamer-1.0\gstx264.dll" (
    echo       [MISSING] gstx264.dll - H.264 encoding will not work!
    set CRITICAL_OK=0
)
if not exist "%PACKAGE_DIR%\gstreamer\lib\gstreamer-1.0\gstopus.dll" (
    echo       [MISSING] gstopus.dll - Opus audio encoding will not work!
    set CRITICAL_OK=0
)
if not exist "%PACKAGE_DIR%\gstreamer\lib\gstreamer-1.0\gstrtmp2.dll" (
    echo       [MISSING] gstrtmp2.dll - RTMP streaming will not work!
    set CRITICAL_OK=0
)
if not exist "%PACKAGE_DIR%\gstreamer\lib\gstreamer-1.0\gstflv.dll" (
    echo       [MISSING] gstflv.dll - FLV muxing for RTMP will not work!
    set CRITICAL_OK=0
)
if not exist "%PACKAGE_DIR%\gstreamer\lib\gstreamer-1.0\gstlibav.dll" (
    echo       [MISSING] gstlibav.dll - AAC audio encoding for RTMP will not work!
    set CRITICAL_OK=0
)
if !CRITICAL_OK!==1 (
    echo       [OK] All critical plugins present
)

REM Copy GStreamer utilities
echo.
echo [5/6] Copying GStreamer utilities...
if exist "%GST_BIN%\gst-inspect-1.0.exe" (
    copy /Y "%GST_BIN%\gst-inspect-1.0.exe" %PACKAGE_DIR%\gstreamer\bin\ >nul 2>&1
    echo       - gst-inspect-1.0.exe
)
if exist "%GST_BIN%\gst-launch-1.0.exe" (
    copy /Y "%GST_BIN%\gst-launch-1.0.exe" %PACKAGE_DIR%\gstreamer\bin\ >nul 2>&1
    echo       - gst-launch-1.0.exe
)
if exist "%GST_BIN%\gst-plugin-scanner.exe" (
    copy /Y "%GST_BIN%\gst-plugin-scanner.exe" %PACKAGE_DIR%\gstreamer\bin\ >nul 2>&1
    echo       - gst-plugin-scanner.exe
)
if exist "%GST_BIN%\gst-device-monitor-1.0.exe" (
    copy /Y "%GST_BIN%\gst-device-monitor-1.0.exe" %PACKAGE_DIR%\gstreamer\bin\ >nul 2>&1
    echo       - gst-device-monitor-1.0.exe
)

REM Create launcher script
echo.
echo [6/6] Creating launcher scripts...

REM Main launcher script
(
echo @echo off
echo setlocal
echo.
echo REM GameLift Streams IVS Broadcast Sidecar Sample Launcher
echo REM Sets up GStreamer environment and runs the application
echo.
echo REM Get the directory where this script is located
echo set SCRIPT_DIR=%%~dp0
echo set PACKAGE_ROOT=%%SCRIPT_DIR%%
echo.
echo REM Set up GStreamer environment
echo set PATH=%%PACKAGE_ROOT%%bin;%%PACKAGE_ROOT%%gstreamer\bin;%%PATH%%
echo set GST_PLUGIN_PATH=%%PACKAGE_ROOT%%gstreamer\lib\gstreamer-1.0
echo set GST_PLUGIN_SYSTEM_PATH=%%PACKAGE_ROOT%%gstreamer\lib\gstreamer-1.0
echo set GST_PLUGIN_SCANNER=%%PACKAGE_ROOT%%gstreamer\bin\gst-plugin-scanner.exe
echo set GST_REGISTRY=%%PACKAGE_ROOT%%gstreamer-registry.bin
echo.
echo REM Disable debug output by default ^(set GST_DEBUG=2 for warnings, 4 for info^)
echo set GST_DEBUG=0
echo.
echo REM Run the broadcast app with logging
echo if not exist "%%PACKAGE_ROOT%%logs" mkdir "%%PACKAGE_ROOT%%logs"
echo "%%PACKAGE_ROOT%%bin\gamelift-streams-ivs-broadcast-sidecar-sample.exe" %%* ^> "%%PACKAGE_ROOT%%logs\broadcaster.log" 2^>^&1
echo.
echo start "explorer.exe"
) > %PACKAGE_DIR%\run_broadcaster.bat
echo       - run_broadcaster.bat

REM Create background launcher (for game integration)
(
echo @echo off
echo setlocal
echo.
echo REM GameLift Streams IVS Broadcast Sidecar Sample - Background Launcher
echo REM Starts the broadcaster in background, then runs your game
echo.
echo set SCRIPT_DIR=%%~dp0
echo set PACKAGE_ROOT=%%SCRIPT_DIR%%
echo.
echo REM Set up GStreamer environment
echo set PATH=%%PACKAGE_ROOT%%bin;%%PACKAGE_ROOT%%gstreamer\bin;%%PATH%%
echo set GST_PLUGIN_PATH=%%PACKAGE_ROOT%%gstreamer\lib\gstreamer-1.0
echo set GST_PLUGIN_SYSTEM_PATH=%%PACKAGE_ROOT%%gstreamer\lib\gstreamer-1.0
echo set GST_PLUGIN_SCANNER=%%PACKAGE_ROOT%%gstreamer\bin\gst-plugin-scanner.exe
echo set GST_REGISTRY=%%PACKAGE_ROOT%%gstreamer-registry.bin
echo set GST_DEBUG=0
echo.
echo REM Start the broadcaster in background with logging ^(minimized^)
echo REM For WHIP ^(the default^), set IVS_STAGE_TOKEN and IVS_WHIP_ENDPOINT env
echo REM vars, or pass --auth-token and --whip-endpoint arguments
echo REM For RTMP, set INGEST_TYPE=rtmp plus RTMP_ENDPOINT and STREAM_KEY env
echo REM vars, or pass --ingest-type rtmp --rtmp-endpoint and --stream-key
echo if not exist "%%PACKAGE_ROOT%%logs" mkdir "%%PACKAGE_ROOT%%logs"
echo start /MIN "GameLift-IVS-Broadcaster" cmd /c "%%PACKAGE_ROOT%%bin\gamelift-streams-ivs-broadcast-sidecar-sample.exe" %%* ^> "%%PACKAGE_ROOT%%logs\broadcaster.log" 2^>^&1
echo.
echo REM Add your game executable below:
echo REM your-game.exe
echo.
echo REM Optionally terminate the broadcaster when the game exits
echo taskkill /IM gamelift-streams-ivs-broadcast-sidecar-sample.exe /F
) > %PACKAGE_DIR%\run_broadcaster_background.bat
echo       - run_broadcaster_background.bat

REM Create test script
(
echo @echo off
echo setlocal
echo.
echo echo Testing GameLift Streams IVS Broadcast Sidecar Sample Package
echo echo ==========================================
echo echo.
echo.
echo set SCRIPT_DIR=%%~dp0
echo set PACKAGE_ROOT=%%SCRIPT_DIR%%
echo.
echo REM Set up environment
echo set PATH=%%PACKAGE_ROOT%%bin;%%PACKAGE_ROOT%%gstreamer\bin;%%PATH%%
echo set GST_PLUGIN_PATH=%%PACKAGE_ROOT%%gstreamer\lib\gstreamer-1.0
echo set GST_PLUGIN_SYSTEM_PATH=%%PACKAGE_ROOT%%gstreamer\lib\gstreamer-1.0
echo set GST_PLUGIN_SCANNER=%%PACKAGE_ROOT%%gstreamer\bin\gst-plugin-scanner.exe
echo set GST_REGISTRY=%%PACKAGE_ROOT%%gstreamer-registry.bin
echo.
echo echo [1/4] Checking executable...
echo if exist "%%PACKAGE_ROOT%%bin\gamelift-streams-ivs-broadcast-sidecar-sample.exe" ^(
echo     echo       [OK] gamelift-streams-ivs-broadcast-sidecar-sample.exe found
echo ^) else ^(
echo     echo       [FAIL] gamelift-streams-ivs-broadcast-sidecar-sample.exe NOT found
echo     exit /b 1
echo ^)
echo.
echo echo [2/4] Checking GStreamer core...
echo "%%PACKAGE_ROOT%%gstreamer\bin\gst-inspect-1.0.exe" --version ^>nul 2^>^&1
echo if errorlevel 1 ^(
echo     echo       [FAIL] GStreamer not working
echo     exit /b 1
echo ^) else ^(
echo     echo       [OK] GStreamer core working
echo ^)
echo.
echo echo [3/4] Checking critical plugins...
echo "%%PACKAGE_ROOT%%gstreamer\bin\gst-inspect-1.0.exe" d3d12screencapturesrc ^>nul 2^>^&1
echo if errorlevel 1 ^(echo       [WARN] d3d12screencapturesrc not found^) else ^(echo       [OK] d3d12screencapturesrc^)
echo "%%PACKAGE_ROOT%%gstreamer\bin\gst-inspect-1.0.exe" whipsink ^>nul 2^>^&1
echo if errorlevel 1 ^(echo       [WARN] whipsink not found^) else ^(echo       [OK] whipsink^)
echo "%%PACKAGE_ROOT%%gstreamer\bin\gst-inspect-1.0.exe" x264enc ^>nul 2^>^&1
echo if errorlevel 1 ^(echo       [WARN] x264enc not found^) else ^(echo       [OK] x264enc^)
echo "%%PACKAGE_ROOT%%gstreamer\bin\gst-inspect-1.0.exe" opusenc ^>nul 2^>^&1
echo if errorlevel 1 ^(echo       [WARN] opusenc not found^) else ^(echo       [OK] opusenc^)
echo "%%PACKAGE_ROOT%%gstreamer\bin\gst-inspect-1.0.exe" wasapisrc ^>nul 2^>^&1
echo if errorlevel 1 ^(echo       [WARN] wasapisrc not found^) else ^(echo       [OK] wasapisrc^)
echo "%%PACKAGE_ROOT%%gstreamer\bin\gst-inspect-1.0.exe" rtmp2sink ^>nul 2^>^&1
echo if errorlevel 1 ^(echo       [WARN] rtmp2sink not found^) else ^(echo       [OK] rtmp2sink^)
echo "%%PACKAGE_ROOT%%gstreamer\bin\gst-inspect-1.0.exe" flvmux ^>nul 2^>^&1
echo if errorlevel 1 ^(echo       [WARN] flvmux not found^) else ^(echo       [OK] flvmux^)
echo "%%PACKAGE_ROOT%%gstreamer\bin\gst-inspect-1.0.exe" avenc_aac ^>nul 2^>^&1
echo if errorlevel 1 ^(echo       [WARN] avenc_aac not found^) else ^(echo       [OK] avenc_aac^)
echo.
echo echo [4/4] Testing application...
echo "%%PACKAGE_ROOT%%bin\gamelift-streams-ivs-broadcast-sidecar-sample.exe" --help 2^>^&1 ^| findstr /C:"Usage:" ^>nul
echo if errorlevel 1 ^(
echo     echo       [FAIL] Application failed to run
echo     exit /b 1
echo ^) else ^(
echo     echo       [OK] Application runs successfully
echo ^)
echo.
echo echo ==========================================
echo echo Package test complete!
echo echo ==========================================
) > %PACKAGE_DIR%\test_package.bat
echo       - test_package.bat

REM Create ZIP archive
echo.
echo ========================================
echo Creating ZIP archive...
set ZIP_NAME=gamelift-streams-ivs-broadcast-sidecar-sample-windows.zip
if exist "%ZIP_NAME%" del /Q "%ZIP_NAME%"

powershell -Command "Compress-Archive -Path '%PACKAGE_DIR%\*' -DestinationPath '%ZIP_NAME%' -Force" 2>nul
if errorlevel 1 (
    echo [WARNING] Failed to create ZIP archive
    echo You can manually zip the %PACKAGE_DIR% directory
) else (
    for %%A in ("%ZIP_NAME%") do set ZIP_SIZE=%%~zA
    set /a ZIP_SIZE_MB=!ZIP_SIZE! / 1048576
    echo [OK] ZIP archive created: %ZIP_NAME% ^(!ZIP_SIZE_MB! MB^)
)

REM Summary
echo.
echo ========================================
echo Packaging Complete!
echo ========================================
echo.
echo Package contents:
echo   bin\
echo     - gamelift-streams-ivs-broadcast-sidecar-sample.exe
echo     - MSVC runtime DLLs
echo   gstreamer\bin\
for /f %%A in ('dir /b "%PACKAGE_DIR%\gstreamer\bin\*.dll" 2^>nul ^| find /c /v ""') do echo     - %%A DLLs
echo   gstreamer\lib\gstreamer-1.0\
for /f %%A in ('dir /b "%PACKAGE_DIR%\gstreamer\lib\gstreamer-1.0\*.dll" 2^>nul ^| find /c /v ""') do echo     - %%A plugins
echo.
echo Scripts:
echo   - run_broadcaster.bat           (main launcher)
echo   - run_broadcaster_background.bat (for game integration)
echo   - test_package.bat              (verify package works)
echo.
echo Output:
echo   Directory: %PACKAGE_DIR%
echo   ZIP file:  %ZIP_NAME%
echo.
echo To test the package:
echo   cd %PACKAGE_DIR%
echo   test_package.bat
echo.
echo To run the broadcaster over WHIP (default):
echo   cd %PACKAGE_DIR%
echo   run_broadcaster.bat --auth-token YOUR_TOKEN --whip-endpoint YOUR_URL
echo.
echo To run the broadcaster over RTMP:
echo   cd %PACKAGE_DIR%
echo   run_broadcaster.bat --ingest-type rtmp --rtmp-endpoint YOUR_URL --stream-key YOUR_KEY
echo.

endlocal
