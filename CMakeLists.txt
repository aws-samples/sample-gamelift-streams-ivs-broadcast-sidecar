cmake_minimum_required(VERSION 3.20)
project(gamelift-streams-ivs-broadcast-sidecar-sample C)

# Set C standard
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# =============================================================================
# Platform Detection
# =============================================================================
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(PLATFORM_WINDOWS TRUE)
    set(PLATFORM_NAME "Windows")
    message(STATUS "Building for Windows platform")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(PLATFORM_LINUX TRUE)
    set(PLATFORM_NAME "Linux")
    message(STATUS "Building for Linux platform")
else()
    message(FATAL_ERROR "Unsupported platform: ${CMAKE_SYSTEM_NAME}")
endif()

# =============================================================================
# Platform-Specific Compiler Flags
# =============================================================================
if(PLATFORM_WINDOWS)
    # Enable static linking on Windows
    set(BUILD_SHARED_LIBS OFF)
    set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".lib")
    
    # Visual Studio 2022 MSVC toolchain compatibility
    if(MSVC)
        # Enable multi-processor compilation
        add_compile_options(/MP)
        # Set warning level
        add_compile_options(/W3)
        # Use static runtime library
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    endif()
    
    # Define Windows platform macro
    add_compile_definitions(PLATFORM_WINDOWS=1)
    add_compile_definitions(_WIN32_WINNT=0x0A00)  # Windows 10+
    
elseif(PLATFORM_LINUX)
    # Linux compiler flags (GCC/Clang)
    add_compile_options(-Wall -Wextra -Wpedantic)
    
    # Enable position-independent code for shared library compatibility
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
    
    # Define Linux platform macro
    add_compile_definitions(PLATFORM_LINUX=1)
    
    # Enable X11 support
    add_compile_definitions(HAVE_X11=1)
endif()

# =============================================================================
# Find pkg-config
# =============================================================================
find_package(PkgConfig REQUIRED)

# =============================================================================
# GStreamer Libraries (Common)
# =============================================================================
pkg_check_modules(GSTREAMER REQUIRED gstreamer-1.0)
pkg_check_modules(GSTREAMER_VIDEO REQUIRED gstreamer-video-1.0)
pkg_check_modules(GSTREAMER_AUDIO REQUIRED gstreamer-audio-1.0)

# =============================================================================
# Platform-Specific GStreamer Plugin Requirements
# =============================================================================
if(PLATFORM_WINDOWS)
    # Windows: D3D12 for screen capture, WASAPI for audio
    # These are typically bundled with GStreamer on Windows
    message(STATUS "Windows GStreamer plugins required:")
    message(STATUS "  - d3d12 (screen capture)")
    message(STATUS "  - wasapi2 (audio capture)")
    message(STATUS "  - x264 (CPU video encoding)")
    message(STATUS "  - nvcodec (optional GPU video encoding)")
    message(STATUS "  - opus (audio encoding for WHIP)")
    message(STATUS "  - webrtc/whip (WHIP streaming)")
    message(STATUS "  - rtmp2sink (RTMP streaming)")
    message(STATUS "  - flvmux (FLV muxing for RTMP)")
    message(STATUS "  - avenc_aac (AAC audio encoding for RTMP)")
    
elseif(PLATFORM_LINUX)
    # Linux: X11 for screen capture, PulseAudio/ALSA for audio
    # Check for X11 development libraries
    find_package(X11)
    if(X11_FOUND)
        message(STATUS "X11 found: ${X11_INCLUDE_DIR}")
    else()
        message(WARNING "X11 not found - screen capture may not work")
    endif()
    
    # Check for PulseAudio (optional, autoaudiosrc will handle fallback)
    pkg_check_modules(PULSEAUDIO libpulse)
    if(PULSEAUDIO_FOUND)
        message(STATUS "PulseAudio found")
        add_compile_definitions(HAVE_PULSEAUDIO=1)
    else()
        message(STATUS "PulseAudio not found - will use autoaudiosrc")
    endif()
    
    message(STATUS "Linux GStreamer plugins required:")
    message(STATUS "  - ximagesrc (screen capture)")
    message(STATUS "  - videoconvert (format conversion)")
    message(STATUS "  - x264 (CPU video encoding)")
    message(STATUS "  - nvcodec (optional GPU video encoding)")
    message(STATUS "  - opus (audio encoding for WHIP)")
    message(STATUS "  - webrtc/whip (WHIP streaming)")
    message(STATUS "  - rtmp2sink (RTMP streaming)")
    message(STATUS "  - flvmux (FLV muxing for RTMP)")
    message(STATUS "  - avenc_aac (AAC audio encoding for RTMP)")
endif()

# =============================================================================
# Find pthread library
# =============================================================================
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

# =============================================================================
# Include Directories
# =============================================================================
include_directories(
    ${GSTREAMER_INCLUDE_DIRS}
    ${GSTREAMER_VIDEO_INCLUDE_DIRS}
    ${GSTREAMER_AUDIO_INCLUDE_DIRS}
)

