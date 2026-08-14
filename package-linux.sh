#!/bin/bash
# Packaging script for GameLift Streams IVS Broadcast Sidecar Sample on Linux
# Creates a self-contained distributable package with all dependencies bundled
# No system dependencies need to be installed on the target GameLift Streams instance
#
# IMPORTANT: This script expects GStreamer to be built from source with the Rust plugins.
# The custom GStreamer installation should be at ~/gstreamer-install (or set GST_PREFIX).
# See README.md for build instructions.

set -e  # Exit on error

echo "========================================"
echo "GameLift Streams IVS Broadcast Sidecar Sample - Linux Packaging"
echo "========================================"
echo ""

# =============================================================================
# Color output helpers
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_info() {
    echo "$1"
}

# =============================================================================
# Detect GStreamer installation (custom build or system)
# =============================================================================
# Check for custom GStreamer build first (required for whipsink)
GST_PREFIX="${GST_PREFIX:-$HOME/gstreamer-install}"

if [ -d "$GST_PREFIX/lib/x86_64-linux-gnu" ]; then
    GST_LIB_DIR="$GST_PREFIX/lib/x86_64-linux-gnu"
    GST_PLUGIN_DIR="$GST_LIB_DIR/gstreamer-1.0"
    GST_BIN_DIR="$GST_PREFIX/bin"
    print_success "[OK] Found custom GStreamer build at: $GST_PREFIX"
elif [ -d "$GST_PREFIX/lib" ] && [ -f "$GST_PREFIX/lib/libgstreamer-1.0.so.0" ]; then
    GST_LIB_DIR="$GST_PREFIX/lib"
    GST_PLUGIN_DIR="$GST_LIB_DIR/gstreamer-1.0"
    GST_BIN_DIR="$GST_PREFIX/bin"
    print_success "[OK] Found custom GStreamer build at: $GST_PREFIX"
else
    print_error "Custom GStreamer build not found at: $GST_PREFIX"
    echo ""
    echo "This application requires GStreamer built from source with Rust plugins (whipsink)."
    echo "Please follow the build instructions in README.md to build GStreamer first."
    echo ""
    echo "Expected location: ~/gstreamer-install"
    echo "Or set GST_PREFIX environment variable to your GStreamer installation path."
    exit 1
fi

# Verify whipsink plugin exists
if [ ! -f "$GST_PLUGIN_DIR/libgstrswebrtc.so" ]; then
    print_error "whipsink plugin (libgstrswebrtc.so) not found in: $GST_PLUGIN_DIR"
    echo ""
    echo "The GStreamer Rust plugins were not built. Please rebuild GStreamer with:"
    echo "  meson setup builddir --prefix=\$HOME/gstreamer-install -Drs=enabled -Dgpl=enabled"
    echo "  ninja -C builddir && ninja -C builddir install"
    exit 1
fi
print_success "[OK] Found whipsink plugin (libgstrswebrtc.so)"

# =============================================================================
# Check if build exists
# =============================================================================
BUILD_DIR="build-linux"
BINARY_NAME="gamelift-streams-ivs-broadcast-sidecar-sample"

if [ ! -f "$BUILD_DIR/$BINARY_NAME" ]; then
    print_error "Build not found at $BUILD_DIR/$BINARY_NAME"
    echo "Please run ./build-linux.sh first."
    exit 1
fi

print_success "[OK] Found binary at: $BUILD_DIR/$BINARY_NAME"
echo ""

# =============================================================================
# Create package directory structure
# =============================================================================
PACKAGE_DIR="gamelift-streams-ivs-broadcast-sidecar-sample-linux"

echo "Creating package directory: $PACKAGE_DIR"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR/bin"
mkdir -p "$PACKAGE_DIR/lib"
mkdir -p "$PACKAGE_DIR/gstreamer/lib/gstreamer-1.0"
mkdir -p "$PACKAGE_DIR/gstreamer/bin"
mkdir -p "$PACKAGE_DIR/gstreamer/libexec"

# =============================================================================
# Copy main executable
# =============================================================================
echo ""
echo "[1/6] Copying main executable..."
cp "$BUILD_DIR/$BINARY_NAME" "$PACKAGE_DIR/bin/"
chmod +x "$PACKAGE_DIR/bin/$BINARY_NAME"
print_info "       - $BINARY_NAME"

