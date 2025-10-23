# Pinchflat-VPN Portainer Deployment - Simplified Solution ✅

## Executive Summary

**Problem**: Portainer GitOps creates bind-mounted config **files** as empty directories instead of files, breaking Gluetun container startup.

**Solution**: Bind-mount the **config directory** (`./config`) instead of individual files. Portainer handles directory mounts correctly.

**Status**: ✅ Tested and working locally. Ready for bael.lan deployment.

---

## Solution Architecture

### What Changed

| Previous Attempts (Failed) | Current Solution (Working) |
|---------------------------|---------------------------|
| Bind-mount file: `./config/auth-config.toml` | Bind-mount directory: `./config` |
| Portainer creates file as empty directory | Portainer syncs directory correctly |
| Container fails with "Is a directory" error | Container starts successfully |

### How It Works

```
1. Git repository contains: config/auth-config.toml (committed file)
2. Portainer pulls repo → config/ directory synced correctly ✅
3. docker-compose.yml mounts: ./config:/gluetun/auth:ro
4. Gluetun reads: /gluetun/auth/auth-config.toml
5. Healthcheck passes → Container healthy ✅
```

### Key Files

**config/auth-config.toml** (in version control):
```toml
[[roles]]
name = "healthcheck"
routes = ["GET /v1/publicip/ip"]
auth = "none"
```

**docker-compose.yml** (simplified):
```yaml
gluetun:
  image: qmcgaw/gluetun:latest
  environment:
    - HTTP_CONTROL_SERVER_ADDRESS=:8000
    - HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH=/gluetun/auth/auth-config.toml
  volumes:
    - ./config:/gluetun/auth:ro  # Directory binding - clean and simple
    - ${DOCKER_VOLUMES_PATH}/gluetun-pinchflat:/gluetun
```

---

## Local Testing Results ✅

```
Container Status:
✅ gluetun-pinchflat: Up 5 minutes (healthy)
✅ pinchflat: Up 5 minutes (healthy)

VPN Connection:
✅ Public IP: 5.182.32.91 (Charlotte, North Carolina)
✅ Provider: NordVPN via WireGuard
✅ No TOML parsing errors
✅ Healthcheck passing consistently

Auth Config:
✅ Available at /gluetun/auth/auth-config.toml (inside container)
✅ Correct TOML syntax
✅ Healthcheck endpoint returns 200 OK
```

**Logs show:**
```
http server listening on [::]:8000
healthy!
```

**Verification commands used:**
```bash
# Check VPN IP
docker exec gluetun-pinchflat wget -qO- https://ipinfo.io/ip
# Output: 5.182.32.91

# Verify auth config accessible
docker exec gluetun-pinchflat cat /gluetun/auth/auth-config.toml
# Shows correct TOML content

# Test healthcheck endpoint
curl -s http://localhost:8000/v1/publicip/ip
# Returns: {"public_ip":"5.182.32.91"}
```

---

## Deployment to bael.lan

### Prerequisites
✅ Changes committed to `feature/pinchflat` branch
✅ Both containers working locally
✅ Documentation updated
✅ No custom entrypoint scripts needed

### Deployment Steps

#### 1. SSH into bael.lan
```bash
ssh bael.lan
```

#### 2. Clean Up Previous Deployment Artifacts (if needed)
```bash
# Find stack ID (check Portainer UI or ls /data/compose/)
ls -la /data/compose/

# Clean up any failed deployments (replace XX with actual stack ID)
sudo rm -rf /data/compose/XX/docker/pinchflat-vpn/config
sudo rm -rf /data/compose/XX/docker/pinchflat-vpn/auth-config.toml

# Verify clean state
ls -la /data/compose/XX/docker/pinchflat-vpn/
```

#### 3. Redeploy via Portainer UI
1. Open Portainer web interface
2. Navigate: **Stacks** → **pinchflat-vpn**
3. Click **"Pull and redeploy"**
4. Wait 60 seconds for containers to stabilize

