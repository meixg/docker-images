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
│   ├── entrypoint.sh
│   ├── .zshrc
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
- Node.js 24.4.1（官方二进制 + GPG 校验）+ pnpm
- Zsh with Oh My Zsh
- Claude Code CLI
- OpenCode CLI

**快速开始**：
```bash
# 拉取镜像
docker pull ghcr.io/meixg/docker-images/dev-base:latest

# 使用 SSH 公钥运行容器
# 容器名称可选，方便后续管理（如 docker stop dev-base）
docker run -d -p 2222:22 \
  --name dev-base \
  -e SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)" \
  ghcr.io/meixg/docker-images/dev-base:latest

# 连接到容器
ssh -p 2222 dev@localhost
```

📖 **查看 [dev-base/README.md](dev-base/) 获取完整文档和安全配置说明**

## 添加新镜像

1. 创建新文件夹（例如 `my-service/`）
2. 在文件夹中创建 `Dockerfile` 和 `README.md`
3. 在 `.github/workflows/build-images.yml` 的 `matrix.image` 数组中添加新镜像名称
4. 提交并推送，GitHub Actions 会自动构建并推送镜像

**重要**：新镜像需要遵循 [安全策略](CLAUDE.md#security-policy)，确保适合公开发布。

## 本地构建

```bash
# 构建特定镜像
cd dev-base
docker build -t dev-base .

# 本地测试
docker run -d -p 2222:22 -e SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)" dev-base
```

## 构建触发与例行重建

- 推送到 `main` 时，只要 `dev-base/` 下的文件（包括 `Dockerfile`、`entrypoint.sh`、`.zshrc`）或 `.github/workflows/build-images.yml` 发生变化，就会自动构建并发布镜像。
- 工作流保留 `workflow_dispatch` 手动触发；手动执行时可选择 `clean_rebuild` 来强制干净重建。
- 工作流还会在 **每周一 UTC 03:00** 定时执行一次例行重建。
- 普通 push / 默认手动构建继续使用 GitHub Actions BuildKit 缓存，以保持日常构建效率。
- 定时构建和启用了 `clean_rebuild` 的手动构建会启用 `pull: true` 与 `no-cache: true`，重新拉取已固定的基础镜像摘要并重新执行 APT / npm 等依赖安装层，以获取仓库中已声明版本的最新安全补丁。

## 镜像标签

- `latest` - 最新的 main 分支构建
- `main` - main 分支的最新构建
- `<sha>` - 特定 commit 的构建

所有镜像支持 **AMD64** 和 **ARM64** 架构（多架构构建）。

## 许可证

MIT
