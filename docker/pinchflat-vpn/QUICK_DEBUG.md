# Quick Diagnostic Commands for bael.lan Pinchflat Deployment

## Run these commands via SSH to diagnose the issue:

```bash
# 1. Check GitOps directory structure
ls -la /data/compose/23/docker/pinchflat-vpn/

# 2. Check if config directory exists
ls -la /data/compose/23/docker/pinchflat-vpn/config/

# 3. Check if auth-config.toml is a file or directory
file /data/compose/23/docker/pinchflat-vpn/config/auth-config.toml

# 4. View auth config content (if it's a file)
cat /data/compose/23/docker/pinchflat-vpn/config/auth-config.toml

# 5. Check for old auth-config.toml in root
ls -la /data/compose/23/docker/pinchflat-vpn/auth-config.toml 2>&1

# 6. Check docker-compose.yml volume mount
grep -A 3 "volumes:" /data/compose/23/docker/pinchflat-vpn/docker-compose.yml | head -6

# 7. Check .env file exists
ls -la /data/compose/23/docker/pinchflat-vpn/.env

# 8. Try to start manually to see real error
cd /data/compose/23/docker/pinchflat-vpn && docker-compose up -d

# 9. Wait a bit then check container status
sleep 10 && docker ps -a | grep -E "(gluetun-pinchflat|pinchflat)"

# 10. Check gluetun logs for actual error
docker logs --tail 50 gluetun-pinchflat 2>&1

# 11. Check if file is mounted in container
docker exec gluetun-pinchflat ls -la /gluetun/auth/config.toml 2>&1

# 12. Try to read the file from inside container
docker exec gluetun-pinchflat cat /gluetun/auth/config.toml 2>&1
```

## If config/auth-config.toml is still a directory:

```bash
# Clean up the bad directory
sudo rm -rf /data/compose/23/docker/pinchflat-vpn/config/auth-config.toml
sudo rm -rf /data/compose/23/docker/pinchflat-vpn/auth-config.toml

# Force Portainer to re-pull from git
# Go to Portainer UI → Stacks → pinchflat-vpn → "Pull and redeploy"
```

## If .env file is missing:

Check Portainer stack environment variables are configured:
- DOCKER_VOLUMES_PATH
- WIREGUARD_PRIVATE_KEY
- VPN_SERVICE_PROVIDER
- TZ
- PUID
- PGID

## Key Things to Check:

1. **Is `config/auth-config.toml` a file or directory?**
   - Must be a FILE with TOML content
   - If it's a directory, Portainer GitOps is still having issues

2. **Does the bind mount path match in docker-compose.yml?**
   - Should be: `./config/auth-config.toml:/gluetun/auth/config.toml:ro`

3. **Are there any permission issues?**
   - File should be readable (644 or similar)
   - Check owner/group

4. **What do the actual container logs say?**
   - Portainer logs don't show the real error
   - Need to check `docker logs gluetun-pinchflat`

## Most Likely Issues:

Based on the Portainer logs pattern (Waiting → Error → Rollback):

### Issue A: Bind Mount Fails
- File doesn't exist or is still a directory
- Causes: Container can't start because mount fails

### Issue B: Healthcheck Timeout
- Container starts but healthcheck never passes
- Causes: VPN not connecting, auth config not loaded, control server not starting

### Issue C: Environment Variables Missing
- Required VPN credentials not set
- Check Portainer stack environment variables

## Next Steps:

Run commands 1-12 above and share:
1. Output of command #3 (file type check)
2. Output of command #4 (file content) 
3. Output of command #10 (gluetun logs)
4. Output of command #11 (mount check)

This will tell us the exact failure point.
