#!/bin/bash
# =============================================================================
# Master Build Script: FFmpeg + AviSynth+ + FFMS2 + yadifmod2
# Optimized for Debian 13 (Trixie)
# =============================================================================

set -e  # Exit immediately if any command fails

# =============================================================================
# PART 1: FFmpeg + AviSynth+
# =============================================================================
START_DIR="$(pwd)"
CLEAN_BUILD=false
UPDATE_REPOS=false

# Get number of CPU cores safely across minimal environments
NUM_CORES=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN || echo 1)

# Parse flags
for arg in "$@"; do
    case $arg in
        --clean)   CLEAN_BUILD=true ;;
        --update)  UPDATE_REPOS=true ;;
        *)         echo "Unknown option: $arg"; exit 1 ;;
    esac
done

echo "=== Starting FFmpeg + AviSynth+ compilation using $NUM_CORES threads ==="

# 1. Initialize Baseline Tools
echo "📦 Updating package index and installing core utilities..."
sudo apt update
sudo apt install -y wget curl git

# 2. Install dependencies (Consolidated APT update check)
echo "🛡️ Refreshing package indices and installing dependencies..."
sudo apt update
sudo apt install -y build-essential autoconf libtool pkg-config cmake \
    libsoundtouch-dev libdevil-dev libx264-dev libx265-dev libfdk-aac-dev \
    libass-dev libopus-dev libvpx-dev libdav1d-dev libaom-dev libmp3lame-dev libplacebo-dev libva-dev zlib1g-dev libbz2-dev \
    nasm yasm python3-dev python3-pip libfontconfig1-dev libfreetype6-dev \
    libjpeg-dev checkinstall

# Global checkinstall configuration overrides
sudo mkdir -p /etc/checkinstallrc.d
echo "INSTALL=1" | sudo tee -a /etc/checkinstallrc >/dev/null
echo "FADDALL=1" | sudo tee -a /etc/checkinstallrc >/dev/null
echo "TRANSLATE=0" | sudo tee -a /etc/checkinstallrc >/dev/null

# Ensure runtime linker searches local paths early
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/usr-local-lib.conf >/dev/null
echo "/usr/local/lib64" | sudo tee -a /etc/ld.so.conf.d/usr-local-lib.conf >/dev/null
sudo ldconfig  # Reload instantly to activate the paths

# 3. Build AviSynth+
echo "=== Building AviSynth+ ==="
if [ ! -d "AviSynthPlus" ]; then
    git clone --recursive https://github.com/AviSynth/AviSynthPlus.git
elif [ "$UPDATE_REPOS" = true ]; then
    echo "🔄 Updating AviSynth+ repository and submodules..."
    cd AviSynthPlus
    git pull
    git submodule update --init --recursive
    cd "$START_DIR"
fi

cd AviSynthPlus
if [ "$CLEAN_BUILD" = true ]; then rm -rf avisynth-build; fi
mkdir -p avisynth-build && cd avisynth-build

# Configuration and Compiling via Make
cmake ../ -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
make -j"$NUM_CORES" # Optimization: Utilizing your defined CPU threads

# Extract exact version dynamically and pass to checkinstall (fallback altered to 3.7.5)
AVS_VERSION=$(grep -oP 'project\(AviSynthPlus VERSION \K[0-9.]+' ../CMakeLists.txt || echo "3.7.5")

# Package with checkinstall (Piped version description directly)
echo "AviSynth+ frame server library compiled from source" | sudo checkinstall --pkgname=avisynth --pkgversion="$AVS_VERSION" --backup=no --default

sudo ldconfig
cd "$START_DIR"

# 4. Build FFmpeg n7.1.3 (With Tightened Git Logic)
echo "=== Building FFmpeg 7.1.3 ==="
if [ ! -d "FFmpeg" ]; then
    git clone https://github.com/FFmpeg/FFmpeg.git
fi

cd FFmpeg
if [ "$UPDATE_REPOS" = true ]; then
    echo "🔄 Fetching latest FFmpeg repository updates..."
    git fetch --tags  
fi

git checkout n7.1.3

if [ "$CLEAN_BUILD" = true ]; then make clean || true; fi

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH

./configure \
  --extra-cflags="-Wno-error=stringop-overflow -I/usr/local/include" \
  --extra-ldflags="-L/usr/local/lib -L/usr/local/lib64 -Wl,-rpath,/usr/local/lib" \
  --enable-gpl \
  --enable-nonfree \
  --enable-avisynth \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libfdk-aac \
  --enable-libmp3lame \
  --enable-libass \
  --enable-libfontconfig \
  --enable-libopus \
  --enable-libvpx \
  --enable-libaom \
  --enable-libdav1d \
  --enable-libfreetype \
  --extra-libs="-ldl" \
  --enable-libplacebo \
  --enable-vaapi \
  --enable-zlib \
  --enable-bzlib \
  --enable-shared \
  --prefix=/usr/local

