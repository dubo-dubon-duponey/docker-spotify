# What

Docker image for a Spotify Connect endpoint.

This is based on [LibreSpot](https://github.com/librespot-org/librespot).

This is useful in the following scenarios:

 1. you are a hobbyist and you want to turn a small appliance connected to speakers into a Spotify Connect receiver (typically a raspberry pi) 
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
    * [x] multi-stage build with no installed dependencies for the runtime image
 * observable
    * [x] healthcheck
    * [x] log to stdout
    * [ ] ~~prometheus endpoint~~

## Run

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

Since the Spotify Connect protocol uses bonjour for discovery, you have to use host networking, or alternatively mac-(or ip)-vlan.

### Configuration reference

#### Runtime

You may specify the following environment variables at runtime:

 * NAME (eg: `Totale Croquette`) controls the "name" under which your endpoint will appear in Spotify

You can also tweak the following for control over which internal ports are being used:

 * PORT (eg: `10042`) controls the port used by the http command endpoint

Of course using any privileged port for that would require CAP_NET_BIND_SERVICE and a `--user=root` (not recommended...).

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
 
So to control which user-id to assign to the in-container user (default is 2000).
