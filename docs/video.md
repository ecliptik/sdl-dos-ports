# Video

## Resolution hierarchy

```
320x200   best
320x240   excellent
320x400   acceptable
640x480   Pentium-oriented
higher    not an initial DOS target
```

doskutsu targets 320x240. A port whose native resolution is 320x200 (many
DOS-era and DOS-recreation games, e.g. OpenJazz) exercises the VESA path
slightly differently and is worth testing deliberately rather than assumed
identical.

## Presentation path

Preferred:

```
game software framebuffer
       |
 single conversion if necessary
       |
 VESA framebuffer
```

Avoid multiple software scaling stages. Prefer native resolution, no
filtering, integer pixels, direct blit, and dirty rectangles where the
game's redraw pattern benefits from them (a mostly-static-screen game like
an adventure engine benefits far more than a scrolling action game).

## What `shared/patches/sdl3-dos/` already handles

The hard-won VESA/VGA chip-specific work — Cirrus CL-GD5430 banked-blit
quirks, S3 ViRGE linear-framebuffer handling, DAC 6-bit vs. 8-bit
palette-width detection, banked-vs-LFB flush path selection, direct-CRTC
page flip — lives in the shared SDL3 DOS backend patches. A new port should
not need to re-derive any of this; it inherits it by pinning the same
patched SDL3.

## Real hardware can diverge from DOSBox-X on window surface format and pitch

Two distinct hazard classes can produce the same visual symptom — stable
corruption/tearing that's clean under DOSBox-X and only shows up on real
hardware — for different reasons. Both are worth knowing before assuming
a hardware defect: one is a confirmed, closed root cause from doskutsu's
own history; the other is a real-hardware finding on dossage/Passage with
an architecturally-sound fix already applied, pending real-hardware
reconfirmation that it's the complete story.

**Window surface pixel format is not guaranteed, and DOSBox-X can hide a
wrong assumption about it.** SDL1.2's `SDL_SetVideoMode(w, h, bpp, flags)`
let a port force a specific bit depth. SDL3's `SDL_CreateWindow` has no bpp
parameter — the real window surface's pixel format tracks whatever VESA
mode SDL's closest-mode matching actually picked, which can differ between
DOSBox-X's software VESA BIOS and a real card's VESA BIOS for the
*identical* logical resolution request, and can differ card-to-card on
real hardware too. A port whose rendering writes raw pixels (`Uint32*` or
similar) assuming a specific format — the natural direct port of an
SDL1.2 engine that used to request 32bpp XRGB explicitly — can render
correctly under DOSBox-X and corrupt every pixel on real hardware, because
DOSBox-X happened to pick a mode compatible with the assumption and the
real card didn't. This is exactly the "single conversion if necessary"
presentation path already recommended above, but treat it as a
**correctness requirement, not just a performance option**: always render
into your own explicitly-created known-format surface (e.g.
`SDL_PIXELFORMAT_XRGB8888`) and blit-convert onto the real window surface
at present time, rather than writing raw pixels into the window surface
directly. (Found on dossage/Passage via a real-hardware Mach64 pass,
2026-08-26 — architecturally fixed in that port's own engine code;
real-hardware reconfirmation that this fully resolves it is still
pending, since a second, independent hazard below hadn't been ruled out
yet at time of writing.)

