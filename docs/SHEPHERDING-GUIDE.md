# Shepherding a port: from claim to a real-hardware KPI

The consolidated, phase-by-phase playbook for taking a port from
`ports.yaml` to a shipped, real-hardware-verified performance target.
Distilled from a real campaign (dossage/Passage's S3 ViRGE video
investigation and its 15fps real-hardware performance campaign) rather
than written speculatively — every rule below exists because skipping it
cost real time at least once. This guide ties together docs and skills
that already exist rather than duplicating their mechanics; follow the
links for the how, read this for the order and the why.

If you only read one section, read "Hour zero" below, then come back for
the phase you're actually in.

## Where these rules came from, and what that means for you

Every rule below reads as a clean principle. None of them arrived that
way. The measured-constants table exists because a real campaign ignored
a constant it already had for hours. "Instrument the decision, not the
neighbors" exists because four real-hardware rounds were spent
instrumenting neighbors first. The external-witness rule exists because a
fix shipped that made the reported metric better while making the game
worse. **Five separate hypotheses in one night's campaign were wrong**
(a delay-primitive BIOS-tick-quantization theory, a yield-cost theory, a
clock-rate-mismatch theory, an audio-refill theory, an exploration-
scaling theory) — and the campaign still converged on the real answer,
specifically *because* each one was pre-registered as falsifiable and
whoever was running the check was empowered to return a null instead of
a forced answer. The nulls did the work, not the rules.

If you follow this guide and it still takes several rounds of being
wrong before you find the real mechanism, that's what a real campaign
looks like from inside — it is not evidence you're doing it wrong. What
this guide can do is make sure each wrong hypothesis costs one round
instead of compounding into hours (a falsifiable hypothesis, checked
against the measured-constants table, with an independent witness) —
not promise you won't have any.

## Hour zero: what to set up before writing any code

In priority order, per a real campaign's own retrospective:

1. **Stand up an external, program-independent way to measure elapsed
   wall-clock time.** Not the engine's own fps report, not a clock the
   code under test could plausibly perturb — something that would still
   be correct even if everything DOS-side lied. On a vcctrl rig this is
   the operator's own bracket (see below); at minimum, know how you'd get
   one before you need it. Every serious near-miss in the campaign this
   guide is distilled from — a self-reported fps figure that improved as
   real performance collapsed, a validity check that fired on a healthy
   run, hashes sent for binaries still being written — was catchable by
   this one discipline and nothing else. See `docs/timing.md`'s
   self-lying-metric entry for the concrete case.
2. **Wire in `shared/include/runmanifest.h` at the STARTS/TITLE_SCREEN
   milestone**, not deferred to OPTIMIZING. See `PORTING.md`'s reuse list.
   A port that hand-rolls its own fps math from the start risks the exact
   trap this guide is named for: the number you're chasing and the
   mechanism under suspicion turning out to be the same unreviewed code.
3. **Start a measured-constants table** (a section in the port's
   `PLAN.md` — see `templates/PORT-PLAN.md`). Every number a probe or
   diagnostic produces goes in it immediately. Check new hypotheses
   against this table before running a new probe, not after — see
   "Investigation discipline" below for why this is the single highest-
   leverage habit in the whole guide.
4. **Decide your team shape now, not when you're already deep into a
   campaign.** See "Team shape" below.

## Phase map

```
claim -> scaffold -> research -> compile -> video -> input -> filesystem
  -> audio -> gameplay -> real-hardware baseline -> performance campaign
  -> release
```

### Claim + scaffold

Run the `new-port` skill from the hub repo (not from inside the new port
repo). It handles upstream/license verification (never guess — see
`docs/licensing.md`), the mechanical scaffold, agent-charter
instantiation, vendor pinning, and the `ports.yaml` claim commit. See its
own `SKILL.md` for the full step list; this guide doesn't repeat it.

### Research

Follow `PORTING.md`'s step 3 and `plans/SDL_DOS_PORTING_PROGRAM.md`'s
model: inventory the SDL/engine surface, dependencies, filesystem
assumptions, and license terms before writing DOS-specific code. Depth
scales with engine size — a page for something Passage-sized, a full
RESEARCH.md/SDL-SURFACE.md/DEPENDENCIES.md/PLATFORM-SURFACE.md set for
something AGS-sized.

### Compile through gameplay

