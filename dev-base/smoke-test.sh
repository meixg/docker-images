#!/usr/bin/env bash
set -euo pipefail

image_ref="${1:?usage: smoke-test.sh <image-ref> [port]}"
port="${2:-2222}"
container_name="dev-base-smoke-${RANDOM}"
tmpdir="$(mktemp -d)"

cleanup() {
  docker rm -f "${container_name}" >/dev/null 2>&1 || true
  rm -rf "${tmpdir}"
}

trap cleanup EXIT

ssh-keygen -q -t ed25519 -N '' -f "${tmpdir}/id_ed25519" >/dev/null
ssh_pub_key="$(tr -d '\n' < "${tmpdir}/id_ed25519.pub")"

docker run --rm --entrypoint sh "${image_ref}" -eu -c '
  baked_host_keys="$(find /etc/ssh -maxdepth 1 -type f -name "ssh_host_*_key" -print)"
  if [ -n "${baked_host_keys}" ]; then
    echo "SSH host private keys must not be baked into the image:" >&2
    echo "${baked_host_keys}" >&2
    exit 1
  fi
'

docker run -d \
  --name "${container_name}" \
  -p "127.0.0.1:${port}:22" \
  -e SSH_PUB_KEY="${ssh_pub_key}" \
  "${image_ref}" >/dev/null

for _ in $(seq 1 30); do
  if docker exec "${container_name}" pgrep -x sshd >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

docker exec "${container_name}" pgrep -x sshd >/dev/null

for expected in \
  "passwordauthentication no" \
  "permitrootlogin no" \
  "allowusers dev" \
  "maxauthtries 3"; do
  docker exec "${container_name}" sh -lc "sshd -T | grep -qx '${expected}'"
done

docker exec "${container_name}" su - dev -c '
  zsh -lc "
    node --version >/dev/null &&
    pnpm --version >/dev/null &&
    zsh --version >/dev/null &&
    tmux -V >/dev/null &&
    claude --version >/dev/null &&
    opencode --version >/dev/null
  "
'

ssh_options=(
  -p "${port}"
  -i "${tmpdir}/id_ed25519"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
)

ssh "${ssh_options[@]}" dev@127.0.0.1 'echo connected >/dev/null'

if ssh "${ssh_options[@]}" root@127.0.0.1 true; then
  echo "root login unexpectedly succeeded" >&2
  exit 1
fi

if ssh \
  -p "${port}" \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  -o NumberOfPasswordPrompts=0 \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  dev@127.0.0.1 true; then
  echo "password authentication unexpectedly succeeded" >&2
  exit 1
fi
