ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_FETCHER=base:golang-bullseye-2021-10-01@sha256:dd38f2bdc3c26ea49db6ccea3923b2bd320605a6fee3e1dcff469bac00346ae2
ARG           FROM_IMAGE_BUILDER=base:builder-bullseye-2021-10-01@sha256:8500836fc43374bdb9831ac0d76d70054987aa210ac6c3f2caff0ddd8ac53b90
ARG           FROM_IMAGE_AUDITOR=base:auditor-bullseye-2021-10-01@sha256:af728eaf5271cae6a948f5c4d34a43b4cff5dae16cc3e5dabf99a0aeea7986a9
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2021-10-01@sha256:24da09d01cc3505dd886672c0993f6f99b4fff4d1de2fcfbbe81aa52c880b9ac
ARG           FROM_IMAGE_RUNTIME=base:runtime-bullseye-2021-10-01@sha256:5c76496f4dc901e9a59370babd9fa3c59427064971058b373121140a29fb153f

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

#######################
# Fetcher
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_FETCHER                                              AS fetcher-main

ARG           GIT_REPO=github.com/librespot-org/librespot
ARG           GIT_VERSION=v0.2.0
ARG           GIT_COMMIT=59683d7965480e63c581dd03082ded6a080a1cd3

RUN           git clone --recurse-submodules git://"$GIT_REPO" .; git checkout "$GIT_COMMIT"

#######################
# Main builder
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS builder-main

ARG           TARGETARCH
ARG           TARGETOS
ARG           TARGETVARIANT

COPY          --from=fetcher-main /source /source

# hadolint ignore=DL3009
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              apt-get update -qq; \
              apt-get install -qq --no-install-recommends \
                libpulse-dev:"$DEB_TARGET_ARCH"=14.2-2 \
                libasound2-dev:"$DEB_TARGET_ARCH"=1.2.4-1.1

# Maybe consider https://github.com/japaric/rust-cross for cross-compilation

RUN           mkdir -p /dist/boot/bin/

ENV           RUST_VERSION=1.53.0
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
RUN           --mount=type=secret,id=CA \
              --mount=type=secret,id=CERTIFICATE \
              --mount=type=secret,id=KEY \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=.curlrc \
              curl -sSf https://sh.rustup.rs | sh -s -- -y

# XXX this is using curl under the hood
# Somehow, not passing secrets along seems to fuck things up because of
# SSL_CERT_FILE <- this is bad if true
RUN           --mount=type=secret,id=CA \
              --mount=type=secret,id=CERTIFICATE \
              --mount=type=secret,id=KEY \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=.curlrc \
              eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              export PKG_CONFIG_ALLOW_CROSS=1; \
              export PKG_CONFIG="${DEB_TARGET_GNU_TYPE}-pkg-config"; \
              export PATH="$PATH:$HOME/.cargo/bin"; \
              printf "%s\n%s\n" "[target.$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM]" "linker = \"$DEB_TARGET_GNU_TYPE-gcc\"" >> "$HOME/.cargo/config"; \
              rustup toolchain install "$RUST_VERSION"; \
              rustup target add "$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM"; \
              cargo build --locked --target="$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM" --release --no-default-features --features "alsa-backend,pulseaudio-backend"; \
              cp ./target/"$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM"/release/librespot /dist/boot/bin/

#######################
# Builder assembly
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_AUDITOR                                              AS assembly

ARG           TARGETARCH
ARG           TARGETVARIANT

# This should not be necessary and linked statically...
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                fbi:"$DEB_TARGET_ARCH"=2.10-4 \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

COPY          --from=builder-main   /dist/boot           /dist/boot

RUN           cp "$(which fbi)" /dist/boot/bin
RUN           setcap 'cap_sys_tty_config+ep' /dist/boot/bin/fbi

# What about TLS?
#COPY          --from=builder-tools  /boot/bin/caddy          /dist/boot/bin
COPY          --from=builder-tools  /boot/bin/http-health    /dist/boot/bin

RUN           RUNNING=true \
              STATIC=true \
                dubo-check validate /dist/boot/bin/http-health

#RUN           [ "$TARGETARCH" != "amd64" ] || export STACK_CLASH=true; \
#              STATIC=true \
#              FORTIFIED=true \
#              STACK_PROTECTED=true \

# XXX missing libpulse-simple.so.0 - why are they dynamic?
#RUN           RUNNING=true \
#              NO_SYSTEM_LINK=true \
RUN           BIND_NOW=true \
              PIE=true \
              RO_RELOCATIONS=true \
                dubo-check validate /dist/boot/bin/librespot

# RUN           setcap 'cap_net_bind_service+ep' /dist/boot/bin/librespot

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;


#######################
# Running image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME

USER          root

# This should not be necessary and linked statically...
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                libasound2=1.2.4-1.1 \
                libpulse0=14.2-2 \
                curl=7.74.0-1.3+b1 \
                fbi=2.10-4 \
                jq=1.6-2.1 \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

USER          dubo-dubon-duponey

COPY          --from=assembly --chown=$BUILD_UID:root /dist /

ENV           MDNS_NAME=Sproutify
ENV           PORT=10042
# Will default to whatever is the system default
ENV           DEVICE=""
# (alsa|pulseaudio|pipe|process)
ENV           OUTPUT=alsa

ENV           HEALTHCHECK_URL="http://127.0.0.1:$PORT/?action=getInfo"
# Set to true to have librespot display coverart on your RPI framebuffer (/dev/fb0 and /dev/tty1 need to be mounted and CAP added)
ENV           DISPLAY_ENABLED=false
ENV           SPOTIFY_CLIENT_ID=""
ENV           SPOTIFY_CLIENT_SECRET=""

EXPOSE        $PORT/tcp

VOLUME        /tmp

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
