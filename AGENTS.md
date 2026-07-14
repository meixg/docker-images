# AGENTS.md

This file provides guidance to AI coding assistants when working with code in this repository.

## Project Overview

This is a Docker images repository that builds and maintains custom development environment images. Images are automatically built and published to GitHub Container Registry (ghcr.io) via GitHub Actions when Dockerfiles change or code is pushed to main.

## Security Policy

**All images in this repository are designed to be publicly accessible.**

When modifying or adding new images, always consider that the images may be publicly available to anyone. Follow these security guidelines:

### Mandatory Security Checks for All Images

Before committing any changes, ensure:

1. **No sensitive information** in Dockerfiles, configs, or entrypoint scripts:
   - No API keys, tokens, or passwords
   - No private SSH keys or certificates
   - No personal information (email, phone, etc.)
   - No internal URLs or endpoints

2. **SSH configuration** (if applicable):
   - Password authentication MUST be disabled: `PasswordAuthentication no`
   - Root login SHOULD be disabled: `PermitRootLogin no`
   - Consider limiting users: `AllowUsers <username>`
   - Set reasonable auth limits: `MaxAuthTries 3`

3. **User privileges**:
   - Avoid running containers as root when possible
   - If NOPASSWD sudo is used, document the justification
   - Consider whether the privilege level is appropriate for public use

4. **Package installation**:
   - Pin specific versions where possible
   - Verify package sources are trusted
   - Avoid `curl | bash` patterns without integrity checks
   - Keep dependencies minimal

5. **Exposed ports**:
   - Only expose necessary ports
   - Document what each port does
   - Consider firewall rules in documentation

### Publicly Acceptable Operational Metadata

Generic security and networking configuration may be committed publicly when it
does not identify a real person, device, tailnet, or household network. Security
controls must not depend on this configuration remaining secret.

Acceptable examples include:
- Generic product and component names such as Docker, UFW, Tailscale, and `ufw-docker`
- Repository-defined local interface or network names such as `devbase0`
- Standard reserved ranges such as RFC1918, link-local, multicast, and Tailscale CGNAT ranges
- Placeholder hostnames, addresses, usernames, and public-key values
- General firewall design, isolation behavior, and documented threat-model assumptions

Do not commit:
- Real Tailscale IPs, MagicDNS hostnames, tailnet names, device names, or Tailscale policy identities
- Real household public IPs, LAN host addresses, router/NAS addresses, or network topology details
- Actual SSH keys, including identifying public keys, or any authentication material
- Personal usernames, email addresses, home-directory paths, or other identifying data
- `.env` files or runtime output from commands such as `tailscale status`, `ip route`, or `docker inspect`

### Image Modification Checklist

Use this checklist before pushing changes:

- [ ] Reviewed all files for hardcoded secrets
- [ ] SSH is configured with key-based auth only (if SSH enabled)
- [ ] User privileges are appropriate for public use
- [ ] No unnecessary services or packages installed
- [ ] All configuration files are generic (no personal settings)
- [ ] Scripts and documentation contain placeholders rather than real device, tailnet, or household-network identifiers
- [ ] Documentation is updated with any new security considerations

## Repository Structure

Each Docker image has its own directory containing:
- `Dockerfile` - Image definition
- `entrypoint.sh` - Container startup script (optional)
- Configuration files (e.g., `.zshrc`)

The GitHub Actions workflow (`.github/workflows/build-images.yml`) uses a matrix strategy to build all images defined in `matrix.image`.

## Adding or Modifying Images

### To add a new image:

1. Create a new directory (e.g., `my-service/`)
2. Add a `Dockerfile` in that directory
3. Edit `.github/workflows/build-images.yml` and add the directory name to the `matrix.image` array:
   ```yaml
   strategy:
     matrix:
       image: [dev-base, my-service]
   ```
4. Commit and push - GitHub Actions will automatically build and push the image

### To modify an existing image:

Edit the Dockerfile or associated files in the image's directory. Changes will trigger automatic rebuild on push to main.

## Local Development

```bash
# Build a specific image locally
cd <image-directory>
docker build -t <image-name> .

# Run with SSH access (for dev-base)
docker run -d -p 2222:22 -e SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)" dev-base

# Connect to the container
ssh -p 2222 dev@localhost
```

## Image Tags

Images are automatically tagged with:
- `latest` - Latest main branch build
- `main` - Main branch build
- `<sha>` - Specific commit SHA

## Current Images

See individual image directories for detailed documentation:
- **[dev-base/](dev-base/)** - Ubuntu 24.04 LTS development environment with SSH access

## CI/CD Pipeline

The GitHub Actions workflow:
- Triggers on push to main or manual workflow_dispatch
- Only runs when Dockerfiles or the workflow file change
- Uses Docker Buildx with GitHub Actions cache for faster builds
- Automatically generates tags and metadata via docker/metadata-action
- Pushes to `ghcr.io/${github.repository}/${image}`
