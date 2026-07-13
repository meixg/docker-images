# dev-base

Ubuntu 24.04 LTS-based development environment container with SSH access.

## Features

- **Base OS**: Ubuntu 24.04 LTS
- **SSH Server**: OpenSSH with key-based authentication only
- **Development Tools**: git, vim, tmux, curl, wget, build-essential
- **Node.js**: Latest official binary with signed manifest verification (amd64/arm64)
- **Package Manager**: pnpm (installed globally)
- **Shell**: Zsh with Oh My Zsh framework
- **User**: `dev` user with sudo privileges
- **Claude Code**: Pre-installed CLI
- **OpenCode**: Pre-installed CLI

Node.js, `pnpm`, Claude Code, and OpenCode are preinstalled during the image
build so they are immediately available in SSH sessions. The Dockerfile
authenticates the latest Node.js release manifest with tracked release keys
before verifying the downloaded archive checksum. `pnpm`, Claude Code, and
OpenCode are installed from npm over HTTPS and follow npm's standard registry
trust model rather than the extra signed-manifest flow used for Node.js.

## Usage

### Pull and Run

```bash
# Pull the image
docker pull ghcr.io/meixg/docker-images/dev-base:latest

# Run with SSH access
# Container name is optional, helps with management (e.g., docker stop dev-base)
export TAILSCALE_IP="$(tailscale ip -4)"
docker run -d -p "${TAILSCALE_IP}:2222:22" \
  --name dev-base \
  -e SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)" \
  ghcr.io/meixg/docker-images/dev-base:latest

# Connect from the tailnet through the desktop's MagicDNS hostname
ssh -p 2222 dev@<desktop-magicdns-hostname>
```

### Docker Compose

The included `compose.yaml` runs the published image and exposes its SSH server on
host port `2222`, bound only to the desktop's Tailscale IPv4 address. A listening
socket binds an IP address rather than a MagicDNS hostname, so resolve the local
Tailscale address before starting the service. Compose stops with an error if
`TAILSCALE_IP` or `SSH_PUB_KEY` is unset or empty.

```bash
cd dev-base

# Start the container
export TAILSCALE_IP="$(tailscale ip -4)"
export SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)"
docker compose up -d

# Connect over SSH from a device in the same tailnet. The MagicDNS hostname is
# used by the client; Compose binds the corresponding Tailscale IP address.
ssh -p 2222 dev@<desktop-magicdns-hostname>
```

Verify that Docker published the port only on the Tailscale address, then inspect
or stop the service:

```bash
docker compose port dev-base 22
docker compose logs -f
docker compose down
```

If your public key uses a different filename, replace `~/.ssh/id_rsa.pub` with
that path. To use another host port, change the `2222` side of the port mapping
in `compose.yaml`. If the desktop leaves and rejoins the tailnet and receives a
new Tailscale IP, recreate the service after refreshing `TAILSCALE_IP`.

### Environment Variables

- `SSH_PUB_KEY` - SSH public key for `dev` user (required)
- `TAILSCALE_IP` - desktop's Tailscale IPv4 address, normally from
  `tailscale ip -4` (required by Compose)

## Host Isolation Scripts

Run the host isolation scripts from the `dev-base` directory before starting the
container. Both scripts require root because they change host-wide Docker or UFW
configuration. Neither script enables UFW automatically.

Recommended first-time setup:

```bash
cd dev-base

# Restarts Docker. Run this before dev-base or other important containers.
sudo ./host-userns-remap.sh apply

# Installs the persistent private-network egress rules.
sudo ./host-firewall.sh apply

export TAILSCALE_IP="$(tailscale ip -4)"
export SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)"
docker compose up -d
```

### User Namespace Remapping

`host-userns-remap.sh` sets Docker's `userns-remap` daemon option to `default`.
Container UID 0 is then mapped to an unprivileged high-numbered host UID instead
of host UID 0.

```bash
# Enable, inspect, or disable the setting
sudo ./host-userns-remap.sh apply
sudo ./host-userns-remap.sh status
sudo ./host-userns-remap.sh remove

# For explicitly authorized non-interactive use
sudo ./host-userns-remap.sh apply --yes
```

Before modifying `/etc/docker/daemon.json`, the script validates that it is a
JSON object and refuses symlinks. It preserves other daemon settings, writes a
timestamped backup, restarts Docker, verifies the live `name=userns` security
option and the `dockremap` entries in `/etc/subuid` and `/etc/subgid`, and
automatically restores the previous configuration if restart or verification
fails. It also reloads an installed UFW/Docker integration after the Docker
restart.

Enabling or disabling this setting interrupts all running containers. Enabling
it makes existing images, containers, and volumes temporarily invisible because
Docker uses a remapped storage area; it does not delete them. Disabling it makes
objects created under remapping unavailable and makes the older non-remapped
objects visible again. Re-pull or rebuild the image and recreate `dev-base`.
Bind-mount ownership, `--network=host`,
`--pid=host`, `--privileged`, and some volume drivers also have user-namespace
compatibility constraints. This repository's no-volume setup avoids the usual
bind-mount ownership issue.

The script refuses to overwrite or remove a custom `userns-remap` mapping and
does nothing when Docker is already running in rootless mode. In a non-interactive
session it requires `--yes`; interactively it asks before restarting Docker.

### Host Firewall Boundary

The `restricted` Compose network uses the stable host bridge interface name
`devbase0`. This makes it possible for host firewall rules to identify traffic
from this container without relying on a changing Docker subnet or container IP.
IPv6 is disabled on this network and the container's `NET_RAW` capability is
dropped, preventing IPv6 LAN bypass and raw-packet scanning respectively.
Compose itself does not enforce destination-based egress policy: add persistent
host firewall rules that reject traffic entering from `devbase0` when it is
addressed to the host itself, RFC1918 networks, Tailscale CGNAT addresses,
link-local ranges, IPv6 ULA/link-local ranges, and multicast. Keep public internet
egress only if Codex needs it.

