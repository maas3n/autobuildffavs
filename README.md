# Debian 13 Multimedia Build Script: FFmpeg + AviSynthPlus + FFMS2 + yadifmod2
#
# For those who want to use FFmpeg natively with AviSynthPlus on Debian for whatever reason.
# This script provides an automated build solution
#


The script compiles and installs FFmpeg + AviSynthPlus + FFMS2 + yadifmod2 from source on Debian 13 (Trixie). 

This script automates the dependency fetching, configuration, compilation, and installation of FFmpeg and native Linux AviSynthPlus, alongside frame serving & deinterlacing plugins.

**Author:** maas3n

## ✨ Features

* **Comprehensive Pipeline:** Builds **FFmpeg 7.1.3** (with non-free components and AviSynth support), **AviSynthPlus**, **FFMS2**, and **yadifmod2** from source.
* **Clean Package Management:** Integrates `checkinstall` and installs FFmpeg + AvisynthPlus using checkinstall, to manage the compiled binaries as standard Debian packages, keeping your system clean and making uninstallation straightforward via `apt`.
* **Standard Build Systems:** Exclusively relies on standard `CMake` and `Make` workflows for compilation, entirely avoiding the need for Ninja or other alternative build systems.
* **WSL Ready:** Extensively tested to run flawlessly on Debian 13 running via Windows Subsystem for Linux (WSL), perfect for users passing local Windows file paths into native Linux scripts.
* **Core Optimizations:** To speed up compile times.

## 🚀 Prerequisites

* **OS:** Debian 13 (Trixie) – *Bare metal, VM, or WSL.*
* **Debian Sources:** Ensure your APT sources (e.g., `/etc/apt/sources.list.d/debian.sources`) are configured to include `contrib`, `non-free`, and `non-free-firmware`.
* **Permissions:** Root (`sudo`) access is required to install dependencies and run `checkinstall`/`make install`.
* **Network:** An active internet connection to download packages from `apt` and clone repositories from GitHub.

## 🛠️ Usage

1. **Clone or Download** the script to your Debian environment.
2. **Make it executable:**
   ```bash
   chmod +x autobuildffavs.sh
   ```
3. **Run the script:**
   ```bash
   ./autobuildffavs.sh
   ```

## 📦 What gets installed?

### Part 1: FFmpeg & AviSynthPlus
* Installs all required core dependencies, libraries, and codecs (`libx264`, `libx265`, `libdav1d`, `libvpx`, etc.).
* Clones and builds **AviSynthPlus**. Packaged via `checkinstall`.
* Clones **FFmpeg** (checkout `n7.1.3`), configured with `--enable-gpl`, `--enable-nonfree`, and `--enable-avisynth`. Packaged via `checkinstall`.
* Updates the runtime linker bindings so libraries in `/usr/local/lib` are immediately recognized.

### Part 2: FFMS2 (FFmpegSource)
* Fetches the latest stable release tag of FFMS2.
* Configures it with AviSynthPlus support
* Compiles and installs natively, allowing frame-accurate access to video files within AviSynth scripts.

### Part 3: yadifmod2
* Clones the native Linux fork of `yadifmod2`.
* Compiles the plugin using `CMake` and `Make`.
* Installs the resulting `.so` file directly into `/usr/local/lib/avisynth/` and generates the necessary symlinks so AviSynthPlus can load it.

## 🎬 Workflow Integration
With `yadifmod2` installed alongside native AviSynthPlus and FFMS2, your pipeline is optimized for high-quality processing. You can seamlessly utilize standard deinterlacing alongside preferred scaling algorithms, like `Spline36Resize`, directly within your `.avs` scripts.

## 📝 Notes
* The script automatically overrides `checkinstall` defaults (`INSTALL=1`, `FADDALL=1`, `TRANSLATE=0`) to ensure smooth unattended packaging without interactive prompts.
* If you run into any path issues with plugins later, ensure your AviSynth scripts correctly reference `/usr/local/lib/avisynth/`.