make -j"$NUM_CORES" # Optimization: Utilizing your defined CPU threads

# Package with checkinstall (Piped version description directly)
echo "Custom FFmpeg build with AviSynth+ enabled" | sudo checkinstall --pkgname=ffmpeg-custom \
  --pkgversion="7.1.3" \
  --default

sudo ldconfig
cd "$START_DIR"

# 5. Verification & Shell Reset
echo "=== Installation Complete! Verification ==="
hash -r  # Reset shell paths so it evaluates the new binaries immediately

echo "FFmpeg version:"
ffmpeg -version | head -n 5
echo
echo "AviSynth support:"
ffmpeg -demuxers 2>/dev/null | grep -E "avisynth" || echo "❌ AviSynth demuxer not found!"

echo
echo "✅ Complete! Your FFmpeg + AviSynth+ workspace is fully set up."
echo

# =============================================================================
# PART 2: FFMS2
# =============================================================================
cd "$START_DIR"  # Ensure we reset to the original directory before cloning FFMS2

echo "========================================="
echo " Starting FFMS2 Compilation & Installation"
echo "========================================="

# 1. Install necessary build dependencies
echo "--> Installing build dependencies..."
sudo apt update
sudo apt install -y build-essential git pkg-config autoconf automake libtool \
libavcodec-dev libavformat-dev libswscale-dev libavutil-dev libswresample-dev

# 2. Clone the repository and checkout the latest release
echo "--> Cloning FFMS2 repository..."
if [ -d "ffms2" ]; then
    echo "    Directory 'ffms2' already exists. Fetching updates..."
    cd ffms2
    git fetch --tags --all
else
    git clone https://github.com/FFMS/ffms2.git
    cd ffms2
fi

# Find the latest release tag (ignoring pre-releases/release candidates)
LATEST_TAG=$(git tag -l | grep -E '^v?[0-9]+\.[0-9]+(\.[0-9]+)?$' | sort -V | tail -n1)

if [ -z "$LATEST_TAG" ]; then
    echo "--> [Warning] No standard release tags found. Falling back to the latest tag available..."
    LATEST_TAG=$(git describe --tags $(git rev-list --tags --max-count=1) 2>/dev/null || echo "")
fi

if [ -n "$LATEST_TAG" ]; then
    echo "--> Checking out latest release: ${LATEST_TAG}"
    git checkout "$LATEST_TAG"
else
    echo "--> [Warning] No tags found at all. Proceeding with the default branch..."
fi

# 3. Generate build files
echo "--> Running autogen.sh..."
./autogen.sh

# 4. Configure the build with AviSynth+ support
echo "--> Configuring build flags..."
./configure --prefix=/usr/local \
            --enable-shared \
            --enable-avisynth \
            CPPFLAGS="-I/usr/local/include/avisynth"

# 5. Compile using all available CPU cores
THREADS=$(nproc)
echo "--> Compiling FFMS2 using ${THREADS} threads..."
make -j"${THREADS}"

# 6. Install to system
echo "--> Installing binaries and updating linker cache..."
sudo make install
sudo ldconfig

echo "========================================="
echo " FFMS2 Installation Completed Successfully!"
echo "========================================="
echo

# =============================================================================
# PART 3: yadifmod2
# =============================================================================
cd "$START_DIR"  # Final reset just to be clean

echo "================================================="
echo " Compiling and Installing yadifmod2 for Debian   "
echo "================================================="

# 1. Install required build tools if missing
echo "Checking build dependencies..."
sudo apt update
sudo apt install -y git cmake g++ make

# 2. Setup a clean build directory
BUILD_DIR="$HOME/yadifmod2_build"
if [ -d "$BUILD_DIR" ]; then
    echo "Cleaning up old build directory..."
    rm -rf "$BUILD_DIR"
fi

# 3. Clone the native Linux fork
echo "Cloning yadifmod2 source code..."
git clone https://github.com/Asd-g/yadifmod2.git "$BUILD_DIR"
cd "$BUILD_DIR"

# 4. Configure with CMake
echo "Configuring build files..."
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..

# 5. Compile using all available CPU cores
echo "Compiling plugin..."
make -j$(nproc)

# 6. Install directly to the system
echo "Installing libyadifmod2.so natively..."
sudo make install

# Create a symlink to ensure the generic .so name exists
sudo ln -sf /usr/local/lib/avisynth/libyadifmod2.0.2.8.so /usr/local/lib/avisynth/libyadifmod2.so

# 7. Verification
echo "Verifying installation path..."
if [ -f "/usr/local/lib/avisynth/libyadifmod2.so" ]; then
    echo "================================================="
    echo " SUCCESS: yadifmod2 installed successfully!"
    ls -l /usr/local/lib/avisynth/libyadifmod2.so
    echo "================================================="
else
    echo "Error: Installation file not found where expected."
    exit 1
fi