Apply both an input rule and forwarding rules. A forwarding-only `DOCKER-USER`
rule does not cover traffic addressed directly to the Docker host. Test the
policy from inside the container against the router, the desktop's LAN address,
another household device, and a public HTTPS endpoint before treating the
boundary as effective.

On Omarchy, install the persistent UFW rules before starting the container. Run
this again after any independent Docker daemon restart so the live
`DOCKER-USER` to UFW integration is reloaded:

```bash
cd dev-base
sudo ./host-firewall.sh apply
```

The script is idempotent and manages only rules carrying its
`dev-base-isolation` marker. It deliberately refuses to enable UFW automatically,
because changing the host's global firewall state could interrupt remote access.
Use these commands to inspect or remove its rules:

```bash
sudo ./host-firewall.sh status
sudo ./host-firewall.sh remove
```

The script requires Docker's iptables backend and the Omarchy-provided
`ufw-docker` command. It fails closed when `DOCKER-USER` is unavailable rather
than claiming protection under Docker's native nftables backend. The rules apply
only to the `devbase0` network used by Compose; the standalone `docker run`
examples do not use this strict egress boundary.

## Security Configuration

### SSH Hardening

The SSH server is configured with the following security measures:

| Setting | Value | Purpose |
|---------|-------|---------|
| `PasswordAuthentication` | `no` | Only allow public key authentication |
| `KbdInteractiveAuthentication` | `no` | Disable keyboard-interactive authentication |
| `PermitRootLogin` | `no` | Disable root SSH access |
| `AllowUsers` | `dev` | Only allow dev user to login |
| `MaxAuthTries` | `3` | Limit authentication attempts |
| `ClientAliveInterval` | `300` | Check connection every 5 minutes |
| `ClientAliveCountMax` | `2` | Disconnect after 10 min timeout |
| `X11Forwarding` | `no` | Disable X11 forwarding |
| `AllowTcpForwarding` | `no` | Disable TCP forwarding |

These settings are applied via `/etc/ssh/sshd_config.d/10-hardening.conf`, and the image validates them with `sshd -t` during build and container startup.

### NOPASSWD Sudo Trade-off

**Configuration**: The `dev` user has passwordless sudo access (`NOPASSWD:ALL`).

**Justification**:
- This is a **personal development environment**, not a production server
- SSH access requires a private key - authentication is already enforced
- All SSH hardening measures are in place (no password login, no root login, limited users)
- The security barrier is the SSH private key; once authenticated, convenience is prioritized

**Risk Assessment**:
- If the SSH private key is compromised, an attacker has full container access
- This is acceptable for personal development use where the key owner is trusted
- For public/shared deployments, consider requiring a sudo password

**To Change**:
If you require sudo password authentication, modify the Dockerfile:
```dockerfile
# Change from:
echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
# To:
echo "dev ALL=(ALL) ALL" >> /etc/sudoers
```
Then set a password for the `dev` user.

## Dependency Update Policy

Node.js, pnpm, Claude Code, and OpenCode are intentionally installed without
fixed version numbers. A clean image build picks up their latest available
releases. The Node.js archive is verified against the latest upstream
`SHASUMS256.txt.asc` manifest after that manifest is authenticated with the
tracked Node.js release keys. Using the unversioned `latest` endpoint is
intentional here to preserve the main branch's rolling-toolchain behavior; use
an image SHA tag when you need a reproducible environment.

Oh My Zsh remains pinned through `OH_MY_ZSH_COMMIT` to avoid executing an
unverified remote installer. Update that commit explicitly and rebuild for both
`linux/amd64` and `linux/arm64` when upgrading it.

Use an image SHA tag when a reproducible toolchain is required.

## Local Development

```bash
# Build locally
cd dev-base
docker build -t dev-base .

# Run the smoke test against a locally built image
./smoke-test.sh dev-base

# Run locally
# Container name is optional, helps with management
export TAILSCALE_IP="$(tailscale ip -4)"
docker run -d -p "${TAILSCALE_IP}:2222:22" \
  --name dev-base \
  -e SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)" dev-base

# Connect
ssh -p 2222 dev@<desktop-magicdns-hostname>
```

## Image Rebuild Policy

- Changes to files under `dev-base/` (including `Dockerfile`, `entrypoint.sh`, and `.zshrc`) trigger the publish workflow on pushes to `main`.
- The publish workflow also performs a scheduled rebuild every Monday at 03:00 UTC.
- Scheduled rebuilds, and manual workflow runs with `clean_rebuild` enabled, ensure the pinned `ubuntu:24.04` base image digest is present locally and bypass BuildKit cache for all build layers.
- Regular push builds continue to use GitHub Actions cache for faster day-to-day publishes.

## CI Verification and Supply Chain Metadata

- CI builds a local `dev-base` smoke-test image before publishing and runs `sshd -t`.
- The smoke test starts the container, verifies the hardened SSH configuration, checks that `sshd` stays alive, and confirms public-key login works while root and password logins fail.
- CI also verifies the preinstalled `node`, `pnpm`, `zsh`, `tmux`, `claude`, and `opencode` commands.
- Trivy scans the image for `HIGH` and `CRITICAL` OS and application vulnerabilities before publish; any non-waived finding fails the workflow.
- Temporary Trivy waivers must be recorded in `.trivyignore.yaml` with the vulnerability ID and a justification.
- Published images include an SBOM attestation and GitHub build provenance attestation in GHCR.

## Container User

The container runs as `root` (required for SSH server to bind port 22).
All SSH login sessions are as the `dev` user.
