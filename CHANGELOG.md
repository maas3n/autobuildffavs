# Changelog

This file summarizes notable repository changes.

## v2.0.0 — 2026-09-09

### Build and reproducibility

- Updated the pinned FFmpeg build from 7.1.3 to 7.1.5.
- Pinned FFmpeg `n7.1.5` to commit `3a0867c2bfda4a4d4309ca1a8cbdc6175e67f587`.
- Pinned AviSynth+ `v3.7.5` to commit `6c7c26617a6675eec89e4d4a3565ed709df6511f`.
- Pinned FFMS2 `5.0` to commit `7ed5e4d039ca9a6236bd2ebdfdd656c4304fbe04`.
- Pinned yadifmod2 to commit `9db5d2118dc2800701c5137afcfe45f3163211da`.
- Added verification that release tags still resolve to the expected immutable commits before building.

### Safety and reruns

- Added Debian 13 preflight validation with an explicit `--allow-unsupported` override.
- Moved source/build trees into a dedicated configurable workspace under `${XDG_CACHE_HOME:-$HOME/.cache}/autobuildffavs` by default.
- Added `--jobs`, `--work-dir`, `--clean`, and `--update` handling plus matching environment overrides where applicable.
- Added checks that reused Git repositories point to the expected upstream origin.
- Refuse to build over modified, staged, or deleted tracked upstream source files.
- Stopped modifying global `/etc/checkinstallrc`; required options are now passed directly to `checkinstall`.
- Replaced the generic linker configuration with `/etc/ld.so.conf.d/autobuildffavs.conf`.
- Made yadifmod2 symlink creation use CMake's install manifest instead of a hard-coded versioned `.so` filename.

### Verification

- Added FFmpeg version verification after installation.
- Added explicit detection of FFmpeg's AviSynth demuxer.
- Added shared-library dependency checks for FFMS2 and yadifmod2.
- Added an end-to-end smoke test that creates a temporary FFV1 clip and processes it through AviSynth + FFMS2 + yadifmod2.
- Added automatic cleanup of temporary smoke-test files.

### Documentation and repository cleanup

- Reworked the README around the v2.0.0 workflow and options.
- Corrected the repository reference to `FFmpegAvisynthx264SyntaxExamples.txt`.
- Added a redistribution warning for the FFmpeg build produced with `--enable-nonfree` and `libfdk-aac`.
- Cleaned up the FFmpeg/AviSynth/x264 examples, including modernized command syntax and clearer CRF versus two-pass guidance.
- Added GitHub Actions checks for Bash syntax and ShellCheck.
- Added a repository license-status notice clarifying that no open-source license has been selected.

## v1.0.0 — 2026-06-11

- Initial public release of the Debian 13 source-build script for FFmpeg + AviSynth+ + FFMS2 + yadifmod2.
- Included `template.avs`, FFmpeg/AviSynth/x264 command examples, and `chapters.txt`.
