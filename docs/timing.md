# Timing

Never assume display FPS and simulation/game timing must be identical.
doskutsu demonstrated why this matters: on slow real hardware, render rate
varies a lot (see `HARDWARE.md`'s baseline table), but game logic must
continue at its intended rate regardless.

## Determine, per port

```
simulation tick
animation tick
audio tick
render tick
input polling rate
```

Where possible:

```
simulation = fixed timestep
rendering  = as fast as practical
```

This prevents slow rendering from slowing gameplay — a candidate does not
need to hit 50/60 FPS to be considered playable if its simulation timing is
cleanly separated from its render rate.

## Your clock can lie

DJGPP's `uclock()` — the only timebase behind `SDL_GetTicks`/`SDL_Delay`/
`SDL_GetPerformanceCounter` on this backend — reads PIT channel 0. Any
code that reprograms PIT ch0 for its own purposes (a PIT-driven audio pump
is the confirmed real case — see the "PIT-driven audio pump" hazard in
`docs/audio.md`'s architecture-wide section) can freeze or corrupt this
timebase while active, silently
invalidating any performance measurement taken during that window — this
produced a false ~42% fps-cost finding for a feature that, measured
correctly via flip-counts against wall-clock `time()` instead, cost
nothing. Before trusting a timing measurement that looks surprising,
check whether anything active during that window reprograms a PIT channel
DJGPP's clock depends on.

A related but distinct `uclock()` hazard: it is **not monotonic** on this
platform — real-hardware logs have shown the unsigned-subtraction wraparound
that produces when two `uclock()` reads are subtracted in the wrong order
(a duration coming out near `2^32`, i.e. ~1.8×10^19 in a wider integer
type, instead of the small positive number expected). Clamp any
`uclock()`-derived duration to a sane range before trusting it, and treat
a single wildly-anomalous timing sample as a suspect measurement to
discard, not as a finding to explain.

## SDL_Delay() overshoot on 486-class CPUs (untested hypothesis)

dossage/Passage bisected a residual fps gap on 486DX2-66 + S3 ViRGE (see
`docs/optimization.md`) to `SDL_Delay()` timer-precision overshoot, with
real per-frame render work well under budget (~45.6ms against a 66.7ms
frame budget). **Not confirmed this session:** this may tie back to the
PIT-channel-0 timebase this doc already documents above -- a 486-class
CPU with no `RDTSC` falls back to a coarser PIT-driven wait primitive
behind `SDL_Delay()`, which would explain overshoot scaling with CPU class
rather than being a fixed constant. A comparison run on a Pentium
OverDrive (which does have `RDTSC`) would settle whether this is actually
the mechanism -- treat this as a hypothesis worth testing, not a
documented cause, until that comparison exists.

## First framebuffer flush after SDL_Init can spike 50-70ms on 486-class hardware

**A one-time startup cost, not a per-frame one, but big enough to trip an
unrelated safety cap.** dossage/Passage's `DOS_Yield()` cost instrumentation
(`shared/patches/sdl3-dos/0136`, temporary) found steady-state `DOS_Yield()`
cost cheap (~0.24-0.34ms/call), but a sharp spike in the first ~200 frames
on real 486DX2-66 + Cirrus CL-GD5434 hardware -- up to 71ms and 52.6ms,
16 and 12 spikes over 10ms in those two windows only, nowhere else in a
119-second/1651-frame run. Cross-referenced against `SDLDBG.LOG` from the
same run, this lines up precisely with the very first framebuffer flush
(57.65ms by itself -- the first-ever DPMI mapping, first non-bank-0 write)
and three separate `SDL_DOSAudioPump()` "cap tripped (>32 calls in one
sequence)" warnings (`shared/patches/sdl3-dos/0067`'s runaway-caller safety
cap) firing in that same window, right after `OpenDevice`.

**Generalizable, not dossage-specific**: any port using this backend's
frame-limiter pattern (a `SDL_Delay`/`SDL_SYS_DelayNS` wait loop yielding to
the audio thread) plausibly pays a similar one-time cold-start cost around
its first framebuffer flush, and that cost can be large enough to trip
0067's runaway-caller cap and produce a `DOS_Yield()` burst -- worth
knowing before misreading a startup-only warning burst as a steady-state
performance problem. Plausibly concentrated in a title-screen/pre-frame-
counting phase rather than counted gameplay: dossage logged 1700 real-sleep
invocations against only 1651 counted frames, a gap consistent with extra
invocations during a title-wait loop.

**Not fixed, not chased further as of this note** -- flagged as real and
reproducible, not as something needing a shared-layer change yet. If a
future port's startup feels janky specifically in its first second or two
on 486-class hardware, this is a known, already-characterized cause to
check before assuming a new bug.

## Add debug output for

```
simulation Hz
render FPS
frame time
audio underruns
dropped renders
```

This instrumentation should exist before any optimization work starts —
see `docs/optimization.md`: never optimize without numbers.
