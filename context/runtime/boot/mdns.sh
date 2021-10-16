#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

_mdns_records=()

mdns::add(){
  local type="$1"
  local host="$2"
  local name="${3:-$host}"
  local port="${4:-9}"
  local text="${5:-[]}"
  _mdns_records+=("$(printf '{"Type": "%s", "Host": "%s", "Name": "%s", "Port": %s, "Text": %s}' "$type" "$host" "$name" "$port" "$text")")
}

mdns::start(){
  local IFS=","
  goello-server-ng -json "[${_mdns_records[*]}]"
}
