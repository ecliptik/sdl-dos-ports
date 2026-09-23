#!/usr/bin/env bash
# dosbox-run.sh -- run a DOS executable under DOSBox-X and capture its stdout.
#
# Headless mode (the common case): stages the exe + any --include files into
# a temp C:\, writes a RUN.BAT that invokes the exe with stdout redirected to
# STDOUT.TXT, runs DOSBox-X with `-silent -exit`, and copies STDOUT.TXT out.
#
# AUDIO: under `-silent` DOSBox-X's emulated Sound Blaster does not answer at
# all (DSP reads 0xFF, no IRQ ever fires). The default mode therefore sets
# SDL_DOS_AUDIO_SB_SKIP_DETECTION=1 so audio init still "succeeds" -- but the
# device never plays: any audio figure from a default-mode run is mixer-side
# only. Pass --sb-live for a run where the SB really plays (no -silent, a
# private Xvfb display, host audio to SDL's dummy driver, detection ON exactly
# as on real hardware). Proven 2026-09-22 with the hub's AUDOPEN probe and
# dosags DSPV1-3: -silent -> 0xFF / 0 IRQs; no -silent -> dsp_ver=4, IRQ-5
# firing, with or without skip-detection, on both shipped confs.
#
# Typical use:
#   tools/dosbox-run.sh --exe build/hello.exe --stdout /tmp/hello.out
#   tools/dosbox-run.sh --exe build/hello.exe --fast
#
# Interactive mode (opens the window -- prefer dosbox-launch.sh for playtest):
#   tools/dosbox-run.sh --exe build/hello.exe --interactive
#
# DOS has no LFN support. Filenames passed via --include are staged to C:\
# with uppercased basenames; the exe is also uppercased. If you need the
# exe to reference other files, they must be 8.3 and on C:\.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_PARITY="${SCRIPT_DIR}/dosbox-x.conf"
CONF_FAST="${SCRIPT_DIR}/dosbox-x-fast.conf"

EXE=""
ARGS=""
STDOUT_PATH=""
INTERACTIVE=0
INCLUDES=()
KEEP_STAGE=0
FAST=0
CONF_OVERRIDE=""
ENVS=() # --env KEY=VALUE, repeatable -- see usage below
# --merge-stderr: capture stderr too (e.g. SDL_Log goes there). DOSBox-X / DOS shells
# don't always honor `2>&1` cleanly -- prefer printf-to-stdout in tests where possible.
MERGE_STDERR=0
SB_LIVE=0 # --sb-live: emulated SB really plays (see header)
CWSDPMI="${CWSDPMI:-$SCRIPT_DIR/../vendor/cwsdpmi/cwsdpmi.exe}"

