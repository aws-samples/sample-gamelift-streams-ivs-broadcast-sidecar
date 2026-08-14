@echo off
REM Build script for GameLift Streams IVS Broadcast Sidecar Sample
REM Requires Visual Studio 2022 and GStreamer installed

echo Setting up Visual Studio 2022 environment...

REM Set up Visual Studio 2022 MSVC environment
REM Adjust path if Visual Studio is installed in a different location
set VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build
if not exist "%VS_PATH%\vcvarsall.bat" (
    set VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build
)
if not exist "%VS_PATH%\vcvarsall.bat" (
    set VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build
)
if not exist "%VS_PATH%\vcvarsall.bat" (
    echo ERROR: Could not find Visual Studio 2022 installation
    echo Please install Visual Studio 2022 or adjust the VS_PATH in this script
    exit /b 1
)

call "%VS_PATH%\vcvarsall.bat" x64
if errorlevel 1 (
    echo ERROR: Failed to set up Visual Studio environment
    exit /b 1
)

echo Visual Studio environment configured successfully

REM Create build directory if it doesn't exist
if not exist build-win mkdir build-win
cd build-win

echo Running CMake with NMake generator...
cmake -G "NMake Makefiles" ..
if errorlevel 1 (
    echo ERROR: CMake configuration failed
    echo Make sure GStreamer is installed and PKG_CONFIG_PATH is set correctly
    cd ..
    exit /b 1
)

echo Building project...
nmake
if errorlevel 1 (
    echo ERROR: Build failed
    cd ..
    exit /b 1
)

echo Windows build completed successfully!
echo.
echo Executable location: build-win\gamelift-streams-ivs-broadcast-sidecar-sample.exe
echo.
echo To run the application, configure the required parameters:
echo   set IVS_STAGE_TOKEN=your_token
echo   set IVS_WHIP_ENDPOINT=https://your-endpoint/whip
echo   build-win\gamelift-streams-ivs-broadcast-sidecar-sample.exe
echo.
echo Or use command-line arguments:
echo   build-win\gamelift-streams-ivs-broadcast-sidecar-sample.exe --auth-token your_token --whip-endpoint https://your-endpoint/whip
echo.
cd ..
