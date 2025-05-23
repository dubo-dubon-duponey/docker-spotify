#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

net::download(){
  local url="$1"
  local destination="${2:-/dev/stdout}"
  local no_cache="${3:-}"
  shift
  shift || true
  shift || true
  local args=(--tlsv1.3 -sSfL --proto "=https" --http2-prior-knowledge)
  args+=("$@")
  # shellcheck disable=SC2015
  [ "$destination" != /dev/stdout ] && [ -e "$destination" ] && [ ! "$no_cache" ] && {
    logger::info "%s is already there. Nothing to do.\n" "$destination"
  } || {
    printf >&2 "Downloading %s\n" "$url"
    curl "${args[@]}" -o "$destination" "$url" || {
      rm "$destination"
      logger::error >&2 "Download failed!\n"
      return 1
    }
  }
}
