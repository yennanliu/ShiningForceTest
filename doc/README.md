# Project Banner — Documentation

Project Banner (working title) is an original, single-player, isometric tactical RPG for desktop. It is built with Godot 4 and typed GDScript and runs fully offline.

| # | Doc | Read it if you want to know… | Main audience |
| --- | --- | --- | --- |
| 01 | [App Design](01-app-design.md) | **What** we are building and **why**: product vision, features, screens, scope, plus the engineering overview | Everyone |
| 02 | [Engineering Design](02-eng-design.md) | **How** it works: architecture, core features, interfaces, class definitions, data formats, testing | Engineers |
| 03 | [Implementation Plan](03-implementation-plan.md) | **In what order** we build it, and how each step is validated | Engineers, leads |
| 04 | [Research & References](04-research-and-references.md) | What we learned from the genre reference, IP guardrails, sources | Design, leads |
| 05 | [Art Direction](05-art-direction.md) | Style, palette, characters, portraits, UI frames, readability, asset specs | Artists, UI, developers |

Reading order: 01 → 02 → 03. Read 04 as needed.

## Decisions at a glance

| Topic | Decision |
| --- | --- |
| Platform | Desktop (macOS, Windows, Linux), local only, 1 player |
| Engine / language | Godot 4.x, typed GDScript |
| Architecture | 3 layers: View (scenes) → Core (pure rules) → Data (resources, saves) |
| Core contract | `BattleState.apply(Command) -> Array[BattleEvent]` is the only way a battle changes |
| Content | Godot Resources (`.tres`), edited in the Godot editor |
| Saves | Versioned JSON in `user://saves/` |
| Testing | Built-in headless runner (`tools/test.sh`): unit tests, AI-vs-AI battles, golden replays, save round-trips |

## Doc conventions

- The docs are Markdown in this folder. Diagrams use Mermaid, which GitHub renders.
- When code changes a public interface (doc 02 §6–8), update that doc in the same PR.
- Numbers marked *(tune)* are starting values to adjust in playtests.
