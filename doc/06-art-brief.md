# 06 · Art Brief: character portraits

What an outside artist needs to quote on and deliver the final character portraits for Project Banner. The placeholder portraits in the game today (`tools/make_portraits.py`) set the layout and style target; the final art replaces them file for file.

| | |
| --- | --- |
| Audience | Commissioned artist, owner |
| Owner | `game-2d-3d-artist` (brief), owner (commission, ⏳) |
| Related | [05 Art Direction §5](05-art-direction.md#5-portraits) · [04 IP guardrails](04-research-and-references.md#4-ip-guardrails) · `assets/CREDITS.md` |
| As of | 2026-11-07 |

---

## 1. What we're making

Head-and-shoulders **bust portraits** in a clean, illustrated style: soft shading in 3–4 steps, expressive eyes with a highlight, hair drawn as strands with one highlight band, a rim light from the top left, and a simple background in a darker shade of the character's colors. Each character faces **to the right, three-quarter view**. The game mirrors enemies so they face left.

They appear in framed cards (doc/05 §6), shown at 64–600 px, so they must read at thumbnail size: a clear silhouette, clear hair shape, and an eye line at about 40% of the height.

## 2. Characters and moods

**15 characters × 5 moods = 75 images.** Moods change only the eyes, brows and mouth. Pose, lighting and framing stay the same across a character's moods.

| Mood | Read |
| --- | --- |
| neutral | Calm, attentive |
| happy | Eyes smiling (closed arcs or squint), open smile |
| angry | Brows down toward the nose, narrowed eyes, tight mouth |
| hurt | One eye squeezed, brows raised in the middle, mouth open |
| determined | Level, slightly narrowed eyes, straight brows, firm mouth |

Each character's look is in `data/units/<id>.tres` (`look`) and `tools/art_palette.py`. Party members:

| Id | Class | Look |
| --- | --- | --- |
| aldric | Swordsman, leader | Brown hair swept back, steel-blue eyes, small scar on the left cheek; slate tunic, blue cape collar, sword at the hip |
| brina | Knight | Flaxen hair in a braid, amber eyes, steel circlet with a blue stone; leather and steel plate, square shield |
| corin | Archer | Short black spiky hair, dark brown eyes; moss-green tunic, quiver, blue collar trim |
| dara | Cleric | Silver bob with a straight fringe, violet eyes, small brass hair pin; linen robe, heather mantle with a blue stripe |
| eamon | Mage | Plum hair under a wide pointed hat, green eyes; heather robe, blue band on the hat |
| fiora | Swordsman | Long copper hair, hazel eyes; ochre tunic, blue cape collar |
| garret | Warrior | Bald, thick black beard, brown eyes; bare shoulders, fur collar, blue sash |
| hale | Archer | Short flaxen hair, grey-blue eyes; slate tunic, ochre scarf, quiver |

Others:
- **goblin_chief:** green skin, long pointed ears, ivory horns, yellow slit eyes, black beard, red war paint, red sash
- **villager:** brown hair, linen tunic
- **elder:** bald, grey beard, heather robe
- **smith:** black hair, leather apron
- **mayor:** brown hair, ochre coat
- **child:** copper spiky hair, moss tunic
- **hunter:** black tied hair, moss tunic

**Team colors:** the party wears exactly **one** blue (`#3b6fd8`) element, and enemies one red (`#c8423a`). Townspeople wear neither. Never use pure team blue or red for anything else (doc/05 §3).

## 3. Technical

| | |
| --- | --- |
| Master | 512×512 px, layered source (PSD, Krita, Procreate or SVG), delivered as well |
| Game file | 256×256 PNG, sRGB, no transparency (the background is part of the portrait) |
| Names | `<id>.png` (neutral), `<id>_<mood>.png`, e.g. `brina_angry.png` |
| Folder | `assets/textures/portraits/` (replace the placeholders; the code needs no change) |
| Safe area | Keep the face inside the middle 70%; frames crop about 4% at the edges and can cover the bottom corners |
| Consistency | Same head size and eye height for every character (use the placeholders as a guide) |

## 4. Originality and rights

- **Original work only.** Never draw, trace, paint over or "redraw" characters, faces, costumes or frames from any existing game, including the genre reference named in doc/04. Talking about genre conventions (a detailed bust in a frame) is fine; copying expression is not.
- No AI-generated images unless the owner agrees in writing first, with a license check and an IP review (doc/04 §4).
- **Rights:** work-for-hire, or an exclusive, perpetual, worldwide license for the game and its marketing. The artist may show the work in a portfolio after release.
- Each delivered file gets a line in `assets/CREDITS.md` (artist, license).

## 5. Process

1. **Quote:** for the 75 images, or the 8 party members first (40 images).
2. **Sketch round:** neutral roughs of 3 characters (Aldric, Brina, Goblin Chief). The owner and `game-art-design` review them against doc/05 and this brief.
3. **Final:** neutral for all, then the moods. The owner reviews each batch in the game: run `godot --path .`, open Camp → Profile.
4. **Hand-off:** PNGs, source files, and a signed license.
