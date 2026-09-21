# Harness invariants: why a check is a check

Distilled from this hub's own `/HARNESS-STANDARD.md` (adopted from
doskutsu, where it originated) -- a formal, platform-agnostic
"agent-driven test harness standard" written with explicit public-release
framing ("nothing in the normative text should assume any particular
project"). Read `/HARNESS-STANDARD.md` itself for the normative spec (the
I1-I3 invariants, the L1-L3 conformance ladder, and the full section-by-
section contract); this file is the *practice* layer -- how those rules
apply concretely on this hub's own vcctrl-driven rig, with this hub's own
worked examples. Read this alongside `cell-protocol.md` and
`abba-methodology.md` -- those cover the DOS-rig-specific mechanics this
file's rules apply to.

## The core problem this whole file addresses

An agent's failure mode tends to resemble its success mode, not announce
itself as failure -- a stale file looks like a fresh one, a sender that
isn't idle yet looks like a completed transfer, a banner printing looks
like a feature engaging. **The point of a harness is to make every claim
a run might make checkable from an artifact that run actually produced**,
so "looks right" and "is right" stop being the same question.

## The three invariants

**I1 -- Attest, do not recall.** Every fact about a run must live in an
artifact the run produced, not in memory, a transcript, or prose written
after the fact. Test: could this run be fully reconstructed from its
artifact bundle alone, with no appeal to what anyone remembers happening?
A manifest field meant to attest something can still fail this if it's
written to a file the collection step never actually ships -- the witness
existed and was never delivered, which is functionally the same as never
existing.

**I2 -- Witness the state, not the artifact.** A side effect proves that
side effect happened, not that the system reached whatever state you're
inferring from it. A file arriving does not mean the sender is idle and
ready for the next step (it may still be inside its own transfer client).
A result file existing does not mean the run that was supposed to write
it actually finished, or even that this run wrote it, rather than a
previous one. A banner printing does not mean the feature it announces
actually engaged on the code path that matters. Each of these gaps has
caused a real incident on this hub's own rig (see `dos-rig-operations`'
file-transfer and log-collection material) -- I2 is the general form all
of those are specific instances of.

**I3 -- Audit for the effect, not the syntax.** When hunting a defect
class, enumerate what the system would actually *do*, not the syntax
pattern you expect causes it. This is the source of the "REM redirect"
lesson already in this hub's docs: searching for unescaped `>` characters
found some real hits, but the actual worst instance was a `REM` comment
whose *quoted example* of the bug still redirected -- documenting the fix
by citing the broken syntax literally recreated the exact file the fix
was meant to stop creating. No syntax-pattern search finds this; auditing
"what file would this line create" does.

## A check that can't distinguish success from failure is not a check

The single rule most of this file's other rules reduce to, already
referenced elsewhere in this hub's skills: **before relying on a check,
state what its failure would look like.** If that's indistinguishable
from what success looks like, it isn't a check -- replace it with one
that can actually fail visibly.

Recurring proxy-for-the-real-thing pairs worth recognizing on sight:
file arrived -> sender ready for next step; result file exists -> the
cell that should have written it finished; a result envelope is complete
-> the cells inside it succeeded (a sweep where every cell died at
startup produces an envelope structurally identical in shape to one where
every cell passed); a command prompt returned -> the command succeeded;
a process is running -> it's making progress; a status's last known value
-> its current value.

**A check that can fabricate an answer is worse than no check at all**,
because it manufactures false confidence rather than leaving an honest
gap. Prefer a check that names the attempt and points at its own witness
(something that cannot be true unless the thing you care about actually
happened) over reading a status whose own provenance you haven't
verified -- does this program even reliably set an exit code on the path
you're checking? A completion message conditioned on an unverified
exit-status source can end up reporting the *previous* command's status
without anyone noticing, because a wrong-but-plausible status looks
exactly like a right one.

### Corollaries worth keeping as their own reminders

- **Having just named a hazard is when it is most likely to recur.**
  Diagnosing a failure shape doesn't confer immunity to it -- the
  dangerous moment is the feeling of being covered right after diagnosis,
  which is exactly when the check that would catch a repeat gets skipped.
  The defense is the procedure, not the understanding of the mechanism.
- **Verification must be routine, not reserved for doubtful-looking
  claims.** A "check suspicious things" policy catches nothing, because
  a claim that looks suspicious would have been questioned anyway. This
  matters most for a report that *explains away your own error* -- it
  arrives with a built-in reason to accept it, which makes it the least
  likely claim to get independently checked, not the most.
