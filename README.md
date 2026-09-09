<div align="right">

##### Donation
<img src="https://upload.wikimedia.org/wikipedia/commons/4/46/Bitcoin.svg" width="14" height="14"> <small>**BTC:** `bc1q79hj2zukfmm75278a7wssjmexanuhvs5nequel`</small>

</div>

# FFmpeg + AviSynth+ + FFMS2 + yadifmod2 build script

**Current source version:** `v2.0.0`

For users who want to run FFmpeg natively with AviSynth+ on Debian, this project provides an automated source-build workflow for the complete toolchain.

The repository also includes an AviSynth+ template, FFmpeg/AviSynth+ command examples, x264 parameter examples, and notes on CRF and two-pass encoding.

**Author:** maas3n

## ✨ Features

- **Complete native pipeline:** Builds and installs **FFmpeg 7.1.5**, **AviSynth+ 3.7.5**, **FFMS2 5.0**, and **yadifmod2** from source.
- **Pinned source revisions:** FFmpeg, AviSynth+, and FFMS2 tags are verified against hard-coded immutable commit hashes before checkout; yadifmod2 is pinned directly to a commit. AviSynth+ submodules are initialized only after the pinned superproject revision has been verified and checked out.
- **AviSynth-enabled FFmpeg:** FFmpeg is built with GPL/non-free components and native AviSynth support.
- **Debian package tracking:** FFmpeg and AviSynth+ are installed through `checkinstall`, making them visible to Debian package-management tools and easier to remove later.
- **Less invasive configuration:** The script does not edit `/etc/checkinstallrc`; required `checkinstall` behavior is selected on the command line. Runtime linker paths are kept in the project-specific `/etc/ld.so.conf.d/autobuildffavs.conf` file.
- **Debian 13 preflight:** The script verifies Debian 13 (Trixie) before installing packages. `--allow-unsupported` can bypass the check explicitly.
- **Configurable parallel compilation:** Uses all available CPU cores by default, or a user-selected count via `--jobs N` or `JOBS=N`.
- **Dedicated workspace:** Source and build trees live under `${XDG_CACHE_HOME:-$HOME/.cache}/autobuildffavs` by default, or a custom `--work-dir`/`WORK_DIR` path.
- **Safer reruns:** Existing repositories are reused only when their `origin` matches the expected upstream repository. Modified/staged/deleted tracked source files cause a hard failure instead of being overwritten; untracked build products are left alone so normal reruns still work. `--clean` recreates known build output without deleting arbitrary user directories.
- **End-to-end verification:** In addition to library/version checks, the script creates a temporary test clip and processes it through AviSynth + FFMS2 + yadifmod2 before reporting success.

## 🚀 Prerequisites

- **OS:** Debian 13 (Trixie) — bare metal, VM, or WSL. Other systems are rejected by default because package names and build assumptions are Debian-13-specific.
- **APT sources:** Ensure your Debian sources (for example `/etc/apt/sources.list.d/debian.sources`) include `contrib`, `non-free`, and `non-free-firmware`. `libfdk-aac-dev` requires the non-free component.
- **Permissions:** `sudo` access is required for package installation, `checkinstall`, linker configuration, and system-wide installation under `/usr/local`.
- **Network:** An active internet connection is required for APT packages and GitHub repositories.

## 🛠️ Installation and usage

### 1. Download the build script

Release download (`v2.0.0`):

```bash
wget https://github.com/maas3n/autobuildffavs/releases/download/v2.0.0/autobuildffavs.sh
```

or:

```bash
curl -LO https://github.com/maas3n/autobuildffavs/releases/download/v2.0.0/autobuildffavs.sh
```

You can also clone the repository and use the copy included there.

### 2. Make the script executable

```bash
chmod +x autobuildffavs.sh
```

### 3. Run it

```bash
./autobuildffavs.sh
```

### Optional flags

```text
--clean                 Remove/recreate build output before compiling.
--update                Refresh remote Git metadata before checking out pins.
--jobs N                Use N parallel compilation jobs (default: all CPUs).
--work-dir PATH         Store source/build trees under PATH.
--allow-unsupported     Bypass the Debian 13 version check; APT/package assumptions still apply.
--help, -h              Show usage information.
```

Environment variables can also set the two most common resource/location options:

```bash
JOBS=4 WORK_DIR="$HOME/build/autobuildffavs" ./autobuildffavs.sh
```

Example with flags:

```bash
./autobuildffavs.sh --clean --update --jobs 4
```

> The build is pinned to **FFmpeg 7.1.5** (`n7.1.5` → `3a0867c2bfda4a4d4309ca1a8cbdc6175e67f587`), **AviSynth+ 3.7.5** (`v3.7.5` → `6c7c26617a6675eec89e4d4a3565ed709df6511f`), **FFMS2 5.0** (`5.0` → `7ed5e4d039ca9a6236bd2ebdfdd656c4304fbe04`), and yadifmod2 commit **`9db5d2118dc2800701c5137afcfe45f3163211da`**. `--update` may refresh tags/remote metadata, but the script rejects any tag that no longer resolves to its expected immutable commit.

