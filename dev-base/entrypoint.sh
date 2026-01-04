#!/bin/bash
set -e

# 配置 SSH 公钥
if [ -n "$SSH_PUB_KEY" ]; then
    echo "$SSH_PUB_KEY" > /home/dev/.ssh/authorized_keys
    chown dev:dev /home/dev/.ssh/authorized_keys
    chmod 600 /home/dev/.ssh/authorized_keys
    echo "SSH public key configured"
fi

# 启动 SSH 服务
echo "Starting SSH server..."
exec /usr/sbin/sshd -D
