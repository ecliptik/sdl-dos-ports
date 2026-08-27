# patches/sdl3-dos/

Local-only patches against `libsdl-org/SDL`'s DOS backend (the commit
pinned by whichever port repo's `vendor/sources.manifest` this is
consumed through). Carried over from doskutsu's `patches/SDL/`, which
proved this backend on real hardware across VESA/Cirrus/S3 video, SB16/
OPL2/OPL3/GUS/WaveBlaster audio, gameport joystick, and DPMI timing.

**These patches are not upstreamed** (project policy inherited from
doskutsu — freedom to patch without waiting on upstream review is worth
more here than upstream alignment; the cost is that every upstream sync
is on us). See `docs/patch-conventions.md` in the sdl-dos-ports hub for the
full convention (lexical `NNNN-*.patch` ordering, `git format-patch`
output, one concern per patch, subject explains *why DOS needs this* not
*what changed*).

Subject lines use the `[SDL3-DOS]` tag (renamed from doskutsu's original
`[DOSKUTSU]` tag during extraction into this shared repo).

## `_disabled/`

Patches that were tried and reverted/disabled during doskutsu's
development — kept as documented prior art (what was tried, why it didn't
work or wasn't kept) rather than deleted. Not applied by
`scripts/apply-patches.sh` in its default configuration.

## Known naming debt (not yet fixed)

Several patches introduce SDL hints, log-tag env vars, or extern
instrumentation symbols still named after doskutsu specifically —
`SDL_HINT_DOS_*`, `DOSKUTSU_LOG_TAG`, `doskutsu_audio_irq_count` and
similar. These are **functional identifiers baked into working,
hardware-validated code**, not just cosmetic strings — renaming them here
without also updating every consumer (doskutsu's own `patches/nxengine-evo/`,
its `setup/` utility, and its QA scripts) would break the wiring between
this patch series and the game-side code that reads these names.

A coordinated neutral rename (`SDL_HINT_DOS_*` -> `SDL_HINT_DOS_*`,
etc., per `docs/patch-conventions.md`) is tracked as part of doskutsu's own
migration to consume this repo via submodule (`plans/META-REPO-PLAN.md`
step 5), where both sides of each rename can be updated together and
re-validated. Until then, a new port consuming this patch series as-is
inherits these doskutsu-flavored names — that's functionally fine, just
not aesthetically neutral yet. Commit message bodies also retain
doskutsu-specific narrative (hardware names, wave/phase numbers) — left
in place because the underlying engineering rationale is still valuable
context for understanding *why* a patch exists, even where the specific
identifiers it names haven't been generalized yet.
