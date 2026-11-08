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
