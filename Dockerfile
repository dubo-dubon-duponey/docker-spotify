ARG           FROM_IMAGE_BUILDER=ghcr.io/dubo-dubon-duponey/base:builder-bullseye-2021-06-01@sha256:addbd9b89d8973df985d2d95e22383961ba7b9c04580ac6a7f406a3a9ec4731e
ARG           FROM_IMAGE_RUNTIME=ghcr.io/dubo-dubon-duponey/base:runtime-bullseye-2021-06-01@sha256:a2b1b2f69ed376bd6ffc29e2d240e8b9d332e78589adafadb84c73b778e6bc77

#######################
# Extra builder for healthchecker
#######################
FROM          --platform=$BUILDPLATFORM $FROM_IMAGE_BUILDER                                                             AS builder-healthcheck

ARG           GIT_REPO=github.com/dubo-dubon-duponey/healthcheckers
ARG           GIT_VERSION=51ebf8c
ARG           GIT_COMMIT=51ebf8ca3d255e0c846307bf72740f731e6210c3
ARG           GO_BUILD_SOURCE=./cmd/http
ARG           GO_BUILD_OUTPUT=http-health
ARG           GO_LD_FLAGS="-s -w"
ARG           GO_TAGS="netgo osusergo"

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone --recurse-submodules git://"$GIT_REPO" . && git checkout "$GIT_COMMIT"
ARG           GOOS="$TARGETOS"
ARG           GOARCH="$TARGETARCH"

# hadolint ignore=DL4006
RUN           env GOARM="$(printf "%s" "$TARGETVARIANT" | tr -d v)" go build -trimpath $(if [ "$CGO_ENABLED" = 1 ]; then printf "%s" "-buildmode pie"; fi) \
                -ldflags "$GO_LD_FLAGS" -tags "$GO_TAGS" -o /dist/boot/bin/"$GO_BUILD_OUTPUT" "$GO_BUILD_SOURCE"

#######################
# Building image
#######################
FROM          --platform=$BUILDPLATFORM $FROM_IMAGE_BUILDER                                                             AS builder
# Maybe consider https://github.com/japaric/rust-cross for cross-compilation

WORKDIR       /build

# v0.2.0
ARG           GIT_REPO=github.com/librespot-org/librespot
ARG           GIT_VERSION=v0.2.0
ARG           GIT_COMMIT=59683d7965480e63c581dd03082ded6a080a1cd3

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone --recurse-submodules git://"$GIT_REPO" . && git checkout "$GIT_COMMIT"

RUN           mkdir -p /dist/boot/bin/

RUN           --mount=type=secret,mode=0444,id=CA,dst=/etc/ssl/certs/ca-certificates.crt \
              --mount=type=secret,id=CERTIFICATE \
              --mount=type=secret,id=KEY \
              --mount=type=secret,id=PASSPHRASE \
              --mount=type=secret,mode=0444,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_OPTIONS,dst=/etc/apt/apt.conf.d/dbdbdp.conf \
              DEB_TARGET_ARCH="$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/armv6/armel/" -e "s/armv7/armhf/" -e "s/ppc64le/ppc64el/" -e "s/386/i386/")"; \
              dpkg --add-architecture "$DEB_TARGET_ARCH"; \
              apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                libpulse-dev:"$DEB_TARGET_ARCH"=14.2-2 \
                libasound2-dev:"$DEB_TARGET_ARCH"=1.2.4-1.1 \
                crossbuild-essential-"$DEB_TARGET_ARCH"=12.9


ARG           RUST_VERSION=1.53.0
#RUN           case "$TARGETPLATFORM" in \
#                "linux/amd64")    arch=x86_64;      abi=gnu;        ga=x86_64;      ;; \
#                "linux/arm64")    arch=aarch64;     abi=gnu;        ga=aarch64;     ;; \
#                "linux/arm/v7")   arch=armv7;       abi=gnueabihf;  ga=arm;         ;; \ # DEB_TARGET_GNU_SYSTEM=linux-gnueabihf GA=$DEB_TARGET_GNU_CPU
#                "linux/ppc64le")  arch=powerpc64le; abi=gnu;        ga=powerpc64le; ;; \ # GA=$DEB_TARGET_GNU_CPU
#                "linux/s390x")    arch=s390x;       abi=gnu;        ga=s390x;       ;; \
#              esac; \
#              printf "%s\n%s\n" "[target.${arch}-unknown-linux-${abi}]" "linker = \"${ga}-linux-${abi}-gcc\"" >> "$HOME/.cargo/config"; \
#              PATH="$PATH:$HOME/.cargo/bin" rustup target add "${arch}-unknown-linux-${abi}"

# XXX pin rust to install 1.48.0
# hadolint ignore=DL4006
RUN           curl --proto '=https' --tlsv1.3 -sSf https://sh.rustup.rs | sh -s -- -y

# XXX make this shit static
RUN           DEB_TARGET_ARCH="$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/armv6/armel/" -e "s/armv7/armhf/" -e "s/ppc64le/ppc64el/" -e "s/386/i386/")"; \
              eval "$(dpkg-architecture -A "$DEB_TARGET_ARCH")"; \
              export PKG_CONFIG_ALLOW_CROSS=1; \
              export PKG_CONFIG_PATH="/usr/lib/${DEB_TARGET_MULTIARCH}/pkgconfig"; \
              export PATH="$PATH:$HOME/.cargo/bin"; \
              printf "%s\n%s\n" "[target.$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM]" "linker = \"$DEB_TARGET_GNU_TYPE-gcc\"" >> "$HOME/.cargo/config"; \
              rustup toolchain install "$RUST_VERSION"; \
              rustup target add "$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM"; \
              cargo build --locked --target="$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM" --release --no-default-features --features "alsa-backend,pulseaudio-backend"; \
              cp ./target/"$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM"/release/librespot /dist/boot/bin/

COPY          --from=builder-healthcheck /dist/boot/bin           /dist/boot/bin
RUN           chmod 555 /dist/boot/bin/*

#######################
# Running image
#######################
FROM          $FROM_IMAGE_RUNTIME

USER          root

RUN           --mount=type=secret,mode=0444,id=CA,dst=/etc/ssl/certs/ca-certificates.crt \
              --mount=type=secret,id=CERTIFICATE \
              --mount=type=secret,id=KEY \
              --mount=type=secret,id=PASSPHRASE \
              --mount=type=secret,mode=0444,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_OPTIONS,dst=/etc/apt/apt.conf.d/dbdbdp.conf \
              apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                libasound2=1.2.4-1.1 \
                libpulse0=14.2-2 \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

USER          dubo-dubon-duponey

COPY          --from=builder --chown=$BUILD_UID:root /dist /

ENV           NAME=Sproutify
ENV           PORT=10042
ENV           HEALTHCHECK_URL="http://127.0.0.1:$PORT/?action=getInfo"

EXPOSE        $PORT/tcp

VOLUME        /tmp

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
