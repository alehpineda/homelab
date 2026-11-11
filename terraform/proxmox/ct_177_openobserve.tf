# CT 177 openobserve-blr-lxc. OpenObserve OSS log/metrics store, side by side
# with Loki CT173. Declared 2026-11-11. This file does not apply it.
# See /workspace/forge/plans/openobserve-loki-plan-20261111.md (Forge).
# Standing pref: LXC via IaC. Further apply still needs its own approval.
#
# Install method (day-1, after create): ansible role `openobserve`
# (playbooks/logging.yml). It reproduces the community-scripts
# install/openobserve-install.sh layout (/opt/openobserve binary +
# openobserve.service) but pins v1.1.2 with a sha256 check; the script
# floats to GitHub "latest", which is v1.2.0-rc1 on 2026-11-11. The host
# ct/openobserve.sh is never run (it would create a second CT). OSS build,
# telemetry off, 30-day retention, memory caps. Root/ingest credentials are
# read from controller secret files at apply time and never committed.
#
# Ports: 5080 HTTP (UI + Loki push + Prometheus remote_write). 5081 gRPC is
# not opened at the PVE guest firewall. Ingress: Caddy 10.10.0.250 (admin
# only) -> http://10.10.0.77:5080.
#
# Sizing: script default 1c/512M/3G is too small for compaction + DataFusion
# at 30 days. 2 cores / 2048 MiB / 512 swap; root 8G and a 30G data volume,
# both on data2 (not local-lvm: 64G, lvextend pending). Both disks are in
# vzdump forge-backup-ssd (backup = true, owner decision 2026-11-11).
#
# Template is the Debian 13 vztmpl already on BRL local. nameserver is
# AdGuard A/B. timezone America/Chicago is a pct setting and is not in the
# Telmate proxmox_lxc schema. After create: pct set 177 --timezone
# America/Chicago, then pct start 177. No IPv6 on this NIC.
#
# features.nesting is create-time here because features is in
# ignore_changes, same as ct_183 / ct_199.
resource "proxmox_lxc" "ct_177" {
  target_node  = var.pm_node
  vmid         = 177
  hostname     = "openobserve-blr-lxc"
  description  = "OpenObserve OSS v1.1.2 (logs + Prometheus remote_write). Side by side with Loki CT173. :5080 via Caddy .250."
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 2
  memory       = 2048
  swap         = 512
  tags         = "community-script;logs;monitoring;storage-data2"
  nameserver   = "10.10.0.53 10.10.0.55"
  # Create-time only. Ignored after create. Public keys only.
  ostemplate      = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ssh_public_keys = var.ct177_ssh_public_keys
  password        = var.lxc_root_password
  start           = false

  features {
    nesting = true
  }

  rootfs {
    storage = var.pm_storage
    size    = "8G"
  }

  # OpenObserve ZO_DATA_DIR (parquet, WAL, SQLite metadata). Included in
  # vzdump so a restore brings back streams, dashboards, alerts, and users.
  mountpoint {
    key     = "0"
    slot    = 0
    storage = var.pm_storage
    mp      = "/opt/openobserve/data"
    size    = "30G"
    backup  = true
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "02:46:4F:52:01:77"
    ip     = "10.10.0.77/24"
    gw     = "10.10.0.1"
  }

  lifecycle {
    prevent_destroy = true
    # ostemplate/password/ssh_public_keys/start/features: create-time only.
    # features is ignored so a later read does not drop nesting.
    # target_node, cmode, network, mountpoint, rootfs[0].storage: Telmate
    # 3.0.2-rc10 import does not read these back, so they would force
    # replacement. See docs/runbooks/terraform-import.md.
    # net0 firewall=1 and the PVE guest firewall (.fw rules/options) are owned by
    # ansible role pve_guest_firewall (group_vars/all/fw_allowlists.yml).
    # `network` stays in ignore_changes so Terraform never flaps the flag.
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description, features,
      target_node, cmode, network, mountpoint, rootfs[0].storage,
    ]
  }
}