# =============================================================================
# Function to copy a library and follow symlinks
# =============================================================================
copy_lib() {
    local lib_path="$1"
    local dest_dir="$2"
    
    if [ ! -e "$lib_path" ]; then
        return 0
    fi
    
    local lib_name
    lib_name=$(basename "$lib_path")
    
    # Skip if already copied
    if [ -e "$dest_dir/$lib_name" ]; then
        return 0
    fi
    
    # Copy the file/symlink
    cp -P "$lib_path" "$dest_dir/" 2>/dev/null || true
    
    # If it's a symlink, also copy the target
    if [ -L "$lib_path" ]; then
        local target
        target=$(readlink -f "$lib_path" 2>/dev/null) || true
        if [ -n "$target" ] && [ -f "$target" ]; then
            local target_name
            target_name=$(basename "$target")
            if [ ! -e "$dest_dir/$target_name" ]; then
                cp -P "$target" "$dest_dir/" 2>/dev/null || true
            fi
        fi
    fi
}

# =============================================================================
# Bundle GStreamer libraries from custom build
# =============================================================================
echo ""
echo "[2/6] Bundling GStreamer libraries and plugins from custom build..."
print_info "       Source: $GST_LIB_DIR"

# Copy ALL GStreamer libraries from custom build
echo "       Copying GStreamer core libraries..."
GST_LIB_COUNT=0
for file in "$GST_LIB_DIR"/libgst*.so*; do
    if [ -e "$file" ]; then
        copy_lib "$file" "$PACKAGE_DIR/lib"
        ((GST_LIB_COUNT++)) || true
    fi
done
print_info "       Copied $GST_LIB_COUNT GStreamer library files"

