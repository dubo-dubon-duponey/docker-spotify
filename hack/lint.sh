#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# Ignore some warnings
# DL3006 is about "dO nOT UsE --platform", which is really ludicrous
# DL3029 complains about unpinned images (which is not true, we are just using ARGs for that)
# DL4006 is about setting pipefail (which we do, in our base SHELL)
# DL3059 is about not having multiple successive RUN statements, and this is moronic
hadolint_ignore=(--ignore DL3006 --ignore DL3029 --ignore DL4006 --ignore DL3059)

# shellcheck source=/dev/null
root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/../"
# shellcheck source=/dev/null
. "$root"/hack/setup.sh

if ! hadolint "${hadolint_ignore[@]}" "$root"/*Dockerfile*; then
  printf >&2 "Failed linting on Dockerfile\n"
  exit 1
fi

if ! shellcheck "$root"/**/*.sh; then
  printf >&2 "Failed shellchecking\n"
  exit 1
fi
