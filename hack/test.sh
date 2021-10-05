#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# shellcheck source=/dev/null
root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/../"

# Simple no-thrill build tester
# XXX Currently reduced to a single architecture to avoid using all disk space until we figure out our space efficiency problem (likely the fat builder image getting duplicated over and over)
# Solution would probably be to do like buildkit and fetch with a lightweight go image while build mount from the previous stage instead of inheriting - annoying but probably the only way
if ! "$root/hack/build.sh" \
    --inject registry="ghcr.io/dubo-dubon-duponey" \
    --inject progress=plain \
	  --inject date=2021-10-01 \
	  --inject suite=bullseye \
    --inject platforms=linux/arm64 \
  	"image" "$@"; then
  printf >&2 "Failed building\n"
  exit 1
fi
