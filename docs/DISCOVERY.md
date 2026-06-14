# Discovery Protocol — Slice 1

Read-only UDS instrumentation for choosing the **Implementation Lever** (see [CONTEXT.md](../CONTEXT.md)).

## Setup

```bash
./install.sh
```

Confirm `G1R_IndoorNight : 1` in `ue4ss/Mods/mods.txt`. Launch G1R; watch the UE4SS console for load banner.

`Scripts/main.lua` defaults: `DISCOVERY_MODE = true`, `SNAPSHOT_KEY = Key.F8`.

## Three poses

| Pose | Location | Game Clock | Expected occlusion |
|------|----------|------------|--------------------|
| **1** | Outdoor, open sky (e.g. near Old Camp gate) | Daytime (~10:00–14:00) | ~0 |
| **2** | Deep indoor (e.g. Old Mine tunnel) | Same daytime | High (~0.7–1.0) |
| **3** | Same spot as pose 2 | Night (~02:00 via sleep/wait) | Same as pose 2 |

**Pose 3 procedure:** Use in-game bed, fire, or wait — no console time cheat. Return to the pose-2 spot, then press **F8**.

## Capture

Press **F8** at each pose. Copy the full `DISCOVERY SNAPSHOT` block from the UE4SS console into the tables below.

## Pose 1 — outdoor daytime baseline

**Location notes:**

```
(paste location)
```

**Console snapshot:**

```
(paste F8 output)
```

**Resolved identifiers:**

| Field | Value | Property name |
|-------|-------|---------------|
| UDS class | | |
| Player Occlusion | | |
| Time of Day | | |

---

## Pose 2 — deep indoor daytime (problem state)

**Location notes:**

```
(paste location — e.g. Old Mine depth)
```

**Console snapshot:**

```
(paste F8 output)
```

**Resolved identifiers:**

| Field | Value | Property name |
|-------|-------|---------------|
| UDS class | | |
| Player Occlusion | | |
| Time of Day | | |

---

## Pose 3 — same indoor spot at ~02:00 (reference state)

**Location notes:**

```
(same as pose 2; clock ~02:00)
```

**Console snapshot:**

```
(paste F8 output)
```

**Resolved identifiers:**

| Field | Value | Property name |
|-------|-------|---------------|
| UDS class | | |
| Player Occlusion | | |
| Time of Day | | |

---

## Lever selection

Compare pose 2 vs pose 3. Properties that change between day-indoors and night-indoors are lever candidates.

Priority (from CONTEXT.md):

1. Skylight / ambient intensity channel
2. Occlusion-native Interior Adjustments field
3. Night Time of Day as proxy
4. Reject if read-only or fights per-frame game sync

**Chosen lever:**

| Property | Pose 2 value | Pose 3 value | Notes |
|----------|--------------|--------------|-------|
| | | | |

**Blend target at full occlusion:** pose-3 value for the chosen property.

## Failure modes

- **UDS actor NOT FOUND** — add class name from ActorDumperMod / Live Property Viewer to `UDS_CLASS_NAMES` in `main.lua`.
- **Player Occlusion UNRESOLVED** — expand `OCCLUSION_CANDIDATES`; note exact name here:
- **No skylight/interior candidates resolve** — enable `ActorDumperMod` temporarily and dump the UDS actor; add property names to candidate lists.

## After discovery

Set `DISCOVERY_MODE = false` in `main.lua` before implementing the write path (Slice 2+).
