# Host-level backups to PBS (BRL, PBS, gremory)

Datastore `hdd-backup` on PBS 10.10.0.25. Namespaces `host/brl`, `host/pbs`,
`host/gremory`. Prune job `prune-host` (ns `host`, depth 1): 14 daily, 8 weekly, 12 monthly.

| Host | Mode | Identity | Timer | Script |
|---|---|---|---|---|
| BRL barbatoslupusrex | push over LAN | `host-brl@pbs!brl` (DatastoreBackup on host/brl) | 01:30 | `/usr/local/sbin/forge-brl-host-backup` (role brl_host_backup) |
| PBS astarothrinascimento | local push | `host-pbs@pbs!pbs` (host/pbs) | 01:45 | `/usr/local/sbin/forge-pbs-self-backup` (role pbs) |
| gremory (aarch64) | **pull** by PBS over public SSH | `host-gremory@pbs!pull` (host/gremory) | 04:30 | `/usr/local/sbin/forge-gremory-pull` (role pbs) + gremory_pull_source |

Tokens: `/etc/forge/pbs-host-<host>.token` (0600 root) on each host; copies in vault. Never in git.

## Encryption (client-side, user-held)
All three use `/etc/forge/pbs-host.key`. Units have `ConditionPathExists` on it and
timers stay disabled until it exists. Create once (on PBS, as root), store in vault:
```
proxmox-backup-client key create /etc/forge/pbs-host.key --kdf scrypt   # prompts for a passphrase
proxmox-backup-client key paperkey /etc/forge/pbs-host.key --output-format text
```
`--kdf scrypt` needs the passphrase at run time (`PBS_ENCRYPTION_PASSWORD`); for unattended timers use
`--kdf none` and protect the file (0600 root) + vault copy + paperkey. Copy the same file to BRL
`/etc/forge/pbs-host.key`. Losing the key means losing these backups.

## gremory pull
- Why pull: no arm64 PBS client from Proxmox; gremory has no route to PBS:8007 (no NetBird host client, by rule).
- PBS root key `/root/.ssh/gremory_pull_ed25519` → `gremory-pull@163.192.206.150`, forced command
  `forge-gremory-pull-gate` allowing only `predump` and `rsync --server --sender` (read-only) via scoped sudoers.
- Host key pinned in `/etc/forge/gremory_known_hosts` (SHA256:QEk8y5Ub9lKf0dXLUgYhB3wgifZmexZSrsQDWiJ20Y0).
- `forge-gremory-predump`: sqlite `.backup` of NetBird `store.db`, `idp.db`, `events.db`, `access_logs.db`
  and CrowdSec `crowdsec.db` (online, no service stop), `pg_dumpall` of honcho and firecrawl, integrity check.
- Paths: dumps, `/home/gremory` (compose, `config.yaml`, `traefik-dynamic.yaml`, secrets/, crowdsec,
  crowdsec-web-ui, honcho, gbrain, `.hermes` minus venv), `/etc`, `/root`, `/usr/local`, docker volumes
  `gremory_netbird_data` (live .db excluded; dumps used), `gremory_netbird_traefik_letsencrypt`,
  `gremory_netbird_proxy_certs`, `gremory_crowdsec_db`. ~10.8 GB, 234k files.
- Test: `forge-gremory-pull --dry-run`, `--stage-only`.

## Weekly PBS config copy
`forge-pbs-self-backup` writes `/var/backups/forge-pbs-config/proxmox-backup-etc.tgz.enc`
(openssl AES-256, pass = key file). BRL copies it Sundays to `/mnt/pve/backup-ssd/forge-pbs-config/`
(keep 8) with root key `/root/.ssh/pbs_cfg_pull_ed25519`, authorized on PBS `grokaudit` with
`restrict,command="cat /var/backups/forge-pbs-config/proxmox-backup-etc.tgz.enc"`.

## Restore test
```
proxmox-backup-client restore --ns host/gremory host/gremory/<time> gremory.pxar /tmp/r --keyfile /etc/forge/pbs-host.key
sqlite3 /tmp/r/var/backups/forge-gremory/db/netbird-store.db 'pragma integrity_check'
```
