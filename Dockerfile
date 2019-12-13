#######################
# Extra builder for healthchecker
#######################
FROM          --platform=$BUILDPLATFORM dubodubonduponey/base:builder                                                   AS builder-healthcheck

ARG           HEALTH_VER=51ebf8ca3d255e0c846307bf72740f731e6210c3

WORKDIR       $GOPATH/src/github.com/dubo-dubon-duponey/healthcheckers
RUN           git clone git://github.com/dubo-dubon-duponey/healthcheckers .
RUN           git checkout $HEALTH_VER
RUN           arch="${TARGETPLATFORM#*/}"; \
              env GOOS=linux GOARCH="${arch%/*}" go build -v -ldflags "-s -w" -o /dist/boot/bin/http-health ./cmd/http

#######################
# Building image
#######################
FROM          dubodubonduponey/base:builder                                   AS builder

WORKDIR       /build

# Maybe consider https://github.com/japaric/rust-cross for cross-compilation
RUN           apt-get install -qq --no-install-recommends \
                libasound2-dev=1.1.8-1 \
                cargo=0.35.0-2

# v0.1.0
ARG           LIBRESPOT_VER=295bda7e489715b9e6c27a262f9a4fcd12fb7632

RUN           git clone git://github.com/librespot-org/librespot

WORKDIR       /build/librespot
RUN           git checkout $LIBRESPOT_VER
RUN           cargo build -Z unstable-options --release --out-dir /dist/boot/bin --no-default-features --features alsa-backend

COPY          --from=builder-healthcheck /dist/boot/bin           /dist/boot/bin

RUN           rm /dist/boot/bin/liblibrespot.rlib
RUN           chmod 555 /dist/boot/bin/*

WORKDIR       /dist/boot/lib/
RUN           cp /usr/lib/"$(gcc -dumpmachine)"/libasound.so.2  .

#######################
# Running image
#######################
FROM          dubodubonduponey/base:runtime

COPY          --from=builder --chown=$BUILD_UID:root /dist .

ENV           NAME=Sproutify
ENV           PORT=10042
ENV           HEALTHCHECK_URL="http://127.0.0.1:$PORT/?action=getInfo"

EXPOSE        $PORT/tcp

VOLUME        /data
VOLUME        /tmp

HEALTHCHECK   --interval=30s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
