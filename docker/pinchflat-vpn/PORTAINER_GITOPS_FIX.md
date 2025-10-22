# Portainer GitOps Deployment Fix - Testing Guide

## Problem Summary

**Issue**: Portainer GitOps was creating `auth-config.toml` as an empty directory instead of pulling it as a file from the repository, causing the Gluetun container to fail healthchecks and the stack to roll back.

**Root Cause**: Portainer's GitOps feature has a known limitation with bind-mounted config files in the compose file's root directory.

## Solution Implemented

**Fix**: Moved `auth-config.toml` into a `config/` subdirectory to ensure Portainer handles it correctly as a file rather than creating it as a directory.

### Changes Made (Commit: 55e799e)

1. **File structure change**:
   ```
   docker/pinchflat-vpn/
   ├── config/
   │   └── auth-config.toml    # ← Moved here (was in root)
   └── docker-compose.yml
   ```

2. **docker-compose.yml update**:
   ```yaml
   volumes:
     - ./config/auth-config.toml:/gluetun/auth/config.toml:ro
   ```
   (Previously: `./auth-config.toml`)

3. **README.md**: Updated documentation with new path and added Portainer GitOps compatibility notes

## Testing on bael.lan

### Prerequisites
- Stack currently deployed via Portainer GitOps
- Repository: `https://github.com/alehpineda/homelab`
- Branch: `refs/heads/feature/pinchflat`
- Compose path: `docker/pinchflat-vpn/docker-compose.yml`

### Step 1: Clean Up Previous Failed Deployment

SSH into bael.lan and check/clean the GitOps directory:

```bash
ssh bael.lan

# Check current state
ls -la /data/compose/21/docker/pinchflat-vpn/

# If auth-config.toml exists as a directory, remove it
sudo rm -rf /data/compose/21/docker/pinchflat-vpn/auth-config.toml

# Verify it's gone
ls -la /data/compose/21/docker/pinchflat-vpn/
```

### Step 2: Update Portainer Stack

In Portainer UI:

1. Navigate to **Stacks** → **pinchflat-vpn**
2. Click **"Pull and redeploy"** or **"Git Pull"**
   - This will fetch the latest changes from `feature/pinchflat` branch
   - Portainer should now create `config/` directory with `auth-config.toml` file inside

### Step 3: Verify Deployment

#### Check File Structure on bael.lan

```bash
# Verify the config directory and file exist
ls -la /data/compose/21/docker/pinchflat-vpn/config/
cat /data/compose/21/docker/pinchflat-vpn/config/auth-config.toml

# Expected output: Should show the TOML file with [[roles]] content
```

#### Check Container Status

```bash
# Check if containers are running and healthy
docker ps --filter "name=gluetun-pinchflat" --filter "name=pinchflat"

# Both should show "Up X seconds (healthy)" status
```

#### Check Gluetun Logs

```bash
# Check for successful VPN connection
docker logs gluetun-pinchflat 2>&1 | grep -E "(Connected|control server)"

# Should see:
# - "control server listening" on :8000
# - VPN connection successful messages
# - NO "401 Unauthorized" errors
```

#### Test Healthcheck Endpoint

```bash
# Test the healthcheck endpoint directly
docker exec gluetun-pinchflat wget --quiet --tries=1 -O - http://localhost:8000/v1/publicip/ip

# Expected: {"public_ip":"<VPN_IP>"}
# Should NOT return 401 error
```

#### Verify Auth Config is Mounted

```bash
# Check if auth config is properly mounted inside container
docker exec gluetun-pinchflat cat /gluetun/auth/config.toml

# Expected: Should display the TOML content with [[roles]] section
```

### Step 4: Monitor Stack Health

```bash
# Watch logs in real-time for any issues
docker logs -f gluetun-pinchflat

# In another terminal, check Pinchflat
docker logs -f pinchflat

# Both containers should remain healthy
# Gluetun healthcheck should pass every 30 seconds
```

## Expected Results

✅ **Success Indicators**:
- `config/auth-config.toml` created as a **file** (not directory)
- Both containers reach `healthy` status
- Healthcheck endpoint returns 200 OK with VPN IP
- No "401 Unauthorized" errors in logs
- Stack remains running (no rollback)

❌ **Failure Indicators**:
- `config/` directory not created
- `auth-config.toml` still created as directory
- Gluetun stuck in "Waiting" state
- 401 errors in healthcheck
- Stack rolls back automatically

## Rollback Plan

If the fix doesn't work:

### Option B: Environment Variable Approach

We could embed the auth config content in an environment variable and write it during startup. This would require:

1. Add to `.env`:
   ```
   GLUETUN_AUTH_CONFIG=[[roles]]\nname = "healthcheck"\nroutes = ["GET /v1/publicip/ip"]\nauth = "none"
   ```

2. Modify docker-compose.yml to use an entrypoint script that writes the config

### Option C: Manual Volume Setup

Revert to volume-based approach with one-time manual setup on bael.lan:

1. Create named volume
2. Manually copy auth-config.toml to volume
3. Stack references the volume instead of bind mount

## Additional Notes

- **Local Testing**: Already verified working on local machine
- **Portainer Version**: Check Portainer CE version on bael.lan (may affect behavior)
- **Git Sync Logs**: Check Portainer logs for any git operation errors

## References

- **Commit**: `55e799e` - Fix Portainer GitOps compatibility by moving auth config to subdirectory
- **Branch**: `feature/pinchflat`
- **Previous Attempts**: 
  - `48c3fce` - Complex volume-based setup (replaced)
  - `5fb3cf6` - Simplified bind mount from root (had Portainer issue)

## Contact

If issues persist, collect:
1. Portainer logs showing git sync operation
2. Directory listing of `/data/compose/21/docker/pinchflat-vpn/`
3. Container logs from both gluetun and pinchflat
4. Output of healthcheck test command
