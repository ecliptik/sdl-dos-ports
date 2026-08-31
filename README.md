# sdl-dos-ports

A hub for porting SDL-based games to MS-DOS, built on the SDL3 DOS backend
proven by [doskutsu](https://github.com/ecliptik/doskutsu) (Cave Story on
real 486/Pentium-class DOS hardware via SDL3, DJGPP, and CWSDPMI).

This repository does not contain the games themselves. Each port lives in
its own git repository and pulls in the reusable platform layer from
[`shared/`](shared/) via a git submodule. This repo tracks status, hosts
that shared layer, documents the porting strategy and hardware/QA process,
and showcases finished ports.

See [`CLAUDE.md`](CLAUDE.md) for the rules an AI agent (or contributor)
should follow when working in this repo,
[`PORTING.md`](PORTING.md) for the full step-by-step process of starting
a new port, and [`docs/SHEPHERDING-GUIDE.md`](docs/SHEPHERDING-GUIDE.md)
for the consolidated playbook covering everything from hour zero through
a real-hardware performance campaign — the single best starting point if
you want to jump in and get results without re-deriving lessons a real
campaign already paid for.

## Starting a new port

1. Pick a `BACKLOG` candidate from the table below (or add a new one to
   [`ports.yaml`](ports.yaml), following its existing schema — never guess
   an upstream URL or license).
2. From this hub repo (not from inside the new port's repo), invoke the
   `new-port` skill (`.claude/skills/new-port/`). It verifies the
   candidate's upstream/license if that's not already done, runs
   `scripts/new-port.sh` to scaffold the new repo (wired to `shared/` via
   submodule, with `shared/skills/*` symlinked in), instantiates
   `shared/agents/*.md` charters for that port, pins
   `vendor/sources.manifest`, claims the candidate in `ports.yaml`, and
   hands off to a porting agent with a concrete starting brief instead of
   an empty "go start porting."
3. Run `scripts/new-port.sh <name>` directly instead if you only want the
   bare mechanical scaffold (no research, charters, or handoff) — see the
   script's own `Next steps` output for what's left to do by hand in that
   case.

See [`PORTING.md`](PORTING.md) for the full process this automates,
including the porting slice order (compile -> video -> input ->
filesystem -> audio -> gameplay -> optimization) the handed-off agent
follows next.

## Ports

| Priority | Project | Upstream | License | Port repo | Status | Difficulty |
|---:|---|---|---|---|---|---:|
| 0 | doskutsu (Cave Story) | [nxengine/nxengine-evo](https://github.com/nxengine/nxengine-evo) | GPL-3.0 (verified) | [ecliptik/doskutsu](https://github.com/ecliptik/doskutsu) | RELEASE_READY | reference |
| 1 | Adventure Game Studio | [adventuregamestudio/ags](https://github.com/adventuregamestudio/ags) | unverified | unclaimed | BACKLOG | 5 |
| 2 | VVVVVV | [TerryCavanagh/VVVVVV](https://github.com/TerryCavanagh/VVVVVV) | unverified — see caution below | unclaimed | BACKLOG | 3 |
| 3 | Meritous | TBD | unverified | unclaimed | BACKLOG | 2 |
| 4 | OpenJazz | [OSSGames/GAME-SDL-openjazz](https://github.com/OSSGames/GAME-SDL-openjazz) | unverified | unclaimed | BACKLOG | 2-3 |
| 5 | POWDER | TBD | unverified — may not be open source, see `ports.yaml` | unclaimed | BACKLOG | 2 |
| 6 | Kobo Deluxe | TBD | unverified | unclaimed | BACKLOG | 3-4 |
| 7 | Blob Wars: Metal Blob Solid | TBD | unverified | unclaimed | BACKLOG | 3-4 |
| 8 | Passage | [jasonrohrer/Passage](https://github.com/jasonrohrer/Passage) | public domain (verified) | [ecliptik/dossage](https://forgejo.ecliptik.com/ecliptik/dossage) | PLAYABLE | 1 |
| 9 | SuperTux 0.1.x | TBD | unverified | unclaimed | BACKLOG | 4 |

This table is generated from [`ports.yaml`](ports.yaml) — the machine-
readable source of truth, including `upstream_license_verified` per entry.
"Unverified" means exactly that: nobody has yet read the actual upstream
LICENSE/COPYING file for that project in this repo. **Never treat an
unverified license as known** — see [`docs/licensing.md`](docs/licensing.md)
and `ports.yaml`'s header comment. VVVVVV in particular has historically
been distributed under source-available terms that are not automatically
redistribution rights; see its `ports.yaml` entry before assuming anything.

See [`COMPATIBILITY.md`](COMPATIBILITY.md) for a richer boots/playable/
hardware-target matrix as ports progress, and [`gallery/`](gallery/) for
screenshots, performance notes, and features per finished port.

## Repository layout

```
sdl-dos-ports/
├── ports.yaml         # candidate backlog + status tracker (source of truth)
├── docs/              # architecture, video/audio/input/filesystem/timing, testing, licensing
├── shared/            # the reusable SDL3-DOS platform layer -- port repos consume this via submodule
├── templates/         # scaffolding for a new port repo (STATUS/PLAN/CLAUDE/benchmark/license-review templates)
├── gallery/            # per-port showcase: screenshots, performance, features
└── scripts/           # scripts/new-port.sh and friends
```

## Reference hardware

Primary targets, shared across all ports (see [`HARDWARE.md`](HARDWARE.md)
for the full matrix and real-hardware testing process via
[vcctrl](https://github.com/ecliptik/vcctrl)):

| ID | CPU | Role |
|---|---|---|
| HW-486-50 | 486DX2-50 | low-end torture test |
| HW-486-66 | 486DX2-66 | primary minimum target |
| HW-POD83 | Pentium OverDrive 83 | upgrade-path target |
| HW-5X86 | AMD Am5x86-133 | fast 486 platform |
| HW-P75 | Pentium 75 | recommended target |

## License

See [`LICENSE`](LICENSE) for this repository's own code and docs, and
[`THIRD-PARTY.md`](THIRD-PARTY.md) for the licensing model applied to
vendored/patched third-party sources in `shared/`. Every port repo tracks
its own game engine and asset licensing separately in its own
`LICENSE-REVIEW.md`.
