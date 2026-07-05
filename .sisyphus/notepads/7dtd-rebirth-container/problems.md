# Problems: 7dtd-rebirth-container

## Blockers

### RESOLVED: Game/mod version mismatch
- **Discovered in**: T1 (Verify game/mod version compatibility)
- **Evidence**: `.sisyphus/evidence/task-1-version-check.txt`
- **Installed server**: `7 Days to Die Dedicated Server` V 3.0.0 (b259), buildid 23906567
- **Mod target**: Rebirth archive `REBIRTH EXPERIMENTAL 2026.07.02 2245 - 7dtd v2.6 b14.zip` requires 7DTD v2.6 b14
- **Resolution**: Modified plan to download the game via SteamCMD at build time using `-beta v2.6` (AppID 294420). The exact v2.6 b14 experimental manifest is no longer publicly exposed by Steam; the `v2.6` stable branch is the closest reproducible, mod-compatible target.
- **Status**: Unblocked. Proceeding with T5/T6/T7/T8 implementation.
