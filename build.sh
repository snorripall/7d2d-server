#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245"
export DOCKER_BUILDKIT=1

docker build \
    --build-context mods=/tmp/rebirth-groups \
    -t "$IMAGE_TAG" \
    "$(dirname "$0")"