# Copy ALL GStreamer plugins from custom build
echo "       Copying GStreamer plugins..."
PLUGINS_COPIED=0
for plugin in "$GST_PLUGIN_DIR"/*.so; do
    if [ -f "$plugin" ]; then
        cp "$plugin" "$PACKAGE_DIR/gstreamer/lib/gstreamer-1.0/"
        ((PLUGINS_COPIED++)) || true
    fi
done
print_info "       Copied $PLUGINS_COPIED GStreamer plugins"

# Verify critical plugins were copied
# Note: In GStreamer 1.24+, videoscale and videoconvert are in libgstvideoconvertscale.so
CRITICAL_PLUGINS="libgstrswebrtc.so libgstwebrtchttp.so libgstcoreelements.so libgstximagesrc.so libgstx264.so libgstopus.so libgstvideoconvertscale.so libgstvideorate.so libgstrtmp2.so libgstflv.so libgstlibav.so"
for plugin in $CRITICAL_PLUGINS; do
    if [ ! -f "$PACKAGE_DIR/gstreamer/lib/gstreamer-1.0/$plugin" ]; then
        print_warning "Critical plugin missing: $plugin"
    fi
done

# Copy GStreamer tools from custom build
echo "       Copying GStreamer tools..."
for tool in gst-launch-1.0 gst-inspect-1.0 gst-typefind-1.0 gst-device-monitor-1.0; do
    if [ -f "$GST_BIN_DIR/$tool" ]; then
        cp "$GST_BIN_DIR/$tool" "$PACKAGE_DIR/gstreamer/bin/"
        print_info "       - $tool"
    fi
done

# Copy gst-plugin-scanner from custom build
for scanner_path in \
    "$GST_PREFIX/libexec/gstreamer-1.0/gst-plugin-scanner" \
    "$GST_LIB_DIR/gstreamer-1.0/gst-plugin-scanner" \
    "$GST_PREFIX/lib/gstreamer-1.0/gst-plugin-scanner"
do
    if [ -f "$scanner_path" ]; then
        cp "$scanner_path" "$PACKAGE_DIR/gstreamer/libexec/"
        print_info "       - gst-plugin-scanner"
        break
    fi
done

# =============================================================================
# Bundle system dependencies (minimal set for this pipeline)
# =============================================================================
echo ""
echo "[3/6] Bundling system dependencies..."

# System library directories to search
SYS_LIB_DIRS="/usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib /lib/x86_64-linux-gnu"

# Copy GLib and related libraries (required by GStreamer)
echo "       Copying GLib and core libraries..."
for pattern in \
    "libglib-2.0.so*" \
    "libgobject-2.0.so*" \
    "libgio-2.0.so*" \
    "libgmodule-2.0.so*" \
    "libgthread-2.0.so*"
do
    for dir in $SYS_LIB_DIRS; do
        for file in "$dir"/$pattern; do
            if [ -e "$file" ]; then
                copy_lib "$file" "$PACKAGE_DIR/lib"
            fi
        done
    done
done

# Copy libnice from custom GStreamer build (critical for WebRTC ICE)
echo "       Copying libnice from custom build..."
for file in "$GST_LIB_DIR"/libnice*.so*; do
    if [ -e "$file" ]; then
        copy_lib "$file" "$PACKAGE_DIR/lib"
    fi
done

# Copy codec libraries (only what we actually use)
echo "       Copying codec libraries..."
for pattern in \
    "libopus.so*" \
    "libx264.so*" \
    "libsrtp2.so*"
do
    for dir in $SYS_LIB_DIRS; do
        for file in "$dir"/$pattern; do
            if [ -e "$file" ]; then
                copy_lib "$file" "$PACKAGE_DIR/lib"
            fi
        done
    done
done

echo "       Copying SSL/TLS and network libraries..."
for pattern in \
    "libssl.so*" \
    "libcrypto.so*" \
    "libsoup-3.0.so*" \
    "libsoup-2.4.so*" \
    "libjson-glib-1.0.so*" \
    "libpsl.so*" \
    "libbrotlidec.so*" \
    "libbrotlicommon.so*" \
    "libnghttp2.so*" \
    "libgnutls.so*" \
    "libp11-kit.so*" \
    "libtasn1.so*" \
    "libidn2.so*" \
    "libunistring.so*" \
    "libnettle.so*" \
    "libhogweed.so*" \
    "libgmp.so*"
do
    for dir in $SYS_LIB_DIRS; do
        for file in "$dir"/$pattern; do
            if [ -e "$file" ]; then
                copy_lib "$file" "$PACKAGE_DIR/lib"
            fi
        done
    done
done

echo "       Copying X11 libraries (for screen capture)..."
for pattern in \
    "libX11.so*" \
    "libX11-xcb.so*" \
    "libXext.so*" \
    "libXfixes.so*" \
    "libXdamage.so*" \
    "libxcb.so*" \
    "libxcb-shm.so*" \
    "libxcb-xfixes.so*" \
    "libXau.so*" \
    "libXdmcp.so*"
do
    for dir in $SYS_LIB_DIRS; do
        for file in "$dir"/$pattern; do
            if [ -e "$file" ]; then
                copy_lib "$file" "$PACKAGE_DIR/lib"
            fi
        done
    done
done

echo "       Copying audio libraries..."
for pattern in \
    "libpulse.so*" \
    "libpulse-simple.so*" \
    "libpulse-mainloop-glib.so*" \
    "libasound.so*" \
    "libsndfile.so*"
do
    for dir in $SYS_LIB_DIRS; do
        for file in "$dir"/$pattern; do
            if [ -e "$file" ]; then
                copy_lib "$file" "$PACKAGE_DIR/lib"
            fi
        done
    done
done

echo "       Copying utility libraries..."
for pattern in \
    "liborc-0.4.so*" \
    "libffi.so*" \
    "libpcre.so*" \
    "libpcre2-8.so*" \
    "libz.so*" \
    "libbz2.so*" \
    "liblzma.so*" \
    "libzstd.so*" \
    "libexpat.so*" \
    "libuuid.so*" \
    "libmount.so*" \
    "libblkid.so*" \
    "libselinux.so*" \
    "libsystemd.so*" \
    "libdbus-1.so*" \
    "libcap.so*" \
    "libgcrypt.so*" \
    "libgpg-error.so*" \
    "liblz4.so*" \
    "libstdc++.so*" \
    "libgcc_s.so*"
do
    for dir in $SYS_LIB_DIRS; do
        for file in "$dir"/$pattern; do
            if [ -e "$file" ]; then
                copy_lib "$file" "$PACKAGE_DIR/lib"
            fi
        done
    done
done

# =============================================================================
# Resolve dependencies using ldd (optimized single pass)
# =============================================================================
echo "       Resolving additional dependencies with ldd..."

# Collect all binaries to check in one list
ALL_BINARIES=$(mktemp)
echo "$PACKAGE_DIR/bin/$BINARY_NAME" >> "$ALL_BINARIES"
find "$PACKAGE_DIR/gstreamer/bin" -type f >> "$ALL_BINARIES" 2>/dev/null || true
find "$PACKAGE_DIR/gstreamer/lib/gstreamer-1.0" -name "*.so" -type f >> "$ALL_BINARIES" 2>/dev/null || true

# Run ldd on all binaries and collect unique dependencies
echo "       Analyzing dependencies (this may take a moment)..."
DEPS_LIST=$(mktemp)

while IFS= read -r binary; do
    if [ -f "$binary" ]; then
        LD_LIBRARY_PATH="$GST_LIB_DIR:$PACKAGE_DIR/lib:${LD_LIBRARY_PATH:-}" ldd "$binary" 2>/dev/null | \
            sed -n 's/.*=> \(\/[^ ]*\).*/\1/p' >> "$DEPS_LIST"
    fi
