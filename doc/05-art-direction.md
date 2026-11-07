# 05 · Art Direction (art bible)

How Project Banner looks, so anyone can make a tile, a character, a portrait or a panel that fits. Every rule here serves the pillar **readable decisions** ([01 §2](01-app-design.md#2-design-pillars)), and everything is original ([04 §4](04-research-and-references.md#4-ip-guardrails)).

| | |
| --- | --- |
| Audience | Artists, UI, developers |
| Owner | `game-art-design` |
| Related | [01 App Design](01-app-design.md) · [03 Plan, steps 13–17](03-implementation-plan.md#presentation-rounds-steps-1317-characters-battle-scenes-portraits) · [04 IP guardrails](04-research-and-references.md#4-ip-guardrails) |
| As of | 2026-11-07 |

**Contents:** [1 Style](#1-style) · [2 Perspective](#2-perspective-decision) · [3 Palette](#3-palette) · [4 Characters](#4-characters) · [5 Portraits](#5-portraits) · [6 UI frames](#6-ui-frames) · [7 Readability](#7-readability-rules) · [8 Asset specs](#8-asset-specs) · [9 Do / Don't](#9-do--dont) · [Changelog](#changelog)

---

## 1. Style

> **Chunky pixel-art characters on clean, textured tiles. Warm daylight palette. Readable first, pretty second.**

Three words: **sturdy · warm · legible**.

- Characters are small and big-headed (about 2.5 heads tall), with one strong prop per class that reads as a silhouette.
- The world is earthy and calm: greens, ochres, slate. That way the two team colors, blue and red, and gold highlights always pop.
- Pixel art has a dark plum outline (never pure black), flat shading with one highlight and one shadow step, and no dithering gradients.

## 2. Perspective decision

**2D sprite billboards on a 3D map** (decided 2026-11-07, closes [01 §15](01-app-design.md#15-open-questions)).

| Option | Cost | Why / why not |
| --- | --- | --- |
| **2D sprites on a 3D map** ✅ | Each character is a set of drawn frames, shown as a flat `Sprite3D` billboard | No modelling, rigging or 3D animation. The same sheets work on today's 2D map (step 15) and the 3D map (step 17). One artist can make them, and placeholders can be generated |
| 3D models | Model, texture, rig and animate each class | Weeks per class, needs a 3D artist, and doesn't help the 2D view |

The battle cut-in scene (step 16) uses larger 2D **battle poses**, which keeps one consistent look.

## 3. Palette

Hex values used by the generator (`tools/art_palette.py`, drawn by `tools/make_art.py`) and the code. Team colors keep their meaning everywhere and are **never** used for decoration.

| Role | Hex | Notes |
| --- | --- | --- |
| Outline | `#1b1622` | Dark plum, 1 px at sprite scale |
| Player (team) | `#3b6fd8` | Trim, foot ring, name plates; `PLAYER_COLOR` in `battle_screen.gd` |
| Enemy (team) | `#c8423a` | Same uses, enemy side; `ENEMY_COLOR` |
| Gold (highlight) | `#ffd34a` | Acting unit, leader ★, rewards, focus; `UI.ACCENT` |
| Panel | `#1c2f6e` bg, `#cbb98a` edge | `UI.PANEL_BG`, `UI.PANEL_BORDER` |
| Poison / sleep | `#8be36b` / `#8fb8ff` | Status icons only |
| Skin | `#f2c9a0` `#d9a27a` `#a86f4c` `#6e4630` | Light → dark; goblins `#8aa04a` |
| Hair | `#2b2224` `#6b3e26` `#b8682e` `#e3c77a` `#b8b8c8` `#5a4a7a` | Black, brown, copper, flax, silver, plum |
| Cloth | `#4e6b3a` `#8a5a3c` `#6c5b7b` `#3d5a6c` `#b07a3a` `#e8e0cc` | Moss, leather, heather, slate, ochre, linen |
| Metal | `#9aa4b0` `#5c6470` `#d8b04a` | Steel, dark steel, brass |
| Terrain | plain `#7cb35a`, forest `#3f7f3a`, hill `#b08e5c`, sand `#d9c48a`, shallow `#5aa0d8`, deep `#2f5f9e`, wall `#6b6b6b` | Unchanged from step 11 (`TERRAIN_COLOR`) |

Shading: each color gets one **shadow** (×0.72 brightness, shifted slightly toward plum) and one **highlight** (+0.18 lightness). No other tints.

## 4. Characters

**Proportions** on a 48×64 frame: head about 22 px (with hair), body about 34 px, feet on row 60. That's about 2.5 heads. The face is 2 eye pixels, with no mouth at map scale.

**One prop per class** (the silhouette has to read at 48 px, even in grayscale):

| Class → promoted | Silhouette prop | Extra on promotion |
| --- | --- | --- |
| swordsman → swordmaster | Sword at the hip, short cape | Long cape, headband |
| knight → paladin | Big square shield in front, helmet, spear | Helmet plume |
| archer → sniper | Bow arc on the back, quiver | Long bow, scarf |
| cleric → bishop | Long robe to the feet, staff with a ring top | Taller staff, shoulder mantle |
| mage → wizard | Wide pointed hat, robe, staff with an orb | Taller hat brim |
| warrior → berserker | Bare arms, big axe on the shoulder, wide stance | Horned helm |
| beast (wolf) | Low four-legged body, ears, tail | — |
| civilian | Plain tunic, apron | — |

**Team trim:** every humanoid has one team-colored part: a cape, sash or hood lining. It's blue for players and red for enemies. The rest of the outfit uses cloth and metal colors only.

**Identity:** each named character has its own fixed hair color, hair style, skin tone and outfit color (`tools/art_palette.py` → `CHARACTERS`). No two party members share all three of hair, outfit and class.

**Facing and frames:** 4 directions, with right mirrored from left. Frames: idle ×2 (1 px bob), walk ×4, attack ×2 (prop forward), hurt ×1 (lean back + white flash in code).

## 5. Portraits

- **Bust, three-quarter view**, head and shoulders, facing the dialogue text: players face right, enemies face left (mirrored in code).
- Drawn on a **64×64 grid, exported 256×256** (×4 nearest), so they match the sprites. Shown with the **Linear** filter, because the box draws them smaller than 256 px. A final artist may paint at full 256 px resolution in the same palette.
- Plain background in a calm tone of the character's outfit color, darkened. The team color appears only as a thin trim on the collar.
- Moods (optional): `neutral` (required), `happy`, `angry`, `hurt`. Only the eyes, brows and mouth change between moods.

## 6. UI frames

Our frame is **flat**: rounded corners (8–10 px), a 2–3 px gold edge `#cbb98a` on navy `#1c2f6e`, and no bevels, gradients or metal textures. It's the same as `UI.panel()` and `UI.make_theme()`.

- **Dialogue box:** a portrait frame (square, same style), then a name tab sitting on the top edge of the text panel, then the text. 26–28 px text at 1080p, at most 3 lines.
- **Cut-in plates (step 16):** small rounded panels with name, `Lv`, HP bar and `hp / max`. A team-color stripe on the left edge says who is who; color is never the only cue, because the side of the screen also tells you.

## 7. Readability rules

| Rule | Value |
| --- | --- |
| Faction shown without color | Player base is a **light round ring**; enemy base is a **dark diamond**. Both tinted in team color, so shape *and* brightness differ (step 15: a notched ring did not survive the grayscale test) |
| Sprite size on the map | Sprite height = 1.15 × tile size; feet at 72% of the tile's height; may overlap the tile above |
| Never hidden | HP bar, cursor, range tints and the acting-unit ring are drawn **over** sprites |
| Text | ≥ 20 px at 1080p; contrast ≥ 4.5:1 on panels |
| Status | One icon bubble above the head; icon + letter (P, Z), never color only |
| Grayscale | Every battle screenshot must still show faction and acting unit in grayscale |
| Pixel art | Texture filter **Nearest**; scale by whole numbers where possible |

## 8. Asset specs

| Asset | Size | Layout | Path |
| --- | --- | --- | --- |
| Map sprite sheet | 48×64 per frame → 432×256 sheet | Columns: idle0, idle1, walk0–3, attack0–1, hurt. Rows: down, left, right, up | `assets/textures/units/<unit_id>.png` |
| Portrait | 256×256 | One file per mood | `assets/textures/portraits/<unit_id>.png`, `<unit_id>_<mood>.png` |
| Head icons | 24×24 | Bubble with a symbol: `poison` (drop), `sleep` (Z), `adv` (!, gold bubble), `bond` (heart); plus `leader` (star, no bubble) | `assets/textures/icons/head_<name>.png` |
| Battle pose | 192×192 per frame (64×64 pixel art ×3) | 11 frames in a row, facing **left**: idle 0–1, wind-up 2–3, strike 4–5, cast 6–8, hurt 9, dodge 10. Mirrored in code for the left side | `assets/textures/battle/<unit_id>.png` (2112×192) |
| Cut-in backdrop | 1280×600 (320×150 pixel art ×4), one layer | Sky bands, far mountains, a terrain-specific middle (trees, hills, dunes, shore, ruins), ground | `assets/textures/backdrops/<kind>.png`: plain, forest, hill, sand, shallow, ruins |

Ids match `data/` exactly. Every file has a line in `assets/CREDITS.md` with its author and license. If a file is missing, the game draws the old shapes instead.

## 9. Do / Don't

| Do | Don't |
| --- | --- |
| Invent each character from the tables above: class prop, own hair, skin and outfit colors | Copy or "redraw" a character, face, hairstyle and outfit combination, or a costume from any existing game |
| Use our flat navy + gold frame for every panel | Imitate another game's bevelled or metal UI frames, fonts or icon shapes |
| Use reference screenshots to talk about **format** (sprite on a map, two plates in a close-up, portrait beside text) | Commit reference screenshots, trace them, or pick colors from them |
| Keep team colors for team meaning only | Dress a neutral character in pure team blue or red |
| Keep placeholder and final art the same size and name | Change a file's layout without updating §8 and the generator |

## Changelog

- 2026-11-07 (step 16): battle poses (per unit, 11 frames) and 6 backdrops; close-up plates use the map's HP colors (green / yellow / red), never a flat bar color.
- 2026-11-07 (step 15): faction bases changed to a light round ring (players) and a dark diamond (enemies), after the notched ring failed the grayscale test. Head icons added.
- 2026-11-07: placeholder art generated by `tools/make_art.py` (15 sprite sheets, 21 portraits); art is found by id with `view/common/art.gd`.
- 2026-11-07: first version (step 13). Decided on 2D sprites on a 3D map; set the palette, character, portrait, frame and readability rules, and the asset specs.
