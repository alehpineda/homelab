# Observability databases: CT 178 PostgreSQL, CT 179 MariaDB

Status: **declared, not created.** The PR adds IaC only. Merge, apply,
package installs and each migration each need the owner's own yes.
Plan: Forge `/workspace/forge/plans/2026-11-16-obs-databases.md`.

Owner, Forge 1:1, Nov 16 2026:
- 4:47 PM CT (t927u): "Im on board with the plan. Im ok with uptime Kuma loosing some of its history since it's been up for less than a week, and the upgrades we implemented have less than a day. So we can do a Mariadb move without much concern."
- 4:48 PM CT (t928u): "I want a two lxc. One for postre and one for Maria"
- 4:49 PM CT (t929u): "And ideally following proxmox community scripts"

## Layout

| CT | Host | IP | Engine | Clients | Size |
|---|---|---|---|---|---|
| 178 | postgres-blr-lxc | 10.10.0.78 | PostgreSQL 17 (PGDG) | O2 CT177 (.77), Grafana CT171 (.71), Seerr CT183 (.83) trial | 2c / 2048 MiB / 8G root + 16G mp0 `/var/lib/postgresql` |
| 179 | mariadb-blr-lxc | 10.10.0.79 | MariaDB 11.8 (Debian 13) | Uptime Kuma CT184 (.84) | 1c / 1024 MiB / 6G root + 8G mp0 `/var/lib/mysql` |

Both: Debian 13 vztmpl, unprivileged, nesting, onboot, data2, MAC
02:46:4F:52:01:<id>, `startup` order 1 (178) and 2 (179), so they start
before 171/177/184 (no order set).

## Community-scripts basis

The CTs come from terraform, and the install follows the script (same
split as OpenObserve CT177). The host `ct/*.sh` scripts are never run.

- PostgreSQL: https://github.com/community-scripts/ProxmoxVE/blob/main/ct/postgresql.sh and
  https://github.com/community-scripts/ProxmoxVE/blob/main/install/postgresql-install.sh
  (last change 2026-10-23, 1385f9e), setup_postgresql in
  https://github.com/community-scripts/core/blob/main/lib/db.func.
  - Defaults: Debian 13, 1c/1024M/4G, PGDG repo, version prompt default 17.
  - The script's postgresql.conf/pg_hba.conf layout and ssl snakeoil are kept.
- MariaDB: https://github.com/community-scripts/ProxmoxVE/blob/main/ct/mariadb.sh and
  https://github.com/community-scripts/ProxmoxVE/blob/main/install/mariadb-install.sh
  (last change 2026-10-24, 54c8b23), setup_mariadb in lib/db.func.
  - Defaults: Debian 13, 1c/1024M/4G, distro mariadb-server/client (MARIADB_VERSION=latest), port 3306.

Deviations, all in the roles:

| Item | Script | Here | Why |
|---|---|---|---|
| PG version | prompt, default 17 | pinned `postgresql-17` | non-interactive, Grafana 13.3 supports 14–18 |
| PG listen | `*` | `localhost,10.10.0.78` | LAN only |
| pg_hba | md5 from 0.0.0.0/0 | peer locally; `hostssl <db> <user> <ip>/32 scram-sha-256` per app | least privilege |
| PG memory | shared_buffers 128MB, 100 conns | 512MB, 50 conns | sized to 2 GiB |
| PG logs | stderr file, UTC | syslog to journald | house JSON pipeline |
| MariaDB bind | commented (all IPs) | `127.0.0.1,10.10.0.79` via `60-forge.cnf` | LAN only; script files left as shipped |
| Sizing | 1c/1024M/4G | see the table above | measured db sizes plus dumps on disk |
| Adminer / phpMyAdmin | optional prompt | not installed | no web admin surface |

## Logs (house standard)

`{ts, level, service, host, env, [component], msg}` comes from the
existing Alloy journal pipeline (`playbooks/logging.yml --tags
alloy_postgres` / `alloy_mariadb`; jobs `postgres_journal` /
`mariadb_journal`, ct 178/179). Never use `--tags alloy_host`.

- PostgreSQL logs through syslog. PG maps each severity to a syslog priority, so `level` is right.
- MariaDB has no native JSON error log. Its stderr lands at journald priority info, so `level` is `info` and the `[Warning]`/`[ERROR]` token stays in `msg`. A follow-up can add an Alloy level regex for `mariadb_journal`.
- The dump and restore-test scripts print `{"level","component","msg"}` JSON, which the pipeline unwraps.

