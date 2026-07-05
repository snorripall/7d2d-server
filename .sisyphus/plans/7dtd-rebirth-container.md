# 7 Days to Die + Rebirth Dedicated Server Container

## TL;DR

> Build a Docker image containing the local Steam-downloaded 7 Days to Die dedicated server and the Rebirth overhaul mod, push it to Docker Hub (`snorripall/7dtd-rebirth`), and deploy it on an Ubuntu Hetzner server via Coolify using a Docker Compose stack with named volumes.
>
> **Deliverables**:
> - `Dockerfile` (Ubuntu 24.04 base, non-root `steam` user, split COPY layers)
> - `docker-compose.yml` (named volumes, ports, restart policy)
> - `serverconfig.xml` template (EAC disabled, runtime placeholders)
> - `entrypoint.sh` (permissions fix, graceful shutdown, config hydration)
> - Helper scripts: `build.sh`, `push.sh`
> - Coolify deployment notes
>
> **Estimated Effort**: Medium
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: T1 → T4 → T7 → T9 → T10 → T13 → F1-F4

---

## Context

### Original Request
Containerize a 7 Days to Die dedicated server with the Rebirth mod, build the image locally, push to a registry, and deploy via Coolify on Hetzner using named volumes.

### Interview Summary
**Key Decisions**:
- **Game source**: Download the 7 Days to Die Dedicated Server at build time via SteamCMD (`app_update 294420 -beta v2.6`) because the locally installed server is V 3.0.0 (b259) and the Rebirth mod requires a v2.6 build. The exact `v2.6 b14` experimental manifest is no longer publicly exposed by Steam; the `v2.6` stable branch is the closest reproducible target and is mod-compatible.
- **Mod source**: `/home/snorri/Downloads/REBIRTH EXPERIMENTAL 2026.07.02 2245 - 7dtd v2.6 b14.zip`.
- **Build strategy**: Bake SteamCMD-downloaded game files + Rebirth mod into the image locally, push to registry, then pull with `docker-compose`.
- **Registry**: Docker Hub, user `snorripall`, already logged in via `docker login -u snorripall`.
- **Target host**: Ubuntu server running Coolify on Hetzner.
- **Persistence**: Named Docker volumes.
- **Defaults delegated to planner**: base image, ports, runtime user, deployment method, config values.

### Research Findings
- The Rebirth archive is 10.45 GiB compressed / 12.34 GiB uncompressed and contains 52 standard 7DTD modlet folders, each with `ModInfo.xml`.
- Installation method: extract every top-level directory into `<server>/Mods/`; no `Data/Config` overrides.
- 7DTD dedicated server App ID is 294420; Rebirth requires matching game version and EAC disabled.
- Docker Hub free personal plan includes 1 private repository; public redistribution of game/mod files is legally risky, so the repository will be private by default.
- Coolify Docker Compose stack is the safer deployment path for game servers (UDP ports + named volumes) versus the `dockerimage` build pack.

### Metis Review
**Identified Gaps** (addressed in plan):
- **Build-time game download**: SteamCMD downloads 7DTD dedicated server AppID 294420 with `-beta v2.6` during `docker build`. The exact v2.6 b14 experimental manifest is no longer publicly exposed by Steam, so the `v2.6` stable branch is the closest reproducible target and is mod-compatible.
- Runtime re-download is still forbidden.
- The Dockerfile layer split must keep both the downloaded game files and the mod under Docker Hub limits.
- Legal/ToS: default to private Docker Hub repo; no public redistribution.
- Secrets: no passwords/tokens baked into image layers.
- Graceful shutdown: entrypoint must use `exec` and handle SIGTERM.
- Permissions: first-start volume permission fix for non-root user.
- Port/protocol contract: explicit UDP/TCP range and optional web/telnet disabled by default.

---

## Work Objectives

### Core Objective
Produce a reproducible, privately-hosted Docker image and Compose deployment for a Rebirth-modded 7 Days to Die dedicated server that runs successfully on a Coolify-managed Ubuntu host.

### Concrete Deliverables
- `Dockerfile`
- `docker-compose.yml`
- `serverconfig.xml.template`
- `entrypoint.sh`
- `build.sh`
- `push.sh`
- `.dockerignore`
- `.env.example`
- Coolify deployment notes in plan

### Definition of Done
- Image builds locally with zero missing shared libraries.
- Image starts the server without fatal errors in local smoke test.
- Image is pushed to Docker Hub and pullable from the Hetzner host.
- Coolify deploys the Compose stack; server ports respond; saves persist across redeploy.

### Must Have
- Game files and Rebirth mod baked into the image.
- EAC disabled.
- Named volumes for saves, logs, and runtime config.
- Private Docker Hub repository.
- Non-root container runtime user.
- Graceful shutdown handling.

### Must NOT Have (Guardrails)
- **No runtime SteamCMD download** — game files must be baked into the image at build time.
- **No runtime mod installation**.
- **No secrets in image layers**.
- **No public redistribution of game/mod files**.
- **No mutable save/log data baked into the image**.
- **No reverse proxy, SSL, backups, or monitoring** (out of scope).

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: NO (no existing project files; workspace is empty).
- **Automated tests**: Tests-after (smoke tests as part of build/QA tasks).
- **Framework**: Shell-based verification via `docker`, `docker compose`, `ldd`, `nc`, `curl`, and log greps.
- **Agent-Executed QA**: MANDATORY for every task.

### QA Policy
Every task MUST include agent-executed QA scenarios. Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Image build/runtime**: Bash (`docker build`, `docker run`, `ldd`).
- **Network reachability**: Bash (`nc -u`, `curl`).
- **Persistence**: Bash (file marker test across `docker compose down/up`).
- **Coolify deployment**: Bash (`docker ps`, `docker compose ps`, `curl` from Hetzner host).

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation):
├── T1: Verify versions and measure source sizes
├── T2: Create project structure and .dockerignore
├── T3: Create serverconfig.xml template
└── T4: Create Dockerfile runtime base

Wave 2 (Image content):
├── T5: Install SteamCMD and download v2.6 dedicated server into image (depends: T1, T2, T4)
├── T6: Stage and split Rebirth mod folders (depends: T1, T2)
├── T7: Add mod COPY layers to Dockerfile (depends: T4, T6)
└── T8: Create entrypoint script (depends: T3, T4)

