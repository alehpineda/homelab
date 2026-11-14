# NetBird client on CT 184 (Uptime Kuma)

Why: Kuma monitors `crowdsec.alehpineda.com`, a NetBird reverse-proxy
service only reachable from mesh peers in its access groups. CT 184 joins
as peer `ct184-uptime-kuma` in group **Monitoring-Kuma** (auto-group on a
one-use setup key from NetTit). NetTit adds that group to the CrowdSec RP.

Authority: DeathScythe 2026-11-13 10:43 PM CT, Forge chat: "Yes to 1".
Applied live 2026-11-13 ~10:46 PM CT.

## What is configured
- Host: `dev0: /dev/net/tun` on CT 184 (`pct set 184 --dev0 /dev/net/tun`,
  hotplugged on PVE 9.2, no restart). Same pattern as CT 176.
- Guest: `netbird` 0.82.0 from `pkgs.netbird.io/debian stable`, `apt-mark hold`,
  service enabled.
- `netbird up --disable-dns --disable-client-routes --disable-server-routes
  --hostname ct184-uptime-kuma`. `resolv.conf` stays AdGuard .53/.55, so the
  other monitors resolve as before. Only `100.85.0.0/16 dev wt0` is added.
- `/etc/hosts` pins below the PVE block:
  - `10.10.0.250 jackett.alehpineda.com`
  - `100.85.100.247 crowdsec.alehpineda.com` (the mesh answer; AdGuard
    returns the public 163.192.206.150)

## Apply
```bash
cd ansible && ansible-playbook playbooks/netbird-client.yml
```
Re-runs are no-ops once enrolled. For a fresh enroll, set
`netbird_client_setup_key_file` in the gitignored inventory to the box
secrets path; the role copies it (no_log), runs `up`, and shreds it.

Gotcha: `pct exec` / sudo pass `SUDO_USER`; netbird 0.82 then fails with
"refusing to fall back to root". Run it via `env -u SUDO_USER ...`.

## Verify
```bash
netbird status -d     # Management + Signal Connected, NetBird IP 100.85.x
cat /etc/resolv.conf  # nameserver 10.10.0.53 / 10.10.0.55
ip route              # no route over 10.10.0.0/24 via wt0
```

## Rollback
1. `netbird down`
2. `apt-mark unhold netbird && apt-get purge -y netbird`, remove
   `/etc/apt/sources.list.d/netbird.list` and the keyring.
3. Remove the crowdsec line from `/etc/hosts`
   (backup `/etc/hosts.bak-20261113-crowdsec`).
4. NetTit deletes peer `ct184-uptime-kuma` and the group from the RP.
5. Optional: `pct set 184 --delete dev0` (applies at next CT restart).
