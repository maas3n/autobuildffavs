# FFmpeg+AviSynthPlus+FFMS2+yadifmod2 build script
## For those who want to use FFmpeg natively with AviSynthPlus on Debian for whatever reason. This script provides an automated build solution
* **The script compiles and installs FFmpeg + AviSynthPlus + FFMS2 + yadifmod2 from source on Debian 13 (Trixie)** 
* **This script automates the dependency fetching, configuration, compilation, and installation of FFmpeg and native Linux AviSynthPlus, alongside frame serving & deinterlacing plugins.**

-AviSynthPlus template script, FFmpeg syntaxes with AviSynthPlus, x264 params uasage (and 2pass explained) is included in the repo-

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
* The script automatically overrides `checkinstall` defaults (`INSTALL=1`, `FADDALL=1`, `TRANSLATE=0`)
* If you run into any path issues with plugins later, ensure your AviSynth scripts correctly reference `/usr/local/lib/avisynth/`.
* Use the template.avs for correct path's
* Take a look into FFmpegAvisynthSyntaxExamples.txt for examples of usage

## 📄 Templates & Examples
* **Script template for AviSynthPlus (tested & confirmed working after running the autobuildffavs.sh script)**
### template.avs
```
# Enable debugging and log all errors to home directory
SetLogParams("/home/YOURUSERNAME/AviSynthPlusdebug.log", 4)
#
# Load your source plugin explicitly if not autoloaded
LoadPlugin("/usr/local/lib/libffms2.so")
# Load your native Linux yadifmod2 plugin
LoadPlugin("/usr/local/lib/avisynth/libyadifmod2.so")
#
# Open your video file using FFMS2
FFVideoSource("/home/YOURUSERNAME/input.mkv")
# Cut for test encode
Trim(7200, 7272)
# Deinterlace
# (mode=1, order=1) If your video is top field first
# (mode=1, order=0) If your video is bottom field first
Yadifmod2(mode=1, order=1)
# Crop
Crop(2, 2, -2, -2)
# Resize
Spline36Resize(1024, 576)
```
### Examples of FFmpeg & AviSynthPlus usage: FFmpeg syntaxes with AviSynthPlus, sx264 params and (2pass explained)
#### EXAMPLE OF USAGE:
Demux your source (in this case, a Blu-ray REMUX with x1 main video stream in H264 & x1 main audio stream in AC-3 )
```
ffmpeg -i SOURCE.mkv -map 0:v -c:v copy input.mkv -map 0:a -c:a copy audio.ac3
```
preview your videofile in mpv (sudo apt install mpv) for visuals
```
mpv -i template.avs
```
priview your videofile in ffprobe for values
```
ffprobe -i template.avs
```
#After optimizing your template.avs script: Trimming (if needed), Deinterlacing (if needed), Cropping (if needed), Resizing (if needed)
#run the template.avs in ffmpeg for test encodes (optimizing your x264 parameters if needed)
#when satisfied with the result, add a # in front of line 12 in your template.avs script to remove the Trim
#(in this case, i have set aq mode to 1, aq strengt to 0.80, psy-rd to 0.95,0.00, disabled mbtree, etc)
#(I am not the right person to explain the purpose and use of all x264 parameters
#but theres a lof of info out there on differen forums about what the different x264 parameters will do to your video) 
#PS: The correct way to do this is to encode in 2pass while testing/tuning the parameters, comparing the results (b frames) with the source. 
#Then switch back to crf when satisfied, aiming for the highest compression (crf) without losing visual quality-
#-while again comparing b frames with the source. start at 18. if no visual quality loss, go up 19, if visual quality loss try 18.5 etc. 
#sometimes you need to go lower than 18. Most important: There's no correct answers key. you need to use your eyes, comparing.
#But again, im not going to make a "x264 advanced encoding guide" 

Now start encoding your video file
```
ffmpeg -i template.avs -c:v libx264 -pix_fmt yuv420p -profile:v high -preset veryslow -x264opts crf=18:level=4.1:fps=23.976:aq-mode=1:deblock=-3,-3:aq-strength=0.80:psy-rd=0.95,0.00:dct-decimate=0:mbtree=0:fast-pskip=0 encode.mkv
```
Now mux the encoded video and the audio file to mkv
```
ffmpeg -i encode.mkv -i audio.ac3 -c copy finish.mkv
```
#OPTIONAL1(for educational purposes only)
#You can also add subtitles, metadata, and titles for the tracks inside the mkv
#(in this case i have a separate .srt file in English, a separate chapter file saved as .txt in the right formatting) 
Now start muxing
```
ffmpeg -i encode.mkv -i audio.ac3 -i subtitle.srt -map 0 -map 1 -map 2 -c copy -metadata:s:v:0 title="Title of The Movie" -metadata:s:a:0 language=eng -metadata:s:a:0 title="English Audio" -metadata:s:s:0 language=eng -metadata:s:s:0 title="English SubRip" finish.mkv
```
#OPTIONAL2(for educational purposes only)
If you want to include Chapters
```
ffmpeg -i encode.mkv -i audio.ac3 -i subtitle.srt -i chapters.txt -map 0 -map 1 -map 2 -map_metadata 3 -map_chapters 3 -c copy -metadata:s:v:0 title="Title of The Movie" -metadata:s:a:0 language=eng -metadata:s:a:0 title="English Audio" -metadata:s:s:0 language=eng -metadata:s:s:0 title="English SubRip" finish.mkv
```
PS: Chapters template in right formatting (save as .txt):
```
;FFMETADATA1
title=Title of The Movie
artist=Director or Studio Name
date=2026
description=A brief synopsis of the movie.

; The section above is the Global Metadata. 
; The line ;FFMETADATA1 is absolutely mandatory and must be the very first line.

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
# Thats it!