Wave 3 (Build & local test):
├── T9: Build image locally (depends: T5, T7, T8)
├── T10: Push image to Docker Hub (depends: T9)
├── T11: Create docker-compose.yml (depends: T3, T8)
└── T12: Local smoke test (depends: T9, T11)

Wave 4 (Coolify deployment):
├── T13: Prepare Coolify Compose resource (depends: T10, T11)
├── T14: Configure Hetzner firewall (depends: T13)
└── T15: Deploy and verify on Coolify (depends: T13, T14)

Wave FINAL:
├── F1: Plan compliance audit (oracle)
├── F2: Code quality review (unspecified-high)
├── F3: Real manual QA (unspecified-high)
└── F4: Scope fidelity check (deep)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| T1 | - | T5, T6, T9 |
| T2 | - | T5, T6, T11 |
| T3 | - | T8, T11 |
| T4 | - | T5, T7, T8 |
| T5 | T1, T2, T4 | T9 |
| T6 | T1, T2 | T7 |
| T7 | T4, T6 | T9 |
| T8 | T3, T4 | T9, T11 |
| T9 | T5, T7, T8 | T10, T12 |
| T10 | T9 | T13 |
| T11 | T3, T8 | T12, T13 |
| T12 | T9, T11 | - |
| T13 | T10, T11 | T15 |
| T14 | T13 | T15 |
| T15 | T13, T14 | - |

### Agent Dispatch Summary

- **Wave 1**: T1 → `quick`, T2 → `quick`, T3 → `quick`, T4 → `quick`
- **Wave 2**: T5 → `unspecified-high`, T6 → `unspecified-high`, T7 → `unspecified-high`, T8 → `quick`
- **Wave 3**: T9 → `unspecified-high`, T10 → `quick`, T11 → `quick`, T12 → `unspecified-high`
- **Wave 4**: T13 → `quick`, T14 → `quick`, T15 → `unspecified-high`
- **FINAL**: F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [x] 1. Verify game/mod version compatibility and measure source sizes

  **What to do**:
  - Read the local dedicated server folder and identify the 7DTD build version (look for `version.txt`, `7DaysToDieServer_Data/StreamingAssets/VersionInfo.json`, or Steam `appmanifest_294420.acf`).
  - Confirm the game build matches the mod's declared target (`7dtd v2.6 b14`).
  - Measure exact disk usage of the server folder and the extracted mod archive (unzip to a temp staging directory and `du -sh`).
  - Determine how many COPY layers are needed to keep each layer under Docker Hub's recommended 5 GB limit.
  - Record the verified version strings and sizes in the project README notes.

  **Must NOT do**:
  - Do not modify or delete the original Steam download.
  - Do not leave the extracted mod files in the workspace permanently; stage them under `/tmp` or a build-time folder only.

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Pure inspection and measurement; no implementation yet.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with T2, T3, T4)
  - **Blocks**: T5, T6, T9
  - **Blocked By**: None

  **References**:
  - `~/.local/share/Steam/steamapps/common/7 Days To Die Dedicated Server` - Source game files.
  - `/home/snorri/Downloads/REBIRTH EXPERIMENTAL 2026.07.02 2245 - 7dtd v2.6 b14.zip` - Source mod archive.
  - Docker Hub docs on image/layer size limits.

  **Acceptance Criteria**:
  - [ ] `du -sh ~/.local/share/Steam/steamapps/common/7\ Days\ To\ Die\ Dedicated\ Server` output recorded.
  - [ ] Extracted mod size measured and recorded.
  - [ ] Game build version identified and matches mod target.
  - [ ] Layer-splitting plan documented (e.g., "server files in one layer; mods split into 3 COPY groups by folder size").

  **QA Scenarios**:

  ```
  Scenario: Verify game version file exists
    Tool: Bash
    Preconditions: Steam dedicated server installed locally.
    Steps:
      1. ls ~/.local/share/Steam/steamapps/common/7\ Days\ To\ Die\ Dedicated\ Server/version.txt 2>/dev/null || find ~/.local/share/Steam/steamapps/common/7\ Days\ To\ Die\ Dedicated\ Server -maxdepth 3 -iname '*version*' -type f
      2. cat the version file or inspect the Steam manifest.
    Expected Result: A version string is found and contains "2.6" or "b14".
    Failure Indicators: No version file found or version does not match mod target.
    Evidence: .sisyphus/evidence/task-1-version-check.txt

  Scenario: Measure source sizes
    Tool: Bash
    Preconditions: Mod archive exists and is readable.
    Steps:
      1. du -sh ~/.local/share/Steam/steamapps/common/7\ Days\ To\ Die\ Dedicated\ Server
      2. mkdir -p /tmp/rebirth-staging && unzip -q "/home/snorri/Downloads/REBIRTH EXPERIMENTAL 2026.07.02 2245 - 7dtd v2.6 b14.zip" -d /tmp/rebirth-staging
      3. du -sh /tmp/rebirth-staging
      4. rm -rf /tmp/rebirth-staging
    Expected Result: Both sizes are recorded; mod size is ~12-13 GiB uncompressed.
    Failure Indicators: Archive unreadable or extraction fails.
    Evidence: .sisyphus/evidence/task-1-size-check.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-1-version-check.txt`
  - [ ] `task-1-size-check.txt`

  **Commit**: NO (gathering info only)

