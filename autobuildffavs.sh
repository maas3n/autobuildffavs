#!/usr/bin/env bash
# =============================================================================
# Master Build Script: FFmpeg + AviSynth+ + FFMS2 + yadifmod2
# Target: Debian 13 (Trixie), including WSL
# =============================================================================

set -Eeuo pipefail

on_error() {
    local rc="$1"
    local line_no="$2"
    local command="$3"

    printf '\nERROR: command failed at line %d: %s (exit %d)\n' "$line_no" "$command" "$rc" >&2
    exit "$rc"
}
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

readonly FFMPEG_VERSION="7.1.5"
readonly FFMPEG_REF="n${FFMPEG_VERSION}"
readonly FFMPEG_COMMIT="3a0867c2bfda4a4d4309ca1a8cbdc6175e67f587"
readonly AVISYNTH_VERSION="3.7.5"
readonly AVISYNTH_REF="v${AVISYNTH_VERSION}"
readonly AVISYNTH_COMMIT="6c7c26617a6675eec89e4d4a3565ed709df6511f"
readonly FFMS2_VERSION="5.0"
readonly FFMS2_REF="${FFMS2_VERSION}"
readonly FFMS2_COMMIT="7ed5e4d039ca9a6236bd2ebdfdd656c4304fbe04"
readonly YADIFMOD2_COMMIT="9db5d2118dc2800701c5137afcfe45f3163211da"
DEFAULT_JOBS="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
readonly DEFAULT_JOBS
readonly DEFAULT_WORK_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/autobuildffavs"

CLEAN_BUILD=false
UPDATE_REPOS=false
ALLOW_UNSUPPORTED=false
JOBS="${JOBS:-$DEFAULT_JOBS}"
WORK_DIR="${WORK_DIR:-$DEFAULT_WORK_DIR}"
SMOKE_DIR=""

cleanup() {
    if [ -n "${SMOKE_DIR:-}" ] && [ -d "$SMOKE_DIR" ]; then
        rm -rf -- "$SMOKE_DIR" || true
    fi
}
trap cleanup EXIT

usage() {
    cat <<'USAGE'
Usage: ./autobuildffavs.sh [options]

Options:
  --clean                 Remove/recreate build output before compiling.
  --update                Refresh remote Git metadata before checking out pins.
  --jobs N                Use N parallel compilation jobs (default: all CPUs).
  --work-dir PATH         Store source/build trees under PATH.
  --allow-unsupported     Bypass the Debian 13 version check; APT/package assumptions still apply.
  --help, -h              Show this help text.

Environment overrides:
  JOBS=N                  Same purpose as --jobs N.
  WORK_DIR=PATH           Same purpose as --work-dir PATH.

Pinned source revisions:
  FFmpeg      7.1.5 (tag n7.1.5 -> 3a0867c2bfda4a4d4309ca1a8cbdc6175e67f587)
  AviSynth+   3.7.5 (tag v3.7.5 -> 6c7c26617a6675eec89e4d4a3565ed709df6511f)
  FFMS2       5.0   (tag 5.0 -> 7ed5e4d039ca9a6236bd2ebdfdd656c4304fbe04)
  yadifmod2   9db5d2118dc2800701c5137afcfe45f3163211da
USAGE
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: required command '$1' was not found." >&2
        exit 1
    fi
}

require_positive_integer() {
    local value="$1"
    local label="$2"
    if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: $label must be a positive integer; got '$value'." >&2
        exit 1
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --update)
            UPDATE_REPOS=true
            shift
            ;;
        --jobs)
            [ "$#" -ge 2 ] || { echo "ERROR: --jobs requires a value." >&2; exit 1; }
            JOBS="$2"
            shift 2
            ;;
        --jobs=*)
            JOBS="${1#*=}"
            shift
            ;;
        --work-dir)
            [ "$#" -ge 2 ] || { echo "ERROR: --work-dir requires a path." >&2; exit 1; }
            WORK_DIR="$2"
            shift 2
            ;;
        --work-dir=*)
            WORK_DIR="${1#*=}"
            shift
            ;;
        --allow-unsupported)
            ALLOW_UNSUPPORTED=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

require_positive_integer "$JOBS" "--jobs/JOBS"

