FROM ubuntu:22.04

# 1. 安装基础开发工具
RUN apt-get update && apt-get install -y \
    openssh-server sudo curl git vim wget build-essential zsh \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. 创建开发用户
RUN useradd -m -s /bin/bash dev && \
    usermod -aG sudo dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 3. 安装 oh-my-zsh
RUN export ZSH="/home/dev/.oh-my-zsh" && \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    chsh -s /bin/zsh dev && \
    chown -R dev:dev /home/dev/.oh-my-zsh

# 4. 复制配置文件
COPY .zshrc /home/dev/.zshrc
RUN chown dev:dev /home/dev/.zshrc

# 5. 安装 Node.js 和 pnpm
USER dev
RUN curl -fsSL https://raw.githubusercontent.com/mklement0/n-install/stable/bin/n-install | bash -s -- -y 24 && \
    export PATH="$HOME/n/bin:$PATH" && \
    node -v && \
    corepack enable pnpm && \
    pnpm -v
USER root

# 6. 安装 Claude Code
USER dev
RUN export PATH="$HOME/n/bin:$PATH" && \
    npm install -g @anthropic-ai/claude-code && \
    claude --version
USER root

# 7. 配置 SSH
RUN mkdir -p /home/dev/.ssh && \
    chown -R dev:dev /home/dev/.ssh && \
    chmod 700 /home/dev/.ssh

# 8. 复制启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
