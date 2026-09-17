# The self-driving campaign loop

How to run a multi-day real-hardware campaign so the operator sets the
direction once and only has to step in for genuine decisions. Distilled
from dosags's 40fps push (2026-09-15..17): fps_p50 5.0 -> 34.6 on a
486DX2-66 through four pre-registered ABBA wins, several harness bugs
found and fixed, three of the coordinator's own claims retracted along
the way -- with the operator mostly watching. Every rule below is there
because its absence cost time in that campaign.

## Shape: one coordinator, one long-lived worker

- **Coordinator** (the session the operator talks to): owns the plan,
  the operator conversation, verification, and the hub repo. Never
  guesses at results; never edits a file the worker currently owns.
- **Worker** (one named, long-lived subagent/fork, resumed by name for
  the whole campaign): owns the port repo and drives the target machine
  itself. It accumulates the operational know-how (tags, transfer
  quirks, how long things take), so resume it rather than starting a
  fresh one; brief a fresh one only from the written plan.
- One worker at a time per port repo. Two agents in one working tree
  race on files and on git; parallel READ-ONLY research is fine.
- This is a subagent shape, not an agent team. Reach for the
  investigating-session + hardware-operator-session split in
  `shared/agents/` only when two humans-worth of attention is really
  needed.

## 1. Write the plan of record before spending hardware time

A dated section in the port's `PLAN.md` (skeleton in
`templates/PORT-PLAN.md`, "Campaign plan of record"). It must hold:

- **Gates**: what "done" means, as measurable statements on named
  hardware.
- **KPI definitions**: exactly which figure judges each gate, and what
  each figure does NOT show (static-screen fps, whole-run vs
  steady-state rates, what a stall is).
- **Operator decisions**, dated, in their words where possible.
- **Standing authorization and its scope** (see 2).
- **Work order**: phases and slices, each with its own gate.
- **Stated-in-advance honesty caveats**: what is probably out of reach
  and why -- and the evidence, so it can be challenged.

Build it from RAW logs, not from summaries of earlier work. Reviewing
the raw per-phase log is what showed that a headline fps number was a
static-screen figure and that a "correction" was itself wrong.

## 2. Get decisions up front, and scope the authorization

- Ask the operator's open questions in one batch, with a recommended
  option and the trade-off for each, through the structured question
  tool (it notifies their phone; a question buried in prose does not).
- Ask for **standing real-hardware authorization scoped to the plan**:
  power on/off, staging builds, running the plan's cells. Anything
  outside it (boot configuration, other software, anything unusual)
  still needs an explicit ask. Record the grant and its scope in the
  plan -- it is what lets the loop run unattended, and it is only valid
  because it came from the operator directly, never relayed.
- When a decision does not block the next slice, **dispatch the work
  first, then ask**. Never idle the hardware on a question whose answer
  only matters later.

## 3. Brief the worker so it does not hand back early

Every dispatch states: the slice(s), the design constraints, the
validation it must pass, **stop conditions decided in advance**, and
what to report. Chain the next slices in the same message ("if the
gates hold, continue straight into X and Y") so a clean result does not
cost a round-trip.

Stop conditions that worked: a pre-registered ABBA regresses; the
independent cross-check disagrees with the self-reported figure; a
correctness gate fails; anything looks wrong on the target machine; the
next step needs an operator choice. Otherwise: keep going.

Known frictions, and the instruction that fixes each:

- A worker tends to end its turn "waiting for a notification" during a
  long run, and nothing wakes it. Say so explicitly: poll internally on
  a fixed interval and return only on real completion, failure, or a
  decision. The coordinator should still expect to nudge occasionally
  (turn limits), and a nudge is one line: "check the current state and
  continue."
- A worker will keep adding one more probe forever. Bound each
  investigation ("this is the closing diagnostic round"), and when a
  guess-one-function loop stops converging, change the METHOD (exhaustive
  partition, a synthetic probe, a cheaper fixture) rather than approving
  another guess.
- Attribution, date, and tag conventions drift across a long run.
  Restate them in the dispatch when they change.

## 4. The slice recipe (performance work)

instrument -> source-grounded hypothesis -> write the prediction down ->
fix -> emulator correctness gate (screenshot hash identical, harness
green, game speed correct) -> pre-registered ABBA on real hardware
against the CURRENT baseline -> commit -> record in the plan.

- One mechanism per build, one commit per slice.
- Pre-register the threshold from the measured noise floor, and compare
  the result with the written prediction -- a 4x miss in either
  direction is a finding about the model, not a footnote.
- When a change touches the clock, the pacer, or the metric itself, add
  an independent witness (RTC, external wall clock) in the same slice.
- Develop on the fastest fixture that exercises the code path; return
  to the heavy one to confirm (`docs/optimization.md`).

## 5. Coordinator duties on every report

- **Verify before relaying**: the commits exist, the tree is clean, the
  machine is in the power state claimed. Then report, separating what
  was verified from what is the worker's account.
- **Read the numbers, not the adjectives.** Check a surprising claim
  against the trusted baseline it should reconcile with before acting
  on it; send it back if it was never reconciled.
- **When the operator says "is it stuck?", look yourself** -- both
  capture channels, power state, lock state -- then tell the worker
  exactly what you saw. Twice this caught a real fault (a dead input
  link; a run that had finished while the worker still waited) and
  twice it cleared a false alarm, all within a minute.
- **Retract in place, promptly, by name.** Mark the wrong section
  retracted with a pointer to the correction; do not delete history. A
  plan that records its own errors is one the operator can trust.
- **Fold durable findings back into the hub as they land** (`docs/`,
  `HARDWARE.md`), labelled proven or unproven. The coordinator owns the
  hub precisely so this never collides with the worker.
- Queue non-urgent instructions to a running worker rather than
  interrupting hardware actions mid-flight.

## 6. Getting back into the flow later

1. Read the port's plan of record and the memory note that points at
   it; confirm the standing authorization still applies to what you are
   about to do (it is scoped to that plan, not to the port forever).
2. Read the last RAW result log, not the last summary.
3. Check the target machine's state (power, lock, screen) before
   assuming anything.
4. Resume the named worker if it still exists; otherwise start one and
   have it read the plan section first.
5. Dispatch the next unchecked slice with stop conditions. Ask only
   what is genuinely undecided.
