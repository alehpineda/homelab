# Proxmox Backup Server (astarothrinascimento)

| Item | Value |
|------|-------|
| Host | astarothrinascimento, 10.10.0.25 (bare metal) |
| Web UI | https://pbs.alehpineda.com (direct: https://10.10.0.25:8007) |
| PBS | 4.2.x on Debian trixie, kernel 7.0.14-26-pve |
| OS disk | sda UDSS UD3CS1HT301-256G (TUSJA24BNX05269), LVM |
| Datastore | `hdd-backup`, XFS on sdb ST12000NM0127 (ZJV0EY0M, 10.9 TiB, ex-Samba HDD), `/mnt/datastore/hdd-backup` |

Ansible: `ansible/playbooks/pbs.yml` (role `pbs`, group `pbs`). Not in `site.yml`.
Run only from an approved plan. `grokops` has limited sudo, so run the
playbook as root or another full-sudo account (`-u root -k`), never with
committed secrets.

## What the role manages (idempotent)

- `pbs-enterprise.sources` set to `Enabled: no`; `proxmox.sources` with
  `pbs-no-subscription` (trixie).
- Subscription-nag removal: `/usr/local/sbin/pbs-no-nag`, re-applied by
  `/etc/apt/apt.conf.d/no-nag-script` after every dpkg run. widget-toolkit
  5.2.x is multi-line, so the old community one-line sed matches nothing; the
  helper targets `data.status.toLowerCase() !== 'active'`.
- Accounts `grokaudit` (read-only) and `grokops` with
  `/etc/sudoers.d/grokops-pbs` (proxmox-backup-manager, proxmox-backup-client,
  systemctl, apt). Public keys come from gitignored host_vars.
- Datastore check (exists, path, mounted). GC `sun 03:00`.
- Verify job `verify-hdd-monthly` (monthly, ignore-verified, outdated-after 30).
- Prune job `prune-hdd-default` (daily; keep 7 daily, 4 weekly, 6 monthly).
- `pve-brl@pbs` user and DatastoreBackup + DatastoreAudit on
  `/datastore/hdd-backup` for the user and token `pve-brl@pbs!brl`.

## Manual, one-time (not in the role)

1. Datastore creation. **Wipes the disk.** Confirm serial first:
   ```
   lsblk -dno NAME,MODEL,SERIAL /dev/sdb
   wipefs -a /dev/sdb && sgdisk --zap-all /dev/sdb
   proxmox-backup-manager disk fs create hdd-backup --disk sdb --filesystem xfs --add-datastore true
   ```
2. Token (secret shown once; store in vault, never in git):
   ```
   proxmox-backup-manager user generate-token pve-brl@pbs brl
   ```
3. API token `grokops@pbs!forge` (Admin on `/`) for Forge automation.

## BRL PVE side (documented; telmate/proxmox does not manage storage or jobs)

Storage `pbs-hdd` (`/etc/pve/storage.cfg`):
```
pbs: pbs-hdd
        datastore hdd-backup
        server 10.10.0.25
        content backup
        fingerprint cc:32:9b:fc:4b:cf:dc:13:22:8b:5b:c7:49:48:9c:4c:8c:78:5a:45:c1:e2:0e:d5:d3:df:ab:fe:ce:e0:4b:ad
        prune-backups keep-all=1
        username pve-brl@pbs!brl
```
Retention lives on PBS (`prune-hdd-default`), so PVE keeps all.
Re-create with `pvesm add pbs pbs-hdd ... --password <token secret>`.

Backup job `forge-backup-pbs-hdd` (`/etc/pve/jobs.cfg`): all guests, exclude
151 and 250 (same set left out of `forge-backup-ssd`), schedule `03:30`
(after `forge-backup-ssd` at 02:00), mode snapshot, notes `{{guestname}}`,
mail on failure.

First test: CT 153 to `pbs-hdd`, TASK OK (2026-11-07).

## Network pieces (outside this repo's Ansible)

- **Caddy** (CT 250, 10.10.0.250): `pbs.alehpineda.com` reverse-proxies to
  `https://10.10.0.25:8007` (upstream TLS verify skipped for the PBS self-signed cert).
- **AdGuard** (CT 153 / 155, 10.10.0.53 / .55): DNS rewrite
  `pbs.alehpineda.com -> 10.10.0.250`.
- **NetBird** (managed by NetTit): network resource for 10.10.0.25 with a
  TCP 8007/22 policy for Admin-Devices and NetTit-Shared; dedicated DNS group
  `PBS-AdGuard` (guest users excluded). No public DNS or exposure.

## Verify

```
proxmox-backup-manager datastore list
proxmox-backup-manager verify-job list
proxmox-backup-manager prune-job list
curl -s -o /dev/null -w '%{http_code}\n' https://pbs.alehpineda.com
pvesm status | grep pbs-hdd
```
