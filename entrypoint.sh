#!/usr/bin/env bash
set -euo pipefail

# Railway usually provides $PORT. If not, fall back to 19999.
PORT="${PORT:-19999}"

# Render /etc/netdata/netdata.conf from template (simple envsubst)
if command -v envsubst >/dev/null 2>&1; then
  export PORT
  envsubst < /etc/netdata/netdata.conf.tmpl > /etc/netdata/netdata.conf
else
  # Busybox/sh fallback
  sed "s/\${PORT}/${PORT}/g" /etc/netdata/netdata.conf.tmpl > /etc/netdata/netdata.conf
fi

exec /usr/sbin/netdata -D
