#!/usr/bin/env bash
set -euo pipefail
IMAGE_TAG="ghcr.io/snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245-loginfix"
docker push "$IMAGE_TAG"
