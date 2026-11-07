# 04 · Research & References

This doc records what we learned from the genre's reference game, Shining Force III Scenario 1 (Sega Saturn, 1997). It also sets the rules that keep Project Banner an original game. **We borrow mechanics, never expression.**

| | |
| --- | --- |
| Audience | Design, leads |
| Related | [01 App Design](01-app-design.md) |
| As of | 2026-11-07 |

**Contents:** [1 Reference game](#1-reference-game) · [2 What it gets right](#2-what-it-gets-right) · [3 What to design against](#3-what-to-design-against) · [4 IP guardrails](#4-ip-guardrails) · [5 Study tools](#5-community-study-tools) · [6 Sources](#6-sources)

---

## 1. Reference game

| | |
| --- | --- |
| Title | Shining Force III Scenario 1 |
| Developer / publisher | Camelot Software Planning / Sega |
| Platform | Sega Saturn |
| Release | Japan 1997, West mid-1998 |
| Structure | Scenario 1 of 3. Each scenario follows a different army's view of the same war. Save data carries over between scenarios |
| Genre | Turn-based tactical RPG on 3D maps |

---

## 2. What it gets right

| Feature | How it works there | Lesson for us | Where it lands |
| --- | --- | --- | --- |
| 3D grid battles | Turn-based fights on 3D maps; camera rotates at any time | Readable height and occlusion beat polygon count | [02 §4.1](02-eng-design.md#41-grid-and-terrain--grid-terraindata), camera rig |
| Short battles | Fights shorter and snappier than other genre leaders | 15–25 min maps; skippable animations | [01 §2](01-app-design.md#2-design-pillars) |
| Friendship system | 5 bond levels give bonuses to 9 stats when bonded units fight together | A light, emergent bond system rewards formation play without grinding | [02 §4.7](02-eng-design.md#47-bonds--bonds) |
| Soft death | Fallen units aren't lost; each bond drops a level | Losses cost something without forcing a reset | [02 §4.7](02-eng-design.md#47-bonds--bonds) |
| Weapon specials | A weapon-dependent special can trigger on attack | Variety per hit; gear choice matters | [02 §4.4](02-eng-design.md#44-combat-resolution--rules) |
| Visible enemy MP | Players can see an enemy caster's MP running out | Show enemy resources so players can plan | HUD unit panel |
| Timed reinforcements | Arrive mid-battle at a distance | Plan dramatic beats but keep them fair | [02 §4.8](02-eng-design.md#48-map-scripting--mapscript-triggerdata) |
| Ruins maps | Loot races with carry limits | Vary objectives beyond "defeat all" | Map twists, [01 §2](01-app-design.md#2-design-pillars) |
| Home base | Storage, party swap, objective reminder, chatter | One hub handles prep and party mood | Camp screen |
| No world map | Linear towns, search spots | Keep momentum; small, dense places | Town screen |
| Linked scenarios | Survivors and choices carry over through saves | Versioned saves with carryover in mind from day one | [02 §8.2](02-eng-design.md#82-save-file--usersavesslot_1json) |

## 3. What to design against

| Criticism | Our answer |
| --- | --- |
| Weak enemy AI; battles easy once bonds are mastered | Utility AI with profiles, AI-vs-AI balance sims, hard mode, clear-rate targets |
| Silent protagonist's "……" lines feel awkward | The lead speaks in key scenes |
| Warping back to heal breaks the flow | Free full heal after every battle |
| Tactical depth below the genre's best | One twist per map, weapon ranges, terrain that matters |

---

## 4. IP guardrails

| Allowed (genre mechanics) | Not allowed (specific expression) |
| --- | --- |
| Grid tactics, initiative turn order | The reference's title, logo or branding |
| Bond / friendship-style bonuses | Character names, designs or personalities |
| Class promotion, weapon specials | Place names, story beats, plot structure |
| Camp hub, towns with search spots | Map layouts, music, sound effects, text |
| Multi-scenario structure | Any file extracted from the original game |

Team rules:

1. No ROMs, ripped assets, or files produced by extraction tools go in the repo.
2. Anyone who studies the original uses a copy they legally own. We never download or share ROMs.
3. GPL tools (for example, emulators) are used for study only and are never linked into or shipped with our build.
4. Legal review of names, art and story happens at each milestone gate.

---

## 5. Community study tools

For research only. Nothing from these ships with or is copied into our game.

| Tool | What it is | How we use it |
| --- | --- | --- |
| [Ymir](https://github.com/ymir-emu/Ymir) | GPL-3.0 C++ Sega Saturn emulator with a debugger and frame stepping | Step through a legally owned copy frame by frame to study pacing, animation timing and camera behavior |
| [sf3tools](https://github.com/Synival/sf3tools) | Community editors and libraries for the reference's data: maps, portraits, sprites, compression | Learn how a 1997 team structured map, unit and event data, as input to our own schemas |
| [SFR-Godot](https://github.com/ShiningForceRemade/SFR-Godot) | Early-stage Godot fan project (4 commits) with battle and movement scenes | One example of a Godot project layout; too early to adopt as a base |

---

## 6. Sources

- [Sega-16 review of Scenario I](https://www.sega-16.com/2025/01/shining-force-iii-scenario-i/) (Jan 2025): release info, bond system details, criticisms
- [Kimimi playthrough, part 1](https://kimimithegameeatingshemonster.com/2024/09/30/shining-force-iii-scenario-1-colossus-of-the-capital-a-shining-start-pt1/) (Sep 2024): pacing, home base, ruins maps, criticisms
- [Shining Wiki entry](https://shining.fandom.com/wiki/Shining_Force_III_Scenario_1:_God_Warrior_of_the_Kingdom): could not be loaded during research
- A ROM download site from the original reference list was left out on purpose
