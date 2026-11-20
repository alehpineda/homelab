# Runbook: Loki + OpenObserve side by side (CT 173 / CT 177)

Plan: Forge `/workspace/forge/plans/openobserve-loki-plan-20261111.md`.
Every step below needs its own approved window. Nothing here runs from
`site.yml`. Secrets never go in git, argv, or chat.

## Inputs (outside git)

| What | Where (CT 176 runner) | Format |
|------|-----------------------|--------|
| OpenObserve root user | `~/.config/forge/openobserve_root` (0600) | `O2_USER_EMAIL=` / `O2_USER_PASSWORD=` |
| OpenObserve ingest user (Alloy + Prometheus) | `~/.config/forge/openobserve_ingest` (0600) | same |
| PVE API token for Terraform | `~/.config/forge/pve.env` | existing |

The owner keeps a copy of the root login in 1Password.

## Order

0. **Prereqs.** Copy the two OpenObserve secret files to CT 176
   `~/.config/forge/` (0600). Back up Terraform state
   (`terraform.tfstate.pre-ct177-<ts>`).
1. **Loki retention (CT 173).** `ansible-playbook playbooks/logging.yml --tags loki --check --diff`, then without `--check`.
   Verify `curl -s http://10.10.0.73:3100/ready` and `/config` shows
   `retention_enabled: true`. Rollback: restore the `config.yml.<ts>~`
   backup the template task left, `systemctl restart loki`.
2. **Create CT 177.** `terraform plan -target=proxmox_lxc.ct_177` must be
   1 add / 0 change / 0 destroy. Apply. Then
   `pct set 177 --timezone America/Chicago` and `pct start 177`.
   Confirm `mp0` is mounted at `/opt/openobserve/data` and backup=1.
3. **PVE guest firewall.** `pve-guest-firewall.yml` with
   `-e '{"pve_fw_rollout":[173,177]}' --check --diff`, then apply. This
   creates the `log_shippers` ipset and the `loki`/`openobserve` aliases.
   CT 173 also has an in-guest `inet loki_filter` table (not in git): add
   `10.10.0.21, 10.10.0.250, 10.10.0.82` to its `app_allow` set for 3100
   (back up `/etc/nftables.conf` first; persist in that file).
   Wave 1 (2026-11-14): `push_allow` (3100 only) is now `.21 .250 .82 .72 .74
   .84 .77`; `.71` is already in `app_allow`. CT 177 has no in-guest filter
   (accept policy), so only the PVE `log_shippers` ipset gates :5080.
4. **OpenObserve install (CT 177).** `--tags openobserve`. Root is created
   from the env file on first start only. Verify `/healthz` 200, root login,
   ingest user listed. Unit fails with 226/NAMESPACE -> rerun with
   `-e openobserve_unit_sandbox=false`.
5. **vzdump.** Add 177 to `forge-backup-ssd` (PVE API
   `PUT /cluster/backup/forge-backup-ssd`, vmid list only; save the job JSON
   first). Run one manual snapshot-mode vzdump of 177.
6. **Ingress.** Caddyfile on CT 250 = `caddy/Caddyfile.final` (back up live
   first, `caddy validate` with the CF env, `systemctl reload caddy`).
   Run `--tags alloy_caddy` first so `/var/log/caddy` is caddy:caddy 0750
   before the reload. AdGuard A rewrite `openobserve.alehpineda.com ->
   10.10.0.250`; sync to B. Prove `curl --resolve
   openobserve.alehpineda.com:443:10.10.0.250 -sI https://openobserve.alehpineda.com`.
   Then hand the mesh DNS match to NetTit.
7. **Alloy on the BRL host.** `--tags alloy_host` needs root on
   `barbatoslupusrex` (grokops sudo has no apt). Either the owner runs it
   as root, or a paste-safe root script with the same files.
8. **Alloy on CT 182.** `--tags alloy_arr`.
9. **Prometheus remote_write (CT 172).** `--tags prom_rw --check --diff`,
   then apply. Verify `prometheus_remote_storage_samples_failed_total`
   stays 0 and OpenObserve shows `node_*`/`pve_*` metric streams.
10. **Equality check.** Per job, hourly line counts in Loki
    (`sum(count_over_time({job="pve_journal"}[1h]))`) and OpenObserve
    (`SELECT count(*) FROM pve_journal WHERE ...`) agree within 1%.

## Standard for new services (JSON logs by default)

Owner, 2026-11-14 1:54 PM CT: "The json for the rest of the existing logs is a yes. That will be the standard for all old and new services we spin up in the homelab."

1. Turn on the app's native JSON console/journal format at deploy when it has one (Servarr: `<APP>__LOG__CONSOLEFORMAT: Clef`).
2. Otherwise ship through the alloy role, which packs lines into `{ts, level, service, host, env, [component], msg}`: journald via `alloy_source_journal`, Docker text consoles via `alloy_docker_json_containers` (add a parse block to `config.alloy.j2` for a new format).
3. Play vars for a new CT: `alloy_journal_job: <service>_journal`, `alloy_service_label: <service>`, `alloy_ct_label: "<ctid>"`. Labels stay job/host/ct/service/env=homelab; never put client IPs, query names, URIs or ids in labels.
4. Add the CT IP to the `log_shippers` ipset (`fw_allowlists.yml`) and to CT173's in-guest `push_allow` before the first push.
   GitLab CT166 (2026-11-20, t994s5195): `.66` was added to both; `push_allow`
   is still the in-guest `/etc/nftables.conf` table `inet loki_filter` (not in git).
