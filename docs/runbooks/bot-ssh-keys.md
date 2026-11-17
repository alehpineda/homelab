# Per-bot SSH keys (role `bot_ssh_keys`)

Each Grok Bot gets its own ed25519 key per origin (bot box and/or CT 176)
instead of the two shared keys. The target accounts stay the same:
`grokaudit` (read-only) and `grokops` (scoped writes). sshd's default
`LogLevel INFO` already logs `Accepted publickey for <user> from <ip> ...
ED25519 SHA256:<fp>`, so a login names the bot without any sshd change.
The fingerprint-to-bot registry lives on the bot box at
`/workspace/secops/ssh-key-registry.md` (no key material).

Limit: bots on one origin share a Linux user, so a bot *could* read another
bot's key. This gives attribution for bots that follow their instructions,
not isolation.

Authority: DeathScythe 2026-11-17 7:52 AM CT, Forge 1:1 card t953s4991
("Yes, create a separate key for each bot and the key list"; "Yes, open the
homelab repo PR that adds the new keys"). Merge and each apply need their
own yes.

## Source of truth

`ansible/group_vars/all/bot_ssh_keys.yml` (`bot_ssh_keys_list`). Public
keys only; private keys never leave the origin that generated them. Each
entry has `bot`, `origin` (`box` | `ct176`), `pubkey` and `grants`
(`account` + `targets`). Targets are classes (`brl`, `gremory`, `lxc`,
`pbs`, `dashboard`) or an inventory hostname (`arr-blr-lxc`).

| Bot | Origins | grokaudit | grokops |
|---|---|---|---|
| forge | box, ct176 | brl, gremory, lxc, pbs | brl, pbs, dashboard |
| patch-marshal | ct176 | brl, gremory, lxc | - |
| night-watch | box | brl, gremory, lxc | - |
| surface-scout | box | brl, gremory, lxc | - |
| wolff | box, ct176 | brl, gremory, lxc | brl, dashboard |
| jack-sparrow | box | brl, arr-blr-lxc | brl |

## Rendering rules

- Each account's `~/.ssh/authorized_keys` is written in full (exclusive).
  The role refuses to write a file with no keys and validates with
  `ssh-keygen -lf`. Ansible keeps a `backup: true` copy on change.
- Bot lines: `from="<origin sources>",restrict <key> <bot>@grokbot` on LAN
  targets; `restrict <key>` only on gremory (public; home WAN and box
  egress both change, so no `from=`). `restrict` turns off port/agent/X11
  forwarding and pty; `pct exec` and plain commands over ssh still work.
- Origin sources (`bot_ssh_keys_origin_from`): `ct176` = 10.10.0.76;
  `box` = 10.10.0.50, 10.10.0.51 (NetBird routing peers CT 150/151 that
  masquerade the mesh onto the LAN) and 100.85.182.107 (the box's NetBird
  peer IP, seen when connecting to BRL's NetBird address 100.85.104.18).
  Checked read-only from `$SSH_CONNECTION` on 2026-11-17.
  Exception: the surface-scout box key sets a per-key `from` that also
  includes 10.10.0.76, so a hop through scout@CT176 is accepted on LAN
  targets (the box has no direct TCP 22 route to some CTs). Other bots
  are unchanged. A key may set `from` to override the origin default.
- `bot_ssh_keys_keep_legacy: true` keeps the two shared keys
  (`grokaudit@grokbot-box`, `forge-ct176`) with no options on the targets
  where they are authorized today, until the retirement step.
- `bot_ssh_keys_extra` (host_vars, `{account: [lines]}`) keeps any non-bot
  line found live during the `--check --diff` review.

## Where it applies

| Target | How | Who |
|---|---|---|
| gremory grokaudit | `playbooks/bot-ssh-keys.yml --tags gremory` (as `gremory`, become) | Forge, with a yes |
| BRL grokaudit + grokops | `scripts/brl-bot-ssh-keys.sh` as root on BRL (grokops cannot write these files) | the user |
| LXC grokaudit | `playbooks/grokaudit.yml --limit <host>` (role `lxc_grokaudit`) | Forge, with a yes |
| PBS grokaudit + grokops | `playbooks/pbs.yml` (role `pbs`) | Forge, with a yes |
| CT 191/198 grokops | `playbooks/dashboards.yml` (role `dashboard_editor`) | Forge, with a yes |

The retired variables `lxc_grokaudit_pubkey`, `pbs_grokaudit_pubkeys`,
`pbs_grokops_pubkeys` and `dashboard_editor_pubkeys` make the roles fail if
still set in a local inventory, so a stale list cannot win silently.

Before every apply, run the same playbook with `--check --diff` and read
which lines would disappear. PBS is add-only today, so any unexpected key
there goes to `bot_ssh_keys_extra` or is removed only with a yes.

## BRL root script

`scripts/brl-bot-ssh-keys.sh` is generated from the same list:

```bash
cd ansible
ansible-playbook playbooks/bot-ssh-keys.yml --tags brl_script
sha256sum ../scripts/brl-bot-ssh-keys.sh
```

It refuses to run unless it is root on `barbatoslupusrex`, backs up each
`authorized_keys` to `.bak-<timestamp>`, writes the new file atomically and
prints before/after/removed fingerprints. It changes nothing else.
Rollback: copy the `.bak-<timestamp>` file back.

## Rollout (plan 2026-11-17-per-bot-ssh-identity-and-scout-probes.md 1.5)

1. Generate keys and registry (done 2026-11-17 07:53 CT, nothing authorized).
2. This change: merge (yes), then apply per target above (yes each) with
   legacy keys kept.
3. Verify per bot/origin/target:
   `ssh -o IdentitiesOnly=yes -o BatchMode=yes -i <new key> <acct>@<host> true`,
   check the target log shows the new fingerprint, and a read-only
   `sudo -n pct exec` round trip as grokops works with `restrict`.
4. Each bot switches its instructions to its own key path.
5. After 7 days with no legacy fingerprint in the logs: set
   `bot_ssh_keys_keep_legacy: false`, re-apply (BRL by script again), move
   the legacy private keys to a `retired/` directory.
