# Optimization

Always optimize based on profiling — instrument first (see `timing.md`),
optimize second. Do not prematurely rewrite major systems in assembly;
determine which subsystem is actually expensive before touching it.

## Measure work-vs-budget ratio before optimizing anything

Before reaching for any bottleneck below, measure real per-frame work
against the frame budget the KPI implies (e.g. 66.67ms at 15fps) and
determine which regime you're in:

- **Compute-bound** (work is close to or over budget): a genuine
  performance problem. The bottleneck list and strategies below apply.
- **Slack** (real work is comfortably under budget, e.g. dossage/Passage's
  ~42.5ms of work against a 66.67ms budget): **a pacing problem, not a
  performance problem.** No amount of further render/audio optimization
  moves the number — see `docs/timing.md`'s pacer-pattern and
  `SDL_Delay()`-overshoot material instead.

Getting this wrong costs real time: an earlier campaign on the same port
was legitimately render-bound, and that framing persisted into a later
investigation where the game had already become slack-bound — hours were
spent reasoning about render cost against a problem that had already
changed character. Re-measure the ratio at the start of *every* new
optimization pass, don't assume last time's regime still holds.

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

## Setting a performance KPI

Write a KPI down *before* chasing it, in a form that can't be satisfied by
a metric that's technically true but practically misleading — a real
campaign on this hub nearly shipped exactly that failure mode more than
once (see `docs/timing.md`'s self-lying-metric entry). A well-formed DOS
port performance KPI:

- **Is real-hardware only.** DOSBox-X/86Box are correctness instruments,
  never a performance proxy — see `docs/testing.md`.
- **Is percentile-based, not a single average.** Require both a central
  figure (`fps_p50`) and a worst-case figure (`fps_p95` or an explicit
  "no single window below X" floor) via `shared/include/runmanifest.h`'s
  fields. An average alone can pass while hiding a real excursion —
  exactly what happened when a debt-repayment fix improved the average
  while momentarily running the game visibly too fast right after a
  stall. "Solid," not just "clears the average," is the actual bar a
  release needs to meet.
- **Is falsifiable, decided in advance.** Write down what result means
  fail, not just what result means pass, before the first real-hardware
  run — same discipline `dos-hardware-validation`'s ABBA methodology
  already requires for an A/B comparison; a KPI is a comparison against a
  fixed target, not a different kind of claim.
- **Is attributed to a specific validated build.** Cite `build_sha12` (or
  equivalent), not "the code we currently have" — a KPI result that can't
  be reproduced against a named commit isn't a result, it's a claim.
- **Has an independent witness available**, not just the engine's own
  self-report — see `docs/timing.md`'s self-lying-metric entry for why a
  metric computed from a clock the change under test can perturb will
  tend to fail in the flattering direction, not an obviously wrong one.

## Rule

Do not make a performance claim without a measurement, and prefer a
real-hardware measurement over an emulator one for anything you intend to
publish in `gallery/` or `COMPATIBILITY.md` — see `docs/hardware-testing.md`.
