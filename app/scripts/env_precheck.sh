#!/bin/sh
# Clone the object_detector_web application repo onto the target VM.
# Executed by the Fabric plugin, which runs scripts via `sh` (the shebang
# is ignored) -- keep this POSIX sh compatible.
set -eu
trap 'echo "ERROR: env_precheck failed at line $LINENO (exit $?)" >&2' EXIT

REPO_URL="${REPO_URL:-https://github.com/Chubtoad5/object_detector_web.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
DEST="$HOME/object_detector_web"

# Ubuntu cloud images do not ship git; install it if missing.
if ! command -v git >/dev/null 2>&1; then
    ctx logger info "git not found - installing..."
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git
fi

if [ -d "$DEST/.git" ]; then
    ctx logger info "Repo already present at ${DEST}; updating to ${REPO_BRANCH}..."
    cd "$DEST"
    git fetch --depth 1 origin "$REPO_BRANCH"
    git checkout "$REPO_BRANCH"
    git reset --hard "origin/${REPO_BRANCH}"
else
    ctx logger info "Cloning ${REPO_URL} (branch ${REPO_BRANCH}) into ${DEST}..."
    rm -rf "$DEST"
    git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$DEST"
fi

chmod +x "$DEST/deploy.sh"
ctx logger info "object_detector_web repository ready at ${DEST}."

trap - EXIT