done < "$ALL_BINARIES"

# Sort unique and copy missing deps
sort -u "$DEPS_LIST" | while IFS= read -r lib_path; do
    if [ -n "$lib_path" ] && [ -f "$lib_path" ]; then
        lib_name=$(basename "$lib_path")
        
        # Skip core system libraries that should not be bundled
        case "$lib_name" in
            libc.so*|libm.so*|libdl.so*|libpthread.so*|librt.so*|ld-linux*.so*|linux-vdso.so*|libresolv.so*|libnss*.so*|libnsl.so*)
                continue
                ;;
        esac
        
        if [ ! -e "$PACKAGE_DIR/lib/$lib_name" ]; then
            cp -P "$lib_path" "$PACKAGE_DIR/lib/" 2>/dev/null || true
            # Also copy symlink target if needed
            if [ -L "$lib_path" ]; then
                target=$(readlink -f "$lib_path" 2>/dev/null) || true
                if [ -n "$target" ] && [ -f "$target" ]; then
                    target_name=$(basename "$target")
                    if [ ! -e "$PACKAGE_DIR/lib/$target_name" ]; then
                        cp -P "$target" "$PACKAGE_DIR/lib/" 2>/dev/null || true
                    fi
                fi
            fi
        fi
    fi
done

# Cleanup temp files
rm -f "$ALL_BINARIES" "$DEPS_LIST"

# Second pass: resolve deps of newly added libs
echo "       Resolving transitive dependencies..."
for lib in "$PACKAGE_DIR/lib"/*.so*; do
    if [ -f "$lib" ] && [ ! -L "$lib" ]; then
        LD_LIBRARY_PATH="$PACKAGE_DIR/lib:${LD_LIBRARY_PATH:-}" ldd "$lib" 2>/dev/null | \
            sed -n 's/.*=> \(\/[^ ]*\).*/\1/p' | while IFS= read -r dep_path; do
            if [ -n "$dep_path" ] && [ -f "$dep_path" ]; then
                dep_name=$(basename "$dep_path")
                case "$dep_name" in
                    libc.so*|libm.so*|libdl.so*|libpthread.so*|librt.so*|ld-linux*.so*|linux-vdso.so*|libresolv.so*|libnss*.so*|libnsl.so*)
                        continue
                        ;;
                esac
                if [ ! -e "$PACKAGE_DIR/lib/$dep_name" ]; then
                    cp -P "$dep_path" "$PACKAGE_DIR/lib/" 2>/dev/null || true
                fi
            fi
        done
    fi
done 2>/dev/null || true

# Count libraries
LIB_COUNT=$(find "$PACKAGE_DIR/lib" -type f -name "*.so*" 2>/dev/null | wc -l)
print_info "       Bundled $LIB_COUNT library files total"


# =============================================================================
# Create launcher script (self-contained)
# =============================================================================
echo ""
echo "[4/6] Creating launcher script..."

cat > "$PACKAGE_DIR/run_broadcaster.sh" << 'LAUNCHER_EOF'
#!/bin/bash
# GameLift Streams IVS Broadcast Sidecar Sample Launcher
# Self-contained launcher that uses bundled GStreamer libraries

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$SCRIPT_DIR"

# Set up library path to use bundled libraries FIRST (before system libs)
export LD_LIBRARY_PATH="$PACKAGE_ROOT/lib:$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0"

