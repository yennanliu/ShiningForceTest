# ShiningForceTest — Project Banner

An original, single-player, isometric tactical RPG for desktop, built with Godot 4 and typed GDScript.

## Docs

| # | Doc | What it covers |
| --- | --- | --- |
| 01 | [App Design](doc/01-app-design.md) | Product vision, features, screens, scope, engineering overview |
| 02 | [Engineering Design](doc/02-eng-design.md) | Architecture, core features, interfaces, class definitions, data formats, testing |
| 03 | [Implementation Plan](doc/03-implementation-plan.md) | 12 steps, with tasks and validation for each |
| 04 | [Research & References](doc/04-research-and-references.md) | Genre reference analysis, IP guardrails, sources |

Start with the [doc index](doc/README.md).

## Setup

No GPU is needed for anything below.

| You want to… | Command |
| --- | --- |
| Play a battle (text mode, in the terminal) | `tools/docker.sh play` (or, with Godot installed: `godot --headless --path . -s res://tools/play.gd`) |
| Run the tests | `tools/docker.sh test` (or `tools/test.sh`) |
| Build the Linux app | `tools/docker.sh export` |
| Balance report (AI vs AI) | `godot --headless --path . -s res://tools/battle_sim.gd -- --runs=200` |

The Godot version is pinned in `.godot-version`. Docker, CI and native runs all use it. A graphical (3D) view is planned for later, on a machine with a GPU.