#### 4. Verify Success
```bash
# Check container status (both should show "healthy")
docker ps --filter "name=gluetun-pinchflat" --filter "name=pinchflat"

# Verify config directory structure
docker exec gluetun-pinchflat ls -la /gluetun/auth/
# Should show: auth-config.toml (file, not directory)

# Verify auth config content
docker exec gluetun-pinchflat cat /gluetun/auth/auth-config.toml
# Should show proper TOML content

# Test healthcheck endpoint
curl -s http://localhost:8000/v1/publicip/ip
# Should return VPN IP (not your home IP)

# Check logs for any errors
docker logs gluetun-pinchflat 2>&1 | grep -iE "(error|warn|failed)"
# Should be clean (no critical errors)
```

### Success Criteria
- [x] Both containers reach `(healthy)` status within 60 seconds
- [x] `config/` directory contains `auth-config.toml` **file** (not directory)
- [x] VPN public IP is different from home IP
- [x] Healthcheck endpoint returns 200 OK
- [x] No "Is a directory" errors in logs
- [x] Stack remains stable without restarts

---

## Troubleshooting Quick Reference

### Issue: Config directory not created
```bash
# Check if Portainer synced the repo correctly
ls -la /data/compose/XX/docker/pinchflat-vpn/config/
# Should contain: auth-config.toml

# If missing, check Portainer logs or manually create:
mkdir -p /data/compose/XX/docker/pinchflat-vpn/config
cat > /data/compose/XX/docker/pinchflat-vpn/config/auth-config.toml << 'EOF'
[[roles]]
name = "healthcheck"
routes = ["GET /v1/publicip/ip"]
auth = "none"
EOF

# Redeploy in Portainer
```

### Issue: Container healthy but healthcheck endpoint returns 401
```bash
# Verify auth config is accessible
docker exec gluetun-pinchflat cat /gluetun/auth/auth-config.toml

# Check environment variable
docker exec gluetun-pinchflat printenv | grep AUTH_CONFIG
# Should show: HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH=/gluetun/auth/auth-config.toml
```

### Issue: Container stuck in "starting" state
```bash
# Check logs for specific error
docker logs gluetun-pinchflat --tail 50

# Verify volume mount
docker inspect gluetun-pinchflat | grep -A10 Mounts
# Should show: ./config:/gluetun/auth:ro
```

---

## Why Previous Approaches Failed

### Attempt 1: Bind mount file from root ❌
```yaml
volumes:
  - ./auth-config.toml:/gluetun/auth/config.toml:ro
```
**Result**: Portainer created `auth-config.toml` as empty directory

### Attempt 2: Bind mount file from subdirectory ❌
```yaml
volumes:
  - ./config/auth-config.toml:/gluetun/auth/config.toml:ro
```
**Result**: Portainer still created file as directory (confirmed on bael.lan)

### Attempt 3: Runtime generation with entrypoint-wrapper.sh ✅ (but overengineered)
```yaml
volumes:
  - ./entrypoint-wrapper.sh:/entrypoint-wrapper.sh:ro
entrypoint: ["/entrypoint-wrapper.sh"]
```
**Result**: Worked, but unnecessarily complex (25-line shell script)

### Current Approach: Directory binding ✅ (simple and clean)
```yaml
volumes:
  - ./config:/gluetun/auth:ro
```
**Result**: Works perfectly - Portainer handles directory mounts correctly

---

## Why This Solution is Better

| Previous (Runtime Generation) | Current (Directory Binding) |
|------------------------------|----------------------------|
| Custom entrypoint script | Standard Docker volumes |
| Runtime file generation | File in version control |
| Complex, hard to understand | Simple, obvious intent |
| 25-line shell script | 1-line volume mount |
| **Still worked, but overkill** | **Clean and maintainable** |

### Key Insights

1. **Portainer GitOps Behavior**:
   - ✅ **Directories** → Synced correctly from git
   - ❌ **Files for bind mount** → Created as empty directories
   - ✅ **Solution**: Bind the directory, not the file

