#!/usr/bin/env bash
set -euo pipefail

: "${HOME:=/home/work}"
: "${PASEO_HOME:=${HOME}/.paseo}"
: "${PASEO_LISTEN:=0.0.0.0:6767}"
: "${PASEO_WEB_UI_ENABLED:=true}"
: "${PASEO_LOG_LEVEL:=info}"
: "${PASEO_LOG_FORMAT:=json}"
: "${CODEX_HOME:=${HOME}/.codex}"
: "${DSH_HOME:=${HOME}/.dsh}"
: "${XDG_CONFIG_HOME:=${HOME}/.config}"
: "${XDG_DATA_HOME:=${HOME}/.local/share}"
: "${XDG_STATE_HOME:=${HOME}/.local/state}"
: "${XDG_CACHE_HOME:=${HOME}/.cache}"

export HOME
export PASEO_HOME
export PASEO_LISTEN
export PASEO_WEB_UI_ENABLED
export PASEO_LOG_LEVEL
export PASEO_LOG_FORMAT
export CODEX_HOME
export DSH_HOME
export XDG_CONFIG_HOME
export XDG_DATA_HOME
export XDG_STATE_HOME
export XDG_CACHE_HOME

ensure_dir() {
  local dir="$1"
  mkdir -p "$dir"
}

DSH_CREDENTIALS_TEMPLATE=/usr/local/share/dev-paseo/dsh-credentials.yaml
DSH_PROVIDER_JSON='{"extends":"acp","label":"DeepSeek Harness","description":"DeepSeek Harness (dsh) coding agent over ACP stdio.","command":["dsh","--profile","acp"],"env":{},"enabled":true}'

seed_dsh_credentials() {
  local target="${DSH_HOME}/.credentials.yaml"
  if [ -e "$target" ]; then
    # DSH refuses to load a credentials file that other users can read.
    chmod 600 "$target" 2>/dev/null || true
    return
  fi
  if [ -f "$DSH_CREDENTIALS_TEMPLATE" ]; then
    install -m 600 "$DSH_CREDENTIALS_TEMPLATE" "$target"
  else
    printf '%s\n' \
      'version: 1' \
      '' \
      'refs:' \
      '  DEEPSEEK_API_KEY: ${DeepSeek API Key}' > "$target"
    chmod 600 "$target"
  fi
  echo "[dsh] created ${target}; replace the DEEPSEEK_API_KEY placeholder"
}

prewarm_dsh_acp_profile() {
  # Paseo probes ACP providers with a short timeout. Bootstrapping the profile
  # on first provider use can exceed it, so initialize it before starting the
  # daemon. This is a no-op once the profile exists in the mounted home.
  if [ -f "${DSH_HOME}/profiles/acp/package.json" ]; then
    return
  fi
  echo "[dsh] initializing ACP profile"
  if ! dsh --profile acp --help >/dev/null 2>&1; then
    echo "[dsh] WARNING: failed to initialize the ACP profile; Paseo may report provider 'dsh' as unavailable." >&2
  fi
}

seed_paseo_dsh_provider() {
  local config="${PASEO_HOME}/config.json"
  local tmp
  if [ ! -e "$config" ]; then
    cat > "$config" <<'JSON'
{
  "version": 1,
  "daemon": {
    "listen": "127.0.0.1:6767",
    "cors": {
      "allowedOrigins": [
        "https://app.paseo.sh"
      ]
    },
    "relay": {
      "enabled": false
    }
  },
  "app": {
    "baseUrl": "https://app.paseo.sh"
  },
  "agents": {
    "providers": {
      "dsh": {
        "extends": "acp",
        "label": "DeepSeek Harness",
        "description": "DeepSeek Harness (dsh) coding agent over ACP stdio.",
        "command": ["dsh", "--profile", "acp"],
        "env": {},
        "enabled": true
      }
    }
  }
}
JSON
    chmod 600 "$config"
    echo "[paseo] created config with dsh ACP provider"
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "[paseo] WARNING: jq is unavailable; add the dsh provider to ${config} manually." >&2
    return
  fi
  if ! jq -e . "$config" >/dev/null 2>&1; then
    echo "[paseo] WARNING: ${config} is not valid JSON; add the dsh provider manually." >&2
    return
  fi
  if jq -e '.agents.providers.dsh' "$config" >/dev/null 2>&1; then
    return
  fi
  tmp="$(mktemp "${PASEO_HOME}/.config.json.XXXXXX")"
  if jq --argjson dsh "$DSH_PROVIDER_JSON" '.agents.providers.dsh = $dsh' "$config" > "$tmp"; then
    chmod 600 "$tmp"
    mv -f "$tmp" "$config"
    echo "[paseo] added dsh ACP provider to ${config}"
  else
    rm -f "$tmp"
    echo "[paseo] WARNING: failed to add the dsh provider to ${config}." >&2
  fi
}

ensure_dir "$HOME"
if [ ! -e "${HOME}/.zshrc" ]; then
  install -m 644 /etc/skel/.zshrc "${HOME}/.zshrc"
fi
ensure_dir "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
ensure_dir "$PASEO_HOME"
ensure_dir "$CODEX_HOME"
ensure_dir "$DSH_HOME"
ensure_dir "${HOME}/.pi/agent"
ensure_dir "$XDG_CONFIG_HOME"
ensure_dir "$XDG_DATA_HOME"
ensure_dir "$XDG_STATE_HOME"
ensure_dir "$XDG_CACHE_HOME"

seed_dsh_credentials
prewarm_dsh_acp_profile
seed_paseo_dsh_provider

if [ -z "${PASEO_PASSWORD:-}" ]; then
  {
    echo "[paseo] WARNING: PASEO_PASSWORD is not set."
    echo "[paseo] The daemon accepts unauthenticated control connections from any client that can reach it."
    echo "[paseo] Set PASEO_PASSWORD for any published port or network-reachable deployment."
  } >&2
fi

if [ ! -f /etc/paseo-server-entry ]; then
  echo "[paseo] FATAL: /etc/paseo-server-entry is missing." >&2
  exit 1
fi

entry="$(cat /etc/paseo-server-entry)"
echo "[paseo] starting daemon on ${PASEO_LISTEN} with web UI ${PASEO_WEB_UI_ENABLED}"
exec node "$entry"
