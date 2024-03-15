#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

helpers::dir::writable(){
  local path="$1"
  local create="${2:-}"
  # shellcheck disable=SC2015
  ( [ ! "$create" ] || mkdir -p "$path" 2>/dev/null ) && [ -w "$path" ] && [ -d "$path" ] || {
    printf >&2 "%s does not exist, is not writable, or cannot be created. Check your mount permissions.\n" "$path"
    exit 1
  }
}

helpers::log::normalize(){
  local lower
  lower="$(printf "%s" "${LOG_LEVEL:-}" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
  "debug")
  ;;
  "info")
  ;;
  "error")
  ;;
  *)
    lower="warning"
  ;;
  esac
  LOG_LEVEL="$lower"
  printf "%s" "$LOG_LEVEL"
}

helpers::log::normalize >/dev/null
