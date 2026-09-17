# Compatibility matrix

This is the richer, human-maintained companion to the summary table in
[`README.md`](README.md) and the machine-readable [`ports.yaml`](ports.yaml).
Update it as ports progress past `BACKLOG`.

| Project | Boots | Playable | 486DX2-66 | Pentium 75 | Notes |
|---|---|---|---|---|---|
| doskutsu | yes | yes | yes (~25 FPS) | yes (headroom) | reference port; see `gallery/doskutsu/` |
| Adventure Game Studio (dosags) | yes | yes (AGS Quest harness slice: rooms, inventory, dialogue, GUI, save/load, animation — identical pixels on DOSBox-X and real hardware) | not yet — runs, below the 40Hz/40fps target | — (not measured) | `dos_status: PLAYABLE` (2026-09-11). Game porting framework and a six-game compatibility sweep claimed (boots + title pass on all six; play-through not automated for closed-binary games). Real 486DX2-66 numbers, 2026-09-17: Trilby's Notes (8-bit) 33.8 of 40 logic ticks/s, `fps_p50` 34.6 — a static-screen figure, only 23 of 881 frames were real presents, up from 5.0 through four pre-registered ABBA wins; AGS Quest (640x360 16-bit) ~33 ticks/s steady and ~7 displayed fps. Active work: dosags `PLAN.md`, "40/40 plan". |
| VVVVVV | — | — | — | — | unclaimed |
| Meritous | — | — | — | — | unclaimed |
| OpenJazz | — | — | — | — | unclaimed |
| POWDER | — | — | — | — | unclaimed |
| Kobo Deluxe | — | — | — | — | unclaimed |
| Blob Wars: Metal Blob Solid | — | — | — | — | unclaimed |
| Passage | — | — | — | — | unclaimed |
| SuperTux 0.1.x | — | — | — | — | unclaimed |

Columns:
- **Boots**: executable starts, SDL initializes, reaches a title/menu.
- **Playable**: a representative slice of the actual game is playable
  start-to-finish for that slice (not necessarily the full game — see that
  port's own `dos_status` in `ports.yaml` for the finer-grained ladder).
- **486DX2-66 / Pentium 75**: playable at an acceptable frame rate on that
  reference machine, per `HARDWARE.md`. Only fill in a number backed by a
  real-hardware or vcctrl-captured measurement, not an emulator estimate.

This table intentionally lags `ports.yaml`'s `dos_status` field — a port can
be `RESEARCH` or `COMPILES` in `ports.yaml` well before it has anything
worth a row here.
