# CT250 Caddy desired state

Live on CT250 as of 2026-11-09 8:47 PM CT is **Caddyfile.final** (sha adb4c10a…).

- `.250` serves admin names only: the 7 *arr/Dockge apps (prowlarr, sonarr, radarr, lidarr, bazarr, qbittorrent, dockge) plus pbs, proxmox, vault, comet, metube, adguard, openbao, ollama, firecrawl, n8n, postiz, and grafana. `.251` serves family names only (jellyfin, seerr, searxng). Cross-listener names are aborted.
- `adguard.alehpineda.com` proxies to AdGuard A (`https://10.10.0.53:443`) with B (`https://10.10.0.55:443`) as failover only: `lb_policy first`, active health on `/login.html` (200), passive fail, `tls_insecure_skip_verify`. A has `force_https`; proxying A's `:80` caused a 307 redirect loop (fixed 8:11 PM CT). B has TLS as of 8:35 PM CT, and CT155 allows :443 from `+caddy`.
- DNS: `jellyfin.alehpineda.com` and `searxng.alehpineda.com` rewrite to `10.10.0.251` on AdGuard A and B. `seerr.alehpineda.com` was already on `.251`. Admin names stay on `.250`.

`Caddyfile.bridge` is the last transitional snapshot (family names still answered on `.250`) and was live until this cutover. Rollback on CT250: restore `/etc/caddy/Caddyfile.bak-final-flip-20261110-024719`, validate, `systemctl reload caddy`. Restore the AdGuard rewrite JSON from the pre-change backup to point jellyfin/searxng back at `.250`.

Firewall vars for CT250 (`ipfilter-net0` {.250,.251}, tcp 80/443 + udp 443 from `+management`) already landed in `ansible/group_vars/all/fw_allowlists.yml` via PR #38.

On 2026-11-10 a systemd drop-in `/etc/systemd/system/caddy.service.d/10-forge-boot.conf` was added live so Caddy retries if it starts before `.250`/`.251` exist (`Restart=on-failure`, `RestartSec=3s`, `StartLimitIntervalSec=0`). The main unit already had `Wants`/`After` `network-online.target`, but this guest has no wait-online provider. IaC: `ansible/playbooks/caddy.yml` and `ansible/roles/caddy_boot/`. The role daemon-reloads and does not restart Caddy. `net.ipv4.ip_nonlocal_bind` was considered and not applied.
