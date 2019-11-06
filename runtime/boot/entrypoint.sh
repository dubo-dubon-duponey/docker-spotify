#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

NAME=${NAME:-no name}
PORT=${PORT:-10042}

exec librespot --cache /data/cache --name "$NAME" --bitrate 320 --device-type speaker --zeroconf-port "$PORT" "$@"

# avr
# username password
# backend
# device
# mixer=alsa
# mixer-name=PCM/Digital
# mixer-card=hw:0
# --enable-volume-normalisation --initial-volume 75
