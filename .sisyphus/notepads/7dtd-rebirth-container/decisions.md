# Decisions: 7dtd-rebirth-container

## [2026-07-05] Plan Selected
- Plan: 7dtd-rebirth-container
- Working directory: /home/snorri/gaming/7d2d-server
- Session: ses_0cc531d98ffeL3lt2CEPU3MzuI

## [2026-07-05] Decision: Resolve V 3.0.0 / v2.6 b14 mismatch with build-time SteamCMD download

### Chosen path
- **Selected option**: Option 2 — modify the Dockerfile to install the dedicated server via SteamCMD at build time using the `v2.6` beta branch.
- **Rationale**: Reproducible, container-native, does not modify the host Steam install, and the `v2.6` stable branch is the closest official V 2.6 build still available from Steam. The exact v2.6 b14 experimental manifest is no longer publicly exposed.

### Implementation notes
- Dockerfile will install SteamCMD, then run:
  ```
  steamcmd +@sSteamCmdForcePlatformType linux +force_install_dir /server +login anonymous +app_update 294420 -beta v2.6 validate +quit
  ```
- Downloaded files will be `chown -R steam:steam /server`.
- Runtime re-download remains forbidden; the server is baked into the image.
- If the mod fails on V 2.6 Stable, revisit Option 3 (historical b14 manifest IDs) as a fallback.

### Status
- Plan updated in `.sisyphus/plans/7dtd-rebirth-container.md`.
- Proceeding to T5/T6/T7/T8 implementation.
