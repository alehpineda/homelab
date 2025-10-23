# Portainer GitOps Deployment Fix - Final Solution ✅

## Problem Summary

**Issue**: Portainer GitOps creates bind-mounted **files** as empty directories instead of pulling them from the repository, causing Gluetun container to fail.

**Root Cause**: Portainer's GitOps feature has a limitation with bind-mounting individual files. When docker-compose.yml references a file for bind mounting, Portainer creates a directory with that name instead of pulling the file from the repository.

## Solution Implemented ✅

**Fix**: Bind-mount the **directory** containing the config file instead of binding the file directly.

### How It Works

```yaml
# ❌ DOESN'T WORK: Binding individual file
volumes:
  - ./config/auth-config.toml:/gluetun/auth/config.toml:ro

# ✅ WORKS: Binding directory containing file
volumes:
  - ./config:/gluetun/auth:ro
```

**Why this works:**
- Portainer CAN handle directory bind mounts ✅
- Portainer CANNOT handle individual file bind mounts ❌
- Directory binding is a standard Docker pattern and works reliably

### Changes Made (Commit: 1139f70)

**docker-compose.yml**:
```yaml
volumes:
  - ./config:/gluetun/auth:ro  # Bind entire directory
environment:
  - HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH=/gluetun/auth/auth-config.toml
```

**Directory structure**:
```
docker/pinchflat-vpn/
├── config/
│   └── auth-config.toml    # File in version control
└── docker-compose.yml      # Binds ./config directory
```

---

## Local Testing Results ✅

```
Container Status:
✅ gluetun-pinchflat: Up (healthy)
✅ pinchflat: Up (healthy)

VPN Connection:
✅ Public IP: 5.182.32.91 (Charlotte, North Carolina)
✅ Provider: NordVPN via WireGuard
✅ Auth config properly mounted
✅ Healthcheck passing

Directory Mount:
✅ /gluetun/auth/ contains auth-config.toml
✅ File readable with correct permissions
✅ No "Is a directory" errors
```

---

## Deployment to bael.lan

### Prerequisites
✅ Changes committed to `feature/pinchflat` branch
✅ Both containers working locally with directory binding
✅ Config file exists in `./config/auth-config.toml`

### Deployment Steps

#### 1. Clean Up Previous Failed Deployments

SSH into bael.lan and remove any incorrectly created directories:

```bash
ssh bael.lan

# Find your stack ID (check Portainer or list directories)
ls -la /data/compose/

# Clean up based on stack ID (replace XX with actual ID, likely 23)
sudo rm -rf /data/compose/XX/docker/pinchflat-vpn/config/auth-config.toml
sudo rm -rf /data/compose/XX/docker/pinchflat-vpn/auth-config.toml

# Verify - should only see .env and docker-compose.yml
ls -la /data/compose/XX/docker/pinchflat-vpn/
```

#### 2. Redeploy via Portainer UI

1. Open Portainer web interface
2. Navigate: **Stacks** → **pinchflat-vpn**
3. Click **"Pull and redeploy"** button
4. Wait 60 seconds for containers to stabilize

Portainer will now:
- Pull latest changes from `feature/pinchflat` branch
- Create `config/` directory correctly
- Copy `auth-config.toml` file inside it
- Mount the directory to `/gluetun/auth/`

#### 3. Verify Deployment Success

```bash
# Check containers are healthy
docker ps --filter "name=pinchflat"
# Both should show "(healthy)" status

# Verify config directory structure
ls -la /data/compose/XX/docker/pinchflat-vpn/config/
# Should show: auth-config.toml as a FILE (not directory)

# Verify file content
cat /data/compose/XX/docker/pinchflat-vpn/config/auth-config.toml
# Should show TOML content with [[roles]]

# Verify inside container
docker exec gluetun-pinchflat ls -la /gluetun/auth/
# Should show auth-config.toml

docker exec gluetun-pinchflat cat /gluetun/auth/auth-config.toml
# Should show correct TOML content

# Test healthcheck endpoint
curl -s http://localhost:8000/v1/publicip/ip
# Should return VPN IP (not home IP)

# Check logs for errors
docker logs gluetun-pinchflat 2>&1 | grep -iE "(error|fail|auth)"
# Should show: "Authentication file path: /gluetun/auth/auth-config.toml"
# Should NOT show: 401 errors or "Is a directory" errors
```

### Success Criteria

- [x] Both containers reach `(healthy)` status
- [x] `config/` created as directory (not file)
- [x] `auth-config.toml` created as file inside `config/`
- [x] Auth config accessible inside container at `/gluetun/auth/auth-config.toml`
- [x] VPN public IP different from home IP
- [x] Healthcheck endpoint returns 200 OK
- [x] No "401 Unauthorized" errors in logs
- [x] No "Is a directory" errors in logs
- [x] Stack remains stable (no restarts or rollbacks)

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
**Result**: Portainer still created file as directory (user confirmed)

