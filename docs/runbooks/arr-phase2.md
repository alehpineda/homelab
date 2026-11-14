# Runbook: CT 182 arr phase 2

Phase 2 adds Prowlarr, Sonarr, Radarr, Lidarr, Bazarr, and FlareSolverr
to the existing CT 182 compose at `ansible/roles/arr/files/compose.yaml`.
The guest path stays `/opt/stacks/arr/compose.yaml`. Opening the pull
request does not merge it, does not copy app configs, and does not start
the new containers.

bael stays up until a separate stop-and-copy approval. Do not print API
keys, download-client passwords, or `.env`. Do not create CT 183. Do not
change Caddy, AdGuard, or NetBird.

## Identity and images

Container uid 1000 is host uid 1100. The LinuxServer services set
`PUID=1000`, `PGID=1000`, and `TZ=America/Chicago` in the compose file.
FlareSolverr is not a LinuxServer image. Its process already runs as uid
1000, and `PUID` / `PGID` do not change it, so those two names are not
set on that service. `TZ=America/Chicago` is set.

`pull_policy` is `missing`. Digests:

| Service | Image |
|---|---|
| Prowlarr | `lscr.io/linuxserver/prowlarr@sha256:431d7efebcef466e56adaa40a7a2fa2b0e85159a037b8bf465eaadbf0cf5bedf` |
| Sonarr | `lscr.io/linuxserver/sonarr@sha256:673dc4609a5672bc8e46069c86ffcea283a86b48d34a6c93d8da8c24a1b87571` |
| Radarr | `lscr.io/linuxserver/radarr@sha256:ade5937813c6ae415b29db729386e53fea3ecf067a019849bafbe2d2a6ec02ba` |
| Lidarr | `lscr.io/linuxserver/lidarr@sha256:d5707cfe084da21a3864c7ef0edd9c0543b5e26c79c551f84dad5ef8683af8c7` |
| Bazarr | `lscr.io/linuxserver/bazarr@sha256:7ef0e58216900dbce30b123e0eb65f5cb30e36f126de9474acdd2022fb069c54` |
| FlareSolverr | `flaresolverr/flaresolverr@sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767` |

## Network

Every phase 2 service uses `network_mode: service:gluetun` and waits
until gluetun is healthy. WebUI ports are published on gluetun, bound to
`10.10.0.82`:

| App | Port |
|---|---|
| qBittorrent (unchanged) | 8085 |
| Prowlarr | 9696 |
| Sonarr | 8989 |
| Radarr | 7878 |
| Lidarr | 8686 |
| Bazarr | 6767 |

`FIREWALL_INPUT_PORTS` is `8085,9696,8989,7878,8686,6767` in the gluetun
service environment, which overrides `env_file`. Leave that name out of
`/opt/stacks/arr/.env`.

FlareSolverr listens on 8191 inside the gluetun network namespace. It is
not published and it is not in `FIREWALL_INPUT_PORTS`. Prowlarr reaches
it at `http://localhost:8191`. Prowlarr reaches Sonarr, Radarr, and
Lidarr on localhost at 8989, 7878, and 8686. Those apps reach
qBittorrent at `localhost:8085`.

Adding the ports recreates gluetun. Recreate every service that shares
its network namespace. Watchtower stays up:

```bash
cd /opt/stacks/arr
docker compose up -d --force-recreate \
  gluetun qbittorrent prowlarr sonarr radarr lidarr bazarr flaresolverr
```

Then repeat the phase 1 VPN checks from
[arr-phase1.md](arr-phase1.md). The egress IP must not be
`72.221.51.177`.

## Config directories

The role creates these guest directories, owner `1000:1000`, mode
`0750`. It does not copy bael configs into them.

| App | Guest path | Container path |
|---|---|---|
| Prowlarr | `/opt/arr/prowlarr` | `/config` |
| Sonarr | `/opt/arr/sonarr` | `/config` |
| Radarr | `/opt/arr/radarr` | `/config` |
| Lidarr | `/opt/arr/lidarr` | `/config` |
| Bazarr | `/opt/arr/bazarr` | `/config` |

