#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
source "$root/helpers.sh"
# shellcheck source=/dev/null
source "$root/mdns.sh"

helpers::dir::writable /tmp

# This is purely cached music, so, disposable and transient
args=(--onevent /boot/onevent.sh --cache-size-limit 8G --cache /tmp/cache --name "${MDNS_NAME:-Sproutify}" --bitrate 320 --device-type speaker --zeroconf-port "${PORT:-10042}")
[ "$(printf "%s" "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')" != "debug" ] || args+=(--verbose)
[ ! "$OUTPUT" ] || args+=(--backend "$OUTPUT")
[ ! "$DEVICE" ] || args+=(--device "$DEVICE")
args+=("$@")

exec librespot "${args[@]}"

# disable-discovery may be the right way to hide librespot mDNS announce
# --disable-discovery Disable discovery mode
