#!/bin/bash
set -e

# 初始化 bind-mounted home，但不覆盖已有用户配置。
chown work:work /home/work
install -d -o work -g work -m 700 /home/work/.ssh
if [ ! -e /home/work/.zshrc ]; then
    install -o work -g work -m 644 /etc/skel/.zshrc /home/work/.zshrc
fi

# 配置 SSH 公钥
if [ -n "$SSH_PUB_KEY" ]; then
    echo "$SSH_PUB_KEY" > /home/work/.ssh/authorized_keys
    chown work:work /home/work/.ssh/authorized_keys
    chmod 600 /home/work/.ssh/authorized_keys
    echo "SSH public key configured"
fi

# Host keys identify a running SSH server and must be unique per container,
# rather than shared by every container built from the image.
echo "Generating missing SSH host keys..."
ssh-keygen -A

# 启动 SSH 服务
echo "Validating SSH configuration..."
/usr/sbin/sshd -t
echo "Starting SSH server..."
exec /usr/sbin/sshd -D
