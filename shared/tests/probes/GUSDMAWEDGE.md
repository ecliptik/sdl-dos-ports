# gusdmawedge -- GF1 DMA-upload-vs-active-voice wedge probe

Standalone DJGPP DOS probe (pure C, no SDL, no engine) answering one specific
question left open by the sdl-dos-ports S5 GUS PCM-streaming research
(dosags `PLAN.md`'s "S5 GUS architecture" section, 2026-09-13): **does a GF1
DMA-based sample upload wedge the real PicoGUS when a DIFFERENT voice is
already actively playing?**

Sibling of `gustone.c`/`gusdet.c`/`gusdump.c` -- same style, same safety
discipline described in `GUS-PROBES.md`.

## Why this exists

doskutsu's own real-hardware GUS campaign (see that repo's own
`memory/gus_campaign_picogus_diag_wedge.md` session memory) found the real
PicoGUS WEDGES (hangs, needs a physical power cycle) when a GF1 port-READ is
concurrent with an active voice -- confirmed 4 separate ways, all involving
PIO-based reads/pokes. The shared SDL3-DOS GF1 driver
(`vendor/SDL/src/audio/dos/SDL_dosaudio_gus.c`) even documents this on its
own one-shot test-tone comment: a forever-looping voice "keeps reading DRAM
and contends with the engine's gameplay `.pat` PIO poke -> wedge on the
PicoGUS."

That driver also has an **opt-in, never-hardware-validated** DMA-upload path
(`gus_upload_dma()`, `SDL_HINT_DOS_GUS_DMA_UPLOAD=1`, default OFF, comment:
"Promote to default once g2k-validated" -- that validation never happened).
Its own completion-wait loop polls the host 8237 status port first, but
falls through to a GF1 port-READ (`gus_r8(GUS_REG_DMA_CTRL)`) if the 8237
hasn't signalled yet -- i.e. it can still touch a GF1 register while the
transfer (and any other active voice) is in flight. Whether that shares the
PIO wedge risk was unknown before this probe existed.

## What it does

- **SAFE mode (default)**: bring up the GF1 (same bounded, proven-safe
  sequence `gustone.c` uses), upload + start a **looping** voice-0 tone,
  play it, stop it, exit. Exercises everything except the risky operation --
  validates the harness itself with zero hang risk.
- **`DMATEST=1`** (the actual experiment, **real-hardware-only, explicit
  opt-in, real hang risk**): once voice 0 is confirmed looping, attempts a
  chunked DMA upload of a second sample to a different DRAM region, mirroring
  `gus_upload_dma()`'s own register sequence byte-for-byte (8237 program ->
  GF1 `DMA_ADDR`/`DMA_CTRL` -> poll 8237 status THEN GF1 `DMA_CTRL` bit
  `0x40`) while voice 0 keeps sounding.

## The log line to watch

```
gusdmawedge: ABOUT TO ATTEMPT DMA UPLOAD WHILE VOICE 0 IS ACTIVE ...
```

- **Wedge**: this is the LAST line in `GUSDMAWEDGE.LOG` (and on-screen). The
  machine hangs; no further output, no exit, needs a physical power cycle.
  Confirms DMA upload shares PIO's wedge risk -- do not build a PCM streaming
  design around it without a different upload mechanism.
- **Survived**: a line beginning `gusdmawedge: DMA upload attempt N/M
  RETURNED, poll_ok=...` appears next. Refutes the immediate-hang hypothesis
  for that one attempt. Not proof for all conditions -- repeat with `REPEAT=`
  and vary chunk exposure before trusting it generally, per this campaign's
  "one clean pass is evidence, not proof" discipline.
- Either way, voice 0 is stopped and the destination DRAM is verified in a
  SAFE, bounded, no-active-voice read afterward (mirrors `GUSDUMP`'s own
  NOINIT-safety framing) -- tells you whether a *survived* attempt actually
  moved correct data.

## Usage

```
GUSDMAWEDGE                       SAFE mode -- no DMA attempt
GUSDMAWEDGE DMATEST=1             the real experiment (hang risk -- see below)
GUSDMAWEDGE DMATEST=1 REPEAT=3    repeat the concurrent-DMA attempt 3x
```

Shared knobs (same convention as `gustone.c`): `V=<n>` (active voices,
default 14 = 44100Hz, avoids the unrelated 28-voice dead-zone), `HZ=<n>`
(tone pitch), `DUR=<ms>`, `BASE=<hex>`, `IRQ=<n>`, `DMA=<n>`, `LATCH=0|1`.

Operator setup (g2k, PicoGUS v2.0, jumpers IRQ7+DMA3), same as every other
GUS probe:
```
SET ULTRASND=240,3,3,7,7
pgusinit /mode gus
pgusinit /gusdma 12
```

**`DMATEST=1` must NOT be run on real hardware without the operator's own
explicit, fresh go-ahead with the hang risk stated plainly** -- this is a
deliberately risky diagnostic, not a routine smoke test, per this project's
standing real-hardware-action rule.

## Build

```
i586-pc-msdosdjgpp-gcc -O2 -Wall gusdmawedge.c -o GUSDMAWEDGE.EXE
```

Builds clean, zero warnings (DJGPP cross-compiler, confirmed this session).

## DOSBox-X validation status -- INCONCLUSIVE, environment issue found (not a probe defect)

DOSBox-X cannot prove or disprove the wedge itself (no real PicoGUS firmware
quirk to reproduce -- see `dosbox_not_proxy`); it can only confirm the probe
builds, runs, and its log format is sane before it ever touches real
silicon. That check did **not** complete in this environment:

- A `[gus]`-enabled DOSBox-X conf was constructed (gus=true, gusbase=240,
  gusirq=7, gusdma=3) since neither `dosbox-x.conf` nor `dosbox-x-fast.conf`
  enables GUS emulation by default.
- Running `GUSDMAWEDGE.EXE` (any mode) via `dosbox-run.sh` produced no
  `STDOUT.TXT` at all -- the DPMI client crashes before any output.
- **Isolated to `disable()`/`enable()` themselves, not to anything in this
  probe**: a trivial 5-line control program that only calls `disable()`/
  `enable()` around two `printf`s crashes identically. The pre-existing,
  previously-proven `gustone.c` (unmodified, this session's own rebuild)
  crashes the same way under the exact same harness. Tried both
  `dosbox-x.conf` and `dosbox-x-fast.conf` -- same result either way.
- Conclusion: this is a pre-existing DJGPP-toolchain / CWSDPMI / DOSBox-X
  interaction issue in this environment affecting `disable()`/`enable()`
  (likely a DPMI privilege-level mismatch for the CLI/STI instructions
  CWSDPMI needs to grant), **not a defect in `gusdmawedge.c`** -- it affects
  the entire existing `gustone`/`gusdet`/`gusdump` probe family equally, none
  of which could be re-validated under DOSBox-X in this environment either.
  Out of scope to fix here; flagging for whoever next touches DOSBox-X
  validation of this probe family. The build itself (the only thing fully
  within this task's scope) is clean.

## Exact command to run on the rig (once the operator gives a fresh go-ahead for the hang risk)

```
GUSDMAWEDGE.EXE DMATEST=1 REPEAT=3
```

then read `GUSDMAWEDGE.LOG` (or, if the machine hung, note that the last
line on disk is the "ABOUT TO ATTEMPT..." announcement and the machine needs
a physical power cycle to recover).