if(PLATFORM_LINUX AND X11_FOUND)
    include_directories(${X11_INCLUDE_DIR})
endif()

# =============================================================================
# Link Directories
# =============================================================================
link_directories(
    ${GSTREAMER_LIBRARY_DIRS}
    ${GSTREAMER_VIDEO_LIBRARY_DIRS}
    ${GSTREAMER_AUDIO_LIBRARY_DIRS}
)

# =============================================================================
# Source Files
# =============================================================================
set(SOURCES
    main.c
    config.c
    pipeline.c
    message_handler.c
)

# =============================================================================
# Main Executable Target
# =============================================================================
add_executable(gamelift-streams-ivs-broadcast-sidecar-sample ${SOURCES})

# =============================================================================
# Platform-Specific Library Linking
# =============================================================================
if(PLATFORM_WINDOWS)
    # Windows: Link GStreamer statically if available, otherwise dynamically
    target_link_libraries(gamelift-streams-ivs-broadcast-sidecar-sample
        ${GSTREAMER_LIBRARIES}
        ${GSTREAMER_VIDEO_LIBRARIES}
        ${GSTREAMER_AUDIO_LIBRARIES}
        Threads::Threads
    )
    
    # Link Windows-specific libraries
    target_link_libraries(gamelift-streams-ivs-broadcast-sidecar-sample
        ole32
        oleaut32
        uuid
    )
    
    # Static linking option for Windows
    if(MSVC)
        target_link_options(gamelift-streams-ivs-broadcast-sidecar-sample PRIVATE /NODEFAULTLIB:MSVCRT)
    else()
        target_link_options(gamelift-streams-ivs-broadcast-sidecar-sample PRIVATE -static)
    endif()
    
elseif(PLATFORM_LINUX)
    # Linux: Link GStreamer dynamically (standard on Linux)
    target_link_libraries(gamelift-streams-ivs-broadcast-sidecar-sample
        ${GSTREAMER_LIBRARIES}
        ${GSTREAMER_VIDEO_LIBRARIES}
        ${GSTREAMER_AUDIO_LIBRARIES}
        Threads::Threads
    )
    
    # Link X11 if available
    if(X11_FOUND)
        target_link_libraries(gamelift-streams-ivs-broadcast-sidecar-sample ${X11_LIBRARIES})
    endif()
    
    # Link PulseAudio if available
    if(PULSEAUDIO_FOUND)
        target_link_libraries(gamelift-streams-ivs-broadcast-sidecar-sample ${PULSEAUDIO_LIBRARIES})
    endif()
    
    # Link math library (common on Linux)
    target_link_libraries(gamelift-streams-ivs-broadcast-sidecar-sample m)
endif()

# =============================================================================
# Compiler Options from pkg-config
# =============================================================================
target_compile_options(gamelift-streams-ivs-broadcast-sidecar-sample PRIVATE
    ${GSTREAMER_CFLAGS_OTHER}
)

# =============================================================================
# Test Executables
# =============================================================================

# Test executable for configuration module
add_executable(test_config test_config.c config.c)
target_link_libraries(test_config
    ${GSTREAMER_LIBRARIES}
    ${GSTREAMER_VIDEO_LIBRARIES}
    ${GSTREAMER_AUDIO_LIBRARIES}
    Threads::Threads
)
if(PLATFORM_LINUX)
    target_link_libraries(test_config m)
endif()

# Test executable for pipeline module
add_executable(test_pipeline test_pipeline.c config.c pipeline.c)
target_link_libraries(test_pipeline
    ${GSTREAMER_LIBRARIES}
    ${GSTREAMER_VIDEO_LIBRARIES}
    ${GSTREAMER_AUDIO_LIBRARIES}
    Threads::Threads
)
if(PLATFORM_LINUX)
    target_link_libraries(test_pipeline m)
    if(X11_FOUND)
        target_link_libraries(test_pipeline ${X11_LIBRARIES})
    endif()
endif()

# =============================================================================
# Installation Rules (Optional)
# =============================================================================
install(TARGETS gamelift-streams-ivs-broadcast-sidecar-sample
    RUNTIME DESTINATION bin
)

# =============================================================================
# Summary
# =============================================================================
message(STATUS "")
message(STATUS "=== Build Configuration Summary ===")
message(STATUS "Platform: ${PLATFORM_NAME}")
message(STATUS "C Standard: ${CMAKE_C_STANDARD}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
if(PLATFORM_WINDOWS)
    message(STATUS "Screen Capture: D3D12 (d3d12screencapturesrc)")
    message(STATUS "Audio Capture: WASAPI2 (wasapi2src)")
    message(STATUS "GPU Encoder: nvcudah264enc (NVIDIA)")
elseif(PLATFORM_LINUX)
    message(STATUS "Screen Capture: X11 (ximagesrc)")
    message(STATUS "Audio Capture: autoaudiosrc (PulseAudio/ALSA)")
    message(STATUS "GPU Encoder: nvcudah264enc (NVIDIA)")
endif()
message(STATUS "CPU Encoder: x264enc")
message(STATUS "===================================")
message(STATUS "")
