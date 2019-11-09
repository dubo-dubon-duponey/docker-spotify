#######################
# Extra builder for healthchecker
#######################
FROM          --platform=$BUILDPLATFORM dubodubonduponey/base:builder                                                   AS builder-healthcheck

ARG           HEALTH_VER=51ebf8ca3d255e0c846307bf72740f731e6210c3

WORKDIR       $GOPATH/src/github.com/dubo-dubon-duponey/healthcheckers
RUN           git clone git://github.com/dubo-dubon-duponey/healthcheckers .
RUN           git checkout $HEALTH_VER
RUN           arch="${TARGETPLATFORM#*/}"; \
              env GOOS=linux GOARCH="${arch%/*}" go build -v -ldflags "-s -w" -o /dist/bin/http-health ./cmd/http

RUN           chmod 555 /dist/bin/*

#######################
# Building image
#######################
FROM          dubodubonduponey/base:builder                                   AS builder

WORKDIR       /build

ARG           LIBRESPOT_VER=cbba63f60baef6c812a82903a0e0735688056d3c

RUN           git clone git://github.com/librespot-org/librespot
RUN           git -C librespot      checkout $LIBRESPOT_VER

RUN           apt-get install -qq --no-install-recommends \
                libasound2-dev=1.1.8-1 \
                cargo=0.35.0-2

WORKDIR       /build/librespot
RUN           cargo build --release

#######################
# Running image
#######################
FROM          dubodubonduponey/base:runtime

USER          root

ARG           DEBIAN_FRONTEND="noninteractive"
ENV           TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
RUN           apt-get update -qq              \
              && apt-get install -qq --no-install-recommends \
                libasound2=1.1.8-1            \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

USER          dubo-dubon-duponey


COPY          --from=builder /build/librespot/target/release/librespot ./bin/librespot
COPY          --from=builder-healthcheck /dist/bin/http-health ./bin/

ENV           NAME=Sproutify
ENV           PORT=10042
ENV           HEALTHCHECK_URL="http://127.0.0.1:$PORT/?action=getInfo"

EXPOSE        $PORT/tcp

VOLUME        /data
VOLUME        /tmp

HEALTHCHECK   --interval=30s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
