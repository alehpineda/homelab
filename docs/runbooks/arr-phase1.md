# Runbook: CT 182 arr phase 1

Phase 1 on `barbatoslupusrex` is CT 182 (`arr-blr-lxc`), Docker, Dockge,
and one compose stack: gluetun, qBittorrent, and monitor-only Watchtower.
Opening the pull request does not merge it and does not apply the guest.

bael stays as it is. Do not stop, copy, or start its torrents for this
phase. Do not add Prowlarr, Sonarr, Radarr, Lidarr, Bazarr, or
FlareSolverr. Do not create CT 183. Do not change Caddy, AdGuard, or
NetBird.

## Guest

| Item | Value |
|---|---|
| CTID | 182 |
| Hostname | `arr-blr-lxc` |
| Address | `10.10.0.82/24` on `vmbr0`, gateway `10.10.0.1` |
| MAC | `02:46:4F:52:01:82` |
| Size | 4 vCPU, 6144 MiB RAM, 512 MiB swap, 16 GiB rootfs on `data2` |
| Privilege | unprivileged, `nesting=1`, `keyctl=1` |
| Start | Terraform `start` is false. `onboot` is true after the first start |

Telmate `proxmox_lxc` 3.0.2-rc10 can set `features.nesting` and
`features.keyctl`. It has no argument for raw `lxc.*` lines, so the idmap
and the tun device are host `pct` config. They are written in
`terraform/proxmox/ct_182_arr.tf` as comments, not as provider attributes.
`SetLxcConfig` does not delete keys it never sends.

Confirm before apply, on the node:

- `pct list` has no 182. `pct config` for other guests has neither
  `10.10.0.82` nor `02:46:4F:52:01:82`.
- The address is free in the router reservation table and in the neighbor
  table. A silent ping is not enough.
- `local:vztmpl/ubuntu-26.04-standard_26.04-1_amd64.tar.zst` is still the
  template. It is the one CT 176 used.
- `pvesm status` shows free space on `data2` for a 16G disk.

## Host identity

Recheck before creating anything. host uid 1000 is `grokaudit` and host
uid 1001 is `grokops`. uid 1100 and the name `media` were absent from the
read-only inventory. If either is taken, stop.

```bash
getent passwd 1100 || true
getent group 1100 || true
getent passwd media || true
getent group media || true
```

When all four are empty:

```bash
groupadd --gid 1100 media
useradd --uid 1100 --gid 1100 --system --no-create-home --shell /usr/sbin/nologin media
```

Preserve the existing `root:` lines in `/etc/subuid` and `/etc/subgid`.
Add only this one-id exception, and only if it is not already there:

```text
root:1100:1
```

Map, both uid and gid. CT 0–999 stays in the default unprivileged band.
CT 1000 is host 1100. CT 1001–65535 continues at host 101001.

```text
lxc.idmap: u 0 100000 1000
lxc.idmap: g 0 100000 1000
lxc.idmap: u 1000 1100 1
lxc.idmap: g 1000 1100 1
lxc.idmap: u 1001 101001 64535
lxc.idmap: g 1001 101001 64535
```

The three host directories already exist and are `root:root` mode `0755`.
Mapped uid 1100 cannot write to them. Changing that ownership is a
separate step and needs your approval. Phase 1's VPN test does not need
write access. Do not chown them, and do not restart CT 180 or CT 181.

## Tun and mounts

After `terraform apply` creates the stopped guest, and before `pct start`:

