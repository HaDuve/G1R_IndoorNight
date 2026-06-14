# Object dump — find Player Occlusion float

One-time setup to resolve the nested occlusion struct blocking Slice 2.

## Prepared for you

- `Keybinds : 1` in `ue4ss/Mods/mods.txt` (Ctrl+J object dump)
- `LoadAllAssetsBeforeDumpingObjects = 0` (leave off — safer)
- `G1R_IndoorNight : 1` stays on (F8 snapshots still work)

**Dump output path (Mac):**

```
../Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Gothic 1 Remake/G1R/Binaries/Win64/ue4ss/UE4SS_ObjectDump.txt
```

## In-game steps

1. **Relaunch G1R** (pick up Keybinds enable)
2. **Load a save** and stand **outdoors** in daylight (Pose 1-ish spot)
3. Wait until fully in-world (not menu)
4. Press **Ctrl+J** once
5. **Wait 30–90 seconds** — file can be hundreds of MB; game may hitch
6. **Do not** dump again unless needed

Optional second pass (helps find live float):

7. Go **deep indoor** (Old Mine / same as Pose 2)
8. Press **Ctrl+J** again (overwrites dump — note time/location)
9. Or skip step 7 and send first dump; we search struct layout

## After dump (Mac terminal)

```bash
cd "/Users/hiono/Library/Application Support/CrossOver/G1R_IndoorNight"
ls -lh "../Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Gothic 1 Remake/G1R/Binaries/Win64/ue4ss/UE4SS_ObjectDump.txt"
./tools/extract-occlusion-from-dump.sh
```

Then tell the agent: **"parse occlusion dump"**

## Disable when done

In `mods.txt` set `Keybinds : 0` again (optional; reduces extra mod load).

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Ctrl+J does nothing | Confirm `Keybinds : 1`; check `UE4SS.log` for Keybinds load |
| No file after Ctrl+J | Wait longer; check same folder as `UE4SS.log` |
| Game crashes after dump | Normal if `LoadAllAssetsBeforeDumpingObjects` was on — keep it **off** |
| File too huge | Expected; use `extract-occlusion-from-dump.sh` instead of opening whole file |
