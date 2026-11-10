"""Normalise PVE firewall rules so desired (vars) and live (API) compare equal."""


def _key(proto, dport, source):
    return "in:ACCEPT:%s:%s:%s" % (proto or "", dport or "", source or "")


def pve_fw_rule_key(rule):
    return _key(rule.get("proto"), rule.get("dport"), rule.get("source"))


def pve_fw_live_key(rule):
    if rule.get("type") == "group":
        return "group:%s" % rule.get("action")
    return _key(rule.get("proto"), rule.get("dport"), rule.get("source"))


class FilterModule(object):
    def filters(self):
        return {"pve_fw_rule_key": pve_fw_rule_key, "pve_fw_live_key": pve_fw_live_key}
