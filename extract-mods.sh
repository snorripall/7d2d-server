#!/usr/bin/env bash
set -euo pipefail

# Extract Rebirth mod groups from the source archive into the staging directory
# expected by build.sh's --build-context mods=/tmp/rebirth-groups.

ZIP_FILE="${REBIRTH_ZIP:-/home/snorri/Downloads/REBIRTH EXPERIMENTAL 2026.07.02 2245 - 7dtd v2.6 b14.zip}"
STAGING_DIR="${REBIRTH_STAGING_DIR:-/home/snorri/.cache/rebirth-groups}"
TMP_LINK="/tmp/rebirth-groups"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_GROUPS_FILE="$SCRIPT_DIR/mod-groups.txt"

if [ ! -f "$ZIP_FILE" ]; then
    echo "ERROR: Source archive not found: $ZIP_FILE" >&2
    echo "Set REBIRTH_ZIP to the correct path." >&2
    exit 1
fi

if [ ! -f "$MOD_GROUPS_FILE" ]; then
    echo "ERROR: Mod group manifest not found: $MOD_GROUPS_FILE" >&2
    exit 1
fi

echo "Source archive: $ZIP_FILE"
echo "Staging directory: $STAGING_DIR"
echo "Temp symlink: $TMP_LINK"
echo

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

for group in mods-group-{0..3}; do
    mkdir -p "$STAGING_DIR/$group"
done

declare -A MOD_TO_GROUP
current_group=""
while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    if [[ "$line" =~ ^\[mods-group-([0-9]+)\] ]]; then
        current_group="mods-group-${BASH_REMATCH[1]}"
        continue
    fi

    if [[ "$line" =~ ^mods-group-[0-9]+:[[:space:]]*(.+)$ ]]; then
        mod_name="${BASH_REMATCH[1]%%[[:space:]]}"
        if [ -z "$current_group" ]; then
            echo "ERROR: Mod '$mod_name' appears before any [mods-group-N] header" >&2
            exit 1
        fi
        MOD_TO_GROUP["$mod_name"]="$current_group"
    fi
done < "$MOD_GROUPS_FILE"

mod_count="${#MOD_TO_GROUP[@]}"
echo "Found $mod_count mods in $MOD_GROUPS_FILE"

for mod_name in "${!MOD_TO_GROUP[@]}"; do
    group="${MOD_TO_GROUP[$mod_name]}"
    echo "Extracting '$mod_name' -> $group/"
    unzip -q "$ZIP_FILE" "$mod_name/*" -d "$STAGING_DIR/$group/"
done

echo

errors=0
for mod_name in "${!MOD_TO_GROUP[@]}"; do
    group="${MOD_TO_GROUP[$mod_name]}"
    if [ ! -d "$STAGING_DIR/$group/$mod_name" ]; then
        echo "ERROR: Expected directory missing: $STAGING_DIR/$group/$mod_name" >&2
        errors=$((errors + 1))
    fi
done

if [ "$errors" -gt 0 ]; then
    echo "ERROR: $errors mod(s) failed to extract." >&2
    exit 1
fi

rm -f "$TMP_LINK"
ln -s "$STAGING_DIR" "$TMP_LINK"

echo
echo "Done. Staged $mod_count mods at $STAGING_DIR"
echo "Build context link: $TMP_LINK -> $STAGING_DIR"