# Set up GStreamer environment to use ONLY bundled plugins (not system plugins)
export GST_PLUGIN_PATH="$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0"
export GST_PLUGIN_SYSTEM_PATH=""
export GST_PLUGIN_SCANNER="$PACKAGE_ROOT/gstreamer/libexec/gst-plugin-scanner"
export GST_REGISTRY="$PACKAGE_ROOT/gstreamer-registry.bin"

# Disable debug output by default (set GST_DEBUG=2 for warnings, 4 for info)
export GST_DEBUG=${GST_DEBUG:-0}

# Run the broadcast app with logging
export DISPLAY=:0
startx &
sleep 3
xterm -hold -geometry 120x40 -e "$PACKAGE_ROOT/bin/gamelift-streams-ivs-broadcast-sidecar-sample" "$@" 2>&1 | tee "$PACKAGE_ROOT/broadcaster.log"
LAUNCHER_EOF

chmod +x "$PACKAGE_DIR/run_broadcaster.sh"
print_info "       - run_broadcaster.sh"

# Create background launcher script
cat > "$PACKAGE_DIR/run_broadcaster_background.sh" << 'BG_LAUNCHER_EOF'
#!/bin/bash
# GameLift Streams IVS Broadcast Sidecar Sample Background Launcher
# Runs the broadcaster in the background, then launches your game

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Start the broadcaster in the background with logging
nohup "$SCRIPT_DIR/run_broadcaster.sh" "$@" > "$SCRIPT_DIR/broadcaster.log" 2>&1 &
BROADCASTER_PID=$!
echo "Broadcaster started in background. PID: $BROADCASTER_PID"
echo "Log file: $SCRIPT_DIR/broadcaster.log"

# Add your game executable below:
# ./your-game

BG_LAUNCHER_EOF

chmod +x "$PACKAGE_DIR/run_broadcaster_background.sh"
print_info "       - run_broadcaster_background.sh"

# =============================================================================
# Create test script
# =============================================================================
echo ""
echo "[5/6] Creating test script..."

cat > "$PACKAGE_DIR/test_package.sh" << 'TEST_EOF'
#!/bin/bash
# GameLift Streams IVS Broadcast Sidecar Sample - Package Test Script
# Verifies that the self-contained package is correctly set up

echo "========================================"
echo "Testing GameLift Streams IVS Broadcast Sidecar Sample Package"
echo "========================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$SCRIPT_DIR"

# Set up environment to use bundled libraries
export LD_LIBRARY_PATH="$PACKAGE_ROOT/lib:$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0"
export GST_PLUGIN_PATH="$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0"
export GST_PLUGIN_SYSTEM_PATH=""
export GST_PLUGIN_SCANNER="$PACKAGE_ROOT/gstreamer/libexec/gst-plugin-scanner"
export GST_REGISTRY="$PACKAGE_ROOT/gstreamer-registry.bin"

TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    echo "       [OK] $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo "       [FAIL] $1"
    ((TESTS_FAILED++))
}

test_warn() {
    echo "       [WARN] $1"
}

# Test 1: Check executable exists
echo "[1/8] Checking executable..."
if [ -f "$PACKAGE_ROOT/bin/gamelift-streams-ivs-broadcast-sidecar-sample" ]; then
    test_pass "gamelift-streams-ivs-broadcast-sidecar-sample found"
else
    test_fail "gamelift-streams-ivs-broadcast-sidecar-sample NOT found"
fi

# Test 2: Check executable permissions
echo "[2/8] Checking executable permissions..."
if [ -x "$PACKAGE_ROOT/bin/gamelift-streams-ivs-broadcast-sidecar-sample" ]; then
    test_pass "Executable has correct permissions"
else
    test_fail "Executable is not executable"
fi

# Test 3: Check bundled libraries
echo "[3/8] Checking bundled libraries..."
LIB_COUNT=$(find "$PACKAGE_ROOT/lib" -name "*.so*" -type f 2>/dev/null | wc -l)
if [ "$LIB_COUNT" -gt 0 ]; then
    test_pass "Found $LIB_COUNT bundled libraries"
else
    test_fail "No bundled libraries found"
fi

# Test 4: Check bundled GStreamer plugins
echo "[4/8] Checking bundled GStreamer plugins..."
PLUGIN_COUNT=$(find "$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0" -name "*.so" -type f 2>/dev/null | wc -l)
if [ "$PLUGIN_COUNT" -gt 0 ]; then
    test_pass "Found $PLUGIN_COUNT bundled GStreamer plugins"
