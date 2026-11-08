# Runbook: PVE Postfix for CT 182 Watchtower

Root procedure on `barbatoslupusrex` (`10.10.0.21`). Watchtower on CT 182
(`10.10.0.82`) submits mail to this host. Opening this note does not run
it. Do not merge or apply it from the pull request alone.

This changes three Postfix parameters. It does not read, print, or edit
Gmail relay credentials. Leave these alone:

- `/etc/postfix/sasl_passwd` and `/etc/postfix/sasl_passwd.db`
- `relayhost`
- `smtp_sasl_auth_enable`
- `smtp_sasl_password_maps`
- `smtp_sasl_security_options`
- `smtp_tls_security_level` and any other SASL or TLS relay setting

## Values

| Parameter | Value |
|---|---|
| `inet_interfaces` | `127.0.0.1,[::1],10.10.0.21` |
| `mynetworks` | `127.0.0.0/8,[::1]/128,10.10.0.82/32` |
| `smtpd_client_restrictions` | `permit_mynetworks,reject` |

The host listens on loopback and on its LAN address. SMTP clients are
localhost and CT 182 only. Everyone else is rejected. Local `sendmail`
on the host does not pass through `smtpd`, so the Gmail relay path for
mail the host itself submits stays as it is.

## Backup

On the node, as root. If the backup file already exists, stop. Do not
overwrite it.

```bash
test ! -e /etc/postfix/main.cf.bak-arr-phase1
cp -a /etc/postfix/main.cf /etc/postfix/main.cf.bak-arr-phase1
postconf -n > /root/postfix-postconf-n.bak-arr-phase1
chmod 600 /root/postfix-postconf-n.bak-arr-phase1
```

Confirm the backup is non-empty and that `sasl_passwd` was not copied
into git or into this session's notes. Do not `cat` credential files.

## Apply

`postconf -e` writes only the three keys. `inet_interfaces` does not
take effect on `postfix reload`; the listeners change only on a restart.
`set -e` stops the block if `postfix check` fails, before the restart.

```bash
set -e
postconf -e 'inet_interfaces = 127.0.0.1,[::1],10.10.0.21'
postconf -e 'mynetworks = 127.0.0.0/8,[::1]/128,10.10.0.82/32'
postconf -e 'smtpd_client_restrictions = permit_mynetworks,reject'
postfix check
systemctl restart postfix
```

## Verify

```bash
postconf inet_interfaces mynetworks smtpd_client_restrictions
ss -H -lnt sport = :25
systemctl is-active postfix
```

`inet_interfaces` is `127.0.0.1,[::1],10.10.0.21`. `mynetworks` is
`127.0.0.0/8,[::1]/128,10.10.0.82/32`. `smtpd_client_restrictions` is
`permit_mynetworks,reject`. Port 25 is listening on those three
addresses and not on `0.0.0.0` or `::`.

From CT 182, after `/opt/stacks/arr/.env` exists, Watchtower's startup
mail is the end-to-end check. The recipient in that private file is
`deathscythe+watchtower@mail.grokbot.com`. Do not print the URL.

## Rollback

```bash
set -e
cp -a /etc/postfix/main.cf.bak-arr-phase1 /etc/postfix/main.cf
postfix check
systemctl restart postfix
postconf inet_interfaces mynetworks smtpd_client_restrictions
```

The restored file is the pre-change `main.cf`. Gmail credential files
were not part of the backup and are not restored or deleted. If
`postfix check` fails after the copy, stop and do not start Postfix
with a half-written config.

## Host firewall

The node firewall already has this rule. It is not a Terraform resource.
Telmate is not used for host firewall rules. The same kind of rule for
node_exporter is recorded in [blr-monitoring.md](../blr-monitoring.md).

```text
IN ACCEPT -source 10.10.0.82/32 -dest 10.10.0.21/32 -p tcp -dport 25 -comment CT182 Watchtower SMTP to PVE relay
```

Direction `in`, action `ACCEPT`, protocol `tcp`, destination port `25`,
source `10.10.0.82/32`, destination `10.10.0.21/32`, comment
`CT182 Watchtower SMTP to PVE relay`. Identity is those fields. Rule
position is not part of the match.

`policy_in` stays `DROP`. That is the default for traffic that matches
no rule. This procedure reads it and does not set it. If it is anything
else, stop. Do not enable or disable the firewall.

On the node, as root:

```bash
python3 - << 'PY'
import json
import subprocess
import sys

node = "barbatoslupusrex"
opts = json.loads(subprocess.check_output(
    ["pvesh", "get", f"/nodes/{node}/firewall/options", "--output-format", "json"],
    text=True,
))
policy = str(opts.get("policy_in") or "DROP").upper()
if policy != "DROP":
    sys.exit(f"policy_in is {policy}; expected DROP. Not changing it.")

wanted = {
    "type": "in",
    "action": "ACCEPT",
    "proto": "tcp",
    "dport": "25",
    "source": "10.10.0.82/32",
    "dest": "10.10.0.21/32",
    "comment": "CT182 Watchtower SMTP to PVE relay",
}
rules = json.loads(subprocess.check_output(
    ["pvesh", "get", f"/nodes/{node}/firewall/rules", "--output-format", "json"],
    text=True,
))

def fields(rule):
    return {key: str(rule.get(key, "")) for key in wanted}

if any(fields(rule) == wanted for rule in rules):
    print("matching firewall rule present; not creating another")
    sys.exit(0)

subprocess.check_call([
    "pvesh", "create", f"/nodes/{node}/firewall/rules",
    "--type", "in",
    "--action", "ACCEPT",
    "--proto", "tcp",
    "--dport", "25",
    "--source", "10.10.0.82/32",
    "--dest", "10.10.0.21/32",
    "--comment", wanted["comment"],
])
print("firewall rule created")
PY
```

A second run finds the existing rule wherever it sits and does not insert
a second one. To remove it, find that same field match and delete only
its current `pos`. Do not change `policy_in`.

```bash
python3 - << 'PY'
import json
import subprocess
import sys

node = "barbatoslupusrex"
wanted = {
    "type": "in",
    "action": "ACCEPT",
    "proto": "tcp",
    "dport": "25",
    "source": "10.10.0.82/32",
    "dest": "10.10.0.21/32",
    "comment": "CT182 Watchtower SMTP to PVE relay",
}
rules = json.loads(subprocess.check_output(
    ["pvesh", "get", f"/nodes/{node}/firewall/rules", "--output-format", "json"],
    text=True,
))

def fields(rule):
    return {key: str(rule.get(key, "")) for key in wanted}

matches = [rule for rule in rules if fields(rule) == wanted]
if not matches:
    print("no matching firewall rule")
    sys.exit(0)
if len(matches) != 1:
    sys.exit(f"expected one match, found {len(matches)}; not deleting")
pos = matches[0]["pos"]
subprocess.check_call([
    "pvesh", "delete", f"/nodes/{node}/firewall/rules/{pos}",
])
print(f"deleted firewall rule at pos {pos}")
PY
```
