#!/bin/bash
# Build script for GameLift Streams IVS Broadcast Sidecar Sample on Linux
# Requires GCC/Clang, CMake, and GStreamer 1.22+ (built from source on Ubuntu 22.04)
#
# IMPORTANT: This script expects GStreamer to be built from source with the Rust plugins.
# The custom GStreamer installation should be at ~/gstreamer-install (or set GST_PREFIX).
# See README.md for build instructions.

set -e  # Exit on error

echo "=== GameLift Streams IVS Broadcast Sidecar Sample - Linux Build Script ==="
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
# Check for required tools
# =============================================================================
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed or not in PATH"
        return 1
    fi
    return 0
}

echo "Checking for required build tools..."

# Check for CMake
if ! check_command cmake; then
    print_error "CMake is required. Install with: sudo apt-get install cmake"
    exit 1
fi
CMAKE_VERSION=$(cmake --version | head -n1 | cut -d' ' -f3)
print_info "  CMake: $CMAKE_VERSION"

# Check for compiler (GCC or Clang)
COMPILER=""
if check_command gcc; then
    COMPILER="gcc"
    GCC_VERSION=$(gcc --version | head -n1)
    print_info "  GCC: $GCC_VERSION"
elif check_command clang; then
    COMPILER="clang"
    CLANG_VERSION=$(clang --version | head -n1)
    print_info "  Clang: $CLANG_VERSION"
else
    print_error "No C compiler found. Install GCC with: sudo apt-get install build-essential"
    exit 1
fi

# Check for make
if ! check_command make; then
    print_error "make is not installed. Install with: sudo apt-get install build-essential"
    exit 1
fi
print_info "  make: $(make --version | head -n1)"

# Check for pkg-config
if ! check_command pkg-config; then
    print_error "pkg-config is not installed. Install with: sudo apt-get install pkg-config"
    exit 1
fi
print_info "  pkg-config: $(pkg-config --version)"

echo ""

# =============================================================================
# Detect GStreamer installation (custom build required for whipsink)
# =============================================================================
echo "Checking for GStreamer installation..."

# Check for custom GStreamer build first (required for whipsink on Ubuntu 22.04)
GST_PREFIX="${GST_PREFIX:-$HOME/gstreamer-install}"

if [ -d "$GST_PREFIX/lib/x86_64-linux-gnu/pkgconfig" ]; then
    GST_PKG_CONFIG_PATH="$GST_PREFIX/lib/x86_64-linux-gnu/pkgconfig"
    GST_LIB_DIR="$GST_PREFIX/lib/x86_64-linux-gnu"
    GST_BIN_DIR="$GST_PREFIX/bin"
    print_success "  Found custom GStreamer build at: $GST_PREFIX"
elif [ -d "$GST_PREFIX/lib/pkgconfig" ]; then
    GST_PKG_CONFIG_PATH="$GST_PREFIX/lib/pkgconfig"
    GST_LIB_DIR="$GST_PREFIX/lib"
    GST_BIN_DIR="$GST_PREFIX/bin"
    print_success "  Found custom GStreamer build at: $GST_PREFIX"
else
    print_error "Custom GStreamer build not found at: $GST_PREFIX"
    echo ""
    echo "This application requires GStreamer 1.22+ built from source with Rust plugins."
    echo "Ubuntu 22.04 ships with GStreamer 1.20.x which lacks the whipsink plugin."
    echo ""
    echo "Please follow the build instructions in README.md to build GStreamer first:"
    echo "  1. Install build dependencies"
    echo "  2. Install Rust 1.79 and cargo-c"
    echo "  3. Clone and build GStreamer with -Drs=enabled"
    echo ""
    echo "Or set GST_PREFIX to point to your custom GStreamer installation."
    exit 1
fi

