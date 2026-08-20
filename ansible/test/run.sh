#!/usr/bin/env bash
#
# Provisions the droplet with site.yml and verifies it, then
# proves the three properties the user-management design rests on:
#
#   1. push provisioning succeeds and the box passes verify.yml
#   2. a second run changes nothing (changed=0)
#   3. the box can provision ITSELF (ansible-pull) and that run also changes
#      nothing
#   4. moving a name from dev_users to dev_users_absent and adding another
#      removes one account cleanly, adds the other, and leaves the survivor's
#      daemon and containers untouched
#   5. re-running the churn changes nothing
#
# Run provision.sh first. Any failure stops the script; destroy.sh afterwards.
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
INV="$HERE/inventory/test.ini"
HOSTYML="$HERE/host.yml"

if [ ! -r "$INV" ]; then
    echo "No test inventory — run provision.sh first." >&2
    exit 1
fi
if [ ! -r "$HERE/inventory/group_vars/all/roster.yml" ]; then
    echo "No generated roster — run provision.sh first." >&2
    exit 1
fi

IP="$(awk '/ansible_host=/{sub("ansible_host=","",$2); print $2}' "$INV")"
SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes"

cd "$ROOT"

# Asserts the PLAY RECAP of the previous ansible-playbook run (captured in $1)
# reports no change.
assert_unchanged() {
    if ! grep -E 'devplatform-test\s*:.*changed=0 ' "$1" >/dev/null; then
        echo "!! Expected changed=0, got:" >&2
        grep -E 'devplatform-test\s*:' "$1" >&2 || true
        exit 1
    fi
    echo "    changed=0 confirmed"
}

echo "==> 0. Box-local settings and a copy of the working tree on the droplet"
$SSH "root@$IP" 'install -d -m 700 /etc/dev-platform'
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q "$HOSTYML" "root@$IP:/etc/dev-platform/host.yml"
$SSH "root@$IP" 'chmod 600 /etc/dev-platform/host.yml'
# The pull run clones from this path, so it must exist before the timer is
# installed. rsync of the working tree — not a git push — so uncommitted
# changes are what gets tested. .git is excluded and a fresh repo initialised;
# the generated (gitignored) test inventory and roster are force-added because
# the pull run on the droplet reads them from the checkout.
rsync -a --delete \
    --exclude .git --exclude '*.pdf' --exclude '.DS_Store' \
    -e "$SSH" \
    "$REPO/" "root@$IP:/srv/dev-platform-src/"
# rsync preserved the operator's uid; git refuses to work in a directory owned
# by someone else, and ansible-pull runs as root.
$SSH "root@$IP" 'chown -R root:root /srv/dev-platform-src'
$SSH "root@$IP" 'cd /srv/dev-platform-src && (git rev-parse --git-dir >/dev/null 2>&1 || git init -q -b main) \
    && git config user.email test@example && git config user.name harness \
    && git add -A \
    && git add -f ansible/test/inventory/test.ini ansible/test/inventory/group_vars/all/roster.yml \
    && (git diff --cached --quiet || git commit -q -m "harness snapshot")'

echo "==> 1. Provision (push)"
ansible-playbook -i "$INV" -e "@$HOSTYML" site.yml "$@"

echo "==> 1. Verify"
ansible-playbook -i "$INV" -e "@$HOSTYML" test/verify.yml

echo "==> 2. Provision again — must change nothing"
ansible-playbook -i "$INV" -e "@$HOSTYML" site.yml | tee "$HERE/run2.log"
assert_unchanged "$HERE/run2.log"

echo "==> 3. Self-provision (ansible-pull on the droplet) — must succeed and change nothing"
$SSH "root@$IP" 'systemctl start dev-platform-pull.service'
$SSH "root@$IP" 'journalctl -u dev-platform-pull.service --no-pager -o cat' > "$HERE/run3.log"
assert_unchanged "$HERE/run3.log"
if ! $SSH "root@$IP" 'systemctl is-active dev-platform-pull.timer' | grep -q active; then
    echo "!! pull timer is not active" >&2; exit 1
fi

echo "==> 4. Churn: remove alice, add carol — bob keeps a container running throughout"
ansible-playbook -i "$INV" -e "@$HOSTYML" -e dev_survivor=bob test/churn_setup.yml
ansible-playbook -i "$INV" -e "@$HOSTYML" \
    -e '{"dev_users":["bob","carol"],"dev_users_absent":["alice"]}' \
    site.yml
ansible-playbook -i "$INV" -e "@$HOSTYML" \
    -e '{"dev_users":["bob","carol"],"dev_users_absent":["alice"],"dev_survivor":"bob","dev_removed":"alice"}' \
    test/verify_users.yml
# SSH as the accounts themselves, from the outside — the thing a developer does.
KEY="${DEV_TEST_PUBKEY%.pub}"
if ! $SSH -i "$KEY" "carol@$IP" 'id -un' | grep -qx carol; then
    echo "!! carol cannot log in" >&2; exit 1
fi
if $SSH -i "$KEY" "alice@$IP" true 2>/dev/null; then
    echo "!! alice can still log in" >&2; exit 1
fi
echo "    carol logs in, alice cannot"

echo "==> 5. Churn again — must change nothing"
ansible-playbook -i "$INV" -e "@$HOSTYML" \
    -e '{"dev_users":["bob","carol"],"dev_users_absent":["alice"]}' \
    site.yml | tee "$HERE/run5.log"
assert_unchanged "$HERE/run5.log"

rm -f "$HERE"/run[235].log
echo "==> All phases passed."