- [x] 2. Create project structure and .dockerignore

  **What to do**:
  - Create the project root files: `Dockerfile`, `docker-compose.yml`, `serverconfig.xml.template`, `entrypoint.sh`, `build.sh`, `push.sh`, `.dockerignore`, `.env.example`.
  - Create `.sisyphus/evidence/` directory.
  - Write `.dockerignore` to exclude: local saves, logs, cache, Steam metadata, the mod zip, `.env`, `.git`, evidence folder, and any host-generated files.
  - Write `.env.example` with placeholder variables (SERVER_NAME, SERVER_PASSWORD, SERVER_PORT, etc.).

  **Must NOT do**:
  - Do not populate file contents; other tasks own the content.
  - Do not commit the `.env` file or the mod zip.

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Scaffolding only.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with T1, T3, T4)
  - **Blocks**: T5, T6, T11
  - **Blocked By**: None

  **References**:
  - Standard `.dockerignore` patterns for Unity/game servers.
  - Docker build context best practices.

  **Acceptance Criteria**:
  - [ ] All expected files exist in `/home/snorri/gaming/7d2d-server/`.
  - [ ] `.dockerignore` exists and excludes the mod archive and local saves.
  - [ ] `.env.example` exists with at least SERVER_NAME, SERVER_PASSWORD, SERVER_PORT placeholders.

  **QA Scenarios**:

  ```
  Scenario: Project files created
    Tool: Bash
    Preconditions: Workspace is empty.
    Steps:
      1. ls /home/snorri/gaming/7d2d-server/Dockerfile /home/snorri/gaming/7d2d-server/docker-compose.yml /home/snorri/gaming/7d2d-server/.dockerignore /home/snorri/gaming/7d2d-server/.env.example
    Expected Result: All four files exist.
    Failure Indicators: Any file missing.
    Evidence: .sisyphus/evidence/task-2-structure.txt

  Scenario: .dockerignore excludes mod zip and saves
    Tool: Bash
    Preconditions: .dockerignore exists.
    Steps:
      1. grep -Ei 'REBIRTH.*\.zip|\.env|Saves|Logs|\.git' /home/snorri/gaming/7d2d-server/.dockerignore
    Expected Result: Each excluded pattern appears at least once.
    Failure Indicators: Missing critical exclusions.
    Evidence: .sisyphus/evidence/task-2-dockerignore.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-2-structure.txt`
  - [ ] `task-2-dockerignore.txt`

  **Commit**: NO (scaffold only)

- [x] 3. Create serverconfig.xml template

  **What to do**:
  - Copy the default `serverconfig.xml` from the local Steam dedicated server folder.
  - Convert it into a template with runtime placeholders for:
    - `ServerName` → `${SERVER_NAME:-7D2D Rebirth Server}`
    - `ServerPassword` → `${SERVER_PASSWORD:-}`
    - `ServerPort` → `${SERVER_PORT:-26900}`
    - `ServerVisibility` → `2` (friends/Steam only; use `1` for public if user overrides)
    - `EACEnabled` → `false`
    - `GameWorld` → `${GAME_WORLD:-Navezgane}`
    - `GameName` → `${GAME_NAME:-RebirthWorld}`
    - `UserDataFolder` → `/data` (so saves/worlds go to named volume)
    - Telnet/WebDashboard ports and passwords from env vars, disabled by default.
  - Save as `serverconfig.xml.template`.
  - Write a small shell snippet (later used by entrypoint) that substitutes placeholders at runtime.

  **Must NOT do**:
  - Do not hardcode real passwords.
  - Do not leave `EACEnabled` as `true`.
  - Do not bake mutable paths into the template.

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: XML templating and env-var substitution.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with T1, T2, T4)
  - **Blocks**: T8, T11
  - **Blocked By**: None

  **References**:
  - `~/.local/share/Steam/steamapps/common/7 Days To Die Dedicated Server/serverconfig.xml` - Default configuration.
  - 7DTD `serverconfig.xml` property reference (official docs / community wiki).

  **Acceptance Criteria**:
  - [ ] `serverconfig.xml.template` exists.
  - [ ] `EACEnabled` is set to `false`.
  - [ ] `UserDataFolder` is set to `/data`.
  - [ ] At least 5 runtime placeholders are present.
  - [ ] Template validates as well-formed XML.

  **QA Scenarios**:

  ```
  Scenario: Template has required settings
    Tool: Bash
    Preconditions: serverconfig.xml.template created.
    Steps:
      1. grep -i 'EACEnabled' /home/snorri/gaming/7d2d-server/serverconfig.xml.template
      2. grep -i 'UserDataFolder' /home/snorri/gaming/7d2d-server/serverconfig.xml.template
      3. grep -c '\${' /home/snorri/gaming/7d2d-server/serverconfig.xml.template
    Expected Result: EACEnabled=false; UserDataFolder=/data; placeholder count >= 5.
    Failure Indicators: EAC still true, no /data path, or fewer than 5 placeholders.
    Evidence: .sisyphus/evidence/task-3-template-check.txt

  Scenario: Template is well-formed XML
    Tool: Bash
    Preconditions: xmllint available or python installed.
    Steps:
      1. xmllint --noout /home/snorri/gaming/7d2d-server/serverconfig.xml.template || python3 -c "import xml.etree.ElementTree as ET; ET.parse('/home/snorri/gaming/7d2d-server/serverconfig.xml.template')"
    Expected Result: Exit code 0.
    Failure Indicators: XML parse error.
    Evidence: .sisyphus/evidence/task-3-xml-valid.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-3-template-check.txt`
  - [ ] `task-3-xml-valid.txt`

  **Commit**: NO (part of final commit group)

- [x] 4. Create Dockerfile runtime base

  **What to do**:
  - Start the `Dockerfile` with `FROM ubuntu:24.04`.
  - Install required runtime libraries:
    - `lib32gcc-s1`
    - `libsdl2-2.0-0`
    - `libcurl4`
    - `ca-certificates`
    - `curl`
    - Any additional library identified by `ldd` in later tasks.
  - Create non-root `steam` user with UID/GID 1000.
  - Set `WORKDIR /server`.
  - Expose ports `26900-26903/udp`, `26900-26903/tcp`, `8080/tcp`, `8081/tcp`.
  - Create `/data` directory owned by `steam`.
  - Leave placeholders/comments for the server COPY and mod COPY layers (T5/T7 will fill them in).

  **Must NOT do**:
  - Do not COPY game files or mod files yet.
  - Do not hardcode secrets.
  - Do not set `USER steam` before creating `/data` and copying scripts that need root.

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Dockerfile scaffolding.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with T1, T2, T3)
  - **Blocks**: T5, T7, T8
  - **Blocked By**: None

  **References**:
  - `steamcmd/steamcmd` and `cm2network/steamcmd` Dockerfiles for library lists.
  - 7DTD Linux dedicated server runtime requirements.

  **Acceptance Criteria**:
  - [ ] `Dockerfile` exists and builds a base image without game files.
  - [ ] Base image contains `steam` user (UID 1000).
  - [ ] `ldd` on a hello-world binary shows no missing libs for the installed packages.

  **QA Scenarios**:

  ```
  Scenario: Base image builds
    Tool: Bash
    Preconditions: Dockerfile exists.
    Steps:
      1. docker build --target not-yet-defined-or-just-base -t 7dtd-rebirth:base /home/snorri/gaming/7d2d-server
    Expected Result: Build succeeds (exit 0).
    Failure Indicators: Docker build fails.
    Evidence: .sisyphus/evidence/task-4-base-build.txt

  Scenario: steam user exists
    Tool: Bash
    Preconditions: Base image built.
    Steps:
      1. docker run --rm 7dtd-rebirth:base id steam
    Expected Result: uid=1000(steam) gid=1000(steam).
    Failure Indicators: User missing or wrong UID.
    Evidence: .sisyphus/evidence/task-4-user-check.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-4-base-build.txt`
  - [ ] `task-4-user-check.txt`

  **Commit**: NO (part of final commit group)

