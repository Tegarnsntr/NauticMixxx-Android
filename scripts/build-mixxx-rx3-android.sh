#!/usr/bin/env bash
# Build NauticMixxx for Android using Mixxx's supported Qt/Android toolchain.
set -euo pipefail

project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=$(cat "$project/VERSION")
work=${RX3_ANDROID_BUILD_ROOT:-"$project/build/android-$version"}
jobs=${RX3_BUILD_JOBS:-"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"}
archive="$work/mixxx-2.5.6.tar.gz"
source_tree="$work/mixxx-2.5.6"

mkdir -p "$work"
if [ ! -f "$archive" ]; then
  curl --fail --location --retry 3 https://github.com/mixxxdj/mixxx/archive/refs/tags/2.5.6.tar.gz -o "$archive"
fi
printf '%s  %s\n' 9cfc9025d50d2511767ee52a07b8854f75c581f0585197d043bc219fcf9f9050 "$archive" | sha256sum -c -
if [ ! -d "$source_tree" ]; then tar -xzf "$archive" -C "$work"; fi

digest=$(cat "$project"/patches/00[0-9][0-9]-*.patch | sha256sum | cut -d ' ' -f 1)
marker="$source_tree/.nauticmixxx-patched"
if [ ! -f "$marker" ]; then
  for patch in "$project"/patches/00[0-9][0-9]-*.patch; do
    (cd "$source_tree" && GIT_CEILING_DIRECTORIES="$work" git apply --no-index "$patch")
  done
  printf '%s\n' "$digest" > "$marker"
fi
if [ "$(cat "$marker")" != "$digest" ]; then
  printf 'NauticMixxx patches changed; choose a fresh RX3_ANDROID_BUILD_ROOT.\n' >&2
  exit 1
fi

# The official Mixxx Android guide owns dependency versions and setup. Set
# RX3_ANDROID_SKIP_SETUP=1 when the matching buildenv is already installed.
if [ "$(uname -s)/$(uname -m)" != Linux/x86_64 ]; then
  printf 'Mixxx Android dependencies require Linux/x86_64 (the upstream setup rejects this host); use Ubuntu 24.04 or CI.\n' >&2
  exit 2
fi
export BUILDENV_BASEPATH="$work/buildenv"
if [ "${RX3_ANDROID_SKIP_SETUP:-0}" != 1 ]; then
  # This is a source operation: the setup script exports the exact vcpkg
  # triplet, SDK and dependency URL required by the current Mixxx guide.
  set +u
  source "$source_tree/tools/android_buildenv.sh" setup
  set -u
fi
if [ -n "${BUILDENV_URL:-}" ] && [ -n "${BUILDENV_SHA256:-}" ]; then
  mkdir -p "$BUILDENV_BASEPATH"
  buildenv_zip="$work/${BUILDENV_NAME}.zip"
  if [ ! -f "$buildenv_zip" ]; then curl --fail --location --retry 3 "$BUILDENV_URL" -o "$buildenv_zip"; fi
  printf '%s  %s\n' "$BUILDENV_SHA256" "$buildenv_zip" | sha256sum -c -
  if [ ! -d "$MIXXX_VCPKG_ROOT" ]; then unzip -q "$buildenv_zip" -d "$BUILDENV_BASEPATH"; fi
fi
toolchain="${MIXXX_VCPKG_ROOT:-}"
if [ -z "$toolchain" ]; then
  toolchain=$(find "$BUILDENV_BASEPATH" -path '*/scripts/buildsystems/vcpkg.cmake' -type f 2>/dev/null | sort | head -n 1 | sed 's#/scripts/buildsystems/vcpkg.cmake$##')
fi
if [ -n "$toolchain" ]; then toolchain="$toolchain/scripts/buildsystems/vcpkg.cmake"; fi
if [ -z "$toolchain" ]; then
  printf 'Android vcpkg toolchain not found under %s/buildenv. Run the Mixxx Android dependency setup first.\n' "$work" >&2
  exit 1
fi

# Branding must be applied before Qt compiles its resource collection.
python3 "$project/packaging/linux/prepare-branding.py" "$source_tree" "$project"
cmake -S "$source_tree" -B "$work/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_SYSTEM_NAME=Android -DCMAKE_TOOLCHAIN_FILE="$toolchain" \
  -DCMAKE_INSTALL_PREFIX="$work/stage" -DNAUTICMIX_VERSION="$version" \
  -DQT6=ON -DQML=OFF -DAU_EFFECTS=OFF -DENGINEPRIME=OFF \
  -DKEYFINDER=OFF -DBUILD_TESTING=OFF -DBUILD_BENCH=OFF
cmake --build "$work/build" --target apk --parallel "$jobs"

# Mixxx's Android package embeds installed resources. Keep the mapping and
# RX3 skin in the same location as desktop builds for automatic discovery.
cmake --install "$work/build" || true
printf 'Android APK: %s\n' "$work/build/android-build/build/outputs/apk/release/android-build-release-signed.apk"
