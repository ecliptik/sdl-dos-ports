#!/usr/bin/env bash
# sync-skills.sh -- symlink any shared/skills/ entry a port repo doesn't
# have yet into its own .claude/skills/.
#
# scripts/new-port.sh does this once, at scaffold time. A port repo
# scaffolded before a new skill was added to shared/skills/ (e.g.
# `review`, `benchmark`) has no way to pick it up automatically -- this
# script closes that gap. Safe to re-run any time; only creates symlinks
# that don't already exist and never touches a real (non-symlink) file
# or directory a port may have deliberately substituted.
#
# Usage (from a port repo's own root, with .sdl-dos-ports/ as the
# submodule):
#   .sdl-dos-ports/shared/scripts/sync-skills.sh

set -euo pipefail

REPO_ROOT="${SDL_DOS_PORT_ROOT:-$PWD}"
HUB_SKILLS="$REPO_ROOT/.sdl-dos-ports/shared/skills"
PORT_SKILLS="$REPO_ROOT/.claude/skills"

log() { printf '[sync-skills] %s\n' "$*" >&2; }

if [[ ! -d "$HUB_SKILLS" ]]; then
    log "error: $HUB_SKILLS not found -- is .sdl-dos-ports/ the hub submodule, checked out?"
    exit 1
fi

mkdir -p "$PORT_SKILLS"

added=0
skipped=0
for skill_dir in "$HUB_SKILLS"/*/; do
    skill_name="$(basename "$skill_dir")"
    target="$PORT_SKILLS/$skill_name"
    link_dest="../../.sdl-dos-ports/shared/skills/$skill_name"

    if [[ -L "$target" ]]; then
        current="$(readlink "$target")"
        if [[ "$current" == "$link_dest" ]]; then
            skipped=$((skipped + 1))
            continue
        fi
        log "warning: $target is a symlink to something else ($current) -- leaving it alone"
        skipped=$((skipped + 1))
        continue
    elif [[ -e "$target" ]]; then
        log "warning: $target exists and is not a symlink (a deliberate copy?) -- leaving it alone"
        skipped=$((skipped + 1))
        continue
    fi

    ln -s "$link_dest" "$target"
    log "linked: .claude/skills/$skill_name -> $link_dest"
    added=$((added + 1))
done

log "done: $added new symlink(s), $skipped already present or intentionally different"
