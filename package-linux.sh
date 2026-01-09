#!/bin/bash
# Packaging script for GameLift Streams IVS Broadcast Sidecar Sample on Linux
# Creates a self-contained distributable package with all dependencies bundled
# No system dependencies need to be installed on the target GameLift Streams instance

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

# =============================================================================
# Copy main executable
# =============================================================================
echo ""
echo "[1/6] Copying main executable..."
cp "$BUILD_DIR/$BINARY_NAME" "$PACKAGE_DIR/bin/"
chmod +x "$PACKAGE_DIR/bin/$BINARY_NAME"
print_info "       - $BINARY_NAME"

# =============================================================================
# Helper function to copy libraries matching a pattern
# =============================================================================
copy_libs() {
    local pattern="$1"
    local dest="$2"
    local count=0
    
    # Use find to avoid glob expansion issues
    while IFS= read -r -d '' file; do
        cp -P "$file" "$dest/" 2>/dev/null || true
        ((count++)) || true
    done < <(find /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib -maxdepth 1 -name "$pattern" -print0 2>/dev/null || true)
    
    return 0
}

# =============================================================================
# Bundle GStreamer libraries and plugins
# =============================================================================
echo ""
echo "[2/6] Bundling GStreamer libraries and plugins..."

# Find GStreamer library directory
GST_LIB_DIR=""
for dir in /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib; do
    if [ -f "$dir/libgstreamer-1.0.so.0" ]; then
        GST_LIB_DIR="$dir"
        break
    fi
done

if [ -z "$GST_LIB_DIR" ]; then
    print_error "Could not find GStreamer libraries"
    exit 1
fi
print_info "       Found GStreamer libraries in: $GST_LIB_DIR"

# Find GStreamer plugin directory
GST_PLUGIN_DIR=""
for dir in "$GST_LIB_DIR/gstreamer-1.0" /usr/lib/x86_64-linux-gnu/gstreamer-1.0 /usr/lib64/gstreamer-1.0; do
    if [ -d "$dir" ]; then
        GST_PLUGIN_DIR="$dir"
        break
    fi
done

if [ -z "$GST_PLUGIN_DIR" ]; then
    print_error "Could not find GStreamer plugins directory"
    exit 1
fi
print_info "       Found GStreamer plugins in: $GST_PLUGIN_DIR"

# Copy core GStreamer libraries using find
echo "       Copying GStreamer core libraries..."
GST_LIB_COUNT=0
for pattern in \
    "libgstreamer-1.0.so*" \
    "libgstbase-1.0.so*" \
    "libgstvideo-1.0.so*" \
    "libgstaudio-1.0.so*" \
    "libgstpbutils-1.0.so*" \
    "libgstapp-1.0.so*" \
    "libgstrtp-1.0.so*" \
    "libgstrtsp-1.0.so*" \
    "libgstsdp-1.0.so*" \
    "libgstwebrtc-1.0.so*" \
    "libgstcodecs-1.0.so*" \
    "libgsttag-1.0.so*" \
    "libgstnet-1.0.so*" \
    "libgstgl-1.0.so*" \
    "libgstcheck-1.0.so*" \
    "libgstcontroller-1.0.so*" \
    "libgstfft-1.0.so*" \
    "libgstriff-1.0.so*" \
    "libgstsctp-1.0.so*" \
    "libgstcodecparsers-1.0.so*" \
    "libgstinsertbin-1.0.so*" \
    "libgstmpegts-1.0.so*" \
    "libgstplay-1.0.so*" \
    "libgstplayer-1.0.so*" \
    "libgsturidownloader-1.0.so*" \
    "libgstadaptivedemux-1.0.so*" \
    "libgstbadaudio-1.0.so*" \
    "libgstisoff-1.0.so*" \
    "libgstphotography-1.0.so*" \
    "libgstwayland-1.0.so*" \
    "libgstwebrtcnice-1.0.so*" \
    "libgstbasecamerabinsrc-1.0.so*" \
    "libgstvalidate-1.0.so*" \
    "libgstanalytics-1.0.so*" \
    "libgstcuda-1.0.so*" \
    "libgstva-1.0.so*" \
    "libgstvulkan-1.0.so*" \
    "libgsttranscoder-1.0.so*" \
    "libgstmse-1.0.so*" \
    "libgstallocators-1.0.so*"
do
    for file in "$GST_LIB_DIR"/$pattern; do
        if [ -e "$file" ]; then
            cp -P "$file" "$PACKAGE_DIR/lib/" 2>/dev/null && ((GST_LIB_COUNT++)) || true
        fi
    done
