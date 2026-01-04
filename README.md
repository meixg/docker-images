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
│   └── entrypoint.sh
└── README.md
```

## 可用镜像

### dev-base

基于 Ubuntu 22.04 的开发环境镜像，包含：
- OpenSSH 服务器
- 常用开发工具 (git, vim, curl, wget, build-essential)
- 预配置的 `dev` 用户（支持 sudo）

#### 使用方法

```bash
# 拉取镜像
docker pull ghcr.io/<your-username>/dockers/dev-base:latest

# 使用 SSH 公钥运行容器
docker run -d -p 2222:22 \
  -e SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)" \
  ghcr.io/<your-username>/dockers/dev-base:latest

# 连接到容器
ssh -p 2222 dev@localhost
```

## 添加新镜像

1. 创建新文件夹（例如 `my-service/`）
2. 在文件夹中创建 `Dockerfile`
3. 在 `.github/workflows/build-images.yml` 的 `matrix.image` 数组中添加新镜像名称
4. 提交并推送，GitHub Actions 会自动构建并推送镜像

## 本地构建

```bash
# 构建特定镜像
cd dev-base
docker build -t dev-base .

# 本地测试
docker run -d -p 2222:22 \
  -e SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)" \
  dev-base
```

## 镜像标签

- `latest` - 最新的 main 分支构建
- `main` - main 分支的最新构建
- `<sha>` - 特定 commit 的构建

## 许可证

MIT
