# Runbook: PVE guest firewall on BRL

Outer, host-enforced firewall for CTs on `barbatoslupusrex`. Root inside a CT
cannot flush it. The in-guest nft tables (inner layer) carry the same
allowlist, so a packet must pass both.

Source of truth: `ansible/group_vars/all/fw_allowlists.yml`.
Role: `ansible/roles/pve_guest_firewall`. Playbook: `ansible/playbooks/pve-guest-firewall.yml`.

## What is live (2026-11-09, 18:52–19:01 CT)

Cluster objects (cluster firewall and node rules unchanged):

| Object | Value |
|---|---|
| ipset `caddy` | 10.10.0.250, 10.10.0.251 |
| ipset `nb_routers` | 10.10.0.50, 10.10.0.51 |
| aliases | grafana .71, prometheus .72, firecrawl .64, n8n .70, seerr .83 |
| group `ct_base` | IN SSH ACCEPT from `+management` (10.10.0.0/24, 100.85.0.0/16); IN icmp ACCEPT |

Per CT: options `enable 1, policy_in DROP, policy_out ACCEPT, ipfilter 1, log_level_in nolog`, `GROUP ct_base`, then:

| CT | Extra IN ACCEPT |
|---|---|
| 164 firecrawl | tcp 3002 from +caddy, n8n; udp 51820 (NetBird) |
| 175 ollama | tcp 11434 from +caddy, firecrawl, +nb_routers, n8n |
| 172 prometheus | tcp 9090 from grafana |
| 173 loki | tcp 3100, 9095 from grafana |
| 174 pve-exporter | tcp 9221 from prometheus |
| 180 jellyfin | tcp 8096, udp 7359, udp 1900 from 10.10.0.0/24; udp 51820 (NetBird) |
| 181 metube | tcp 8081 from +caddy |
| 182 arr | tcp 5001,6767,7878,8085,8686,8989,9696 from +caddy; tcp 7878,8989 from seerr |
| 183 seerr | tcp 5055 from 10.10.0.0/24 |

Not rolled out (no rules defined yet, or needs NetTit): 150/151 NetBird
routers, 153/154/155/156 DNS, 160, 161, 162, 165, 169, 170, 171, 176, 250 Caddy.
CT250 note: replies sourced from .251 leave via eth0, so `ipfilter: 1` on net0
would drop them; it needs a custom `ipfilter-net0` ipset (.250 + .251) and
udp/443 (HTTP/3) before rollout.

## Apply one CT

```bash
cd ansible
ansible-playbook playbooks/pve-guest-firewall.yml \
  -e '{"pve_fw_rollout":[164]}' -e @/path/outside/git/pve-fw-token.yml --check
ansible-playbook playbooks/pve-guest-firewall.yml \
  -e '{"pve_fw_rollout":[164]}' -e @/path/outside/git/pve-fw-token.yml
```

The token file holds `pve_fw_token_id` and `pve_fw_token_secret` for
`forge@pve!fw` (role `ForgeFirewall`: Sys.Audit, Sys.Modify, VM.Audit,
VM.Config.Network). The token lacks `SDN.Use` on
`/sdn/zones/localnetwork/<bridge>`, so the NIC step (`firewall=1`) runs
`sudo pct set` on inventory host `pve` (grokops). Setting the flag re-plugs the
host veth through `fwbr<vmid>i0`: ~1 s blip, same MAC/IP, no CT restart.

The role refuses to overwrite a CT whose live rules differ from the vars file.

## Verify

- SSH to the CT from the LAN still works; `pct exec` works.
- The allowed caller reaches the app port; the Caddy URL returns 200/302.
- A LAN host not in the allowlist (CT176 `scout`) gets a timeout.
- Prometheus targets all `up`; NetBird peers 164/180 `netbird status` connected
  and mesh reachability unchanged.

## Rollback (no restart)

One CT:

```bash
pvesh set /nodes/barbatoslupusrex/lxc/<VMID>/firewall/options --enable 0
# or via API: PUT /nodes/barbatoslupusrex/lxc/<VMID>/firewall/options enable=0
```

All rolled-out CTs, from a box with the token:

```bash
for v in 164 175 172 173 174 180 181 182 183; do
  curl -sk -X PUT -H "Authorization: PVEAPIToken=$TID=$SECRET" \
    -d enable=0 https://10.10.0.21:8006/api2/json/nodes/barbatoslupusrex/lxc/$v/firewall/options
done
```

With `enable 0` the fwbr stays but passes everything. To remove the NIC flag
too: `pct set <VMID> -net0 <same string without firewall=1>`.