FlareSolverr has no `/config` bind. The source volume had no durable
database.

## Volumes

Data volumes are CT paths only. Each app gets the library and download
subpaths it writes. Books, metube, documents, photos, backups, and
usenet incomplete are not mounted into these containers. qBittorrent
still has all of `/data/downloads`. Hardlinks across these binds do not
work; imports stay copies.

| App | Binds |
|---|---|
| Prowlarr | config only |
| Sonarr | `/data/media/tv`, `/data/media/anime-tv`, `/data/downloads/tv`, `/data/usenet/complete/tv` |
| Radarr | `/data/media/movies`, `/data/media/anime-movies`, `/data/downloads/movies`, `/data/usenet/complete/movies` |
| Lidarr | `/data/media/music`, `/data/downloads/music`, `/data/usenet/complete/music` |
| Bazarr | `/data/media/movies`, `/data/media/anime-movies`, `/data/media/tv`, `/data/media/anime-tv` |
| FlareSolverr | none |

The role checks `findmnt` for each of those paths and fails if one is
missing. It does not create the mount. Do not run `docker compose up`
against a missing source: Docker would create a local directory there.

## Watchtower

Phase 2 services set:

```text
com.centurylinklabs.watchtower.enable=true
com.centurylinklabs.watchtower.monitor-only=true
```

`WATCHTOWER_MONITOR_ONLY` stays `true` and
`WATCHTOWER_LABEL_TAKE_PRECEDENCE` stays `false`, same as phase 1.
Labels cannot turn updates on. Pinned digests do not by themselves
produce new-release mail.

## Recyclarr

Recyclarr 8.8.1 shares gluetun's network and publishes no port, so it is
not added to `FIREWALL_INPUT_PORTS`. Include `recyclarr` when recreating
that namespace. The image does not honor `PUID` or `PGID`. Compose sets
`user: "1000:1000"`. The role creates `/opt/arr/recyclarr` (container
`/config`), owner `1000:1000`, mode `0750`. It does not copy a config.

Copy `ansible/roles/arr/files/recyclarr.yml.example` to
`/opt/arr/recyclarr/recyclarr.yml` on the guest. API keys belong only in
`/opt/arr/recyclarr/secrets.yml`, mode `0600`, owner uid `1000`. Do not
commit that file. `delete_old_custom_formats` stays `false`. Do not
enable global `reset_unmatched_scores`: that would zero the local
`Malware extensions` custom format (`-10000`) and the language custom
formats.

The container cron is `0 4 * * *` (`America/Chicago`) and runs
`recyclarr sync` once `recyclarr.yml` is present. Preview before that
live sync:

```bash
docker exec recyclarr recyclarr sync --preview
```

## Jackett

Jackett (`lscr.io/linuxserver/jackett` v0.24.3055-ls35, amd64 digest)
shares gluetun's network. Its UI and Torznab API are on 9117, published
on gluetun at `10.10.0.82:9117` and listed in `FIREWALL_INPUT_PORTS`.
Adding that port recreates gluetun, so include `jackett` when recreating
the namespace. `AUTO_UPDATE` is `false` so the pinned digest stays put.
The role creates `/opt/arr/jackett` (container `/config`), owner
`1000:1000`, mode `0750`. The API key lives in
`/opt/arr/jackett/Jackett/ServerConfig.json`. Do not commit it.
FlareSolverr is `http://127.0.0.1:8191` from Jackett.

## Apply

Same play as phase 1, only after the child mounts are present and a
live run is approved:

```bash
cd ansible
ansible-playbook --syntax-check playbooks/arr.yml
ansible-playbook playbooks/arr.yml
```

The play still refuses to start the stack when `/opt/stacks/arr/.env` is
missing, empty, or not root mode `0600`. It still does not run
`docker compose config` on the guest, and it does not print `.env`.