# Set up environment to use custom GStreamer
export PKG_CONFIG_PATH="$GST_PKG_CONFIG_PATH:${PKG_CONFIG_PATH:-}"
export PATH="$GST_BIN_DIR:$PATH"
export LD_LIBRARY_PATH="$GST_LIB_DIR:${LD_LIBRARY_PATH:-}"
export GST_PLUGIN_PATH="$GST_LIB_DIR/gstreamer-1.0"

print_info "  PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
echo ""

# =============================================================================
# Verify GStreamer packages via pkg-config
# =============================================================================
echo "Verifying GStreamer development packages..."

check_gstreamer_pkg() {
    if pkg-config --exists "$1" 2>/dev/null; then
        VERSION=$(pkg-config --modversion "$1" 2>/dev/null)
        print_info "  $1: $VERSION"
        return 0
    else
        print_error "$1 not found via pkg-config"
        return 1
    fi
}

GSTREAMER_OK=true

if ! check_gstreamer_pkg "gstreamer-1.0"; then
    GSTREAMER_OK=false
fi

if ! check_gstreamer_pkg "gstreamer-video-1.0"; then
    GSTREAMER_OK=false
fi

if ! check_gstreamer_pkg "gstreamer-audio-1.0"; then
    GSTREAMER_OK=false
fi

if [ "$GSTREAMER_OK" = false ]; then
    print_error "GStreamer development packages not found in custom build."
    echo "Please verify your GStreamer build completed successfully."
    exit 1
fi

# Check GStreamer version is 1.22+
GST_VERSION=$(pkg-config --modversion gstreamer-1.0 2>/dev/null)
GST_MAJOR=$(echo "$GST_VERSION" | cut -d. -f1)
GST_MINOR=$(echo "$GST_VERSION" | cut -d. -f2)

if [ "$GST_MAJOR" -lt 1 ] || ([ "$GST_MAJOR" -eq 1 ] && [ "$GST_MINOR" -lt 22 ]); then
    print_warning "GStreamer version $GST_VERSION detected. Version 1.22+ is recommended for whipsink."
fi

echo ""

# =============================================================================
# Check for optional dependencies
# =============================================================================
echo "Checking for optional dependencies..."

# Check for X11 development libraries
if pkg-config --exists x11 2>/dev/null; then
    X11_VERSION=$(pkg-config --modversion x11 2>/dev/null)
    print_info "  X11: $X11_VERSION"
else
    print_warning "X11 development libraries not found. Screen capture may not work."
    echo "  Install with: sudo apt-get install libx11-dev"
fi

# Check for PulseAudio
if pkg-config --exists libpulse 2>/dev/null; then
    PULSE_VERSION=$(pkg-config --modversion libpulse 2>/dev/null)
    print_info "  PulseAudio: $PULSE_VERSION"
else
    print_info "  PulseAudio: not found (autoaudiosrc will use available audio system)"
fi

echo ""

# =============================================================================
# Check for required GStreamer plugins
# =============================================================================
echo "Checking for required GStreamer plugins..."

check_gst_plugin() {
    if gst-inspect-1.0 "$1" &>/dev/null; then
        print_info "  $1: found"
        return 0
    else
        print_warning "$1: not found"
        return 1
    fi
}

PLUGINS_OK=true

# Video capture
if ! check_gst_plugin "ximagesrc"; then
    print_warning "ximagesrc plugin not found - screen capture will not work"
    PLUGINS_OK=false
fi

# Video encoding (CPU)
if ! check_gst_plugin "x264enc"; then
    print_warning "x264enc plugin not found - CPU video encoding will not work"
    PLUGINS_OK=false
fi

# Video encoding (GPU - optional)
# The application uses nvcudah264enc (CUDA mode) on Linux - see GPU_CONFIG in pipeline.c.
# Do not probe the legacy nvh264enc here: it is still registered by nvcodec but fails at
# runtime on NVIDIA driver 595+ with "Selected preset not supported", so its presence is
# not evidence that GPU encoding works.
if check_gst_plugin "nvcudah264enc"; then
    print_info "  GPU encoding: available (nvcudah264enc)"
else
    print_info "  GPU encoding: not available (will use CPU encoding)"