else
    test_fail "No bundled GStreamer plugins found"
fi

# Test 5: Check GStreamer tools
echo "[5/8] Checking bundled GStreamer tools..."
if [ -f "$PACKAGE_ROOT/gstreamer/bin/gst-inspect-1.0" ]; then
    if "$PACKAGE_ROOT/gstreamer/bin/gst-inspect-1.0" --version &>/dev/null; then
        GST_VERSION=$("$PACKAGE_ROOT/gstreamer/bin/gst-inspect-1.0" --version 2>/dev/null | head -n1)
        test_pass "GStreamer tools working: $GST_VERSION"
    else
        test_warn "GStreamer tools present but may have issues"
    fi
else
    test_warn "GStreamer tools not bundled (optional)"
fi

# Test 6: Check critical GStreamer plugins
echo "[6/8] Checking critical GStreamer plugins..."

check_plugin() {
    local plugin_file="$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0/libgst$1.so"
    if [ -f "$plugin_file" ]; then
        test_pass "$1"
        return 0
    else
        test_fail "$1 not found"
        return 1
    fi
}

check_plugin "ximagesrc"
check_plugin "videoconvertscale"
check_plugin "videorate"
check_plugin "x264"
check_plugin "opus"
check_plugin "webrtc"
check_plugin "rswebrtc"
check_plugin "webrtchttp"
check_plugin "audiobuffersplit"
check_plugin "autodetect"
check_plugin "rtmp2"
check_plugin "flv"
check_plugin "libav"

# Test 7: Check whipsink element is available
echo "[7/8] Checking whipsink element..."
if "$PACKAGE_ROOT/gstreamer/bin/gst-inspect-1.0" whipsink &>/dev/null; then
    test_pass "whipsink element available"
else
    test_fail "whipsink element NOT available"
fi

# Check optional GPU encoder
if [ -f "$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0/libgstnvcodec.so" ]; then
    test_pass "GPU encoder available (nvcodec)"
else
    test_warn "GPU encoder not available (will use CPU encoding)"
fi

# Test 8: Test application runs
echo "[8/8] Testing application..."
if "$PACKAGE_ROOT/bin/gamelift-streams-ivs-broadcast-sidecar-sample" --help 2>&1 | grep -q "Usage:\|auth-token\|whip-endpoint"; then
    test_pass "Application runs successfully"
else
    test_fail "Application failed to run"
fi

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "All tests passed! Package is ready to use."
    echo ""
    echo "This is a self-contained package - no system dependencies required."
    echo ""
    echo "To run the broadcaster over WHIP (default):"
    echo "  ./run_broadcaster.sh --auth-token YOUR_TOKEN --whip-endpoint YOUR_URL"
    echo ""
    echo "To run the broadcaster over RTMP:"
    echo "  ./run_broadcaster.sh --ingest-type rtmp --rtmp-endpoint YOUR_URL --stream-key YOUR_KEY"
    echo ""
    echo "See README.txt for the full option list."
    exit 0
else
    echo "Some tests failed. Please check the errors above."
    exit 1
fi
TEST_EOF

chmod +x "$PACKAGE_DIR/test_package.sh"
print_info "       - test_package.sh"

# =============================================================================
# Create README for the package
# =============================================================================
echo ""
echo "[6/6] Creating package documentation..."

cat > "$PACKAGE_DIR/README.txt" << 'README_EOF'
================================================================================
GameLift Streams IVS Broadcast Sidecar Sample for Linux
================================================================================

A sample Linux sidecar application that captures screen content and system audio
using GStreamer and streams it to Amazon IVS (Interactive Video Service).
Designed to run alongside game applications on Amazon GameLift Streams instances.

NOTE: This is a sample application intended for demonstration and development
purposes. It is not production-ready.

================================================================================
SELF-CONTAINED PACKAGE
================================================================================

This package is FULLY SELF-CONTAINED and includes all required dependencies:
- GStreamer 1.24+ core libraries (built from source)
- GStreamer Rust plugins including whipsink for WHIP streaming
- rtmp2sink, flvmux and avenc_aac for RTMP streaming
- GStreamer plugins (video, audio, encoding, WebRTC)
- All required system libraries