## Credentials

Each role's `forge-*-ensure-app` helper generates `/root/forge-db/<app>.pass`
on the DB CT (root 0600, 40 alnum chars) the first time, then always sets
the role password from that file. Passwords go to psql/mariadb on stdin,
never argv, and are never printed or copied to the controller. Moving a
password to a client CT is part of each migration window: copy CT to CT
into the client's root-only env/config file. OpenBao comes later, per the
secrets plan.

## Backups

- vzdump: PBS job `forge-backup-pbs-hdd` (`all`) picks both CTs up. `forge-backup-ssd` lists vmids explicitly, so add 178 and 179 there (separate yes).
- Logical dumps: `forge-pg-dump.timer` / `forge-mariadb-dump.timer` at 01:30 America/Chicago, before vzdump 02:00 and PBS 03:30.
  - Keeps 14 daily and 8 weekly (Sunday copy).
  - PG writes to `/var/lib/postgresql/backups/<db>/` (mp0) plus globals without role passwords.
  - MariaDB writes to `/var/backups/mariadb/<db>/` (rootfs, because mp0 is the datadir).
- Restore test: `forge-*-restore-test.timer` runs on the 1st of the month at 04:30. It restores the newest dump into `restoretest_<db>`, compares the table count, drops it, and logs PASS/FAIL as JSON. Run it once by hand before the first cutover.

## Metrics

- `prometheus-postgres-exporter` :9187 (peer auth, role `prometheus` with pg_monitor).
- `prometheus-mysqld-exporter` :9104 (unix_socket user `prometheus`).
- node_exporter :9100 on both.
- Scrape jobs `postgres`, `postgres_node`, `mariadb`, `mariadb_node` are in `logging.yml` prom_scrape. Apply them as a subset only after the CTs exist.
- Guest firewall: 178 allows 5432 from .71/.77/.83 and 9187/9100 from prometheus. 179 allows 3306 from .84 and 9104/9100 from prometheus. Both are in `log_shippers` for Alloy push. A temporary 5432 allow from CT176 (.76) is gated by `postgres_pgloader_temp_allow` (default false); see the Seerr trial section.

## Apply order (each step its own yes)

1. Terraform create CT178 and CT179 (`-target=proxmox_lxc.ct_178` / `ct_179`). Then `pct set <id> --timezone America/Chicago` and `pct start <id>`.
   Telmate 3.0.2-rc10 drops `backup = true` on `mp0` at create (state and
   `pct config` show no `backup=1`; CT177 was fixed by hand the same way).
   Before the first start, run `pct set 178 --mp0 data2:vm-178-disk-1,mp=/var/lib/postgresql,backup=1,size=16G`
   and `pct set 179 --mp0 data2:vm-179-disk-1,mp=/var/lib/mysql,backup=1,size=8G`.
   On a running CT the change stays pending until the next CT stop/start.
   Without it, vzdump skips the data volume and the PostgreSQL dumps on it.
2. `playbooks/databases.yml --tags db_postgres`, then `db_mariadb`, then `db_node_exporter`.
3. `pve-guest-firewall.yml` with `pve_fw_rollout: [178]`, then `[179]`.
4. `logging.yml --tags alloy_postgres`, then `alloy_mariadb`, then the prom_scrape subset.
   Before the first push, add .78 and .79 to CT173's in-guest `push_allow`
   (`/etc/nftables.conf`, table `inet loki_filter`, 3100 only). That set is
   not in IaC (see logging-loki-openobserve.md step 4). Without it, Alloy on
   178/179 reaches OpenObserve but times out on Loki.
5. Migrations follow the plan: OpenObserve, then Kuma, then Grafana after a 7-day soak.

## Rollback

Nothing depends on CT178/179 until a migration cuts over. Before that,
`pct stop <id>` is enough. Destroying a CT needs a yes (`prevent_destroy`
is set). Each migration has its own rollback in the plan.

## Seerr trial (CT183 → CT178)

Status: **IaC only** until the owner says yes to merge, then to apply,
then to the cutover window. Plan: Forge
`/workspace/forge/plans/2026-11-16-seerr-postgres-trial.md`.

Owner, Forge 1:1, 6:37 PM CT Nov 16 2026 (card t938s4874): "Yes, open the
PR for the Seerr Postgres plan" and "Yes, install rootless Podman on CT176
for the one-off pgloader run". Merge, apply, the pgloader run, and the
cutover each still need their own yes.

