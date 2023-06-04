#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/twpayne/chezmoi"
TOOL_NAME="chezmoi"
TOOL_TEST="chezmoi"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
  list_github_tags
}

detect_system() {
  case $(uname -s) in
    Darwin) echo "darwin" ;;
    FreeBSD) echo "freebsd" ;;
    *) echo "linux" ;;
  esac
}

detect_architecture() {
  case $(uname -m) in
    amd64 | x86_64) echo "amd64" ;;
    ppc64le) echo "ppc64le" ;;
    aarch64 | aarch64_be | armv8b | armv8l | arm64) echo "arm64" ;;
    *) fail "Architecture not supported" ;;

  esac
}

detect_variant() {
  case "$(ldd /bin/sh)" in
    *musl*) echo '-musl';;
    *) echo '';
  esac
}

download_release() {
  local version platform filename url
  version="$1"
  platform="$2"
  filename="$3"

  url="$GH_REPO/releases/download/v${version}/chezmoi_${version}_${platform}.tar.gz"

  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path"
    cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

    # move bin
    mkdir -p "$install_path/bin"
    mv "$install_path/chezmoi" "$install_path/bin/"

    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
