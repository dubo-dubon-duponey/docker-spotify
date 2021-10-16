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

# mDNS blast if asked to
[ ! "$MDNS_HOST" ] || {
  [ ! "${MDNS_STATION:-}" ] || mdns::add "_workstation._tcp" "$MDNS_HOST" "${MDNS_NAME:-}" "$PORT"
  mdns::add "${MDNS_TYPE:-_spotify-connect._tcp}" "$MDNS_HOST" "${MDNS_NAME:-}" "$PORT" '["VERSION=1", "CPath=/"]'
  mdns::start &
  args+=(--disable-discovery)
}

[ "$(printf "%s" "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')" != "debug" ] || args+=(--verbose)
[ ! "$OUTPUT" ] || args+=(--backend "$OUTPUT")
[ ! "$DEVICE" ] || args+=(--device "$DEVICE")
args+=("$@")

exec librespot "${args[@]}"

# Nightingale
# spotify.nightingale.local.
# 10.0.4.66:10042
# VERSION=1.0
# CPath=/
