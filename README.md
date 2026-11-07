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

| You want to… | Use | Command |
| --- | --- | --- |
| Run tests / build the app | **Docker** (no local Godot needed) | `tools/docker.sh test` · `tools/docker.sh export` |
| Play or edit the game | **Native Godot** (needs a GPU and a window) | `brew install --cask godot`, then `godot --editor --path .` |
| Run tests without Docker | Native Godot | `tools/test.sh` |

The Godot version is pinned in `.godot-version`. Docker, CI and the native setup all use it.
