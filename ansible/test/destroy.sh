#!/usr/bin/env bash
#
# Destroys the throwaway droplet and removes the generated inventory.
#
set -euo pipefail

DROPLET_NAME="devplatform-test"
HERE="$(cd "$(dirname "$0")" && pwd)"

if ! doctl compute droplet get "$DROPLET_NAME" >/dev/null 2>&1; then
    echo "No droplet named '$DROPLET_NAME' — nothing to destroy."
else
    echo "==> Destroying $DROPLET_NAME"
    doctl compute droplet delete "$DROPLET_NAME" --force
    # Deletion is asynchronous; a provision.sh that follows immediately would
    # still see the droplet.
    for _ in $(seq 1 30); do
        doctl compute droplet get "$DROPLET_NAME" >/dev/null 2>&1 || break
        sleep 2
    done
fi

rm -f "$HERE/inventory/test.ini"
echo "==> Done."
