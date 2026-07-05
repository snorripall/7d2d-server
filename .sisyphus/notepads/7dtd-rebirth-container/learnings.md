# Learnings: 7dtd-rebirth-container

## Conventions
- Game files sourced from: `~/.local/share/Steam/steamapps/common/7 Days To Die Dedicated Server`
- Mod archive: `/home/snorri/Downloads/REBIRTH EXPERIMENTAL 2026.07.02 2245 - 7dtd v2.6 b14.zip`
- Image tag: `snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245`
- Runtime user: `steam` UID/GID 1000
- UserDataFolder: `/data`
- Ports: 26900-26903 UDP+TCP, 8080 TCP, 8081 TCP

## Patterns
- Dockerfile uses split COPY layers to stay under Docker Hub 5GB limit
- Mods installed under `/server/Mods/` with no group wrapper directories
- serverconfig.xml is hydrated from template at runtime via entrypoint.sh
- Graceful shutdown via `exec` in entrypoint

## Decisions
- Private Docker Hub repository by default (legal/ToS risk)
- Named volumes for saves/logs/config persistence
- EAC disabled
- No SteamCMD at runtime, no runtime mod installation

## Task 2: Project structure & .dockerignore
- Root placeholder files created: `Dockerfile`, `docker-compose.yml`, `serverconfig.xml.template`, `entrypoint.sh`, `build.sh`, `push.sh`, `.dockerignore`, `.env.example`.
- `.dockerignore` excludes local saves, logs, cache, Steam metadata, `REBIRTH*.zip`, `.env`, `.git`, `.sisyphus/evidence/`, and host-generated files.
- `.env.example` contains placeholders for `SERVER_NAME`, `SERVER_PASSWORD`, `SERVER_PORT`, `GAME_WORLD`, `GAME_NAME`, `SERVER_VISIBILITY`, `TELNET_PASSWORD`, `WEB_DASHBOARD_PASSWORD`.
- Evidence captured in `.sisyphus/evidence/task-2-structure.txt` and `.sisyphus/evidence/task-2-dockerignore.txt`.

## Task 4: Dockerfile runtime base
- Created `/home/snorri/gaming/7d2d-server/Dockerfile` with `FROM ubuntu:24.04`.
- Installed runtime libs: lib32gcc-s1, libsdl2-2.0-0, libcurl4, ca-certificates, curl, gettext-base, libgl1, libxcursor1, libxrandr2, libxi6, libxinerama1, libxxf86vm1, libasound2t64.
- Removed pre-existing `ubuntu` user/group (UID/GID 1000) before creating `steam` user/group with UID/GID 1000 and home `/home/steam`.
- Set `WORKDIR /server`, exposed 26900-26903/udp, 26900-26903/tcp, 8080/tcp, 8081/tcp, and created `/data` owned by `steam:steam`.
- Added placeholders for future COPY server files, mod groups, entrypoint.sh, and `USER steam`.
- Verified `docker build -t 7dtd-rebirth:base .` exits 0 and `docker run --rm 7dtd-rebirth:base id steam` returns uid=1000.
- Evidence captured in `.sisyphus/evidence/task-4-base-build.txt` and `.sisyphus/evidence/task-4-user-check.txt`.

## Task 1: Version and size verification
- Correct server install directory name is `7 Days to Die Dedicated Server` (lowercase "to"), not `7 Days To Die Dedicated Server`.
- Server version files (`version.txt`, `VersionInfo.json`) were absent from the expected paths; the definitive version came from running the Linux binary, which printed: `Version: V 3.0.0 (b259) Compatibility Version: V 3.0.0`.
- Steam `appmanifest_294420.acf` shows `buildid 23906567`; the SteamCMD API reports this buildid for both `public` and `latest_experimental` branches.
- Mod archive `/home/snorri/Downloads/REBIRTH EXPERIMENTAL 2026.07.02 2245 - 7dtd v2.6 b14.zip` targets `7dtd v2.6 b14`.
- **Compatibility result: MISMATCH.** Installed server is V 3.0.0 (b259); must downgrade/reinstall to v2.6 b14 before using this mod.
- Server folder size: `17G` per `du -sh`.
- Mod archive: `11G` compressed.
- Extracted mod: `13G` disk usage (`12.34 GiB` actual), 52 top-level modlet folders.
- Layer split plan: 3 COPY layers, each under 5 GiB (~5.00 GiB, ~5.00 GiB, ~2.34 GiB).
- Evidence captured in `.sisyphus/evidence/task-1-version-check.txt` and `.sisyphus/evidence/task-1-size-check.txt`.

