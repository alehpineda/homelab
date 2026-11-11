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
