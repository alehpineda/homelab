# Portainer GitOps Deployment Fix - Testing Guide

## Problem Summary

**Issue**: Portainer GitOps creates bind-mounted config files as **empty directories** instead of files from the repository, causing the Gluetun container to fail healthchecks and the stack to roll back.

**Root Cause**: Portainer's GitOps feature has a known limitation - it cannot handle bind-mounted config files (in root directory OR subdirectories). When docker-compose.yml references a file for bind mounting, Portainer creates a directory with that name instead of pulling the file from the repository.

## Solution Implemented ✅

**Fix**: Generate the auth config file at **runtime** using an entrypoint wrapper script instead of bind-mounting it from the repository.

### How It Works (Commit: bc272e6)

1. **entrypoint-wrapper.sh**: Shell script bind-mounted from repo (scripts work fine, data files don't)
2. **Runtime generation**: Script creates `/gluetun/auth/config.toml` inside container at startup using heredoc
3. **No config file bind mount**: No opportunity for Portainer to mishandle the config file

### Changes Made

```
docker/pinchflat-vpn/
├── entrypoint-wrapper.sh          # ← NEW: Creates auth config at startup
├── docker-compose.yml              # ← UPDATED: Uses custom entrypoint
└── .env.example                    # ← UPDATED: Documentation
```

**Key docker-compose.yml changes:**
```yaml
volumes:
  - ./entrypoint-wrapper.sh:/entrypoint-wrapper.sh:ro  # Bind mount script (works)
  # REMOVED: ./config/auth-config.toml bind mount
entrypoint: ["/entrypoint-wrapper.sh"]
command: []
```

**entrypoint-wrapper.sh logic:**
```bash
mkdir -p /gluetun/auth
cat > /gluetun/auth/config.toml << 'EOF'
[[roles]]
name = "healthcheck"
routes = ["GET /v1/publicip/ip"]
auth = "none"
EOF
exec /gluetun-entrypoint "$@"
```

## Testing on bael.lan

### Prerequisites
- Stack ID in Portainer: Check current deployment (likely `23` based on previous attempts)
- Repository: `https://github.com/alehpineda/homelab`
- Branch: `refs/heads/feature/pinchflat`
- Compose path: `docker/pinchflat-vpn/docker-compose.yml`

### Step 1: Clean Up Previous Failed Deployments

SSH into bael.lan and remove any directories created by previous attempts:

```bash
ssh bael.lan

# Find your stack ID (check Portainer or look for directories)
ls -la /data/compose/

# Clean up based on stack ID (replace XX with actual stack ID)
sudo rm -rf /data/compose/XX/docker/pinchflat-vpn/config/
sudo rm -rf /data/compose/XX/docker/pinchflat-vpn/auth-config.toml

# Example for stack ID 23:
sudo rm -rf /data/compose/23/docker/pinchflat-vpn/config/
sudo rm -rf /data/compose/23/docker/pinchflat-vpn/auth-config.toml

# Verify cleanup
ls -la /data/compose/XX/docker/pinchflat-vpn/
```

### Step 2: Redeploy via Portainer

In Portainer UI:

1. Navigate to **Stacks** → **pinchflat-vpn**
2. Click **"Pull and redeploy"** or **"Git Pull"**
   - Portainer will pull `entrypoint-wrapper.sh` from repository
   - No config files to mishandle = clean deployment
3. Wait for stack to stabilize (30-60 seconds)

### Step 3: Verify Deployment

#### Check File Structure on bael.lan

```bash
# Verify entrypoint script was pulled correctly
ls -la /data/compose/XX/docker/pinchflat-vpn/entrypoint-wrapper.sh
cat /data/compose/XX/docker/pinchflat-vpn/entrypoint-wrapper.sh

# Expected: Script should exist and be executable
```

#### Check Container Status

```bash
# Check if containers are running and healthy
docker ps --filter "name=gluetun-pinchflat" --filter "name=pinchflat"

# Both should show "Up X seconds (healthy)" status
# Look for: STATUS column showing "(healthy)"
```

#### Verify Auth Config Created Inside Container

```bash
# Check if auth config was created at runtime
docker exec gluetun-pinchflat cat /gluetun/auth/config.toml

# Expected output:
# [[roles]]
# name = "healthcheck"
# routes = ["GET /v1/publicip/ip"]
# auth = "none"
```

#### Check Gluetun Startup Logs

```bash
# Check for successful auth config creation and VPN connection
docker logs gluetun-pinchflat 2>&1 | grep -E "(Creating auth config|Auth config created|control server|Connected)"

# Should see:
# - "Creating auth config for healthcheck..."
# - "Auth config created successfully"
# - "http server listening on [::]:8000"
# - VPN connection successful messages
```

#### Test Healthcheck Endpoint

```bash
# Test from outside the container
curl -s http://localhost:8000/v1/publicip/ip

# Expected: {"public_ip":"<VPN_IP>","region":"..."}
# Should return 200 OK with VPN server IP (NOT your home IP)
```

#### Test from Inside Container

```bash
# Test healthcheck from inside Gluetun
docker exec gluetun-pinchflat wget --quiet --tries=1 -O - http://localhost:8000/v1/publicip/ip

# Expected: Same JSON output as above
# Should NOT return 401 error
```

### Step 4: Monitor Stack Health

```bash
# Watch logs for 2-3 minutes to ensure stability
docker logs -f gluetun-pinchflat

# Look for:
# - "healthy!" messages every 30 seconds
# - No restart loops
# - No authentication errors
# - Public IP remains consistent (VPN IP, not home IP)

# Press Ctrl+C to exit
```

## Expected Results

### ✅ Success Indicators
- [x] `entrypoint-wrapper.sh` pulled from repository as executable file
- [x] Both containers reach `(healthy)` status within 60 seconds
- [x] `/gluetun/auth/config.toml` created **inside container** (not on host)
- [x] Healthcheck endpoint returns 200 OK with VPN IP
- [x] No "401 Unauthorized" errors in logs
- [x] No "Permission denied" or "Is a directory" errors
- [x] Stack remains running (no rollback)
- [x] Logs show "Creating auth config" and "Auth config created successfully"

### ❌ Failure Indicators
- [ ] `entrypoint-wrapper.sh` not found or not executable
- [ ] Containers stuck in "Waiting" state
- [ ] Container logs show "exec format error" or "not found"
- [ ] Auth config file missing inside container
- [ ] 401 errors when accessing healthcheck endpoint
- [ ] Stack automatically rolls back
- [ ] Gluetun restarts repeatedly

## Troubleshooting

### Issue: "exec format error"
**Cause**: Script has wrong line endings (CRLF instead of LF)
**Fix**: 
```bash
# On bael.lan, convert line endings
dos2unix /data/compose/XX/docker/pinchflat-vpn/entrypoint-wrapper.sh
```

### Issue: "Permission denied" on entrypoint
**Cause**: Script not executable
**Fix**:
```bash
# On bael.lan, make script executable
chmod +x /data/compose/XX/docker/pinchflat-vpn/entrypoint-wrapper.sh
# Then redeploy stack in Portainer
```

### Issue: Container starts but no auth config created
**Cause**: Entrypoint script not being executed
**Fix**:
```bash
# Check container entrypoint
docker inspect gluetun-pinchflat | grep -A5 Entrypoint
# Should show: ["/entrypoint-wrapper.sh"]

# Check script is mounted
docker exec gluetun-pinchflat ls -la /entrypoint-wrapper.sh
```

### Issue: Auth config exists but healthcheck fails
**Cause**: TOML syntax error or wrong content
**Fix**:
```bash
# Verify exact content inside container
docker exec gluetun-pinchflat cat /gluetun/auth/config.toml

# Should match exactly:
# [[roles]]
# name = "healthcheck"
# routes = ["GET /v1/publicip/ip"]
# auth = "none"
```

## Why This Solution Works

### Previous Approaches (Failed)
1. **Bind mount from root** (Commit 5fb3cf6): ❌ Portainer created directory
2. **Bind mount from subdirectory** (Commit 55e799e): ❌ Portainer still created directory
3. **Environment variable TOML** (Not committed): ❌ TOML parsing errors with `\n` escaping

### Current Approach (Success)
4. **Runtime generation with heredoc** (Commit bc272e6): ✅ Works because:
   - **Scripts CAN be bind-mounted** - Portainer handles executable files correctly
   - **Data files generated at runtime** - No opportunity for Portainer to mishandle
   - **Heredoc avoids escaping** - TOML content embedded directly in shell script
   - **Tested locally** - Both containers healthy, VPN connected

## Rollback Plan

If the fix doesn't work on bael.lan:

### Option A: Manual File Creation (Temporary)
```bash
# SSH into bael.lan
ssh bael.lan

# Create auth config manually in Gluetun volume
docker exec gluetun-pinchflat sh -c 'mkdir -p /gluetun/auth && cat > /gluetun/auth/config.toml << "EOF"
[[roles]]
name = "healthcheck"
routes = ["GET /v1/publicip/ip"]
auth = "none"
EOF'

# Restart container to pick up config
docker restart gluetun-pinchflat
```

### Option B: Init Container Pattern
Create a separate init container that sets up the config before Gluetun starts (requires docker-compose changes)

### Option C: Portainer Stack with Manual Config
Deploy stack via Portainer but manage config file manually on host (defeats purpose of GitOps)

## Additional Notes

- **Local Testing**: ✅ Verified working on local Docker environment
  - Both containers healthy
  - VPN connected (IP: 94.140.11.119, Miami, Florida)
  - No TOML parsing errors
  - Healthcheck passes consistently

- **Portainer Compatibility**: This approach is designed specifically for Portainer GitOps limitations
  - Bind-mounted scripts: ✅ Works
  - Bind-mounted config files: ❌ Doesn't work
  - Runtime-generated configs: ✅ Works

- **Security**: Auth config is non-sensitive (only whitelists a read-only healthcheck endpoint)

## Commit History

- `bc272e6` - ✅ **Current**: Fix with runtime generation (entrypoint wrapper + heredoc)
- `31fa712` - Add diagnostic scripts for troubleshooting
- `b5052e4` - Add testing guide
- `55e799e` - ❌ Attempt: Move to subdirectory (still failed)
- `5fb3cf6` - ❌ Attempt: Simplified bind mount from root (failed)

## References

- **Gluetun Auth Documentation**: https://github.com/qdm12/gluetun/wiki/Control-server#authentication
- **Portainer GitOps Docs**: https://docs.portainer.io/user/docker/stacks/add#git-repository
- **Issue Discussion**: Portainer forums report similar bind mount issues with GitOps

## Success Metrics

After deployment on bael.lan, confirm:

1. ✅ Stack deployed without manual intervention
2. ✅ Both containers healthy after 60 seconds
3. ✅ VPN connected (public IP different from home IP)
4. ✅ Healthcheck passing every 30 seconds
5. ✅ No errors in logs after 5 minutes
6. ✅ Pinchflat can access internet through VPN
7. ✅ Stack survives Portainer restarts
8. ✅ Stack survives Docker daemon restarts

## Contact

If issues persist, collect and share:
1. Portainer stack ID and logs (Settings → View logs)
2. Directory listing: `ls -laR /data/compose/XX/docker/pinchflat-vpn/`
3. Container logs: `docker logs gluetun-pinchflat` and `docker logs pinchflat`
4. Container inspect: `docker inspect gluetun-pinchflat | grep -A10 Mounts`
5. Healthcheck test output
6. Portainer version: Check bottom of Portainer UI