- [x] 5. Install SteamCMD and download v2.6 dedicated server into image

  **What to do**:
  - In the `Dockerfile`, install SteamCMD (download Valve's `steamcmd_linux.tar.gz`, extract to `/opt/steamcmd`, symlink `/usr/local/bin/steamcmd`).
  - Add a build step that runs SteamCMD as root to download AppID 294420 with `-beta v2.6` into `/server`:
    ```
    steamcmd \
      +@sSteamCmdForcePlatformType linux \
      +force_install_dir /server \
      +login anonymous \
      +app_update 294420 -beta v2.6 validate \
      +quit
    ```
  - The exact `v2.6 b14` experimental build manifest is no longer publicly exposed by Steam; `v2.6` stable is the closest reproducible, mod-compatible target.
  - After download, remove SteamCMD metadata and ensure `chown -R steam:steam /server` and `chmod -R u+rwX /server` so the runtime user owns the files.
  - Verify the executable `7DaysToDieServer.x86_64` is present and executable.
  - Build an intermediate stage/tag `7dtd-rebirth:stage-server` to verify this layer.

  **Must NOT do**:
  - Do not leave SteamCMD running or re-downloading at runtime.
  - Do not bake SteamCMD login credentials into the image.
  - Do not leave files owned by root if the runtime user is non-root.
  - Do not rely on the local V 3.0.0 server files.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: SteamCMD integration, large download, permission setup.

  **Parallelization**:
  - **Can Run In Parallel**: YES (with T6, T8)
  - **Parallel Group**: Wave 2
  - **Blocks**: T9
  - **Blocked By**: T1, T2, T4

  **References**:
  - SteamCMD documentation: https://developer.valvesoftware.com/wiki/SteamCMD
  - 7DTD dedicated server AppID 294420, `v2.6` beta branch.
  - `.sisyphus/notepads/7dtd-rebirth-container/learnings.md` for branch/depot research.

  **Acceptance Criteria**:
  - [ ] Dockerfile installs SteamCMD and downloads AppID 294420 `-beta v2.6` into `/server`.
  - [ ] Resulting image has `/server/7DaysToDieServer.x86_64`.
  - [ ] Server files are owned by `steam:steam`.

  **QA Scenarios**:

  ```
  Scenario: Server executable present and owned by steam
    Tool: Bash
    Preconditions: Image built after this task.
    Steps:
      1. docker run --rm 7dtd-rebirth:stage-server ls -l /server/7DaysToDieServer.x86_64
    Expected Result: File exists and owner is steam.
    Failure Indicators: File missing or owned by root.
    Evidence: .sisyphus/evidence/task-5-server-copy.txt

  Scenario: ldd shows no missing libs for server binary
    Tool: Bash
    Preconditions: Image built.
    Steps:
      1. docker run --rm 7dtd-rebirth:stage-server ldd /server/7DaysToDieServer.x86_64 | grep 'not found' || true
    Expected Result: Empty output (no missing libraries).
    Failure Indicators: Any "not found" line.
    Evidence: .sisyphus/evidence/task-5-ldd-check.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-5-server-copy.txt`
  - [ ] `task-5-ldd-check.txt`

  **Commit**: NO (part of final commit group)

- [x] 6. Stage and split Rebirth mod folders

  **What to do**:
  - Extract the Rebirth zip to a staging directory (e.g., `/tmp/rebirth-staging/`).
  - Inspect the 52 top-level mod folders and group them into N subdirectories (`mods-group-0`, `mods-group-1`, ...) so that each group's total uncompressed size is under ~4 GB.
  - This grouping lets the Dockerfile use multiple COPY instructions, keeping each layer under Docker Hub's safe 5 GB limit.
  - Record the grouping in a small manifest file (e.g., `mod-groups.txt`) so it can be reproduced.
  - Clean up the staging directory after Dockerfile layers are finalized.

  **Must NOT do**:
  - Do not commit the extracted mod files to git.
  - Do not create a single COPY layer for the entire mod.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: File-size analysis and layer planning.

  **Parallelization**:
  - **Can Run In Parallel**: YES (with T5, T8)
  - **Parallel Group**: Wave 2
  - **Blocks**: T7
  - **Blocked By**: T1, T2

  **References**:
  - `/home/snorri/Downloads/REBIRTH EXPERIMENTAL 2026.07.02 2245 - 7dtd v2.6 b14.zip`
  - Docker Hub image/layer size guidance.

  **Acceptance Criteria**:
  - [ ] Staging directory contains grouped mod folders.
  - [ ] Each group's total size is ≤ 4 GiB.
  - [ ] Every top-level mod folder from the archive appears in exactly one group.

  **QA Scenarios**:

  ```
  Scenario: All mod folders grouped
    Tool: Bash
    Preconditions: Mod extracted to staging.
    Steps:
      1. find /tmp/rebirth-staging -maxdepth 1 -mindepth 1 -type d | wc -l
      2. Verify count equals 52.
    Expected Result: 52 top-level directories.
    Failure Indicators: Count differs from 52.
    Evidence: .sisyphus/evidence/task-6-group-count.txt

  Scenario: Each group under size limit
    Tool: Bash
    Preconditions: Groups created under /tmp/rebirth-groups/.
    Steps:
      1. for d in /tmp/rebirth-groups/*; do du -sh "$d"; done
      2. Verify each is ≤ 4G.
    Expected Result: All groups ≤ 4 GiB.
    Failure Indicators: Any group > 4 GiB.
    Evidence: .sisyphus/evidence/task-6-group-sizes.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-6-group-count.txt`
  - [ ] `task-6-group-sizes.txt`

  **Commit**: NO (manifest only, not mod files)

- [x] 7. Add mod COPY layers to Dockerfile

  **What to do**:
  - In the `Dockerfile`, after the server download, ensure `/server/Mods` exists.
  - Add one `COPY --chown=steam:steam` instruction per mod group created in T6, copying each group into `/server/Mods/`.
  - Use Docker BuildKit additional build context (`--build-context mods=/tmp/rebirth-groups`) so the host staging directory is reachable during build.
  - After all COPYs, ensure `/server/Mods` contains all 52 mod folders directly (not nested under group directories). The v2.6 Steam download also installs a few default mods (e.g., `TFP_*`, `Xample_*`), so the total `/server/Mods` count will be greater than 52.
  - Add a minimal `ModInfo.xml` for any Rebirth folder that ships without one (the archive omits it for `zz_REBIRTH__Core_2_0`) so 7DTD loads its config overrides.
  - Set final ownership and permissions on `/server/Mods`.

  **Must NOT do**:
  - Do not leave group wrapper directories inside `/server/Mods`.
  - Do not exceed 5 GB per layer.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Multi-layer COPY orchestration.

  **Parallelization**:
  - **Can Run In Parallel**: YES (with T5, T8)
  - **Parallel Group**: Wave 2
  - **Blocks**: T9
  - **Blocked By**: T4, T6

  **References**:
  - `mod-groups.txt` from T6.
  - 7DTD modlet structure (each mod has `ModInfo.xml`).

  **Acceptance Criteria**:
  - [ ] Dockerfile has N COPY instructions for mod groups.
  - [ ] Built image has 52 Rebirth mod folders in `/server/Mods` (total count may be higher because the v2.6 server download includes default mods).
  - [ ] Each `/server/Mods/<name>/ModInfo.xml` exists.

  **QA Scenarios**:

  ```
  Scenario: Correct number of mods in image
    Tool: Bash
    Preconditions: Image built after mod COPY.
    Steps:
      1. docker run --rm 7dtd-rebirth:stage-mods ls -1 /server/Mods | wc -l
    Expected Result: >= 52 (52 Rebirth mods plus default server mods installed by Steam).
    Failure Indicators: Count < 52.
    Evidence: .sisyphus/evidence/task-7-mod-count.txt

  Scenario: All mod folders have ModInfo.xml
    Tool: Bash
    Preconditions: Image built.
    Steps:
      1. docker run --rm 7dtd-rebirth:stage-mods bash -c 'for d in /server/Mods/*/; do [ -f "${d}ModInfo.xml" ] || echo "MISSING: $d"; done'
    Expected Result: Empty output.
    Failure Indicators: Any MISSING line.
    Evidence: .sisyphus/evidence/task-7-modinfo-check.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-7-mod-count.txt`
  - [ ] `task-7-modinfo-check.txt`

  **Commit**: NO (part of final commit group)

- [x] 8. Create entrypoint script

  **What to do**:
  - Write `entrypoint.sh` that:
    1. Ensures `/data/saves`, `/data/logs`, `/data/config` exist and are owned by `steam` (fix permissions on first start).
    2. Copies `serverconfig.xml.template` to `/data/config/serverconfig.xml` and substitutes environment variables for placeholders.
    3. Exports `LD_LIBRARY_PATH` to include `/server` and any native plugin directories.
    4. Uses `exec` to replace itself with the 7DTD server binary so signals pass through.
    5. Passes `-configfile=/data/config/serverconfig.xml` and standard flags (`-quit -batchmode -nographics -dedicated`).
  - Make the script executable.
  - Copy it into the Dockerfile and set as `ENTRYPOINT`.

  **Must NOT do**:
  - Do not run the server as root.
  - Do not hardcode real passwords in the script.
  - Do not skip the `exec` — graceful shutdown depends on it.

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Shell scripting and signal handling.

  **Parallelization**:
  - **Can Run In Parallel**: YES (with T5, T6, T7)
  - **Parallel Group**: Wave 2
  - **Blocks**: T9, T11
  - **Blocked By**: T3, T4

  **References**:
  - `serverconfig.xml.template` from T3.
  - `cbrgm/7days-docker` and `OpenSourceLAN/gameservers-docker` startup scripts for `LD_LIBRARY_PATH` and `exec` patterns.

  **Acceptance Criteria**:
  - [ ] `entrypoint.sh` exists and is executable.
  - [ ] Script substitutes env vars into the config template.
  - [ ] Script uses `exec` to launch the server.
  - [ ] Script fixes `/data` ownership before launching.

  **QA Scenarios**:

  ```
  Scenario: Entrypoint generates hydrated config
    Tool: Bash
    Preconditions: entrypoint.sh and serverconfig.xml.template exist.
    Steps:
      1. mkdir -p /tmp/entrypoint-test
      2. SERVER_NAME=TestRebirth SERVER_PASSWORD=secret123 bash /home/snorri/gaming/7d2d-server/entrypoint.sh --dry-run-config > /tmp/entrypoint-test/serverconfig.xml 2>/dev/null || true
      3. grep 'TestRebirth' /tmp/entrypoint-test/serverconfig.xml
      4. grep 'secret123' /tmp/entrypoint-test/serverconfig.xml
    Expected Result: Both substituted values appear in output.
    Failure Indicators: Placeholders not replaced.
    Evidence: .sisyphus/evidence/task-8-config-hydration.txt

  Scenario: Entrypoint uses exec
    Tool: Bash
    Preconditions: entrypoint.sh exists.
    Steps:
      1. grep -E '^\s*exec\s+' /home/snorri/gaming/7d2d-server/entrypoint.sh
    Expected Result: At least one `exec` line found.
    Failure Indicators: No exec line.
    Evidence: .sisyphus/evidence/task-8-exec-check.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-8-config-hydration.txt`
  - [ ] `task-8-exec-check.txt`

  **Commit**: NO (part of final commit group)

- [ ] 9. Build Docker image locally

  **What to do**:
  - Finalize the `Dockerfile` so it combines the runtime base, SteamCMD-downloaded v2.6 server files, mod layers, entrypoint, and `USER steam`.
  - Create `build.sh` helper script that wraps `docker build` with the correct tag and build context.
  - Run `docker build` (either directly or via `build.sh`) to produce the final image tagged `snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245`.
  - Verify no build errors, no missing shared libraries, and all 52 mods present.
  - Inspect image layers to confirm no layer exceeds 5 GB.

  **Must NOT do**:
  - Do not push the image yet (T10 owns that).
  - Do not leave intermediate stage tags if they waste disk.
  - Do not re-download the server at runtime.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Full image build; may take significant time and disk.

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Wave 2)
  - **Parallel Group**: Wave 3
  - **Blocks**: T10, T12
  - **Blocked By**: T5, T7, T8

  **References**:
  - Final `Dockerfile`.
  - `docker build` documentation.

  **Acceptance Criteria**:
  - [ ] `docker build` exits 0.
  - [ ] Final image tagged correctly.
  - [ ] `docker inspect` shows no layer > 5 GB.
  - [ ] `docker run --rm <image> ldd /server/7DaysToDieServer.x86_64` has no missing libs.

  **QA Scenarios**:

  ```
  Scenario: Full image builds successfully
    Tool: Bash
    Preconditions: Dockerfile complete.
    Steps:
      1. docker build -t snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245 /home/snorri/gaming/7d2d-server
    Expected Result: Exit code 0.
    Failure Indicators: Build error or non-zero exit.
    Evidence: .sisyphus/evidence/task-9-build-log.txt

  Scenario: No missing shared libraries
    Tool: Bash
    Preconditions: Image built.
    Steps:
      1. docker run --rm snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245 ldd /server/7DaysToDieServer.x86_64 | grep 'not found' || true
    Expected Result: Empty output.
    Failure Indicators: Any missing library line.
    Evidence: .sisyphus/evidence/task-9-ldd-final.txt

  Scenario: Layer sizes under limit
    Tool: Bash
    Preconditions: Image built.
    Steps:
      1. docker history --format '{{.Size}} {{.CreatedBy}}' snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245
    Expected Result: No layer size exceeds 5 GB.
    Failure Indicators: Any layer > 5 GB.
    Evidence: .sisyphus/evidence/task-9-layer-sizes.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-9-build-log.txt`
  - [ ] `task-9-ldd-final.txt`
  - [ ] `task-9-layer-sizes.txt`

  **Commit**: YES (after build succeeds)
  - Message: `feat: add Dockerfile and build 7dtd-rebirth image`
  - Files: `Dockerfile`, `serverconfig.xml.template`, `entrypoint.sh`, `.dockerignore`, `.env.example`

