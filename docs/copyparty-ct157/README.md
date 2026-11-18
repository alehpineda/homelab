# copyparty on CT157 (files-blr-lxc): pilot

LAN-only web file manager for the ZFS media datasets. It's at https://files.alehpineda.com, reached through Caddy CT250 on `.250` only.
- `.251`, NetBird (`.50`/`.51`) and direct `:3923` access are refused.
- Owner approval: 2026-11-17 4:33 PM CT (card t973s5107) for full rights including delete. Arcade was dropped (card t976s5122), so mp7 stays unused.

## Files (copies of the live CT157 files)
| Repo | CT157 path | Owner/mode |
|---|---|---|
| `copyparty.conf` | `/etc/copyparty/copyparty.conf` | root:media 0640 |
| `copyparty.service` | `/etc/systemd/system/copyparty.service` | root:root 0644 |

- The account hash is **not** in git.
- The password lives in 1Password and in Forge's box secret `copyparty/files-admin.txt`.
- To re-hash, run this as root on CT157 and type the password twice. The plaintext never touches disk.
  ```
  cd /var/lib/copyparty && runuser -u media -- env XDG_CONFIG_HOME=/var/lib/copyparty/.config python3 /opt/copyparty/copyparty-sfx.py -c /etc/copyparty/copyparty.conf --ah-cli
  ```
- The salt is in `/var/lib/copyparty/.config/copyparty/ah-salt.txt`. A hash only works with that salt.

## Install facts
- Debian 13 packages: python3 (3.13.5), python3-argon2 (21.1.0-3), curl, ca-certificates.
- Service user `media` is 1000:1000. It maps to host `media` 1100:1100 through a per-mount idmap on mp0–mp5.
- Binary: `/opt/copyparty/copyparty-sfx.py` **v1.20.26**, pinned with no auto-update.
  - sha256 `8f9a0def8a9c15252a06395781ec083372043b60caa80fb33c3d6dafa7f1b40a`, which equals the GitHub release asset digest.
- `hist` (DB and thumbnails) lives at `/var/lib/copyparty/hist` on the rootfs. No `.hist` folders go into the media datasets.
- `RestrictAddressFamilies` includes `AF_NETLINK`. Without it, copyparty's adapter listing logs `Errno 97` at startup.

## Verification (2026-11-17, 6:10–6:13 PM CT)
All checks passed:
- It listens on `10.10.0.57:3923` only.
- From LAN CT176 through `.250`:
  - Login page: 200. Anonymous `/movies/`: 403. Wrong password: 403. Right password: `/movies/?ls` returns 200 with 420 dirs.
  - Writes in music: PUT gives 201 and the file is `1100:1100` on the host. Move gives 201 and the renamed file is `1100:1100`. Delete gives 200 and the file is gone on the host.
  - A PUT to metube is refused with 403 (no write access, and the bind is ro).
- `.251` is aborted. NetBird from the box (arriving as `.50`) is aborted. A direct `:3923` connection from CT176 times out (PVE firewall).
- The copyparty log records the real LAN client (`10.10.0.76`), so the x-forwarded-for setup is correct.
- After `systemctl restart copyparty` the service is active, with RSS about 65 MB and a cgroup peak of about 88 MB during the first index. The CT has 1 GiB.

## Snapshot / undo
- The owner took `zfs snapshot -r media/data/media@pre-copyparty-20261117` at 6:07 PM CT, covering 12 datasets.
- Copyparty deletes are permanent. Restore single files from `<dataset>/.zfs/snapshot/pre-copyparty-20261117/`.
- Dropping the snapshot later is a delete and needs the owner's yes.