fi

# Audio encoding
if ! check_gst_plugin "opusenc"; then
    print_warning "opusenc plugin not found - audio encoding will not work"
    PLUGINS_OK=false
fi

# WHIP sink (critical - from gst-plugins-rs)
if ! check_gst_plugin "whipsink"; then
    print_error "whipsink plugin not found - WHIP streaming will not work!"
    echo ""
    echo "    The whipsink plugin is required for streaming to IVS."
    echo "    Please rebuild GStreamer with Rust plugins enabled:"
    echo "      meson setup builddir --prefix=\$HOME/gstreamer-install -Drs=enabled -Dgpl=enabled"
    echo "      ninja -C builddir && ninja -C builddir install"
    PLUGINS_OK=false
fi

# Audio buffer split (required for audio pipeline)
if ! check_gst_plugin "audiobuffersplit"; then
    print_warning "audiobuffersplit plugin not found - audio streaming may not work"
    PLUGINS_OK=false
fi

# RTMP streaming plugins
if ! check_gst_plugin "rtmp2sink"; then
    print_warning "rtmp2sink plugin not found - RTMP streaming will not work"
    PLUGINS_OK=false
fi

if ! check_gst_plugin "flvmux"; then
    print_warning "flvmux plugin not found - RTMP FLV muxing will not work"
    PLUGINS_OK=false
fi

if ! check_gst_plugin "avenc_aac"; then
    print_warning "avenc_aac plugin not found - AAC audio encoding for RTMP will not work"
    PLUGINS_OK=false
fi

if [ "$PLUGINS_OK" = false ]; then
    echo ""
    print_warning "Some GStreamer plugins are missing. The build will continue,"
    print_warning "but the application may not function correctly at runtime."
fi

echo ""

# =============================================================================
# Create build directory
# =============================================================================
BUILD_DIR="build-linux"

echo "Creating build directory: $BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# =============================================================================
# Run CMake
# =============================================================================
echo ""
echo "Running CMake with Unix Makefiles generator..."
echo ""

cmake -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$COMPILER" \
    ..

if [ $? -ne 0 ]; then
    print_error "CMake configuration failed"
    cd ..
    exit 1
fi

echo ""
print_success "CMake configuration completed successfully"
echo ""

# =============================================================================
# Build the project
# =============================================================================
echo "Building project..."
echo ""

# Use all available CPU cores for parallel build
NPROC=$(nproc 2>/dev/null || echo 4)
make -j"$NPROC"

if [ $? -ne 0 ]; then
    print_error "Build failed"
    cd ..
    exit 1
fi

echo ""
print_success "Linux build completed successfully!"
echo ""

# =============================================================================
# Print usage information
# =============================================================================
echo "=== Build Output ==="
echo ""
echo "Executable location: $BUILD_DIR/gamelift-streams-ivs-broadcast-sidecar-sample"
echo ""
echo "IMPORTANT: Before running, source the GStreamer environment:"
echo "  source ~/use-gstreamer.sh"
echo ""
echo "To run the application:"
echo ""
echo "  Using environment variables:"
echo "    export IVS_STAGE_TOKEN=your_token"
echo "    export IVS_WHIP_ENDPOINT=https://your-endpoint/whip"
echo "    ./$BUILD_DIR/gamelift-streams-ivs-broadcast-sidecar-sample"
echo ""
echo "  Using command-line arguments:"
echo "    ./$BUILD_DIR/gamelift-streams-ivs-broadcast-sidecar-sample --auth-token your_token --whip-endpoint https://your-endpoint/whip"
echo ""
echo "For GPU encoding (requires NVIDIA GPU with NVENC support):"
echo "    ./$BUILD_DIR/gamelift-streams-ivs-broadcast-sidecar-sample --encoder gpu --auth-token your_token --whip-endpoint https://your-endpoint/whip"
echo ""
echo "Next step: Create a distributable package with:"
echo "  ./package-linux.sh"
echo ""

cd ..
