# Skill templates

Genericized Claude Code skills, same adoption model as `shared/agents/`
(see its own `README.md`): these are process templates distilled from real
campaign experience on one port, stripped of that port's specific numbers
and names, meant to be copied (or symlinked) into a port repo's own
`.claude/skills/` rather than invoked from inside this hub repo directly.

A skill here only helps if a port actually has it wired up locally --
this hub is a source of truth for the *content*, not a place these run
from day to day.

| Skill | What it covers | Reusable as-is vs. needs a per-port fill-in |
|---|---|---|
| `dos-hardware-validation/` | Running a real-hardware validation or A/B benchmark campaign on a vcctrl-controlled rig: design-before-run discipline, populate/verify, per-cell set/forbid/expect_log witnessing, RUNMANIFEST-driven metrics, ABBA methodology, bug-vs-workaround discipline, raw-data handoffs | Reusable close to as-is -- the harness protocol and methodology are port-agnostic. Fill in your own RUNMANIFEST field names/env-var names if you don't reuse `DOS_PORT_*` (see `docs/patch-conventions.md`'s naming-debt note), and your own vcctrl profile per `templates/vcctrl-profile.yaml.template` |

## Adopting a skill into a port repo

```sh
mkdir -p .claude/skills
ln -s ../.sdl-dos-ports/shared/skills/dos-hardware-validation .claude/skills/dos-hardware-validation
```

Symlinking (rather than copying) keeps the skill in sync with this hub the
same way `patches/SDL` and the vendor scripts do -- see
`plans/DOSKUTSU-MIGRATION-PLAN.md` for the precedent and its one caveat:
anything that enumerates files by walking a symlinked directory needs `-L`
(GNU `find`) or the equivalent, or it silently sees nothing. Copying
instead of symlinking is fine too if a port wants to diverge (e.g. fill in
port-specific RUNMANIFEST field names inline rather than parameterizing) --
same tradeoff as the agent charter templates: copy-and-fill-in loses the
free sync, symlink-and-parameterize keeps it.

## Provenance

`dos-hardware-validation/` was distilled from a real multi-hour real-hardware
session validating doskutsu on the vcctrl rig (Gateway 2000 / POD-83,
ATI Mach64) during doskutsu's `shared/` submodule migration -- an 8-cell
ABBA fps campaign plus four real harness bugs found and fixed along the way.
Port-specific details (doskutsu's own env var names, the specific fps
numbers, the specific bugs) were stripped the same way the agent charter
templates strip doskutsu's wave-by-wave findings -- see `shared/agents/README.md`'s
framing. The underlying discipline is what's shared; the campaign history
belongs to whichever port lived it.
