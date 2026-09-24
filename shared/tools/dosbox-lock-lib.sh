# shared/tools/dosbox-lock-lib.sh -- the host-wide DOSBox-X lock, as a
# SOURCED library (do not exec). Used by dosbox-run.sh and ratchet.sh; a
# port's own harness may source it too (resolve the path with readlink -f
# through the tools/ symlink, as dosbox-run.sh does).
#
# THE LOCK: flock on $DBXLOCK_FILE (default /tmp/dos-port-dosbox.lock,
# env DOSBOX_LOCK_FILE), EXCLUSIVE for timing-, rate- and screen-dependent
# runs, SHARED for runs whose result does not depend on host load. See the
# lock section of shared/skills/dos-emulator-workflow/references/tooling.md.
#
# WRITER PRIORITY (intent lock, $DBXLOCK_FILE.intent): flock alone lets a
# new SHARED taker in while an EXCLUSIVE waiter is queued, so a stream of
# overlapping shared holders can starve a writer indefinitely (dosags saw an
# exclusive waiter wait over an hour, 2026-09-23). So every taker passes
# through the intent lock first:
#   EXCLUSIVE: intent EXCLUSIVE -> main EXCLUSIVE -> release intent.
#   SHARED:    intent SHARED    -> main SHARED    -> release intent.
# A queued writer holds intent while it waits for the main lock, so no new
# reader can get past intent: the writer only waits for the readers already
# inside. Readers that are themselves still waiting on the main lock hold
# intent SHARED, so a writer arriving behind them waits for them too -- the
# order of arrival is kept.
# The writer releases intent as soon as it holds the main lock, rather than
# keeping it for its whole run: a second writer arriving during that run then
# takes intent itself and waits on the main lock, which makes it the NEXT
# holder when the first writer finishes -- no reader can slip between them.
# (If the first writer kept intent, the second would queue on intent beside
# new readers, and when intent freed a reader could win it and make the
# second writer wait out that reader's whole run.)
#
# .who ($DBXLOCK_FILE.who): informational, one line per holder or waiting
# writer, each removed by its own process on release/acquire:
#   pid=<pid> tool=... mode=shared|exclusive ... since=<utc>
#   waiting: pid=<pid> tool=... mode=exclusive ... since=<utc>
# Readers of it mark each line (alive) or (STALE: pid N is not running) --
# a holder killed outright cannot clean up. The flock is the truth: to ask
# whether the lock is free, test it; never read .who.
#
# API (all return 0 on success):
#   dbxlock_acquire MODE WAIT_S DESC   MODE shared|exclusive; DESC is
#       "tool=... <more key=value>". Holds the main lock on fd 8 on success
#       (a child that inherits fd 8 keeps the lock alive with it). Returns 1
#       when WAIT_S seconds pass first. Prints one "waiting" line to stderr
#       (with the current .who) if it has to wait, unless DBXLOCK_QUIET=1.
#   dbxlock_release                    remove our .who lines, close fd 8.
#   dbxlock_describe                   the .who lines, each marked alive/STALE.
# fds used: 8 main (held), 7 intent (transient), 6 .who edits (transient).
# DOSBOX_LOCK_HELD=1 is the CALLER's business: when a parent already holds
# the lock around us, do not call dbxlock_acquire at all.

DBXLOCK_FILE="${DOSBOX_LOCK_FILE:-/tmp/dos-port-dosbox.lock}"

_dbxlock_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

_dbxlock_who_edit() {   # $1 = add|drop|dropwait, $2 = line (add)
    local who="$DBXLOCK_FILE.who" tmp
    exec 6>>"$DBXLOCK_FILE.who.lock" || return 0
    flock -x -w 5 6 || { exec 6>&-; return 0; }
    case "$1" in
        add) printf '%s\n' "$2" >> "$who" 2>/dev/null ;;
        drop|dropwait)
            if [[ -f "$who" ]]; then
                tmp="$who.$$"
                if [[ "$1" == "drop" ]]; then
                    grep -v -e "^pid=$$ " -e "^waiting: pid=$$ " "$who" > "$tmp" 2>/dev/null || true
                else
                    grep -v -e "^waiting: pid=$$ " "$who" > "$tmp" 2>/dev/null || true
                fi
                if [[ -s "$tmp" ]]; then mv -f "$tmp" "$who"; else rm -f "$tmp" "$who"; fi
            fi ;;
    esac
    exec 6>&-
    return 0
}

dbxlock_describe() {
    local who="$DBXLOCK_FILE.who" line pid
    if [[ ! -s "$who" ]]; then echo "none recorded"; return 0; fi
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        pid="${line#waiting: }"; pid="${pid#pid=}"; pid="${pid%% *}"
        if [[ "$pid" =~ ^[0-9]+$ && -d "/proc/$pid" ]]; then echo "  $line (alive)"
        else echo "  $line (STALE: pid $pid is not running)"; fi
    done < "$who"
    return 0
}

dbxlock_acquire() {
    local mode="$1" wait_s="$2" desc="$3" opt deadline rem said=0
    case "$mode" in exclusive) opt=-x ;; shared) opt=-s ;; *) return 2 ;; esac
    deadline=$(( $(date +%s) + wait_s ))
    exec 7>>"$DBXLOCK_FILE.intent" || return 1
    exec 8>>"$DBXLOCK_FILE" || { exec 7>&-; return 1; }
    [[ "$mode" == "exclusive" ]] && _dbxlock_who_edit add "waiting: pid=$$ $desc mode=exclusive since=$(_dbxlock_utc)"
    # 1) intent
    if ! flock -n "$opt" 7; then
        if [[ "${DBXLOCK_QUIET:-0}" != "1" ]]; then
            echo "dosbox lock: waiting (up to ${wait_s}s) to take the $mode lock; recorded:" >&2
            dbxlock_describe >&2; said=1
        fi
        rem=$(( deadline - $(date +%s) )); (( rem < 0 )) && rem=0
        if ! flock -w "$rem" "$opt" 7; then
            exec 7>&- 8>&-; _dbxlock_who_edit dropwait; return 1
        fi
    fi
    # 2) main
    if ! flock -n "$opt" 8; then
        if [[ "${DBXLOCK_QUIET:-0}" != "1" && "$said" == "0" ]]; then
            echo "dosbox lock: waiting (up to ${wait_s}s) to take the $mode lock; recorded:" >&2
            dbxlock_describe >&2
        fi
        rem=$(( deadline - $(date +%s) )); (( rem < 0 )) && rem=0
        if ! flock -w "$rem" "$opt" 8; then
            exec 7>&- 8>&-; _dbxlock_who_edit dropwait; return 1
        fi
    fi
    # 3) release intent: held main now; see the header for why not later
    flock -u 7; exec 7>&-
    [[ "$mode" == "exclusive" ]] && _dbxlock_who_edit dropwait
    _dbxlock_who_edit add "pid=$$ $desc mode=$mode since=$(_dbxlock_utc)"
    return 0
}

dbxlock_release() {
    _dbxlock_who_edit drop
    exec 8>&-
    return 0
}