- [ ] 10. Push image to Docker Hub

  **What to do**:
  - Create `push.sh` helper script that tags and pushes the image to Docker Hub.
  - Ensure `docker login -u snorripall` is still active; re-login if needed.
  - Push the tagged image to Docker Hub (directly or via `push.sh`).
  - Verify the tag appears on https://hub.docker.com/r/snorripall/7dtd-rebirth/tags after push.
  - If the repository does not exist, Docker Hub will create it on first push; ensure it is set to **private** via the web UI afterward.

  **Must NOT do**:
  - Do not push if build verification (T9) failed.
  - Do not make the repository public.

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Registry push and verification.

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on T9)
  - **Parallel Group**: Wave 3
  - **Blocks**: T13
  - **Blocked By**: T9

  **References**:
  - Docker Hub `docker push` documentation.
  - User's Docker Hub account: `https://hub.docker.com/u/snorripall`

  **Acceptance Criteria**:
  - [ ] `docker push` exits 0.
  - [ ] Tag is visible on Docker Hub web UI.
  - [ ] Repository visibility is private.

  **QA Scenarios**:

  ```
  Scenario: Image pushes to Docker Hub
    Tool: Bash
    Preconditions: Image built and docker login active.
    Steps:
      1. docker push snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245
    Expected Result: Exit code 0; output shows pushed layers.
    Failure Indicators: Push fails, timeout, or auth error.
    Evidence: .sisyphus/evidence/task-10-push-log.txt

  Scenario: Tag visible on Docker Hub
    Tool: Bash (or webfetch)
    Preconditions: Push succeeded.
    Steps:
      1. curl -sf https://hub.docker.com/v2/repositories/snorripall/7dtd-rebirth/tags/7dtd-2.6-b14-rebirth-20260702-2245/ | head -c 200
    Expected Result: HTTP 200 and JSON containing the tag name.
    Failure Indicators: 404 or tag not found.
    Evidence: .sisyphus/evidence/task-10-tag-visible.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-10-push-log.txt`
  - [ ] `task-10-tag-visible.txt`

  **Commit**: NO (registry operation)

