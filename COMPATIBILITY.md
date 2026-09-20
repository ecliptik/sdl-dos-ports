# Compatibility matrix

This is the richer, human-maintained companion to the summary table in
[`README.md`](README.md) and the machine-readable [`ports.yaml`](ports.yaml).
Update it as ports progress past `BACKLOG`.

| Project | Boots | Playable | 486DX2-66 | Pentium 75 | Notes |
|---|---|---|---|---|---|
| doskutsu | yes | yes | yes (~25 FPS) | yes (headroom) | reference port; see `gallery/doskutsu/` |
| Adventure Game Studio (dosags) | yes | yes (AGS Quest harness slice: rooms, inventory, dialogue, GUI, save/load, animation — identical pixels on DOSBox-X and real hardware) | **8-bit: yes — 40.00 fps / 40.04 ticks/s, replicated 5/5.** 16-bit: 38.0 fps as authored | — (not measured) | `dos_status: PLAYABLE` (2026-09-11). Game porting framework and a six-game compatibility sweep claimed (boots + title pass on all six; play-through not automated for closed-binary games). **Real 486DX2-66 + ATI Mach64 numbers, 2026-09-20 — read each with its boundary, they are not interchangeable.** (1) **Gate 1 CLAIMED, operator sign-off**: Trilby's Notes (8-bit, unmodified) `fps_p50` 40.00, `tick_rate_steady` 40.04, whole-run 39.54 against a 39.2 bar, replicated 5/5 with 0.12 spread — from 5.02 fps at campaign open. (2) **Gate 2 OPEN**: BENCH8 Mode 13h `fps_p50` 40.00 and steady 40.11 both pass; whole-run 39.05 fails 39.2 by 0.15, pending two stall fixes. (3) **Gate 3 CLOSED ON EVIDENCE, not met**: AGS Quest (640x360 16-bit) reaches **38.0 as authored** — bounded by content volume, not port efficiency, because the game draws a 460x260 masked GUI over a moving scene; removing it is sufficient and unavailable, clipping it is available and insufficient. (4) **Port capability at 16-bit, measured on a MODIFIED fixture (that GUI hidden): 40.61 fps, 4 cells, spread 0.17, mechanism confirmed on each.** This is a fact about the port's rendering path, **not** a Gate 3 pass and **not** a claim that 16-bit games run at 40 — the one tested does not. Mach64 only; ViRGE and Cirrus untested, and per `docs/video.md` a presentation result is a fact about one card + BIOS + VBE provider. Quote figures on this fixture as `tick_rate_steady x (1 - frames_skipped/ticks)`, never `fps_p50`, which carries ±1.2 on a run containing multi-second blocking operations. Active work: dosags `PLAN.md`, "40/40 plan". |
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
