#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

NAME=${NAME:-no name}
PORT=${PORT:-10042}

# Ensure the folder is writable
[ -w /tmp ] || {
  printf >&2 "/tmp is not writable. Check your mount permissions.\n"
  exit 1
}

exec librespot --cache /tmp/cache --name "$NAME" --bitrate 320 --device-type speaker --zeroconf-port "$PORT" "$@"
# disable-discovery may be the right way to hide librespot mDNS announce
