#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-19999}"
STORAGE_ROOT="/netdata-storage"

log() { printf '[netdata-entrypoint] %s\n' "$*"; }

# idempotent linking helper: link $2 -> $1 (target -> linkpath)
link_dir() {
  local target="$1" linkpath="$2"
  mkdir -p "$target"
  if [ -L "$linkpath" ]; then
    : # already a symlink
  elif [ -d "$linkpath" ] && [ ! -L "$linkpath" ]; then
    # If original dir has content and target is empty, move it to storage once
    if [ -z "$(ls -A "$target")" ] && [ -n "$(ls -A "$linkpath")" ]; then
      log "Migrating existing data from $linkpath -> $target"
      cp -a "$linkpath/." "$target/"
    fi
    rm -rf "$linkpath"
    ln -s "$target" "$linkpath"
  else
    # missing path, just symlink
    rm -rf "$linkpath" || true
    ln -s "$target" "$linkpath"
  fi
}

# If a persistent volume is mounted at /netdata-storage, wire it up
if [ -d "$STORAGE_ROOT" ]; then
  log "Persistent storage detected at $STORAGE_ROOT"
  # Create structured subdirs
  mkdir -p "$STORAGE_ROOT/etc" "$STORAGE_ROOT/lib" "$STORAGE_ROOT/cache"
  # Link Netdata paths -> storage
  link_dir "$STORAGE_ROOT/etc"   "/etc/netdata"
  link_dir "$STORAGE_ROOT/lib"   "/var/lib/netdata"
  link_dir "$STORAGE_ROOT/cache" "/var/cache/netdata"
else
  log "No persistent storage mounted at $STORAGE_ROOT (running stateless)"
fi

# Render netdata.conf from template (bind to $PORT)
if [ -f /etc/netdata/netdata.conf.tmpl ]; then
  if command -v envsubst >/dev/null 2>&1; then
    export PORT
    envsubst < /etc/netdata/netdata.conf.tmpl > /etc/netdata/netdata.conf
  else
    sed "s/\${PORT}/${PORT}/g" /etc/netdata/netdata.conf.tmpl > /etc/netdata/netdata.conf
  fi
fi

# Optional: allow disabling local UI if you only use Netdata Cloud
# export NETDATA_WEB_MODE=none to disable local web
if [ "${NETDATA_WEB_MODE:-}" = "none" ]; then
  # Append a small override if not already present
  if ! grep -q 'web mode' /etc/netdata/netdata.conf 2>/dev/null; then
    printf "\n[web]\n  web mode = none\n" >> /etc/netdata/netdata.conf
  else
    # Replace existing setting
    sed -i 's/^\s*web mode\s*=.*/  web mode = none/' /etc/netdata/netdata.conf || true
  fi
  log "Local web UI disabled (NETDATA_WEB_MODE=none)"
fi

# (Optional) Claim to Netdata Cloud if env vars are provided
# Uses claim script only if present in the image
if [ -n "${NETDATA_CLAIM_TOKEN:-}" ]; then
  CLAIM_URL="${NETDATA_CLAIM_URL:-https://app.netdata.cloud}"
  if command -v netdata-claim.sh >/dev/null 2>&1; then
    log "Attempting Cloud claim..."
    if [ -n "${NETDATA_CLAIM_ROOMS:-}" ]; then
      netdata-claim.sh -token "$NETDATA_CLAIM_TOKEN" -rooms "$NETDATA_CLAIM_ROOMS" -url "$CLAIM_URL" || true
    else
      netdata-claim.sh -token "$NETDATA_CLAIM_TOKEN" -url "$CLAIM_URL" || true
    fi
  else
    log "netdata-claim.sh not found in image; skipping explicit claim (agent may auto-claim if supported)"
  fi
fi

log "Starting Netdata on port ${PORT}"
exec /usr/sbin/netdata -D
