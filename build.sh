#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export DEBIAN_DATE=2020-06-01
export TITLE="Librespot"
export DESCRIPTION="A dubo image for Librespot"
export IMAGE_NAME="librespot"
# Building on armv6 takes an excruciating amount of time now (does it even complete?), so, bye bye v6
export PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/helpers.sh"
