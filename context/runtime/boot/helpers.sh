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

# shellcheck disable=SC2034
readonly DC_COLOR_BLACK=0
# shellcheck disable=SC2034
readonly DC_COLOR_RED=1
# shellcheck disable=SC2034
readonly DC_COLOR_GREEN=2
# shellcheck disable=SC2034
readonly DC_COLOR_YELLOW=3
# shellcheck disable=SC2034
readonly DC_COLOR_BLUE=4
# shellcheck disable=SC2034
readonly DC_COLOR_MAGENTA=5
# shellcheck disable=SC2034
readonly DC_COLOR_CYAN=6
# shellcheck disable=SC2034
readonly DC_COLOR_WHITE=7
# shellcheck disable=SC2034
readonly DC_COLOR_DEFAULT=9

# shellcheck disable=SC2034
readonly DC_LOGGER_DEBUG=4
# shellcheck disable=SC2034
readonly DC_LOGGER_INFO=3
# shellcheck disable=SC2034
readonly DC_LOGGER_WARNING=2
# shellcheck disable=SC2034
readonly DC_LOGGER_ERROR=1

export DC_LOGGER_STYLE_DEBUG=( setaf "$DC_COLOR_WHITE" )
export DC_LOGGER_STYLE_INFO=( setaf "$DC_COLOR_GREEN" )
export DC_LOGGER_STYLE_WARNING=( setaf "$DC_COLOR_YELLOW" )
export DC_LOGGER_STYLE_ERROR=( setaf "$DC_COLOR_RED" )

_DC_PRIVATE_LOGGER_LEVEL="$DC_LOGGER_WARNING"

helpers::logger::log(){
  local prefix="$1"
  shift

  local level="DC_LOGGER_$prefix"
  local style="DC_LOGGER_STYLE_${prefix}[@]"

  [ "$_DC_PRIVATE_LOGGER_LEVEL" -ge "${!level}" ] || return 0

  # If you wonder about why that crazy shit: https://stackoverflow.com/questions/12674783/bash-double-process-substitution-gives-bad-file-descriptor
  exec 3>&2
  [ ! "$TERM" ] || [ ! -t 2 ] || >&2 tput "${!style}" 2>/dev/null || true
  >&2 printf "[%s] [%s] %s\n" "$(date 2>/dev/null || true)" "$prefix" "$*"
  [ ! "$TERM" ] || [ ! -t 2 ] || >&2 tput op 2>/dev/null || true
  exec 3>&-
}

helpers::logger::set() {
  local desired
  desired="$(printf "DC_LOGGER_%s" "${1:-warning}" | tr '[:lower:]' '[:upper:]')"
  _DC_PRIVATE_LOGGER_LEVEL="${!desired}"
}

helpers::logger::slurp(){
  local level
  level="$(printf "%s" "${1:-warning}" |  tr '[:lower:]' '[:upper:]')"
  shift
  while read -r line; do
    helpers::logger::log "$level" "$* $line";
  done </dev/stdin
}
