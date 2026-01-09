#!/bin/bash
# Build script for GameLift Streams IVS Broadcast Sidecar Sample on Linux
# Requires GCC/Clang, CMake, and GStreamer development packages

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
# Check for GStreamer installation
# =============================================================================
echo "Checking for GStreamer installation..."

check_gstreamer_pkg() {
    if pkg-config --exists "$1" 2>/dev/null; then
        VERSION=$(pkg-config --modversion "$1" 2>/dev/null)
        print_info "  $1: $VERSION"
        return 0
    else
        print_error "$1 not found"
        return 1
    fi
}

GSTREAMER_OK=true

# Check required GStreamer packages
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
    echo ""
    print_error "GStreamer development packages are missing."
    echo ""
    echo "Install GStreamer on Ubuntu/Debian with:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev"
    echo "  sudo apt-get install gstreamer1.0-plugins-base gstreamer1.0-plugins-good"
    echo "  sudo apt-get install gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly"
    echo "  sudo apt-get install gstreamer1.0-tools"
    echo ""
    echo "For GPU encoding support (NVIDIA), also install:"
    echo "  sudo apt-get install gstreamer1.0-plugins-bad"
    echo "  (Requires NVIDIA drivers with NVENC support)"
    exit 1
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
    echo "    Install with: sudo apt-get install gstreamer1.0-plugins-good"
    PLUGINS_OK=false
fi

# Video encoding (CPU)
if ! check_gst_plugin "x264enc"; then
    print_warning "x264enc plugin not found - CPU video encoding will not work"
    echo "    Install with: sudo apt-get install gstreamer1.0-plugins-ugly"
    PLUGINS_OK=false
fi

# Video encoding (GPU - optional)
if check_gst_plugin "nvh264enc" || check_gst_plugin "nvenc_h264"; then
    print_info "  GPU encoding: available"
else
    print_info "  GPU encoding: not available (will use CPU encoding)"
fi

# Audio encoding
if ! check_gst_plugin "opusenc"; then
    print_warning "opusenc plugin not found - audio encoding will not work"
    echo "    Install with: sudo apt-get install gstreamer1.0-plugins-base"
    PLUGINS_OK=false
fi

# WHIP sink
if ! check_gst_plugin "whipsink"; then
    print_warning "whipsink plugin not found - WHIP streaming will not work"
    echo "    Install with: sudo apt-get install gstreamer1.0-plugins-bad"
    PLUGINS_OK=false
fi

if [ "$PLUGINS_OK" = false ]; then
    echo ""
    print_warning "Some GStreamer plugins are missing. The build will continue,"
    print_warning "but the application may not function correctly."
fi

echo ""

# =============================================================================
# Set up pkg-config environment
# =============================================================================
echo "Setting up pkg-config environment..."

# Add common GStreamer pkg-config paths if not already set
if [ -z "$PKG_CONFIG_PATH" ]; then
    export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig"
else
    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/usr/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig"
fi

print_info "  PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
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
echo "To run the application, configure the required parameters:"
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

cd ..
