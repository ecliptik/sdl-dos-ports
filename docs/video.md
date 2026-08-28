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
an adventure engine benefits far more than a scrolling action game). If
your engine renders a small image into a larger surface (e.g. a centered
sub-image), **rect-limit every stage that touches the surface, not just
one** — a blit call and a present/window-update call are separate APIs
each needing their own rect argument; limiting only one still leaves the
other doing full-surface work every frame. See `optimization.md`'s
rect-limiting note for a real-hardware measurement of just how much this
costs when missed.

Upstream's own backend documentation
([README-dos](https://wiki.libsdl.org/SDL3/README-dos)) is explicit that
**tear-free rendering depends on hardware page-flipping being available,
and page-flipping is not universal** — it's an LFB-mode capability, not
something banked mode gets. A card forced into banked mode by capability
(no linear framebuffer at the mode in use — see the Mach64 case in
"Real hardware can diverge..." below) may not have a tear-free path
available at all under this backend's current design, independent of
whatever vsync-wait code exists in the banked path itself. This
reframes "why is there a stable tear on this card" from "something is
broken" to "check whether page-flipping was ever an option here" before
assuming a fixable bug.

Separately, `SDL_HINT_DOS_ALLOW_DIRECT_FRAMEBUFFER` (a genuine **upstream**
SDL3 hint, not something `shared/` introduced — confirmed present in
unpatched SDL3's own `SDL_dosframebuffer.c`) trades away vsync entirely
for speed: per its own documentation, setting it skips normal surface
copying and "performs page flipping without vblank synchronization,"
with "no vsync" and "potentially slow readback on real hardware" as its
stated, accepted trade-offs. If a port's video hint configuration touches
this one (directly or via `shared/patches/sdl3-dos/0010`'s
`SDL_HINT_DOS_PREFER_LFB` interaction with it), tearing is expected
behavior for that path, not a defect.

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
2026-08-26 — architecturally fixed in that port's own engine code as its
patch 0003. **Confirmed as the complete fix**: a direct pixel-diff of a
post-fix real-hardware capture against the DOSBox-X reference screenshot
came back at 2.85/255 mean difference, consistent with JPEG noise, not a
defect. The pre-fix saved frame was independently re-checked and confirmed
genuinely, severely broken — near-total fine-grained garbage across nearly
the whole frame — so this was a real bug with a real fix, not a
non-issue. No second video hazard was involved; see the triage note
below for how that got clarified.)

**A faster alternative to render-then-blit-convert: write directly in the
window surface's real, queried format.** The render-into-known-format-
then-blit-convert path above is safe, but the blit-conversion pass turned
out to be the single largest per-frame cost in dossage/Passage's later
performance investigation on the same real Mach64 hardware (~145-160ms/
frame before rect-limiting, still ~25-37ms/frame after — see
`optimization.md`'s rect-limiting note). The actual bug in the original
XRGB8888 finding was never "writing directly into the window surface" —
it was writing an *unverified, assumed* format. Querying the window
surface's real pixel format at runtime (`SDL_GetPixelFormatDetails`) and
packing each pixel directly into *that* format (`SDL_MapSurfaceRGB`),
writing straight into the window surface with no intermediate surface or
blit pass, is equally safe — because it's format-aware instead of
format-assuming — and eliminates the blit entirely. Confirmed against
SDL's own reference behavior before trusting it: the 3-bytes-per-pixel
byte-order convention was checked against `SDL_FillSurfaceRect3`
(`SDL_fillrect.c`) rather than assumed (little-endian, low-byte-first,
matching a plain memcpy of a `Uint32`'s low N bytes on x86). Real-hardware
confirmed clean via careful multi-checkpoint color scrutiny, no
corruption, and delivered a real ~38% flip-cost reduction on its own
(6.90 → 8.18fps). Fall back to the render+blit path above for any pixel
format this direct-write approach doesn't explicitly handle (non-2/3/4
bytes-per-pixel, e.g. indexed) — **this is an alternative for a port
that wants to avoid the blit cost, not a replacement recommendation**;
either approach is correctness-safe, so the choice is a performance
trade-off, not a correctness one, unlike the original raw-`Uint32`-write
bug that started this thread.

**Diff against the known-good reference before reaching for hardware
register diagnostics.** After the XRGB8888 fix above landed, a real-hardware
Mach64 retest still showed a banded, non-uniform region on the right side
of the screen. Read visually against expectations of "clean gameplay," this
looked like corruption, and it drove a genuinely careful five-patch
diagnostic chase at the shared SDL3-DOS layer — bank-switch chunk-content
and post-write readback (`SDL/0128`-`0131`), a legacy VGA Graphics
Controller register dump (`SDL/0132`), a raw CRTC offset register read
(`SDL/0133`), and a standardized VBE 4F06 Get Scan Line Length call
(`SDL/0134`) — all of which came back clean or internally consistent, ruling
out bank-switching, legacy VGA read/write-mode state, and stride/pitch
mismatches one by one with real evidence. The actual answer only surfaced
when the "corrupted" capture was pixel-diffed directly against this
project's own `docs/screenshots/dossage-gameplay.png` DOSBox-X reference
(2.85/255 mean difference — the banded region was Passage's *intended*
right-side visual content, not a defect at all). **Lesson for the next
real-hardware-only video symptom that looks wrong on sight: do the direct
pixel-diff against a known-good reference screenshot first**, before
spending register-level diagnostic effort — it's cheaper than a single one
of the probes above and would have closed this case immediately. This
doesn't make the probes wasted work: they're retained in `shared/` as
hint-gated (`SDL_HINT_DOS_BANK_CHUNK_PROBE`; zero cost when unset),
chip-agnostic diagnostic tooling precisely because ruling out those layers
cleanly is a real, reusable result for whatever the *next* investigation
turns out to be.

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

**A closest-mode-match result is not a fixed fact for a given chip
model, and the mode-set log line reports the resolved mode, not the
app's raw request — both easy to misread.** doskutsu's own Mach64
215CT history above landed on a 512x384 closest-match for a 320x240
request. A later, independent real-hardware measurement on nominally
the same chip family (dossage/Passage, same "cannot do 320x200/240"
UniVBE-confirmed constraint) landed on 640x480 for the same logical
request instead — a different result on nominally the same hardware
class, most likely because a different enumerated-mode list (different
BIOS/VBE version, different configured mode table) changed which
mode SDL's closest-match algorithm considered "closest." **Treat one
measurement's closest-match result as a data point for that specific
config, not a universal fact about the chip model** — re-verify rather
than assuming a prior measurement still holds when hardware, BIOS
version, or UniVBE config differs even slightly.
Separately: `DOSVESA_SetDisplayMode` (`SDL_dosmodes.c`) logs the
`SDL_DisplayMode*` it resolved to *after* SDL's own closest-match
algorithm already ran — so a log line reading e.g. "requested
id=... 640x480" does **not** mean the app asked for 640x480, it means
closest-match landed there for whatever the app actually requested.
This tripped up real-hardware round-trips on dossage/Passage more than
once before being caught by reading the source instead of assuming the
log line's plain-English reading was literal. Read that log line as
"resolved mode," never as "requested mode," and check the source at
that call site if the distinction matters for a specific investigation.

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

**For contrast: Cirrus's one confirmed genuine hardware defect.** Not
every real-hardware-only video symptom traces back to port-side or
caching bugs — on the g2k rig's Cirrus card (labeled CL-GD5434 throughout
most of `shared/`'s own patch history, though the physical silkscreen
confirms CL-GD5430; HWiNFO's chip-ID misdetects it, and no prior
measurement is invalidated by the mislabel, just the name used for it),
the LFB aperture and the VRAM region the display generator actually reads
from are genuinely decoupled at the hardware level under UniVBE 6.7:
writes through the LFB aperture land in VRAM cells the display generator
never reads, while every BIOS-level readback (display-start GET/SET,
the mode-set return code) reports correctly — the corruption is below the
BIOS interface, invisible to any check phrased in terms of BIOS state.
Confirmed via 100+ post-flush LFB writes producing zero visible screen
change. Fixed in `shared/patches/sdl3-dos/0019` (auto-detect Cirrus,
force-disable LFB, route through the banked `A000:0` window instead).

`0019` itself needed a follow-up, `0020`: it flipped the framebuffer
layer's write path to banked but left the BIOS-level mode-set still
requesting LFB, so the BIOS programmed LFB hardware while the FB layer
wrote through the banked window — the two layers disagreed, producing a
blank screen rather than even partial rendering. The general lesson: a
two-layer decision (BIOS mode-set choice vs. FB-layer write-path choice)
has to be gated on the *same* condition, checked at *both* layers, or you
get exactly this shape of defect — everything reports correctly at the
BIOS level, the screen is still wrong. Both patches are closed at the
shared layer; no port needs to re-derive this.

## Reduced color depth

8-bit or 16-bit software surfaces are strongly preferred over 32-bit on
486/Pentium-class hardware — see `optimization.md`. Full-screen pixel
copies and pixel-format conversion are consistently the first or second
most expensive thing on this class of hardware.

This is also a correctness-risk reduction, not just a performance one.
[DevilutionX](https://github.com/diasurgical/DevilutionX) — an unrelated
engine also porting to DOS via SDL3 — sets
`DEVILUTIONX_DISPLAY_PIXELFORMAT SDL_PIXELFORMAT_INDEX8` explicitly for
its DOS build, sidestepping packed-multi-byte pixel-format conversion
(the exact class of code implicated, though not yet confirmed as root
cause, in dossage/Passage's real-hardware Mach64 investigation above)
entirely. 8-bit indexed VGA/VESA banked-mode paths are the most
thoroughly real-hardware-proven code in `shared/patches/sdl3-dos/`; a
port that can accept indexed color inherits that maturity directly,
where a 32-bit-truecolor port exercises less-trodden conversion paths on
whatever format a given card's BIOS happens to pick.
