# CT 176 always-on Grok Bot (headless)

CT 176 (`forge-ws-blr-lxc`, 10.10.0.76, LAN-only) runs the Grok Bot desktop
app with nobody logged in, so agents can use it as an always-on computer.
Role: `ansible/roles/grokbot_headless`. Playbook: `ansible/playbooks/grokbot-headless.yml`
(not imported by `site.yml`).

## What it sets up

- `gnome-keyring` + `libpam-gnome-keyring` (Secret Service for Electron safeStorage).
- `grokbot-xvfb.service` (user): private Xvfb on `:99`, TCP disabled, private Xauthority.
- `grokbot-headless.service` (user): `grok-bot --password-store=gnome-libsecret` on `:99`.
  `ExecStartPre` runs `forge-grokbot-keyring-ready`, which unlocks the default
  collection over Secret Service (no prompt) and fails unless `Locked=false`.
  App output goes to `/dev/null` so sign-in URLs/tokens never reach the journal.
- `loginctl enable-linger` so the user manager starts at boot without a PAM login.
- RDP launchers go through `forge-grokbot-launch`, which refuses to start a
  second copy while the headless service is active.
- Opt-in (`grokbot_headless_initialize_blank_keyring=true`): one-time reset that
  backs up the old keyring/profile on the guest and creates a new **empty-password**
  default `Login` collection. Guarded by a marker file; never remove it to force a retry.

## Security tradeoff

The default keyring has no password, so the Grok Bot session stored in it is
readable by root on CT 176 and by root on the PVE host. Accepted (user-approved
2026-11-07) because CT 176 is LAN-only and only the owner has root.

## First-time use

1. Run the playbook (with the opt-in reset only on a fresh setup).
2. Stop the headless copy, RDP in, sign in to Grok Bot once, fully quit it, log out.
3. `systemctl --user start grokbot-headless.service` as the user.
4. Reboot CT 176 with nobody logged in and confirm the app reconnects.

## Caveat: single-instance lock

Opening Grok Bot in an RDP session takes the single-instance lock; closing it
leaves no running copy. Recover as the user on CT 176:

```bash
systemctl --user restart grokbot-headless.service
```
