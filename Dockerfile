ARG           BUILDER_BASE=dubodubonduponey/base@sha256:b51f084380bc1bd2b665840317b6f19ccc844ee2fc7e700bf8633d95deba2819
ARG           RUNTIME_BASE=dubodubonduponey/base@sha256:d28e8eed3e87e8dc5afdd56367d3cf2da12a0003d064b5c62405afbe4725ee99

#######################
# Extra builder for healthchecker
#######################
# hadolint ignore=DL3006,DL3029
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-healthcheck

ARG           GIT_REPO=github.com/dubo-dubon-duponey/healthcheckers
ARG           GIT_VERSION=51ebf8ca3d255e0c846307bf72740f731e6210c3
ARG           BUILD_TARGET=./cmd/http
ARG           BUILD_OUTPUT=http-health
ARG           BUILD_FLAGS="-s -w"

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone git://$GIT_REPO .
RUN           git checkout $GIT_VERSION
# hadolint ignore=DL4006
RUN           env GOOS=linux GOARCH="$(printf "%s" "$TARGETPLATFORM" | sed -E 's/^[^/]+\/([^/]+).*/\1/')" go build -v \
                -ldflags "$BUILD_FLAGS" -o /dist/boot/bin/"$BUILD_OUTPUT" "$BUILD_TARGET"

#######################
# Building image
#######################
# hadolint ignore=DL3006,DL3029
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder
# Maybe consider https://github.com/japaric/rust-cross for cross-compilation

WORKDIR       /build

# hadolint ignore=DL4006
RUN           curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN           set -eu; \
              case "$TARGETPLATFORM" in \
                "linux/amd64")    debian_arch=amd64; ;; \
                "linux/arm64")    debian_arch=arm64; ;; \
                "linux/arm/v7")   debian_arch=armhf; ;; \
                "linux/ppc64le")  debian_arch=ppc64el; ;; \
                "linux/s390x")    debian_arch=s390x; ;; \
              esac; \
              dpkg --add-architecture $debian_arch; \
              apt-get update -qq; \
              apt-get install -qq --no-install-recommends \
                libpulse-dev:$debian_arch=12.2-4+deb10u1 \
                libasound2-dev:$debian_arch=1.1.8-1 \
                crossbuild-essential-$debian_arch=12.6

# XXX pin rust to install 1.48.0
RUN           set -eu; \
              case "$TARGETPLATFORM" in \
                "linux/amd64")    arch=x86_64;      abi=gnu;        ga=x86_64;      ;; \
                "linux/arm64")    arch=aarch64;     abi=gnu;        ga=aarch64;     ;; \
                "linux/arm/v7")   arch=armv7;       abi=gnueabihf;  ga=arm;         ;; \
                "linux/ppc64le")  arch=powerpc64le; abi=gnu;        ga=powerpc64le; ;; \
                "linux/s390x")    arch=s390x;       abi=gnu;        ga=s390x;       ;; \
              esac; \
              printf "%s\n%s\n" "[target.${arch}-unknown-linux-${abi}]" "linker = \"${ga}-linux-${abi}-gcc\"" >> "$HOME/.cargo/config"; \
              PATH="$PATH:$HOME/.cargo/bin" rustup target add "${arch}-unknown-linux-${abi}"

# v0.1.3
ARG           GIT_REPO=github.com/librespot-org/librespot
# ARG           GIT_VERSION=064359c26e0e0d29a820a542bb2e48bc237b3b49

# v0.2.0
ARG           GIT_VERSION=59683d7965480e63c581dd03082ded6a080a1cd3

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone git://$GIT_REPO .
RUN           git checkout $GIT_VERSION

RUN           mkdir -p /dist/boot/bin/

RUN           set -eu; \
              case "$TARGETPLATFORM" in \
                "linux/amd64")    arch=x86_64;      abi=gnu;        ga=x86_64;      ;; \
                "linux/arm64")    arch=aarch64;     abi=gnu;        ga=aarch64;     ;; \
                "linux/arm/v7")   arch=armv7;       abi=gnueabihf;  ga=arm;         ;; \
                "linux/ppc64le")  arch=powerpc64le; abi=gnu;        ga=powerpc64le; ;; \
                "linux/s390x")    arch=s390x;       abi=gnu;        ga=s390x;       ;; \
              esac; \
              PATH=$PATH:$HOME/.cargo/bin PKG_CONFIG_ALLOW_CROSS=1 PKG_CONFIG_PATH=/usr/lib/$ga-linux-$abi/pkgconfig \
                cargo build --locked --target=${arch}-unknown-linux-${abi} --release --no-default-features --features "alsa-backend,pulseaudio-backend"; \
              cp ./target/${arch}-unknown-linux-${abi}/release/librespot /dist/boot/bin/

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

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
