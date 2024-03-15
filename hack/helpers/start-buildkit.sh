#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export TAG=latest
readonly IMAGE_BLDKT="${IMAGE_BLDKT:-docker.io/dubodubonduponey/buildkit:$TAG}"

setup::buildkit() {
  [ "$(docker container inspect -f '{{.State.Running}}' dbdbdp-buildkit 2>/dev/null)" == "true" ]  || {
    docker run --pull always --rm -d \
      -p 4242:4242 \
      --network host \
      --name dbdbdp-buildkit \
      --env MOD_MDNS_ENABLED=true \
      --env MOD_MDNS_HOST=buildkit-machina \
      --env MOD_MDNS_NAME="Dubo Buildkit on la machina" \
      --entrypoint buildkitd \
      --user root \
      --privileged \
      "$IMAGE_BLDKT"
    docker exec --env QEMU_BINARY_PATH=/boot/bin/ dbdbdp-buildkit binfmt --install all
    docker exec dbdbdp-buildkit mkdir /tmp/runtime
  }
}

setup::buildkit 1>&2 || {
  echo >&2 "Something wrong with starting buildkit"
  exit 1
}

echo "docker-container://dbdbdp-buildkit"