## Task 3: serverconfig.xml.template
- Source: `~/.local/share/Steam/steamapps/common/7 Days to Die Dedicated Server/serverconfig.xml`
- Output: `/home/snorri/gaming/7d2d-server/serverconfig.xml.template`
- Placeholder syntax: `${VAR:-default}` for envsubst-style substitution in entrypoint.sh
- 12 unique placeholders added: SERVER_NAME, SERVER_PASSWORD, SERVER_PORT, SERVER_VISIBILITY, GAME_WORLD, GAME_NAME, TELNET_ENABLED, TELNET_PORT, TELNET_PASSWORD, WEB_DASHBOARD_ENABLED, WEB_DASHBOARD_PORT, WEB_DASHBOARD_PASSWORD
- EAC disabled (`EACEnabled` = `false`)
- UserDataFolder set to `/data`
- XML validated with `xmllint --noout`
- Evidence captured in `.sisyphus/evidence/task-3-template-check.txt` and `.sisyphus/evidence/task-3-xml-valid.txt`

## Task 5 (prerequisite research): Obtaining 7DTD v2.6 b14 via SteamCMD

### Authoritative source used
- Local `steamcmd` install in `/tmp/steamcmd` queried with `+login anonymous +app_info_update 1 +app_info_print 294420` on 2026-07-05.
- SteamCMD API (`https://api.steamcmd.net/v1/info/294420`) confirmed the same branch/depot data.

### Current branch situation for AppID 294420 (7 Days to Die Dedicated Server)
- `public` → buildid **23906567** (V 3.0.0 b259) — this matches the locally installed server.
- `latest_experimental` → buildid **23906567** (currently also V 3.0.0 b259).
- `v3.0.0` → buildid **23906567** (Version 3.0.0 Stable).
- `v2.6` → buildid **22422094** (Version 2.6 Stable).
- `v2.5`, `v2.4`, `v2.0`, `v1.4`, `alpha21.2`, `alpha20.7`, `alpha19.6`, `alpha18.4`, `alpha17.4`, `alpha16.4`, `alpha15.2`, `alpha14.7`, `alpha13.8`, `alpha12.5`, `alpha11.6`, `alpha10.4`, `alpha9.3`, `alpha8.8` are also retained.

### Critical finding: no public branch for v2.6 b14 specifically
- There is **no** Steam beta branch named `v2.6_b14`, `v2.6-b14`, `latest_experimental` pointing to b14, or similar.
- `latest_experimental` now points to V 3.0.0 b259.
- The only official way to get a V 2.6 server today is the `v2.6` stable branch (buildid 22422094).
- V 2.6 b14 was the **experimental** build released 2026-03-21; it was superseded by V 2.6 Stable in April 2026.

### Closest available official version
- Branch: `v2.6`
- Windows depot: **294421**, manifest gid **4973862835415237937**, size ~16.97 GB, download ~12.73 GB.
- Linux depot: **294422**, manifest gid **5955696906242074551**, size ~16.92 GB, download ~12.66 GB.
- These are the **V 2.6 Stable** manifests, not the historical b14 experimental manifests.

### SteamCMD commands that work today
```bash
# Linux server, V 2.6 Stable (closest official to v2.6 b14)
./steamcmd.sh \
  +@sSteamCmdForcePlatformType linux \
  +force_install_dir /home/steam/7dtd-v2.6 \
  +login anonymous \
  +app_update 294420 -beta v2.6 validate \
  +quit

# Windows server, V 2.6 Stable
./steamcmd.sh \
  +@sSteamCmdForcePlatformType windows \
  +force_install_dir /path/to/7dtd-v2.6 \
  +login anonymous \
  +app_update 294420 -beta v2.6 validate \
  +quit
```

### If an exact v2.6 b14 build is required
- It is **not** available through any public beta branch.
- You must use `download_depot` with the historical manifest IDs for the b14 experimental build.
- The historical manifest IDs for b14 are **not** exposed by Steam’s public APIs; they would have to come from SteamDB history, a personal depot cache, or a community manifest archive (e.g., ManifestHub).
- Known depot IDs for `download_depot`:
  - Windows: `download_depot 294420 294421 <b14_manifest_id>`
  - Linux: `download_depot 294420 294422 <b14_manifest_id>`
- The current V 2.6 Stable manifest IDs (above) can be used with `download_depot` if V 2.6 Stable is acceptable instead of b14.

### Authentication
- Anonymous login works for AppID 294420 (it is marked `freetodownload` in Steam metadata).
- No Steam Guard or game ownership is required for the dedicated server tool.

