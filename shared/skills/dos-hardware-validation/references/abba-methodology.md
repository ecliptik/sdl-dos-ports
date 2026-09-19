# ABBA methodology with pre-registered thresholds

A method for turning a real-hardware A/B performance claim into something
someone can act on, instead of "some numbers that happened."

## Why ABBA, not A-then-B

A straight "run A, then run B" comparison confounds the lever under test
with anything that drifts over time -- thermal state, a card warming up,
a background process, session-to-session rig variance. ABBA (A/B/B/A,
repeated as a block) cancels a monotonic drift across the block: if
performance is trending up or down for reasons unrelated to the lever,
that trend shows up symmetrically in both A's and both B's rather than
biasing the comparison toward whichever arm happened to run first.

## Steps, in order

1. **Pick the lever(s) and write the pre-registered thresholds** -- what
   delta magnitude counts as a real win, what counts as noise, what counts
   as a regression -- *before* running the first cell. If the thresholds
   get adjusted after seeing the data, the result is no longer a test, it
   is a story fit to the data.
2. **Write the invalidity conditions** -- see below. Also before running.
3. **Run the block**: A, B, B, A (one full cell each, full
   set/forbid/expect_log discipline per `cell-protocol.md`). Repeat the
   block (x2 or more) if the campaign's budget allows -- a single block
   is the minimum, not the target.
4. **Check invalidity conditions before looking at the delta.** If the
   block is invalid, don't compute a verdict from it -- re-run instead.
5. **Compute the verdict** from the pre-registered threshold table, not
   from eyeballing the raw numbers.

## Invalidity conditions (check these before trusting any delta)

- **A-to-A spread too wide.** The two A cells in a block should agree with
  each other within a stated band (a same-config, same-binary re-run
  should reproduce closely). If they don't, the rig was not sitting
  stable during this block -- something changed between the two A runs
  that had nothing to do with the lever, and the B cells sandwiched
  between them are not trustworthy either. Discard the block, don't
  average through the instability.
- **Baseline does not reproduce a known prior figure within a stated
  band.** If this port/config has a previously-measured baseline number,
  today's A cells should land near it. If they don't, something changed
  outside the lever under test (a different binary than intended, a rig
  config drift, a different card/CPU than expected) -- resolve that before
  trusting any comparison run on top of it.

Both checks exist because a comparison run on an unstable baseline can
produce a confident-looking delta that is actually measuring instability,
not the lever.

**A noise floor belongs to a fixture, not to a machine.** Measured on one
real target in one campaign: 0.12 fps spread on an idle fixture and 0.24
on a moving-content one, same machine, same session. Carrying the smaller
one across would have halved the bar a delta had to clear. Measure the
floor for the fixture you are about to draw a conclusion on.

## The second noise floor: build layout, which A-to-A cannot see

An A-to-A check re-runs **the same binary**, so it measures run-to-run
variance and nothing else. It is structurally incapable of detecting
**build-to-build layout variance** -- the performance difference between
two binaries that do the same work but whose code the compiler placed,
aligned, or allocated registers for differently. On a 486-class target
with a small cache and no branch prediction, that is not a rounding
error: a real campaign measured a build with *strictly more work in it*
running **0.93 fps faster** than the same revision without the added
instrumentation, four times that fixture's run-to-run spread.

This matters because **every single-build A/B comparison is exposed to
it.** An A/B of patch N versus patch N+1 compares two different binaries,
so its delta contains the lever's effect *plus* whatever layout variance
those two builds happen to differ by. If the layout floor is comparable to
the delta, the measurement cannot attribute the difference to the patch at
all -- and no amount of diffing the source will ever find the mechanism,
because there isn't one. Repeated failure to find a mechanism for a
reproducible delta is a signal worth taking seriously here.

**Measure it with a layout-perturbation ensemble.** Build three or four
**semantically identical** variants of the *same* revision -- vary
`-falign-functions`/`-falign-loops`, insert padding ahead of the hot
function, reorder two independent functions -- and run a cell on each. The
spread across that ensemble is the layout floor, and any single-build A/B
smaller than it is unattributable. Two practical notes: an added probe or
banner is *not* a semantically neutral perturbation if it executes on the
hot path, and the floor is per-translation-unit as much as per-fixture, so
measure it on the TU the lever actually touches.

