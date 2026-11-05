# Compatibility matrix

This is the richer, human-maintained companion to the summary table in
[`README.md`](README.md) and the machine-readable [`ports.yaml`](ports.yaml).
Update it as ports progress past `BACKLOG`.

| Project | Boots | Playable | 486DX2-66 | Pentium 75 | Notes |
|---|---|---|---|---|---|
| doskutsu | yes | yes | yes (~25 FPS) | yes (headroom) | reference port; see `gallery/doskutsu/` |
| Adventure Game Studio (dosags) | yes | yes (AGS Quest harness slice: rooms, inventory, dialogue, GUI, save/load, animation -- identical pixels on DOSBox-X and real hardware) | **yes, sound on, at all three colour depths: the 486 gates (S8/S16/S32P) were MET 2026-09-30, see (1).** Bar cells, whole-run / steady: 8-bit 39.26 / 40.23 and 39.35 / 40.29; 16-bit 39.29 / 40.13 and 39.29 / 40.10; 32-bit 39.28 / 40.12 and 39.34 / 40.07. `fps_p50` 40.00 in every cell. Maniac Mansion Deluxe (16-bit 320x200, character select room 50, instrumented build a30ee9702c2a, 2026-09-26): logic-bound: logic alone takes 24.6 ms of the 25 ms tick, leaving almost nothing to draw in, so the game steps at 36.5 ticks/s (not 40) and displays only one frame in four (750 of 999 ticks skipped, `fps_p50` 8.9-9.8, about 9 frames/s). Each render costs ~15 ms at most (derived from the totals: 28.3 s loop minus 24.6 s logic over 250 renders, not measured directly). This supersedes the 2026-09-22 title-screen reading (6.84, dispatch-bound at 26.5 ms/tick) | -- (not measured) | `dos_status: PLAYABLE` (2026-09-11). Game porting framework and a six-game compatibility sweep claimed (boots + title pass on all six; play-through not automated for closed-binary games). **Real 486DX2-66 + ATI Mach64 figures, sound on, fixed timestep, each read with its fixture.** (1) **PLAN-GATES S8 / S16 / S32P MET 2026-09-30 (dosags fdbaf461).** The bar per depth: two cells with both tick figures (whole-run / steady) within 39.2-40.8, `fps_p50` >= 40, completeness >= 95%, a clean camera witness and clean audio counters (overwrites 0, late 0, silent 0 outside room loads), plus one harness-scored 640x480 capture listen. S8 = Trilby's Notes room 35, 8-bit, 512x384 centred 1x, OPL3 (GL8A/B; listen CAPS8). S16 = 5 Days a Stranger room 3, 16-bit, 512x384 centred 1x, OPL3 (GL16A/B; CAPS16, OPL3 +1 cent). S32P = 5 Days room 3 forced to 32-bit, 640x480 centred 1x, pack24 present, OPL3 (GL32A/B; CAPS32R, +1 cent). A WaveBlaster arm (music-only cells on their own fixtures, depth-score.py) also PASSes at all three depths (WBC8R/16R/32R, ef123dba0adf). **Caveats that travel with it:** n=2; whole-run margins over 39.2 are only 0.06-0.15; the evidence spans four binaries; the bar cells and CAPS8 ran with the ~89-cent-sharp OPL3 F-number table since fixed hub-wide (pitch is not in the bar, and S8's capture scorer has no pitch check, so none is claimed there). (2) **D2 FAILED as registered:** cold-start sound latency 4.30 ms median over 39 cold starts against a 1.0 ms bar (dosags cd217660); it stays failed. (3) Earlier scoped claims, superseded by (1) but kept in dosags `PLAN.md`: Gate 1 (Trilby's Notes 8-bit idle title, 2026-09-18), Gate 2 (8-bit BENCH8 synthetic fixtures at Mode 13h, 2026-09-21) and Gate 3 (5 Days a Stranger 16-bit in play, sound off, 2026-09-22). AGS Quest (16-bit 640x360) closed at 38.0, content-bound by its masked GUI. (4) Since 2026-09-30: a release build flavour (timing instrumentation compiled out) and `make dist` (a player zip checked against the licence records). On the 486 the release flavour carries the S8 gate: round R1 2026-11-05, an ABBA against the instrumented build on the same commit, EQUIVALENT (mean whole-run 39.25 vs 39.24, steady 40.255 vs 40.26); both release cells MET (39.27 / 40.27, 39.23 / 40.24; whole-run margins 0.03-0.07), and its 640x480 capture listen CAPR8 PASSes. Gate cells use the release flavour from R1 on; S16 / S32P on the release exe are next (R2). **Check a `--startr` debug-jump entry against the game's natural route before hunting a present-path bug** (dosags DUPCHAR4). Quote a figure as `tick_rate_steady x (1 - frames_skipped/ticks)`; `fps_p50` alone counts render passes, not displayed frames. ViRGE and Cirrus untested. Plan of record: dosags `PLAN-NEXT.md`; gate record `PLAN.md`; history `PLAN-LOG.md`. |
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
