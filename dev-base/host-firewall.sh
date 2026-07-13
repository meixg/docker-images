#!/usr/bin/env bash
set -euo pipefail

readonly RULE_MARKER="dev-base-isolation"
readonly BRIDGE_INTERFACE="${DEV_BASE_BRIDGE_INTERFACE:-devbase0}"
readonly UFW_AFTER_RULES="/etc/ufw/after.rules"
readonly -a BLOCKED_IPV4_DESTINATIONS=(
  "0.0.0.0/8"
  "10.0.0.0/8"
  "100.64.0.0/10"
  "127.0.0.0/8"
  "169.254.0.0/16"
  "172.16.0.0/12"
  "192.168.0.0/16"
  "224.0.0.0/4"
  "240.0.0.0/4"
)

usage() {
  cat <<'EOF'
Usage: sudo ./host-firewall.sh <apply|remove|status>

Commands:
  apply   Install persistent UFW rules for the devbase0 Compose bridge.
  remove  Remove only rules managed by this script.
  status  Show the managed rules and fail if any expected rule is missing.

Set DEV_BASE_BRIDGE_INTERFACE to override the default bridge interface name.
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "run this script with sudo"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

validate_bridge_interface() {
  [[ "${BRIDGE_INTERFACE}" =~ ^[[:alnum:]_.:-]{1,15}$ ]] ||
    die "invalid bridge interface name: ${BRIDGE_INTERFACE}"
}

require_active_ufw() {
  LC_ALL=C ufw status | grep -F "Status: active" >/dev/null ||
    die "UFW is not active; review its existing policy before enabling it"
}

rule_exists() {
  local comment="$1"
  LC_ALL=C ufw status | grep -F "${comment}" >/dev/null
}

install_ufw_docker_integration() {
  require_command docker
  require_command ufw-docker
  require_command iptables

  docker info >/dev/null 2>&1 || die "Docker daemon is not reachable"

  if ! grep -Fq "# BEGIN UFW AND DOCKER" "${UFW_AFTER_RULES}"; then
    echo "Installing ufw-docker integration..."
    ufw-docker install
  fi

  # Docker restarts can recreate DOCKER-USER, so reload UFW before checking the
  # live jump into ufw-user-forward.
  ufw reload
  iptables -C DOCKER-USER -j ufw-user-forward >/dev/null 2>&1 ||
    die "DOCKER-USER is not connected to UFW; Docker's nftables backend is not supported by this script"
}

add_managed_rule() {
  local comment="$1"
  shift

  if rule_exists "${comment}"; then
    echo "Already present: ${comment}"
  else
    ufw "$@" comment "${comment}"
  fi
}

apply_rules() {
  local destination comment

  install_ufw_docker_integration

  add_managed_rule "${RULE_MARKER} host" \
    insert 1 deny in on "${BRIDGE_INTERFACE}"

  for destination in "${BLOCKED_IPV4_DESTINATIONS[@]}"; do
    comment="${RULE_MARKER} ${destination}"
    add_managed_rule "${comment}" \
      route insert 1 deny in on "${BRIDGE_INTERFACE}" to "${destination}"
  done

  ufw reload
  echo
  status_rules
  echo
  echo "Applied. Start dev-base with docker compose so it uses ${BRIDGE_INTERFACE}."
}

managed_rule_numbers() {
  LC_ALL=C ufw status numbered |
    grep -F "${RULE_MARKER}" |
    sed -E 's/^[[:space:]]*\[[[:space:]]*([0-9]+)\].*/\1/' |
    sort -rn
}

remove_rules() {
  local -a rule_numbers=()
  local rule_number

  mapfile -t rule_numbers < <(managed_rule_numbers || true)
  if [[ "${#rule_numbers[@]}" -eq 0 ]]; then
    echo "No managed rules found."
    return
  fi

  for rule_number in "${rule_numbers[@]}"; do
    ufw --force delete "${rule_number}"
  done
  ufw reload
  echo "Removed ${#rule_numbers[@]} managed rule(s)."
}

status_rules() {
  local destination comment
  local missing=0

  echo "Managed UFW rules:"
  LC_ALL=C ufw status numbered | grep -F "${RULE_MARKER}" || true

  if ! grep -Fq "# BEGIN UFW AND DOCKER" "${UFW_AFTER_RULES}" ||
    ! iptables -C DOCKER-USER -j ufw-user-forward >/dev/null 2>&1; then
    echo "Missing: live ufw-docker DOCKER-USER integration" >&2
    missing=1
  fi

  if ! rule_exists "${RULE_MARKER} host"; then
    echo "Missing: ${RULE_MARKER} host" >&2
    missing=1
  fi

  for destination in "${BLOCKED_IPV4_DESTINATIONS[@]}"; do
    comment="${RULE_MARKER} ${destination}"
    if ! rule_exists "${comment}"; then
      echo "Missing: ${comment}" >&2
      missing=1
    fi
  done

  if [[ "${missing}" -ne 0 ]]; then
    return 1
  fi

  echo "All expected rules are present for ${BRIDGE_INTERFACE}."
}

main() {
  require_root
  require_command ufw
  require_command iptables
  validate_bridge_interface
  require_active_ufw

  case "${1:-}" in
    apply)
      apply_rules
      ;;
    remove)
      remove_rules
      ;;
    status)
      status_rules
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

main "$@"