NO SYSTEM DEPENDENCIES NEED TO BE INSTALLED on the target system.
This makes it ideal for deployment on Amazon GameLift Streams instances.

================================================================================
QUICK START
================================================================================

1. Test the package:

   ./test_package.sh

2. Run the broadcaster (WHIP, the default):

   ./run_broadcaster.sh --auth-token YOUR_TOKEN --whip-endpoint YOUR_URL

   Or using environment variables:

   export IVS_STAGE_TOKEN=your_token
   export IVS_WHIP_ENDPOINT=https://your-endpoint/whip
   ./run_broadcaster.sh

   To stream to an IVS low-latency channel over RTMP instead:

   ./run_broadcaster.sh --ingest-type rtmp \
       --rtmp-endpoint rtmps://YOUR_INGEST_SERVER:443/app \
       --stream-key YOUR_STREAM_KEY

   Or using environment variables:

   export INGEST_TYPE=rtmp
   export RTMP_ENDPOINT=rtmps://your-ingest-server:443/app
   export STREAM_KEY=your_stream_key
   ./run_broadcaster.sh

3. Run in background (for GameLift Streams):

   ./run_broadcaster_background.sh --auth-token YOUR_TOKEN --whip-endpoint YOUR_URL

   The background launcher accepts the same options, so the RTMP form above
   works there too.

================================================================================
INGEST PROTOCOLS
================================================================================

The sidecar streams over WHIP by default. Set --ingest-type rtmp (or
INGEST_TYPE=rtmp) to stream to an Amazon IVS low-latency channel, or to any
standard RTMP ingest server, instead. Only the settings for the selected
protocol are required; the other protocol's settings are ignored.

For RTMP, the stream key is appended to the endpoint to form the ingest URL
(a trailing / on the endpoint is handled either way). Using an IVS channel's
ingest server and stream key:

  --rtmp-endpoint rtmps://a1b2c3d4e5f6.global-contribute.live-video.net:443/app
  --stream-key sk_us-west-2_abcd1234efgh5678ijkl

produces:

  rtmps://a1b2c3d4e5f6.global-contribute.live-video.net:443/app/sk_us-west-2_abcd1234efgh5678ijkl

RTMPS uses outbound port 443/TCP and must be given as rtmps:// with the :443
in the path. Plain rtmp:// uses port 1935 and requires insecure ingest to be
enabled on the IVS channel. On the RTMP path, video is H.264 and audio is AAC
(IVS low-latency accepts AAC-LC at 96-320 kbps); WHIP uses Opus audio.

Prefer the environment variables for the auth token and stream key. Values
passed as command-line arguments are visible to other users on the instance
in the process list.

================================================================================
COMMAND-LINE OPTIONS
================================================================================

Usage: ./run_broadcaster.sh [OPTIONS]

Ingest protocol:
  --ingest-type TYPE        Protocol: whip or rtmp (default: whip)

WHIP options (required when the ingest protocol is whip):
  --auth-token TOKEN        IVS authentication token
  --whip-endpoint URL       WHIP endpoint URL

RTMP options (required when the ingest protocol is rtmp):
  --rtmp-endpoint URL       RTMP ingest server URL
  --stream-key KEY          RTMP stream key

Common options:
  --encoder cpu|gpu         Encoder type (default: gpu, falls back to cpu)
  --width WIDTH             Video width (default: 1280)
  --height HEIGHT           Video height (default: 720)
  --framerate FPS           Video framerate (default: 30)
  --video-bitrate KBPS      Video bitrate in kbps (default: 4000)
  --audio-bitrate BPS       Audio bitrate in bps (default: 128000)
  --queue-buffer-size N     Video queue depth in buffers (default: 5,
                            0 = unlimited)
  --no-audio                Disable audio capture
  --debug                   Print the pipeline string for debugging
  --help                    Show help message