5. Verify both sinks get valid JSON with 0 drops, then hand the service to Wolff.

## Wave 6: PBS host, Flint syslog, PBS exporter (owner card t72s425, 10:42 PM CT Nov 14 2026)

- **PBS host journal** (job `pbs_journal`, labels env/host/service/job, no ct).
  `grokops` on PBS only has allowlisted sudo (proxmox-backup-manager,
  proxmox-backup-client, systemctl, apt), so `--tags alloy_pbs` needs root
  (`-u root -k`). Live apply: the owner runs, as root on PBS,
  `/home/grokops/forge-wave6/pbs-alloy-wave6-20261114.sh` after
  `sha256sum -c /home/grokops/forge-wave6/pbs-alloy-wave6-20261114.sh.sha256`.
  It does what the role does (pinned Alloy from apt.grafana.com, held; journal
  groups; o2.env 0600; config rendered from this play). `rollback` argument
  undoes it. Alloy HTTP stays on 127.0.0.1:12345. `.25` is in `log_shippers`
  and CT173 `push_allow`.
- **Flint remote syslog** (job `flint_syslog`, host `flint`). Listener on the
  CT173 Alloy, `10.10.0.73:1514/udp`, RFC3164; PVE guest rule udp/1514 from
  alias `flint` only, plus `ip saddr 10.10.0.1 udp dport 1514 accept` in
  CT173's in-guest nft. JSON body `{ts, level, service, host, env, app, msg}`,
  `ts` = receive time. Router side (OpenWrt logd), backup
  `/etc/config/system.bak-forge-wave6-*` first:
  ```
  uci set system.@system[0].log_ip=10.10.0.73
  uci set system.@system[0].log_port=1514
  uci set system.@system[0].log_proto=udp
  uci commit system
  /etc/init.d/log restart
  ```
  Rollback: `uci delete` the three options, commit, restart log.
- **Flint syslog heartbeat** (job `flint_syslog`). A 5-minute cron on the
  router so a quiet night does not look like a dead shipper. Owner (Wolff
  1:1 card t90s555, 9:29 AM CT Nov 16): "Yes, add the Flint heartbeat and
  switch the alert to it". Persistent fragment
  `/etc/gl_crontabs/crontabs.d/flint-heartbeat`:
  ```
  */5 * * * * logger -t flint-heartbeat alive
  ```
  Live crond is started by `/etc/init.d/gl_timer`, which copies
  `/etc/gl_crontabs/crontabs.d/*` into tmpfs `/tmp/gl_crontabs/crontabs.d/`,
  concatenates them into `/tmp/gl_crontabs/root`, and runs
  `crond -c /tmp/gl_crontabs`. `/etc/init.d/cron` is the stock OpenWrt
  unit and starts nothing here (`/etc/crontabs` is empty). List the live
  crontab with `crontab -c /tmp/gl_crontabs -l`. Reload with
  `/etc/init.d/gl_timer restart` (do not reboot). Do not put backup files
  inside `crontabs.d/` — every file there is concatenated into root.
  Verified 9:35:00 AM CT Nov 16: `logread` showed `flint-heartbeat: alive`,
  and Loki `{job="flint_syslog"} |= "flint-heartbeat"` returned JSON
  `{ts,level,service,host,env,app=flint-heartbeat,msg=alive}` (ts
  2026-11-16T15:35:00.094956Z). Existing `auto_timezone` and ARP-scan
  crons stayed in the live crontab.
  Role: `ansible/roles/flint_heartbeat` via `playbooks/flint.yml` (raw
  only; Flint has no Python). Not imported by `site.yml`. Rollback:
  remove the fragment and restart `gl_timer`. Pre-change copies:
  `/root/bak-forge-heartbeat-20261116/` and
  `*.bak-forge-heartbeat-20261116` next to the originals (not inside
  `crontabs.d/`).
- **Comet KVM (GL-RM1)**: no remote-syslog setting in the UI or docs; not
  shipped.
- **PBS exporter**: role `pbs_exporter` on CT172 (`metrics.yml --tags
  metrics_pbs`), natrontech/pbs-exporter v0.10.0 (tarball and binary sha256
  pinned), `127.0.0.1:10019`, Prometheus job `pbs`. Read-only identity
  `pbs-exporter@pbs!prometheus` (Audit on `/` for user and token), token in
  `/etc/pbs-exporter/token` (0600 root, systemd LoadCredential, DynamicUser).
  TLS verified against the pinned PBS cert (fingerprint in role defaults).

## Rollback

- Alloy: `systemctl disable --now alloy`; `apt-mark unhold alloy && apt purge alloy`;
  remove `/etc/apt/sources.list.d/grafana.sources`, the preferences pin,
  and `/etc/alloy/o2.env`.
- Prometheus: remove the `FORGE openobserve remote_write` block (or restore
  the blockinfile backup), `promtool check config`, `systemctl reload prometheus`.
- Caddy: restore the pre-change Caddyfile backup, reload.
- AdGuard: delete the rewrite on A; sync to B.
- CT 177: `pct stop 177`; remove from the vzdump job. Destroy only on an
  explicit yes (`prevent_destroy` is set).
- Loki: restore the config backup, restart.
