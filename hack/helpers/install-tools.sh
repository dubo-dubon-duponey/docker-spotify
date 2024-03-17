#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export SUITE=bookworm
export DATE=2024-03-01

export BIN_LOCATION="${BIN_LOCATION:-$HOME/bin}"
export PATH="$BIN_LOCATION:$PATH"
readonly IMAGE_TOOLS="${IMAGE_TOOLS:-dubodubonduponey/tools:$(uname -s | grep -q Darwin && printf "macos" || printf "linux-dev")-$SUITE-$DATE}"

export SHELLCHECK_VERSION=0.10.0
export HADOLINT_VERSION=2.12.0

setup::tools(){
  local location="$1"
  if  command -v "$location/cue" > /dev/null &&
      command -v "$location/buildctl" > /dev/null &&
      command -v "$location/docker" > /dev/null &&
      command -v "$location/hadolint" > /dev/null &&
      command -v "$location/shellcheck" > /dev/null; then
    return
  fi

  mkdir -p "$location"
  docker rm -f dubo-tools >/dev/null 2>&1 || true
  docker create --pull always --name dubo-tools "$IMAGE_TOOLS" bash > /dev/null
  docker cp dubo-tools:/boot/bin/cue "$location"
  docker cp dubo-tools:/boot/bin/buildctl "$location"
  docker cp dubo-tools:/boot/bin/docker "$location"
  docker rm -f dubo-tools >/dev/null 2>&1

  # XXX add hado & shellcheck to the dev image
  curl --proto '=https' --tlsv1.2 -sSfL -o "$location/hadolint" "https://github.com/hadolint/hadolint/releases/download/v$HADOLINT_VERSION/hadolint-$(uname -s)-$(uname -m)"
  chmod 700 "$location/hadolint"

  curl --proto '=https' --tlsv1.2 -sSfL -o shellcheck.tar.xz "https://github.com/koalaman/shellcheck/releases/download/v$SHELLCHECK_VERSION/shellcheck-v$SHELLCHECK_VERSION.$(uname -s | tr '[:upper:]' '[:lower:]').$(uname -m).tar.xz"
  tar -xf shellcheck.tar.xz
  mv ./shellcheck-v$SHELLCHECK_VERSION/shellcheck "$location"
  rm shellcheck.tar.xz
  rm -Rf ./shellcheck-v$SHELLCHECK_VERSION
}

setup::tools "$BIN_LOCATION"
