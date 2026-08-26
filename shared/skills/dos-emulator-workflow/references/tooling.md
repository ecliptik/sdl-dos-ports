# DOSBox-X tooling mechanics

Covers `shared/tools/dosbox-launch.sh`, `dosbox-run.sh`,
`dosbox-teardown.sh`, and the three `.conf` variants. All three scripts
are already fully generic (usable as-is by any port) -- this is a guide
to using them well, not a spec of what they do (read the scripts' own
`--help`/header comments for the authoritative flag list, which can
change).

## Picking a mode

- **Manual/visual work** (play-testing, screenshots, driving via
  `xdotool`, watching a bug happen): `dosbox-launch.sh`. It mounts and
  stays running; you drive it or watch it. `--stage` mounts
  `build/stage/` (the real install layout: exe + `CWSDPMI.EXE` + `data/`
  co-located) rather than the repo root -- use `--stage` for anything
  where the engine resolves assets relative to its own base path, which
  is most gameplay-adjacent testing.
- **Scripted/CI-style smoke checks** (does it boot, does the expected
  banner line show up, does it exit 0): `dosbox-run.sh`. Headless, stages
  one exe (+ `--include` files), captures stdout to a file, exits.

## The stdout-only logging convention, and why it exists

`dosbox-run.sh`'s headless capture works by redirecting stdout to a file
in a generated `RUN.BAT` (`> STDOUT.TXT`). If a probe or test logs via
something that writes to **stderr** (e.g. SDL's own `SDL_Log()`), that
output is invisible to this capture path *and there is no fix available
inside DOSBox-X's own shell*: DOSBox-X's built-in command interpreter
does not support `2>&1` redirection the way a real DOS `COMMAND.COM`-plus-
DJGPP-runtime combination does when a DJGPP binary is invoked directly --
DOSBox-X parses `2>&1` as a redirect to a file literally named `&1`,
producing an empty capture, not a merged stream. (`dosbox-run.sh`'s
`--merge-stderr` flag works around this differently -- it only helps for
a program whose *own runtime* processes the `2>&1` in its invocation
line, which DJGPP's does; it does not make DOSBox-X's shell itself
understand the syntax.)

**Practical rule: write any new probe/smoke-test diagnostic output via
`printf`/stdout, not a stderr-writing logger**, if it needs to be
captured by a headless DOSBox-X run. This is why `shared/tests/sdl3-smoke/`'s
own probe reimplements upstream SDL's test coverage with `printf()`
instead of using `SDL_Log()` directly -- not a style preference, a
capture-mechanism requirement.

## Env-var hooks on `dosbox-launch.sh`

- **`DOSBOX_CONF=<path>`** -- override which `.conf` is used, resolved
  against the repo root if relative. Applied after `--fast`/parity flag
  parsing, so it wins over both.
- **`LAUNCH_LOG_VERBOSE_VAR=<NAME>`** -- forces `SET <NAME>=1` in the
  guest so a port's own verbose-logging env var is on for this launch,
  letting a smoke-gate banner-emit check witness INFO-level banners even
  when the port's untagged-run default is a quieter level.
- **`LAUNCH_EXTRA_SET="NAME=VALUE ..."`** -- injects arbitrary additional
  `SET` commands into the guest environment, applied after the launcher's
  own fixed `SET`s so a caller can deliberately override one of them.
  This is the same mechanism `docs/hardware-testing.md` and
  `dos-hardware-validation/references/runmanifest-log.md` reference for
  setting a port's environment-detection override.

## The three `.conf` variants

- **`dosbox-x.conf`** (parity) -- calibrated to approximate a specific
  real reference machine's CPU throughput (`cycles=fixed <N>`), for
  anything where real-HW-equivalent *timing* matters even locally (audio
  dropout investigation, anything timing-sensitive enough that
  `cycles=max` would hide or fabricate a problem). The shipped file is
  one port's own calibration, explicitly not a universal setting --
  re-benchmark and re-calibrate `cycles`/`oplmode`/`memsize`/video for
  your own port's reference machine rather than assuming the checked-in
  number transfers.
- **`dosbox-x-fast.conf`** -- identical except `cycles=max`, runs as fast
  as the host CPU allows (several times faster than a real reference
  machine). Use for fast iteration where wall-clock timing doesn't
  matter -- most compile/video/input/filesystem work.
- **`dosbox-x-oversized.conf`** -- a variant for a specific display/video
  scenario (see the conf's own header for current specifics, which can
  change as it's tuned).

## Emulator-only escape hatches baked into the shipped confs

The shipped `dosbox-x*.conf` and `dosbox-run.sh`'s generated `RUN.BAT`
set `SDL_DOS_AUDIO_SB_SKIP_DETECTION=1` unconditionally. This exists
because DOSBox-X's emulated SB16 returns a fixed failure value on the DSP
detection read regardless of timing tuning, so without this env var,
SDL3-DOS's real-hardware-validated SB16 detection logic never succeeds
under emulation at all -- audio simply doesn't init. **This is an
emulator-only escape hatch.** See
`references/emulator-vs-hardware-boundary.md` for the general rule this
is an instance of, and why setting it on real hardware would actively
mask a real regression rather than just being redundant.

## The global-`pkill` hazard

`dosbox-teardown.sh` exists because a global `pkill -x dosbox-x` kills
*every* DOSBox-X process on the machine, not just the one a script
launched -- in a session with concurrent workstreams (a human reviewing a
build in one window, an automated smoke gate running in another), that
global kill has aborted a live, unrelated review more than once. Source
`dosbox-teardown.sh` and call `dbx_kill_conf "$CONF"` (conf-scoped,
comm-filtered so it can never self-kill the calling shell) instead of
reaching for `pkill` directly in any new script.
