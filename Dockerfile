ARG           BUILDER_BASE=dubodubonduponey/base:builder
ARG           RUNTIME_BASE=dubodubonduponey/base:runtime

#######################
# Extra builder for healthchecker
#######################
# hadolint ignore=DL3006
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-healthcheck

ARG           GIT_REPO=github.com/dubo-dubon-duponey/healthcheckers
ARG           GIT_VERSION=51ebf8ca3d255e0c846307bf72740f731e6210c3

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone git://$GIT_REPO .
RUN           git checkout $GIT_VERSION
# hadolint ignore=DL4006
RUN           env GOOS=linux GOARCH="$(printf "%s" "$TARGETPLATFORM" | sed -E 's/^[^/]+\/([^/]+).*/\1/')" go build -v -ldflags "-s -w" \
                -o /dist/boot/bin/http-health ./cmd/http

#######################
# Building image
#######################
# hadolint ignore=DL3006
FROM          $BUILDER_BASE                                                                                             AS builder

WORKDIR       /build

# Maybe consider https://github.com/japaric/rust-cross for cross-compilation
RUN           apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                libasound2-dev=1.1.8-1 \
                libpulse-dev=12.2-4+deb10u1 \
                cargo=0.35.0-2

# v0.1.1
ARG           LIBRESPOT_VER=3672214e312d7a5634ca71837589555f9b0554e5

RUN           git clone git://github.com/librespot-org/librespot

WORKDIR       /build/librespot
RUN           git checkout $LIBRESPOT_VER
RUN           cargo build -Z unstable-options --release --out-dir /dist/boot/bin --no-default-features --features "alsa-backend,pulseaudio-backend"

RUN           rm /dist/boot/bin/liblibrespot.rlib

COPY          --from=builder-healthcheck /dist/boot/bin           /dist/boot/bin
RUN           chmod 555 /dist/boot/bin/*

#######################
# Running image
#######################
# hadolint ignore=DL3006
FROM          $RUNTIME_BASE

USER          root

RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                libasound2=1.1.8-1 \
                libpulse0=12.2-4+deb10u1 \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

USER          dubo-dubon-duponey

COPY          --from=builder --chown=$BUILD_UID:root /dist .

ENV           NAME=Sproutify
ENV           PORT=10042
ENV           HEALTHCHECK_URL="http://127.0.0.1:$PORT/?action=getInfo"

EXPOSE        $PORT/tcp

VOLUME        /tmp

HEALTHCHECK   --interval=30s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
