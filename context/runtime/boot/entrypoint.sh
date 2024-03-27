#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
. "$root/helpers.sh"
# shellcheck source=/dev/null
. "$root/mdns.sh"

helpers::dir::writable "$XDG_CACHE_HOME"

readonly ADVANCED_PORT="${ADVANCED_PORT:-10042}"

# Basic spot arguments
args=(--cache-size-limit 8G --cache "$XDG_CACHE_HOME"/spotify --name "${MOD_MDNS_NAME:-Magnetar}" --bitrate 320 --device-type speaker --zeroconf-port "$ADVANCED_PORT")

# mDNS blast if asked to
[ "${MOD_MDNS_ENABLED:-}" != true ] || {
  [ "${ADVANCED_MOD_MDNS_STATION:-}" != true ] || mdns::records::add "_workstation._tcp" "${MOD_MDNS_HOST}" "${MOD_MDNS_NAME:-}" "$ADVANCED_PORT"
  mdns::records::add "${ADVANCED_MOD_MDNS_TYPE:-_spotify-connect._tcp}" "${MOD_MDNS_HOST:-}" "${MOD_MDNS_NAME:-}" "$ADVANCED_PORT" '["VERSION=1", "CPath=/"]'
  mdns::start::broadcaster
  args+=(--disable-discovery)
}

# XXX going to move out to something else
# Hook the experimental display script if asked to
[ ! "$_EXPERIMENTAL_SPOTIFY_CLIENT_ID" ] || [ ! "$_EXPERIMENTAL_SPOTIFY_CLIENT_SECRET" ] || [ ! "$_EXPERIMENTAL_DISPLAY_ENABLED" ] || args+=(--onevent /boot/onevent.sh)

# Make it verbose if debugging
[ "$LOG_LEVEL" != "debug" ] || args+=(--verbose)

# Backend (alsa default) and device
[ ! "$MOD_AUDIO_OUTPUT" ] || args+=(--backend "$MOD_AUDIO_OUTPUT")
[ ! "$MOD_AUDIO_DEVICE" ] || args+=(--device "$MOD_AUDIO_DEVICE")

if [ "$MOD_AUDIO_VOLUME_IGNORE" == true ]; then
  # Close it out...
  args+=(--mixer softvol --initial-volume 100 --volume-ctrl fixed)
else
  # Initial default
  [ ! "$MOD_AUDIO_VOLUME_DEFAULT" ] || args+=(--initial-volume "$MOD_AUDIO_VOLUME_DEFAULT")
  # Softvol or alsa
  [ ! "$SPOTIFY_MIXER" ] || args+=(--mixer "$SPOTIFY_MIXER")
  # Normalization
  [ "$SPOTIFY_ENABLE_VOLUME_NORMALIZATION" != true ] || args+=(--enable-volume-normalisation)
fi

case "$LOG_LEVEL" in
  "debug")
    reg="TRACE"
  ;;
  "info")
    reg="TRACE|DEBUG"
  ;;
  "warning")
    reg="TRACE|DEBUG|INFO"
  ;;
  "error")
    reg="TRACE|DEBUG|INFO|WARN"
  ;;
esac
reg="^[0-9/: ]*(?:$reg)"

args+=("$@")

# TODO control crashes and exponential backoff. Conditions to handle:
# - failed DNS
# - failed connection to AP
# - device busy
{
  exec librespot "${args[@]}" 2>&1
} > >(grep -Pv "$reg" | sed -e 's/^[[0-9:/. ]*/[/' -E -e 's/^(DEBUG|INFO|WARN|ERROR)[ ]*//' | helpers::logger::slurp "$LOG_LEVEL")
