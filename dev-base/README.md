# dev-base

Ubuntu 22.04-based development environment container with SSH access.

## Features

- **Base OS**: Ubuntu 22.04
- **SSH Server**: OpenSSH with key-based authentication only
- **Development Tools**: git, vim, tmux, curl, wget, build-essential
- **Node.js**: LTS 24.x installed via n-install
- **Package Manager**: pnpm (enabled via corepack)
- **Shell**: Zsh with Oh My Zsh framework
- **User**: `dev` user with sudo privileges
- **Claude Code**: Pre-installed CLI
- **OpenCode**: Pre-installed CLI

## Usage

### Pull and Run

```bash
# Pull the image
docker pull ghcr.io/meixg/docker-images/dev-base:latest

# Run with SSH access
# Container name is optional, helps with management (e.g., docker stop dev-base)
docker run -d -p 2222:22 \
  --name dev-base \
  -e SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)" \
  ghcr.io/meixg/docker-images/dev-base:latest

# Connect to the container
ssh -p 2222 dev@localhost
```

### Environment Variables

- `SSH_PUB_KEY` - SSH public key for `dev` user (required)

## Security Configuration

### SSH Hardening

The SSH server is configured with the following security measures:

| Setting | Value | Purpose |
|---------|-------|---------|
| `PasswordAuthentication` | `no` | Only allow public key authentication |
| `PermitRootLogin` | `no` | Disable root SSH access |
| `AllowUsers` | `dev` | Only allow dev user to login |
| `MaxAuthTries` | `3` | Limit authentication attempts |
| `ClientAliveInterval` | `300` | Check connection every 5 minutes |
| `ClientAliveCountMax` | `2` | Disconnect after 10 min timeout |
| `X11Forwarding` | `no` | Disable X11 forwarding |
| `AllowTcpForwarding` | `no` | Disable TCP forwarding |

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

## Local Development

```bash
# Build locally
cd dev-base
docker build -t dev-base .

# Run locally
# Container name is optional, helps with management
docker run -d -p 2222:22 \
  --name dev-base \
  -e SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)" dev-base

# Connect
ssh -p 2222 dev@localhost
```

## Container User

The container runs as `root` (required for SSH server to bind port 22).
All SSH login sessions are as the `dev` user.
