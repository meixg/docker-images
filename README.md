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

基于 Ubuntu 22.04 的开发环境镜像，包含 SSH 访问和常用开发工具。

**主要特性**：
- OpenSSH 服务器（仅支持公钥认证）
- 开发工具：git, vim, tmux, curl, wget, build-essential
- Node.js LTS 24.x + pnpm
- Zsh with Oh My Zsh
- Claude Code CLI

**快速开始**：
```bash
# 拉取镜像
docker pull ghcr.io/meixg/dockers/dev-base:latest

# 使用 SSH 公钥运行容器
# 容器名称可选，方便后续管理（如 docker stop dev-base）
docker run -d -p 2222:22 \
  --name dev-base \
  -e SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)" \
  ghcr.io/meixg/dockers/dev-base:latest

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

## 镜像标签

- `latest` - 最新的 main 分支构建
- `main` - main 分支的最新构建
- `<sha>` - 特定 commit 的构建

所有镜像支持 **AMD64** 和 **ARM64** 架构（多架构构建）。

## 许可证

MIT
