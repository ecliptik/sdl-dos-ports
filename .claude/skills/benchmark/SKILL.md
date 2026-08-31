---
name: benchmark
description: >
  Running or recording a real-hardware performance KPI campaign for a DOS
  port -- writing a falsifiable KPI, picking team shape, and following
  the investigation/coordination discipline a real campaign converged on.
  Use this whenever asked to benchmark, optimize toward a target fps, run
  a real-hardware performance campaign, or record a benchmark result --
  not for a single one-off sanity check (see dos-hardware-validation for
  that) or for correctness/compatibility testing (see dos-realhw-
  verification).
---

# Running a real-hardware performance campaign

Full playbook: `docs/SHEPHERDING-GUIDE.md`'s "Performance campaign"
section. This skill is the tight checklist version; follow the links for
full rationale and worked examples.

## 1. Confirm you're actually compute-bound

Measure real per-frame work against the frame budget the target implies
before touching anything. Slack (work comfortably under budget) means a
pacing problem, needing `docs/timing.md`'s pacer material, not the
bottleneck list in `docs/optimization.md`. Re-check this every new pass —
a port's regime can change between campaigns.

## 2. Write the KPI down before chasing it

Real-hardware only, percentile-based (`fps_p50`/`fps_p95` via
`shared/include/runmanifest.h`, not a single average), falsifiable in
advance (what result means fail, not just pass), attributed to a named
`build_sha12`. See `docs/optimization.md`'s "Setting a performance KPI".

## 3. Pick team shape

Solo + subagents for a one-off check. Once you're doing genuine iterative
real-hardware investigation: one investigating session + one dedicated
rig-operator session, peer-to-peer. See `shared/agents/README.md`.

## 4. Start a measured-constants table

A section in the port's `PLAN.md` (template in `templates/PORT-PLAN.md`).
Every number a probe produces goes in immediately; every new hypothesis
gets checked against it before a new probe runs.

## 5. Investigate: instrument the suspect directly, not its neighbors

When there's a specific unexplained quantity, instrument the code that
directly produces it before instrumenting adjacent systems. State what
would falsify each hypothesis before spending rig time on it. See
`dos-hardware-validation`'s corresponding sections.

## 6. Rig discipline, every round, no exceptions under pressure

Hash-verify a staged binary before staging *and* after sending. Pair
every self-reported metric with an independent bracket, unprompted. Never
trust a summary number without an internal cross-check. The rig session
investigates ambiguity with its own tools before reporting anything as a
game-side symptom. See `dos-hardware-validation`.

## 7. Confirm a fix against the KPI itself, not the metric it targeted

A change can verifiably move the intermediate quantity it was designed to
influence and still not move the KPI — confirm the actual target metric
moved before crediting the fix. See `docs/optimization.md`'s
stalls-vs-tightening finding for a real case.

## 8. Record the result

`templates/BENCHMARK.md` for a single result; `gallery/<name>/` once a
port is showcase-ready. If a temporary diagnostic patch was landed in
`shared/` to get here, land its removal too (see the `review` skill) —
don't leave it as a silent tax on every port that pins past it.

## Land a shared/ patch that came out of this?

Use the `review` skill before committing it.
