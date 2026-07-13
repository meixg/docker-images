# Refresh this pinned digest periodically to pick up new Ubuntu 24.04 security updates.
FROM ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90
ARG OH_MY_ZSH_COMMIT=677a4592b18c08ddea737f8aca70bac0e9fc9313

# 1. 安装基础开发工具
RUN apt-get update && apt-get install -y \
    ca-certificates openssh-server sudo curl git vim wget build-essential zsh tmux xz-utils \
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
RUN set -eu; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
        amd64) NODE_ARCH="x64" ;; \
        arm64) NODE_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; \
    esac; \
    TMP_DIR="$(mktemp -d)"; \
    export GNUPGHOME="${TMP_DIR}/gnupg"; \
    mkdir -p "${GNUPGHOME}"; \
    chmod 700 "${GNUPGHOME}"; \
    NODE_BASE_URL="https://nodejs.org/dist/latest"; \
    NODE_RELEASE_KEYS_REF='b28073028e6d6855cfb53bf7fa0137599c01f967'; \
    for key in \
        5BE8A3F6C8A5C01D106C0AD820B1A390B168D356 \
        DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 \
        CC68F5A3106FF448322E48ED27F5E38D5B0A215F \
        8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
        890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
        C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
        108F52B48DB57BB0CC439B2997B01419BD92F80A \
        A363A499291CBBC940DD62E41F10027AF002F8B0; do \
        curl -fsSL "https://raw.githubusercontent.com/nodejs/release-keys/${NODE_RELEASE_KEYS_REF}/keys/${key}.asc" -o "${TMP_DIR}/${key}.asc"; \
        gpg --batch --import "${TMP_DIR}/${key}.asc"; \
    done; \
    curl -fsSL "${NODE_BASE_URL}/SHASUMS256.txt.asc" -o "${TMP_DIR}/SHASUMS256.txt.asc"; \
    gpg --batch --decrypt --output "${TMP_DIR}/SHASUMS256.txt" "${TMP_DIR}/SHASUMS256.txt.asc"; \
    NODE_TARBALLS="$(awk -v arch="${NODE_ARCH}" '$2 ~ ("^node-v[0-9.]+-linux-" arch "\\.tar\\.xz$") { print $2 }' "${TMP_DIR}/SHASUMS256.txt")"; \
    test -n "${NODE_TARBALLS}"; \
    test "$(printf '%s\n' "${NODE_TARBALLS}" | wc -l)" -eq 1; \
    NODE_TARBALL="${NODE_TARBALLS}"; \
    NODE_SHA256="$(awk -v file="${NODE_TARBALL}" '$2 == file { print $1 }' "${TMP_DIR}/SHASUMS256.txt")"; \
    test -n "${NODE_SHA256}"; \
    curl -fsSL "${NODE_BASE_URL}/${NODE_TARBALL}" -o "${TMP_DIR}/${NODE_TARBALL}"; \
    echo "${NODE_SHA256}  ${TMP_DIR}/${NODE_TARBALL}" | sha256sum -c -; \
    tar -xJf "${TMP_DIR}/${NODE_TARBALL}" -C /usr/local --strip-components=1 --no-same-owner; \
    gpgconf --kill all; \
    rm -rf "${TMP_DIR}"; \
    node -v && \
    npm -v

# 6. 安装 Claude Code 和 OpenCode
RUN npm install -g pnpm @anthropic-ai/claude-code opencode-ai && \
    pnpm --version && \
    claude --version && \
    opencode --version

# 7. 配置 SSH 安全加固
COPY sshd_config.d/10-hardening.conf /etc/ssh/sshd_config.d/
RUN mkdir -p /home/dev/.ssh && \
    chown -R dev:dev /home/dev/.ssh && \
    chmod 700 /home/dev/.ssh && \
    chmod 644 /etc/ssh/sshd_config.d/10-hardening.conf && \
    sshd -t

# 8. 复制启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
