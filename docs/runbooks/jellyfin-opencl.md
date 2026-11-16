# Runbook: Intel OpenCL runtime on Jellyfin (CT 180)

Jellyfin on CT 180 `jellyfin-blr-lxc` (10.10.0.80) transcodes with QSV on
the Intel Arc Pro B60 (Battlemage BMG-G21, `xe` driver, host kernel
7.0.14-pve). HDR/Dolby Vision tone mapping uses `tonemap_opencl`, which
needs Intel's OpenCL runtime inside the guest.

## Why not the Ubuntu package

Ubuntu 24.04 ships `intel-opencl-icd` 23.43, which predates Battlemage.
The role installs Intel's official release `.deb`s instead, pinned and
sha256-verified (compute-runtime `ww40.sum`, IGC release notes):

| Package | Version | Source |
|---|---|---|
| `intel-opencl-icd` | 26.40.40196.8-0 | intel/compute-runtime release 26.40.40196.8 |
| `libigdgmm12` | 22.10.2 (replaces noble 22.3.17) | same release |
| `intel-igc-core-2`, `intel-igc-opencl-2` | 2.42.6 | intel/intel-graphics-compiler v2.42.6 |
| `ocl-icd-libopencl1` | 2.3.2 (already present) | Ubuntu |
| `clinfo` | 3.0.23.01.25 | Ubuntu |

Not installed: `intel-ocloc`, `libze-intel-gpu1` (Level Zero), debug
symbols. Battlemage OpenCL does not need Level Zero (that limitation is
Nova Lake only).

Jellyfin keeps its bundled iHD media driver (jellyfin-ffmpeg 8.1.3, iHD
26.3.5). Jellyfin settings (OpenCL tone mapping toggle) belong to the arr
stack owner, not this role.

## Apply

From `ansible/`, with the gitignored inventory:

```
ansible-playbook playbooks/jellyfin-opencl.yml --check --diff
ansible-playbook playbooks/jellyfin-opencl.yml
```

Live install 2026-11-16 was by hand via `pct exec 180` with the same pins.

## Verify

```
runuser -u jellyfin -- clinfo -l
runuser -u jellyfin -- /usr/lib/jellyfin-ffmpeg/ffmpeg -v verbose -init_hw_device vaapi=va:/dev/dri/renderD128 -init_hw_device opencl=ocl@va -f lavfi -i nullsrc -t 1 -f null -
```

Expected: `Intel(R) OpenCL Graphics (discrete)` / `Intel(R) Arc(TM) Pro B60
Graphics`, Driver Version 26.40.40196.8, and ffmpeg finding the
`clCreateFromVA_APIMediaSurfaceINTEL` mapping. 2026-11-16: a 4K P010 PQ
test pattern through `tonemap_opencl=tonemap=bt2390` ran at about 80 fps.

## Upgrade

Bump the version and sha256 values in
`ansible/roles/jellyfin_opencl/defaults/main.yml` from the next
compute-runtime release (its `wwNN.sum` and the matching IGC release).

## Rollback

No snapshot: CT 180 has bind mounts, so `pct snapshot` reports the
feature unavailable. The change is packages only:

```
apt-get remove intel-opencl-icd intel-igc-opencl-2 intel-igc-core-2 clinfo
```

`libigdgmm12` 22.10.2 is ABI-compatible with noble's 22.3.17 and can stay;
to go back exactly, `apt-get install --allow-downgrades libigdgmm12=22.3.17+ds1-1ubuntu1`.
Jellyfin then needs OpenCL tone mapping turned off, or it falls back.
