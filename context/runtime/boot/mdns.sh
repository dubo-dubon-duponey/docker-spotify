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

mdns::start::default(){
  local host="${1:-}"
  local name="${2:-}"
  local with_http_proxy="${3:-}"
  local with_http_proxy_https="${4:-}"
  local with_tls_proxy="${5:-}"
  local with_station="${6:-}"
  local type="${7:-}"

  local http_proxy_https_port="${7:-443}"
  local http_proxy_http_port="${8:-80}"
  local tls_proxy_port="${9:-443}"

  local port="$tls_proxy_port"

  [ "$with_http_proxy" != true ] || {
    port="$([ "$with_http_proxy_https" == true ] && printf "%s" "$http_proxy_https_port" || printf "%s" "$http_proxy_http_port")"
    type="${type:-_http._tcp}"
  }
  [ "$with_tls_proxy" != true ] || type="${type:-_tls._tcp}"

  mdns::records::add "$type" "$host" "$name" "$port"
  [ "$with_station" != true ] || mdns::records::add "_workstation._tcp" "$host" "$name" "$port"
  mdns::start::broadcaster
}

mdns::start::broadcaster(){
  [ ! -e "$_default_mod_mdns_configuration_path" ] || mdns::records::load "$_default_mod_mdns_configuration_path"
  local IFS=","
  goello-server-ng -json "[${_internal_mod_mdns_records[*]}]" &
}

mdns::start::avahi(){
  # Current issues with Avahi:
  # - no way to change /run/avahi-daemon to another location - symlink works though (has to happen in the Dockerfile obviously)
  # - daemonization writing to syslog is a problem
  # - avahi insists that /run/avahi-daemon must belong to avahi:avahi
  # which is absolutely ridiculous - https://github.com/lathiat/avahi/blob/778fadb71cb923eee74f3f1967db88b8c2586830/avahi-daemon/main.c#L1434
  # Some variant of it: https://github.com/lathiat/avahi/issues/349
  # - project is half-dead anyway: https://github.com/lathiat/avahi/issues/388

  local log_level="$1"
  local args=()
  local avahisocket="/run/avahi-daemon/socket"

  # Make sure we can write it
  helpers::dir::writable "$(dirname "$avahisocket")"

  # Cleanup leftovers on container restart
  rm -f "$(dirname "$avahisocket")/pid"

  [ "$log_level" != "debug" ] || args+=(--debug)

  # -D/--daemonize implies -s/--syslog that we do not want, so, just background it
  # shellcheck disable=SC2015
  {
    {
      avahi-daemon -f "$XDG_CONFIG_DIRS"/avahi/main.conf --no-drop-root --no-chroot "${args[@]}" 2>&1
    } > >(helpers::logger::slurp "$log_level" "[avahi]") \
      && helpers::logger::log INFO "[avahi]" "Avahi stopped" \
      || helpers::logger::log ERROR "[avahi]" "Avahi stopped with exit code: $?"
  } &


  local tries=1
  # Wait until the socket is there
  until [ -e "$avahisocket" ]; do
    sleep 1s
    tries=$(( tries + 1))
    [ $tries -lt 10 ] || {
      helpers::logger::log ERROR "[avahi]" "Failed starting avahi in a reasonable time. Something is quite wrong"
      return 1
    }
    helpers::logger::log DEBUG "[avahi]" "Avahi started successfully"
  done
}

mdns::start::dbus(){
  # https://linux.die.net/man/1/dbus-daemon-1
  # https://man7.org/linux/man-pages/man3/sd_bus_default.3.html
  # https://specifications.freedesktop.org/basedir-spec/latest/ar01s03.html

  local log_level="$1"
  local dbussocket=/magnetar/runtime/dbus/system_bus_socket
  # Configuration file also has that ^ hardcoded, so, cannot use the variable...

  # Ensure directory exists
  helpers::dir::writable "$(dirname "$dbussocket")" create

  # Point it there for other systems
  export DBUS_SYSTEM_BUS_ADDRESS=unix:path="$dbussocket"
  export DBUS_SESSION_BUS_ADDRESS=unix:path="$dbussocket"

  # Start it, without a PID file, no fork
  # XXX somehow right now shairport-sync is not happy - disable custom config for now
  # dbus-daemon --nofork --nopidfile --nosyslog --config-file "$XDG_CONFIG_DIRS"/dbus/main.conf
  # shellcheck disable=SC2015
  {
    {
      dbus-daemon --system --nofork --nopidfile --nosyslog 2>&1
    } > >(helpers::logger::slurp "$log_level" "[dbus]") \
      && helpers::logger::log INFO "[dbus]" "DBUS stopped" \
      || helpers::logger::log ERROR "[dbus]" "DBUS stopped with exit code: $?"
  } &

  local tries=1
  # Wait until the socket is there
  until [ -e "$dbussocket" ]; do
    sleep 1s
    tries=$(( tries + 1))
    [ $tries -lt 10 ] || {
      helpers::logger::log ERROR "[dbus]" "Failed starting dbus in a reasonable time. Something is quite wrong"
      return 1
    }
  done
  helpers::logger::log DEBUG "[dbus]" "DBUS started successfully"
}
