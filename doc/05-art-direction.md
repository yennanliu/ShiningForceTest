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

**Style v2** (step 19; the target is the design example and [doc/06](06-art-brief.md)): illustrated busts, not pixel art.

- **Framing:** head and shoulders, three-quarter view facing right (enemies mirrored in code). The head fills about 55% of the height, with eyes at about 42%.
- **Rendering:** soft gradients in 3–4 steps on skin, hair and cloth. Irises have 2 tones, a pupil and a white highlight. Hair is drawn as strands with one highlight band. A thin warm rim light comes from the top left, with a faint blush on the near cheek.
- **Background:** a vertical gradient in a darker version of the outfit color, with a soft glow behind the head.
- **Team color:** exactly one element per character: a cape collar, sash, emblem or trim. None for townspeople.
- **Moods:** `neutral` (required), `happy`, `angry`, `hurt`, `determined`. Only eyes, brows and mouth change.
- **Placeholders** come from `tools/make_portraits.py` (SVG, built from the class outfit and each character's look) and are rasterized by `tools/render_portraits.gd` to 256×256. A final artist works at 512 and delivers 256 (doc/06).
- **Display:** the Linear filter; they're shown at 64–600 px.

## 6. UI frames

**The Banner frame** (step 18; the target look is the design example canvas, *Banner UI Style Frames*). One 9-slice texture family from `tools/make_art.py` (`assets/ui/`), applied by one theme (`view/common/banner_theme.gd` → `assets/ui/banner_theme.tres`). Layers, outside in:

1. **Gold rim**, 2 px (`#e2cd8e`), lit on its top half (`#f6e6b0`) and darker below (`#b39a5a`)
2. **Dark line**, 2 px (`#0a1130`)
3. **Navy field**, a vertical gradient `#1f3270` → `#121c44`, with a soft **inner shadow** under the top edge
4. **Pennant notch** (26×16 gold pennant) at the top center: our motif, drawn on the frame
5. **Team ribbon** (blue / red stripe) on cards that belong to a side

| Weight | Use | Theme variation |
| --- | --- | --- |
| Panel | Menus, the battle side panel, dialogue text | `PanelContainer` default |
| Card | Portraits, plates, profile cards (3 px rim) | `BannerCard`, `PortraitFrame`, `PlateCard` |
| Chip | Tags such as "! Advantage", statuses | `BannerChip` |

**Buttons:** normal (bronze rim), hover (gold rim, lifts 4%), pressed (deeper field, squashes), disabled (dim), and a **gold focus ring** (3 px, `#ffd34a`) on whatever has keyboard / gamepad focus. One **primary** button per screen is solid gold with dark Cinzel text (`PrimaryButton`).

**Fonts:**
- **Cinzel** (display: titles, names, primary buttons) and **Inter** (body), both SIL OFL, in `assets/fonts/` with their license files
- `UI.label` switches to Cinzel from 30 px up; body text stays ≥ 20 px at 1080p

**Motion:** 0.12 s + 0.16 s fade between screens (`Transition` autoload), button lift and squash, panels fading in. All scaled by the animation speed; none when it's *skip* or headless.

**Sound:** hover, confirm, cancel and open ticks (placeholder, `tools/make_audio.py`), silent while debugging.

- **Dialogue box:** a portrait in a card frame with the pennant, then the speaker's name in Cinzel, then the text in a panel. 26–28 px text at 1080p, at most 3 lines.
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
| Portrait | 256×256 (from a 512 master) | 5 moods per speaker | `assets/textures/portraits/<id>.png`, `<id>_<mood>.png`; sources `assets/art_src/portraits/*.svg` |
| Item icon | 24×24 | One per item: the shape says the kind (sword, spear, axe, bow, staff, leaf, seed, vial, ring) | `assets/textures/icons/item_<item_id>.png` |
| Tile top (3D map) | 32×32 | One per terrain, tiles seamlessly; box sides use the terrain color darkened | `assets/textures/tiles/<terrain>.png` |
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

- 2026-11-07 (step 19): portraits v2 (illustrated busts, 5 moods, §5); item icons; artist brief in doc/06.
- 2026-11-07 (step 18): §6 rewritten: the Banner frame (rim, dark line, navy gradient, inner shadow, pennant, ribbon), button states, focus ring, primary button, Cinzel + Inter, motion and UI sounds.
- 2026-11-07 (step 17): 3D map. Tile tops (32×32), faction bases as 3D meshes (ring / diamond), shadow discs, and a faint checker for the grid.
- 2026-11-07 (step 16): battle poses (per unit, 11 frames) and 6 backdrops; close-up plates use the map's HP colors (green / yellow / red), never a flat bar color.
- 2026-11-07 (step 15): faction bases changed to a light round ring (players) and a dark diamond (enemies), after the notched ring failed the grayscale test. Head icons added.
- 2026-11-07: placeholder art generated by `tools/make_art.py` (15 sprite sheets, 21 portraits); art is found by id with `view/common/art.gd`.
- 2026-11-07: first version (step 13). Decided on 2D sprites on a 3D map; set the palette, character, portrait, frame and readability rules, and the asset specs.