preflight_os() {
    echo "=== Checking operating system ==="

    if [ ! -r /etc/os-release ]; then
        if [ "$ALLOW_UNSUPPORTED" = true ]; then
            echo "WARNING: /etc/os-release is unavailable; continuing because --allow-unsupported was supplied." >&2
            return
        fi
        echo "ERROR: cannot identify the operating system; expected Debian 13." >&2
        echo "Use --allow-unsupported to bypass this check at your own risk." >&2
        exit 1
    fi

    # shellcheck disable=SC1091
    . /etc/os-release
    local id="${ID:-unknown}"
    local version_id="${VERSION_ID:-unknown}"

    if [ "$id" != "debian" ] || [ "$version_id" != "13" ]; then
        if [ "$ALLOW_UNSUPPORTED" = true ]; then
            echo "WARNING: detected ${PRETTY_NAME:-$id $version_id}; this project targets Debian 12." >&2
            return
        fi
        echo "ERROR: detected ${PRETTY_NAME:-$id $version_id}; this project targets Debian 13 (Trixie)." >&2
        echo "Use --allow-unsupported to bypass this check at your own risk." >&2
        exit 1
    fi

    echo "OK: ${PRETTY_NAME:-Debian 13}"
}

prepare_work_dir() {
    if [ -z "$WORK_DIR" ]; then
        echo "ERROR: --work-dir/WORK_DIR must not be empty." >&2
        exit 1
    fi
    mkdir -p -- "$WORK_DIR"
    WORK_DIR="$(cd -- "$WORK_DIR" && pwd -P)"
    echo "Build workspace: $WORK_DIR"
}

verify_git_repo() {
    local dir="$1"

    if [ -e "$dir" ]; then
        if [ ! -d "$dir" ] || ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            echo "ERROR: '$dir' exists but is not a Git work tree." >&2
            exit 1
        fi
    fi
}

normalize_github_remote() {
    local url="$1"

    case "$url" in
        git@github.com:*)
            url="https://github.com/${url#git@github.com:}"
            ;;
        ssh://git@github.com/*)
            url="https://github.com/${url#ssh://git@github.com/}"
            ;;
        git://github.com/*)
            url="https://github.com/${url#git://github.com/}"
            ;;
    esac

    url="${url%/}"
    url="${url%.git}"
    printf '%s\n' "${url,,}"
}

verify_repo_origin() {
    local dir="$1"
    local expected_url="$2"
    local actual_url

    if ! actual_url="$(git -C "$dir" remote get-url origin 2>/dev/null)"; then
        echo "ERROR: '$dir' has no readable 'origin' remote." >&2
        exit 1
    fi

    if [ "$(normalize_github_remote "$actual_url")" != "$(normalize_github_remote "$expected_url")" ]; then
        echo "ERROR: unexpected Git origin for '$dir'." >&2
        echo "Expected: $expected_url" >&2
        echo "Actual:   $actual_url" >&2
        exit 1
    fi
}

verify_tracked_source_clean() {
    local dir="$1"

    # Ignore untracked build products so ordinary reruns remain possible, but
    # never build with modified/staged/deleted upstream tracked source files.
    # Submodules are verified separately after they are synchronized.
    if ! git -C "$dir" diff --quiet --ignore-submodules=all -- ||
       ! git -C "$dir" diff --cached --quiet --ignore-submodules=all --; then
        echo "ERROR: tracked source changes were detected in '$dir'." >&2
        echo "Commit/stash/revert them before running this script; nothing will be deleted automatically." >&2
        git -C "$dir" status --short --untracked-files=no >&2 || true
        exit 1
    fi
}

verify_submodules_clean() {
    local dir="$1"
    local submodule_state

    if ! submodule_state="$(git -C "$dir" submodule status --recursive 2>&1)"; then
        echo "ERROR: failed to inspect submodule state in '$dir':" >&2
        printf '%s\n' "$submodule_state" >&2
        exit 1
    fi

    if grep -Eq '^[+-U]' <<<"$submodule_state"; then
        echo "ERROR: one or more submodules in '$dir' are not at the commits recorded by the pinned source revision:" >&2
        printf '%s\n' "$submodule_state" >&2
        exit 1
    fi

    if ! git -C "$dir" submodule foreach --quiet --recursive \
        'git diff --quiet --ignore-submodules=all -- && git diff --cached --quiet --ignore-submodules=all --'; then
        echo "ERROR: tracked changes were detected inside a submodule of '$dir'." >&2
        echo "Commit/stash/revert them before running this script; nothing will be deleted automatically." >&2
        git -C "$dir" submodule foreach --quiet --recursive \
            'git status --short --untracked-files=no || true' >&2 || true
        exit 1
    fi
}

