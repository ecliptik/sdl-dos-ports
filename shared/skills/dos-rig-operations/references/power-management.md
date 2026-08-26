# Power management

Lower bug-density than input/capture/transfer, but the stakes when it's
wrong are physical rather than just "the run is invalid" -- so the rules
here are short and non-negotiable rather than judgment calls.

For the literal smart-plug scoping and command surface, see vcctrl's own
`vcctrl-rig-hazards`.

## The plug's scoping is visibility to a human, not a hardware interlock

A power-control system scoped so a given control can't hit the wrong
*plug* still can't verify which physical *machine* is actually seated on
the other end of that plug's cabling. Scoping prevents you from
accidentally power-cycling a different rig by picking the wrong control;
it does not prove the cabling matches what the config claims. Treat plug
scoping as a safety rail against picking the wrong control, not as proof
of which machine you're actually about to affect -- if there's ever real
doubt about what's physically wired to a given control, resolve that
before acting, don't infer it from the config alone.

## A power cycle should be unconditional regardless of reported state

A machine that's wedged (hung, frozen, unresponsive) can still report
"on" through whatever status channel exists -- a wedged machine isn't
necessarily a powered-off one. Don't skip a power cycle because the
reported state already looks like what you want; if the goal is a known-
clean boot, cycle power unconditionally rather than trusting a status
read that a hang can trivially falsify.

## Confirm-string discipline

Any power action that isn't trivially reversible (a full power-off, not
just a reboot) should require an explicit confirm step, not fire on the
first request -- the cost of an accidental power-off on a real machine
(interrupted writes, a card that needs a clean reboot to re-enumerate
correctly) is higher than the cost of one extra confirmation prompt.
