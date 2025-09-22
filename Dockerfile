# Keep it simple & small; pin if you want (e.g., :v2.5.4)
FROM netdata/netdata:stable

# Optional: healthier checks in containers
ENV NETDATA_HEALTHCHECK_TARGET=cli

# Copy a tiny entrypoint that renders netdata.conf using $PORT
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Template with our configurable port/bind address
COPY netdata.conf.tmpl /etc/netdata/netdata.conf.tmpl

# Netdata’s default web port is 19999; Railway may set $PORT dynamically
EXPOSE 19999

CMD ["/entrypoint.sh"]
