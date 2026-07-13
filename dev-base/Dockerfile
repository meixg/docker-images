FROM ubuntu:22.04

ARG OH_MY_ZSH_COMMIT=677a4592b18c08ddea737f8aca70bac0e9fc9313
ARG NODE_VERSION=24.5.0
ARG NODE_LINUX_X64_SHA256=32edb1f2aeaf8ea0d484af33bf3b5d8330d7d33c9cd8c70f811b8a643822e613
ARG NODE_LINUX_ARM64_SHA256=313367534186a8551d68b39fbc2a6cc36638e583fb5dc75dcf5da3c6582bff3b

# 1. 安装基础开发工具
RUN apt-get update && apt-get install -y \
    openssh-server sudo curl git vim wget build-essential zsh tmux \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. 创建开发用户
RUN useradd -m -s /bin/bash dev && \
    usermod -aG sudo dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 3. 安装 oh-my-zsh（固定 commit，避免执行远程安装脚本）
# 升级方式：更新 OH_MY_ZSH_COMMIT 到目标 commit，并确认构建通过
RUN git clone https://github.com/ohmyzsh/ohmyzsh.git /home/dev/.oh-my-zsh && \
    cd /home/dev/.oh-my-zsh && \
    git checkout --detach "${OH_MY_ZSH_COMMIT}" && \
    test "$(git rev-parse HEAD)" = "${OH_MY_ZSH_COMMIT}" && \
    rm -rf /home/dev/.oh-my-zsh/.git && \
    chsh -s /bin/zsh dev && \
    chown -R dev:dev /home/dev/.oh-my-zsh

# 4. 复制配置文件
COPY .zshrc /home/dev/.zshrc
RUN chown dev:dev /home/dev/.zshrc

# 5. 安装 Node.js 和 pnpm（官方二进制 + SHA256 校验）
# 升级方式：更新 NODE_VERSION 和对应架构 SHA256（来自 nodejs.org 发布页）
USER dev
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
        amd64) NODE_ARCH="x64"; NODE_SHA256="${NODE_LINUX_X64_SHA256}" ;; \
        arm64) NODE_ARCH="arm64"; NODE_SHA256="${NODE_LINUX_ARM64_SHA256}" ;; \
        *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; \
    esac; \
    NODE_DIST="node-v${NODE_VERSION}-linux-${NODE_ARCH}"; \
    TMP_DIR="$(mktemp -d)"; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_DIST}.tar.xz" -o "${TMP_DIR}/${NODE_DIST}.tar.xz"; \
    echo "${NODE_SHA256}  ${TMP_DIR}/${NODE_DIST}.tar.xz" | sha256sum -c -; \
    mkdir -p "$HOME/n"; \
    tar -xJf "${TMP_DIR}/${NODE_DIST}.tar.xz" -C "$HOME/n" --strip-components=1; \
    rm -rf "${TMP_DIR}"; \
    export PATH="$HOME/n/bin:$PATH" && \
    node -v && \
    corepack enable pnpm && \
    pnpm -v
USER root

# 6. 安装 Claude Code 和 OpenCode
USER dev
RUN export PATH="$HOME/n/bin:$PATH" && \
    npm install -g @anthropic-ai/claude-code opencode-ai && \
    claude --version && \
    opencode --version
USER root

# 7. 配置 SSH 安全加固
RUN mkdir -p /home/dev/.ssh && \
    chown -R dev:dev /home/dev/.ssh && \
    chmod 700 /home/dev/.ssh && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config && \
    echo "AllowUsers dev" >> /etc/ssh/sshd_config && \
    echo "MaxAuthTries 3" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config && \
    echo "X11Forwarding no" >> /etc/ssh/sshd_config && \
    echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config

# 8. 复制启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