- [ ] 11. Create docker-compose.yml

  **What to do**:
  - Write `docker-compose.yml` that:
    - Uses image `snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245`.
    - Defines service name `7dtd-rebirth`.
    - Maps required ports with correct protocols:
      - `26900-26903:26900-26903/udp`
      - `26900-26903:26900-26903/tcp`
      - Optionally `8080:8080/tcp` and `8081:8081/tcp` (commented out by default).
    - Mounts named volumes:
      - `7dtd-saves:/data/saves`
      - `7dtd-logs:/data/logs`
      - `7dtd-config:/data/config`
    - Sets `restart: unless-stopped`.
    - Sets environment variables from `.env` for config hydration.
    - Uses a `deploy.resources.limits` memory reservation (e.g., 16G soft, 24G hard) if desired.
  - Define named volumes at the bottom of the file.

  **Must NOT do**:
  - Do not put real passwords in `docker-compose.yml`.
  - Do not bind-mount host paths instead of named volumes.

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Compose file authoring.

  **Parallelization**:
  - **Can Run In Parallel**: YES (with T12)
  - **Parallel Group**: Wave 3
  - **Blocks**: T12, T13
  - **Blocked By**: T3, T8

  **References**:
  - Docker Compose specification.
  - 7DTD port/protocol requirements.

  **Acceptance Criteria**:
  - [ ] `docker-compose.yml` exists.
  - [ ] File uses the correct image and tag.
  - [ ] Named volumes `7dtd-saves`, `7dtd-logs`, `7dtd-config` are declared.
  - [ ] UDP and TCP port ranges are mapped.

  **QA Scenarios**:

  ```
  Scenario: Compose file validates
    Tool: Bash
    Preconditions: docker-compose.yml exists.
    Steps:
      1. docker compose -f /home/snorri/gaming/7d2d-server/docker-compose.yml config
    Expected Result: Exit code 0; normalized compose config printed.
    Failure Indicators: YAML parse error or validation error.
    Evidence: .sisyphus/evidence/task-11-compose-valid.txt

  Scenario: Named volumes declared
    Tool: Bash
    Preconditions: Compose file exists.
    Steps:
      1. docker compose -f /home/snorri/gaming/7d2d-server/docker-compose.yml config | grep -A2 'volumes:'
      2. grep -E '7dtd-saves|7dtd-logs|7dtd-config' /home/snorri/gaming/7d2d-server/docker-compose.yml
    Expected Result: All three volume names appear.
    Failure Indicators: Any volume missing.
    Evidence: .sisyphus/evidence/task-11-volumes.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-11-compose-valid.txt`
  - [ ] `task-11-volumes.txt`

  **Commit**: YES (with T9 commit group)