done
print_info "       Copied $GST_LIB_COUNT GStreamer library files"

# Copy required GStreamer plugins
echo "       Copying GStreamer plugins..."
PLUGINS_COPIED=0
for plugin in \
    libgstcoreelements.so \
    libgstcoretracers.so \
    libgsttypefindfunctions.so \
    libgstximagesrc.so \
    libgstvideoconvert.so \
    libgstvideoconvertscale.so \
    libgstvideoscale.so \
    libgstvideorate.so \
    libgstvideofilter.so \
    libgstvideotestsrc.so \
    libgstvideobox.so \
    libgstvideocrop.so \
    libgstvideomixer.so \
    libgstvideoparsersbad.so \
    libgstcompositor.so \
    libgstautodetect.so \
    libgstaudioconvert.so \
    libgstaudioresample.so \
    libgstaudiorate.so \
    libgstaudiotestsrc.so \
    libgstaudiomixer.so \
    libgstaudioparsers.so \
    libgstaudiofx.so \
    libgstvolume.so \
    libgstlevel.so \
    libgstpulseaudio.so \
    libgstalsa.so \
    libgstx264.so \
    libgstopenh264.so \
    libgstlibav.so \
    libgstvpx.so \
    libgsttheora.so \
    libgstnvcodec.so \
    libgstopus.so \
    libgstvorbis.so \
    libgstlame.so \
    libgstflac.so \
    libgstspeex.so \
    libgstwebrtc.so \
    libgstwebrtcdsp.so \
    libgstnice.so \
    libgstdtls.so \
    libgstsrtp.so \
    libgstrtp.so \
    libgstrtpmanager.so \
    libgstrtsp.so \
    libgstsdpelem.so \
    libgstsctp.so \
    libgstudp.so \
    libgsttcp.so \
    libgstsoup.so \
    libgstmatroska.so \
    libgstisomp4.so \
    libgstflv.so \
    libgstogg.so \
    libgstavi.so \
    libgstwavparse.so \
    libgstwavenc.so \
    libgstplayback.so \
    libgstapp.so \
    libgstgio.so \
    libgstencoding.so \
    libgstdebug.so \
    libgstinterleave.so \
    libgstsubparse.so \
    libgstpango.so \
    libgstcairo.so \
    libgstjpeg.so \
    libgstpng.so \
    libgstgdkpixbuf.so \
    libgstopengl.so \
    libgstmultifile.so \
    libgstid3demux.so \
    libgstid3tag.so \
    libgstapetag.so \
    libgsticydemux.so \
    libgstreplaygain.so \
    libgstequalizer.so \
    libgstspectrum.so \
    libgstdeinterlace.so \
    libgstimagefreeze.so \
    libgstalphacolor.so \
    libgstalpha.so \
    libgsteffectv.so \
    libgstgaudieffects.so \
    libgstgeometrictransform.so \
    libgstshapewipe.so \
    libgstsmpte.so
do
    if [ -f "$GST_PLUGIN_DIR/$plugin" ]; then
        cp "$GST_PLUGIN_DIR/$plugin" "$PACKAGE_DIR/gstreamer/lib/gstreamer-1.0/"
        ((PLUGINS_COPIED++)) || true
    fi
done
print_info "       Copied $PLUGINS_COPIED GStreamer plugins"

# =============================================================================
# Bundle system dependencies
# =============================================================================
echo ""
echo "[3/6] Bundling system dependencies..."

# Function to copy a library and follow symlinks
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

# Copy GLib and related libraries
echo "       Copying GLib and core libraries..."
for pattern in \
    "libglib-2.0.so*" \
    "libgobject-2.0.so*" \
    "libgio-2.0.so*" \
    "libgmodule-2.0.so*" \
    "libgthread-2.0.so*"
do
    for file in "$GST_LIB_DIR"/$pattern /usr/lib/x86_64-linux-gnu/$pattern; do
        if [ -e "$file" ]; then
            copy_lib "$file" "$PACKAGE_DIR/lib"
        fi
    done
done

# Copy additional required libraries
echo "       Copying codec and multimedia libraries..."
for pattern in \
    "libopus.so*" \
    "libx264.so*" \
    "libopenh264.so*" \
    "libvpx.so*" \
    "libavcodec.so*" \
    "libavutil.so*" \
    "libavformat.so*" \
    "libswresample.so*" \
    "libswscale.so*" \
    "libnice.so*" \
    "libsrtp2.so*" \
    "libtheora.so*" \
    "libtheoraenc.so*" \
    "libtheoradec.so*" \
    "libvorbis.so*" \
    "libvorbisenc.so*" \
    "libvorbisfile.so*" \
    "libFLAC.so*" \
    "libogg.so*" \
    "libspeex.so*" \
    "libspeexdsp.so*" \
    "libmp3lame.so*" \
    "libwebrtc_audio_processing.so*"