## 📦 What gets installed?

### Part 1: AviSynth+ and FFmpeg

- Installs the required compilers, build tools, libraries, codecs, and development packages.
- Clones/reuses **AviSynth+**, verifies that tag **`v3.7.5`** resolves to the pinned commit, checks it out, updates its submodules, and packages it through `checkinstall`.
- Clones/reuses **FFmpeg**, verifies that tag **`n7.1.5`** resolves to the pinned commit, checks it out, and builds it with options including `--enable-gpl`, `--enable-nonfree`, and `--enable-avisynth`.
- Packages the custom FFmpeg build through `checkinstall`.
- Supplies `--install=yes` and `--fstrans=no` directly to `checkinstall` instead of changing global `/etc/checkinstallrc` defaults.
- Configures the runtime linker through `/etc/ld.so.conf.d/autobuildffavs.conf` so `/usr/local/lib` and `/usr/local/lib64` are recognized.

### Part 2: FFMS2 (FFmpegSource)

- Clones/reuses FFMS2, verifies that release tag **`5.0`** resolves to the pinned commit, and checks it out.
- Configures FFMS2 with AviSynth+ support.
- Compiles and installs it under `/usr/local` for frame-accurate source access from AviSynth scripts.

### Part 3: yadifmod2

- Clones/reuses the native Linux-capable fork of `yadifmod2` and checks out commit **`9db5d2118dc2800701c5137afcfe45f3163211da`**.
- Compiles the plugin with `CMake` and `Make` using the configured job count.
- Installs it under `/usr/local/lib/avisynth/`.
- Reads CMake's install manifest to identify the versioned yadifmod2 library installed by the current build, then creates `/usr/local/lib/avisynth/libyadifmod2.so` without hard-coding the `.so` filename or accidentally selecting a stale older installation.

## ✅ Final verification

The script does not report success until it has checked that:

- the `ffmpeg` found in `PATH` reports version **7.1.5**;
- FFmpeg exposes the `avisynth` demuxer;
- the FFMS2 shared library is installed under `/usr/local` and has no missing dynamic-library dependencies;
- `/usr/local/lib/avisynth/libyadifmod2.so` exists, resolves correctly, and has no missing dynamic-library dependencies;
- a temporary FFV1 test clip can be opened by `FFVideoSource`, processed by `Yadifmod2`, and decoded through FFmpeg's AviSynth demuxer.

Temporary smoke-test files are created with `mktemp` and removed automatically on exit.

If one of these checks fails, the script exits with an error instead of printing a misleading success message.

## 🎬 Workflow integration

With yadifmod2 installed alongside native AviSynth+ and FFMS2, you can create `.avs` processing scripts and feed them directly into FFmpeg. This supports workflows such as frame-accurate source loading, deinterlacing, cropping, and resizing with filters such as `Spline36Resize`.

## 📝 Notes

- The default source/build workspace is `${XDG_CACHE_HOME:-$HOME/.cache}/autobuildffavs`; use `--work-dir PATH` or `WORK_DIR=PATH` if you want it elsewhere.
- Reused Git repositories must have the expected GitHub `origin`. HTTPS, GitHub SSH, and `git://github.com/` forms are normalized before comparison.
- The script refuses to build when tracked source files are modified, staged, or deleted. It intentionally ignores untracked files because the supported build systems create untracked build products during ordinary reruns.
- `--clean` removes only known component build directories inside the workspace. It no longer removes a fixed `$HOME/yadifmod2_build` directory.
- `--update` fetches tags/remote metadata, but the actual source revisions remain pinned to hard-coded commits; if an upstream tag is moved, the script stops instead of following it.
- `--allow-unsupported` bypasses only the Debian 13 version check. The dependency names, APT workflow, and other build assumptions remain Debian-oriented.
- The script does **not** edit `/etc/checkinstallrc`; command-line options override the relevant `checkinstall` defaults for each package operation.
- If you encounter plugin-loading issues, verify the paths used in your AviSynth script, especially `/usr/local/lib/avisynth/`.
- See `template.avs` for a working path/layout example.
- See `FFmpegAvisynthx264SyntaxExamples.txt` for additional FFmpeg and AviSynth+ usage examples.

## 📄 AviSynth+ template

Download `template.avs`:

```bash
wget https://github.com/maas3n/autobuildffavs/raw/main/template.avs
```

or:

```bash
curl -LO https://github.com/maas3n/autobuildffavs/raw/main/template.avs
```

### `template.avs`

```avs
# Enable debugging and log errors to your home directory
SetLogParams("/home/YOURUSERNAME/AviSynthPlusdebug.log", 4)

# Load source plugin explicitly if it is not autoloaded
LoadPlugin("/usr/local/lib/libffms2.so")

# Load the native Linux yadifmod2 plugin
LoadPlugin("/usr/local/lib/avisynth/libyadifmod2.so")

# Open the source with FFMS2
FFVideoSource("/home/YOURUSERNAME/input.mkv")

# Optional short section for test encodes
Trim(7200, 7272)

# Deinterlace
# order=1: top field first
# order=0: bottom field first
Yadifmod2(mode=1, order=1)

# Crop
Crop(2, 2, -2, -2)

# Resize
Spline36Resize(1024, 576)
```