ensure_repo() {
    local dir="$1"
    local url="$2"

    verify_git_repo "$dir"

    if [ ! -d "$dir" ]; then
        # Clone only the superproject here. Submodules, when required, are
        # initialized only after the superproject has been verified and moved
        # to its pinned immutable revision.
        git clone "$url" "$dir"
    fi

    verify_repo_origin "$dir" "$url"
    verify_tracked_source_clean "$dir"

    if [ "$UPDATE_REPOS" = true ]; then
        echo "Refreshing remote metadata for $(basename "$dir")..."
        git -C "$dir" fetch --tags --prune --force origin
    fi
}

checkout_pinned_ref() {
    local dir="$1"
    local ref="$2"
    local expected_commit="$3"
    local refspec="refs/tags/${ref}^{commit}"

    if ! git -C "$dir" rev-parse -q --verify "$refspec" >/dev/null 2>&1; then
        echo "Fetching missing pinned tag '$ref' for $(basename "$dir")..."
        git -C "$dir" fetch --tags --force origin
    fi

    local target_commit
    target_commit="$(git -C "$dir" rev-parse "$refspec")"
    if [ "$target_commit" != "$expected_commit" ]; then
        echo "ERROR: tag '$ref' in '$dir' does not resolve to the expected immutable commit." >&2
        echo "Expected: $expected_commit" >&2
        echo "Actual:   $target_commit" >&2
        exit 1
    fi

    git -C "$dir" checkout --detach "$expected_commit"

    local actual_commit
    actual_commit="$(git -C "$dir" rev-parse HEAD)"
    if [ "$actual_commit" != "$expected_commit" ]; then
        echo "ERROR: failed to check out pinned commit '$expected_commit' in '$dir'." >&2
        exit 1
    fi

    verify_tracked_source_clean "$dir"
}

checkout_pinned_commit() {
    local dir="$1"
    local expected_commit="$2"

    if ! git -C "$dir" cat-file -e "${expected_commit}^{commit}" 2>/dev/null; then
        echo "Fetching missing pinned commit '$expected_commit' for $(basename "$dir")..."
        git -C "$dir" fetch origin "$expected_commit"
    fi

    git -C "$dir" checkout --detach "$expected_commit"

    local actual_commit
    actual_commit="$(git -C "$dir" rev-parse HEAD)"
    if [ "$actual_commit" != "$expected_commit" ]; then
        echo "ERROR: failed to check out pinned commit '$expected_commit' in '$dir'." >&2
        exit 1
    fi

    verify_tracked_source_clean "$dir"
}

install_dependencies() {
    echo "=== Installing build dependencies ==="
    sudo apt update

    # libfdk-aac-dev is in Debian's non-free component. Give a useful error
    # before the large install command if the configured APT sources omit it.
    if ! apt-cache show libfdk-aac-dev >/dev/null 2>&1; then
        cat >&2 <<'MSG'
ERROR: libfdk-aac-dev is unavailable from the configured APT sources.
Enable Debian 13's contrib, non-free, and non-free-firmware components,
run 'sudo apt update', then run this script again.
MSG
        exit 1
    fi

    sudo apt install -y \
        build-essential g++ make \
        autoconf automake libtool pkg-config cmake \
        wget curl git ca-certificates \
        nasm yasm \
        python3-dev python3-pip \
        checkinstall \
        libsoundtouch-dev libdevil-dev \
        libx264-dev libx265-dev libfdk-aac-dev \
        libass-dev libopus-dev libvpx-dev libdav1d-dev libaom-dev \
        libmp3lame-dev libplacebo-dev libva-dev \
        zlib1g-dev libbz2-dev \
        libfontconfig1-dev libfreetype6-dev libjpeg-dev \
        libavcodec-dev libavformat-dev libswscale-dev libavutil-dev \
        libswresample-dev
}

configure_system_paths() {
    echo "=== Configuring local library paths ==="

    # Use a project-specific linker configuration file rather than modifying
    # generic/global checkinstall configuration.
    printf '%s\n' '/usr/local/lib' '/usr/local/lib64' \
        | sudo tee /etc/ld.so.conf.d/autobuildffavs.conf >/dev/null
    sudo ldconfig

    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
}

run_checkinstall() {
    local description="$1"
    local pkgname="$2"
    local pkgversion="$3"

    # Command-line switches override /etc/checkinstallrc, so this script no
    # longer changes system-wide checkinstall defaults.
    printf '%s\n' "$description" \
        | sudo checkinstall \
            --type=debian \
            --install=yes \
            --fstrans=no \
            --pkgname="$pkgname" \
            --pkgversion="$pkgversion" \
            --backup=no \
            --default
}

