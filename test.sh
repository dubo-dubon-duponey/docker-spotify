#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

TEST_DOES_NOT_BUILD=${TEST_DOES_NOT_BUILD:-}

if ! hadolint ./*Dockerfile*; then
  printf >&2 "Failed linting on Dockerfile\n"
  exit 1
fi

if ! shellcheck ./*.sh; then
  printf >&2 "Failed shellchecking\n"
  exit 1
fi

if [ ! "$TEST_DOES_NOT_BUILD" ]; then
  [ ! -e "./refresh.sh" ] || ./refresh.sh
  if ! ./hack/cue-bake image --inject platforms=linux/arm64; then
    printf >&2 "Failed building image\n"
    exit 1
  fi
fi
