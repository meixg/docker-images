# Docker Images Repository

这个仓库包含多个 Docker 镜像，通过 GitHub Actions 自动构建并发布到 GitHub Container Registry。

## 仓库结构

```
.
├── .github/
│   └── workflows/
│       └── build-images.yml    # GitHub Actions 工作流
├── dev-base/                    # 开发基础镜像
│   ├── Dockerfile
│   ├── compose.yaml
│   ├── entrypoint.sh
│   ├── .zshrc
│   └── README.md                # 详细文档
├── dev-paseo/                   # Paseo 守护进程镜像
│   ├── Dockerfile
│   ├── entrypoint.sh
│   └── README.md                # 详细文档
├── CLAUDE.md                    # Claude Code 使用指南
└── README.md
```

## 可用镜像

### [dev-base](dev-base/)

基于 Ubuntu 24.04 LTS 的开发环境镜像，包含 SSH 访问和常用开发工具。

**主要特性**：
- OpenSSH 服务器（仅支持公钥认证）
- 开发工具：git, vim, tmux, curl, wget, build-essential
- 最新官方 Node.js 二进制（GPG 验证清单 + SHA256 校验）+ 全局安装的 pnpm
- Zsh with Oh My Zsh
- Claude Code CLI
- OpenCode CLI

**快速开始**：
```bash
# 拉取镜像
docker pull ghcr.io/meixg/docker-images/dev-base:latest

# 使用 SSH 公钥运行容器
# 容器名称可选，方便后续管理（如 docker stop dev-base）
export TAILSCALE_IP="$(tailscale ip -4)"
docker run -d -p "${TAILSCALE_IP}:2222:22" \
  --name dev-base \
  -e SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)" \
  ghcr.io/meixg/docker-images/dev-base:latest

# 通过 Tailscale MagicDNS hostname 连接到容器
ssh -p 2222 dev@<desktop-magicdns-hostname>
```

📖 **查看 [dev-base/README.md](dev-base/) 获取完整文档和安全配置说明**

### [dev-paseo](dev-paseo/)

基于 `dev-base` 的 Paseo 守护进程镜像，提供开箱即用的 Paseo 服务器。

**主要特性**：
- 继承 dev-base 的所有开发工具（git, vim, tmux, Node.js, pnpm, Claude Code, OpenCode）
- 预装 Paseo CLI 和 Server（从 npm 安装）
- Paseo Web UI（默认端口 6767）
- 无 SSH，只运行 Paseo 守护进程
- 以 `dev` 用户运行，`tini` 作为 init 进程

**快速开始**：
```bash
# 拉取镜像
docker pull ghcr.io/meixg/docker-images/dev-paseo:latest

# 运行 Paseo 容器
docker run -d \
  --name dev-paseo \
  -p 6767:6767 \
  -v dev-paseo-home:/home/dev \
  -e PASEO_PASSWORD="your-strong-password" \
  ghcr.io/meixg/docker-images/dev-paseo:latest

# 访问 Web UI
# 打开浏览器访问 http://localhost:6767
```

📖 **查看 [dev-paseo/README.md](dev-paseo/) 获取完整文档和配置说明**

### 宿主机隔离初始化

在首次启动安全隔离版本前，先启用 Docker user namespace remapping，再安装
仅针对 `devbase0` 的家庭网络出站限制：

```bash
cd dev-base
sudo ./host-userns-remap.sh apply
sudo ./host-firewall.sh apply

export TAILSCALE_IP="$(tailscale ip -4)"
export SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)"
docker compose up -d
```

查看或撤销对应设置：

```bash
sudo ./host-userns-remap.sh status
sudo ./host-userns-remap.sh remove
sudo ./host-firewall.sh status
sudo ./host-firewall.sh remove
```

`host-userns-remap.sh` 会重启 Docker，应在重要容器启动前执行。两个脚本的
验证、备份、回滚、兼容性和安全影响详见 [dev-base 文档](dev-base/README.md#host-isolation-scripts)。

## 添加新镜像

基础镜像（如 `dev-base`）应添加到 `build-images.yml` 的 `matrix.image` 数组中。
派生镜像（继承现有镜像的）建议添加独立 job，依赖基础镜像的构建完成。

具体步骤：
1. 创建新文件夹（例如 `my-service/`）
2. 在文件夹中创建 `Dockerfile`、`entrypoint.sh` 和 `README.md`
3. 在 `.github/workflows/build-images.yml` 中添加对应的构建 job
4. 提交并推送，GitHub Actions 会自动构建并推送镜像

**重要**：新镜像需要遵循 [安全策略](CLAUDE.md#security-policy)，确保适合公开发布。

## 本地构建

```bash
# 构建 dev-base
cd dev-base
docker build -t dev-base .

# 构建 dev-paseo（依赖 dev-base:latest）
cd dev-paseo
docker build -t dev-paseo .
```

## 构建触发与例行重建

- 推送到 `main` 时，只要任何镜像目录下的文件（包括 `Dockerfile`、`entrypoint.sh`、`.zshrc`）或 `.github/workflows/build-images.yml` 发生变化，就会自动构建并发布镜像。
- 工作流保留 `workflow_dispatch` 手动触发；手动执行时可选择 `clean_rebuild` 来强制干净重建。
- 工作流还会在 **每周一 UTC 03:00** 定时执行一次例行重建。
- 普通 push / 默认手动构建继续使用 GitHub Actions BuildKit 缓存，以保持日常构建效率。
- 定时构建和启用了 `clean_rebuild` 的手动构建会启用 `pull: true` 与 `no-cache: true`，确保构建环境中存在仓库固定的基础镜像摘要并重新执行所有构建层，以获取仓库中已声明版本的最新安全补丁。

## 镜像标签

- `latest` - 最新的 main 分支构建
- `main` - main 分支的最新构建
- `<sha>` - 特定 commit 的构建

所有镜像支持 **AMD64** 和 **ARM64** 架构（多架构构建）。

## 许可证

MIT