Environment Variables:
  INGEST_TYPE               Ingest protocol (alternative to --ingest-type)
  IVS_STAGE_TOKEN           Authentication token (alternative to --auth-token)
  IVS_WHIP_ENDPOINT         WHIP endpoint URL (alternative to --whip-endpoint)
  RTMP_ENDPOINT             RTMP server URL (alternative to --rtmp-endpoint)
  STREAM_KEY                RTMP stream key (alternative to --stream-key)
  ENCODER_TYPE              Encoder type (alternative to --encoder)
  ENABLE_AUDIO              Set to false to disable audio capture
  QUEUE_BUFFER_SIZE         Video queue depth (alternative to
                            --queue-buffer-size)
  VIDEO_WIDTH               Video width (alternative to --width)
  VIDEO_HEIGHT              Video height (alternative to --height)
  VIDEO_FRAMERATE           Video framerate (alternative to --framerate)
  VIDEO_BITRATE             Video bitrate (alternative to --video-bitrate)
  AUDIO_BITRATE             Audio bitrate (alternative to --audio-bitrate)
  DEBUG_PIPELINE            Set to true to print the pipeline string
  GST_DEBUG                 GStreamer debug level (0-5, default: 0)

================================================================================
PACKAGE CONTENTS
================================================================================

gamelift-streams-ivs-broadcast-sidecar-sample-linux/
├── bin/
│   └── gamelift-streams-ivs-broadcast-sidecar-sample    # Main executable
├── lib/
│   └── *.so*                           # Bundled system libraries
├── gstreamer/
│   ├── bin/
│   │   └── gst-*                       # GStreamer tools
│   ├── libexec/
│   │   └── gst-plugin-scanner          # Plugin scanner
│   └── lib/
│       └── gstreamer-1.0/
│           └── *.so                    # GStreamer plugins (incl. whipsink, rtmp2sink)
├── run_broadcaster.sh                  # Main launcher script
├── run_broadcaster_background.sh       # Background launcher
├── test_package.sh                     # Package test script
└── README.txt                          # This file

================================================================================
LICENSE
================================================================================

This library is licensed under the MIT-0 License. See the LICENSE file.

README_EOF

print_info "       - README.txt"

# =============================================================================
# Create tarball archive
# =============================================================================
echo ""
echo "========================================"
echo "Creating tarball archive..."

TARBALL_NAME="gamelift-streams-ivs-broadcast-sidecar-sample-linux.tar.gz"
rm -f "$TARBALL_NAME"

tar -czvf "$TARBALL_NAME" "$PACKAGE_DIR" > /dev/null 2>&1

if [ -f "$TARBALL_NAME" ]; then
    TARBALL_SIZE=$(du -h "$TARBALL_NAME" | cut -f1)
    print_success "[OK] Tarball created: $TARBALL_NAME ($TARBALL_SIZE)"
else
    print_warning "Failed to create tarball"
    echo "You can manually create it with: tar -czvf $TARBALL_NAME $PACKAGE_DIR"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "========================================"
echo "Packaging Complete!"
echo "========================================"
echo ""
echo "Package contents:"
echo "  bin/"
echo "    - gamelift-streams-ivs-broadcast-sidecar-sample"
echo "  lib/"
LIB_COUNT=$(find "$PACKAGE_DIR/lib" -type f -name "*.so*" 2>/dev/null | wc -l)
echo "    - $LIB_COUNT bundled library files"
echo "  gstreamer/lib/gstreamer-1.0/"
PLUGIN_COUNT=$(find "$PACKAGE_DIR/gstreamer/lib/gstreamer-1.0" -name "*.so" -type f 2>/dev/null | wc -l)
echo "    - $PLUGIN_COUNT GStreamer plugins"
echo ""
echo "Scripts:"
echo "  - run_broadcaster.sh           (main launcher)"
echo "  - run_broadcaster_background.sh (background launcher)"
echo "  - test_package.sh              (verify package works)"
echo "  - README.txt                   (documentation)"
echo ""
echo "Output:"
echo "  Directory: $PACKAGE_DIR"
echo "  Tarball:   $TARBALL_NAME"
echo ""
echo "This package is SELF-CONTAINED and requires NO system dependencies."
echo "It can be deployed directly to Amazon GameLift Streams instances."
echo ""
echo "To test the package:"
echo "  cd $PACKAGE_DIR"
echo "  ./test_package.sh"
echo ""
echo "To deploy to GameLift Streams:"
echo "  1. Upload: $TARBALL_NAME"
echo "  2. Extract: tar -xzvf $TARBALL_NAME"
echo "  3. Run (WHIP):  ./$PACKAGE_DIR/run_broadcaster.sh --auth-token TOKEN --whip-endpoint URL"
echo "     Run (RTMP):  ./$PACKAGE_DIR/run_broadcaster.sh --ingest-type rtmp --rtmp-endpoint URL --stream-key KEY"
echo ""