### Expected install layout and size
- Install dir name configured by Steam: `7 Days to Die Dedicated Server`.
- Expected size: ~16.9–17.6 GB on disk depending on branch (v2.6 ~16.9 GB; public V3.0 ~17.6 GB).
- Key Linux binaries: `7DaysToDieServer.x86_64`, `startserver.sh`, `UnityPlayer.so`, `steamclient.so`.
- Key config: `serverconfig.xml`.
- Content folders: `7DaysToDieServer_Data/`, `Data/`, `Mods/`.

### Relevant external references
- Official 7DTD v2.6 b14 EXP announcement: https://community.thefunpimps.com/threads/v2-6-exp-updated-b14.46837/
- Official v2.6 Stable announcement: https://7daystodie.com/v2-6-stable/
- SteamCMD API info for 294420: https://api.steamcmd.net/v1/info/294420
- Celltek reference confirming buildid 22422094 / 16.58 GB for 294420: https://www.celltek.space/apps/7dtd

## Task 8: Entrypoint script
- Created `/home/snorri/gaming/7d2d-server/entrypoint.sh` with `set -euo pipefail`.
- Entrypoint starts as root, creates `/data/saves`, `/data/logs`, `/data/config`, and runs `chown -R steam:steam /data` before dropping privileges.
- Config hydration uses a Python fallback because `envsubst` (gettext-base) does **not** understand `${VAR:-default}` syntax; the envsubst path is kept for plain `${VAR}` placeholders.
- `LD_LIBRARY_PATH` is exported as `/server` so the Unity server binary finds bundled `.so` files.
- The server is launched with `exec gosu steam /server/7DaysToDieServer.x86_64 -configfile=/data/config/serverconfig.xml -quit -batchmode -nographics -dedicated` so signals pass through for graceful shutdown.
- Added `--dry-run-config` mode for testing config hydration without launching the server or touching `/data`.
- Updated `Dockerfile` to install `gosu`, copy `serverconfig.xml.template` and `entrypoint.sh` into `/server`, mark the script executable, and set `ENTRYPOINT ["/server/entrypoint.sh"]`.
- Verified `SERVER_NAME=TestRebirth SERVER_PASSWORD=secret123` are substituted correctly and unset placeholders fall back to their defaults.
- Evidence captured in `.sisyphus/evidence/task-8-config-hydration.txt` and `.sisyphus/evidence/task-8-exec-check.txt`.


## Task 6: Stage and split Rebirth mod folders into layer groups
- Extracted Rebirth zip to `/tmp/rebirth-staging`; verified 52 top-level modlet folders.
- Grouped folders into `/tmp/rebirth-groups/mods-group-{0,1,2}` following the T1 size plan:
  - mods-group-0: 8 folders, 5368698750 bytes (~5.000 GiB)
  - mods-group-1: 15 folders, 5368689656 bytes (~5.000 GiB)
  - mods-group-2: 29 folders, 2509405089 bytes (~2.337 GiB)
- All groups are within the Docker Hub 5 GiB layer limit (actual uncompressed bytes).
- Note: a strict 4 GiB per group limit is impossible with 3 groups because the total mod size is ~12.34 GiB; the T1 plan and Docker Hub limit are ~5 GiB.
- Manifest written to `/home/snorri/gaming/7d2d-server/mod-groups.txt`.
- Evidence captured in `.sisyphus/evidence/task-6-group-count.txt`, `.sisyphus/evidence/task-6-group-sizes.txt`, and `.sisyphus/evidence/task-6-verification.txt`.
- Pitfall: bash has a readonly array variable named `GROUPS`; use `DEST` or another variable name for the group directory path to avoid silent mis-expansion.
- `/tmp/rebirth-groups` is retained for T7 (Dockerfile COPY layers).

## Task 5 (implementation): SteamCMD build-time server download

### Dockerfile changes
- Changed `FROM ubuntu:24.04` to `FROM ubuntu:24.04 AS stage-server` to expose the intermediate build target.
- Added a single RUN layer after `/data` setup that:
  1. Downloads `https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz` to `/tmp` and extracts it into `/opt/steamcmd`.
  2. Installs a `/usr/local/bin/steamcmd` wrapper script instead of a symlink, because `steamcmd.sh` uses `$SCRIPT_DIR/linux32/steamcmd` internally and a symlink resolves the script dir to `/usr/local/bin`.
  3. Runs `steamcmd +@sSteamCmdForcePlatformType linux +force_install_dir /server +login anonymous +app_update 294420 -beta v2.6 validate +quit`.
  4. Removes `/server/Package` metadata and `/root/Steam` / `/root/.steam` logs to keep the layer lean.
  5. Fixes ownership with `chown -R steam:steam /server` and permissions with `chmod -R u+rwX /server`.

