# dev-paseo

Paseo daemon container built on top of the `dev-base` image. Provides a
ready-to-run Paseo server with Codex, OpenCode, Pi, and a full development
toolchain.

## Features

All features from [dev-base](../dev-base/) are inherited:

- **Base OS**: Ubuntu 24.04 LTS
- **Development Tools**: git, vim, tmux, curl, wget, build-essential
- **Node.js**: Latest official binary with signed manifest verification (amd64/arm64)
- **Package Manager**: pnpm (installed globally)
- **Shell**: Zsh with Oh My Zsh framework
- **Codex**: Pre-installed CLI
- **OpenCode**: Pre-installed CLI
- **Pi**: Pre-installed CLI

Additional features in this image:

- **Paseo Daemon**: `@getpaseo/cli` and `@getpaseo/server` installed from npm
- **Web UI**: Paseo web interface enabled by default on port 6767
- **User**: Runs as the `work` user (UID/GID 1001, home `/home/work`)
- **Default shell**: `/bin/zsh` is exported in the daemon environment

Unlike `dev-base`, this image does **not** run SSH. It starts the Paseo server
as the single foreground process under `tini`.

The image sets `SHELL=/bin/zsh` explicitly because Paseo's ordinary terminal
creation path does not send a command or arguments. The server then resolves
the shell from its environment, so relying only on the `work` user's login
shell (`/etc/passwd`) is not sufficient. Docker Compose and `docker run` may
still explicitly override `SHELL` when a different shell is required.

## Usage

### Pull and Run

```bash
# Pull the image
docker pull ghcr.io/meixg/docker-images/dev-paseo:latest

# Run with Paseo web UI on port 6767
mkdir -p "${HOME}/docker-homes/dev-paseo"
docker run -d \
  --name dev-paseo \
  -p 6767:6767 \
  -v "${HOME}/docker-homes/dev-paseo:/home/work" \
  ghcr.io/meixg/docker-images/dev-paseo:latest
```

Paseo starts listening on `0.0.0.0:6767` with the web UI enabled. Open
`http://localhost:6767` in a browser to access the interface.

### Docker Compose

Use the included `compose.yaml`. It bind-mounts
`${DOCKER_HOMES_ROOT}/dev-paseo` as the complete `/home/work`:

```yaml
services:
  dev-paseo:
    image: ghcr.io/meixg/docker-images/dev-paseo:latest
    container_name: dev-paseo
    ports:
      - "6767:6767"
    volumes:
      - "${DOCKER_HOMES_ROOT:?Set DOCKER_HOMES_ROOT to an absolute host path}/dev-paseo:/home/work"
    environment:
      PASEO_PASSWORD: "${PASEO_PASSWORD:?Set PASEO_PASSWORD to a strong password}"
```

```bash
# Start the container
export PASEO_PASSWORD="your-strong-password"
export DOCKER_HOMES_ROOT="${HOME}/docker-homes"
mkdir -p "${DOCKER_HOMES_ROOT}/dev-paseo"
docker compose up -d

# View logs
docker compose logs -f

# Stop the container
docker compose down
```

### Access Paseo CLI Inside the Container

```bash
docker exec -it dev-paseo paseo --help
docker exec -it dev-paseo paseo agent list
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `SHELL` | `/bin/zsh` | Default shell for Paseo terminals that do not specify a command |
| `PASEO_HOME` | `/home/work/.paseo` | Paseo data directory |
| `PASEO_LISTEN` | `0.0.0.0:6767` | Listen address and port |
| `PASEO_WEB_UI_ENABLED` | `true` | Enable/disable the web UI |
| `PASEO_LOG_LEVEL` | `info` | Log level (trace/debug/info/warn/error) |
| `PASEO_LOG_FORMAT` | `json` | Log format (json/text) |
| `PASEO_PASSWORD` | _(unset)_ | Authentication password for the Paseo web UI |

If `PASEO_PASSWORD` is not set, the daemon starts without authentication and
logs a warning. Always set `PASEO_PASSWORD` for network-reachable deployments.

## Data Persistence

Bind-mount `${HOME}/docker-homes/dev-paseo` at `/home/work` to persist the
complete user home, including Paseo state, provider credentials, SSH files, and
repositories:

```bash
docker run -d \
  --name dev-paseo \
  -p 6767:6767 \
  -v "${HOME}/docker-homes/dev-paseo:/home/work" \
  -e PASEO_PASSWORD="your-strong-password" \
  ghcr.io/meixg/docker-images/dev-paseo:latest
```

## Security Considerations

- **Authentication**: Set `PASEO_PASSWORD` for any published port or
  network-reachable deployment. Without it, the daemon accepts unauthenticated
  control connections from any client that can reach it.
- **No SSH**: Unlike `dev-base`, this image does not start an SSH server.
  Paseo's own TLS+authentication layer is the primary access control.
- **Non-root**: The Paseo daemon runs as the `work` user (UID/GID 1001).
- **Sensitive home**: `/home/work` can contain SSH keys and provider credentials;
  protect the bind-mounted host directory and its backups.
- **Init Process**: `tini` is used as PID 1 for proper signal forwarding and
  zombie process reaping.

## Local Development

```bash
# Build locally
cd dev-paseo
docker build -t dev-paseo .

# Validate against a locally-built dev-base candidate
docker build \
  --build-arg DEV_BASE_IMAGE=dev-base-work-home:test \
  -t dev-paseo-work-home:test .

# Run locally
docker run -d --name dev-paseo -p 6767:6767 dev-paseo

# Check health
curl http://localhost:6767/api/health

# View logs
docker logs -f dev-paseo

# Stop and remove
docker stop dev-paseo && docker rm dev-paseo
```

## Image Rebuild Policy

- Changes to files under `dev-paseo/` (including `Dockerfile` and `entrypoint.sh`)
  trigger the publish workflow on pushes to `main`.
- The `dev-paseo` build runs after `dev-base` is published, ensuring it always
  uses the latest published `dev-base` as its base image.
- Scheduled rebuilds (weekly) and manual workflow runs with `clean_rebuild`
  enabled rebuild all layers without cache.
- Published images include an SBOM attestation and GitHub build provenance
  attestation in GHCR.

## Container User

The container runs as the `work` user (UID/GID 1001). The `tini` init process and the
Paseo server both execute under this user.