build_avisynth() {
    echo "=== Building AviSynth+ ${AVISYNTH_VERSION} ==="
    local repo="$WORK_DIR/AviSynthPlus"
    local build_dir="$repo/avisynth-build"

    ensure_repo "$repo" "https://github.com/AviSynth/AviSynthPlus.git"
    checkout_pinned_ref "$repo" "$AVISYNTH_REF" "$AVISYNTH_COMMIT"
    git -C "$repo" submodule update --init --recursive
    verify_submodules_clean "$repo"

    if [ "$CLEAN_BUILD" = true ]; then
        rm -rf -- "$build_dir"
    fi

    mkdir -p -- "$build_dir"
    cd "$build_dir"

    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local
    make -j"$JOBS"

    run_checkinstall \
        "AviSynth+ frame server library compiled from source" \
        "avisynth" \
        "$AVISYNTH_VERSION"

    sudo ldconfig
}

build_ffmpeg() {
    echo "=== Building FFmpeg ${FFMPEG_VERSION} ==="
    local repo="$WORK_DIR/FFmpeg"

    ensure_repo "$repo" "https://github.com/FFmpeg/FFmpeg.git"
    checkout_pinned_ref "$repo" "$FFMPEG_REF" "$FFMPEG_COMMIT"
    cd "$repo"

    if [ "$CLEAN_BUILD" = true ] && [ -f Makefile ]; then
        make distclean || make clean || true
    fi

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

    make -j"$JOBS"

    run_checkinstall \
        "Custom FFmpeg build with AviSynth+ enabled" \
        "ffmpeg-custom" \
        "$FFMPEG_VERSION"

    sudo ldconfig
    hash -r
}

build_ffms2() {
    echo "========================================="
    echo " Building FFMS2 ${FFMS2_VERSION}"
    echo "========================================="

    local repo="$WORK_DIR/ffms2"
    ensure_repo "$repo" "https://github.com/FFMS/ffms2.git"
    checkout_pinned_ref "$repo" "$FFMS2_REF" "$FFMS2_COMMIT"
    cd "$repo"

    if [ "$CLEAN_BUILD" = true ] && [ -f Makefile ]; then
        make distclean || make clean || true
    fi

    ./autogen.sh
    ./configure \
        --prefix=/usr/local \
        --enable-shared \
        --enable-avisynth \
        CPPFLAGS="-I/usr/local/include/avisynth"

    echo "Compiling FFMS2 using ${JOBS} jobs..."
    make -j"$JOBS"
    sudo make install
    sudo ldconfig
}

build_yadifmod2() {
    echo "========================================="
    echo " Building yadifmod2 (pinned revision)"
    echo "========================================="

    local repo="$WORK_DIR/yadifmod2"
    local build_dir="$repo/build"

    ensure_repo "$repo" "https://github.com/Asd-g/yadifmod2.git"
    checkout_pinned_commit "$repo" "$YADIFMOD2_COMMIT"

    if [ "$CLEAN_BUILD" = true ]; then
        rm -rf -- "$build_dir"
    fi

    mkdir -p -- "$build_dir"
    cd "$build_dir"

    cmake -DCMAKE_BUILD_TYPE=Release ..
    make -j"$JOBS"
    sudo make install
    sudo ldconfig

    local plugin_dir="/usr/local/lib/avisynth"
    local install_manifest="$build_dir/install_manifest.txt"
    local yadif_lib

    # Use CMake's install manifest so an older libyadifmod2 left in /usr/local
    # can never be mistaken for the library installed by this build.
    if [ ! -r "$install_manifest" ]; then
        echo "ERROR: yadifmod2 install manifest was not found at $install_manifest." >&2
        exit 1
    fi

    yadif_lib="$(
        awk -v prefix="$plugin_dir/" '
            index($0, prefix) == 1 &&
            $0 ~ /\/libyadifmod2[^/]*\.so\.[^/]+$/ { print }
        ' "$install_manifest" |
            while IFS= read -r candidate; do
                if [ -e "$candidate" ]; then
                    printf '%s\n' "$candidate"
                fi
            done |
            sort -V |
            tail -n1
    )"

    if [ -z "$yadif_lib" ]; then
        echo "ERROR: the current yadifmod2 build did not install a versioned shared library in $plugin_dir." >&2
        echo "Install manifest: $install_manifest" >&2
        exit 1
    fi

    sudo ln -sfn "$(basename "$yadif_lib")" "$plugin_dir/libyadifmod2.so"
}