Adjust `/home/YOURUSERNAME/` and the source-specific processing values for your own system and video.

## 🎞️ Example workflow

The following example assumes a Blu-ray REMUX containing one H.264 video stream and one AC-3 audio stream.

### 1. Demux video and audio

```bash
ffmpeg -i SOURCE.mkv \
  -map 0:v -c:v copy input.mkv \
  -map 0:a -c:a copy audio.ac3
```

### 2. Preview the AviSynth output

Install mpv if necessary:

```bash
sudo apt install mpv
```

Then preview the script:

```bash
mpv template.avs
```

Inspect it with ffprobe:

```bash
ffprobe template.avs
```

### 3. Test and tune the encode

Use a short `Trim()` section in `template.avs` while evaluating deinterlacing, cropping, resizing, and encoder settings. When you are satisfied, remove or comment out the `Trim()` line before the final encode.

There is no universal CRF value or x264 tuning recipe that is correct for every source. A common starting point is CRF 18, followed by visual comparisons against the source and adjustment according to your quality and size goals.

CRF and two-pass encoding serve different rate-control goals:

- **CRF** targets a chosen quality level while allowing file size/bitrate to vary.
- **Two-pass bitrate encoding** is useful when you need to target a particular average bitrate or output size.

You do not need to use two-pass encoding before switching to CRF. Choose the rate-control method that matches your final goal, and use representative test samples when tuning other x264 parameters.

### 4. Encode through AviSynth+

Example based on the original project's x264 settings:

```bash
ffmpeg -i template.avs \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -profile:v high \
  -preset veryslow \
  -x264-params "crf=18:level=4.1:fps=23.976:aq-mode=1:deblock=-3,-3:aq-strength=0.80:psy-rd=0.95,0.00:dct-decimate=0:mbtree=0:fast-pskip=0" \
  encode.mkv
```

The values above are examples, not universal recommendations. Tune them for the source and your own quality/size requirements.

### 5. Mux the encoded video and original audio

```bash
ffmpeg -i encode.mkv -i audio.ac3 -c copy finish.mkv
```

## Optional: subtitles and track metadata

Example with an external English `.srt` subtitle:

```bash
ffmpeg -i encode.mkv -i audio.ac3 -i subtitle.srt \
  -map 0 -map 1 -map 2 \
  -c copy \
  -metadata:s:v:0 title="Title of The Movie" \
  -metadata:s:a:0 language=eng \
  -metadata:s:a:0 title="English Audio" \
  -metadata:s:s:0 language=eng \
  -metadata:s:s:0 title="English SubRip" \
  finish.mkv
```

## Optional: chapters

Download the chapter template:

```bash
wget https://github.com/maas3n/autobuildffavs/raw/main/chapters.txt
```

or:

```bash
curl -LO https://github.com/maas3n/autobuildffavs/raw/main/chapters.txt
```

Mux chapters from an FFmetadata file:

```bash
ffmpeg -i encode.mkv -i audio.ac3 -i subtitle.srt -i chapters.txt \
  -map 0 -map 1 -map 2 \
  -map_metadata 3 -map_chapters 3 \
  -c copy \
  -metadata:s:v:0 title="Title of The Movie" \
  -metadata:s:a:0 language=eng \
  -metadata:s:a:0 title="English Audio" \
  -metadata:s:s:0 language=eng \
  -metadata:s:s:0 title="English SubRip" \
  finish.mkv
```

### `chapters.txt` template

```ini
;FFMETADATA1
title=Title of The Movie
artist=Director or Studio Name
date=2026
description=A brief synopsis of the movie.

; FFMETADATA1 must be the first line of the file.

[CHAPTER]
TIMEBASE=1/1000
START=0
END=120000
title=Chapter 1: The Opening

[CHAPTER]
TIMEBASE=1/1000
START=120000
END=345000
title=Chapter 2: The Setup

[CHAPTER]
TIMEBASE=1/1000
START=345000
END=720500
title=Chapter 3: The Climax

[CHAPTER]
TIMEBASE=1/1000
START=720500
END=800000
title=Chapter 4: End Credits
```

## ⚠️ Important

This script installs source-built software under `/usr/local` and writes `/etc/ld.so.conf.d/autobuildffavs.conf` so the runtime linker can find `/usr/local/lib` and `/usr/local/lib64`. It does not edit `/etc/checkinstallrc`. Review the script before running it, especially on systems where `/usr/local` already contains custom multimedia libraries.

Because the FFmpeg build enables both `--enable-gpl` and `--enable-nonfree` (including `libfdk-aac`), FFmpeg documents the resulting binary as **unredistributable**. This repository distributes the build script, not compiled FFmpeg binaries. See https://ffmpeg.org/legal.html for FFmpeg licensing guidance.

## License

No open-source license has been selected for autobuildffavs yet. The source is publicly viewable in this repository, but no additional reuse/distribution rights are granted until a license is added. FFmpeg, AviSynthPlus, and other third-party projects remain governed by their own licenses.