- [ ] 12. Local smoke test

  **What to do**:
  - Use the compose file to start the container locally.
  - Wait for the server to initialize (may take 1-3 minutes; world generation may take longer).
  - Check logs for fatal errors, EAC warnings, or mod load failures.
  - Verify UDP port 26900 responds.
  - Stop the container and verify save/log/config data persists in named volumes.

  **Must NOT do**:
  - Do not leave the container running indefinitely.
  - Do not skip log inspection.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Runtime verification of a large game server.

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on T9 and T11)
  - **Parallel Group**: Wave 3
  - **Blocks**: None
  - **Blocked By**: T9, T11

  **References**:
  - `docker-compose.yml` from T11.
  - 7DTD server log messages.

  **Acceptance Criteria**:
  - [ ] `docker compose up -d` starts the container.
  - [ ] Logs show server initialization without fatal errors within 180 seconds.
  - [ ] `nc -u -z -w2 localhost 26900` succeeds.
  - [ ] After `docker compose down`, named volume data remains.

  **QA Scenarios**:

  ```
  Scenario: Server starts without fatal errors
    Tool: Bash
    Preconditions: Image built and compose file ready.
    Steps:
      1. cd /home/snorri/gaming/7d2d-server
      2. docker compose up -d
      3. sleep 180
      4. docker logs 7dtd-rebirth-1 2>&1 | grep -iE 'FATAL|Could not load|EAC' || true
    Expected Result: No fatal/EAC/mod-load error lines.
    Failure Indicators: Fatal error or EAC-related line found.
    Evidence: .sisyphus/evidence/task-12-smoke-log.txt

  Scenario: Game port responds
    Tool: Bash
    Preconditions: Container running.
    Steps:
      1. nc -u -z -w2 localhost 26900 && echo "OPEN"
    Expected Result: "OPEN" printed.
    Failure Indicators: nc times out or fails.
    Evidence: .sisyphus/evidence/task-12-port-check.txt

  Scenario: Persistence across restart
    Tool: Bash
    Preconditions: Container ran and created data.
    Steps:
      1. docker exec 7dtd-rebirth-1 touch /data/saves/persistence-test.marker
      2. docker compose down
      3. docker compose up -d
      4. docker exec 7dtd-rebirth-1 ls /data/saves/persistence-test.marker
    Expected Result: Marker file exists after restart.
    Failure Indicators: Marker missing.
    Evidence: .sisyphus/evidence/task-12-persistence.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-12-smoke-log.txt`
  - [ ] `task-12-port-check.txt`
  - [ ] `task-12-persistence.txt`

  **Commit**: NO (runtime test)

- [ ] 13. Prepare Coolify Compose resource

  **What to do**:
  - Write a concise `COOLIFY.md` note explaining how to deploy the Compose stack in Coolify.
  - Steps to include:
    1. In Coolify, create a new Resource → Docker Compose.
    2. Point it to the Git repository containing `docker-compose.yml` (or paste the compose content).
    3. Configure environment variables from `.env.example` in Coolify's UI.
    4. Add a private Docker Hub registry in Coolify (Settings → Private Registries) so it can pull `snorripall/7dtd-rebirth`.
    5. Set healthcheck or disable Coolify's default HTTP healthcheck (game UDP ports won't pass HTTP checks).
    6. Deploy.
  - Include the exact image tag and a reminder to keep the repo private.

  **Must NOT do**:
  - Do not install or configure Coolify itself (out of scope).
  - Do not commit Docker Hub credentials.

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Documentation and deployment notes.

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on T10, T11)
  - **Parallel Group**: Wave 4
  - **Blocks**: T15
  - **Blocked By**: T10, T11

  **References**:
  - Coolify Docker Compose resource docs.
  - `docker-compose.yml` from T11.

  **Acceptance Criteria**:
  - [ ] `COOLIFY.md` exists with step-by-step deployment instructions.
  - [ ] Instructions mention private registry auth.
  - [ ] Instructions mention disabling/setting appropriate healthchecks.

  **QA Scenarios**:

  ```
  Scenario: Coolify doc covers key points
    Tool: Bash
    Preconditions: COOLIFY.md written.
    Steps:
      1. grep -iE 'registry|healthcheck|env|compose|private' /home/snorri/gaming/7d2d-server/COOLIFY.md | wc -l
    Expected Result: Count >= 4 (each keyword present).
    Failure Indicators: Missing key deployment concepts.
    Evidence: .sisyphus/evidence/task-13-coolify-doc.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-13-coolify-doc.txt`

  **Commit**: YES (with final docs group)

