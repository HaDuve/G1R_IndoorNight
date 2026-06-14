# G1R Indoor Night Mod — Glossary

## Game Clock
The in-world time used by quests, NPC schedules, sleep/wait, and UI (e.g. "Day 3, 14:30"). **Not** modified by this mod.

## Sun / Sky Lighting
The visual day/night presentation driven by the sky system (G1R credits list **Ultra Dynamic Sky**). Controls sun angle, moon, ambient sky light, and related atmosphere — **independent of quest/logic time** for mod purposes.

## Indoor Night Override
While the player is **Inside**, the mod pushes Sun / Sky Lighting toward a **moonlit night** presentation using **occlusion-blended** adjustments — not a global sky flip. At full occlusion the target is UDS time-of-day roughly **22:00–04:00** (dark, some ambient sky fill). Blend strength tracks UDS **Player Occlusion** (same family of signal as `ExtraInteriorExposure`). Blending **starts at ~0.5 occlusion** (mid threshold); below that, sky stays vanilla. Game Clock continues unchanged. Local light sources (torches, fires) stay at **vanilla brightness** unless configured otherwise. **Mod:** `G1R_IndoorNight` (UE4SS Lua). **Toggle:** F7 enables/disables mid-session; **off = instant** restore to true sky. **Default:** enabled on load. **Config:** tunables at top of `main.lua` (`TARGET_TOD`, occlusion thresholds, key, `ENABLED`, debug log).

## Player Occlusion
UDS metric (0–1) for how enclosed the camera is: collision traces + optional occlusion volumes. Drives Interior Adjustments, sound muffling, and G1R's interior exposure boost.

## Inside
Any enclosed playable space where **Player Occlusion** rises — buildings, caves, dungeons, mines. Detected via UDS occlusion traces and volumes, not custom mod logic.

## Extra Interior Exposure
A player graphics setting (`ExtraInteriorExposure` in `GameUserSettings`) that **brightens** indoor scenes for visibility. Shares the occlusion signal family with Player Occlusion but **stacks independently** — the mod does not override it; the player balances both settings manually.
