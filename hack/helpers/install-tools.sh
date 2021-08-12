#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export SUITE=bullseye
export DATE=2021-07-01

export BIN_LOCATION="${BIN_LOCATION:-$HOME/bin}"
export PATH="$BIN_LOCATION:$PATH"
readonly IMAGE_TOOLS="${IMAGE_TOOLS:-ghcr.io/dubo-dubon-duponey/tools:$(uname | grep -q Darwin && printf "macos" || printf "linux-dev")-$SUITE-$DATE}"

setup::tools(){
  local location="$1"
  if  command -v "$location/cue" > /dev/null &&
      command -v "$location/buildctl" > /dev/null &&
      command -v docker > /dev/null; then
    return
  fi

  mkdir -p "$location"
  docker rm -f dubo-tools 2>/dev/null || true
  docker run --pull always --name dubo-tools "$IMAGE_TOOLS" /boot/bin/cue >/dev/null 2>&1 || true
  docker cp dubo-tools:/boot/bin/cue "$location"
  docker cp dubo-tools:/boot/bin/buildctl "$location"
  docker cp dubo-tools:/boot/bin/docker "$location"
  docker rm -f dubo-tools 2>/dev/null || true
}

# XXX add hado & shellcheck to the images
command -v hadolint >/dev/null || {
  printf >&2 "You need to install hadolint"
  exit 1
}

command -v shellcheck >/dev/null || {
  printf >&2 "You need to install shellcheck"
  exit 1
}

setup::tools "$BIN_LOCATION"