do
    for dir in "$GST_LIB_DIR" /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib; do
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
    "libsoup-2.4.so*" \
    "libsoup-3.0.so*" \
    "libjson-glib-1.0.so*" \
    "libxml2.so*" \
    "libpsl.so*" \
    "libbrotlidec.so*" \
    "libbrotlicommon.so*" \
    "libnghttp2.so*" \
    "libssh2.so*" \
    "librtmp.so*" \
    "libgnutls.so*" \
    "libp11-kit.so*" \
    "libtasn1.so*" \
    "libidn2.so*" \
    "libunistring.so*" \
    "libnettle.so*" \
    "libhogweed.so*" \
    "libgmp.so*"
do
    for dir in "$GST_LIB_DIR" /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib; do
        for file in "$dir"/$pattern; do
            if [ -e "$file" ]; then
                copy_lib "$file" "$PACKAGE_DIR/lib"
            fi
        done
    done
done

echo "       Copying X11 and display libraries..."
for pattern in \
    "libX11.so*" \
    "libXext.so*" \
    "libXfixes.so*" \
    "libXdamage.so*" \
    "libXcomposite.so*" \
    "libXrender.so*" \
    "libXrandr.so*" \
    "libXi.so*" \
    "libXtst.so*" \
    "libxcb.so*" \
    "libxcb-shm.so*" \
    "libxcb-xfixes.so*" \
    "libXau.so*" \
    "libXdmcp.so*" \
    "libdrm.so*" \
    "libva.so*" \
    "libva-drm.so*" \
    "libva-x11.so*" \
    "libvdpau.so*" \
    "libGL.so*" \
    "libGLX.so*" \
    "libGLdispatch.so*" \
    "libEGL.so*" \
    "libgbm.so*" \
    "libwayland-client.so*" \
    "libwayland-server.so*" \
    "libwayland-egl.so*"
do
    for dir in "$GST_LIB_DIR" /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib; do
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
    "libasound.so*" \
    "libsndfile.so*"
do
    for dir in "$GST_LIB_DIR" /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib; do
        for file in "$dir"/$pattern; do
            if [ -e "$file" ]; then
                copy_lib "$file" "$PACKAGE_DIR/lib"
            fi
        done
    done
done

echo "       Copying text rendering libraries..."
for pattern in \
    "libpango-1.0.so*" \
    "libpangocairo-1.0.so*" \
    "libpangoft2-1.0.so*" \
    "libcairo.so*" \
    "libcairo-gobject.so*" \
    "libgdk_pixbuf-2.0.so*" \
    "libjpeg.so*" \
    "libpng16.so*" \
    "libpng12.so*" \
    "libfontconfig.so*" \
    "libfreetype.so*" \
    "libharfbuzz.so*" \
    "libpixman-1.so*" \
    "libfribidi.so*" \
    "libthai.so*" \
    "libdatrie.so*" \
    "libgraphite2.so*"
do
    for dir in "$GST_LIB_DIR" /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib; do
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
    "libsqlite3.so*" \
    "libgudev-1.0.so*" \
    "libusb-1.0.so*" \
    "libv4l2.so*" \
    "libv4lconvert.so*" \
    "libfftw3.so*" \
    "libfftw3f.so*"
do
    for dir in "$GST_LIB_DIR" /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib; do
        for file in "$dir"/$pattern; do
            if [ -e "$file" ]; then
                copy_lib "$file" "$PACKAGE_DIR/lib"
            fi
        done
    done
done

# Use ldd to find and copy any missing dependencies
echo "       Resolving additional dependencies with ldd..."

resolve_dependencies() {
    local binary="$1"
    local dest_dir="$2"
    
    if [ ! -f "$binary" ]; then
        return 0
    fi
    
    ldd "$binary" 2>/dev/null | while IFS= read -r line; do
        # Extract library path from ldd output (format: "libname.so => /path/to/lib (addr)")
        local lib_path
        lib_path=$(echo "$line" | sed -n 's/.*=> \(\/[^ ]*\).*/\1/p')
        
        if [ -n "$lib_path" ] && [ -f "$lib_path" ]; then
            local lib_name
            lib_name=$(basename "$lib_path")
            
            # Skip core system libraries that should always be present
            case "$lib_name" in
                libc.so*|libm.so*|libdl.so*|libpthread.so*|librt.so*|ld-linux*.so*|linux-vdso.so*)
                    continue
                    ;;
            esac
            
            if [ ! -e "$dest_dir/$lib_name" ]; then
                cp -P "$lib_path" "$dest_dir/" 2>/dev/null || true
                # Also copy symlink targets
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
            fi
        fi
    done
}