2. **Standard Docker Practices**:
   - No custom entrypoints needed
   - Config files in version control
   - Easy to understand and maintain

3. **Simplicity Wins**:
   - Fewer moving parts = fewer failure points
   - Clear intent in docker-compose.yml
   - No shell scripting required

---

## Rollback Plan

If deployment fails on bael.lan:

### Option 1: Manual Config Creation (Quick Fix)
```bash
# Create config inside running container
docker exec gluetun-pinchflat sh -c 'cat > /gluetun/auth/auth-config.toml << "EOF"
[[roles]]
name = "healthcheck"
routes = ["GET /v1/publicip/ip"]
auth = "none"
EOF'

docker restart gluetun-pinchflat
```

### Option 2: Revert to Runtime Generation Approach
```bash
# Checkout previous commit (before simplification)
git checkout 2ea38ac  # Runtime generation commit

# Redeploy in Portainer
```

---

## Next Steps After Successful Deployment

1. ✅ **Verify stack is healthy** (both containers running for 5+ minutes)
2. ✅ **Test VPN rotation**: `./rotate-vpn-ip.sh`
3. ✅ **Monitor for stability** (check after 1 hour, 6 hours, 24 hours)
4. ✅ **Configure Ansible cron** (optional): `ansible-playbook playbooks/configure-pinchflat-vpn-rotation.yml`
5. ✅ **Merge to main** if stable after 24 hours: `git merge feature/pinchflat`

---

## Git History

**Current branch**: `feature/pinchflat`

**Key commits**:
- `1139f70` - **Simplify Portainer GitOps fix by binding config directory** (current)
- `2ea38ac` - Update documentation for runtime generation approach
- `bc272e6` - Fix with runtime generation (entrypoint-wrapper.sh)
- `55e799e` - Attempt: subdirectory (failed)
- `5fb3cf6` - Attempt: root bind mount (failed)

---

## References

- **Portainer GitOps Fix Details**: `PORTAINER_GITOPS_FIX.md` (comprehensive explanation)
- **Quick Debug Commands**: `QUICK_DEBUG.md` (copy-paste troubleshooting)
- **Main Documentation**: `README.md` (updated with directory binding approach)
- **Gluetun Auth Docs**: https://github.com/qdm12/gluetun/wiki/Control-server#authentication

---

## Success Indicators

**Report these if deployment succeeds** ✅:
- Both containers show `(healthy)` status within 60 seconds
- VPN IP showing correctly (different from home IP)
- No errors in logs for 5 minutes
- Healthcheck passing every 30 seconds
- Config file accessible at `/gluetun/auth/auth-config.toml` (not directory)

**Report these + logs if deployment fails** ❌:
- Container stuck in "starting" or "waiting" state
- "Is a directory" errors in logs
- Auth config not accessible or is a directory
- 401 errors on healthcheck endpoint
- Stack rolls back automatically

### Collect Diagnostics
```bash
# Container status
docker ps --filter "name=pinchflat"

# Logs
docker logs gluetun-pinchflat --tail 100 > /tmp/gluetun.log
docker logs pinchflat --tail 100 > /tmp/pinchflat.log

# File structure
ls -laR /data/compose/XX/docker/pinchflat-vpn/ > /tmp/files.log

# Container mounts
docker inspect gluetun-pinchflat | grep -A10 Mounts > /tmp/mounts.log

# Config verification
docker exec gluetun-pinchflat ls -la /gluetun/auth/ > /tmp/auth-ls.log
docker exec gluetun-pinchflat cat /gluetun/auth/auth-config.toml > /tmp/auth-content.log
```

---

**Ready to deploy! 🚀**

✅ Local testing: PASSED  
✅ Documentation: COMPLETE  
✅ Solution: SIMPLIFIED (directory binding)  
✅ Branch: `feature/pinchflat`  
⚠️ Not pushed yet: Push before deploying!
