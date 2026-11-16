# CT 178 postgres-blr-lxc. PostgreSQL 17 for the observability stack:
# OpenObserve CT177 metadata first, then Grafana CT171 after a 7-day soak.
# Declared 2026-11-16. This file does not apply it.
# Plan: /workspace/forge/plans/2026-11-16-obs-databases.md (Forge).
# Owner: design approved 4:47 PM CT Nov 16 (t927u, Forge 1:1); two LXCs
# (t928u, 4:48 PM CT); follow community-scripts (t929u, 4:49 PM CT).
# Merge, apply and each migration still need their own yes.
#
# Install method (day-1, after create): ansible role `postgresql`
# (playbooks/databases.yml --tags db_postgres). It mirrors community-scripts
# install/postgresql-install.sh (Debian 13, PGDG apt repo, PG 17 default,
# its postgresql.conf/pg_hba.conf layout, ssl on with the snakeoil cert).
# The host ct/postgresql.sh is never run (it would create a second CT).
# Deviations from the script (all in the role): PG 17 pinned instead of the
# interactive prompt; listen on localhost + 10.10.0.78 only; pg_hba allows
# only hostssl scram-sha-256 per app from its client IP (script: md5 from
# 0.0.0.0/0); logs to journald via syslog (house JSON pipeline); no Adminer.
#
# Sizing: script baseline 1c/1024M/4G. This CT: 2 cores / 2048 MiB / 512
# swap; root 8G and a 16G data volume at /var/lib/postgresql, both on data2
# (not local-lvm: 64G, lvextend pending). Measured 2026-11-16: grafana.db
# 2.3 MB, O2 metadata.sqlite 52.5 MB + 5.7 MB WAL. 2 cores for O2's
# file_list polling + pg_dump/autovacuum; 2 GiB for shared_buffers 512MB.
#
# startup order=1: PVE starts ordered guests first, so CT178 is up before
# CT171/177 (no startup order set) at boot. Template is the Debian 13
# vztmpl already on BRL local (same as CT177). timezone America/Chicago is
# a pct setting, not in the Telmate schema: after create, pct set 178
# --timezone America/Chicago, then pct start 178.
resource "proxmox_lxc" "ct_178" {
  target_node  = var.pm_node
  vmid         = 178
  hostname     = "postgres-blr-lxc"
  description  = "PostgreSQL 17 (community-scripts layout). OpenObserve CT177 meta, Grafana CT171. LAN 5432 from .71/.77 only."
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  startup      = "order=1,up=30"
  cores        = 2
  memory       = 2048
  swap         = 512
  tags         = "community-script;database;monitoring;storage-data2"
  nameserver   = "10.10.0.53 10.10.0.55"

  ostemplate      = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ssh_public_keys = var.ct178_ssh_public_keys
  password        = var.lxc_root_password
  start           = false

  features {
    nesting = true
  }

  rootfs {
    storage = var.pm_storage
    size    = "8G"
  }

  mountpoint {
    key     = "0"
    slot    = 0
    storage = var.pm_storage
    mp      = "/var/lib/postgresql"
    size    = "16G"
    backup  = true
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "02:46:4F:52:01:78"
    ip     = "10.10.0.78/24"
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
