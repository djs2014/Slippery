#!/usr/bin/env bash
# Install/update the Slippery desklet on the local Cinnamon desklet session.
# Usage: ./install.sh   (run from the cinnamon-desklet directory, or anywhere)
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/slippery@desklet"
DEST_DIR="${HOME}/.local/share/cinnamon/desklets/slippery@desklet"

if [ ! -d "${SRC_DIR}" ]; then
    echo "error: desklet source not found at ${SRC_DIR}" >&2
    exit 1
fi

mkdir -p "${DEST_DIR}"
cp -r "${SRC_DIR}/." "${DEST_DIR}/"

echo "installed slippery@desklet -> ${DEST_DIR}"
echo "Menu -> Desklets -> find 'Slippery Desklet' -> add to desktop -> gear icon for settings"