The strategic reading matters as much as the number. When a target sits
right at a frame-budget boundary, a layout lottery of this size decides
gate outcomes. **The durable fix is to take enough real work out to move
off the margin**, not to keep chasing deltas the size of the floor.

**Measure a floor with a deliberate ensemble; never infer one from
incidental observations.** A real campaign watched two code-adding
changes land at +0.93 and -1.04 fps, concluded from those two points that
growing the hot path carried a +/-1 scatter, and wrote down a ~2 fps
floor. Measured properly with dead-but-emitted blocks at three sizes, the
actual size effect was **0.19 / 0.23 / 0.27 across a 5.6x size range** --
smooth, monotone, no cliff, and indistinguishable from that target's
0.19 alignment floor and 0.24 run-to-run floor. The real floor was ~0.25,
not 2. The cost of the error ran both ways: a correctly-attributed 1.21
fps regression was retracted as noise, and a wrong floor reached this
file before the ensemble that refuted it had been run.

So the useful rule is narrower than "calibrate by perturbation class,"
though that still holds: **two observations are an anecdote, and the
ensemble is cheap.** If a floor is load-bearing for an attribution, run
the variants.

**The diagnostic signature and the test that settles it.** When two
unrelated patches each add small, provably cheap logic to the same hot
path and each cost about the same, with no mechanism surviving scrutiny,
the natural hypothesis is that growth itself is the cost -- an I-cache
boundary or an inlining flip. Test it with **dead-but-emitted code**: a
block of comparable size behind a condition the compiler cannot fold away
(a `volatile` read, an env var), so it is emitted but never executed.
Confirm emission by diffing instruction counts, or a folded-away block
gives a null result that means nothing.

In the case above the test came back **negative** -- inert code the same
size as the real change cost 0.23 where the real change cost 1.05, a 4.6x
difference at identical growth. That is a strong result, not a wasted
round: it proves the cost is *execution*, eliminates size, layout and
inlining in one cell, and sends the investigation back to finding out why
calls that look like nanoseconds are not. A cheap test that kills a
plausible hypothesis is worth more than the argument it replaces.

## Prefer a within-build A/B: put the lever behind a runtime switch

Everything above -- layout variance, code-size scatter, inlining flips,
I-cache placement -- exists only because the two arms are **two different
binaries**. Compile the lever behind a **runtime hint or env var and A/B
within one build**, and all of it vanishes by construction: identical
code, identical layout, identical cache behaviour, toggled at startup.
The floor collapses back to the run-to-run figure, which is typically an
order of magnitude smaller.

**Any effect smaller than the code-adding floor must be measured
within-build or not claimed.** Large deltas are safe either way -- a
comparison of presentation modes differing by 13+ fps was never at risk
from a 2 fps floor -- so this is a rule about small effects, which is
exactly where optimization work lives once the obvious wins are gone.

This usually costs nothing to adopt, because a lever worth measuring is
often a lever worth shipping as a tunable anyway. Build the switch for
the feature and the measurement method comes free with it. Two cautions:
the switch itself must not be read on the hot path (hoist it to a
startup-time bool), and both arms still carry the code, so a within-build
A/B tells you the lever's value but *not* what the added code cost to
include -- that question needs the dead-but-emitted test above.

## Verdict table shape

Key the verdict to the delta magnitude against the pre-registered
thresholds, not to statistical significance alone (a real hardware sample
size is usually too small for significance testing to be the deciding
factor) -- e.g.:

| Delta vs. baseline | Verdict |
|---|---|
| Within the noise band (± threshold) | No measurable effect -- do not claim a win or a loss |
| Beyond the noise band, below the "large" threshold | Small effect -- note it, don't lead with it |
| Beyond the "large" threshold | Large effect -- actionable conclusion |
| Negative beyond the noise band | Regression -- do not ship without understanding why |

Set the actual threshold numbers per port/metric based on that port's own
measured noise band (see `docs/optimization.md` and `docs/timing.md` in
the sdl-dos-ports hub for why real-hardware FPS noise has been measured at
several times the within-session band -- a threshold copied from a
different port's noise characteristics is not safe to reuse blind).

## What a finished campaign write-up needs

- The full verdict table and which row the result landed in.
- The actual per-cell numbers (raw data, not just the computed delta --
  see the main skill's "hand off raw data" rule).
- Which invalidity checks were run and that they passed.
- Identity fields for every cell (see `cell-protocol.md`'s Collect
  section) -- a campaign result is only as trustworthy as the weakest
  cell's identity confirmation.
