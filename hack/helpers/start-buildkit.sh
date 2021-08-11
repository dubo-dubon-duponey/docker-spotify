#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export SUITE=bullseye
export DATE=2021-08-01

readonly IMAGE_BLDKT="${IMAGE_BLDKT:-ghcr.io/dubo-dubon-duponey/buildkit:$SUITE-$DATE}"

setup::buildkit() {
  [ "$(docker container inspect -f '{{.State.Running}}' dbdbdp-buildkit 2>/dev/null)" == "true" ]  || {
    docker run --pull always --rm -d \
      -p 4242:4242 \
      --network host \
      --name dbdbdp-buildkit \
      --env MDNS_ENABLED=true \
      --env MDNS_HOST=buildkit-machina \
      --env MDNS_NAME="Dubo Buildkit on la machina" \
      --entrypoint buildkitd \
      --user root \
      --privileged \
      "$IMAGE_BLDKT"
    docker exec --env QEMU_BINARY_PATH=/boot/bin/ dbdbdp-buildkit binfmt --install all
  }
}

setup::buildkit 1>&2 || {
  echo >&2 "Something wrong with starting buildkit"
  exit 1
}

echo "docker-container://dbdbdp-buildkit"
