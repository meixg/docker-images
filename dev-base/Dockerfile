FROM ubuntu:22.04

ARG OH_MY_ZSH_COMMIT=677a4592b18c08ddea737f8aca70bac0e9fc9313

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

# 5. 安装最新版 Node.js 和 pnpm（官方二进制 + SHA256 校验）
ENV PATH="/home/dev/n/bin:${PATH}"
USER dev
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
        amd64) NODE_ARCH="x64" ;; \
        arm64) NODE_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; \
    esac; \
    TMP_DIR="$(mktemp -d)"; \
    NODE_BASE_URL="https://nodejs.org/dist/latest"; \
    curl -fsSL "${NODE_BASE_URL}/SHASUMS256.txt" -o "${TMP_DIR}/SHASUMS256.txt"; \
    NODE_TARBALL="$(awk -v arch="${NODE_ARCH}" '$2 ~ ("^node-v[0-9.]+-linux-" arch "\\.tar\\.xz$") { print $2 }' "${TMP_DIR}/SHASUMS256.txt")"; \
    test -n "${NODE_TARBALL}"; \
    NODE_SHA256="$(awk -v file="${NODE_TARBALL}" '$2 == file { print $1 }' "${TMP_DIR}/SHASUMS256.txt")"; \
    test -n "${NODE_SHA256}"; \
    curl -fsSL "${NODE_BASE_URL}/${NODE_TARBALL}" -o "${TMP_DIR}/${NODE_TARBALL}"; \
    echo "${NODE_SHA256}  ${TMP_DIR}/${NODE_TARBALL}" | sha256sum -c -; \
    mkdir -p "$HOME/n"; \
    tar -xJf "${TMP_DIR}/${NODE_TARBALL}" -C "$HOME/n" --strip-components=1; \
    rm -rf "${TMP_DIR}"; \
    node -v && \
    npm install -g corepack@latest && \
    corepack enable pnpm && \
    corepack install -g pnpm@latest && \
    pnpm -v
USER root
ENV PATH="/home/dev/n/bin:${PATH}"

# 6. 安装 Claude Code 和 OpenCode
USER dev
RUN npm install -g @anthropic-ai/claude-code opencode-ai && \
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