find_ffms2_library() {
    local candidate
    for candidate in \
        /usr/local/lib/libffms2.so \
        /usr/local/lib64/libffms2.so \
        /usr/local/lib/avisynth/libffms2.so; do
        if [ -e "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    ldconfig -p 2>/dev/null | awk '/libffms2\.so/ && $NF ~ /^\/usr\/local\// && !found {print $NF; found=1}'
}

verify_no_missing_dependencies() {
    local library="$1"
    local ldd_output

    if ! command -v ldd >/dev/null 2>&1; then
        echo "ERROR: required command 'ldd' was not found; cannot verify $library." >&2
        exit 1
    fi

    if ! ldd_output="$(ldd "$library" 2>&1)"; then
        echo "ERROR: ldd failed while checking $library:" >&2
        printf '%s\n' "$ldd_output" >&2
        exit 1
    fi

    if grep -F 'not found' <<<"$ldd_output" >/dev/null; then
        echo "ERROR: unresolved shared-library dependencies detected for $library:" >&2
        printf '%s\n' "$ldd_output" >&2
        exit 1
    fi
}

run_avisynth_smoke_test() {
    local ffms2_lib="$1"
    local yadif_lib="/usr/local/lib/avisynth/libyadifmod2.so"

    echo "=== Running end-to-end AviSynth smoke test ==="
    SMOKE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/autobuildffavs.XXXXXX")"

    local source_file="$SMOKE_DIR/source.mkv"
    local avs_file="$SMOKE_DIR/smoke.avs"

    ffmpeg -hide_banner -loglevel error \
        -f lavfi -i 'testsrc2=size=64x64:rate=25' \
        -frames:v 4 -c:v ffv1 -y "$source_file"

    cat > "$avs_file" <<EOF_AVS
LoadPlugin("$ffms2_lib")
LoadPlugin("$yadif_lib")
FFVideoSource("$source_file")
Yadifmod2(mode=0, order=1)
EOF_AVS

    ffmpeg -hide_banner -loglevel error \
        -f avisynth -i "$avs_file" \
        -frames:v 1 -f null -

    echo "OK: AviSynth + FFMS2 + yadifmod2 smoke test completed."
}

verify_installation() {
    echo "========================================="
    echo " Final verification"
    echo "========================================="

    hash -r
    require_command ffmpeg

    local version_line actual_version
    version_line="$(ffmpeg -version 2>/dev/null | sed -n '1p')"
    echo "$version_line"
    actual_version="$(awk '{print $3}' <<<"$version_line")"

    if [ "$actual_version" != "$FFMPEG_VERSION" ]; then
        echo "ERROR: expected FFmpeg ${FFMPEG_VERSION}, but found version '${actual_version:-unknown}'." >&2
        echo "Resolved binary: $(command -v ffmpeg)" >&2
        exit 1
    fi

    if ! ffmpeg -demuxers 2>/dev/null | grep -E '(^|[[:space:]])avisynth([[:space:]]|$)' >/dev/null; then
        echo "ERROR: FFmpeg AviSynth demuxer was not found." >&2
        exit 1
    fi
    echo "OK: FFmpeg AviSynth demuxer detected."

    local ffms2_lib
    ffms2_lib="$(find_ffms2_library)"
    if [ -z "$ffms2_lib" ] || [ ! -e "$ffms2_lib" ]; then
        echo "ERROR: FFMS2 shared library was not found." >&2
        exit 1
    fi
    verify_no_missing_dependencies "$ffms2_lib"
    echo "OK: FFMS2 shared library detected: $ffms2_lib"

    local yadif_lib="/usr/local/lib/avisynth/libyadifmod2.so"
    if [ ! -e "$yadif_lib" ]; then
        echo "ERROR: $yadif_lib was not found or is a broken symlink." >&2
        exit 1
    fi
    verify_no_missing_dependencies "$yadif_lib"
    echo "OK: yadifmod2 plugin detected."

    run_avisynth_smoke_test "$ffms2_lib"

    echo
    echo "SUCCESS: FFmpeg ${FFMPEG_VERSION} + AviSynth+ ${AVISYNTH_VERSION} + FFMS2 ${FFMS2_VERSION} + yadifmod2 are installed."
}

main() {
    require_command sudo
    require_command apt
    require_command apt-cache

    preflight_os
    prepare_work_dir

    echo "=== Starting FFmpeg + AviSynth+ build using ${JOBS} jobs ==="
    install_dependencies
    configure_system_paths

    # Commands below rely on packages installed above.
    require_command git
    require_command cmake
    require_command make
    require_command checkinstall

    build_avisynth
    build_ffmpeg
    build_ffms2
    build_yadifmod2
    verify_installation
}

main "$@"
