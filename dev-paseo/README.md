# dev-paseo

Paseo daemon container built on top of the `dev-base` image. Provides a
ready-to-run Paseo server with Claude Code, OpenCode, and a full development
toolchain.

## Features

All features from [dev-base](../dev-base/) are inherited:

- **Base OS**: Ubuntu 24.04 LTS
- **Development Tools**: git, vim, tmux, curl, wget, build-essential
- **Node.js**: Latest official binary with signed manifest verification (amd64/arm64)
- **Package Manager**: pnpm (installed globally)
- **Shell**: Zsh with Oh My Zsh framework
- **Claude Code**: Pre-installed CLI
- **OpenCode**: Pre-installed CLI

Additional features in this image:

- **Paseo Daemon**: `@getpaseo/cli` and `@getpaseo/server` installed from npm
- **Web UI**: Paseo web interface enabled by default on port 6767
- **User**: Runs as the `dev` user (UID 1000)

Unlike `dev-base`, this image does **not** run SSH. It starts the Paseo server
as the single foreground process under `tini`.

## Usage

### Pull and Run

```bash
# Pull the image
docker pull ghcr.io/meixg/docker-images/dev-paseo:latest

# Run with Paseo web UI on port 6767
docker run -d \
  --name dev-paseo \
  -p 6767:6767 \
  -v dev-paseo-home:/home/dev \
  ghcr.io/meixg/docker-images/dev-paseo:latest
```

Paseo starts listening on `0.0.0.0:6767` with the web UI enabled. Open
`http://localhost:6767` in a browser to access the interface.

### Docker Compose

Create a `compose.yaml`:

```yaml
services:
  dev-paseo:
    image: ghcr.io/meixg/docker-images/dev-paseo:latest
    container_name: dev-paseo
    ports:
      - "6767:6767"
    volumes:
      - dev-paseo-home:/home/dev
    environment:
      PASEO_PASSWORD: "${PASEO_PASSWORD:?Set PASEO_PASSWORD to a strong password}"

volumes:
  dev-paseo-home:
```

```bash
# Start the container
export PASEO_PASSWORD="your-strong-password"
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
| `PASEO_HOME` | `/home/dev/.paseo` | Paseo data directory |
| `PASEO_LISTEN` | `0.0.0.0:6767` | Listen address and port |
| `PASEO_WEB_UI_ENABLED` | `true` | Enable/disable the web UI |
| `PASEO_LOG_LEVEL` | `info` | Log level (trace/debug/info/warn/error) |
| `PASEO_LOG_FORMAT` | `json` | Log format (json/text) |
| `PASEO_PASSWORD` | _(unset)_ | Authentication password for the Paseo web UI |

If `PASEO_PASSWORD` is not set, the daemon starts without authentication and
logs a warning. Always set `PASEO_PASSWORD` for network-reachable deployments.

## Data Persistence

Mount `/home/dev` as a volume to persist Paseo data (agent registries, workspaces,
schedules, and configuration) across container restarts:

```bash
docker run -d \
  --name dev-paseo \
  -p 6767:6767 \
  -v dev-paseo-home:/home/dev \
  -e PASEO_PASSWORD="your-strong-password" \
  ghcr.io/meixg/docker-images/dev-paseo:latest
```

## Security Considerations

- **Authentication**: Set `PASEO_PASSWORD` for any published port or
  network-reachable deployment. Without it, the daemon accepts unauthenticated
  control connections from any client that can reach it.
- **No SSH**: Unlike `dev-base`, this image does not start an SSH server.
  Paseo's own TLS+authentication layer is the primary access control.
- **Non-root**: The Paseo daemon runs as the `dev` user (UID 1000).
- **Init Process**: `tini` is used as PID 1 for proper signal forwarding and
  zombie process reaping.

## Local Development

```bash
# Build locally
cd dev-paseo
docker build -t dev-paseo .

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

The container runs as the `dev` user (UID 1000). The `tini` init process and the
Paseo server both execute under this user.