```text
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

Append those two lines, and the six `lxc.idmap` lines, to
`/etc/pve/lxc/182.conf`. If Proxmox already wrote `lxc.idmap` lines,
replace them with the six above. Then:

```bash
pct config 182
```

`mp0` is host `/media/data/media` at `/data/media`. `mp1` is host
`/media/data/torrents` at `/data/downloads`, which is the path
qBittorrent uses. `mp2` is host `/media/data/usenet` at `/data/usenet`
and stays before any usenet child. All three are `backup=0`.

Live `mp3`–`mp20` are not transcribed here. The source is `pct config 182`
in `~/.config/forge/ct182-pct-config-pre-phase2`, listed in
`/workspace/forge/plans/2026-11-08-brl-arr-phase2.md`. Neither file was
available in this environment, so `ct_182_arr.tf` marks those paths
TODO and does not declare them. Children named metube, books, documents,
photos, and backups are read-only on the node. `ignore_changes` includes
`mountpoint`, so Terraform hides drift on these mounts.

`onboot` is true. Add the tun and idmap lines before the next node boot,
or the guest can start without them.

```bash
pct start 182
```

Inside the guest, `/dev/net/tun` must be a character device, and `findmnt`
must show `/data/media`, `/data/downloads`, and `/data/usenet`. Also run
`getent passwd 1000`. Phase 1 uses numeric uid 1000 as the mapped media
id (host 1100). If that uid is an unrelated login, stop. Do not chown
the host directories.

## Terraform

From `terraform/proxmox`, with `PM_API_URL`, `PM_API_TOKEN_ID`, and
`PM_API_TOKEN_SECRET` in the environment. Do not put them in git.
`TF_VAR_lxc_root_password` comes from a secret store when this create
should set the console root password. `TF_VAR_ct182_ssh_public_keys` is
optional and is public keys only.

```bash
terraform fmt -check
terraform init
terraform plan -out=tfplan
terraform show tfplan
```

The plan should add `proxmox_lxc.ct_182` and leave every existing guest
unchanged. A destroy or a replace stops here. On the node, as root,
before the guest is created, confirm the three existing source
directories. If any test fails, stop. Do not create them:

```bash
test -d /media/data/media
test -d /media/data/torrents
test -d /media/data/usenet
```

Apply only the reviewed plan file:

```bash
terraform apply tfplan
```

The guest stays stopped. Do not commit `tfplan`.

## Ansible

Dockge listens on `10.10.0.82:5001` only. The arr stack is
`/opt/stacks/arr/compose.yaml`. The role copies it from
`ansible/roles/arr/files/compose.yaml`. It does not start gluetun,
qBittorrent, or Watchtower when `/opt/stacks/arr/.env` is missing, empty,
or not mode `0600` owned by root. It never runs `docker compose config`.

```bash
cd ansible
cp inventory/blr.yml.example inventory/blr.yml
ansible-playbook --syntax-check playbooks/arr.yml
```

Syntax check does not connect. A live run is a separate step, after the
guest is started and the tun and mounts are in place:

```bash
ansible-playbook playbooks/arr.yml
```

`site.yml` does not import this playbook. The example inventory lists
`arr-blr-lxc`, so a ping of `all` tries `.82` and fails until the guest
exists.

## Env file

Values stay on the guest. The committed file is
`ansible/roles/arr/files/.env.example`, names only. Paste real lines on
the BRL root console. A literal `$` in a secret must be quoted for
Compose, or written as `$$`.

```bash
pct exec 182 -- bash -c 'install -d -o root -g root -m 0700 /opt/stacks/arr; umask 077; cat > /opt/stacks/arr/.env; chmod 600 /opt/stacks/arr/.env'
```

End the paste with Ctrl-D. Confirm owner, mode, and that the file is
non-empty. Do not print it. Leave unused names out, so a blank line does
not override a gluetun default. `PUID` and `PGID` in the file do not
change the containers. The compose file pins them at 1000, and the volume
paths are literals.

These four names must be non-empty or the play refuses to start the stack:

- `VPN_SERVICE_PROVIDER`
- `VPN_TYPE`
- `WIREGUARD_PRIVATE_KEY`
- `WATCHTOWER_NOTIFICATION_URL`

Gluetun's `env_file` is this same file, so the notification URL is also in
that container's environment. Watchtower is given only
`WATCHTOWER_NOTIFICATION_URL`, not the VPN keys. Do not copy `docker
inspect` output into git or chat.

`WATCHTOWER_NOTIFICATION_URL` is a shoutrrr SMTP URL. The recipient,
set only in that private file, is
`deathscythe+watchtower@mail.grokbot.com`. In the query string write the
`+` as `%2B` and the `@` as `%40`. Username, password, host, port, and the
from-address stay inside that URL. Do not commit them:

```text
smtp://USERNAME:PASSWORD@HOST:PORT/?from=FROM&to=deathscythe%2Bwatchtower%40mail.grokbot.com
```

Re-run `ansible-playbook playbooks/arr.yml` after the file exists. The
play enforces mode `0600` and then starts the stack. A failed start is
censored in Ansible output. On the guest, rerun the compose command below
only if you need the error, and do not copy the output into git or chat.

## Images and restarts

Pins:

| Service | Image |
|---|---|
| gluetun | `qmcgaw/gluetun@sha256:44a82caf5b866193bfdfe8ffffbb11b20ce8138a917466c2c9bff9a52861c1a5` |
| qBittorrent | `lscr.io/linuxserver/qbittorrent@sha256:05c1454f9a32967affc1f34f67f8cc0cc57dd805dca45489fe797095a6286556` |
| Watchtower | `containrrr/watchtower@sha256:f9086bfda061100361fc2bacf069585678d760d705cf390918ccdbda8a00980b` (1.7.1 amd64) |
| Dockge | `louislam/dockge@sha256:edee39b74f238378ebfe0d9d12b3833f9d1e123aea9dfaf5149ad45c9afe2527` (1.5.0 amd64) |

`pull_policy` is `missing`. A second Ansible run does not move off these
digests. bael tracked `:latest` and refreshed the VPN with a pull and
redeploy. This stack does not.

Gluetun's own healthcheck restarts the VPN connection inside the running
container (`HEALTH_RESTART_VPN` defaults on). qBittorrent keeps that
network namespace, so a tunnel drop does not need a recreate. Do not
redeploy for that.

To restart the VPN without upgrading, on the guest:

```bash
cd /opt/stacks/arr
docker compose up -d --force-recreate gluetun qbittorrent
```

That uses the pinned digests. It does not recreate Watchtower. After a
kill-switch test, recreate qBittorrent with this same command so it
attaches to the new gluetun namespace, then check the egress IP again.

To bump an image: change the digest in
`ansible/roles/arr/files/compose.yaml`, then re-run
`ansible-playbook playbooks/arr.yml`. Compose pulls the new digest
because it is not local. Do not `docker pull` a `:latest` tag. Watchtower
will mail when a newer image exists. It will not apply that image.

## Watchtower

Watchtower is the third service in the arr compose. It is not on
gluetun's network, so mail uses the CT's LAN path and a stopped gluetun
does not remove Watchtower's namespace.

- `WATCHTOWER_MONITOR_ONLY` is `true` in the compose file. Container
  labels cannot override it (`WATCHTOWER_LABEL_TAKE_PRECEDENCE` is
  false). It never updates a container.
- There is no `WATCHTOWER_LABEL_ENABLE` and no `WATCHTOWER_SCOPE`, and
  the service has no container-name arguments. Watchtower therefore
  monitors every running container on this Docker daemon. Later arr apps
  added to the stack are covered without a label. Dockge is included.
  A container that is not running is not scanned.
- The schedule is `0 0 6 * * *` with `TZ=America/Chicago` (06:00 CT).
  A quiet day does not send a report. The first start does send one mail,
  which is the SMTP check. Later mail is an available image update.
- `DOCKER_API_VERSION` is `1.44` in the compose file. Watchtower 1.7.1
  defaults to Docker API 1.25. Docker 29 rejects that client and the
  container crash-loops. Do not leave this to `.env`.
- The Docker socket is mounted read-only. If Watchtower cannot list
  containers, stop. Do not remount the socket read-write in order to let
  it update.
- No Watchtower port is published.
- Mail is submitted to Postfix on the PVE host. The recipient in the
  private `.env` is `deathscythe+watchtower@mail.grokbot.com`. The host
  Postfix change and the node firewall rule (IN ACCEPT tcp/25 from
  `10.10.0.82/32` to `10.10.0.21/32`, `policy_in` stays DROP) are in
  [pve-postfix-arr.md](pve-postfix-arr.md). That procedure does not edit
  Gmail credentials.

```bash
docker logs watchtower --tail 50
```

Do not copy those logs into git if they ever contain a URL or a secret.
Confirm they show a scan, not an API 1.25 error, and that the startup
mail arrived at `deathscythe+watchtower@mail.grokbot.com`.

## VPN validation

Run this only after `.env` is in place and the stack is up. qBittorrent
uses `network_mode: service:gluetun`, and its WebUI is published on
gluetun at `10.10.0.82:8085`. Port 6881 is not published. Use the client
already in the pinned image. Do not install extra tools. Do not print
`.env`.

```bash
docker inspect --format '{{.HostConfig.NetworkMode}}' qbittorrent
docker exec qbittorrent curl -fsS --max-time 15 https://ifconfig.io/ip
```

The network mode must be gluetun's container. The IP command must succeed
and the body must be non-empty. It must not be `72.221.51.177`. A
different string is not enough on its own: it has to be the provider
egress you expect for this tunnel.

Direct IP, so a DNS failure is separate from a blocked route:

```bash
docker exec qbittorrent curl -fsS --max-time 10 https://1.1.1.1/cdn-cgi/trace
```

IPv6 must not egress. This command failing is the pass:

```bash
docker exec qbittorrent curl -6 -fsS --max-time 10 https://ifconfig.io/ip
```

DNS: the hostname lookup above must succeed through the tunnel. In
`docker logs gluetun`, the resolver must be the one selected in `.env`,
not `10.10.0.53` and not the ISP resolver. Reading `/etc/resolv.conf`
alone is not the check. Do not paste logs that contain a key or endpoint
secret.

Kill switch. Stop gluetun. Do not stop qBittorrent first.

```bash
docker stop gluetun
docker inspect --format '{{.State.Status}}' qbittorrent
```

If qBittorrent is still running, both of these must fail quickly:

```bash
docker exec qbittorrent curl -fsS --max-time 5 https://ifconfig.io/ip
docker exec qbittorrent curl -fsS --max-time 5 https://1.1.1.1/cdn-cgi/trace
```

LAN access to port 8085 lives in gluetun's namespace, so it drops with
gluetun. That is not a path around the filter. If qBittorrent exited
because the namespace went away, write that down. The exit alone is not
proof the firewall blocked traffic. Start gluetun again and recreate
qBittorrent with the force-recreate command above. Check the egress IP
again before any download.

Port forwarding is N/A unless the provider assigns a port. Publishing a
port on the LAN is not VPN ingress. Do not assume a port-forward feature,
and do not switch provider to get one.

Leave qBittorrent paused. Do not load bael's queue.

## Console autologin

CT 182 is on the console-autologin allowlist as Ubuntu 26.04
(`arr-blr-lxc` at `10.10.0.82`). The drop-in is the existing opt-in role.
It does not set a password, and it does not replace vendor `TTYPath`.
`site.yml` does not import `playbooks/console-autologin.yml`. The example
inventory group stays empty, so a copied inventory does not select the
guest. Opening this change does not run the playbook. See
[ansible/README.md](../../ansible/README.md).

## Later phases

After this gate, and only in a later change:

- On CT 182, still behind gluetun: Prowlarr, Sonarr, Radarr, Lidarr,
  Bazarr, and FlareSolverr. Keep FlareSolverr. Do not add Byparr. Pin
  FlareSolverr's digest in that change. Jackett and Pinchflat are not
  part of the move.
- Jellyseerr goes on CT 183 (`10.10.0.83`), not in this VPN namespace.
- Root folders are `/data/media/{movies,tv,music}`. qBittorrent keeps
  `/data/downloads` (host `/media/data/torrents`). `/data/usenet` stays
  unused until a later phase.
- Caddy on CT 250 and AdGuard rewrites wait for the NetTit handoff. No
  public route for FlareSolverr or the gluetun control port.

## Backups

`mp0`, `mp1`, and `mp2` are `backup=0`, so vzdump does not archive the
media tree, the torrents tree, or the usenet tree. Do not exclude CT 182
itself because phase 1 is still waiting on `.env`.

`forge-backup-pbs-hdd` has no guest excludes, so the rootfs is included
once the guest exists. `forge-backup-ssd` is an explicit id list. Add 182
to that job by hand when the guest exists. This repo does not edit
`/etc/pve/jobs.cfg`. See [pbs.md](pbs.md).

No Pulse rules live in this repo. The Ansible skip is the env wait. It
does not hide a disk or backup failure.

## Secrets

Nothing in git holds a VPN key, an SMTP password, an API token, or a
filled `.env`. `ansible/roles/arr/files/.env` is gitignored. The example
file is names and blank values.
