ARG DEV_BASE_IMAGE=ghcr.io/meixg/docker-images/dev-base:latest
FROM ${DEV_BASE_IMAGE}

# Paseo uses env.SHELL when a terminal request does not include command/args.
ENV USER=work \
    LOGNAME=work \
    HOME=/home/work \
    SHELL=/bin/zsh \
    PASEO_HOME=/home/work/.paseo \
    PASEO_LISTEN=0.0.0.0:6767 \
    PASEO_WEB_UI_ENABLED=true \
    PASEO_LOG_FORMAT=json \
    PASEO_LOG_LEVEL=info \
    CODEX_HOME=/home/work/.codex \
    DSH_HOME=/home/work/.dsh \
    XDG_CONFIG_HOME=/home/work/.config \
    XDG_DATA_HOME=/home/work/.local/share \
    XDG_STATE_HOME=/home/work/.local/state \
    XDG_CACHE_HOME=/home/work/.cache

RUN apt-get update && apt-get install -y --no-install-recommends tini \
    && rm -rf /var/lib/apt/lists/*

ENV ONNXRUNTIME_NODE_INSTALL=skip
RUN npm install -g @getpaseo/cli @getpaseo/server && \
    server_entry="$(npm root -g)/@getpaseo/server/dist/scripts/supervisor-entrypoint.js" && \
    test -f "$server_entry" && \
    printf '%s\n' "$server_entry" > /etc/paseo-server-entry && \
    node --check "$server_entry" && \
    npm cache clean --force

# DeepSeek Harness CLI (`dsh`). Paseo drives it through its ACP profile.
RUN npm install -g @deepseek-ai/dsh && \
    dsh --version && \
    npm cache clean --force

RUN mkdir -p \
    /home/work/.paseo \
    /home/work/.codex \
    /home/work/.dsh \
    /home/work/.pi/agent \
    /home/work/.config \
    /home/work/.local/share \
    /home/work/.local/state \
    /home/work/.cache && \
    chown -R work:work /home/work

COPY entrypoint.sh /usr/local/bin/dev-paseo-entrypoint
RUN chmod +x /usr/local/bin/dev-paseo-entrypoint

# DSH credential store template. The runtime entrypoint copies it into a
# bind-mounted home when no credentials file exists yet.
COPY dsh-credentials.yaml /usr/local/share/dev-paseo/dsh-credentials.yaml
RUN chmod 644 /usr/local/share/dev-paseo/dsh-credentials.yaml && \
    install -o work -g work -m 600 \
      /usr/local/share/dev-paseo/dsh-credentials.yaml \
      /home/work/.dsh/.credentials.yaml

USER work
WORKDIR /home/work

# Prewarm the ACP profile so Paseo's provider probe does not pay for first-run
# profile initialization (and time out).
RUN dsh --profile acp --help

EXPOSE 6767
VOLUME ["/home/work"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "const listen=process.env.PASEO_LISTEN||'0.0.0.0:6767'; const m=listen.match(/:(\\d+)$/); const port=m?Number(m[1]):6767; require('http').get({hostname:'127.0.0.1',port,path:'/api/health'},r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/dev-paseo-entrypoint"]
