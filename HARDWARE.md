# Reference hardware

Every port should eventually be evaluated against the same hardware matrix,
so results are comparable across ports rather than each port inventing its
own baseline.

## Primary matrix

| ID | CPU | Role |
|---|---|---|
| HW-486-50 | 486DX2-50 | low-end torture test |
| HW-486-66 | 486DX2-66 | primary minimum target |
| HW-POD83 | Pentium OverDrive 83 | upgrade-path target |
| HW-5X86 | AMD Am5x86-133 | fast 486 platform |
| HW-P75 | Pentium 75 | recommended target |

For each machine, record when available: CPU, clock, L1/L2 cache, memory
size, chipset, video card, VESA BIOS/version, sound card, MIDI device, DOS
version, memory manager configuration. Cache configuration in particular
should never be omitted for a 486-class result — it materially changes
throughput.

## doskutsu's real-hardware baseline (for calibrating expectations)

| Hardware | Approximate render rate |
|---|---:|
| 486DX2-50 | ~19 FPS |
| 486DX2-66 | ~25 FPS |
| Pentium OverDrive 83 | ~33 FPS |
| Am5x86-133 | ~33 FPS |

Cave Story's game logic runs at a fixed simulation rate decoupled from
render rate — see `docs/timing.md`. A candidate does not need to hit
50/60 FPS to be playable if its simulation timing can be cleanly separated
from its render rate; use doskutsu's numbers as a rough complexity yardstick,
not a pass/fail bar.

## Known hardware-specific issues

A living log, updated as issues are found -- not just once resolved.
Record here as soon as a real-hardware-only symptom is localized to a
specific card/chip, even before root cause is known, so a second port
hitting the same card doesn't have to rediscover an investigation already
in progress. Once resolved and generalized, the durable lesson moves into
`docs/video.md`/`docs/audio.md` (cross-referenced below); this table
stays the fast index of what's known per component.

| Component | Status | Summary | Details |
|---|---|---|---|
| ATI Mach64 (215CT/-ET) | **Open** -- investigating | Real-hardware-only video corruption on dossage/Passage at 640x480 (forced banked 24bpp, no LFB on this card). Two candidate root causes already ruled out with evidence (stride/pitch caching -- already fixed generically in `SDL/0125`, confirmed via exact bank-crossing arithmetic; generic SDL blit conversion -- ruled out via a host-build byte-exact round-trip test). Currently narrowing via a chunk-content + post-write-readback probe (`SDL_HINT_DOS_BANK_CHUNK_PROBE`, `SDL/0128`+`SDL/0129`) to distinguish a physical-write quirk from a scanout/display-timing issue. | `docs/video.md` (mode-selection/centering history); this table for current status |
| ATI Mach64 (215CT/-ET) | Resolved | Silicon cannot double-scan -- no 320x200/320x240 VESA mode exists at all (confirmed via UniVBE's own printed banner). Forces closest-mode-match to a larger mode, which is the trigger condition for the stride-caching bug above and for missing-centering/dirty-rect-coordinate bugs in doskutsu's own engine-side code. | `docs/video.md` |
| Cirrus CL-GD5430 (mislabeled "5434" throughout most of shared/'s own patch history -- HWiNFO misdetects it; physical silkscreen confirms 5430, no measurement invalidated) | Resolved | Genuine hardware defect: LFB aperture and the VRAM the display generator actually reads are decoupled under UniVBE 6.7. Fixed generically at the shared layer (`SDL/0019` auto-disables LFB on this chip; `SDL/0020` fixes a second-order BIOS/FB-layer disagreement `0019` itself introduced). | `docs/video.md` |
| S3 ViRGE (86C375 Rev B) | No known card-specific defect | No stride/pitch or LFB-aperture issue found in doskutsu's history on this card (native 320x240 support avoids the Mach64 trigger condition). The one real gotcha here is rig-wide, not card-specific: UniVBE silently declines after any card swap without re-running its setup -- see below. | `docs/video.md`, `dos-hardware-validation` |
| Any card, after a swap | Recurring operational hazard, not a one-time bug | `UNIVBE.EXE` prints nothing when it declines to install, so a stale `UNIVBE.DRV` from the previous card silently falls back to bare ROM VBE. Reads exactly like a hang. Check `MEM /C \| FIND "UNIVBE"` (positive-only, high-memory loads can false-negative) and the SDL boot log's `oem_string=` field (zero-cost, cannot-fabricate) before trusting any video diagnosis after a swap. | `shared/skills/dos-hardware-validation/SKILL.md` |

## Real-hardware testing process

Real-hardware validation for all ports currently runs through
[vcctrl](https://github.com/ecliptik/vcctrl), a KVM/automation rig (PS/2
input injection, VGA/audio capture, power control, FTP file transfer) built
around one physical machine with hot-swappable CPUs matching the matrix
above. See [`docs/hardware-testing.md`](docs/hardware-testing.md) for the
integration design and current workflow, and
[`templates/vcctrl-profile.yaml.template`](templates/vcctrl-profile.yaml.template)
for how a new port defines its own vcctrl profile.

DOSBox-X (and, for a second correctness opinion, 86Box) automation is the
day-to-day regression gate; real hardware is the authoritative result for
performance and device-compatibility claims. Never report a performance
number measured only in an emulator as if it were a hardware result.
