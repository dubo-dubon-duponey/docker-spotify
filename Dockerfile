ARG           FROM_REGISTRY=docker.io/dubodubonduponey

ARG           FROM_IMAGE_FETCHER=base:golang-bookworm-2025-05-01
ARG           FROM_IMAGE_BUILDER=base:builder-bookworm-2025-05-01
ARG           FROM_IMAGE_AUDITOR=base:auditor-bookworm-2025-05-01
ARG           FROM_IMAGE_TOOLS=tools:linux-bookworm-2025-05-01
ARG           FROM_IMAGE_RUNTIME=base:runtime-bookworm-2025-05-01

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

#######################
# Fetcher
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_FETCHER                                              AS fetcher-main

ARG           GIT_REPO=github.com/librespot-org/librespot
ARG           GIT_VERSION=v0.6.0
ARG           GIT_COMMIT=383a6f6969f23b3e3cbc693747101cb9c92463dc

RUN           git clone --recurse-submodules https://"$GIT_REPO" .; git checkout "$GIT_COMMIT"

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
                libpulse-dev:"$DEB_TARGET_ARCH"=16.1+dfsg1-2+b1 \
                libasound2-dev:"$DEB_TARGET_ARCH"=1.2.8-1+b1

# Maybe consider https://github.com/japaric/rust-cross for cross-compilation

RUN           mkdir -p /dist/boot/bin/

# ENV           RUST_VERSION=1.53.0
ENV           RUST_VERSION=1.87.0
# XXX whatever, rust...
ENV           RUSTUP_USE_CURL=1;
#RUN           case "$TARGETPLATFORM" in \
#                "linux/amd64")    arch=x86_64;      abi=gnu;        ga=x86_64;      ;; \
#                "linux/arm64")    arch=aarch64;     abi=gnu;        ga=aarch64;     ;; \
#                "linux/arm/v7")   arch=armv7;       abi=gnueabihf;  ga=arm;         ;; \ # DEB_TARGET_GNU_SYSTEM=linux-gnueabihf GA=$DEB_TARGET_GNU_CPU
#                "linux/ppc64le")  arch=powerpc64le; abi=gnu;        ga=powerpc64le; ;; \ # GA=$DEB_TARGET_GNU_CPU
#                "linux/s390x")    arch=s390x;       abi=gnu;        ga=s390x;       ;; \
#              esac; \
#              printf "%s\n%s\n" "[target.${arch}-unknown-linux-${abi}]" "linker = \"${ga}-linux-${abi}-gcc\"" >> "$HOME/.cargo/config"; \
#              PATH="$PATH:$HOME/.cargo/bin" rustup target add "${arch}-unknown-linux-${abi}"

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
              cargo build --locked --target="$DEB_TARGET_GNU_CPU-unknown-$DEB_TARGET_GNU_SYSTEM" --release --no-default-features --features "alsa-backend pulseaudio-backend with-libmdns"; \
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
                fbi:"$DEB_TARGET_ARCH"=2.10-4+b1 \
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
COPY          --from=builder-tools  /boot/bin/goello-server-ng /dist/boot/bin

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

COPY          --from=assembly --chown=$BUILD_UID:root /dist /

USER          root

# Some of this should not be necessary and instead linked statically...
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                libasound2=1.2.8-1+b1 \
                libpulse0=16.1+dfsg1-2+b1 \
                curl=7.88.1-10+deb12u12 \
                fbi=2.10-4+b1 \
                jq=1.6-2.1 \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

# librespot still puts a lock file in /tmp
RUN           rmdir /tmp; ln -s /magnetar/runtime /tmp

USER          dubo-dubon-duponey

ENV           _SERVICE_NICK="spotify"
ENV           _SERVICE_TYPE="_spotify-connect._tcp"

ENV           LOG_LEVEL="warn"

### Audio module configuration common with other systens
ENV           MOD_AUDIO_DEVICE=""
# (alsa|pulseaudio|pipe|process)
ENV           MOD_AUDIO_OUTPUT=alsa
# only operative if mixer alsa is selected
ENV           MOD_AUDIO_MIXER=""
# mono/stereo is a no-op for Spotify
ENV           MOD_AUDIO_MODE="stereo"
# default vol, unless volume is ignored
ENV           MOD_AUDIO_VOLUME_DEFAULT="75"
# ignore volume entirely
ENV           MOD_AUDIO_VOLUME_IGNORE=false

# Provisional
ENV           MOD_MQTT_ENABLED=false
ENV           MOD_MQTT_HOST=""
ENV           MOD_MQTT_PORT=""
ENV           MOD_MQTT_USER=""
ENV           MOD_MQTT_PASSWORD=""
ENV           MOD_MQTT_CA=""
ENV           MOD_MQTT_CERT=""
ENV           MOD_MQTT_KEY=""

### Spotify specific configuration hooks
ENV           SPOTIFY_ENABLE_VOLUME_NORMALIZATION=true
ENV           SPOTIFY_MIXER=softvol
ENV           SPOTIFY_CACHE_SIZE=8G

### mDNS broadcasting
# XXX note this unfortunately does not work with librespot
# Whether to enable MDNS broadcasting or not
ENV           MOD_MDNS_ENABLED=false
# Name is used as a short description for the service
ENV           MOD_MDNS_NAME="$_SERVICE_NICK mDNS display name"
# The service will be annonced and reachable at $MOD_MDNS_HOST.local
ENV           MOD_MDNS_HOST="$_SERVICE_NICK"

### Advanced settings
# Type to advertise
ENV           ADVANCED_MOD_MDNS_TYPE="$_SERVICE_TYPE"
# Also announce the service as a workstation (for example for the benefit of coreDNS mDNS)
ENV           ADVANCED_MOD_MDNS_STATION=false

### Experimental settings
# Note: this should instead send a message over mqtt
# Set to true to have librespot display coverart on your RPI framebuffer (/dev/fb0 and /dev/tty1 need to be mounted and CAP added)
# XXX experimental for now - will be removed in a separate project, and use mqtt publishing instead
ENV           _EXPERIMENTAL_DISPLAY_ENABLED=false
ENV           _EXPERIMENTAL_SPOTIFY_CLIENT_ID=""
ENV           _EXPERIMENTAL_SPOTIFY_CLIENT_SECRET=""

ENV           ADVANCED_PORT=10042
ENV           HEALTHCHECK_URL="http://127.0.0.1:$ADVANCED_PORT/?action=getInfo"

## Both protocols
# Obviously 5353 for the mDNS listener
EXPOSE        5353
# Spot port
EXPOSE        $ADVANCED_PORT/tcp

VOLUME        "$XDG_CACHE_HOME"
VOLUME        "$XDG_RUNTIME_DIR"

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
