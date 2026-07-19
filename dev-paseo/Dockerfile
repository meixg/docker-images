FROM ghcr.io/meixg/docker-images/dev-base:latest

ENV HOME=/home/dev \
    PASEO_HOME=/home/dev/.paseo \
    PASEO_LISTEN=0.0.0.0:6767 \
    PASEO_WEB_UI_ENABLED=true \
    PASEO_LOG_FORMAT=json \
    PASEO_LOG_LEVEL=info \
    CLAUDE_CONFIG_DIR=/home/dev/.claude \
    CODEX_HOME=/home/dev/.codex \
    XDG_CONFIG_HOME=/home/dev/.config \
    XDG_DATA_HOME=/home/dev/.local/share \
    XDG_STATE_HOME=/home/dev/.local/state \
    XDG_CACHE_HOME=/home/dev/.cache

RUN apt-get update && apt-get install -y --no-install-recommends tini \
    && rm -rf /var/lib/apt/lists/*

ENV ONNXRUNTIME_NODE_INSTALL=skip
RUN npm install -g @getpaseo/cli @getpaseo/server && \
    server_entry="$(npm root -g)/@getpaseo/server/dist/scripts/supervisor-entrypoint.js" && \
    test -f "$server_entry" && \
    printf '%s\n' "$server_entry" > /etc/paseo-server-entry && \
    node --check "$server_entry" && \
    npm cache clean --force

RUN mkdir -p \
    /home/dev/.paseo \
    /home/dev/.claude \
    /home/dev/.codex \
    /home/dev/.config \
    /home/dev/.local/share \
    /home/dev/.local/state \
    /home/dev/.cache && \
    chown -R dev:dev /home/dev

COPY entrypoint.sh /usr/local/bin/dev-paseo-entrypoint
RUN chmod +x /usr/local/bin/dev-paseo-entrypoint

USER dev
EXPOSE 6767
VOLUME ["/home/dev"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "const listen=process.env.PASEO_LISTEN||'0.0.0.0:6767'; const m=listen.match(/:(\\d+)$/); const port=m?Number(m[1]):6767; require('http').get({hostname:'127.0.0.1',port,path:'/api/health'},r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/dev-paseo-entrypoint"]
