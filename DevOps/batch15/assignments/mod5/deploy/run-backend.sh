#!/usr/bin/env bash
# Started by systemd: run-backend.sh <env>-<port>
set -euo pipefail
INST="$1"; ENVN="${INST%-*}"; PORT="${INST##*-}"
set -a; . "/etc/shopnest/$ENVN/backend.env"; set +a
export PORT
cd "/opt/shopnest/$ENVN/slots/$PORT"
exec /usr/bin/node src/server.js