### What the IaC adds

- Role `postgresql`: database `seerr` owned by role `seerr`. `pg_hba`
  gets `hostssl seerr seerr 10.10.0.83/32 scram-sha-256`. The password is
  generated on CT178 into root-only `/root/forge-db/seerr.pass`, same as
  the other apps. Adding `seerr` to `postgresql_apps` includes it in the
  01:30 CT dump set (14 daily, 8 weekly) and the monthly restore test.
- `fw_allowlists.yml`: CT178 IN tcp/5432 from the existing `seerr`
  alias (10.10.0.83). The PVE firewall stays at `policy_in DROP`.
- Temporary pgloader allow from 10.10.0.76/32 to 5432, and the matching
  `pg_hba` line, are both gated by `postgres_pgloader_temp_allow`
  (default `false`). Merging this PR, or applying the roles with the
  default, does not open 5432 to CT176. To turn it on: apply
  `databases.yml --tags db_postgres` and `pve-guest-firewall.yml` for 178
  with `-e postgres_pgloader_temp_allow=true`. Turn it off the same way
  with the default (or `=false`) after the run.
- No new scrape job: `postgres_exporter` already covers CT178.

### Forge apply steps (each its own yes)

1. Apply `playbooks/databases.yml --tags db_postgres` so the `seerr`
   role, database, password file, and `pg_hba` line exist. Do not enable
   the temp allow yet.
2. Apply `pve-guest-firewall.yml` with `pve_fw_rollout: [178]` so .83 can
   reach 5432. Confirm the .76 rule is absent while the toggle is false.
3. Password handoff to CT183, host-side only, never in chat and never on
   argv or in a process list:
   - As `grokops` on BRL, use `sudo -n pct` only.
   - Copy `/root/forge-db/seerr.pass` from CT178 to a root-only 0600
     file on the PVE host (for example under `/root/forge-db/`), then
     `pct push` that file into CT183 as a root-only temp file.
   - On CT183, merge `DB_TYPE=postgres`, `DB_HOST=10.10.0.78`,
     `DB_PORT=5432`, `DB_USER=seerr`, `DB_NAME=seerr`, and `DB_PASS`
     into `/etc/seerr/seerr.conf` (root 0600) by reading the temp file
     inside the CT. Do not pass the password as a `pct exec` argument.
   - Shred the PVE-host and CT183 temp files. Leave
     `/root/forge-db/seerr.pass` on CT178 in place.
4. Jack backs up `/etc/seerr` and the SQLite file, starts Seerr once so
   it creates the Postgres tables, then stops it.
5. For the data copy, set `postgres_pgloader_temp_allow=true` and re-apply
   Postgres `pg_hba` plus the CT178 firewall. Run pgloader (below). Set
   the toggle back to false and re-apply both so the .76 allow is gone.
6. Jack starts Seerr and verifies requests, users, and settings.

### pgloader (one-off on CT176)

Do not use Ubuntu's packaged pgloader (3.6.x has known SQLite and
newer-Postgres problems). Use the upstream image
`ghcr.io/dimitri/pgloader:latest` once, with `--rm`, **data-only**,
against a **copy** of Seerr's `db.sqlite3` taken while Seerr is stopped.
Do not point pgloader at the live file or at any other database.

```bash
# After the copy is on CT176, as deathscythe (rootless). Example only;
# the exact load file is written at cutover. This is not a run command.
podman run --rm --network=host \
  -v /path/to/stopped-copy:/data:ro \
  ghcr.io/dimitri/pgloader:latest \
  pgloader --version
```

CT176 package install is `playbooks/podman-rootless.yml` (role
`podman_rootless`, CT176 only, not imported by `site.yml`). Rootless
Podman needs a nested user namespace and the `deathscythe` subuid/subgid
range. On an unprivileged LXC that already uses a 65536-uid map,
`newuidmap` may fail with `write to uid_map failed: Operation not
permitted`. Do not change CT176's LXC features (`nesting` / `keyctl`)
or its idmap without a new yes from the owner.

### Rollback

Set `DB_TYPE=sqlite` in `/etc/seerr/seerr.conf` and point Seerr back at
the untouched SQLite file (the copy used by pgloader is separate). Leave
the `seerr` Postgres database in place until the owner says yes to drop
it. If the temp allow was opened, set `postgres_pgloader_temp_allow`
false and re-apply `pg_hba` and the CT178 firewall.
