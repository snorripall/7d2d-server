#!/usr/bin/env bash
# Entrypoint for the 7 Days to Die + Rebirth dedicated server container.
# Runs as root initially, fixes /data ownership, hydrates serverconfig.xml
# from the template, drops to the steam user, and execs the server so signals
# pass through for graceful shutdown.

set -euo pipefail

TEMPLATE_PATH="/server/serverconfig.xml.template"
CONFIG_PATH="/data/config/serverconfig.xml"
SERVER_BINARY="/server/7DaysToDieServer.x86_64"

# Allow --dry-run-config to work when invoked from the repository build host.
if [ ! -f "$TEMPLATE_PATH" ] && [ -f "${PWD}/serverconfig.xml.template" ]; then
    TEMPLATE_PATH="${PWD}/serverconfig.xml.template"
fi

# Hydrate ${VAR:-default} placeholders. envsubst does not understand the
# :-default syntax, so we fall back to a small Python implementation when the
# template uses it; for plain ${VAR} placeholders envsubst is used directly.
hydrate_template() {
    local template="$1"

    if command -v envsubst >/dev/null 2>&1 && ! grep -qE '\$\{[A-Za-z_][A-Za-z0-9_]*:-' "$template"; then
        envsubst < "$template"
        return
    fi

    python3 - <<'PY' "$template"
import os, re, sys

def repl(match):
    var = match.group(1)
    default = match.group(2) if match.group(2) is not None else ""
    return os.environ.get(var, default)

with open(sys.argv[1], "r", encoding="utf-8") as f:
    text = f.read()
print(re.sub(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-([^}]*))?\}", repl, text), end="")
PY
}

if [ "${1:-}" = "--dry-run-config" ]; then
    if [ ! -f "$TEMPLATE_PATH" ]; then
        echo "ERROR: serverconfig.xml.template not found at $TEMPLATE_PATH" >&2
        exit 1
    fi
    hydrate_template "$TEMPLATE_PATH"
    exit 0
fi

mkdir -p /data/saves /data/logs /data/config

if [ "$(id -u)" -eq 0 ]; then
    chown -R steam:steam /data
else
    echo "WARNING: not running as root; skipping /data ownership fix" >&2
fi

if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "ERROR: serverconfig.xml.template not found at $TEMPLATE_PATH" >&2
    exit 1
fi

cp "$TEMPLATE_PATH" "$CONFIG_PATH"
hydrate_template "$TEMPLATE_PATH" > "$CONFIG_PATH"

export LD_LIBRARY_PATH="/server${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

exec gosu steam "$SERVER_BINARY" \
    -configfile="$CONFIG_PATH" \
    -quit \
    -batchmode \
    -nographics \
    -dedicated

