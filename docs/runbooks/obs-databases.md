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
| 178 | postgres-blr-lxc | 10.10.0.78 | PostgreSQL 17 (PGDG) | O2 CT177 (.77), Grafana CT171 (.71) | 2c / 2048 MiB / 8G root + 16G mp0 `/var/lib/postgresql` |
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
- Guest firewall: 178 allows 5432 from .71/.77 and 9187/9100 from prometheus. 179 allows 3306 from .84 and 9104/9100 from prometheus. Both are in `log_shippers` for Alloy push.

## Apply order (each step its own yes)

1. Terraform create CT178 and CT179 (`-target=proxmox_lxc.ct_178` / `ct_179`). Then `pct set <id> --timezone America/Chicago` and `pct start <id>`.
2. `playbooks/databases.yml --tags db_postgres`, then `db_mariadb`, then `db_node_exporter`.
3. `pve-guest-firewall.yml` with `pve_fw_rollout: [178]`, then `[179]`.
4. `logging.yml --tags alloy_postgres`, then `alloy_mariadb`, then the prom_scrape subset.
5. Migrations follow the plan: OpenObserve, then Kuma, then Grafana after a 7-day soak.

## Rollback

Nothing depends on CT178/179 until a migration cuts over. Before that,
`pct stop <id>` is enough. Destroying a CT needs a yes (`prevent_destroy`
is set). Each migration has its own rollback in the plan.