**A stale cached VRAM pitch across an in-place mode-set is a *closed*
hazard at the shared layer, not one a new port needs to defend against
itself.** `src/video/dos/SDL_dosframebuffer.c`'s `CreateWindowFramebuffer`
populates `fb_state` (cached pitch, pixel pointer, a `pitches_match` flag)
once; the flush routine (`DOSVESA_UpdateWindowFramebuffer`) trusted those
cached fields for the framebuffer's whole life, even across a *later*
mode-set that changed the hardware's real VRAM pitch on the same surface
pointer (no new `CreateWindowFramebuffer` call, so nothing re-triggered a
refresh). Confirmed on a Mach64 215CT: the card's own UniVBE-printed
banner states plainly that Mach64-CT/-ET silicon cannot double-scan, so
320x200/320x240 aren't available modes at all — doskutsu's engine
requesting 320x240 landed on a 512x384 closest-match at first mode-set,
then a later mode-set (reached with the native-mode pin disabled, to
actually measure at 640x480) moved the hardware to 640x480 in place while
the cached pitch stayed at 512, shearing every subsequent flush
progressively down the frame. Fixed generically in
`shared/patches/sdl3-dos/0125` (re-derives the flush's cached pitch from
the live surface whenever it no longer matches, at the cost of one
pointer deref plus one int compare per flush on the common no-op path) —
this lives at the framebuffer layer, not gated to Mach64, so any port
pinning the current shared patch series inherits the fix on every card,
not just the one it was found on. It only resurfaces as a live hazard if
a port's *own* engine code separately caches a pitch/stride value outside
of what SDL3-DOS itself tracks. (0125 fixes the shear/correctness only —
it does not make an undersized composed surface fill an oversized mode;
that's a separate, unrelated concern.)

**The diagnostic technique that actually broke the case, worth reusing
directly rather than re-deriving:** the investigating session's first
theory (an offered LFB silently declining to a banked fallback that drew
nothing) turned out to be an artifact of a `uvconfig` run that had been
interrupted mid-write, leaving a half-written `UVCONFIG.DAT` advertising a
mode the card couldn't actually produce — re-running `uvconfig` to
completion and re-confirming via UniVBE's own printed banner retracted
that theory outright (see `dos-rig-operations`/vcctrl's rig-hazards
material on why a card swap or an interrupted config run needs a full
re-verify, not just an assumption it took). With configuration
independently confirmed correct, the same corruption signature
reproduced — and the actual cause was found by **logging the code's own
cached value directly beside a freshly-queried live value at the exact
moment of the flush**, not by inferring a mismatch from the visual
symptom: `pitches_match=0 src_pitch=512 vram_pitch=640` is a direct
before/after comparison instrumented in the code, and it's a technique
worth reusing verbatim for any similar "renders wrong shape on real
hardware only" investigation. A second, independent corroborating tell
sealed it: a "640x480" measurement cell read numerically identical to the
512x384 control cell (same drawn area, same drawcall count) — meaning the
engine was still doing 512x384 work while believing it was at 640x480.
That kind of exact-match-to-the-wrong-control number is a strong tell a
real hardware defect would not produce.

**Triage order:** a real-hardware-only, DOSBox-X-clean video
corruption/tearing symptom should be triaged as "probably a port-side
format or stride assumption, or a stale rig configuration" **before**
"probably a hardware/VESA defect" — on this hub's history so far, every
hypothesis that reached for a hardware defect first was wrong.

**No confirmed precedent on Cirrus (CL-GD5430/5434) or S3 ViRGE** for the
stride/pitch hazard specifically — doskutsu's own extensive real-hardware
history has no recorded incident on either chip. Best-supported reason
(inference, not proven): both support native 320x240 directly, so a
port's mode request is satisfied at the first mode-set with no later
corrective mode-set to different geometry — the specific trigger (a
closest-match miss, *then* a second mode-set to genuinely different
pitch) never arises for them. Since 0125 is a generic framebuffer-layer
fix rather than Mach64-gated, it already protects those cards too if they
ever hit an in-place geometry change for some other reason — "not
observed" means the trigger condition hasn't occurred for them, not that
the bug class is unprotected there. The window-surface-format hazard
above is a different story: it's not chip-specific at all, and can occur
on any card whose auto-selected mode's format doesn't match what a port's
rendering code assumes.

## Reduced color depth

8-bit or 16-bit software surfaces are strongly preferred over 32-bit on
486/Pentium-class hardware — see `optimization.md`. Full-screen pixel
copies and pixel-format conversion are consistently the first or second
most expensive thing on this class of hardware.
