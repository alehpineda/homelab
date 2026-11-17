#!/usr/bin/env bash
set +H
set -euo pipefail
# Generated from ansible/group_vars/all/bot_ssh_keys.yml by
#   ansible-playbook playbooks/bot-ssh-keys.yml --tags brl_script
# Do not edit by hand; regenerate and record the new sha256.
#
# Run as root on barbatoslupusrex (BRL). Writes the full authorized_keys
# for grokaudit and grokops (per-bot keys + the two legacy shared keys while
# bot_ssh_keys_keep_legacy is true). Backs up each existing file first and
# prints before/after fingerprints. Changes nothing else (no sshd, sudoers
# or user changes). Rollback: copy the .bak-<timestamp> file back.

if [ "$(id -u)" -ne 0 ]; then echo "Run as root." >&2; exit 1; fi
if [ "$(hostname -s)" != "barbatoslupusrex" ]; then
  echo "This is for barbatoslupusrex only (this is $(hostname -s))." >&2; exit 1
fi

ts="$(date +%Y%m%d-%H%M%S)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fps() { ssh-keygen -lf "$1" 2>/dev/null | awk '{print $2, $3}' | sort -u; }

install_keys() {
  local acct="$1" src="$2" home grp dir dest
  home="$(getent passwd "$acct" | cut -d: -f6)"
  if [ -z "$home" ]; then echo "No user $acct; skipping." >&2; return 1; fi
  grp="$(id -gn "$acct")"
  dir="$home/.ssh"; dest="$dir/authorized_keys"
  ssh-keygen -lf "$src" >/dev/null   # refuses a malformed file
  install -d -m 0700 -o "$acct" -g "$grp" "$dir"
  echo "== $acct: before"
  if [ -f "$dest" ]; then
    cp -a "$dest" "$dest.bak-$ts"
    fps "$dest" | tee "$tmp/$acct.before"
    echo "   backup: $dest.bak-$ts"
  else
    : > "$tmp/$acct.before"; echo "   (no file)"
  fi
  install -m 0600 -o "$acct" -g "$grp" "$src" "$dest.new"
  mv -f "$dest.new" "$dest"
  echo "== $acct: after"
  fps "$dest" | tee "$tmp/$acct.after"
  echo "== $acct: removed (was there, not in the new file)"
  comm -23 <(cut -d' ' -f1 "$tmp/$acct.before" | sort -u) <(cut -d' ' -f1 "$tmp/$acct.after" | sort -u) | sed 's/^/   /'
}

cat > "$tmp/grokaudit.keys" <<'KEYS'
# Managed by Ansible role bot_ssh_keys. Manual edits are overwritten.
# Source: ansible/group_vars/all/bot_ssh_keys.yml (alehpineda/homelab).
# account=grokaudit target=brl
from="10.10.0.50,10.10.0.51,100.85.182.107",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMvYFpwy+PMsnuKJUjJ0Uw7b8auHyBojKWmE2FGwRaCF forge@grokbot
from="10.10.0.76",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMOpaPvoTBn2RGaKTOIx6uLdVhyGMc09+O65GCt48iyv forge@grokbot
from="10.10.0.76",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIYPKKWC6gSp2kZsdL8k/04vQ12oWtY/ng5e7RdapDvO patch-marshal@grokbot
from="10.10.0.50,10.10.0.51,100.85.182.107",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICFqu1WZ35tyOjqfwXYPTz67NRatSqmV8naHGDLX87vB night-watch@grokbot
from="10.10.0.50,10.10.0.51,100.85.182.107,10.10.0.76",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII4S1y9BYCVa1MuyHUgkYklDHjIQv+BBKrF4+YbBSOQ3 surface-scout@grokbot
from="10.10.0.50,10.10.0.51,100.85.182.107",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILm5xiROsfnUBwGRU4+9eTkTelhluvIWTaqsOTKO0ELq wolff@grokbot
from="10.10.0.76",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHIWs60up1WltyH8qPwr7Sxw3SfRWpklHCD5gW7Pwkgl wolff@grokbot
from="10.10.0.50,10.10.0.51,100.85.182.107",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDwssQiRO2opzfDRGJJwDQEE1Ue8NGDWAGKoYyfQmwIA jack-sparrow@grokbot
# legacy shared keys (transition; remove with bot_ssh_keys_keep_legacy: false)
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICHYly9HcArNUHAgqk8av76uTHrqZuH3jJMO0Wu6V8+b grokaudit@grokbot-box
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMS00dkr6w3LB/iP5YRA6eKvHKn4EDJbvoHZTj4cwgGV forge-ct176
KEYS
install_keys grokaudit "$tmp/grokaudit.keys"

cat > "$tmp/grokops.keys" <<'KEYS'
# Managed by Ansible role bot_ssh_keys. Manual edits are overwritten.
# Source: ansible/group_vars/all/bot_ssh_keys.yml (alehpineda/homelab).
# account=grokops target=brl
from="10.10.0.50,10.10.0.51,100.85.182.107",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMvYFpwy+PMsnuKJUjJ0Uw7b8auHyBojKWmE2FGwRaCF forge@grokbot
from="10.10.0.76",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMOpaPvoTBn2RGaKTOIx6uLdVhyGMc09+O65GCt48iyv forge@grokbot
from="10.10.0.50,10.10.0.51,100.85.182.107",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILm5xiROsfnUBwGRU4+9eTkTelhluvIWTaqsOTKO0ELq wolff@grokbot
from="10.10.0.76",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHIWs60up1WltyH8qPwr7Sxw3SfRWpklHCD5gW7Pwkgl wolff@grokbot
from="10.10.0.50,10.10.0.51,100.85.182.107",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDwssQiRO2opzfDRGJJwDQEE1Ue8NGDWAGKoYyfQmwIA jack-sparrow@grokbot
# legacy shared keys (transition; remove with bot_ssh_keys_keep_legacy: false)
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICHYly9HcArNUHAgqk8av76uTHrqZuH3jJMO0Wu6V8+b grokaudit@grokbot-box
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMS00dkr6w3LB/iP5YRA6eKvHKn4EDJbvoHZTj4cwgGV forge-ct176
KEYS
install_keys grokops "$tmp/grokops.keys"

echo "Done. Reply to Forge with the output above (fingerprints only)."
