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

**A loop-only reading can say "slack" while nearly half the frame is
being eaten by work the loop never sees.** The spans a main loop
instruments itself -- render, blit, present, tail -- exclude whatever
this backend's cooperatively scheduled audio pump does *inside the
pacer's own `SDL_Delay` sleep*. That cost stays invisible right up until
it grows large enough to consume the sleep entirely, at which point it
spills into frame time all at once instead of showing up gradually in
the loop's own numbers. dossage/Passage hit exactly this on the 486DX2-50
tier (`docs/BENCHMARK-PLAN.md` there, "Methodology lesson from this
gate's failure mode", 2026-09-04): audio conversion was taking ~43% of
every frame while the loop-only spans still read healthy, and after that
was fixed a much smaller version of the same blind spot (the
silence-detect throttle, see `docs/audio.md`) still cost 0.08-0.18 fps
against the KPI line. So the compute-bound gate above has to be re-run
per CPU tier and per audio configuration with the cooperative background
work counted: either a diagnostic build that instruments the sleep/yield
span directly, or an A/B pair across whatever toggle changes that
background work's volume. A clean "slack" reading from loop spans alone
is necessary, not sufficient.

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
**Caveat found later (dosags, 2026-09-17): that per-rect loop exists only
on the backend's banked path and its `SDL_HINT_DOS_ALLOW_DIRECT_FRAMEBUFFER=1`
path. The normal LFB path ignores the rect list and copies the whole
surface** -- check which path your mode-set log says you are on
(`use_lfb`, `banked`, `hint_direct_fb`) before spending effort on dirty
rectangles. See `video.md`, "No low-res mode on the card".

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

**486DX2-66 + S3 ViRGE/Cirrus result, campaign closed.** dossage/Passage's
real-hardware fps campaign closed at **14.936/14.932fps** (measured twice
independently), up from 13.992fps at the campaign's start -- reported
honestly short of the 15.000fps target rather than tuned to cross it. Run
`/sdldos:benchmark` for the campaign checklist this result came from (delay(1) granularity,
`DOS_Yield()` cost, clock-rate mismatch, and audio-refill were each tested
and eliminated in turn; the real mechanism was the frame limiter's own
deadline-vs-actual error, fixed to land within microseconds; the residual
gap to 15.000 is audio-buffer-refill-driven stalls, root cause not yet
identified as of this writing).

**You cannot compensate your way past stalls by tightening the pacer's
target -- stalls are the binding constraint, and squeezing the budget
manufactures more of them.** The last experiment in that campaign
shortened the pacer's deadline by the measured mean overshoot (0.293ms/
frame), on the sound argument that targeting exactly `1/lockedFrameRate`
makes 15.000 unreachable by construction (a stalled frame is a permanent,
unrecoverable loss). **The mechanism worked exactly as predicted** --
steady-state rose from 14.9989fps to **15.089fps**, above target, pacer
still landing within 0.03ms of its (tightened) deadline. **The run
average moved 14.936 -> 14.942fps. Nothing.** Tightening the deadline
also converts more ordinary frames into missed/stalled frames, and every
stall is a pure, unrecoverable loss -- measured stall cost more than
doubled (0.279 -> 0.654ms/frame), consuming exactly what the tightening
bought. Reverted; the reverted binary is byte-identical to the
already-validated build, and the knob is documented in-code so it isn't
re-derived. **The general lesson: don't fight a stall-dominated residual
by squeezing the steady-state target tighter** -- find and fix the stalls,
or accept the average; a tighter target only trades steady-state
performance for more frequent losses of the same total size.

**A change whose mechanism verifiably works can still be worthless --
measure the thing you actually care about, not the thing the change was
designed to move.** The tightened-deadline experiment above is a clean
case study: the metric the change directly targeted (steady-state fps)
moved beautifully and exactly as predicted; the metric that actually
mattered (run-average fps, the KPI) didn't move at all. Reporting
"steady-state now exceeds 15fps" alone would have been true, verifiable,
and measured on real hardware -- and would have been a materially
misleading way to close out a campaign whose actual goal was a 15fps
run average. Before crediting an optimization, confirm it moved the KPI
itself, not just the intermediate quantity it was designed to influence.

