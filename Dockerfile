ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_BUILDER=base:builder-bullseye-2021-07-01@sha256:f1c46316c38cc1ca54fd53b54b73797b35ba65ee727beea1a5ed08d0ad7e8ccf
ARG           FROM_IMAGE_RUNTIME=base:runtime-bullseye-2021-07-01@sha256:9f5b20d392e1a1082799b3befddca68cee2636c72c502aa7652d160896f85b36
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2021-07-01@sha256:f1e25694fe933c7970773cb323975bb5c995fa91d0c1a148f4f1c131cbc5872c

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

#######################
# Fetcher
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS fetcher-main

ENV           GIT_REPO=github.com/librespot-org/librespot
ENV           GIT_VERSION=v0.2.0
ENV           GIT_COMMIT=59683d7965480e63c581dd03082ded6a080a1cd3

RUN           git clone --recurse-submodules git://"$GIT_REPO" .
RUN           git checkout "$GIT_COMMIT"

RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq; \
              for architecture in armel armhf arm64 ppc64el i386 s390x amd64; do \
                apt-get install -qq --no-install-recommends \
                  libpulse-dev:"$DEB_TARGET_ARCH"=14.2-2 \
                  libasound2-dev:"$DEB_TARGET_ARCH"=1.2.4-1.1 \
              done

#######################
# Main builder
#######################
FROM          --platform=$BUILDPLATFORM fetcher-main                                                                    AS builder-main

ARG           TARGETARCH
ARG           TARGETOS
ARG           TARGETVARIANT

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

# XXX make this shit static
RUN           DEB_TARGET_ARCH="$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/armv6/armel/" -e "s/armv7/armhf/" -e "s/ppc64le/ppc64el/" -e "s/386/i386/")"; \
              eval "$(dpkg-architecture -A "$DEB_TARGET_ARCH")"; \
              export PKG_CONFIG_ALLOW_CROSS=1; \
              export PKG_CONFIG="${DEB_TARGET_GNU_TYPE}-pkg-config"; \
              export PATH="$PATH:$HOME/.cargo/bin"; \
              printf "%s\n%s\n" "[target.$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM]" "linker = \"$DEB_TARGET_GNU_TYPE-gcc\"" >> "$HOME/.cargo/config"; \
              rustup toolchain install "$RUST_VERSION"; \
              rustup target add "$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM"; \
              cargo build --locked --target="$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM" --release --no-default-features --features "alsa-backend,pulseaudio-backend"; \
              cp ./target/"$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM"/release/librespot /dist/boot/bin/

#######################
# Builder assembly, XXX should be auditor
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS builder

COPY          --from=builder-main   /dist/boot/bin           /dist/boot/bin

# What about TLS?
#COPY          --from=builder-tools  /boot/bin/caddy          /dist/boot/bin
COPY          --from=builder-tools  /boot/bin/http-health    /dist/boot/bin

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;


#######################
# Running image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME

USER          root

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
