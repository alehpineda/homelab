# Pinchflat-VPN Portainer Deployment - Final Solution ✅

## Executive Summary

**Problem**: Portainer GitOps creates bind-mounted config files as empty directories instead of files, breaking Gluetun container startup.

**Solution**: Generate auth config at runtime using `entrypoint-wrapper.sh` instead of bind-mounting from repository.

**Status**: ✅ Tested and working locally. Ready for bael.lan deployment.

---

## Solution Architecture

### What Changed

| Before (Failed) | After (Working) |
|----------------|-----------------|
| Bind-mount `auth-config.toml` from repo | Bind-mount `entrypoint-wrapper.sh` (script) |
| Portainer creates it as directory | Script creates config at runtime |
| Container fails to start | Container starts successfully |

### How It Works

```
1. Portainer pulls repo → entrypoint-wrapper.sh downloaded (scripts work fine)
2. Container starts → runs entrypoint-wrapper.sh
3. Script creates /gluetun/auth/config.toml inside container
4. Script execs original gluetun-entrypoint
5. Gluetun starts with auth config ✅
```

### Key Files

**entrypoint-wrapper.sh** (new):
```bash
#!/bin/sh
set -e
mkdir -p /gluetun/auth
cat > /gluetun/auth/config.toml << 'EOF'
[[roles]]
name = "healthcheck"
routes = ["GET /v1/publicip/ip"]
auth = "none"
EOF
exec /gluetun-entrypoint "$@"
```

**docker-compose.yml** (modified):
```yaml
gluetun:
  volumes:
    - ./entrypoint-wrapper.sh:/entrypoint-wrapper.sh:ro  # NEW
    # REMOVED: ./config/auth-config.toml bind mount
  entrypoint: ["/entrypoint-wrapper.sh"]  # NEW
  command: []  # NEW
```

---

## Local Testing Results ✅

```
Container Status:
✅ gluetun-pinchflat: Up 4 minutes (healthy)
✅ pinchflat: Up 4 minutes (healthy)

VPN Connection:
✅ Public IP: 94.140.11.119 (Miami, Florida)
✅ Provider: NordVPN via WireGuard
✅ No TOML parsing errors
✅ Healthcheck passing consistently

Auth Config:
✅ Created at /gluetun/auth/config.toml (inside container)
✅ Correct TOML syntax
✅ Healthcheck endpoint returns 200 OK
```

**Logs show:**
```
Creating auth config for healthcheck...
Auth config created successfully
http server listening on [::]:8000
healthy!
```

---

## Deployment to bael.lan

### Prerequisites
✅ Changes committed to `feature/pinchflat` branch
✅ Both containers working locally
✅ Documentation updated

### Deployment Steps

#### 1. SSH into bael.lan
```bash
ssh bael.lan
```

#### 2. Find and Clean Stack Directory
```bash
# Find stack ID (likely 23 based on previous attempts)
ls -la /data/compose/

# Clean up failed deployments (replace XX with actual ID)
sudo rm -rf /data/compose/XX/docker/pinchflat-vpn/config/
sudo rm -rf /data/compose/XX/docker/pinchflat-vpn/auth-config.toml

# Verify
ls -la /data/compose/XX/docker/pinchflat-vpn/
```

#### 3. Redeploy via Portainer UI
1. Open Portainer
2. Navigate: **Stacks** → **pinchflat-vpn**
3. Click **"Pull and redeploy"**
4. Wait 60 seconds for stabilization

#### 4. Verify Success
```bash
# Check container status
docker ps --filter "name=gluetun-pinchflat" --filter "name=pinchflat"
# Both should show "(healthy)"

# Verify auth config created
docker exec gluetun-pinchflat cat /gluetun/auth/config.toml

# Test healthcheck
curl -s http://localhost:8000/v1/publicip/ip
# Should return VPN IP (not home IP)

# Check logs
docker logs gluetun-pinchflat 2>&1 | grep -E "(Creating auth config|Auth config created|healthy)"
```

### Success Criteria
- [ ] Both containers reach `(healthy)` status
- [ ] Auth config exists inside container
- [ ] VPN public IP different from home IP
- [ ] No "401 Unauthorized" errors
- [ ] No "Is a directory" errors
- [ ] Stack remains stable (no restarts)

---

## Troubleshooting Quick Reference

### Issue: "exec format error"
```bash
# Fix line endings
dos2unix /data/compose/XX/docker/pinchflat-vpn/entrypoint-wrapper.sh
# Redeploy in Portainer
```

### Issue: "Permission denied"
```bash
# Make executable
chmod +x /data/compose/XX/docker/pinchflat-vpn/entrypoint-wrapper.sh
# Redeploy in Portainer
```

