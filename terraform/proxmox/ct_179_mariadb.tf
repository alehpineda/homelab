# CT 179 mariadb-blr-lxc. MariaDB for Uptime Kuma 2.5.11 (CT184) only.
# Declared 2026-11-16. This file does not apply it.
# Plan: /workspace/forge/plans/2026-11-16-obs-databases.md (Forge).
# Owner: Kuma to MariaDB with history loss accepted (t927u, 4:47 PM CT);
# separate LXC from Postgres (t928u, 4:48 PM CT); follow community-scripts
# (t929u, 4:49 PM CT). Merge, apply and the migration need their own yes.
#
# Install method (day-1, after create): ansible role `mariadb`
# (playbooks/databases.yml --tags db_mariadb). It mirrors community-scripts
# install/mariadb-install.sh: Debian 13 distribution packages
# mariadb-server + mariadb-client (setup_mariadb with MARIADB_VERSION
# "latest" = distro packages), port 3306. The host ct/mariadb.sh is never
# run. Deviations: bind 127.0.0.1 + 10.10.0.79 (script comments out
# bind-address = all interfaces), the kuma user is limited to 10.10.0.84,
# error log stays on journald (house JSON pipeline), no phpMyAdmin.
#
# Sizing: script baseline 1c/1024M/4G, kept for CPU/RAM. Kuma's kuma.db is
# 14.9 MB + 7.7 MB WAL (2026-11-16) with 57 monitors; innodb_buffer_pool
# 256M. Root 6G (packages + exporter + Alloy + local dumps under
# /var/backups/mariadb) and an 8G data volume at /var/lib/mysql for
# heartbeat growth, both on data2.
#
# startup order=2: after CT178, before CT184 (no order) at boot.
# timezone: pct set 179 --timezone America/Chicago after create.
resource "proxmox_lxc" "ct_179" {
  target_node  = var.pm_node
  vmid         = 179
  hostname     = "mariadb-blr-lxc"
  description  = "MariaDB (Debian 13 packages, community-scripts layout). Uptime Kuma CT184 only. LAN 3306 from .84 only."
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  startup      = "order=2,up=20"
  cores        = 1
  memory       = 1024
  swap         = 512
  tags         = "community-script;database;monitoring;storage-data2"
  nameserver   = "10.10.0.53 10.10.0.55"

  ostemplate      = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ssh_public_keys = var.ct179_ssh_public_keys
  password        = var.lxc_root_password
  start           = false

  features {
    nesting = true
  }

  rootfs {
    storage = var.pm_storage
    size    = "6G"
  }

  mountpoint {
    key     = "0"
    slot    = 0
    storage = var.pm_storage
    mp      = "/var/lib/mysql"
    size    = "8G"
    backup  = true
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "02:46:4F:52:01:79"
    ip     = "10.10.0.79/24"
    gw     = "10.10.0.1"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description, features,
      target_node, cmode, network, mountpoint, rootfs[0].storage,
    ]
  }
}
