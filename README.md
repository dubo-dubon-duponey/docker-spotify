# What

Docker image for a Spotify Connect endpoint.

This is based on [LibreSpot](https://github.com/librespot-org/librespot).

This is useful in the following scenarios:

 1. you are a hobbyist and you want to turn a small appliance connected to speakers (eg: a raspberry pi, typically) into a Spotify Connect receiver
 1. that's it :-)

## Image features

 * multi-architecture:
    * [x] linux/amd64
    * [x] linux/arm64
    * [x] linux/arm/v7
    * [x] linux/arm/v6
 * hardened:
    * [x] image runs read-only
    * [x] image runs with no capabilities
    * [x] process runs as a non-root user, disabled login, no shell
 * lightweight
    * [x] based on `debian:buster-slim`
    * [x] simple entrypoint script
    * [ ] multi-stage build with ~~no~~ one installed dependencies (`libasound`) for the runtime image
 * observable
    * [x] healthcheck
    * [x] log to stdout
    * [ ] [KO] prometheus endpoint

## Run

First off, librespot [requires ipv6](https://github.com/librespot-org/librespot/issues/292#issuecomment-552058573).

To enable it for the Docker daemon, edit /etc/docker/daemon.json:

```
{
        "ipv6": true,
        "fixed-cidr-v6": "2001:db8:1::/64"
}
```

Restart the docker daemon now (usually `systemctl restart docker`).

The following is the most straight-forward example, using host networking:

```bash
docker run -d \
    --name "spot" \
    --env "NAME=Super Name For Your Spotify Connect Endpoint" \
    --net host \
    --device /dev/snd \
    --group-add audio \
    --cap-drop ALL \
    --read-only \
    dubodubonduponey/librespot:v1
```

## Notes

### Networking

Besides the requirement to have ipv6 enabled, and since the Spotify Connect protocol uses bonjour for discovery, 
you have to use host networking, or alternatively mac-(or ip)-vlan.

### Configuration reference

#### Runtime

You may specify the following environment variables at runtime:

 * NAME (eg: `Totale Croquette`) controls the "name" under which your endpoint will appear in Spotify

You can also tweak the following for control over which internal ports are being used:

 * PORT (eg: `10042`) controls the port used by the http command endpoint

Of course using any privileged port for that would require CAP_NET_BIND_SERVICE and a root user.

Finally, any additional arguments provided when running the image will get fed to the `librespot` binary.

This is specifically relevant if you need to select a different alsa device, card or mixer, or use another librespot option.

Here is an example:
```
docker run -d \
    --name "spot" \
    --env "NAME=Super Name For Your Spotify Connect Endpoint" \
    --net host \
    --device /dev/snd \
    --group-add audio \
    --cap-drop ALL \
    --read-only \
    dubodubonduponey/librespot:v1 \
    --device default:CARD=Mojo \
    --enable-volume-normalisation \
    -v
```

For a reference of all librespot options, try:
```
docker run --rm \
    dubodubonduponey/librespot:v1 \
    --help
```

#### Build time

You can rebuild the image using the following build arguments:

 * BUILD_UID
 
So to control which user-id to assign to the in-container user.