### Issue: Container starts but no auth config
```bash
# Check entrypoint
docker inspect gluetun-pinchflat | grep -A5 Entrypoint
# Should show: ["/entrypoint-wrapper.sh"]

# Check if script is mounted
docker exec gluetun-pinchflat ls -la /entrypoint-wrapper.sh
```

### Issue: Auth config exists but healthcheck fails
```bash
# Verify content
docker exec gluetun-pinchflat cat /gluetun/auth/config.toml
# Must match exactly (no extra spaces, correct TOML syntax)
```

---

## Why Previous Approaches Failed

### Attempt 1: Bind mount from root ❌
```yaml
volumes:
  - ./auth-config.toml:/gluetun/auth/config.toml:ro
```
**Result**: Portainer created `auth-config.toml` as empty directory

### Attempt 2: Bind mount from subdirectory ❌
```yaml
volumes:
  - ./config/auth-config.toml:/gluetun/auth/config.toml:ro
```
**Result**: Portainer still created directory (user confirmed on bael.lan)

### Attempt 3: Environment variable with `\n` ❌
```yaml
environment:
  - GLUETUN_AUTH_CONFIG='[[roles]]\nname = "healthcheck"...'
```
**Result**: TOML parsing errors (escape sequences not handled correctly)

### Current Approach: Runtime generation with heredoc ✅
```yaml
volumes:
  - ./entrypoint-wrapper.sh:/entrypoint-wrapper.sh:ro
entrypoint: ["/entrypoint-wrapper.sh"]
```
**Result**: Works perfectly - scripts CAN be bind-mounted, config generated at runtime

---

## Why This Works

### Portainer GitOps Behavior
- ✅ **Executable scripts** → Downloaded correctly from repo
- ❌ **Config files for bind mount** → Created as empty directories
- ✅ **Files generated at runtime** → No opportunity for Portainer to mishandle

### Technical Details
1. **Script binding works**: Portainer handles executable files correctly
2. **Runtime generation**: Config created after container starts, not during git sync
3. **Heredoc avoids escaping**: TOML content embedded directly in shell script
4. **No parsing issues**: No environment variable interpolation needed

---

## Rollback Plan

If deployment fails on bael.lan:

### Quick Fix: Manual Creation
```bash
docker exec gluetun-pinchflat sh -c 'mkdir -p /gluetun/auth && cat > /gluetun/auth/config.toml << "EOF"
[[roles]]
name = "healthcheck"
routes = ["GET /v1/publicip/ip"]
auth = "none"
EOF'

docker restart gluetun-pinchflat
```

This manually creates the config - stack should then work normally.

---

## Commits

- `b1a46f1` - Update documentation
- `bc272e6` - **Fix with runtime generation** (main fix)
- `31fa712` - Add diagnostic scripts
- `55e799e` - Attempt: subdirectory (failed)
- `5fb3cf6` - Attempt: root bind mount (failed)

---

## Next Steps After Deployment

1. ✅ Verify stack is healthy
2. ✅ Test VPN rotation: `./rotate-vpn-ip.sh`
3. ✅ Configure Ansible cron for hourly rotation (optional)
4. ✅ Monitor for 24 hours to ensure stability
5. ✅ Merge `feature/pinchflat` to `main` if successful

---

## References

- **Testing Guide**: `PORTAINER_GITOPS_FIX.md` (comprehensive)
- **Quick Debug**: `QUICK_DEBUG.md` (copy-paste commands)
- **README**: `README.md` (updated with runtime generation docs)
- **Gluetun Auth Docs**: https://github.com/qdm12/gluetun/wiki/Control-server#authentication

---

## Contact & Support

**Success Indicators** (report these):
✅ Both containers healthy after 60s
✅ VPN IP showing correctly
✅ No errors in logs for 5 minutes
✅ Healthcheck passing every 30s

**Failure Indicators** (report these + logs):
❌ Container stuck in "Waiting"
❌ "exec format error" in logs
❌ Auth config not created
❌ 401 errors on healthcheck
❌ Stack rolls back automatically

Collect diagnostics:
```bash
# Container status
docker ps --filter "name=pinchflat"

# Logs
docker logs gluetun-pinchflat > /tmp/gluetun.log
docker logs pinchflat > /tmp/pinchflat.log

# File structure
ls -laR /data/compose/XX/docker/pinchflat-vpn/ > /tmp/files.log

# Container mounts
docker inspect gluetun-pinchflat | grep -A10 Mounts > /tmp/mounts.log
```

---

**Ready to deploy! 🚀**

Local testing: ✅ PASSED  
Documentation: ✅ COMPLETE  
Commits pushed: ✅ YES  
Branch: `feature/pinchflat`