### Build verification
- `docker build --target stage-server -t 7dtd-rebirth:stage-server .` completed successfully.
- `docker run --rm 7dtd-rebirth:stage-server ls -l /server/7DaysToDieServer.x86_64` shows `steam steam` ownership and executable permissions.
- `docker run --rm 7dtd-rebirth:stage-server ldd /server/7DaysToDieServer.x86_64` reports no missing libraries.

### Gotchas
- A naive symlink of `steamcmd.sh` into `/usr/local/bin` fails with `/usr/local/bin/linux32/steamcmd: No such file or directory`; use a wrapper script that calls `/opt/steamcmd/steamcmd.sh`.
- SteamCMD writes to `/root/Steam` even when installing to another directory; cleaning it after the download avoids log bloat in the image layer.

### Evidence
- `.sisyphus/evidence/task-5-server-copy.txt`
- `.sisyphus/evidence/task-5-ldd-check.txt`

## Task 11: Docker Compose
- Created `/home/snorri/gaming/7d2d-server/docker-compose.yml` with service `7dtd-rebirth`.
- Image: `snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245`.
- Ports: `26900-26903` mapped for both UDP and TCP; `8080/tcp` (web dashboard) and `8081/tcp` (telnet) are commented out by default.
- Named volumes mounted for persistence: `7dtd-saves` → `/data/saves`, `7dtd-logs` → `/data/logs`, `7dtd-config` → `/data/config`.
- Environment loaded from `.env` via `env_file`; `.env` was created from `.env.example` so `docker compose config` can resolve the env file.
- Restart policy: `unless-stopped`; memory limits: 24 GB limit / 16 GB reservation.
- Validation: `docker compose -f /home/snorri/gaming/7d2d-server/docker-compose.yml config` exits 0 and lists all three named volumes.
- Evidence captured in `.sisyphus/evidence/task-11-compose-valid.txt` and `.sisyphus/evidence/task-11-volumes.txt`.

## Layer split fix: reduce COPY layers under 5 GiB

- Problem: the original 3-group split produced uncompressed COPY layers of ~5.37 GB, ~5.39 GB, and ~2.51 GB, exceeding Docker Hub's safe 5 GB layer limit.
- Solution: redistributed the 52 Rebirth mod folders into 4 groups using first-fit-decreasing bin packing with a 3.5 GiB per-group cap.
- New groups (uncompressed file bytes):
  - mods-group-0: 7 folders, 3,758,095,376 bytes (3.500 GiB)
  - mods-group-1: 18 folders, 3,758,019,536 bytes (3.500 GiB)
  - mods-group-2: 9 folders, 3,757,396,780 bytes (3.499 GiB)
  - mods-group-3: 18 folders, 1,973,281,803 bytes (1.838 GiB)
- Total: 52 folders, 13,246,793,495 bytes (12.337 GiB).
- Files updated: `/home/snorri/gaming/7d2d-server/mod-groups.txt`, `/home/snorri/gaming/7d2d-server/Dockerfile`.
- Dockerfile now has 4 COPY lines (`mods-group-0` through `mods-group-3`) into `/server/Mods/`; the `zz_REBIRTH__Core_2_0` ModInfo.xml generation step remains unchanged.
- Verification: all 52 mod folders are included exactly once and every group is ≤3.5 GiB uncompressed, giving comfortable headroom under the 5 GB Docker Hub layer limit.
- Note: the actual `/tmp/rebirth-groups/` tree on disk was rebuilt by re-extracting the source zip after an earlier partial cleanup removed folders; the final grouping was generated from a clean extraction.


## Task 3 fix: serverconfig.xml.template v2.6 b14 compatibility

- Rebased `/home/snorri/gaming/7d2d-server/serverconfig.xml.template` on `/tmp/serverconfig-v2.6-default.xml` extracted from the built image (`/server/serverconfig.xml`).
- Removed the V 3.0.0-specific `WebDashboardPassword` property; v2.6 b14 only has `WebDashboardEnabled`, `WebDashboardPort`, and `WebDashboardUrl`.
- Updated `.env.example` to remove the unused `WEB_DASHBOARD_PASSWORD` placeholder.
- Retained runtime placeholders using `${VAR:-default}` syntax for envsubst-compatible hydration:
  - `ServerName`, `ServerPassword`, `ServerPort`, `ServerVisibility`
  - `GameWorld`, `GameName`
  - `TelnetEnabled`, `TelnetPort`, `TelnetPassword`
  - `WebDashboardEnabled`, `WebDashboardPort`
- Forced `EACEnabled` to `false` and uncommented `UserDataFolder` with value `/data`.
- Validated the rewritten template with `xmllint --noout` and confirmed it is well-formed.
- Evidence captured in `.sisyphus/evidence/task-3-template-check-v2.txt` and `.sisyphus/evidence/task-3-xml-valid-v2.txt`.
