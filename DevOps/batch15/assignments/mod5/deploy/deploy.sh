#!/usr/bin/env bash
# ShopNest server-side deploy tool. Installed at /opt/shopnest/bin/deploy.sh. Run as root.
#
#   deploy.sh deploy   <env> <sha>   # extract /tmp/release-<sha>.tgz, blue/green switch (env vars on stdin)
#   deploy.sh rollback <env> <sha>   # re-activate an existing release
#   deploy.sh current  <env>         # print active sha (or "none")
#   deploy.sh history  <env>         # list releases on disk
set -euo pipefail

CMD="${1:?command}"; ENVN="${2:?env}"; SHA="${3:-}"
case "$ENVN" in
  production) PORTS=(3001 3002); NGINX_PORT=80 ;;
  staging)    PORTS=(3101 3102); NGINX_PORT=8080 ;;
  *) echo "unknown env $ENVN" >&2; exit 2 ;;
esac

BASE="/opt/shopnest/$ENVN"
CONF="/etc/shopnest/$ENVN"
LOG="/var/log/shopnest/deploy-$ENVN.log"
mkdir -p "$BASE/releases" "$BASE/slots" "$CONF" /var/log/shopnest
touch "$LOG"

log() { echo "$(date -u +%FT%TZ) [$ENVN] $*" | tee -a "$LOG" >&2; }

active_port() { cat "$BASE/active_port" 2>/dev/null || echo ""; }
current_sha() { [ -L "$BASE/current" ] && basename "$(readlink "$BASE/current")" || echo none; }

wait_healthy() { # port sha
  local port=$1 sha=$2
  for _ in $(seq 1 30); do
    body=$(curl -fsS --max-time 2 "http://127.0.0.1:$port/health" 2>/dev/null || true)
    if echo "$body" | grep -q '"status":"ok"' && echo "$body" | grep -q "\"version\":\"$sha\""; then
      return 0
    fi
    sleep 1
  done
  return 1
}

point_nginx() { # port
  echo "server 127.0.0.1:$1;" > "$CONF/upstream.inc.tmp"
  mv -f "$CONF/upstream.inc.tmp" "$CONF/upstream.inc"
  nginx -t >/dev/null 2>&1
  nginx -s reload   # graceful: in-flight requests finish on old workers
}

activate() { # sha
  local sha=$1 rel="$BASE/releases/$1"
  [ -d "$rel" ] || { log "release $sha not found"; return 1; }

  local old_port new_port old_sha
  old_port=$(active_port); old_sha=$(current_sha)
  if [ "${PORTS[0]}" = "$old_port" ]; then new_port=${PORTS[1]}; else new_port=${PORTS[0]}; fi

  log "activating $sha on port $new_port (old: ${old_sha} on ${old_port:-none})"
  ln -sfn "$rel/backend" "$BASE/slots/$new_port"
  systemctl restart "shopnest@$ENVN-$new_port"

  if ! wait_healthy "$new_port" "$sha"; then
    log "FAILED: $sha did not become healthy on $new_port; keeping ${old_sha}"
    journalctl -u "shopnest@$ENVN-$new_port" -n 20 --no-pager | sed "s/^/    /" | tee -a "$LOG" >&2 || true
    systemctl stop "shopnest@$ENVN-$new_port" || true
    return 1
  fi

  point_nginx "$new_port"
  ln -sfn "$rel" "$BASE/current.tmp" && mv -T "$BASE/current.tmp" "$BASE/current"
  echo "$new_port" > "$BASE/active_port"

  # verify through nginx on the real serving path; revert if broken
  sleep 1
  if ! curl -fsS --max-time 3 "http://127.0.0.1:$NGINX_PORT/health" | grep -q "\"version\":\"$sha\""; then
    log "FAILED: post-switch verification via nginx; reverting to ${old_sha}"
    if [ -n "$old_port" ]; then
      point_nginx "$old_port"; echo "$old_port" > "$BASE/active_port"
      [ "$old_sha" != none ] && ln -sfn "$BASE/releases/$old_sha" "$BASE/current.tmp" && mv -T "$BASE/current.tmp" "$BASE/current"
    fi
    systemctl stop "shopnest@$ENVN-$new_port" || true
    return 1
  fi

  # drain then stop old instance
  if [ -n "$old_port" ]; then sleep 5; systemctl stop "shopnest@$ENVN-$old_port" || true; fi
  echo "$sha" >> "$BASE/history"
  log "SUCCESS: $sha is live (previous: ${old_sha})"
}

case "$CMD" in
  current) current_sha ;;
  history)
    log "releases on disk:"; ls -1t "$BASE/releases" || true
    echo "live: $(current_sha)"; echo "deploy order:"; tail -n 10 "$BASE/history" 2>/dev/null || true ;;
  deploy)
    [ -n "$SHA" ] || { echo "sha required" >&2; exit 2; }
    TGZ="/tmp/release-$SHA.tgz"; [ -f "$TGZ" ] || { log "missing $TGZ"; exit 1; }
    log "deploy start sha=$SHA"
    if [ ! -t 0 ]; then
      umask 077; cat > "$CONF/backend.env.new"
      if [ -s "$CONF/backend.env.new" ]; then
        chown root:shopnest "$CONF/backend.env.new"; chmod 640 "$CONF/backend.env.new"
        mv -f "$CONF/backend.env.new" "$CONF/backend.env"
      fi
    fi
    rm -rf "$BASE/releases/$SHA"; mkdir -p "$BASE/releases/$SHA"
    tar -xzf "$TGZ" -C "$BASE/releases/$SHA"; rm -f "$TGZ"
    (cd "$BASE/releases/$SHA/backend" && npm ci --omit=dev --no-audit --no-fund >>"$LOG" 2>&1)
    activate "$SHA"
    # keep the 5 most recent releases (never delete the live one)
    ls -1t "$BASE/releases" | tail -n +6 | while read -r r; do
      [ "$r" != "$(current_sha)" ] && rm -rf "$BASE/releases/$r"
    done ;;
  rollback)
    [ -n "$SHA" ] || { echo "sha required" >&2; exit 2; }
    log "rollback requested to $SHA"
    activate "$SHA" ;;
  *) echo "usage: $0 deploy|rollback|current|history <env> [sha]" >&2; exit 2 ;;
esac
