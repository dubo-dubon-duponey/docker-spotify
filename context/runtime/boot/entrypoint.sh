#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
. "$root/helpers.sh"
# shellcheck source=/dev/null
. "$root/mdns.sh"

helpers::logger::set "$LOG_LEVEL"

helpers::logger::log INFO "[entrypoint]" "Starting container"

helpers::logger::log DEBUG "[entrypoint]" "Checking directories permissions"
helpers::dir::writable "$XDG_CACHE_HOME"/spotify create
helpers::dir::writable "$XDG_RUNTIME_DIR"

helpers::logger::log DEBUG "[entrypoint]" "Preparing configuration"

helpers::logger::log DEBUG "[entrypoint]" "Preparing command"

readonly ADVANCED_PORT="${ADVANCED_PORT:-10042}"

# Basic spot arguments
args=(--cache-size-limit "${SPOTIFY_CACHE_SIZE:-8G}" --cache "$XDG_CACHE_HOME"/spotify --name "${MOD_MDNS_NAME:-Magnetar}" --bitrate 320 --device-type speaker --zeroconf-port "$ADVANCED_PORT")

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
    reg="TRACE|DEBUG|INFO|WARN|WARNING"
  ;;
esac
reg="[[ZT0-9:/. -]*(?:$reg)[ ]*"

args+=("$@")

helpers::logger::log DEBUG "[entrypoint]" "Command ready to execute - handing over now:"
helpers::logger::log INFO "[entrypoint]" "Starting: librespot ${args[*]}"

{
  exec librespot "${args[@]}" 2>&1
} | while read -r line; do
  line="$(grep -Pv "$reg" <<<"$line")"
  [ "$line" ] || continue
  level="$(sed -Ee 's/^[[ZT:0-9/. -]+(DEBUG|INFO|WARN|WARNING|ERROR).+/\1/' <<<"$line")"
  line="$(sed -Ee 's/^[[ZT:0-9/. -]+(DEBUG|INFO|WARN|WARNING|ERROR)[ ]*/[/' <<<"$line")"
  helpers::logger::log "$level" "$line";
done

# XXX giving up on the wrapped for now - librespot will just keep on crashing if the device is busy
# librespot will exit for a number of reason - one of them being the device is busy or turned of
# exiting in such a case is bad
# - if the container is not restarting, now you have to restart manually whenever the device is free or back online
# - if the container is restarting "always", then it will restart in fast succession and suck up resources and logs space
# The wrapper here is meant to alleviate that, by restarting librespot and will only exit with a throttle
#{
  # Note: librespot logging is stuffed entirely on stdout by the wrapper - only our logging is on stderr, so, no redirect needed here for the post-processing
#  exec librespot "${args[@]}" # 2>&1
#  exec /boot/wrap.sh librespot "${args[@]}" 2>&1 > >(grep -Pv "$reg")
#} > >(grep -Pv "$reg" | sed -e 's/^[[0-9:/. ]*/[/' -E -e 's/^(DEBUG|INFO|WARN|ERROR)[ ]*//' | helpers::logger::slurp "$LOG_LEVEL")

# > >(sed -Ee 's/^[[ZT:0-9/. -]+/[/' -Ee 's/^[[](DEBUG|INFO|WARN|WARNING|ERROR)[ ]*/[/')

# | helpers::logger::slurp "$LOG_LEVEL")
