# Optimization

Always optimize based on profiling — instrument first (see `timing.md`),
optimize second. Do not prematurely rewrite major systems in assembly;
determine which subsystem is actually expensive before touching it.

## Likely DOS bottlenecks, roughly in order

1. Full-screen pixel copies.
2. Pixel-format conversion.
3. Alpha blending.
4. Software scaling.
5. Compressed audio decode.
6. Audio mixing.
7. Excessive heap allocations.
8. Floating point.
9. C++ container churn.
10. Filesystem calls.
11. Sprite/collision loops.
12. Cache-unfriendly object layouts.

## High-value strategies

- Native framebuffer resolution (see `video.md`).
- 8/16-bit rendering instead of 32-bit when practical.
- Dirty rectangles, especially for mostly-static-screen games.
- Preconverted graphics and preconverted audio.
- Hardware MIDI instead of software synthesis or decode (see `audio.md`).
- Static lookup tables, fixed-point math.
- Object pooling; avoid per-frame allocation.
- Reduce intermediate SDL surfaces; cache decoded assets.
- Compile-time removal of unused subsystems.

## Confirmed real-hardware findings

**Rect-limit every stage of the pipeline, not just one.** dossage/Passage
found `SDL_BlitSurface(..., NULL, ..., NULL)` and `SDL_UpdateWindowSurface()`
(which builds an implicit full-window rect internally — confirmed by
reading `SDL_video.c`, not assumed) both running full-surface every frame
regardless of how little of a small, centered sub-image actually changed.
These are two separate calls, each needing its own rect argument — dirty-
rectangle work on one does nothing for the other. Limiting *both* to the
same sub-rect (falling back to full-surface only on a frame where
something structural changes, e.g. a resize) cut real-hardware frame time
roughly in half combined — the two largest single wins in that
investigation. The present-side fix needed no shared-backend change: it
relies on `DOSVESA_UpdateWindowFramebuffer`'s existing per-rect VRAM-copy
loop (`SDL_dosframebuffer.c`), reached via `SDL_UpdateWindowSurfaceRects`
instead of `SDL_UpdateWindowSurface` — calling the right existing API, not
new plumbing. Before trusting a "dirty rectangles" optimization is
actually working, verify every stage between your draw calls and the
screen is rect-limited, not just the one you remembered to change first.

**Float/double-to-int conversion costs a real rounding-mode dance on
486-class CPUs, not just the arithmetic — and this is invisible under
DOSBox-X.** dossage/Passage found a hot per-frame function doing three
`(unsigned char)(double)` truncations per call, 2400 calls/frame,
*unconditionally* — even on a cache hit reusing an already-computed
value. Moving the truncation to happen once at cache-population time
instead of once per reuse, and switching the hot per-call path to
fixed-point integer math (scaled-by-256 multiply+shift), cut render-loop
cost ~29% on real 486DX2-50 hardware. **This cost showed zero
DOSBox-X-visible magnitude difference beforehand** — it was invisible in
emulator testing and only surfaced as the dominant remaining cost once
earlier, unrelated fixes cleared everything ahead of it in the profile.
Another concrete instance of "DOSBox-X is a correctness instrument, not a
performance proxy" (`docs/testing.md`). Prefer converting a value to
integer once and caching the integer, not re-truncating a cached
double/float on every reuse — the x87 `fldcw`/`fistp`/`fldcw`
rounding-mode-change dance behind a naive C truncation is real,
measurable cost on this CPU class independent of the arithmetic itself.

**486DX2-66 + S3 ViRGE result, after the video-corruption investigation in
`docs/video.md` closed out.** dossage/Passage now runs at 14.16-14.5fps on
this config, with real audio and zero video corruption (patches 0027-0029).
The residual gap to a 15fps target was bisected and found to be
`SDL_Delay()` timer-precision overshoot, not a rendering bottleneck -- real
per-frame work has plenty of headroom (~45.6ms measured against a 66.7ms
frame budget at 15fps). See `docs/timing.md` for an untested hypothesis on
why `SDL_Delay()` overshoot specifically shows up on this CPU class.

## Rule

Do not make a performance claim without a measurement, and prefer a
real-hardware measurement over an emulator one for anything you intend to
publish in `gallery/` or `COMPATIBILITY.md` — see `docs/hardware-testing.md`.
