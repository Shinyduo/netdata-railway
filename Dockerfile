# Pin if you like (e.g., netdata/netdata:v2.0.0)
FROM netdata/netdata:stable

# Helpful in containers
ENV NETDATA_HEALTHCHECK_TARGET=cli

# Copy in entrypoint and config template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY netdata.conf.tmpl /etc/netdata/netdata.conf.tmpl

# Default Netdata port (Railway will still inject $PORT)
EXPOSE 19999

# Simple liveness probe against the local API
HEALTHCHECK --interval=30s --timeout=5s --retries=5 \
  CMD sh -c 'PORT="${PORT:-19999}"; wget -qO- "http://127.0.0.1:${PORT}/api/v1/info" >/dev/null || exit 1'

CMD ["/entrypoint.sh"]