**Skip the present entirely when the frame is unchanged -- a cheap
stand-in for dirty rectangles on a mostly-static game.** dosags (AGS,
Trilby's Notes, HW-486-66) cached the last-presented frame and skipped
the blit + `SDL_UpdateWindowSurface()` when the new one was
byte-identical (palette, offset and flip state checked too). On an idle
adventure-game screen **95.9% of presents were skipped**; pre-registered
ABBA: fps_p50 8.57 -> 21.05. It is not a substitute for real dirty
rectangles -- the moment anything moves, every frame pays the full
present again -- but it is a few dozen lines and needs no engine
knowledge. (dosags patches 0091/0092.)

**DJGPP libc's `memcmp()` and tiny `memcpy()` calls are slow enough to
decide a frame budget.** Disassembling the toolchain's `libc.a` showed
`memcmp` is a byte-at-a-time loop (no `REP CMPSB`, no word widening).
Replacing a 64 KB frame compare with a 32-bit word compare (exact, not a
hash -- a `Uint32` is equal iff its four bytes are) took fps_p50 22.01 ->
34.62 in a pre-registered ABBA, 4x the predicted effect, because on a
fixed-timestep engine saved time also removes catch-up ticks. The same
port's first "fast blit" showed ZERO real-hardware gain until a
per-replicated-byte `memcpy()` (~153,600 one-byte calls per frame) was
replaced with direct stores. Verify a hot inner loop compiled to what you
think it did before crediting or blaming the algorithm.

**Label every fps number with how many presents were real.** After the
skip-unchanged change, dosags's headline `fps_p50=34.62` counted render
passes on a static screen: 23 of 881 frames actually reached the card,
and a real present still cost ~76 ms (~13 fps if everything changed).
Both statements are true; only one describes gameplay. Emit
`presents_real`/`presents_skipped` beside fps, and never quote a
static-screen figure as a gameplay figure. The same applies to a
whole-run tick rate that silently averages in one-time stalls: report a
steady-state figure AND list the stalls.

**A build fingerprint derived from the COMMITTED tree cannot see an
uncommitted working-tree change -- so an A/B pair built that way can
stamp identical identities and silently pass its own invalidity check.**
dosags derives `binary_sha12` from `git rev-parse HEAD^{tree}` over its
vendored trees plus the build flags (its `Makefile`). A worker built the
A arm by reverse-applying a patch to the working tree: it compiled the
older code but stamped the NEWER commit's identity, and both ABBA arms
came back with the same fingerprint. "binary_sha12 must differ between
arms" is one of this hub's standard invalidity conditions, and it would
have passed. **Build each arm from a genuine checkout of its own commit,
not by patching the working tree**, and treat two arms sharing a
fingerprint as a build error rather than as the check being satisfied.
The same gap applies to any fingerprint built from committed state --
git describe, a tag, a submodule SHA.

**Stage every config input explicitly; ambient state left on the target
is a silent confound.** The same campaign voided a cell because the
machine still carried an `ACSETUP.CFG` from an earlier zero-patch
experiment, so the A arm ran with the treatment already applied -- two
samples of the same state, the failure mode two entries below. It was
caught only because the A arm's number resembled the B arm's prediction.
A benchmark cell should write the config it depends on rather than
inheriting whatever the previous run left behind.

**A once-per-run summary metric cannot show that a per-event cost
recurs -- and will make a recurring cost look like a one-off.** dosags
bracketed a 1351 ms room-load phase, but the bracket was reported in a
startup summary emitted once, at first-room-ready. A run that paid the
cost twice (a save-restore re-enters the same room-load path) reported
exactly the same single figure as a run that paid it once, so the
bracket built to find that cost would have hidden its most important
property. Fixed by emitting one line per occurrence, with a sequence
number and a cheap identity (here a palette hash) so repeats are
visible and attributable. **If a cost can happen more than once per
run, count the occurrences -- a total or a first-occurrence figure is
not enough**, and check where your report is emitted from before
trusting what it does not show.

**Instrumentation bugs that hid real signal in one campaign, worth
checking in any per-phase timer:** (1) truncating each sample to whole
milliseconds *before* summing -- nine phases reported exactly 0 ms
across 10,000+ calls; sum in the clock's native units and convert once.
(2) a whole-function bracket on a function with call sites outside the
path being measured summed to MORE than its parent -- an impossible
subset is a free tell; bracket the call site, not the callee. (3) totals
for a phase that can re-enter itself (a blocking script wait that runs
nested game ticks) double-count; measure self-time, or the arithmetic
built on those totals is wrong. (4) the measured cost of the timing
mechanism itself was 11 us per bracket -- cheap enough, but measure it
once rather than assume. (5) changing a recorder's unit without updating
every call site: the fix for (1) moved the recorder to microseconds, two
hand-rolled call sites kept passing milliseconds, and for a day the
script VM read 1000x too cheap -- which sent the investigation hunting
"zero-work wrapper overhead" that was really script time. The tell was
in the data the whole time: a parent phase with max 2605 ms wrapping a
child that claimed max 2 ms. Put the unit in the parameter AND the local
variable names, and sanity-check child-vs-parent maxima after any change
to the timing code itself.

**Pick the iteration vehicle for speed, the validation vehicle for
truth.** dosags spent most of a day on 20-70 minute real-hardware cells
because its only 32-bit content was a 72 MB game. Forcing a small,
fully scripted game onto the same code path with an existing
depth-override lever reproduced the same relative behaviour in 4-8
minute cells. Develop against the fastest fixture that exercises the
code path; return to the heavy one only to confirm.

See also `video.md` ("No low-res mode on the card") for the largest
structural lever found so far -- presenting unscaled instead of
scale-to-fill -- and `timing.md` for the 1.3 ms clock read.

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
