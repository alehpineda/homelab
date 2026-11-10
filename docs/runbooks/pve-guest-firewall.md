# Runbook: PVE guest firewall on BRL

Outer, host-enforced firewall for CTs on `barbatoslupusrex`. Root inside a CT
cannot flush it. The in-guest nft tables (inner layer) carry the same
allowlist, so a packet must pass both.

Source of truth: `ansible/group_vars/all/fw_allowlists.yml`.
Role: `ansible/roles/pve_guest_firewall`. Playbook: `ansible/playbooks/pve-guest-firewall.yml`.

## What is live (wave 1 — 2026-11-09, 18:52–19:01 CT)

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

## Wave 2 (DRAFT — no apply)

Aliases added in vars (not live until apply): `adguard_a` .53, `adguard_b` .55, `adguardsync` .56, `unbound` .54.

| CT | Extra IN ACCEPT | Notes |
|---|---|---|
| 153 adguard A | udp/tcp 53 from +management; tcp 80 from +caddy; tcp 443 + tcp/udp 853 from +management | DNS must stay open to whole LAN + NetBird overlay. Sync from .56 hits :443. |
| 154 unbound | udp/tcp 5335 from adguard_a, adguard_b | Keep A→Unbound and B→Unbound working. |
| 155 adguard B | udp/tcp 53 from +management; tcp 80 from adguardsync | On **vmbr1**. No TLS. Sync A→B every 15 min. |
| 156 adguardsync | (ct_base only) | Outbound client; no app listen. |
| 160 searxng | tcp 8888 from +caddy; udp 51820 | NetBird peer. |
| 161 vaultwarden | tcp 8000 from +caddy; udp 51820 | NetBird peer. Caddy → https://.61:8000. |
| 162 openbao | tcp 8200 from +caddy | 8201 stays closed. |
| 165 honcho | (ct_base only) | Placeholder; no app listen today. |
| 169 postiz | tcp 80 from +caddy | nginx fronts 3000/4200; leave those closed at PVE. |
| 170 n8n | tcp 5678 from +caddy, +nb_routers | Confirm gremory MCP RP needs +nb_routers before apply. |
| 171 grafana | tcp 3000 from +caddy | |
| 176 forge-ws | tcp 3389 from +management; udp 51820 | RDP + NetBird peer. |
| 250 caddy | tcp 80/443 + udp 443 from +management | **Requires** guest ipset `ipfilter-net0` = {.250,.251} before enable. Never open 2019. Both net0 and net1 get `firewall=1`. |

Excluded: 150/151 NetBird routers (NetTit present). Stopped 166–168.

### Wave 2 apply order (when yes)

One CT at a time, soak ≥5 min, stop on first failure:

1. **154 unbound** (narrow callers; AdGuard still works if this fails closed only for A/B)
2. **156** (ct_base only; noop risk)
3. **153 adguard A** — verify LAN dig, mesh dig, Caddy adguard UI, sync still updates B
4. **155 adguard B** — verify LAN dig via .55, sync pull still 200
5. **165** → **162** → **161** → **160** → **169** → **171** → **170** → **176**
6. **250 caddy last** — create `ipfilter-net0` first (role does this), then rules/options, then both NICs. Probe every Caddy name + QUIC.

### Wave 2 test matrix

| Check | How |
|---|---|
| DNS A | From LAN host: `dig @10.10.0.53 alehpineda.com`; from CT176 same; from a mesh peer (or via nb router) |
| DNS B | `dig @10.10.0.55 …` |
| Unbound | From CT153/155 only: `dig @10.10.0.54 -p 5335 …`; from CT176 must time out |
| Sync | Wait ≤15 min or restart adguardhome-sync; B rewrite count matches A |
| Caddy E2E | `--resolve name:443:10.10.0.250` and `:10.10.0.251` for *arr names; HTTP/3 if client supports |
| App via Caddy | searxng, vault, openbao, postiz, n8n, grafana, adguard |
| RDP | LAN client → .76:3389 |
| Scout closed | CT176 → blocked app ports (8888/8000/8200/80-on-169/5678/3000/443-on-non-caddy) time out |
| SSH | Still open from management on every rolled CT |

### Wave 2 rollback

Same as wave 1 — flip `enable=0` per CT (no restart):

```bash
# example
curl -sk -X PUT -H "Authorization: PVEAPIToken=$TID=$SECRET" \
  -d enable=0 \
  https://10.10.0.21:8006/api2/json/nodes/barbatoslupusrex/lxc/<VMID>/firewall/options
```

CT250: if ipfilter drops .251 replies, `enable=0` first; optionally delete guest ipset `ipfilter-net0` after.

## Apply one CT

```bash
cd ansible
ansible-playbook playbooks/pve-guest-firewall.yml \
  -e '{"pve_fw_rollout":[164]}' -e @/path/outside/git/pve-fw-token.yml --check
ansible-playbook playbooks/pve-guest-firewall.yml \
  -e '{"pve_fw_rollout":[164]}' -e @/path/outside/git/pve-fw-token.yml
```

Token `forge@pve!fw` (role `ForgeFirewall`: Sys.Audit, Sys.Modify, VM.Audit,
VM.Config.Network, SDN.Use). NIC `firewall=1` goes through the API by default
(`pve_fw_nic_via_api: true`). Set that false to fall back to `sudo pct set` on
inventory host `pve`. Setting the flag re-plugs the host veth through
`fwbr<vmid>iN`: ~1 s blip, same MAC/IP, no CT restart.

The role refuses to overwrite a CT whose live rules differ from the vars file.

## Verify

- SSH to the CT from the LAN still works; `pct exec` works.
- The allowed caller reaches the app port; the Caddy URL returns 200/302.
- A LAN host not in the allowlist (CT176 `scout`) gets a timeout.
- Prometheus targets all `up`; NetBird peers `netbird status` connected
  and mesh reachability unchanged.

## Rollback (no restart)

One CT:

```bash
pvesh set /nodes/barbatoslupusrex/lxc/<VMID>/firewall/options --enable 0
# or via API: PUT /nodes/barbatoslupusrex/lxc/<VMID>/firewall/options enable=0
```

All wave-1 CTs, from a box with the token:

```bash
for v in 164 175 172 173 174 180 181 182 183; do
  curl -sk -X PUT -H "Authorization: PVEAPIToken=$TID=$SECRET" \
    -d enable=0 https://10.10.0.21:8006/api2/json/nodes/barbatoslupusrex/lxc/$v/firewall/options
done
```

With `enable 0` the fwbr stays but passes everything. To remove the NIC flag
too: `pct set <VMID> -net0 <same string without firewall=1>`.