usage() {
  cat <<'USAGE'
Usage: dosbox-run.sh --exe PATH [--args "..."] [--stdout PATH] [--include PATH]...
                     [--fast | --conf PATH] [--interactive] [--keep-stage] [--merge-stderr]
                     [--sb-live]

  --exe PATH         DOS executable to run (required). Basename is placed at C:\.
  --args "..."       Arguments passed to the exe (quoted as a single string).
  --stdout PATH      Where to copy captured stdout. Default: stream to host stdout.
  --include PATH     Additional file to stage into C:\ (repeatable). If CWSDPMI
                     is present at vendor/cwsdpmi/cwsdpmi.exe it is auto-included.
  --fast             Use dosbox-x-fast.conf (cycles=max) instead of parity config.
  --conf PATH        Use an arbitrary DOSBox-X conf instead of either shipped one.
                     Mutually exclusive with --fast (say which conf you mean).
                     The two shipped confs deliberately set oplmode=none, so a
                     port validating a MIDI backend under DOSBox-X (dosags's
                     Sound gate needed oplmode=opl3 for OPL3 chip detection)
                     previously had to stage a scratch conf and hand-run this
                     script; that conf now lives in the port's own tree and is
                     passed here. Same staging/RUN.BAT/exit behavior otherwise --
                     this only changes which file lands on `-conf`.
  --interactive      Open the DOSBox-X window instead of running headless.
  --keep-stage       Leave the staging temp dir on exit (useful for debugging).
  --merge-stderr     Capture both stdout and stderr (>STDOUT.TXT 2>&1). Needed for
                     programs that log to stderr (e.g. SDL_Log on DJGPP). DJGPP's
                     runtime processes 2>&1 itself so the syntax works under DOS.
  --env KEY=VALUE    SET KEY=VALUE in RUN.BAT before invoking the exe (repeatable).
                     This is how to reach an SDL_HINT_* value from this script --
                     SDL_GetHint() falls back to getenv() for anything never
                     SDL_SetHint()'d in code, and RUN.BAT's SET is a real DOS
                     environment variable the exe's own getenv() sees, exactly
                     like this script's own hardcoded BLASTER/
                     SDL_DOS_AUDIO_SB_SKIP_DETECTION lines below. Previously a
                     real gap (dosags S5 WaveBlaster validation had to stage
                     RUN.BAT by hand for exactly this); mirrors tests/harness/
                     run-rig.sh's own --env flag (real-hardware side) for the
                     DOSBox-X side.
  --sb-live          Run with DOSBox-X's Sound Blaster actually playing: drop
                     `-silent` (which disables the emulated SB outright), run
                     under a private `xvfb-run -a` display (or DOSBOX_DISPLAY if
                     set), send host audio to SDL_AUDIODRIVER=dummy unless set,
                     and do NOT set SDL_DOS_AUDIO_SB_SKIP_DETECTION, so SB
                     detection runs as it does on real hardware. Use it for any
                     run whose audio figures (IRQ counts, ring fill, clip timing)
                     should mean something. Clip timing becomes device-paced, so
                     a run that waits on sounds is no longer tick-deterministic
                     across two runs -- keep screen-equality A/B rows sound-off.
  -h, --help         Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --exe)         EXE="$2"; shift 2 ;;
    --args)        ARGS="$2"; shift 2 ;;
    --stdout)      STDOUT_PATH="$2"; shift 2 ;;
    --include)     INCLUDES+=("$2"); shift 2 ;;
    --fast)        FAST=1; shift ;;
    --conf)        CONF_OVERRIDE="$2"; shift 2 ;;
    --interactive) INTERACTIVE=1; shift ;;
    --keep-stage)  KEEP_STAGE=1; shift ;;
    --merge-stderr) MERGE_STDERR=1; shift ;;
    --env)         ENVS+=("$2"); shift 2 ;;
    --sb-live)     SB_LIVE=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "dosbox-run.sh: unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -n "${CONF_OVERRIDE:-}" && "$FAST" == "1" ]]; then
  echo "dosbox-run.sh: --conf and --fast are mutually exclusive (pass the conf you actually want)" >&2
  exit 2
fi
if [[ -n "${CONF_OVERRIDE:-}" ]]; then
  CONF="$CONF_OVERRIDE"
elif [[ "$FAST" == "1" ]]; then
  CONF="$CONF_FAST"
else
  CONF="$CONF_PARITY"
fi

if [[ -z "$EXE" ]]; then
  echo "dosbox-run.sh: --exe is required" >&2
  usage; exit 2
fi
if [[ ! -f "$EXE" ]]; then
  echo "dosbox-run.sh: exe not found: $EXE" >&2
  exit 2
fi
if [[ ! -f "$CONF" ]]; then
  echo "dosbox-run.sh: conf not found: $CONF" >&2
  exit 2
fi
for e in "${ENVS[@]:-}"; do
  [[ -z "$e" ]] && continue
  if [[ "$e" != *=* ]]; then
    echo "dosbox-run.sh: --env expects KEY=VALUE, got: $e" >&2
    exit 2
  fi
done

# Stage ---------------------------------------------------------------------
STAGE="$(mktemp -d -t dos-port-dosbox.XXXXXX)"
cleanup() {
  if [[ "$KEEP_STAGE" == "1" ]]; then
    echo "dosbox-run.sh: stage kept at $STAGE" >&2
  else
    rm -rf "$STAGE"
  fi
}
trap cleanup EXIT

cp "$EXE" "$STAGE/"
EXE_BASENAME="$(basename "$EXE")"
EXE_DOSNAME="${EXE_BASENAME^^}"

# Auto-include cwsdpmi.exe if vendored. DJGPP binaries need it; the hello
# smoke test doesn't strictly, but having it in the stage costs nothing.
if [[ -f "$CWSDPMI" && ! " ${INCLUDES[*]:-} " =~ [[:space:]]"$CWSDPMI"[[:space:]] ]]; then
  INCLUDES+=("$CWSDPMI")
fi

for f in "${INCLUDES[@]:-}"; do
  [[ -z "$f" ]] && continue
  if [[ ! -f "$f" ]]; then
    echo "dosbox-run.sh: --include not found: $f" >&2
    exit 2
  fi
  # DOS uppercases at runtime; uppercase here so the RUN.BAT references match.
  dest_name="$(basename "$f" | tr '[:lower:]' '[:upper:]')"
  cp "$f" "$STAGE/$dest_name"
