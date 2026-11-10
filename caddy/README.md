# CT250 Caddy desired state

Live on CT250 as of 2026-11-09 8:38 PM CT is **Caddyfile.bridge** (sha f73dd113…).

- `.250` serves admin names and the 7 *arr apps (prowlarr, sonarr, radarr, lidarr, bazarr, qbittorrent, dockge). `.251` serves family names only (jellyfin, seerr, searxng); *arr and Dockge on the `.251` listener are aborted. Jellyfin and SearXNG still also answer on `.250` until the final cutover.
- `adguard.alehpineda.com` proxies to AdGuard A (`https://10.10.0.53:443`) with B (`https://10.10.0.55:443`) as failover only: `lb_policy first`, active health on `/login.html` (200), passive fail, `tls_insecure_skip_verify`. A has `force_https`; proxying A's `:80` caused a 307 redirect loop (fixed 8:11 PM CT). B is HTTP-only today and is firewalled off from Caddy, so B stays unhealthy until TLS and a `+caddy` allow exist.
- **Caddyfile.final** is staged, not installed. Installing it would also abort jellyfin/searxng on `.250`. Do not install it, and do not move jellyfin/searxng DNS to `.251`, until that cutover is approved.

Firewall vars for CT250 (`ipfilter-net0` {.250,.251}, tcp 80/443 + udp 443 from `+management`) already landed in `ansible/group_vars/all/fw_allowlists.yml` via PR #38.