- [ ] 14. Configure Hetzner firewall

  **What to do**:
  - Document the required firewall rules in `COOLIFY.md` or a separate `FIREWALL.md`.
  - Required ports:
    - UDP 26900-26903 (game server)
    - TCP 26900-26903 (Steam query/server browser)
    - TCP 8080 (web dashboard, optional, only if enabled)
    - TCP 8081 (telnet, optional, only if enabled and restricted by source IP)
  - Note that SSH/HTTP/HTTPS for Coolify are separate and already assumed open.
  - Provide Hetzner Cloud Console steps or `hcloud` CLI example.

  **Must NOT do**:
  - Do not open telnet/web dashboard to the public without IP restriction.
  - Do not modify actual Hetzner firewall rules (this is documentation/planning only).

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Firewall documentation.

  **Parallelization**:
  - **Can Run In Parallel**: YES (with T13)
  - **Parallel Group**: Wave 4
  - **Blocks**: T15
  - **Blocked By**: T13

  **References**:
  - Hetzner Cloud firewall documentation.
  - 7DTD dedicated server port requirements.

  **Acceptance Criteria**:
  - [ ] Firewall rules documented.
  - [ ] UDP and TCP port ranges explicitly listed.
  - [ ] Optional dashboard/telnet ports flagged as restricted.

  **QA Scenarios**:

  ```
  Scenario: Firewall doc lists required ports
    Tool: Bash
    Preconditions: Firewall doc exists.
    Steps:
      1. grep -E '2690[0-3]' /home/snorri/gaming/7d2d-server/COOLIFY.md /home/snorri/gaming/7d2d-server/FIREWALL.md 2>/dev/null
    Expected Result: UDP and TCP rules for 26900-26903 visible.
    Failure Indicators: Ports missing or wrong protocol.
    Evidence: .sisyphus/evidence/task-14-firewall-ports.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-14-firewall-ports.txt`

  **Commit**: YES (with final docs group)

- [ ] 15. Deploy and verify on Coolify

  **What to do**:
  - On the Hetzner/Coolify host, pull the image: `docker pull snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245`.
  - Deploy the Compose stack via Coolify.
  - Verify the container is running with `docker ps`.
  - Check that the game port responds from a remote machine: `nc -u <hetzner-ip> 26900`.
  - Verify save/config/log volumes are populated.
  - Capture evidence on the remote host.

  **Must NOT do**:
  - Do not expose the server publicly before the firewall is configured.
  - Do not skip remote port verification.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Remote deployment verification.

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on T13, T14)
  - **Parallel Group**: Wave 4
  - **Blocks**: None
  - **Blocked By**: T13, T14

  **References**:
  - `COOLIFY.md` from T13.
  - `docker-compose.yml` from T11.

  **Acceptance Criteria**:
  - [ ] Image pulls successfully on Hetzner host.
  - [ ] Coolify deploys the container as healthy/running.
  - [ ] Remote UDP port check to Hetzner IP succeeds.
  - [ ] Named volumes contain save/log/config files.

  **QA Scenarios**:

  ```
  Scenario: Image pullable from Hetzner
    Tool: Bash
    Preconditions: Docker Hub auth configured on Hetzner host.
    Steps:
      1. ssh user@hetzner-ip 'docker pull snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245'
    Expected Result: Exit code 0.
    Failure Indicators: Auth error, timeout, or image not found.
    Evidence: .sisyphus/evidence/task-15-remote-pull.txt

  Scenario: Container running on Coolify
    Tool: Bash
    Preconditions: Deployed via Coolify.
    Steps:
      1. ssh user@hetzner-ip 'docker ps --filter ancestor=snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245 --format "{{.Names}} {{.Status}}"'
    Expected Result: Output shows a container name and status "Up".
    Failure Indicators: No container or status not Up.
    Evidence: .sisyphus/evidence/task-15-container-up.txt

  Scenario: Remote game port responds
    Tool: Bash
    Preconditions: Hetzner firewall open and server running.
    Steps:
      1. nc -u -z -w5 <hetzner-ip> 26900 && echo "OPEN"
    Expected Result: "OPEN" printed.
    Failure Indicators: nc timeout/failure.
    Evidence: .sisyphus/evidence/task-15-remote-port.txt
  ```

  **Evidence to Capture**:
  - [ ] `task-15-remote-pull.txt`
  - [ ] `task-15-container-up.txt`
  - [ ] `task-15-remote-port.txt`

  **Commit**: NO (deployment operation)

---

## Final Verification Wave

> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, curl endpoint, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in `.sisyphus/evidence/`. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Review all created files for: hardcoded secrets, missing shebangs, unsafe quoting (paths with spaces), `chmod +x` on scripts, and obvious anti-patterns. Verify `.dockerignore` excludes local saves/logs and the mod archive itself.
  Output: `Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start from clean state. Execute EVERY QA scenario from EVERY task — follow exact steps, capture evidence. Test cross-task integration (image pull → compose up → port check → persistence). Save to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff/files. Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT do" compliance. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- Commit the project files as one logical unit after Wave 3 succeeds locally.
- Suggested message: `feat: containerize 7dtd dedicated server with rebirth mod`
- Files to commit: `Dockerfile`, `docker-compose.yml`, `serverconfig.xml.template`, `entrypoint.sh`, `build.sh`, `push.sh`, `.dockerignore`, `.env.example`.
- Do NOT commit secrets, save files, logs, or the mod archive.

---

## Success Criteria

### Verification Commands
```bash
# Image exists and has no missing libraries
docker run --rm snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245 ldd ./7DaysToDieServer.x86_64 | grep 'not found' | wc -l
# Expected: 0

# Mods are present
docker run --rm snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245 ls -1 /server/Mods | wc -l
# Expected: 52

# EAC is disabled
docker run --rm snorripall/7dtd-rebirth:7dtd-2.6-b14-rebirth-20260702-2245 grep -i 'EACEnabled' /server/serverconfig.xml
# Expected: value="false"

# Server ports respond after local smoke test
nc -u -z -w2 localhost 26900
# Expected: exit 0
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] Image pushed to Docker Hub and pullable from Hetzner
- [ ] Coolify Compose stack deploys and stays healthy
- [ ] Save data persists across redeploy
- [ ] All evidence files captured in `.sisyphus/evidence/`
