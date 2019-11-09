#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export TITLE="Librespot"
export DESCRIPTION="A dubo image for Librespot"
export IMAGE_NAME="librespot"
# Look into https://github.com/japaric/rust-cross
export PLATFORMS="linux/amd64,linux/arm/v7"

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/helpers.sh"