done

# RUN.BAT -- invokes the exe with stdout captured to STDOUT.TXT.
# With --merge-stderr we add `2>&1` so SDL_Log (and any stderr writer) is also
# captured. DJGPP's runtime parses argv-level redirection itself, so 2>&1 works
# under DOS even though MS-DOS COMMAND.COM proper doesn't support it natively.
if [[ "$MERGE_STDERR" == "1" ]]; then
  REDIR='> STDOUT.TXT 2>&1'
else
  REDIR='> STDOUT.TXT'
fi
case "${EXE_DOSNAME##*.}" in
  BAT|bat)
    INVOKE_LINE="$(printf 'COMMAND /C %s %s %s\r\n' "$EXE_DOSNAME" "$ARGS" "$REDIR")"
    ;;
  *)
    INVOKE_LINE="$(printf '%s %s %s\r\n' "$EXE_DOSNAME" "$ARGS" "$REDIR")"
    ;;
esac
{
  printf '@ECHO OFF\r\n'
  printf 'SET BLASTER=A220 I5 D1 H5 T6\r\n'
  # SDL_DOS_AUDIO_SB_SKIP_DETECTION -- escape hatch from patches/SDL/0001.
  # Needed ONLY because the default mode runs `-silent`, which switches the
  # emulated SB off (DSP reads 0xFF, no IRQ). CORRECTED 2026-09-22: this
  # comment used to say DOSBox-X's SB16 returns 0xFF "regardless of timing
  # tuning"; that was the -silent artifact -- without -silent detection passes
  # (dsp_ver=4). With skip set here the driver opens a device that never plays.
  # --sb-live leaves it unset. Real hardware MUST NOT set it (it would mask a
  # real card-detection failure).
  if [[ "$SB_LIVE" != "1" ]]; then
    printf 'SET SDL_DOS_AUDIO_SB_SKIP_DETECTION=1\r\n'
  fi
  for e in "${ENVS[@]:-}"; do
    [[ -z "$e" ]] && continue
    printf 'SET %s\r\n' "$e"
  done
  printf '%s' "$INVOKE_LINE"
} > "$STAGE/RUN.BAT"

# Invoke DOSBox-X -----------------------------------------------------------
DBX_ARGS=(-conf "$CONF" -nopromptfolder
          -c "MOUNT C $STAGE"
          -c "C:"
          -c "CALL RUN.BAT")

if [[ "$INTERACTIVE" == "1" ]]; then
  # Visible run -- user drives; don't auto-exit.
  export DISPLAY="${DOSBOX_DISPLAY:-:0}"
  dosbox-x "${DBX_ARGS[@]}"
elif [[ "$SB_LIVE" == "1" ]]; then
  # No -silent: it disables the emulated SB. Needs a display instead.
  DBX_ARGS+=(-c "EXIT" -exit -nogui -nomenu)
  export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-dummy}"
  if [[ -n "${DOSBOX_DISPLAY:-}" ]]; then
    DISPLAY="$DOSBOX_DISPLAY" dosbox-x "${DBX_ARGS[@]}" >/dev/null 2>&1 || {
      rc=$?
      echo "dosbox-run.sh: dosbox-x exited non-zero ($rc)" >&2
      exit $rc
    }
  else
    if ! command -v xvfb-run >/dev/null 2>&1; then
      echo "dosbox-run.sh: --sb-live needs xvfb-run (or DOSBOX_DISPLAY set)" >&2
      exit 2
    fi
    xvfb-run -a dosbox-x "${DBX_ARGS[@]}" >/dev/null 2>&1 || {
      rc=$?
      echo "dosbox-run.sh: dosbox-x exited non-zero ($rc)" >&2
      exit $rc
    }
  fi
else
  DBX_ARGS+=(-c "EXIT" -silent -exit -nogui -nomenu)
  dosbox-x "${DBX_ARGS[@]}" >/dev/null 2>&1 || {
    rc=$?
    echo "dosbox-run.sh: dosbox-x exited non-zero ($rc)" >&2
    exit $rc
  }
fi

# Deliver captured stdout ---------------------------------------------------
OUT="$STAGE/STDOUT.TXT"
if [[ -f "$OUT" ]]; then
  if [[ -n "$STDOUT_PATH" ]]; then
    cp "$OUT" "$STDOUT_PATH"
  else
    cat "$OUT"
  fi
else
  echo "dosbox-run.sh: no STDOUT.TXT produced (exe may have crashed under DPMI)" >&2
  exit 3
fi
