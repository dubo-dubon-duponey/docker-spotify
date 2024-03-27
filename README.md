# What

Docker image for a Spotify Connect endpoint.

This is based on [LibreSpot](https://github.com/librespot-org/librespot).

This is useful in the following scenarios:

 1. you are a hobbyist, and you want to turn a small appliance connected to speakers into a Spotify Connect receiver (typically a raspberry pi) 
 1. that's it :-)

## Image features

* multi-architecture:
  * [x] linux/amd64
  * [x] linux/arm64
* hardened:
  * [x] image runs read-only
  * [x] image runs with no capabilities (you need NET_BIND_SERVICE if you want to use privileged ports obviously)
  * [x] process runs as a non-root user, disabled login, no shell
* lightweight
  * [x] based on our slim [Debian Bookworm](https://github.com/dubo-dubon-duponey/docker-debian)
  * [x] simple entrypoint script
  * [ ] multi-stage build with ~~zero packages~~ `libpulse0`, `libasound2` installed in the runtime image
* observable
  * [x] healthcheck
  * [x] log to stdout
  * [ ] ~~prometheus endpoint~~ not applicable - one should rather monitor containers using a dedicated prometheus endpoint

## Run

The following is the most straight-forward example, using host networking:

```bash
docker run --rm \
    --name spotify \
    --group-add audio \
    --device /dev/snd \
    --net host \
    --cap-drop ALL \
    --read-only \
    --env "MOD_MDNS_NAME=Display name for your speaker"
    docker.io/dubodubonduponey/spotify:bookworm-2024-03-01
```

And here is a compose file:
```yaml
spotify:
  # Please pin a specific version, and do NOT use latest, which is prone to breaking changes
  image: index.docker.io/dubodubonduponey/spotify:bookworm-2024-03-01
  container_name: spotify
  # See below note on networking - host or mac/ip-vlan is required for mDNS to work
  network_mode: host
  # anything you pass as command will be fed as extra arguments to the librespot binary for advanced control
  #command: 
  #  - autoplay
  restart: always
  environment:
    - "MOD_MDNS_NAME=Display name for your speaker"
    # Pick a verbosity: debug, info, warn, error
    #- "LOG_LEVEL=warn"
    # Output: supported are alsa, pulseaudio, pipe and process
    #- "MOD_AUDIO_OUTPUT=alsa"
    # If you are using a non default audio device, add it here - example: hw:CARD=sndrpihifiberry,DEV=0
    # Note: you can list audio devices with `aplay -L`
    #- "MOD_AUDIO_DEVICE=default"
    # "alsa" if you want spotify to use the alsa mixer
    #- "SPOTIFY_MIXER=softvol"
    # If mixer alsa is selected, allow to pick a specific control - example: Digital
    #- "MOD_AUDIO_MIXER="
    # Initial default volume when starting (in percent)
    #- "MOD_AUDIO_VOLUME_DEFAULT=75"
    # If you want to entirely disable Spotify ability to control the volume
    #- "MOD_AUDIO_VOLUME_IGNORE=false"
    # If you want to disable volume normalization 
    #- "SPOTIFY_ENABLE_VOLUME_NORMALIZATION=true"
  group_add:
    - audio
  devices:
    - /dev/snd
  cap_drop:
    - ALL
  read_only: true
```

## Notes

### Networking

You need to run this in `host` or `mac(or ip)vlan` networking (because of mDNS).

### Additional arguments

Any additional arguments when running the image will get fed to the `librespot` binary.

This is specifically relevant if you need to use a librespot option that is not hooked through environment variables.

For example, just get --help for a list of all librespot options:
```bash
docker run --rm \
    docker.io/dubodubonduponey/spotify \
    --help
```

### Custom configuration

Commonly used options (see compose file example for details)
* LOG_LEVEL
* MOD_AUDIO_OUTPUT
* MOD_AUDIO_DEVICE
* SPOTIFY_MIXER
* MOD_AUDIO_MIXER
* MOD_AUDIO_VOLUME_DEFAULT
* MOD_AUDIO_VOLUME_IGNORE
* SPOTIFY_ENABLE_VOLUME_NORMALIZATION

Advanced and experimental options:
* ADVANCED_PORT
* HEALTHCHECK_URL
* _EXPERIMENTAL_DISPLAY_ENABLED
* _EXPERIMENTAL_SPOTIFY_CLIENT_ID
* _EXPERIMENTAL_SPOTIFY_CLIENT_SECRET

You may specify the following environment variables at runtime:

Note that changing the port to a privileged port requires you to add `CAP_NET_BIND_SERVICE`.

### Experimental display

Undocumented. Will be moved to a separate project.

## Moar?

See [DEVELOP.md](DEVELOP.md)
