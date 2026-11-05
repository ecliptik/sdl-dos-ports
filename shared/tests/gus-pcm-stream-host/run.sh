#!/usr/bin/env bash
# run.sh -- build and run the gus_pcm_stream host test (exit 0 = pass).
# Compiles shared/audio/gus_pcm_stream.c + gus_dram_floor.c verbatim with the
# host C compiler (CC, default cc). No SDL, no DJGPP, no dependencies.
# AUDIO_DIR overrides the module location (e.g. to run against an older copy).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIO_DIR="${AUDIO_DIR:-$HERE/../../audio}"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
"${CC:-cc}" -std=c99 -O1 -Wall -Wextra -I"$AUDIO_DIR" -o "$OUT/gus_pcm_stream_test" \
    "$HERE/gus_pcm_stream_test.c" "$AUDIO_DIR/gus_pcm_stream.c" "$AUDIO_DIR/gus_dram_floor.c"
"$OUT/gus_pcm_stream_test"
