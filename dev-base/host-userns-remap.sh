#!/usr/bin/env bash
set -euo pipefail

readonly DOCKER_CONFIG="${DOCKER_DAEMON_CONFIG:-/etc/docker/daemon.json}"
readonly SUBUID_FILE="${DOCKER_SUBUID_FILE:-/etc/subuid}"
readonly SUBGID_FILE="${DOCKER_SUBGID_FILE:-/etc/subgid}"
readonly USERNS_KEY="userns-remap"
readonly USERNS_VALUE="default"

ASSUME_YES=false

usage() {
  cat <<'EOF'
Usage: sudo ./host-userns-remap.sh <apply|remove|status> [--yes]

Commands:
  apply   Set "userns-remap" to "default" and restart Docker.
  remove  Remove this setting and restart Docker.
  status  Compare daemon.json with Docker's active security options.

Options:
  --yes   Skip the interactive Docker-restart confirmation.

Docker restarts interrupt running containers. Existing Docker objects are hidden
while userns-remap is enabled, but they are not deleted.
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

validate_config_path() {
  [[ "${DOCKER_CONFIG}" == /* ]] || die "Docker config path must be absolute"
  [[ "${DOCKER_CONFIG}" != */../* && "${DOCKER_CONFIG}" != */.. ]] ||
    die "Docker config path must not contain '..'"
}

validate_config() {
  if [[ -e "${DOCKER_CONFIG}" ]]; then
    [[ -f "${DOCKER_CONFIG}" && ! -L "${DOCKER_CONFIG}" ]] ||
      die "Docker config must be a regular file, not a symlink: ${DOCKER_CONFIG}"
    jq -e 'type == "object"' "${DOCKER_CONFIG}" >/dev/null ||
      die "Docker config is not a valid JSON object: ${DOCKER_CONFIG}"
  fi
}

configured_value() {
  if [[ -e "${DOCKER_CONFIG}" ]]; then
    jq -r --arg key "${USERNS_KEY}" '.[$key] // empty' "${DOCKER_CONFIG}"
  fi
}

docker_security_options() {
  docker info --format '{{json .SecurityOptions}}'
}

docker_userns_active() {
  docker_security_options | grep -F 'name=userns' >/dev/null
}

docker_rootless_active() {
  docker_security_options | grep -F 'name=rootless' >/dev/null
}

subordinate_ranges_valid() {
  local file="$1"
  awk -F: '
    $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ && $3 > 0 {
      count++
      owner[count] = $1
      first[count] = $2
      last[count] = $2 + $3 - 1
      if ($1 == "dockremap" && !dockremap_seen) {
        dockremap_seen = 1
        dockremap_large_enough = ($3 >= 65536)
      }
    }
    END {
      if (!dockremap_seen || !dockremap_large_enough) exit 1
      for (i = 1; i <= count; i++) {
        for (j = i + 1; j <= count; j++) {
          if (first[i] <= last[j] && first[j] <= last[i]) {
            printf "Overlapping subordinate ranges in %s: %s and %s\n", FILENAME, owner[i], owner[j] > "/dev/stderr"
            exit 1
          }
        }
      }
    }
  ' "${file}"
}

default_mapping_ready() {
  getent passwd dockremap >/dev/null 2>&1 &&
    subordinate_ranges_valid "${SUBUID_FILE}" &&
    subordinate_ranges_valid "${SUBGID_FILE}"
}

confirm_restart() {
  local action="$1"
  if [[ "${ASSUME_YES}" == true ]]; then
    return
  fi
  [[ -t 0 ]] || die "confirmation required; rerun with --yes in a non-interactive session"

  echo "This will ${action} and restart Docker."
  echo "Running containers, including dev-base SSH sessions, will be interrupted."
  read -r -p "Continue? [y/N] " answer
  [[ "${answer}" == "y" || "${answer}" == "Y" ]] || die "cancelled"
}

backup_config() {
  if [[ -e "${DOCKER_CONFIG}" ]]; then
    local backup
    backup="${DOCKER_CONFIG}.userns-remap.$(date -u +%Y%m%dT%H%M%SZ).$$.bak"
    cp -a -- "${DOCKER_CONFIG}" "${backup}"
    printf '%s\n' "${backup}"
  fi
}

write_config() {
  local operation="$1"
  local config_dir tmp
  config_dir="$(dirname -- "${DOCKER_CONFIG}")"
  mkdir -p -- "${config_dir}"
  tmp="$(mktemp "${config_dir}/.daemon.json.userns-remap.XXXXXX")"

  if [[ "${operation}" == "apply" ]]; then
    if [[ -e "${DOCKER_CONFIG}" ]]; then
      jq --arg key "${USERNS_KEY}" --arg value "${USERNS_VALUE}" \
        '.[$key] = $value' "${DOCKER_CONFIG}" > "${tmp}"
    else
      jq -n --arg key "${USERNS_KEY}" --arg value "${USERNS_VALUE}" \
        '{($key): $value}' > "${tmp}"
    fi
  else
    jq --arg key "${USERNS_KEY}" 'del(.[$key])' "${DOCKER_CONFIG}" > "${tmp}"
  fi

  jq -e 'type == "object"' "${tmp}" >/dev/null
  if [[ -e "${DOCKER_CONFIG}" ]]; then
    chown --reference="${DOCKER_CONFIG}" -- "${tmp}"
    chmod --reference="${DOCKER_CONFIG}" -- "${tmp}"
  else
    chown root:root -- "${tmp}"
    chmod 0644 -- "${tmp}"
  fi
  mv -f -- "${tmp}" "${DOCKER_CONFIG}"
}

reload_ufw_docker_if_configured() {
  if command -v ufw >/dev/null 2>&1 &&
    [[ -f /etc/ufw/after.rules ]] &&
    grep -Fq "# BEGIN UFW AND DOCKER" /etc/ufw/after.rules &&
    LC_ALL=C ufw status | grep -F "Status: active" >/dev/null; then
    echo "Reloading UFW after the Docker restart..."
    ufw reload
  fi
}

restart_docker() {
  local attempt
  systemctl restart docker || return 1

  for attempt in {1..15}; do
    if docker info >/dev/null 2>&1; then
      reload_ufw_docker_if_configured
      return 0
    fi
    sleep 1
  done
  return 1
}

restore_config() {
  local backup="$1"
  if [[ -n "${backup}" ]]; then
    cp -a -- "${backup}" "${DOCKER_CONFIG}"
  else
    rm -f -- "${DOCKER_CONFIG}"
  fi
}

rollback() {
  local backup="$1"
  echo "Restoring the previous Docker configuration..." >&2
  restore_config "${backup}"
  if restart_docker; then
    echo "Rollback succeeded." >&2
  else
    echo "Rollback restored ${DOCKER_CONFIG}, but Docker did not restart successfully." >&2
  fi
}

status_userns() {
  local configured security
  configured="$(configured_value)"
  security="$(docker_security_options)" || die "Docker daemon is not reachable"

  echo "Docker config: ${DOCKER_CONFIG}"
  echo "Configured ${USERNS_KEY}: ${configured:-<disabled>}"
  echo "Active security options: ${security}"

  if [[ "${configured}" == "${USERNS_VALUE}" ]] && docker_userns_active; then
    if default_mapping_ready; then
      echo "userns-remap is active."
      return 0
    fi
    echo "userns-remap is active, but dockremap subordinate ranges are missing, too small, or overlapping." >&2
    return 1
  fi
  if [[ -n "${configured}" && "${configured}" != "${USERNS_VALUE}" ]] &&
    docker_userns_active; then
    echo "A custom userns-remap mapping is active."
    return 0
  fi
  if [[ -z "${configured}" ]] && ! docker_userns_active; then
    echo "userns-remap is disabled."
    return 1
  fi

  echo "Configuration and Docker runtime state do not match; restart Docker." >&2
  return 1
}

apply_userns() {
  local configured backup=""
  configured="$(configured_value)"

  if docker_rootless_active; then
    die "Docker is already running rootless; userns-remap is unnecessary"
  fi
  if [[ -n "${configured}" && "${configured}" != "${USERNS_VALUE}" ]]; then
    die "${USERNS_KEY} is already set to '${configured}'; refusing to overwrite a custom mapping"
  fi
  if [[ "${configured}" == "${USERNS_VALUE}" ]] &&
    docker_userns_active && default_mapping_ready; then
    echo "userns-remap is already configured and active."
    return
  fi

  confirm_restart "enable userns-remap"
  backup="$(backup_config)"
  write_config apply

  if ! restart_docker || ! docker_userns_active || ! default_mapping_ready; then
    rollback "${backup}"
    die "failed to enable userns-remap or create non-overlapping dockremap subordinate ranges"
  fi

  [[ -z "${backup}" ]] || echo "Backup: ${backup}"
  status_userns
  echo "Re-pull or rebuild images and recreate containers under the remapped storage."
}

remove_userns() {
  local configured backup=""
  configured="$(configured_value)"

  if [[ -z "${configured}" ]]; then
    echo "userns-remap is not configured in ${DOCKER_CONFIG}."
    return
  fi
  if [[ "${configured}" != "${USERNS_VALUE}" ]]; then
    die "refusing to remove custom ${USERNS_KEY} value '${configured}'"
  fi

  confirm_restart "disable userns-remap"
  backup="$(backup_config)"
  write_config remove

  if ! restart_docker || docker_userns_active; then
    rollback "${backup}"
    die "failed to disable userns-remap"
  fi

  [[ -z "${backup}" ]] || echo "Backup: ${backup}"
  echo "userns-remap is disabled. Older Docker objects may become visible again, while objects created under remapping become unavailable."
}

parse_args() {
  ACTION="${1:-}"
  case "${2:-}" in
    "") ;;
    --yes) ASSUME_YES=true ;;
    *) usage; exit 2 ;;
  esac
  [[ "$#" -le 2 ]] || { usage; exit 2; }
}

main() {
  require_root
  require_command docker
  require_command getent
  require_command jq
  require_command systemctl
  validate_config_path
  validate_config
  parse_args "$@"

  case "${ACTION}" in
    apply) apply_userns ;;
    remove) remove_userns ;;
    status) status_userns ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"