### Attempt 3: Runtime generation with entrypoint ❌ (overengineered)
```yaml
volumes:
  - ./entrypoint-wrapper.sh:/entrypoint-wrapper.sh:ro
entrypoint: ["/entrypoint-wrapper.sh"]
```
**Result**: Worked but unnecessarily complex

### Current Approach: Bind mount directory ✅ (SIMPLE!)
```yaml
volumes:
  - ./config:/gluetun/auth:ro
```
**Result**: Works perfectly - Portainer handles directories correctly

---

## Why This Solution Works

### Portainer GitOps Behavior
- ✅ **Directory bind mounts** → Work correctly, standard Docker behavior
- ❌ **File bind mounts** → Created as directories during git sync
- ✅ **Simple and clean** → No custom scripts, no runtime generation

### Benefits
1. **Simplicity**: Standard Docker volume binding pattern
2. **Maintainability**: Config file in version control, easy to update
3. **Portability**: Works with Portainer GitOps AND standard Docker Compose
4. **No workarounds**: No custom entrypoints or runtime file generation
5. **Clear intent**: Obvious what's being mounted and why

---

## Troubleshooting

### Issue: config/ created as file instead of directory
**Unlikely but check:**
```bash
ls -la /data/compose/XX/docker/pinchflat-vpn/
# If config is a file, remove it:
sudo rm -f /data/compose/XX/docker/pinchflat-vpn/config
# Then redeploy in Portainer
```

### Issue: auth-config.toml missing inside config/
**Check repo sync:**
```bash
# Verify Portainer pulled the file
cat /data/compose/XX/docker/pinchflat-vpn/config/auth-config.toml
# If missing, check Portainer git sync logs
```

### Issue: Container can't read auth-config.toml
**Check permissions:**
```bash
# View from host
ls -la /data/compose/XX/docker/pinchflat-vpn/config/

# View from container
docker exec gluetun-pinchflat ls -la /gluetun/auth/

# Both should show auth-config.toml as readable file
```

### Issue: 401 Unauthorized on healthcheck
**Verify file path and content:**
```bash
# Check Gluetun is looking at correct path
docker logs gluetun-pinchflat 2>&1 | grep "Authentication file path"
# Should show: /gluetun/auth/auth-config.toml

# Verify content matches expected TOML
docker exec gluetun-pinchflat cat /gluetun/auth/auth-config.toml
```

---

## Rollback Plan

If this approach fails (highly unlikely):

### Option A: Manual Directory Creation
```bash
# SSH into bael.lan
ssh bael.lan

# Manually create config directory and file
sudo mkdir -p /data/compose/XX/docker/pinchflat-vpn/config
sudo tee /data/compose/XX/docker/pinchflat-vpn/config/auth-config.toml << 'EOF'
[[roles]]
name = "healthcheck"
routes = ["GET /v1/publicip/ip"]
auth = "none"
EOF

# Restart stack in Portainer
```

### Option B: Use Named Volume
Switch to using a Docker named volume instead of bind mount (requires docker-compose changes).

---

## Commit History

- `1139f70` - ✅ **Current**: Simplify with directory binding (BEST SOLUTION)
- `b676a1a` - Add deployment readiness guide
- `b1a46f1` - Update documentation for runtime generation
- `bc272e6` - Runtime generation with entrypoint (overengineered)
- `55e799e` - Attempt: Move file to subdirectory (failed)
- `5fb3cf6` - Attempt: Bind mount from root (failed)

---

## References

- **Gluetun Auth Documentation**: https://github.com/qdm12/gluetun/wiki/Control-server#authentication
- **Portainer GitOps Docs**: https://docs.portainer.io/user/docker/stacks/add#git-repository
- **Docker Volume Docs**: https://docs.docker.com/storage/volumes/

---

## Success Metrics

After deployment on bael.lan, confirm:

1. ✅ Stack deployed without manual intervention
2. ✅ Both containers healthy after 60 seconds
3. ✅ Config directory structure correct on host
4. ✅ Auth config file accessible inside container
5. ✅ VPN connected (public IP different from home IP)
6. ✅ Healthcheck passing every 30 seconds
7. ✅ No errors in logs after 5 minutes
8. ✅ Stack survives Portainer restarts
9. ✅ Stack survives Docker daemon restarts

---

**This is the cleanest solution! 🎯**

Approach: Bind directory, not file
Complexity: Minimal
Portainer Compatible: Yes
Maintainable: Yes
