terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      # Latest registry release as of 2026-10-31. Still a release candidate;
      # bump only in a later plan after re-running validate.
      version = "3.0.2-rc10"
    }
  }
}
