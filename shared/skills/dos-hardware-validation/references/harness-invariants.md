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

**A campaign believed for one round that exactly this had happened to
it** — that 94% of a 7.53-second engine event was its own
`debug_script_log` calls, enabled by default in both its emulator and
hardware runners and therefore present in every measurement it had ever
taken. It reached the operator as a retraction of a major finding before
the next measurement showed the belief was false: the logging was **1.9
milliseconds** across all nine dispatches, and the 38.4 seconds belonged
to the engine call the bracket had accidentally swallowed. (That
sub-episode is its own lesson — see the scope-bug and halt-condition
entries below.)

So the worked example is a false alarm, and the rule stands on its logic
rather than on that story: **a bracket-set diff compares two binaries and
therefore cannot see anything present in both.** Overhead that every run
carries is invisible to it by construction, and the failure mode is
silent — every figure is consistently wrong in the same direction, which
is precisely what a differential check is blind to.

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
