#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

#username="$(cat /tmp/cache/credentials.json | jq -rc .username)"
#auth="$(cat /tmp/cache/credentials.json | jq -rc .auth_data | base64 -d)"

get::token(){
  local cid="$1"
  local cse="$2"
  local token
  curl -fsSL -X "POST" -H "Authorization: Basic $(printf "%s:%s" "$cid" "$cse" | base64 -w 0)" -d grant_type=client_credentials https://accounts.spotify.com/api/token | jq -rc .access_token
}

get::url(){
  local token="$1"
  local tid="$2"
  curl -fsSL \
    "https://api.spotify.com/v1/tracks/$tid" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" | jq -rc .album.images[0].url
}

display(){
  local img="$1"
  # Should be smarter and verify permissions on the ttys or bail out
  fbi -a -noverbose -norandom -T 2 -once "$img"
}

call(){
  if [ ! "$SPOTIFY_CLIENT_ID" ] || [ ! "$SPOTIFY_CLIENT_SECRET" ] || [ ! "$DISPLAY_ENABLED" ]; then
    printf >&2 "No token or display has been disabled. Nothing to be done.\n"
    exit
  fi

  case "$PLAYER_EVENT" in
    "stopped")
      display /boot/default.jpg
      exit
    ;;
    "playing")
      echo "Ignoring playing"
      exit
    ;;
    "paused")
      echo "Ignoring paused"
      exit
    ;;
    "preloading")
      echo "Ignoring preloading"
      exit
    ;;
    "volume_set")
      echo "Ignoring volume_set"
      exit
    ;;
    "changed")
    ;;
    "started")
    ;;
  esac

  local image
  [ -e /tmp/token ] || get::token "$SPOTIFY_CLIENT_ID" "$SPOTIFY_CLIENT_SECRET" > /tmp/token || {
    echo "Failed to get token. Wrong credentials?"
    exit 1
  }

  image="$(get::url "$(cat /tmp/token)" "$TRACK_ID")" || {
    echo "Failed. Token expired? Retrying."
    rm /tmp/token
    get::token "$SPOTIFY_CLIENT_ID" "$SPOTIFY_CLIENT_SECRET" > /tmp/token
    image="$(get::url "$(cat /tmp/token)" "$TRACK_ID")"
  }

  curl -fsSL -o /tmp/framebuffer_album.jpg "$image"
  display /tmp/framebuffer_album.jpg
}

# This seems to be blocking (librespot, whatsup?), so, avoid underrun issues
call &