- **A watch/monitor/alarm is a check too, and is unusually good at being
  blind to its own event**, because "nothing to report" is both its
  normal state and its broken state. Before arming a watch, state what it
  would actually emit if the exact failure it exists for happened right
  now -- if the honest answer is "nothing," it isn't a watch yet. A stall
  detector that compares the current frame signature against the
  previous one is a concrete instance of this: a dead/black capture
  yields a null signature every time, null never equals the prior null,
  so a wedged, unchanging screen scores as "activity" indefinitely (this
  is the exact mechanism behind the frame-diff stall-detector incident
  referenced in this hub's own rig-hazard material). **A null/absent/error
  reading must never flow into a comparison that treats "different" as
  "healthy"** -- absence is a third state, not a degenerate case of the
  other two. A watch should be tested by deliberately inducing its event
  before it's trusted; one that has never fired has not been shown to
  work.
- **Silence may be the failure signal, not the absence of one.** Where
  success announces itself with a banner and failure just says nothing, a
  broken run looks exactly like a clean one from the outside. Never infer
  success from an absence of complaint -- assert the positive consequence
  directly (the module is resident, the file is present, the capability
  is actually offered) instead of trusting that a problem would have said
  something.
- **An unstated scope gets read as covering whatever the reader is
  currently worried about.** A verdict is only sound within some
  boundary; if a check doesn't state that boundary in its own output,
  different readers will supply different boundaries -- typically
  whichever one answers their current question. A harness-readiness
  check that answers "can the apparatus drive the target" easily gets
  read as "is the target correctly configured to be measured," and a
  fully green harness can drive a misconfigured target for an entire
  session without anyone noticing the difference. Any check emitting a
  verdict should name its subject, and should say what it does *not*
  cover wherever a reader could plausibly over-extend it.
- **A reading must be shown to belong to the current epoch, not just to
  be currently readable.** A status surface (an LED, a "ready" flag, a
  cached value) retains its last published value through a discontinuity
  it didn't cause -- a power cycle, a reboot, a re-enumeration -- so a
  target that's mid-reset and publishing nothing just keeps showing
  whatever was true before the reset. That's not flagged stale; it reads
  as exactly the same value a genuinely-current reading would show. A
  level-check on this kind of state is invalid across any discontinuity;
  what's actually needed is a transition observed *after* the
  discontinuity (wait for the indicator to go false first, proving the
  next true you see belongs to this boot, not the previous one) or a
  value that carries its own epoch marker. The moment right after
  something changed is exactly the moment a retained reading is most
  likely to get consulted -- and exactly the moment it's least trustworthy.

## A platform profile is a lint gate, and its false-positive rate is a real requirement

Every project should maintain its own list of what its target platform
does silently -- as checkable rules, enforced by a lint gate that runs
*before* packaging, not discovered after deployment. This hub's own
DOS/DJGPP/real-MS-DOS instance of that list -- no escape character in
`COMMAND.COM`, redirection parsed inside `REM` comments, a 256-byte
environment block silently dropping a `SET`, and similar -- lives in
`docs/dos-scripting.md`, not duplicated here.

The methodology point worth keeping regardless of platform: **a gate's
false-positive rate is a functional requirement, not a nuisance to tune
out eventually.** A noisy gate stops getting run, and its mere existence
then creates false confidence that the class of bug it was meant to
catch is covered -- which is strictly worse than having no gate at all,
because the belief persists after the practice has actually lapsed. A
gate that reported 534 failures (22 real, 512 from two bugs in the gate's
own parser) went unused for exactly this reason until the parser bugs
were fixed and the count dropped to a trustworthy 25.

## Declared vs. detected are different kinds of fact -- keep both

**Declared**: human-asserted, unverifiable by a machine, goes stale the
moment the hardware changes underneath it. Must be parameterized, never
hardcoded -- an empty/unset declared field honestly reads as "nobody
stated this yet"; a hardcoded string keeps asserting its original value
forever, silently wrong the moment reality moves on.

**Detected**: software-observed, recorded verbatim, must name what
actually performed the detection. Detection can itself be masked and
report the wrong layer -- a compatibility shim that reports its own
identity rather than the real underlying hardware means a detection
field attests the shim, not the thing you actually wanted to know about.
The real discriminators are often already sitting in other log lines
(a mode list, an aperture address, a chip-specific identification
string) rather than needing new instrumentation.

Neither replaces the other -- they answer different questions, and a
result envelope being structurally complete does not imply the cells
inside it succeeded (a sweep that died at init on every cell produces an
envelope indistinguishable in shape from one where everything passed; the
separating fact is a captured completion witness, not envelope presence).

## Hardware swap discipline

A hardware change (a card swap, in this hub's own case) is the single
riskiest moment in a campaign, because it's exactly when a stale
declaration is both most likely and least visible:

- A swap ends the session -- any comparison across the swap is a
  cross-session comparison by construction (see the noise-floor section
  below), never treat it as same-session.
- Re-anchor on the new hardware (run a control + repeat pair) before
  measuring anything else -- a baseline does not survive a swap.
- Update every declared field as part of the swap procedure itself, not
  as an afterthought once someone notices something looks off.
- Re-read every detected field after the swap -- it's the only
  independent check on whether the declared fields still match reality.
  A swap where declared and detected disagree is a stopped campaign, not
  a footnote to work around.
- A replacement part lacking a mode/resolution/feature the campaign
  depends on threatens the *validity* of results from it, not just their
  comparability to other parts -- a config that can't run the reference
  workload identically must not contribute rows to a shared comparison
  table at all.
- Carry a known defect on a specific configuration forward explicitly,
  or it gets rediscovered later and mistaken for a property of whatever's
  actually under test.

## Preflight and the physical layer

Logs, screen captures, and status flags all report *software* state --
a physical-layer fault (a marginal connector, a partially-seated card, a
failing cable) sits upstream of every one of them, and no amount of
better logging reaches it. A harness needs to be able to say "I cannot
determine this" and escalate to a physical check, rather than continuing
to generate plausible-sounding software hypotheses. A confident sequence
of plausible causes, none of them right, is itself a symptom of not
having real evidence yet -- plausibility is cheap and isn't the same
thing as progress.

Two sharper rules worth applying directly to this hub's own vcctrl-driven
rig work:

- **Prove the control path at the far end, not just at the near end.**
  Every near-end status (driver loaded, device opened, write reported
  success) can be green while nothing actually arrives at the target --
  get a response *from the target itself* proving the path end-to-end
  before trusting a run. This needs four states, not two:
  answered (proven working), did not answer (a real fault), could not
  look (this configuration has no return channel to check -- must never
  collapse into "did not answer"), and tool failed (the check itself
  didn't run). Collapsing "could not look" into "did not answer" turns an
  honest gap into a false failure.
- **Preflight is one command with one exit code.** A list of several
  individually-correct readiness checks is not a gate -- lists get
  skipped exactly when a run is finally ready to start, which is the
  moment they matter most. Combine into one verdict: any fault anywhere
  -> FAULT; else any unknown -> UNKNOWN (never silently reads as pass);
  else PASS -- but still report which specific check decided the
  verdict, and don't let a later fault mask an earlier unknown or vice
  versa. Run non-invasive checks before invasive ones, so a target not
  fit to be written to is discovered without having been written to. A
  check that can't run for an incidental reason (another session holds
  the rig lock) is UNKNOWN, never FAULT -- name what's blocking it.

## Preconditions checked after the run are receipts, not gates

A precondition (no other TSR resident, the right driver loaded, the right
provider active) must be checked *before* the gated work runs, as an
executable check, not written down as prose in a run sheet read
beforehand. This is an ordering requirement, not a diligence one -- a
correctly-worded precondition assertion, applied to the returned logs
after a 14-minute run whose graphics provider had silently failed to
load, still "worked": it accurately reported the run was worthless,
fourteen minutes too late to matter. What makes this trap persistent:
a post-hoc check still passes review (it's present, correctly specified,
and does fire -- its defect is invisible in the document, visible only on
a calendar); it's cheapest to write on the wrong side (a grep over a
returned log is easy to write; checking the *live* machine needs a
different instrument, so the grep gets written first and never replaced);
and a run sheet read in order means "preparation" formally ends where the
round begins, so a post-run conditions list gets read after the round is
already over. A post-hoc version of the same check is still worth keeping
as a *second* gate (it catches drift during a run that a pure preflight
can't see) -- it should just never be *the* gate.

The software stack under test (drivers, firmware, resident providers,
compatibility shims) needs this same per-cell attestation, not just the
hardware -- a silently-declined driver falling back to a card's bare ROM
VBE is exactly this shape of failure (see `docs/video.md`'s UniVBE
material), and the discriminating field is usually already sitting in a
log line nobody had checked yet.

## Noise floor: two bands, not one

Within-session (a control + repeat pair run in one sitting) and
across-session (the identical nominal config, a different sitting -- a
different day, a card reseated) are **not interchangeable, and any
comparison must state which band it's being read against.** On this
hub's own real-hardware history: within-session repeatability measured as
tight as 0.0-0.1 fps; the identical nominal config measured a day apart
differed by up to 0.85 fps -- over 4x wider. An effect smaller than the
relevant band cannot be attributed to anything that changed, no matter
how tight the within-session numbers looked in isolation. **Quoting a
within-session figure and then comparing it against a different
session's number is one of the most common ways a benchmark manufactures
a result that isn't real** -- always requantify the band for whichever
comparison is actually being made, and treat any delta smaller than that
band as unresolved, not as a win or a loss.

The same discipline applies to validating a change to the measurement
apparatus itself (a new rig host, a different capture path, an updated
driver) -- across-session confounds exist even when nobody can name their
cause, so comparing an apparatus change against an absolute banked figure
has no power to fail; a number landing near the old one reads as a clean
pass whether or not the comparison could ever have failed. Validate an
apparatus change on *differences* instead: does the control-pair spread
widen on the new apparatus (a regression regardless of absolute numbers)?
Does a previously-measured arm delta reproduce within the known band on
the new apparatus? Pick a workload that's already gated end-to-end for
this, so an apparatus effect doesn't get confounded with an unrelated
precondition failure.

## Decompose a single metric before trusting it

A single throughput number conflates distinct costs and can actively
invert a ranking. Concrete worked example from this exact hazard: a
render-loop metric extrapolated as `flips / (route_duration -
overhead)` read as 114.9 fps on a cell that was, in wall-clock terms, the
slowest of the batch -- because 82% of that cell's wall time was booked
as one-time load-stall overhead (a scene-transition data upload), and the
extrapolation treats overhead as if it were free once it's subtracted
out, which stops meaning anything once overhead dominates the total. Fix:
decompose into an in-loop rate and an out-of-loop overhead as two
separate numbers (`per_loop_fps` and `overhead_s`), and only trust the
extrapolated per-loop figure when overhead is a small fraction of total
duration (roughly under 25%, as a starting heuristic) -- above that,
quote the plain wall-clock mean and a per-stage breakdown instead. Sanity
check: `per_loop_fps / fps_mean` should roughly equal
`duration / (duration - overhead)`; if those disagree by more than a few
percent, something else is wrong, not just the overhead ratio.

## Before spending a cell on a lever, prove the code under test EXECUTES

`set_vars`/`forbid`/`expect_log` prove the lever was *requested* and that
the engine *accepted* it. None of them prove the code you are measuring
actually runs on the fixture you are running it against. A cell that
cannot distinguish a positive result from a negative one is not a
measurement, and it costs the same machine time as a real one.

Two instances from one campaign, both burning cells on tests that could
not test anything:
- **Already out-of-line.** A `noinline` attribute was applied to a
  function the compiler had *already* placed out-of-line, so the build
  was a near no-op. The null result read as evidence against the
  hypothesis; it was evidence of nothing. **Symbol count in the built
  binary** settles it before the cell runs.
- **Never reached.** The same attribute was then tested on a fixture
  where that function never executes -- an unrelated patch gates the
  whole code path above a buffer-size threshold the fixture exceeds. An
  **execution counter** (`presents_skipped=0` here) settles it, and in
  this case the constraint had already been written down in the
  campaign's own prior record and simply not re-read.

So: prove reachability the same way you prove anything else here, by
attestation rather than recall. **Symbol count for "is it a distinct
function", an execution counter for "does it run on this fixture", and a
grep of your own prior records before designing the cell.** The second
instance is the cheaper lesson of the two -- the answer was already in the
project's notes, and the round was spent anyway.

### A present-path bug needs a capture of the SCREEN, not of the buffer

A backbuffer hash or reference-bitmap comparison validates what the game
*drew*. It is blind, by construction, to everything that happens between
the buffer and the monitor: which rectangle got pushed, where it landed,
whether it landed at all. A dirty-rect optimization in one campaign
pushed 417 frames' worth of rects **60 rows too high** -- refreshing the
wrong strip of the display -- while every baseline capture passed, because
the back buffer those baselines hash was correct the whole time.

The offset came from accumulating a bounding box in *game* coordinates
and testing it against *window* coordinates, which differed by a
letterbox margin. Any coordinate-space mismatch on the present path has
this shape. **Whenever a change touches what gets pushed or where, verify
with a capture of the actual screen** -- the port's own VGA capture or a
camera -- and do it before and after, not only after. See `docs/video.md`
on the limits of each capture channel.

**But match the gate to the layer the change touches — the camera is not
always the stronger one.** A later round in the same campaign split a fix
into two stages and found their correctness gates were not
interchangeable. Stage 1 altered *invalidation* and provably did not
touch the back buffer, so a buffer hash could not have caught a fault
there and only a camera capture was evidence. Stage 2 altered
*compositing*, and the buffer hash caught a rendering defect on its first
run — a defect the camera gate from stage 1 would have passed, and which
no timing number would ever have shown. **A change that touches both
layers needs both gates**, and a change that touches neither needs to
explain why it is being measured at all.

**Attach the workaround, or this rule sends people into a false
failure.** A capture path that judges liveness by looking for frame
changes will refuse a *correct static screen* -- "every frame in the
window was a duplicate" is indistinguishable from no signal to it, and an
adventure game holding a still room is exactly the case you most want to
verify. Use the raw burst path rather than the judged one for this check.
Two consecutive identical frames are the desired result here, not a
fault: they also rule out a display alternating between correct and stale
content, which a single capture cannot.

### A stamp-based build can hand you a stale library and a clean build log

`make` targets that gate on a stamp file rather than on source timestamps
will not notice an edit to vendored source. One campaign found its SDL
library **four days stale** while the engine rebuilt happily against it —
no error, no warning, a green build. The instrumentation added that
afternoon was simply not in the binary.

It was caught by checking for the new symbol with `nm` before running.
Had it not been, the cell would have measured the **old backend** and
returned zeros for every new counter — and zeros are exactly what the
hypothesis under test predicted, so the wrong binary would have produced
a confident, wrong confirmation.

**Verify the artifact contains the change before spending a cell on it.**
A clean build log is a claim about `make`, not about what is in the file
— the same "attest, don't recall" invariant applied one layer down.

**But pick a check that actually works on your toolchain, and confirm it
can fail.** This entry originally recommended `nm` for a new symbol.
On the DJGPP toolchain it was then found to return **zero matches for
symbols that demonstrably link and fire** — so it had been cited twice as
the verification while verifying nothing, and the real check both times
was a **functional** one: the new counter printing a non-zero value under
the emulator. A static-symbol query is easy to get silently wrong
(stripping, local linkage, inlining, name decoration); an output line
that only the new code can produce is not.

**Prefer the functional check**: run the build and look for something the
change emits. And test the check itself against a binary that *lacks* the
change — a verification that passes on both is not a verification, which
is this file's founding rule applied to its own advice.

### A counter reading zero must distinguish "false" from "never ran"

Zero is the most ambiguous value an instrument can return, and it is
usually the value a failing hypothesis predicts — so a zero you cannot
decompose will confirm whatever you were hoping to rule out.

A campaign testing whether a vblank guard caused a stall instrumented the
guard's condition and read zero. That zero was consistent with **the
condition being false**, with **the guard never being reached**, and with
**the wrong call site being instrumented**. It was resolved by adding a
`skipped` counter — incremented on reaching the guard and not taking it —
which separates not-taken from not-reached, and by instrumenting *both*
call sites rather than one.

**Two rules.** Pair every conditional counter with a reached-but-not-taken
counter, so zero is decomposable. And **instrumenting one of N call sites
is not a measurement of the function** — enumerate the call sites first,
and instrument all of them or state which one you measured.

**And decompose zero at every level, not just one.** The campaign above
then hit the same wall one layer up. The `skipped` counter it had built
for exactly this purpose reported *not reached* — and that was read as
"this call site is dead", so a **second site inside the same function**
was instrumented next. The function itself was never called: the port
takes a direct-framebuffer fast path that bypasses it entirely, and three
patches ran in dead code before anyone asked.

The hierarchy is **branch not taken → site not reached → function not
called → path not taken**, and a zero at any level says nothing about the
levels above it. When a counter reports not-reached, **the next question
is not "which other site" but "is this function on the path at all"** —
one counter at the function's own entry answers it, and it is cheaper
than the site-by-site search it replaces.

**Which gives the mechanical fix for the enumerate-call-sites rule:
instrument the callee, not the callers.** The same session miscounted
call sites three times in one function — twice reporting "two sites"
where there were three, with the conclusion surviving only because the
third happened to sit on the same side of the branch as the other two.
Enumerating N callers is an O(N) search with an O(1) alternative: **one
unconditional counter at the top of the called function answers "is this
reached on our path" for every site at once, including sites added
later.** Reach for caller enumeration only when you need to know *which*
site, not *whether*.

**And make the "I was here" counter reflexive.** Every instrumented site
should carry an unconditional hit count beside its conditional ones, at
the function's own entry. Then zero on the unconditional counter reports
not-reached immediately, at that site, with no inference — and three
patches cannot run in dead code, because the first one says so.

**"Unconditional" is not enough: the entry counter goes on the FIRST
line, or it is measuring something else.** The same session then placed
an unconditional counter 950 lines into a 1,000-line function — past an
early return two-thirds of the way through — and read its zero as "this
function is never called". The function was called on every frame; the
early return was simply always taken. **An unconditional counter after a
branch is a branch counter wearing an entry counter's name**, and it
produces exactly the same misleading zero the rule was written to
eliminate. The correctly-placed counter in the same round, on the first
line of a different function, gave the right answer immediately.

A function long enough to need instrumenting is long enough to defeat
placement-by-intuition. **Put the counter on line one, then place the
others relative to it.**

### A decomposition instrument must assert that its parts sum to its whole

An instrument bug that produces an *absurd* number gets caught. An
instrument bug that produces a *plausible* number gets believed and acted
on, and no amount of care detects it — the reading looks exactly like a
finding.

A campaign hit two in one short patch. A per-phase delta printed
17,847,809 microseconds of script time inside a 636 ms tick, because
phase totals accumulate across nested loops while the self-time figure
deliberately excludes them, so the two were never comparable. The fix
introduced the second bug: a children figure that printed the parent's
running accumulator rather than the child total. Both were caught only
because the values were self-evidently impossible. As the author put it:
at 1.4 seconds instead of 17.8, it would have been read as real and
reported as a finding.

**So make the check structural rather than relying on noticing.** Any
instrument that splits a quantity into parts should assert the parts
reconstruct the whole — `self + children == total`, phase sum == frame
total — and report a violation count alongside the data. Both bugs above
fail that assertion immediately and automatically. This is the
decomposition case of the rule that a check which cannot distinguish
success from failure is not a check: without the sum, a decomposition
cannot tell a correct split from a wrong one.

**Pair it with a plausibility floor, because the sum alone is not
enough.** The same patch produced a third bug the assertion passed
cleanly: a per-frame line of well-formed zeros, because the snapshot was
taken at the end of one call and reported at the top of the next with
nothing running in between. Every delta was correctly zero and the parts
summed perfectly to the whole. **A sum check tests internal consistency;
it says nothing about whether the interval measured is the intended
one.** Two failure modes need two defences — assert the parts add up,
*and* assert the total is physically possible. A frame that took 0
microseconds is not a frame.

### Label correct behaviour that looks identical to a known bug

An instrument had just been fixed for a bug whose signature was a zero
total alongside non-zero children. It then produced a *legitimate* zero
total alongside non-zero children — the outer call records on return, so
during a nested blocking loop the outer total genuinely has not advanced
while inner phases have. Correct, and indistinguishable in the output
from the defect fixed minutes earlier.

**When correct behaviour shares a signature with a bug you have seen,
label the correct case explicitly** — one extra field saying
`NESTED=outer-call-still-in-flight` removes a whole class of future
misreading, including by the author weeks later. Otherwise every reader
has to re-derive which of two identical outputs they are holding, and
the one who gets it wrong will "fix" working code.

### Instrumented code on a timing-gated path needs a forced-execution mode

The pre-cell rule — prove the code executes before spending a cell on it
— can fail at a second level: the instrument runs, the harness reports no
error, and the numbers are meaningless because the *path the instrument
lives in* was never entered. One campaign read `frames_skipped=0` under
its emulator as "the emulator never falls behind"; the truth was that the
fixed-timestep code was switched off there entirely. Two very different
facts with the same number, and the flattering one got taken.

Some paths only execute under real timing and cannot be reached on a
developer machine at all. **Treat a forced-execution switch as a
requirement on instrumented code of that class, not as a workaround** —
without one, the pre-cell rule is unsatisfiable off-target and the
emulator's silence will read as coverage.

### Diff the defaults between your emulator runner and your hardware runner

The cause of the above was an asymmetry nobody had audited: the hardware
runner set an environment variable by default and the emulator runner did
not. **Every emulator validation of everything behind that variable had
been vacuous** — not wrong, vacuous, which is worse, because it looked
like coverage and generated passing checks.

Enumerate every variable, flag and default each runner sets, diff them,
and for each divergence state which code paths differ as a result. Some
divergences are deliberate and should stay — committed reference hashes
recorded under one configuration are a real reason not to flip a default
— but that is an argument for re-recording the expectations under a known
configuration, not for leaving the correctness gate blind. Keep the diff
in the repo so it is reviewable rather than rediscovered.

### Run at least one cell with ALL optional instrumentation off

There is an existing rule for checking whether instrumentation
contaminates a comparison: diff the bracket sets of the two binaries, and
if they are identical, per-tick overhead cannot differ between them. That
rule is correct and it is not enough. **It only covers *differential*
contamination. Anything present in every run is invisible to it by
construction**, and the campaign that wrote the rule then spent a day
chasing a cost that was exactly that.

**A campaign found exactly this, after first finding a false version of
it.** The false one: 94% of a 7.53-second engine event attributed to its
own `debug_script_log` calls, which reached the operator as a retraction
of a major finding before the next measurement showed the logging was
**1.9 milliseconds** and the time belonged to an engine call a misplaced
bracket had swallowed.

The real one, hours later and on a different phenomenon: a ~250 ms stall
recurring inside the present path, which had survived **six** hypotheses.
It was the port's own diagnostic doing an `fsync` from inside the flush —
one write per hundred presents, most costing 21-36 ms on the CF card and
one hitting **227 ms** on what was probably an erase cycle or FAT commit.
The stall had been measured at **18.7x over-represented** against the
present's share of CPU time, and that was the clue read backwards: **the
present was over-represented because the present was where the disk
writes had been put.**

**Keep the two straight wherever both appear**, because the sentences are
nearly identical and the evidence is not comparable — the false one was a
scope bug, the true one had `fsync`-level attribution with phase maxima
summing to the total within 0.002 ms in 23 of 24 blocks.

The rule stands on its logic independently of either: **a bracket-set
diff compares two binaries and therefore cannot see anything present in
both.** Overhead that every run carries is invisible to it by
construction, and the failure mode is silent — every figure is
consistently wrong in the same direction, which is precisely what a
differential check is blind to.

**So price your own instrumentation directly, with at least one cell per
campaign that has every optional channel, counter and log switched off.**
The bounding is the same as for a suspect clock: ratios and within-build
A/Bs stay safe, because both arms carry the same overhead; **absolute
figures judged against fixed bars do not.** And note the mechanism is
platform-specific — a log line that is nearly free on a host filesystem
can cost orders of magnitude more on real hardware doing a synchronous
write per line, which is exactly why it survives emulator validation.

The fix is not to delete the instrumentation. It is to measure with and
without, put the artefact's size on the record, and state which arm every
figure came from.

### "Absurd on its face" is a halt condition, not a hedge

A number you have just called impossible must stop the conclusion resting
on it. It must not appear beside that conclusion with an explanation for
why it might not apply.

Worked example, and it took two people to fail at it. An instrument
implied a cost of 0.78 seconds per log line. Its author wrote that this
was "absurd on its face" and shipped the conclusion anyway, labelled as
arithmetic rather than as a finding. The reviewer then derived the
contradiction *independently* from a second direction — 40 such calls
would be 31 seconds, against a whole-run excess of 2.7 seconds for the
entire fixture — wrote that down, and resolved it with "so either the
cost is specific to this context, or the per-call estimate is badly off."
That disjunction turned a falsifier into a caveat. The conclusion then
drove a work-order change and reached the operator. The real figure was
1.9 milliseconds; the estimate had been wrong by a factor of 20,000.

**A failed sanity check is a stop, not an annotation.** If the arithmetic
does not close, the next action is the measurement that closes it, not
the report. And note the reviewer's failure was the worse one: an
independent derivation of the same contradiction is stronger evidence
than the original flag, and it was spent on a hedge.

### A result that fits a pattern you have been rewarded for gets shipped faster

The same episode had a second cause worth separating from the first. Four
times that day the campaign had found that the real win was its own
redundant work rather than slow engine code, and each find was received
enthusiastically and relayed immediately. The fifth candidate fit that
pattern exactly — and it was the only one of five that left its author's
hands before a bracket had killed or confirmed it. The four that died
quietly each had a measurement between the guess and the message.

Two things follow, and the second is for whoever is coordinating rather
than measuring. **Put a measurement between a striking result and the
message that reports it**, especially when it confirms a pattern the team
has been rewarded for finding. And recognise that **turnaround speed is
set by the reader, not the writer**: a coordinator who responds within
minutes and relays upward immediately is training a pace that leaves no
room for the intervening check. Slowing the relay is the coordinator's
job to fix, not the worker's.

### Commit an analysis BEFORE the measurement that could confirm it

Pre-registration usually means writing down a prediction before a run.
The same discipline applies to **interpretations formed mid-investigation**
— a reading of existing data, an argument about what some earlier result
implies — when a measurement is already in flight that could appear to
vindicate it.

A campaign hit this productively. While a discriminating cell was on the
hardware, a session re-read four earlier instrument arms and found an
account of them that was **materially more favourable to the hypothesis
the cell was about to test** than the account it had published an hour
before. It committed the new reading, with its reasoning, before the cell
reported. That is the difference between an argument and a
rationalisation, and it cost nothing.

The author's own formulation is the one to keep: **when a pending
measurement could plausibly confirm a reading you have just formed, the
reading gets committed before the measurement reports, or it does not get
claimed at all.**

Note what makes this cheap rather than bureaucratic: it only binds when a
relevant measurement is *already running*, which is exactly the window in
which a convenient re-reading is most likely to appear and least likely
to be questioned.

### A scope opened before an `#ifdef` runs to the end of the enclosing block

A timing scope declared before a preprocessor conditional, with no
closing brace of its own, extends to the end of whatever block encloses
it — not to the end of the construct it is named after. One named
`_dp_log` in this way swallowed an engine call sitting *after* the
`#endif` and attributed 38.4 seconds of that call's time to logging.

This is the class of instrument bug that a parts-sum-to-whole assertion
cannot catch, because the parts still add up correctly — they are simply
parts of the wrong whole. **Check a scope's extent against the code it
claims to measure, not against its own name.**

### Make an instrument print the symbolic name, not a numeric code

An instrument that emits a bare enum value pushes the decoding onto
whoever reads the log, and that decoding gets done from memory or from
the order of cases in a `switch`. Neither is the enum.

A campaign came within one step of reporting the wrong cause of its
largest remaining cost. The measurement split an event kind by sub-type;
the expensive one was sub-type 1 and the free one sub-type 2, at a ratio
of 48,000 to 1. The handler's `switch` listed them in the opposite order,
and the phase's visible action in the game script pointed at the cheap
one — so matching the printed number against source order, which is the
natural thing to do, would have produced a confident report of exactly
the wrong sub-type. Reading the enum definition is what caught it.

**The fix is not to read more carefully. Print the name.** An instrument
that emits `kObjEventType_Room` has no downstream mapping step to get
wrong. Where a numeric code must be emitted, put the enum's own mapping
in the same output rather than expecting a reader to reconstruct it.

### State the denominator and population before comparing two figures

The most frequent analysis error in one real campaign was not a wrong
measurement. Every number involved was correct. The error was comparing
two of them whose *scopes* differed, three separate times, each costing
at least a round:

- **Nested brackets treated as additive.** Subtracting two measured terms
  from a frame budget produced a "17 ms unattributed" that did not exist,
  because the parent bracket contained the children and summed to more
  than the run.
- **Two fixtures treated as one.** "13% here versus 24.3% there means the
  cost scales with colour depth" compared shares of different frames on
  different fixtures; in absolute terms the comparison pointed the other
  way.
- **Two tick populations treated as the same.** "Script is 11-13% of
  these ticks but 94% of that path — a contradiction needing a cell to
  resolve" compared stall ticks in one phase against event dispatches in
  another. There was no contradiction, and reading the bracket site
  settled it in less time than designing the measurement took.

**Before comparing two figures, say out loud what each one is a fraction
of** — which interval, which events, which fixture, and whether the
brackets nest. All three of these were caught by reading rather than by
measuring, which means the check is cheap and belongs before the
hypothesis, not after it.

**A fourth instance, recorded because of who made it and what it nearly
cost.** The session that wrote this rule then quoted a phase's share of
frame time — 47% — from a *different fixture at a different colour depth
and four times the pixel count*. On the fixture actually under test the
figure was **4.9%**. It was the input to a significance test: the
phenomenon accounted for 92% of the stall time, so against 47% it looked
proportional and the investigation would have concluded the cost came
from outside the code entirely, while against 4.9% it is **18.7x
over-represented** and the code path is implicated. **The wrong
denominator would have inverted the conclusion and closed the search.**

Knowing the rule is evidently not sufficient to follow it, so make the
check mechanical rather than intentional: **when quoting any share or
percentage, write the fixture name beside it**, in the message and in the
notes. A figure carrying its own population cannot be misapplied silently
— and the person most likely to misapply it is whoever is most fluent
with the numbers.

### Prefer a decomposable rate over a percentile on a heavy-tailed run

A percentile is computed over a distribution. When that distribution has
a heavy tail, the percentile moves a great deal while the quantities
underneath it barely move at all — and it will look like a real effect.

Three cells in one campaign, the last two on an identical binary and
configuration, measured `fps_p50` at 36.60, 39.00 and 38.12 — a spread of
**2.40**. The same three runs give `tick_rate_steady x (1 -
skipped/ticks)` as 38.03, 37.97 and 38.00, a spread of **0.05**. The
fixture contained nineteen multi-second blocking operations, which skew
the per-second distribution the percentile is taken over. A coordinator
had already been handed the 36.60-versus-39.00 pair as an unexplained
anomaly, supplied a plausible mechanism for it, and relayed both upward.
**There was nothing to explain.**

**So when a metric can be decomposed into factors you also measure,
prefer the decomposition** — here into a tick rate and a skip fraction,
each independently meaningful, each stable, and each pointing at a
different cause when it moves. Keep the percentile for describing what a
player experiences, not for detecting a 1-2% effect.

And note the enabling error, which is the per-fixture noise floor rule
one step further on: the campaign had measured that fixture's blocking
behaviour in detail, had documented all three of its noise floors as
per-fixture, **and went on judging a percentile against a floor measured
on a different fixture entirely.** Characterising a distribution and then
using a statistic unsuited to it is a distinct failure from not
characterising it.

### A threshold detector finds one population and hides its neighbour

Any instrument that reports events "over N" partitions reality at N, and
the events just below it become invisible — not absent, invisible. If a
second population sits close under the threshold, the first one will look
like the whole story.

A campaign's stall detector fired at 250 ms and found a deterministic
~240 ms event with a clean mechanism, confirmed three times across three
binaries. A later cell carried a **168 ms** event in a different phase, at
no special offset, which the detector never reported. It surfaced instead
as **skipped frames rising from 12 to 17** — a different metric entirely,
and only noticed because someone compared two arms that should have
matched.

Two populations, then: one deterministic and explained, one sporadic and
not. **The clean mechanism would have absorbed the whole phenomenon** if
nobody had looked below the line.

**Set the threshold below the effect you care about, not at it** — and
when a threshold-based finding looks complete, check the distribution
just under the cut before believing it. A neighbouring population is the
most likely thing a clean result is hiding.

### An intermittent detector makes non-detection look like absence

The rule above is about events below a threshold. This one is about events
*above* it that the instrument still misses, which is worse, because the
detector is nominally working and its output looks like a complete list.

Three runs of the same sweep, same binary, same parameters, reported
**7**, **10** and **14** events. **A 2x range in detected count with
nothing varied** — and the third only turned up because a voided cell was
mined for what it could still say. Two conclusions were drawn from the
first pair and both were wrong:

- **"Position is not reproducible."** Six of seven positions were
  identical. The comparison that killed the position hypothesis had varied
  record size *and* sweep length *and* whether other arms ran — three
  levers at once — so the mismatch it found was its own.
- **"The rate is not stable"** — 6 events against 10 over the same bytes.
  A later lattice fit put every event in both runs on one 35.0-record
  period, `n` running 0..6 with no gaps. **One stable period, observed
  incompletely.**

Each time, a *missing detection* was read as a *missing event*, and each
time it retired a live hypothesis. A detected-event list is a statement
about the detector, and the union of two runs' lists can contain
structure that neither list shows alone.

**Two operational rules.** When runs disagree on a count, **fit the union
of their event sets before concluding anything from the difference** — a
lattice fit is robust to misses in a way an interval fit is not, because
a missed event merely raises one `n` instead of merging two intervals.
And **calibrate any such fit against a null**: with the period free, a
lattice will find *something*, so the question is how often it finds one
this good by chance. Here, 0 of 2,000 random draws reached the observed
residual — which is what made it a result instead of a shape. See
`abba-methodology.md`, "Calibrate a fit tolerance against a null".

### Never blind-probe a removable drive, and prefer the banner to the probe

A "read-only verification" cell wedged the target. The command was
`VOL C:;VOL D:;VOL E:;VOL F:`, added to read back the drive map after a
boot-config change.

**`VOL` or `DIR` against an empty optical drive is not a read.** It
raises DOS's critical-error handler:

```
CDR101: Not ready reading drive D
Abort, Retry, Fail?
```

and the machine blocks on a character that no automated caller is going
to send. The keyboard path was demonstrably working when the probe
started — the screen showed `CD C:\FSTEST` and `PRUN.BAT` typed and
executed — and by the time `F` was sent, the path no longer carried
keystrokes. No keyboard means no warm reboot, **so it cost a mains cycle
on thirty-year-old parts that this campaign is deliberately not thermal
cycling.**

Three things, in increasing order of what they would have saved:

**Never issue a media-touching command against a removable device
without a guard.** On DOS that means `VOL`, `DIR`, and anything else
reaching the drive. Set `INT 24h` to fail, or enumerate drives from a
source that does not touch media. A command that can block forever on a
prompt is not read-only, whatever it reads.

**The answer was already free in the boot banner.** MSCDEX prints
`Drive D: = Driver OPTICAL unit 0` during init, and the screen-capture
tool this workflow already uses reads it. **A passive witness that the
system emits on its own is strictly better than a probe that asks** —
it costs nothing, it cannot wedge anything, and it is available before
you think to ask. Check what the machine already tells you before
writing a command to make it tell you.

The sharp form: **the most dangerous thing run that night was the
read-only cell** — because it touched a device the experiment does not
use, to answer a question that had already been answered.

**And the check order saved a misdiagnosis.** `verify_input` returned
`verified: false` / "no LED change" — the documented post-FTP
keyboard-hang signature, exactly — and that answer was in hand *before*
anyone took a screenshot. The documented order is lock/activity → chord
window → **both capture channels** → verify-input, and the capture step
is third because it is the one carrying the information. Following it
turned "the known fault recurred" into "my own command wedged it."

That also makes the LED reading **a symptom rather than a diagnosis**:
at an `INT 24h` prompt with a driver retrying, the BIOS keyboard path may
not service LED commands at all. The failure was real, reproducible, and
identical to a known fault — and it was **caused by the state, not the
cause of it.** See `### A confirmed cause is not necessarily the
operative cause` above; this is the second instance in one campaign.

### A transform applied for comparison must never reach the artifact

A machine's `CONFIG.SYS` was fetched so a modified copy could be pushed
back. The fetch came through a text path that **doubled newlines**, so
the file was normalised to make it diffable against a reference — and it
diffed clean, which is how the fetch was confirmed authentic.

The file then staged for the push was **LF-only, 1,307 bytes, zero
carriage returns.** The normalisation had done its job and then followed
the data into the artifact. Caught at the staging check; re-staged at
1,349 bytes with 42 CRLF pairs.

The rule "push back the bytes the machine gave you" was already written
down and was being followed in intent. What defeated it is that **the
bytes in hand were no longer the bytes the machine gave** — a transform
had silently replaced them one step earlier, for a legitimate purpose, in
a different part of the workflow.

**Keep the verbatim fetch and the normalised copy as two separate
files, and write from the verbatim one.** Never normalise in place. A
comparison needs a canonical form; an artifact needs the original bytes;
the moment those are the same file, the first requirement quietly
overwrites the second.

**And assert the property you are about to rely on, at the point of
use** — here, a byte count and a CRLF count immediately before staging.
A diff that passes proves the content matches under the transform, which
is precisely the property that says nothing about the bytes.

Worth knowing why this one was caught: **a boot file is the one place a
line-ending difference is not cosmetic**, so the staging check was being
read carefully. The same leak into a log path or a data file would have
passed unremarked — so the guard belongs in the workflow, not in the
operator's attention.

### An absence needs one control per way of being silent

A cell whose informative outcome is **presence** needs one control: did
the thing you are looking for have a chance to appear. A cell whose
informative outcome is **absence** needs one control **for every way the
run could have gone quiet without meaning anything** — because all of
them produce the same output as the finding.

A device-comparison cell — does this stall happen on a different medium —
accumulated four guards before it was safe to run, each blocking a
different route to the same clean, quiet, zero-exit false result:

| guard | the false absence it blocks |
|---|---|
| arms matched on **elapsed time**, not bytes | an arm too fast to contain one period. The RAM-disk arm as first written covered **0.06 of one** |
| the original medium's arm as a **positive control** | the write pattern having killed the phenomenon, leaving two silent arms that cannot be told apart |
| a **not-scorable duration floor** | an arm too short to contain an event, landing as a verdict instead of as nothing |
| **bytes-written asserted against bytes-attempted** | an arm that never wrote. `fwrite` to a full DOS volume returns short rather than failing, so the loop completes in good time and reports zero |

Four is not over-engineering. **It is the count of distinct ways that
particular run could be quiet**, and every one of them was live: the
first was a real defect in the design, and the fourth was a real
possibility given a 2 MB disk taking 25-50 MB of writes through a wrap.

**Before running any cell whose useful answer is "it did not happen",
enumerate the ways it could fail to happen for uninteresting reasons and
write a guard for each.** Then check that each guard **voids** rather
than scores — "not scorable" and "absent" must be different outputs, or
the guard has only moved the problem.

The tell that you need this discipline: **you cannot distinguish your
success case from your failure case by looking at the output.** When
that is true, no amount of care in reading the result will help, because
the reading is not where the information was lost.

### The command was right; the quantifier was wrong

A campaign needed a RAM disk driver. Someone ran `DIR C:\DOS\*.SYS`, read
one file in the output, and reported: **there is no `RAMDRIVE.SYS` on
this machine.** The cell was declared blocked and a licensing question
was about to be escalated to the operator.

`RAMDRIVE.SYS` was in `C:\WINDOWS`. A whole-volume search found
**eighteen `.SYS` files across eight directories**. And the inference was
available from evidence already in hand — `AUTOEXEC.BAT` loads
`C:\WINDOWS\SMARTDRV.EXE`, a file that had been fetched, verified and
quoted an hour earlier, and Windows 3.x ships `RAMDRIVE.SYS` beside it.

**Nothing went wrong with the command or with reading it.** The command
was correct, the output was correct, the reading was correct. What failed
was the **scope of the claim**: evidence about one directory was reported
as a fact about the machine. `DIR C:\DOS\*.SYS` cannot return a statement
about `C:\`, and no amount of care in running it makes it able to.

This is the sibling of `### State the denominator and population before
comparing two figures`, applied to search rather than arithmetic, and it
is more dangerous because **a correct result carries no signal that your
claim is wider than it is.** A bad measurement eventually contradicts
something. A sound observation stretched past its scope agrees with
everything, including the things it does not cover.

**Write the scope into the claim, in the same breath as the evidence:**
"no `RAMDRIVE.SYS` *in `C:\DOS`*" is a true sentence that invites the
next search; "no `RAMDRIVE.SYS` on the machine" is a false one that ends
it. When the conclusion is about to block work or trigger an escalation,
**re-read the command that produced it and ask what population it
actually sampled.**

### Relaxing a gate after seeing the data: the one test that separates the cases

Sooner or later a pre-registered gate fails on a run you believe is
sound, and you will want to relax it. Usually that is rationalisation.
Occasionally the gate is simply wrong. **One question separates them:
would the relaxation have been made if the result had gone the other
way?**

Two cases from one campaign, hours apart:

**Legitimate.** A host-side gate required exactly four status tables to
prove four stages ran. A correct run emits **six**, because each of the
two toggle commands prints one too. The gate was counting the wrong
thing — **it would have voided every correct run, including a failing
one** — and the six-table figure was derivable from the toggle's
documented behaviour before the cell was ever run. Relaxed, and the
stage count was carried instead by a stronger check that had also been
pre-registered. A gate that voids every correct run is **broken, not
strict**.

**Not legitimate.** A fit missed its pre-registered threshold, and
dropping one point brought it to a pass by 0.0045. The point was chosen
*after* seeing which one spoiled the fit, and nothing recommended the
drop except that it passed. Refused.

The asymmetry is **independent falsifiability**, not the quality of the
reasoning. The first gate's defect can be demonstrated from the
instrument's specification with the results still sealed; the second
cannot be argued at all without looking at the answer. **Write the
justification and check whether it survives with the outcome column
covered up.** If it does not, you are negotiating, not correcting.

And declare it either way. The relaxation above was announced up front,
before the verdicts it enabled — which is what let it be audited instead
of discovered.

### Excluding a noisy statistic from a test excludes it from scrutiny

A cell's event counts swung 2x across identical configurations, so
counts were deliberately excluded from every verdict and every stability
bar — correctly, since a statistic that noisy cannot carry a conclusion.

The four arms then returned **6, 7, 8, 15** events, in stage order,
strictly increasing, with the lever explaining none of it. Nobody
noticed, because the one statistic set aside as unreliable was also the
one nobody was looking at. It surfaced only because a reader went
through the raw numbers that no test consumed.

(The trend did not survive — checked against every comparable run on
disk, the counts at cumulative-bytes zero were 7, 10, 14, 11 and 6,
bracketing the whole within-run range, so the intermittency account
stood and the ordering stayed a 1-in-24 oddity. **The lesson is about
the examination, not the outcome.**)

**Excluding a statistic from a test is a decision about verdicts, not
about attention.** When you set one aside, say so explicitly and put its
raw values in the report anyway, unscored and labelled as such. The cost
of the exclusion is that nothing will flag a pattern in it — so
something has to look on purpose.

### Do not let an instrument divide by a number it cannot trust

A probe printed a summary line of the form `RATE = one event per N
bytes`. Across three runs of one configuration it reported **56,228,
39,360 and 28,114** — a 2x swing with nothing varied, because the event
count in the numerator came from a detector with intermittent
sensitivity, a property nobody knew it had.

The division is what did the damage. `events=7 bytes=393,600` invites the
question "is seven all of them?". `RATE = one event per 56,228 bytes`
does not — it is a single authoritative-looking figure with its
unreliable input dissolved into it, **printed by the instrument itself,
which lent it the instrument's credibility.** It was read and reasoned
from three times, and it contributed an argument to killing a hypothesis
family before the intermittency was discovered.

**Print the inputs, not the ratio, whenever an input's reliability is
unestablished.** A derived figure is a claim that its terms are sound; an
instrument that emits one is making that claim on your behalf, in a
format that survives being copied into a summary long after the caveat is
forgotten. If a ratio genuinely helps, print it *next to* both terms,
never instead of them.

The broader form, and the reason this belongs with the decomposition
rules above: **an instrument's output is an argument, and an instrument
that computes is an instrument that can be wrong in ways reading it
cannot reveal.** Keep arithmetic in the analysis, where it can be
re-derived and audited, rather than in the probe, where it arrives
pre-concluded.

### Voiding a cell invalidates its comparison, not its observations

The same run that exposed the delimiter bug was declared void — it had
executed one arm of a four-arm design. It was then mined anyway, and it
produced the third point of the 7 / 10 / 14 detection spread and the
2.7% figure that calibrated a threshold for the next cell.

**A void verdict attaches to the question the cell was built to answer,
not to every observation inside it.** The truncated run still executed a
complete, valid configuration identical to two earlier ones; what it
could not do was compare. Before discarding a failed cell, ask which of
its observations stand on their own — a baseline, a noise figure, an
identity witness, a constant measured in passing. They cost nothing to
extract and they were paid for already.

The caution that goes with it: **extract only what does not depend on the
broken part**, and say in writing which part that is. A cell voided for a
truncated sequence can still report what its one executed stage did; it
cannot report anything that needed the stages that never ran.

### A value that travels through a shell must be audited against THAT shell

A multi-stage probe took its stage list in one environment variable,
`|`-separated. It arrived truncated at the first stage:

```
FSPROBE_SEQ=SMARTDRV /S|SMARTDRV C- ;SMARTDRV /S|...
                        ^ everything from here silently lost
```

The probe ran stage one, swept once, and exited zero. **A complete,
internally consistent, entirely plausible single-arm result, with no
error anywhere in it** — from a cell that was supposed to run four arms.
Nothing in the output announces the three missing stages.

**This entry then went through a wrong diagnosis, a wrong withdrawal of
that diagnosis, and finally a measurement. All three are kept, because
the sequence is the lesson.**

**The diagnosis:** COMMAND.COM reads `|` as a pipe. It fit instance one,
so it shipped as mechanism. **The withdrawal:** the separator was changed
to `#`, the identical truncation happened, and nothing reads `#` as
anything — so one mechanism did not explain both instances, and the
diagnosis was retracted.

**Then somebody finally sent the characters through and read them back:**

| sent at that position | arrived |
|---|---|
| `\|` | **truncated** |
| `>` | **truncated** |
| `%` | **silently stripped, rest intact** |
| `#` | intact — twice, including the exact failing string |
| `;` `^` `&` `,` space, plain, 100 chars | intact |

**The pipe diagnosis was right and the withdrawal was wrong.** The
withdrawal rested on "`#` was eaten", which was *inferred from a run that
truncated* and never tested — **the identical error to the one it was
correcting**, committed while writing the entry warning against it.

Four things to take:

**A withdrawal is a claim and needs evidence like any other.** Retracting
is a virtue in a culture that over-defends, and it becomes its own bias
the moment retraction is the move that signals rigour. Here a correct
finding was deleted from this file on the strength of an untested
inference.

**"One mechanism must explain every instance" survived intact — the
input to it did not.** The rule was applied correctly to a
mis-observation. A sound rule fed bad data produces a confident wrong
answer, and the rule cannot warn you about that.

**Test the mechanism directly instead of inferring it from the failure.**
Two cells were voided and three explanations argued over a question that
one echo-back probe answered in one run. The probe cost less than any of
the arguments.

**Stripping and truncation are different failures, and a presence check
sees neither difference.** `%` arrived with the character silently
removed and everything after it intact. An instrument asking "did the
value arrive?" passes that. Compare **byte for byte against what was
sent**.

Also worth recording: `>` truncates as hard as `|` and was on nobody's
candidate list, while `#`, already convicted, was innocent. **The
plausible member of an alphabet set the prior and the prior was wrong in
both directions at once.**

Two rules on the original bug, and the second is the one that cost a cell
to learn.

**Remove the structure from the value rather than re-encoding it.** After
two delimiters were eaten by a layer nobody could name, the fix was one
environment variable per stage plus a declared count. Separate variables
cannot truncate into each other, a missing one is visible *as* missing,
and — the point — **this is correct whether or not the mangling is ever
explained.** A delimiter is a guess about every parser in the path;
separate variables are a guess about none of them. Pair it with a
self-describing count: have the caller pass the number of elements it
intends and the program refuse to run on a mismatch, printing what it
received. Truncation and absence produce identical output, exactly as in
`### A counter reading zero must distinguish "false" from "never ran"`,
and only an explicit expectation separates them.

**One mechanism has to explain every instance, or none of them is
established.** This hub already carries that rule for measurements. Here
it was violated for a *diagnosis*: a satisfying story for instance one,
written down as mechanism, and never revisited. A diagnosis is a claim
like any other and is owed the same second instance — **"it fit" is not
"it was tested."** (The irony recorded above: the story turned out to be
correct, and the second instance that appeared to refute it was itself
never tested. The rule was right, the observation fed to it was not.)

**RESOLVED, and the answer was in the probe's own source.** A nested
`strtok`:

```c
for (stage = strtok(buf, "#"); stage; stage = strtok(NULL, "#")) {
    run_cmds(stage, ...);        /* which itself does: */
        for (tok = strtok(buf2, ";"); tok; tok = strtok(NULL, ";"))
```

**`strtok` keeps one global state pointer, and the inner loop destroys
the outer loop's.** The outer `strtok(NULL, "#")` returns NULL on
iteration two, so the run ends after stage one — with the environment
value fully intact in memory the entire time.

It accounts for every observation at once: the `#` run (value fine, loop
terminated), the `|` run (truncated by the pipe **and** ended by the
nested `strtok`), and the later cell working, because the replacement
took a counted `for` loop over `getenv` with no `strtok` in it. **The
delimiter-safety fix removed the real bug as a side effect**, which is
why the cell suddenly worked and why nobody could see what had changed.

Three things worth more than the bug:

**A confirmed cause is not necessarily the operative cause.** The pipe
truncation was real, measured directly, and **irrelevant to the
outcome** — the `strtok` bug produced the identical result with a
perfectly intact value. Reinstating the pipe diagnosis on measurement
was correct, and it still explained nothing about why the cell failed. A
verified mechanism can be a bystander; **check that your cause is
load-bearing, not merely present.**

**Suspect your own new code before the infrastructure.** Two hypotheses
were argued at length — the environment transit, then a stale staged
binary — and both were about long-standing shared machinery. The defect
was in the freshly written probe, the one component with no history of
working. It was never suspected precisely because its author had just
read it.

**Read the harness before hypothesising about it.** The stale-binary
hypothesis was dead before it was raised: the runner already did a
`stage-file` / `send-file` sha round trip and printed "all files verified
byte-for-byte". One read of an existing script would have retired a
hypothesis that instead got argued across two messages. This is the same
failure as reasoning about `#` without testing `#`, one layer up.

**What was previously recorded here as unexplained:** `#` survives transit,
so that cell truncated for some other reason — and splitting the value on
`#` gives four stages while splitting on `|` gives one stage of three
`;`-separated commands, where what actually ran was one command and one
sweep. Neither. **A mechanism that explains one failure does not retire
the other**, and the residue here is a live, narrower question rather
than a closed one.

### Read the machine's own configuration before probing the device

Five cells were spent varying record size, position, operation count and
timing against a periodic write stall, testing five mechanism families
and killing all five. Nobody had read the machine's `CONFIG.SYS` and
`AUTOEXEC.BAT`.

When it was finally read -- as a side errand, while fetching a file for
an unrelated restore -- the first line that mattered was a **resident
disk cache hooking INT 13h**, sitting between the program and the media,
matching every surviving observation, and belonging to a layer none of
the five probes could distinguish from the media itself.

**The configuration is the candidate list.** A stall, a periodicity, an
unexplained cost on a device path is produced by *something that is
loaded*, and what is loaded is written down on the machine in a file
anyone can read in a minute. Probing the device without that list means
inventing hypotheses about a stack whose contents are unknown -- which is
how a search comes to test "FAT cluster boundary" and "rate per device
byte" before it tests "the cache that is actually installed."

**Do this at campaign open, not at hypothesis five.** Enumerate the
residents, the drivers, the caches and the TSRs, and keep the list beside
the measured-constants table. It costs one read, it is authoritative
rather than inferred, and it turns an open-ended search into a bounded
one.

Two riders learned in the same hour. **Read the target's own copy, not a
sibling repository's** -- a configuration reconstructed from elsewhere
may be right, and you will not know which, and that is the same
provenance failure as quoting a figure measured on another fixture. Use
the sibling copy to *ask* the question and the machine's copy to answer
it. And **record the numeric settings while you are there** (`BUFFERS=`,
`FILES=`, cache sizes): a later follow-up then starts from "change this
from 20" instead of "find out what it is", and the values themselves
carry evidence -- a `BUFFERS=20` is 10 KB, which made a periodic flush in
the DOS filesystem layer less plausible and a resident cache below it
more so, before either had been tested.

### Name the layers a negative result actually clears, before you run it

An elimination test's value is entirely in its branch labels, and those
labels are written by whoever designs the cell — usually in a hurry,
usually in one line, and nobody re-reads them once a number exists.

A test swapped a CF card for a RAM disk to locate a stall. The branches
as first written: **"no spikes = the CF media; spikes = DOS or the BIOS
above it."** Both halves were wrong in the same direction. A RAM disk
driver plugs into the DOS block-device layer, so it bypasses the driver
below it, INT 13h, the controller *and* the media — **four candidates,
not one.** And the BIOS sits *below* DOS, not above, so the second branch
named the wrong follow-up.

The first label is the dangerous one: it is the branch that lets the
investigation stop, and as written it would have retired three live
candidates by wording alone, in a report nobody would have re-derived.

**Write the layer stack out and mark which rows the swap replaces, before
the cell runs.** A test does not eliminate "the hardware" or "the OS" —
it eliminates a contiguous span of a stack, and the span is a fact about
the substitution you made, not about the component you had in mind. This
is `### State the denominator and population before comparing two
figures` applied to elimination rather than to arithmetic: **say what
population each branch clears, in writing, before the branch is taken.**

Its companion, from the same design: **a proxy for "different" is not
"different".** The cell verified a different *volume* via cluster
geometry, while the hypothesis was about a physical erase block — and a
second partition on the same card would have passed that check while
sharing every erase block it was meant to rule out. **Assert the property
the hypothesis is actually about**, not a correlate of it that happens to
be easy to read.

### Kill a hypothesis with a measurement, not with a pattern

Five mechanism families for one stall were tested against pre-registered
criteria and all five failed. Four of those failures were **pattern**
failures — a fit that did not hold, a count that did not match — and
every one of them stayed arguable, because a pattern can fail for want of
resolution, for a confound, or for a detector that missed half the events
(as two of them did, above).

The fifth was different. Halving the record size while holding everything
else constant moved the period **28,000 -> 19,778 bytes, a 29% swing on
the one coordinate a byte counter cannot vary by definition.** Nothing
about that needs a fit, a threshold, or an assumption about the detector.

**When a family has survived several pattern tests, stop designing better
patterns and find the coordinate the mechanism is forbidden to move.**
Vary it directly and read the answer. One such cell is worth more than
the next three refinements of a fit, and it is the only kind of result
that closes a family rather than wounding it.

**Its companion: measure the conversion constant in the same run.** The
prediction here required a per-record cost to convert a time period into
a record count. The 800-byte run measured 6,419 us; assuming the
400-byte run would be half of that (or the same) would have produced a
wrong prediction either way — it came back **5,244.9 us**, neither. The
probe measured it in-run, so the prediction was evaluated against the
measured value. **A constant carried across the very change under test
is an assumption wearing a number's clothes.**

### Check for multiple populations before taking a mean

A mean over a mixture distribution describes no member of it, and the
mixture is usually invisible in the summary that hides it.

A campaign measured 41 frames that had overrun their budget and reported
9.1% of their time in rendering — a figure that would have sent the next
week at the wrong subsystem. Split by size, the population was two things
that barely overlap: **37 ordinary frames averaging 79 ms, 85.8% render
and literally 0% script or events**, and **4 outliers averaging 8,790 ms,
98.9% events**. Four monsters drowned 37 ordinary frames, and the
aggregate described neither. The correct conclusion — that the everyday
tail is render-bound — is the *opposite* of what the aggregate implied.

The same campaign hit it once already, on a dirty-check cost that was
bimodal by construction: a full buffer scan when frames matched, an early
exit when they differed, ~0.60 ms against ~0.15, averaged into a figure
that described neither case and misdirected an investigation for two
rounds.

**So before averaging a set of measurements, ask what distinguishes its
members** — size, outcome, code path taken — and report the populations
separately with their own counts. A bimodal cost with a 4x or 100x ratio
between modes is common in this domain, not exotic: skip-versus-do,
hit-versus-miss, and fast-path-versus-slow-path all produce it.

### Assert every derived figure against its own physical bounds

Instruments need plausibility floors; so does the *analysis* built on
them. In one campaign day three separate tools emitted plausible-shaped
wrong numbers, and the only thing that caught the worst of them was that
it happened to be ridiculous rather than merely wrong: a gate figure
computed at **107 ticks/s on a 40 Hz pacer**, because two excluded
intervals overlapped and the subtraction removed **80% of the run's wall
clock**.

Two assertions would have caught it before it printed, and neither needs
to know the right answer: **excluded intervals must be disjoint**, and
**a figure computed by exclusion must report what fraction of the whole
it removed**, refusing or flagging above a threshold. More generally, a
rate above what the pacer can produce, a share above 100%, or excluded
time exceeding elapsed time are all impossible regardless of the
question being asked. **Assert bounds at the point of computation** —
relying on someone noticing an absurd number is relying on the error
being large, and the dangerous ones are the ones that are not.

### "Clocked to wall time" does not mean "external"

A recurring cost that reproduces against the clock rather than against
work looks conclusively like something outside your program — a timer, a
watchdog, driver housekeeping, an interrupt. **Anything inside your
program that grows steadily with wall time produces exactly the same
signature.**

A campaign measured a ~250 ms stall recurring at the *same wall-clock
times* across four independent runs — **3 ms of spread on an event 121
seconds in**, with the tick index at that moment varying between runs
while the clock time did not. Both sessions concluded the cause had to be
external, since "nothing in an engine is clocked to wall time", and spent
a round looking at TSRs, packet drivers, DPMI housekeeping and SMIs.

It was **the log file reaching a particular byte offset**. The log grew at
a steady rate, so it reached that offset at a fixed wall-clock moment, and
something about writing there cost ~220 ms. Two runs on different binaries
hit it at 16,103→16,861 and 16,141→16,899 — same flush, same tick. **The
reproducibility that made it look external was just how deterministic the
writing was.**

(The mechanism first proposed for *what* is expensive at that offset — a
FAT cluster allocation — was **falsified**: the volume's clusters are 32 KB
and the logs never reached 32,768 at all. That retraction is its own
lesson and does not touch this one. **The point here is that an internal
quantity growing at a steady rate reproduces against the clock**,
whatever is waiting for it at the far end.)

**So when periodicity points outside the program, enumerate the internal
quantities that grow with time before accepting it** — log and trace file
sizes, allocation counts, buffer fills, anything monotonic. And note the
diagnostic that would have separated them sooner: an external timer fires
on a *constant* interval, while a growing quantity crossing evenly-spaced
boundaries fires on an interval set by its own growth rate, which changes
when you change how much it writes.

### A parked observation ages against the tree — re-confirm before designing around it

An anomaly you deferred is a fact about the binary it was seen on. By the
time you come back to it, that binary may not exist.

One campaign parked a recurring stall recorded as "deterministic at ticks
603 and 1807". Returning to it five patch series later, the stalls were
still there and the indices were **803 and 2407**. The determinism was
real; its *values* were a property of the old build. A probe armed at the
recorded indices — the obvious design, and the one both sessions had
independently planned, since known indices lift the usual cost constraint
on instrumentation — would have caught nothing and read as the
phenomenon having vanished.

**Re-confirm a parked observation on the current tree before designing
any work around it**, and prefer a confirmation that is also useful:
here, re-running the gate's own cells both re-measured the stalls and
answered whether the gate had closed on other changes in the meantime.
That campaign hit this four times; each cost a round spent instrumenting
something that had moved or gone.

A corollary worth stating separately: **when an index or threshold shifts
between builds, the shift is data.** In this case the two pairs satisfied
the same exact relation, which pointed at a mechanism that neither pair
alone suggested.

### An addressable saving is not the term's cost

Measuring what something costs today tells you what it costs today. It
does not tell you what removing it saves, because part of it is usually
structural.

A campaign measured 1,201 ms of file I/O in a benchmark run, traced it to
a script re-opening its log file eight times, and projected the whole
1,201 ms as the saving. **Two of the eight opens were irreducible** — the
log's own single open, and a config read — so the real saving was 900 ms.
The difference decided whether a gate cleared by 1.0x its noise spread or
2.8x, which is the difference between a coin toss and a claim, and four
hardware cells were about to be spent on the wrong one.

**So predict and measure the post-fix residual, not just the pre-fix
total.** What caught this was counting the opens *after* the fix rather
than assuming the count would be zero — a single field, checked instead
of assumed. Before quoting a saving, state what will remain and then
verify it.

This is a cousin of the residual error in the next entry and not the same
one: there the phantom quantity was invented by subtraction, here a real
measured quantity was assumed to be entirely removable.

### A residual is not a term -- subtraction is not measurement

Taking a total, subtracting the terms you have measured, and treating the
remainder as a thing that exists somewhere is not instrumentation. It
produces a phantom with a plausible size, and the enclosing function's
*name* then supplies a plausible location for it. Both halves are
invented.

Two instances in one campaign day, by two different sessions, hours
apart. A coordinator subtracted two known terms from a frame budget,
announced "17 ms unattributed", and commissioned a search for it -- the
brackets nested, so the arithmetic was meaningless and there was no hole.
A worker subtracted a measured sub-term from its parent, attributed the
~4.4 ms remainder to the part of the function whose name matched, and
sent a well-reasoned hypothesis after a term that did not exist; the real
cost was 60% of the parent sitting somewhere else entirely, and the
measured figure for the named part was 10%.

**Measure the term you intend to reason about.** Where a residual is
genuinely useful is as an error bar -- "our brackets account for 91.6% of
the frame" is a statement about instrument coverage, not a discovery of
an 8.4% component. And before subtracting anything, check whether the
brackets nest: a bracket that totals more than the run cannot be additive
with its children.

### A note you wrote yourself is not evidence

The same campaign spent a day repeatedly finding that the answer was
already in its own logs. The mirror-image failure is worse and arrived
the same day: a bracket comment written months earlier asserted that a
given code path did not touch the back buffer, was believed, and was
wrong -- nobody had followed the call chain past the first line. The term
it mislabelled turned out to be the second-largest in the frame, with
the engine's *own* author comment sitting directly above the call saying
it can take up to 50% of game CPU at high resolutions and colour depths.

Treat a comment, a plan entry, or a prior conclusion as **a hypothesis
with your handwriting on it**. Records are for finding things you already
measured; they are not a substitute for reading the code when the claim
is about what the code does.

**The sharper version arrived a round later, and it is about inferences
minutes old rather than notes months old.** A clean A/B had correctly
falsified one explanation and narrowed the cause to two candidates. The
more interesting candidate was written into the record as *the* cause,
propagated to a second session, and used to justify a design change.
Splitting one counter showed it was the other candidate entirely -- and
the dull one, an unclipped rectangle, was worth 417 frames going to
3,253 once fixed. **Freshness feels like evidence and is not.** When a
result leaves two candidates standing, the next line of code should
discriminate between them, not pick one.

### A diagnostic must reset on the same cadence as the metric it explains

A "why" field cleared by a per-frame reset, annotating counters that
accumulate across a run, reads empty forever. In one campaign that
combination printed `reason="-"` for 2,124 consecutive frames while
someone tried to work out why an optimization had stopped engaging.
Check the lifetime of an explanatory field against the lifetime of the
number it explains, or the explanation is guaranteed to be absent exactly
when it is needed.

### A number that CONFIRMS your prior gets less scrutiny -- reverse that

The most dangerous figure in an investigation is the one that agrees with
what you already believe, because it is the one that ends the
investigation. A contradicting number gets checked; a confirming number
gets acted on.

Worked example from one campaign. A term was suspected of being
efficient. Its cost came out at "0.70 ms per sprite, about 2.3
cycles/pixel -- a fast masked copy," which confirmed the suspicion and
would have closed the question with "the code is fine, move on." The
sprite dimension in that calculation had been **invented, not measured**.
Measured, the sprites were a fifth the assumed area and the real figure
was **19.4 cycles/pixel -- wrong by 8x, in the reassuring direction.**

The correction mattered beyond the number. "The code is efficient"
invites micro-optimization; "the memory is saturated" says only fewer
bytes or fewer passes can help. Those send the next week somewhere
different.

Two habits follow. **Check every quantity in a calculation that you did
not measure**, especially the ones sitting quietly in a denominator --
and note that fixing one does not immunise the next: in the same
investigation the replacement conclusion rested on an inferred *stream
count* in the numerator, one round after an invented dimension in the
denominator. And **invert the arithmetic as a routine test**: compute
backwards from the measured time to the implied quantity, and check that
against something known. Here, 0.70 ms at the machine's measured memory
bandwidth implied a 77x77 sprite, which visibly contradicted the assumed
100x200 -- the contradiction was available without any new instrument.

### A cross-port finding tested with a broken instrument is worse than one never read

The hub carries findings between ports so the next one does not pay
twice. That only works if the test applied to a borrowed finding is
sound — and **a false negative on someone else's correct result actively
removes a true lead**, where simply not reading it would have left the
lead open.

One campaign hit this twice on the same `HARDWARE.md` row. The row
described a multi-hundred-millisecond flush stall on a different card,
narrowed by that port to one mechanism, with the one-variable test
written down and never run. The borrowing session read it, instrumented
the named guard, got zeros, and reported the mechanism falsified. The
guard sites were in a code branch that port never executes — **the test
never ran**, and a correct lead spent a round dead before the retraction.

**So when testing a borrowed finding, verify the test applies to your
path before trusting its result** — the other port's mechanism lives in
their configuration, and yours may reach the same symptom by a different
route. And when a borrowed lead comes back negative, hold it to the same
standard as a positive: **a negative that would close a cross-port lead
deserves the confirmation you would demand of a claim.**

Worth noting what the hub got right here anyway: the same row named the
instrument the borrowing port eventually needed — a four-phase bracket
another port had already built behind a hint, for this exact symptom.
**Reading the hub was correct both times; only the testing was wrong.**

### Never edit a shell script while an instance of it is running

Bash reads a script incrementally, by byte offset, as it executes. A
length-changing edit to a file a running instance has not finished
reading does not fail cleanly — **execution resumes at an offset that now
points into different text, and runs whatever happens to be there.**

A campaign edited its hardware-runner script while four cells were
invoking it. The error was caught inside a minute and the file reverted
to its exact prior bytes — **and the running cell died anyway, `rc=127`**,
having resumed at an offset that landed in the middle of an embedded
Python heredoc roughly a thousand lines from where it had been.

**Two corrections that make this worse than it first appears, both
learned the hard way after this entry was first written.**

**Reverting is not a remedy.** The running process had already taken its
new offset; restoring the original bytes changed nothing for it. Once the
edit lands, the in-flight instance is committed to whatever it is going
to do.

**"Still running" is not "unaffected".** The first check performed was
that the cell was still executing, and it was — right up until it wasn't.
Liveness says nothing about integrity here. **Verify the exit code and
the completeness of the output**, not that the process exists.

This one survived on luck: the corruption surfaced in the *collection
verification* step, after the file fetch had already returned, so the
data sat recoverable in the daemon's pulled store and was rescued by hash
before the next cell cleared it. Landing a few hundred lines earlier
would have produced the worst class available — **a corrupted run that
still looks like a run**.

**Stage edits to harness scripts and apply them between runs**, never
during. Keep the modified version somewhere else — a scratchpad copy —
and move it into place when nothing is executing. If a change is urgent
enough to feel worth doing live, that urgency is itself the signal to
wait: the cost of waiting is minutes, and the cost of the alternative is
a lost cell at best.

### Audit the harness's fetch list against every file the program writes

An instrument that records faithfully into a file nobody collects is
indistinguishable from an instrument that does not exist — and it fails
silently, because nothing errors and no log is short.

A campaign spent six hypotheses and several days on a recurring stall it
could not locate. The decisive four-phase bracket had been written by
**another port, years earlier, for this exact symptom** — unconditional,
always on, writing to `LOGS\<TAG>SDL.LOG`. The harness's collection step
had never fetched that filename. **The instrument had been recording on
every cell of the campaign and been read on none of them.** The fix was
one line in the run batch and one name in a fetch list.

This is worse than the more common "the answer was already in a log
nobody re-read", because there was no log to re-read: the data was
generated, written, and discarded at collection time. **Enumerate what
the program writes and diff it against what the harness fetches**, as a
standing check rather than a one-off — and treat any file the program
produces but the harness ignores as either a collection bug or an
instrument that should be deleted.

### Grep the cell you already have before designing a new one

That last clause deserves its own standing: in a single campaign day, the
answer was already on disk **four separate times** -- a gating constraint
recorded in the team's own prior ABBA notes, a set of bandwidth-probe
figures that refuted an exotic theory about a copy's cost, repaint counts
that settled a hypothesis without a new cell, and finally a stall
breakdown showing **61% of a run's wall time inside 19 ticks**, sitting in
a log collected an hour earlier. That last one redirected the entire
remaining plan.

"The data was already there" cost that campaign more rounds than any
wrong hypothesis did, and it is a cheaper failure to fix: a structured
per-run log (see `runmanifest-log.md`) is only worth what someone reads
out of it. **Before designing a cell, grep the last one for the quantity
you are about to go measure.**

The same habit applies to a metric's definition, not just its values.
Before doing arithmetic on a rate, **read what its clock is anchored
to.** Two sessions in that campaign confidently attributed a 25-point
whole-run gap to startup and load; the metric's denominator began *after*
engine init and game-data load, and the entire pre-loop turned out to be
0.9% of the run. A phase-by-phase instrumentation of startup was one
decision away from being commissioned on the project's most expensive
fixture.

## When a batch of cells fails, run a known-good binary BETWEEN the failures

"My change broke it" and "the harness had a transient" are
indistinguishable from a failing cell's output alone, and a run of
consecutive failures makes the first explanation feel overwhelming. It
is not evidence. **Interleave a previously-working binary and see
whether it also fails.** If it reproduces its own earlier figure, the
change is exonerated and the fault is in the harness, the transfer, or
the machine.

A real campaign hit four consecutive collection failures -- stage
directories holding only a send witness, target idle at a prompt, input
verified working -- with a plausible common cause sitting right there in
the one thing that had changed. A known-good binary run in between
succeeded at *exactly* its previous value, and the supposedly-broken
binary later produced a clean result. The transient was never explained.
Without the interleave, the available conclusion was "binaries built this
way don't run on hardware," which was false and would have deleted a
confirmed 1.20 fps win.

Two details that make it work: the control has to be a binary with a
**known prior figure**, so "it ran" can be upgraded to "it reproduced";
and it has to run **between** the failures rather than before or after
the batch, or it cannot distinguish a transient from a state change that
began partway through. Record an unexplained transient as unexplained --
a later recurrence should be recognised, not re-diagnosed from scratch.

## A conjunction counter says nothing about either conjunct

A counter that increments on `A && B` cannot support a claim about `A`
alone or `B` alone. This sounds obvious written down and is very easy to
violate in practice, because the counter's *name* usually mentions only
one of the conditions. A real example: `presents_palette_only` counts
presents where the frames were equal AND the palette changed. Two people
investigating the same regression both reasoned from it to a conclusion
about the palette flag by itself -- one to rule a code path out, one to
argue it stayed open -- and both were wrong. It took a direct probe on the
flag alone (`palchg true=2 of 1000`) to settle a question two people had
already reasoned about confidently and in opposite directions.

Zero on a conjunction counter is the trap-shaped case: it is consistent
with `A` never being true, with `B` never being true, and with both being
frequently true but never simultaneously. **When a hypothesis turns on how
often one condition holds, instrument that condition directly.** A
one-line counter on the conjunct is cheaper than either the argument or
the wrong conclusion, and this whole hub's "attest, don't recall"
invariant applies to a fact about your own program's control flow exactly
as it does to a fact about the hardware.

## One mechanism per measured build

Shipping more than one new mechanism in the same measured binary makes
per-mechanism attribution impossible the moment a regression shows up --
correlated mechanisms can return the identical number for every arm of a
killswitch matrix, and untangling which one actually caused an effect
after the fact costs far more than a single-lever ship would have. One
new mechanism per build; multiple ablation *cells* around that one
mechanism (default-off, killswitch-on, an alternate value) are
encouraged, not a violation -- that's a proper ablation matrix, not a
second mechanism. Pure instrumentation, banners, and probes riding along
don't count as a mechanism either. This rule exists because a real
improvement was banked, shipped default-on based on a result that looked
solid, and did not reproduce -- the discipline is the direct answer to
that incident, not a hypothetical precaution.

## Any automated step that SELECTS an artifact needs a cheap identity check

A script that picks which commit, patch level, or binary to build is
making a claim about identity, and a loose selector will make that claim
confidently and wrongly. A real bisect script's commit-matching regex also
matched an unrelated `dos: ` subject line, so it silently checked out the
wrong patch level when asked for a specific one. It was caught only
because an unrelated cheap assertion -- a patch count on the checked-out
tree -- failed; nobody noticed the wrong checkout by reading the output.

Two things follow. First, **pin selection to something that cannot
ambiguously match**: read the SHA from the patch file's own `From` line
rather than pattern-matching a subject. Second, **carry a cheap invariant
alongside the selection** (a patch count, a file that must exist at that
revision, an expected `build_sha12`), because the failure mode here is
silent -- a mis-selected artifact produces a complete, plausible, entirely
wrong result set, and a bisect is exactly the procedure where one wrong
data point sends the whole conclusion to the wrong commit. This is the
"attest, don't recall" invariant applied to the *input* side of a
measurement rather than its output.

A related auditability trap from the same campaign: folding working-tree
dirt into a build fingerprint fixes stamp collisions between dirty builds,
but if it is folded in *unconditionally* it also makes every historical
fingerprint unreproducible, so an old result can no longer be tied to a
build. Fold dirt in only when the tree is actually dirty -- a clean build
must still reproduce its stamp, or you have traded one attribution problem
for a worse one.

## An emulator is a correctness instrument, not a performance proxy

Where an emulator and real hardware disagree, real hardware wins, full
stop -- and the disagreement is not small or predictable. Measured
scaling between emulated and real-hardware timings of the *same* code
path, in the *same* binary and scene, ranged from 0.81x to 286x depending
on which code path was being measured. This is not "the emulator is
uniformly slower" or "uniformly faster" -- some code paths it barely
represents at all (a whole path it never models realistically runs
unrealistically fast), others it represents faithfully enough to be
dramatically slower per instruction than real silicon. Use an emulator
for *qualitative* ranking (which bracket of the code dominates cost) and
correctness/logic verification, never for absolute numbers or
cross-environment comparison -- `dos-emulator-workflow`'s
`local-benchmarking.md` covers the practical version of this rule.

A subtler failure mode from the same gap: **a green smoke-test pass in an
emulator only proves the code paths the emulator actually reached
executed cleanly** -- a device whose emulated behavior diverges from real
hardware (an emulated sound chip that "succeeds" a reset sequence real
hardware would fail, for instance) can silently route the smoke test
through a safe fallback branch instead of the risky real-hardware-I/O
path it was meant to exercise. "9/9 smoke cells passed" can quietly mean
"9/9 of the safe branches the emulator's own fallback took," while the
actual risky path freezes on first contact with real hardware. Before
trusting an emulator smoke pass for anything touching real port writes,
IRQ handling, or DMA, confirm the log shows the *risky* path actually
fired -- not just that nothing crashed.

## Fault handling

A retry is fine; a retry silently presented as if it were the first
attempt is not -- record retries as retries. A hung cell should be
reported as a hole in the data, never silently retried into a substitute
result: a round with a known, disclosed gap is worth more than one with
an undisclosed substitution. Classify a timeout from a rolling window of
observations, not a single frame -- a genuine wedge, a slow loading
stage, and a stage that's rendering nothing at all can be indistinguishable
in one still image, and become obvious over tens of seconds of history.
If a capture mechanism repeats frames to preserve timing across a gap, it
holds more frames than were actually captured -- report both the
captured count and the held/repeated count; the difference between them
*is* the stall structure, which is usually exactly what a stall
investigation is trying to measure.

## Archive, never delete, when clearing a collection directory

Clearing a collection/log directory before a run (to avoid the stale-
artifact-from-a-prior-run hazard this file already covers under
"declared vs. detected") must move the old contents aside, not remove
them -- the clearing step is itself part of a run's provenance chain, and
applying it destructively to the very artifacts you're trying to keep
provenance for is self-defeating. Concrete incident: correctly-archived
DOS-side artifacts survived a cleanup pass, but the harness runner's own
stdout log was deleted in the same pass under the same "clean up before
next run" reasoning -- and that log was the only recording of the actual
failure mode under investigation (a stall detector reporting false
"activity" for several minutes against a dead capture -- the same
mechanism as this file's "a watch can be blind to its own event"
section). This applies to the collection directory, the runner's own
stdout, and any capture file named after a fixed tag rather than a
run-unique one (which silently overwrites every prior poll under that
tag).

## What a project needs to emit to be drivable at all

Five requirements, in the order they matter:

1. **A bounded, observable run.** A fixed-length run with a detectable
   end. Fully deterministic (recorded input, fixed seed, fixed
   termination) is the strongest form; a scripted demo plus a hard
   termination cap is an acceptable, cheaper substitute that buys the
   bound without buying full determinism. Expect this to require real
   engine changes -- it gates everything else on this list.
2. **One schema-versioned, machine-readable manifest record at exit**,
   carrying build identity and headline metrics. This is RUNMANIFEST's
   actual justification -- see `runmanifest-log.md` and
   `shared/include/runmanifest.h`.
3. **Start and end banners.** Often a harness's only reliable progress
   signal when nothing else is instrumented yet.
4. **Decomposed metrics**, per the section above -- a single number that
   conflates distinct costs is worse than two numbers that don't.
5. **File-based configuration** that can be shipped and diffed, with
   documented precedence against any env-var overrides.

Plus the two-witness rule already referenced elsewhere in this hub's
skills: a string embedded in a binary (`strings | grep`) proves
compilation, never execution -- dead code keeps its string literals too.
Only a runtime log line, captured from an actual run, proves the code
path fired.
