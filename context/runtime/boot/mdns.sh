#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

readonly _default_mod_mdns_configuration_path="$XDG_CONFIG_DIRS/goello/main.json"
_internal_mod_mdns_records=()

mdns::records::add(){
  local type="$1"
  local host="$2"
  local name="${3:-$host}"
  local port="${4:-9}"
  local text="${5:-[\"\"]}" # XXX Goello bug - if [] the announce is not visible
  _internal_mod_mdns_records+=("$(printf '{"Type": "%s", "Host": "%s", "Name": "%s", "Port": %s, "Text": %s}' "$type" "$host" "$name" "$port" "$text")")
}

mdns::records::load(){
  local file="$1"
  local records=""
  while read line -r; do
    records+="$line"
  done < "$file"
  records="${records%]*}"
  records="${records#*[}"
  _internal_mod_mdns_records+=("$records")
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

mdns::start::broadcaster(){
  [ ! -e "$_default_mod_mdns_configuration_path" ] || mdns::records::load "$_default_mod_mdns_configuration_path"
  local IFS=","
  goello-server-ng -json "[${_internal_mod_mdns_records[*]}]" &
}

mdns::start::avahi(){
  # Current issues with Avahi:
  # - no way to change /run/avahi-daemon to another location - symlink works though
  # - daemonization writing to syslog is a problem
  # - avahi insists that /run/avahi-daemon must belong to avahi:avahi
  # which is absolutely ridiculous - https://github.com/lathiat/avahi/blob/778fadb71cb923eee74f3f1967db88b8c2586830/avahi-daemon/main.c#L1434
  # Some variant of it: https://github.com/lathiat/avahi/issues/349
  # - project is half-dead: https://github.com/lathiat/avahi/issues/388

  local args=()
  # local avahisocket="$XDG_STATE_HOME/avahi-daemon/socket"
  # XXX giving up on trying to be fancy with avahi
  local avahisocket="/run/avahi-daemon/socket"

  # Make sure we can write it
  helpers::dir::writable "$(dirname "$avahisocket")" true

  # Cleanup leftovers on container restart
  rm -f "$(dirname "$avahisocket")/pid"

  [ "$LOG_LEVEL" != "debug" ] || args+=(--debug)

  # -D/--daemonize implies -s/--syslog that we do not want, so, just background it
  avahi-daemon -f /config/avahi/main.conf --no-drop-root --no-chroot "${args[@]}" &

  local tries=1
  # Wait until the socket is there
  until [ -e "$avahisocket" ]; do
    sleep 1s
    tries=$(( tries + 1))
    [ $tries -lt 10 ] || {
      printf >&2 "Failed starting avahi in a reasonable time. Something is quite wrong\n"
      return 1
    }
  done
}

mdns::start::dbus(){
  # https://linux.die.net/man/1/dbus-daemon-1
  # https://man7.org/linux/man-pages/man3/sd_bus_default.3.html
  # https://specifications.freedesktop.org/basedir-spec/latest/ar01s03.html

  # $XDG_STATE_HOME=/tmp/state
  # Configuration file also has that ^ hardcoded, so, cannot use the variable...

  local dbussocket=/tmp/state/dbus/system_bus_socket

  # Ensure directory exists
  helpers::dir::writable "$(dirname "$dbussocket")" create

  # Point it there for other systems
  export DBUS_SYSTEM_BUS_ADDRESS=unix:path="$dbussocket"
  export DBUS_SESSION_BUS_ADDRESS=unix:path="$dbussocket"

  # Start it, without a PID file
  dbus-daemon --nopidfile --config-file /config/dbus/main.conf

  local tries=1
  # Wait until the socket is there
  until [ -e "$dbussocket" ]; do
    sleep 1s
    tries=$(( tries + 1))
    [ $tries -lt 10 ] || {
      printf >&2 "Failed starting dbus in a reasonable time. Something is quite wrong\n"
      return 1
    }
  done
}
