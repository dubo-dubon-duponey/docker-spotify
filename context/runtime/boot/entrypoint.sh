#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
source "$root/helpers.sh"
# shellcheck source=/dev/null
source "$root/mdns.sh"

helpers::dir::writable /tmp

readonly PORT="${PORT:-10042}"
# This is purely cached music, so, disposable and transient
args=(--cache-size-limit 8G --cache /tmp/cache --name "${MDNS_NAME:-Sproutify}" --bitrate 320 --device-type speaker --zeroconf-port "$PORT")

# Hook the experimental display script if asked to
[ ! "$SPOTIFY_CLIENT_ID" ] || [ ! "$SPOTIFY_CLIENT_SECRET" ] || [ ! "$DISPLAY_ENABLED" ] || args+=(--onevent /boot/onevent.sh)

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
