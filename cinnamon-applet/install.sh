#!/usr/bin/env bash
# Install/update the Slippery applet on the local Cinnamon panel.
# Usage: ./install.sh   (run from the cinnamon-applet directory, or anywhere)
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/slippery@local"
DEST_DIR="${HOME}/.local/share/cinnamon/applets/slippery@local"

if [ ! -d "${SRC_DIR}" ]; then
    echo "error: applet source not found at ${SRC_DIR}" >&2
    exit 1
fi

mkdir -p "${DEST_DIR}"
cp -r "${SRC_DIR}/." "${DEST_DIR}/"

echo "installed slippery@local -> ${DEST_DIR}"
echo "then: Alt+F2 -> r  (restart Cinnamon)"
echo "Menu -> Applets -> find 'Slippery' -> add to panel -> gear icon for settings"
