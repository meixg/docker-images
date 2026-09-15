# Docker 开发镜像的持久 Home

## 最终状态

`dev-base` 提供固定的非 root 开发用户：

| 项目 | 值 |
|---|---|
| 用户 | `work` |
| UID/GID | `1001:1001` |
| Home | `/home/work` |
| Shell | `/bin/zsh` |

`dev-paseo` 继承该身份并以 `work` 运行 Paseo。Paseo、Codex、GitHub CLI、SSH
和其他遵循 Home/XDG 约定的工具都把状态保存在 `/home/work` 下：

```text
/home/work/
├── .ssh/
├── .config/gh/
├── .codex/
├── .local/
├── .paseo/
└── repositories...
```

Paseo 的路径契约为：

```text
HOME=/home/work
PASEO_HOME=/home/work/.paseo
CODEX_HOME=/home/work/.codex
XDG_CONFIG_HOME=/home/work/.config
XDG_DATA_HOME=/home/work/.local/share
XDG_STATE_HOME=/home/work/.local/state
XDG_CACHE_HOME=/home/work/.cache
```

## 宿主持久化布局

宿主统一在 `~/docker-homes` 下按容器实例保存 `/home/work`：

```text
~/docker-homes/
├── dev-base/
├── dev-paseo/
└── other-instance/
```

Compose 使用 bind mount：

```yaml
volumes:
  - "${DOCKER_HOMES_ROOT}/dev-paseo:/home/work"
```

运行 Compose 前设置 `DOCKER_HOMES_ROOT="$HOME/docker-homes"`。显式传入绝对路径，
可以避免通过 `sudo docker compose` 运行时将 `${HOME}` 错误解析为 `/root`。

目录是完整的用户 Home，可能包含 SSH 私钥、GitHub token 和模型服务凭据，应限制
宿主访问权限并保护备份。使用 Docker user namespace remapping 时，宿主目录必须为
容器内 UID/GID `1001:1001` 对应的映射身份可写。

## 镜像职责

- `dev-base` 创建 `work` 用户、安装 `/opt/oh-my-zsh`，并提供 `/etc/skel/.zshrc`。
- `dev-base` 和 `dev-paseo` 启动时只补充缺失的 `.zshrc` 和 `.ssh`，不覆盖已有用户配置。
- `dev-base` 以 root 启动 sshd，只允许 `work` 使用公钥登录。
- `dev-paseo` 以 `work` 启动 daemon，不启动 SSH。
- `dev-paseo` 将 `/home/work` 声明为 volume，并通过 Compose 绑定宿主持久目录。

## 验收

基础镜像沿用 `dev-base/smoke-test.sh`，验证 UID/GID、Home、工具可用性、SSH
安全配置及 `work` 公钥登录。Paseo 镜像只需验证容器用户、Home/Paseo 路径和健康
接口；持久性通过 Compose 重建后文件仍存在确认。
