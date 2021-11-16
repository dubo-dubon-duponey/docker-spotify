#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

_mdns_records=()

mdns::records::add(){
  local type="$1"
  local host="$2"
  local name="${3:-$host}"
  local port="${4:-9}"
  local text="${5:-[]}"
  _mdns_records+=("$(printf '{"Type": "%s", "Host": "%s", "Name": "%s", "Port": %s, "Text": %s}' "$type" "$host" "$name" "$port" "$text")")
}

mdns::records::broadcast(){
  local IFS=","
  goello-server-ng -json "[${_mdns_records[*]}]"
}

mdns::records::resolve(){
  local name="$1"
  local type="$2"
  local server
  local port
  server="$(goello-client -t "$type" -n "$name")"
  port="$(printf "%s" "$server" | jq -rc .Port)"
  server="$(printf "%s" "$server" | jq -rc .IPs[])"
  printf "%s %s" "$server" "$port"
}

mdns::resolver::start(){
  helpers::dir::writable "$XDG_STATE_HOME/avahi-daemon" create
  rm -f /run/avahi-daemon/pid
  avahi-daemon -f /config/avahi/main.conf --daemonize --no-drop-root --no-chroot --debug
}
