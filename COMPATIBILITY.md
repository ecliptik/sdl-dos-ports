# Compatibility matrix

This is the richer, human-maintained companion to the summary table in
[`README.md`](README.md) and the machine-readable [`ports.yaml`](ports.yaml).
Update it as ports progress past `BACKLOG`.

| Project | Boots | Playable | 486DX2-66 | Pentium 75 | Notes |
|---|---|---|---|---|---|
| doskutsu | yes | yes | yes (~25 FPS) | yes (headroom) | reference port; see `gallery/doskutsu/` |
| Adventure Game Studio (dosags) | yes | yes (AGS Quest harness slice: rooms, inventory, dialogue, GUI, save/load, animation — identical pixels on DOSBox-X and real hardware) | **8-bit 320x200: yes — 40.00 fps / 40.01 ticks/s on moving content (BENCH8 anim12 at Mode 13h, 4/4 cells, Gate 2 claimed 2026-09-21).** 8-bit 320x240 idle: 40.00 (Gate 1). 16-bit: 38.0 on the AGS Quest demo (640x360, content-bound); real 320x200 titles unmeasured since 2026-09-16 (5.45 and 2.73 then). 32-bit: correct, unmeasured since 2026-09-15 (0.05 then) | — (not measured) | `dos_status: PLAYABLE` (2026-09-11). Game porting framework and a six-game compatibility sweep claimed (boots + title pass on all six; play-through not automated for closed-binary games). **Real 486DX2-66 + ATI Mach64 figures — Mach64-only, sound off, fixed timestep, each read with its fixture:** (1) **Gate 1 CLAIMED 2026-09-18**: Trilby's Notes (8-bit 320x240) idle title, `fps_p50` 40.00, `tick_rate_steady` 40.04, whole-run 39.54 against 39.2, replicated 5/5. Idle means ~23 real presents per run: an engine-overhead figure, not a rendering one. (2) **Gate 2 CLAIMED 2026-09-21 by operator decision**: BENCH8 anim12 (8-bit 320x200, 12 animating sprites) at Mode 13h, `fps_p50` 40.00, steady 40.01, whole-run 39.41 against 39.2, 99.9% of content frames shown, 4/4 cells with 0.01 spread. The ~210 ms CF-card write stall that held the claim is closed as bounded and mitigated, not named — see `HARDWARE.md`. The same fixture on the default 640x480 2x rung scores 14.99. (3) **AGS Quest (640x360 16-bit): 38.0 as authored**, bound by a 460x260 masked GUI composited over moving content, not by the port; **40.61 with that GUI hidden** (4 cells, spread 0.17) is a fact about the render path, never a pass. The 16-bit gate is re-homed (2026-09-21) on 5 Days a Stranger (320x200) at a centred 1x rung, with the BENCH16 fixture as the A/B instrument; no figure yet. (4) 32-bit: two zero-code cells on the current binary are owed before any statement. Quote a figure as `tick_rate_steady x (1 - frames_skipped/ticks)`; `fps_p50` alone counts render passes, not displayed frames. ViRGE and Cirrus untested and in scope after the fps work. Plan of record: dosags `PLAN.md`; full history: dosags `PLAN-LOG.md`. |
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