# Resolve dependencies for main binary
resolve_dependencies "$PACKAGE_DIR/bin/$BINARY_NAME" "$PACKAGE_DIR/lib"

# Resolve dependencies for all copied libraries (run multiple passes to catch transitive deps)
echo "       Resolving transitive dependencies (this may take a moment)..."
for pass in 1 2 3; do
    for lib in "$PACKAGE_DIR/lib"/*.so* "$PACKAGE_DIR/lib"/*.so; do
        if [ -f "$lib" ] && [ ! -L "$lib" ]; then
            resolve_dependencies "$lib" "$PACKAGE_DIR/lib"
        fi
    done 2>/dev/null || true
done

# Resolve dependencies for all plugins
for plugin in "$PACKAGE_DIR/gstreamer/lib/gstreamer-1.0"/*.so; do
    if [ -f "$plugin" ]; then
        resolve_dependencies "$plugin" "$PACKAGE_DIR/lib"
    fi
done 2>/dev/null || true

# Count libraries
LIB_COUNT=$(find "$PACKAGE_DIR/lib" -type f -name "*.so*" 2>/dev/null | wc -l)
print_info "       Bundled $LIB_COUNT library files total"

# Copy GStreamer tools
echo "       Copying GStreamer tools..."
GST_BIN_DIR=""
for dir in /usr/bin /usr/local/bin; do
    if [ -f "$dir/gst-launch-1.0" ]; then
        GST_BIN_DIR="$dir"
        break
    fi
done

if [ -n "$GST_BIN_DIR" ]; then
    for tool in gst-launch-1.0 gst-inspect-1.0 gst-typefind-1.0; do
        if [ -f "$GST_BIN_DIR/$tool" ]; then
            cp "$GST_BIN_DIR/$tool" "$PACKAGE_DIR/gstreamer/bin/"
            print_info "       - $tool"
        fi
    done
fi

# Find and copy gst-plugin-scanner
for dir in /usr/libexec/gstreamer-1.0 /usr/lib/x86_64-linux-gnu/gstreamer-1.0 "$GST_LIB_DIR/gstreamer-1.0"; do
    if [ -f "$dir/gst-plugin-scanner" ]; then
        cp "$dir/gst-plugin-scanner" "$PACKAGE_DIR/gstreamer/bin/"
        print_info "       - gst-plugin-scanner"
        break
    fi
done

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

# Set up library path to use bundled libraries
export LD_LIBRARY_PATH="$PACKAGE_ROOT/lib:$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0:${LD_LIBRARY_PATH:-}"

# Set up GStreamer environment to use bundled plugins
export GST_PLUGIN_PATH="$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0"
export GST_PLUGIN_SYSTEM_PATH="$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0"
export GST_PLUGIN_SCANNER="$PACKAGE_ROOT/gstreamer/bin/gst-plugin-scanner"
export GST_REGISTRY="$PACKAGE_ROOT/gstreamer-registry.bin"

# Disable debug output by default (set GST_DEBUG=2 for warnings, 4 for info)
export GST_DEBUG=${GST_DEBUG:-0}

# Run the broadcast client
exec "$PACKAGE_ROOT/bin/gamelift-streams-ivs-broadcast-sidecar-sample" "$@"
LAUNCHER_EOF

chmod +x "$PACKAGE_DIR/run_broadcaster.sh"
print_info "       - run_broadcaster.sh"

# Create background launcher script
cat > "$PACKAGE_DIR/run_broadcaster_background.sh" << 'BG_LAUNCHER_EOF'
#!/bin/bash
# GameLift Streams IVS Broadcast Sidecar Sample Background Launcher
# Runs the broadcaster in the background

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nohup "$SCRIPT_DIR/run_broadcaster.sh" "$@" > "$SCRIPT_DIR/broadcaster.log" 2>&1 &
echo "Broadcaster started in background. PID: $!"
echo "Log file: $SCRIPT_DIR/broadcaster.log"
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
export LD_LIBRARY_PATH="$PACKAGE_ROOT/lib:$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0:${LD_LIBRARY_PATH:-}"
export GST_PLUGIN_PATH="$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0"
export GST_PLUGIN_SYSTEM_PATH="$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0"
export GST_PLUGIN_SCANNER="$PACKAGE_ROOT/gstreamer/bin/gst-plugin-scanner"
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
echo "[1/7] Checking executable..."
if [ -f "$PACKAGE_ROOT/bin/gamelift-streams-ivs-broadcast-sidecar-sample" ]; then
    test_pass "gamelift-streams-ivs-broadcast-sidecar-sample found"
else
    test_fail "gamelift-streams-ivs-broadcast-sidecar-sample NOT found"
fi

# Test 2: Check executable permissions
echo "[2/7] Checking executable permissions..."
if [ -x "$PACKAGE_ROOT/bin/gamelift-streams-ivs-broadcast-sidecar-sample" ]; then
    test_pass "Executable has correct permissions"
else
    test_fail "Executable is not executable"
fi

# Test 3: Check bundled libraries
echo "[3/7] Checking bundled libraries..."
LIB_COUNT=$(find "$PACKAGE_ROOT/lib" -name "*.so*" -type f 2>/dev/null | wc -l)
if [ "$LIB_COUNT" -gt 0 ]; then
    test_pass "Found $LIB_COUNT bundled libraries"
else
    test_fail "No bundled libraries found"
fi

# Test 4: Check bundled GStreamer plugins
echo "[4/7] Checking bundled GStreamer plugins..."
PLUGIN_COUNT=$(find "$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0" -name "*.so" -type f 2>/dev/null | wc -l)
if [ "$PLUGIN_COUNT" -gt 0 ]; then
    test_pass "Found $PLUGIN_COUNT bundled GStreamer plugins"
else
    test_fail "No bundled GStreamer plugins found"
fi

# Test 5: Check GStreamer tools
echo "[5/7] Checking bundled GStreamer tools..."
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
echo "[6/7] Checking critical GStreamer plugins..."

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
check_plugin "videoconvert"
check_plugin "x264"
check_plugin "opus"
check_plugin "webrtc"
check_plugin "autodetect"

# Check optional GPU encoder
if [ -f "$PACKAGE_ROOT/gstreamer/lib/gstreamer-1.0/libgstnvcodec.so" ]; then
    test_pass "GPU encoder available (nvcodec)"
else
    test_warn "GPU encoder not available (will use CPU encoding)"
fi

# Test 7: Test application runs
echo "[7/7] Testing application..."
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
    echo "To run the broadcaster:"
    echo "  ./run_broadcaster.sh --auth-token YOUR_TOKEN --whip-endpoint YOUR_URL"
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
- GStreamer core libraries
- GStreamer plugins (video, audio, encoding, WebRTC)
- All required system libraries

NO SYSTEM DEPENDENCIES NEED TO BE INSTALLED on the target system.
This makes it ideal for deployment on Amazon GameLift Streams instances.

================================================================================
QUICK START
================================================================================

1. Test the package:
   
   ./test_package.sh

2. Run the broadcaster:
   
   ./run_broadcaster.sh --auth-token YOUR_TOKEN --whip-endpoint YOUR_URL

   Or using environment variables:
   
   export IVS_STAGE_TOKEN=your_token
   export IVS_WHIP_ENDPOINT=https://your-endpoint/whip
   ./run_broadcaster.sh

3. Run in background (for GameLift Streams):
   
   ./run_broadcaster_background.sh --auth-token YOUR_TOKEN --whip-endpoint YOUR_URL

================================================================================
COMMAND-LINE OPTIONS
================================================================================

Usage: ./run_broadcaster.sh [OPTIONS]

Options:
  --auth-token TOKEN        IVS authentication token (required)
  --whip-endpoint URL       WHIP endpoint URL (required)
  --encoder cpu|gpu         Encoder type (default: cpu)
  --width WIDTH             Video width (default: 1280)
  --height HEIGHT           Video height (default: 720)
  --framerate FPS           Video framerate (default: 30)
  --video-bitrate KBPS      Video bitrate in kbps (default: 4000)
  --help                    Show help message

Environment Variables:
  IVS_STAGE_TOKEN           Authentication token (alternative to --auth-token)
  IVS_WHIP_ENDPOINT         WHIP endpoint URL (alternative to --whip-endpoint)
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
│   └── lib/
│       └── gstreamer-1.0/
│           └── *.so                    # GStreamer plugins
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
echo "  3. Run: ./$PACKAGE_DIR/run_broadcaster.sh --auth-token TOKEN --whip-endpoint URL"
echo ""