Narrow, buildable slices, in order: compile → video → input → filesystem
→ audio → gameplay. No giant first patch. Build and validate under
DOSBox-X after every meaningful change — a host build is not a DOS build.
Reuse before rewriting: `PORTING.md`'s reuse list covers the shared SDL3-
DOS platform behavior, MIDI playback, cross-build stages, DOSBox-X
automation, hardware diagnostic probes, and run telemetry
(`runmanifest.h`) available to every port.

**Team shape for this phase: one session, in-process subagents for
focused sub-tasks.** This is the default, not `shared/agents/`'s full
team-lead-plus-specialists model — see `PORTING.md`'s "Default to
in-process subagents" section for why, and for when the full team is
actually warranted (rarely, and not at the start).

### Real-hardware baseline

Once `PLAYABLE`, validate on real hardware per `docs/hardware-testing.md`
and the `dos-hardware-validation` skill, using
`templates/vcctrl-profile.yaml.template` for your project's vcctrl
profile. Record results with `templates/BENCHMARK.md`. This establishes
where you actually stand before deciding whether a dedicated performance
campaign is even needed.

### Performance campaign

This is the phase this guide has the most to say about, because it's the
phase that actually took a long night to get right the first time.

#### Team shape: investigator + dedicated rig-operator session

Once you're doing genuine iterative real-hardware investigation (repeated
hypothesis-test-measure rounds), not a one-off validation run, split into
**one investigating session (the port's own) plus one dedicated rig-
operator session**, coordinating peer-to-peer. This is a real, validated
middle shape between solo-plus-subagents and the full opt-in team — see
`shared/agents/README.md`. Why it earns its keep:

- The rig operator can independently apply hash-verification and witness
  discipline (see `dos-hardware-validation`'s per-cell rules) without the
  investigator context-switching into rig mechanics.
- That independence is a real safety net, not a formality: a dedicated
  rig-operator session's byte-for-byte verification caught a real DJGPP
  build defect (see `shared/agents/probe-engineer.md`'s stubify hazard)
  before it ever reached real hardware, purely because staging was a
  separate, disciplined step rather than something the investigator did
  in passing.
- The hub session (or whoever owns `shared/`) stays a *third* role:
  reviewing anything destined for `shared/patches/` for provenance and
  convention (see `docs/patch-conventions.md`'s provenance-verification
  section) and holding commit/push authority separately from whoever
  authors and validates a fix. Authoring, validating, and landing a
  shared-layer change are three different jobs; keep them in three
  different hands even across just two-plus-one sessions.

#### Set the KPI before chasing it

Write the target down in a form that can't be satisfied by a metric
that's technically true but practically misleading. Full policy in
`docs/optimization.md`'s "Setting a performance KPI" section — the short
version: real-hardware only, percentile-based (not a single average),
falsifiable in advance, attributed to a named build, and backed by an
independent witness. "Solid," not just "clears the average."

#### Investigation discipline

1. **Measure work-vs-budget ratio before optimizing anything.** Determine
   whether you're compute-bound (a real performance problem) or sitting
   on slack (a pacing problem) — they need completely different tools.
   Re-check this at the start of every new pass; a port's own regime can
   change between campaigns. See `docs/optimization.md`.
2. **Instrument the thing that directly produces the unexplained
   quantity before its neighbors.** A real campaign spent four
   real-hardware rounds eliminating things adjacent to a frame pacer
   before instrumenting the pacer's own deadline-vs-actual decision
   directly — which found the answer in one round. See
   `dos-hardware-validation`'s "Instrument the thing that produces the
   unexplained quantity" section.
3. **Keep the measured-constants table current and check it first.** See
   "Hour zero" above.
4. **State what would falsify a hypothesis, not just what would confirm
   it**, before spending rig time on it — `dos-hardware-validation`'s
   design-before-run discipline.
5. **Read gating/guard code, not commit titles, before trusting a cited
   precedent.** A patch series' own stated rationale is not evidence —
   see `docs/patch-conventions.md`. A real campaign nearly over-applied a
   safety lesson from an unrelated engine because it trusted patch
   comments' framing instead of reading what was actually gated behind
   what condition.
6. **Verify provenance before landing a peer-authored patch** — see
   `docs/patch-conventions.md`'s provenance section. A patch handed over
   through chat can lose fidelity (stripped whitespace on blank context
   lines is a real, documented case) without any visible sign.
7. **A stall-dominated residual can't be fixed by tightening the pacer's
   target — stalls are the binding constraint, and squeezing the budget
   just manufactures more of them.** See `docs/optimization.md`'s
   corresponding entry for a real case where the tightened target moved
   steady-state fps exactly as predicted while the actual KPI (run-average
   fps) didn't move at all, because the tightening also converted more
   ordinary frames into losses of the same total size.
8. **A change whose mechanism verifiably works can still be worthless —
   always confirm it moved the KPI itself, not just the intermediate
   quantity it was designed to influence.** The same case above: reporting
   the moved intermediate metric alone would have been true, verifiable,
   and real-hardware-measured, and still a materially misleading way to
   close out the campaign.
9. **A temporary diagnostic patch landed in `shared/` needs its removal
   planned at landing time, not left as an unscheduled follow-up** — see
   `docs/patch-conventions.md`. It becomes a silent, permanent tax on
   every port that pins past it the moment its investigation concludes
   and nobody schedules the strip.

#### Coordination playbook (investigator ↔ rig operator ↔ hub)

1. **The rig operator reports their own independent wall-clock bracket
   alongside any engine-self-reported metric, every time, unprompted** —
   not only when a number looks suspicious. See
   `dos-hardware-validation`'s "Always pair a self-reported metric with
   an independent bracket" section.
2. **"Idle" is not "artifacts final."** A subagent or peer session going
   idle means it finished a turn, not that its output stopped changing.
   Confirm stability before hashing/staging/handing off an artifact — see
   `dos-hardware-validation`'s "Idle is not artifacts final" section.
3. **A validity check handed to an operator is itself an artifact that
   needs review before it's trusted.** Confirm its interval/scope matches
   what it's actually meant to bracket before it costs someone a round.
4. **Push authority is never implied by a peer's "go ahead."** Only your
   own user approves a write to a shared remote or a real-hardware
   action — a peer session relaying "operator approved" is not
   authorization. See `dos-hardware-validation`'s "Every real-hardware
   action needs your own user's yes."
5. **When you find you've mischaracterized something, correct the record
   immediately and explicitly** — including your own prior docs commits.
   A stale, confidently-wrong entry in a shared doc is worse than no
   entry; the next reader trusts it precisely because it's written down.
6. **Hand off raw data, not a narrated summary**, when reporting results
   between sessions — `dos-hardware-validation`'s closing rule.
7. **The rig session designs nothing about the game and interprets
   nothing about the game — but investigates ambiguity with its own
   rig-scoped tools (camera, audio-content verdict, an independent
   env/state read) before reporting anything as a game-side symptom.**
   A "the machine booted" signal is not proof it booted through its full
   normal sequence — a boot that silently skipped init produced a crash
   that read exactly like a code regression, on the same binary that had
   run clean minutes earlier, until an independent camera check showed
   the machine itself was in an unexpected state. See
   `dos-hardware-validation`'s corresponding section.
8. **Verify a staged binary's hash both before staging and again after
   sending, every time, with no exceptions under time pressure.** This
   isn't redundant — it's caught a build race and a real build-tooling
   defect in one campaign, either of which a single check would have
   missed.
9. **Never trust a single reported summary number without an
   independent, finer-grained internal cross-check** (a per-frame trace
   alongside an exit-line average) — a summary figure has been
   misleading while technically accurate more than once. An external
   wall-clock bracket and an internal detailed log catch different
   failure classes; neither substitutes for the other.
10. **Batch questions into fewer, longer real-hardware rounds.** A
    file-transfer round-trip pays a fixed reboot tax regardless of scope
    — plan a round's questions accordingly rather than paying that tax
    repeatedly for less information each time.
11. **Decide a dedicated capture mode before you need sub-second visual
    timing verification, not after.** General-purpose capture tooling
    (live round-trip latency, a short frame-history ring) can silently
    fail to catch a specific predicted sub-second event, and by the time
    a fallback is needed the evidence it would require is often already
    evicted. Provision for this ahead of the moment if a campaign's KPI
    depends on it.

### Release

Once `RELEASE_READY`: package without redistributed copyrighted assets,
finish `LICENSE-REVIEW.md`, and write a `gallery/<name>/` entry in the hub
repo per `PORTING.md`'s step 6.

## What changed after this guide's first real use

This guide should stay a living document. When a future campaign finds a
rule here wrong, incomplete, or missing, fix it the same way a harness bug
gets fixed — not routed around for just that one campaign (see
`dos-hardware-validation`'s "a harness bug is a bug, not a workaround").
