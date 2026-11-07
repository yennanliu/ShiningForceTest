#!/usr/bin/env python3
"""Portraits v2 (doc/05 §5, doc/03 step 19): illustrated busts, built as SVG from parts.

Standard library only, deterministic. Each speaker's look (class, skin, hair, eyes, extras) comes
from tools/art_palette.py; moods change only the eyes, brows and mouth. Original designs.
    python3 tools/make_portraits.py      -> assets/art_src/portraits/<id>[_<mood>].svg
Then tools/render_portraits.gd rasterizes them to assets/textures/portraits/*.png (256x256).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_palette as P  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "art_src", "portraits")
MOODS = ["neutral", "happy", "angry", "hurt", "determined"]

# Eye color per speaker (iris light, mid, dark) and the background tint.
EYES = {
    "aldric": ("#7fb0e6", "#3a66a8", "#1b2f5a"), "brina": ("#e8b65a", "#a8672a", "#5a3414"),
    "corin": ("#b07a4c", "#6b3e26", "#2a1810"), "dara": ("#b9a4e6", "#6e54a8", "#34245a"),
    "eamon": ("#9ad48a", "#4a8a46", "#1e3e1c"), "fiora": ("#d0a868", "#8a6a3a", "#3e2c14"),
    "garret": ("#a8774c", "#5c3a1e", "#24140a"), "hale": ("#a8c0d0", "#5c7890", "#283848"),
    "goblin_chief": ("#fff27a", "#f2d24a", "#a88a1a"), "villager": ("#a87a54", "#5e4028", "#24160c"),
    "elder": ("#b8c4cc", "#7a8a96", "#3a444c"), "smith": ("#8a6444", "#4e3420", "#1e120a"),
    "mayor": ("#8ab0d8", "#4a6c98", "#1e2e48"), "child": ("#e8b65a", "#a8672a", "#5a3414"),
    "hunter": ("#b8c880", "#6a7a3a", "#2c3418"),
}
SCAR = {"aldric"}


def hx(c):
    return "#%02x%02x%02x" % (c[0], c[1], c[2])


def shade(c, f=0.75):
    return (int(c[0] * f), int(c[1] * f), int(c[2] * f), 255)


def lighten(c, t=0.3):
    return tuple(int(c[i] + (255 - c[i]) * t) for i in range(3)) + (255,)


def grad(gid, top, bottom, x2="0", y2="1"):
    return ('<linearGradient id="%s" x1="0" y1="0" x2="%s" y2="%s"><stop offset="0" stop-color="%s"/>'
            '<stop offset="1" stop-color="%s"/></linearGradient>' % (gid, x2, y2, top, bottom))


def build(cid, mood="neutral"):
    cls, team, skin_k, hair_k, style, outfit_k, extra = P.CHARACTERS[cid]
    skin = P.SKIN[skin_k]
    hair = P.HAIR.get(hair_k, P.HAIR["black"])
    cloth = P.CLOTH.get(outfit_k, P.CLOTH["slate"])
    trim = P.team_color(team)
    goblin = skin_k == "goblin"
    eyes = EYES.get(cid, ("#a87a54", "#5e4028", "#24160c"))
    bg_top = hx(lighten(shade(cloth, 0.55), 0.15))
    bg_bot = hx(shade(cloth, 0.22))
    defs = [
        grad("bg", bg_top, bg_bot),
        '<radialGradient id="glow" cx="0.55" cy="0.4" r="0.5"><stop offset="0" stop-color="%s" stop-opacity="0.5"/>'
        '<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>' % (hx(lighten(cloth, 0.4)), hx(lighten(cloth, 0.4))),
        grad("skin", hx(lighten(skin, 0.18)), hx(shade(skin, 0.92)), "1", "1"),
        grad("hair", hx(lighten(hair, 0.12)), hx(shade(hair, 0.62)), "1", "1"),
        grad("cloth", hx(lighten(cloth, 0.12)), hx(shade(cloth, 0.62)), "1", "1"),
        grad("steel", "#d7dee6", "#5c6470", "1", "1"),
        '<radialGradient id="iris" cx="0.45" cy="0.4" r="0.6"><stop offset="0" stop-color="%s"/>'
        '<stop offset="0.6" stop-color="%s"/><stop offset="1" stop-color="%s"/></radialGradient>' % eyes,
    ]
    sk_sh = hx(shade(skin, 0.82))
    hair_hi = hx(lighten(hair, 0.4))
    hair_dk = hx(shade(hair, 0.55))
    team_hex = hx(trim) if trim else None
    b = []   # body parts, back to front
    b.append('<rect width="512" height="512" fill="url(#bg)"/><rect width="512" height="512" fill="url(#glow)"/>')

    # hair behind the head
    if style == "long":
        b.append('<path d="M156,190 C130,270 132,360 156,430 L214,430 L206,240 Z" fill="%s"/>' % hair_dk)
        b.append('<path d="M370,200 C392,270 386,350 362,420 L322,420 L328,240 Z" fill="%s"/>' % hair_dk)
    if style == "tied":
        b.append('<path d="M150,210 C120,260 118,330 140,400 C150,430 166,440 176,430 C160,380 160,300 186,240 Z" fill="url(#hair)"/>')
        b.append('<path d="M146,260 L176,270 M142,300 L172,308 M144,340 L172,346" stroke="%s" stroke-width="5" stroke-linecap="round"/>' % hair_dk)
    if style == "bob":
        b.append('<path d="M156,200 C150,290 170,340 200,350 L200,240 Z" fill="%s"/>' % hair_dk)
        b.append('<path d="M368,206 C374,280 360,326 330,344 L326,240 Z" fill="%s"/>' % hair_dk)
    if style == "hood":
        b.append('<path d="M130,250 C120,140 190,70 268,70 C350,72 404,130 396,240 C392,300 370,350 340,380 L176,380 C150,350 134,300 130,250 Z" fill="%s"/>' % hx(shade(cloth, 0.7)))

    # shoulders / outfit by class
    if cls == "knight":
        b.append('<path d="M40,512 C60,432 136,396 200,386 L320,386 C396,396 462,432 480,512 Z" fill="#7a5236"/>')
        b.append('<path d="M168,420 C210,396 302,396 344,420 L360,512 L152,512 Z" fill="url(#steel)"/>')
        b.append('<ellipse cx="112" cy="440" rx="80" ry="46" fill="url(#steel)"/><ellipse cx="404" cy="440" rx="80" ry="46" fill="url(#steel)"/>')
        b.append('<path d="M60,428 C90,410 140,408 170,422" stroke="#eef2f6" stroke-width="4" fill="none" opacity="0.7"/>')
        if team_hex:
            b.append('<path d="M256,440 L274,456 L256,486 L238,456 Z" fill="%s" stroke="#1f2a46" stroke-width="3"/>' % team_hex)
    elif cls in ("cleric", "mage"):
        b.append('<path d="M36,512 C58,430 132,394 198,384 L322,384 C396,394 460,430 482,512 Z" fill="url(#cloth)"/>')
        b.append('<path d="M120,430 C170,398 220,392 256,404 C292,392 344,398 394,430 L410,470 C350,440 300,434 256,446 C212,434 162,440 104,470 Z" fill="%s"/>' % hx(shade(cloth, 0.8)))
        if team_hex:
            b.append('<path d="M112,460 C168,432 216,428 256,440 C298,428 346,432 402,460" stroke="%s" stroke-width="7" fill="none"/>' % team_hex)
    elif cls == "warrior":
        b.append('<path d="M30,512 C50,430 124,392 196,380 L330,380 C402,392 468,430 488,512 Z" fill="url(#skin)"/>')
        b.append('<path d="M60,512 C90,460 130,430 170,420" stroke="%s" stroke-width="14" fill="none" opacity="0.55"/>' % sk_sh)
        b.append('<path d="M150,512 L350,404 L374,420 L186,512 Z" fill="#5e3c1a"/>')
        b.append('<path d="M110,420 C140,384 200,372 256,384 C312,372 372,384 402,420 C370,412 360,430 330,418 C310,436 290,420 256,432 C222,420 202,436 182,418 C152,430 142,412 110,420 Z" fill="#4a3a30"/>')
        if team_hex:
            b.append('<path d="M200,512 L360,430 L372,446 L224,512 Z" fill="%s"/>' % team_hex)
    else:   # swordsman, archer, civilian: a tunic
        b.append('<path d="M30,512 C52,430 128,392 196,380 L330,380 C402,392 466,430 488,512 Z" fill="url(#cloth)"/>')
        if cls == "swordsman" and team_hex:
            b.append('<path d="M150,400 C190,372 230,368 256,382 C286,368 330,372 368,400 L350,430 C320,410 290,408 256,420 C224,408 194,410 166,430 Z" fill="%s"/>' % team_hex)
        if cls in ("swordsman", "archer"):
            b.append('<path d="M170,512 L330,402 L350,416 L198,512 Z" fill="#6b4a32"/>')
        if cls == "archer":
            b.append('<path d="M86,400 L72,330 M100,396 L92,322 M114,394 L112,318" stroke="#e8e0cc" stroke-width="6" stroke-linecap="round"/>')
            if team_hex:
                b.append('<path d="M196,388 C224,402 288,402 318,388 L314,398 C284,412 228,412 200,398 Z" fill="%s"/>' % team_hex)
        if extra.get("apron"):
            b.append('<path d="M176,420 L336,420 L350,512 L162,512 Z" fill="#e8e0cc"/>')
        if cls == "civilian" and not extra.get("apron"):
            b.append('<path d="M222,384 L256,420 L290,384" stroke="%s" stroke-width="6" fill="none"/>' % hx(shade(cloth, 0.6)))
    if extra.get("scarf"):
        b.append('<path d="M196,372 C230,392 290,392 320,372 L326,398 C290,420 226,420 192,398 Z" fill="#b07a3a"/>')

    # neck, ears, face
    b.append('<path d="M220,302 L296,302 L300,392 C278,400 238,400 216,392 Z" fill="%s"/>' % sk_sh)
    if goblin:
        b.append('<path d="M368,216 C410,180 468,156 498,150 C470,190 430,232 376,258 Z" fill="%s"/>' % sk_sh)
        b.append('<path d="M176,210 C130,170 66,146 30,140 C60,186 110,236 172,262 Z" fill="url(#skin)"/>')
    elif style != "hood":
        b.append('<ellipse cx="182" cy="236" rx="16" ry="26" fill="%s"/>' % sk_sh)
    b.append('<path d="M178,198 C172,130 232,92 288,98 C348,106 372,160 366,222 C360,276 334,320 296,338 C274,348 248,346 228,334 C194,314 180,264 178,198 Z" fill="url(#skin)"/>')
    b.append('<path d="M184,212 C188,262 204,304 232,328 C214,330 194,298 188,262 Z" fill="%s" opacity="0.55"/>' % sk_sh)
    if not goblin:
        b.append('<ellipse cx="318" cy="268" rx="17" ry="8" fill="#f08a7a" opacity="%s"/>' % ("0.4" if mood == "happy" else "0.22"))
    if cid in SCAR:
        b.append('<path d="M332,250 L344,262" stroke="#c98a72" stroke-width="3" stroke-linecap="round"/>')
    if goblin:
        b.append('<path d="M206,200 L262,212 M286,212 L346,198" stroke="#c8423a" stroke-width="9" stroke-linecap="round" opacity="0.85"/>')

    b.extend(_face(mood, goblin, hx(shade(hair, 0.7)) if hair_k else "#3a2a20", sk_sh))

    # beard / mask under the hair
    if extra.get("beard"):
        b.append('<path d="M218,318 C236,350 254,394 270,410 C286,394 316,352 330,320 C300,340 252,340 218,318 Z" fill="%s"/>' % hx(shade(hair, 0.8)))

    # front hair by style
    if style == "short":
        b.append('<path d="M166,214 C150,130 204,60 284,62 C356,64 398,116 384,196 C376,168 360,146 336,132 C300,150 254,150 220,132 C200,150 188,178 186,214 Z" fill="url(#hair)"/>')
        b.append('<path d="M214,108 C250,86 300,84 336,98" stroke="%s" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.9"/>' % hair_hi)
        b.append('<path d="M226,128 C244,116 262,112 280,114" stroke="%s" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.7"/>' % hair_hi)
        b.append('<path d="M172,170 C172,200 178,222 186,236 L180,236 C168,214 164,190 166,170 Z" fill="%s"/>' % hair_dk)
    elif style == "tied":
        b.append('<path d="M168,212 C156,130 212,70 286,72 C356,76 394,128 380,196 C366,160 336,132 296,124 C258,120 222,132 200,160 C188,176 184,196 186,214 Z" fill="url(#hair)"/>')
        b.append('<path d="M220,96 C260,80 330,86 364,124" stroke="%s" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.8"/>' % hair_hi)
        b.append('<path d="M352,140 C364,160 368,186 366,206" stroke="%s" stroke-width="4" fill="none" stroke-linecap="round"/>' % hair_dk)
    elif style == "spiky":
        b.append('<path d="M166,214 C150,140 190,96 230,84 L222,40 L258,76 L272,30 L292,74 L326,40 L322,86 L366,70 L350,110 C384,130 394,170 384,200 C372,170 356,150 334,138 C300,152 254,150 220,134 C200,152 188,180 186,214 Z" fill="url(#hair)"/>')
        b.append('<path d="M232,100 C258,88 300,88 330,100" stroke="%s" stroke-width="6" fill="none" stroke-linecap="round" opacity="0.8"/>' % hair_hi)
    elif style == "bob":
        b.append('<path d="M168,210 C152,128 212,68 288,70 C360,74 396,128 384,206 C378,176 368,158 352,146 L350,184 L330,150 L318,186 L300,148 L284,184 L268,148 L250,184 L236,150 L220,186 C210,166 196,160 190,170 C184,184 182,198 184,214 Z" fill="url(#hair)"/>')
        b.append('<path d="M220,92 C262,76 332,82 366,120" stroke="%s" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.85"/>' % hair_hi)
    elif style == "long":
        b.append('<path d="M164,216 C148,128 210,64 288,66 C362,70 400,126 386,204 C370,168 340,140 300,132 C268,150 236,170 214,200 C200,220 192,260 196,300 L176,300 C166,272 162,244 164,216 Z" fill="url(#hair)"/>')
        b.append('<path d="M226,90 C266,74 334,82 368,120" stroke="%s" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.8"/>' % hair_hi)
        b.append('<path d="M300,132 C320,150 338,170 352,196" stroke="%s" stroke-width="4" fill="none" stroke-linecap="round"/>' % hair_dk)
    elif style == "bald":
        b.append('<ellipse cx="250" cy="118" rx="38" ry="12" fill="#ffffff" opacity="0.25"/>')
    elif style == "hood":
        b.append('<path d="M150,250 C142,160 200,96 268,96 C340,98 390,150 384,240 C362,190 330,160 300,152 C260,146 214,160 190,190 C176,210 170,232 172,256 Z" fill="%s"/>' % hx(shade(cloth, 0.8)))

    # class headgear and extras
    if cls == "knight":
        b.append('<path d="M176,168 C220,140 320,136 378,164" stroke="url(#steel)" stroke-width="12" fill="none" stroke-linecap="round"/>')
        if team_hex:
            b.append('<circle cx="276" cy="146" r="8" fill="%s" stroke="#1f2a46" stroke-width="3"/>' % team_hex)
    if cls == "mage":
        b.append('<ellipse cx="270" cy="128" rx="150" ry="26" fill="url(#cloth)"/>')
        b.append('<path d="M178,126 C220,60 280,10 360,-6 C330,40 340,90 362,124 Z" fill="url(#cloth)"/>')
        if team_hex:
            b.append('<path d="M186,118 C240,104 300,104 356,116" stroke="%s" stroke-width="8" fill="none"/>' % team_hex)
    if extra.get("horns"):
        b.append('<path d="M202,112 C176,74 172,40 188,14 C204,52 220,80 236,100 Z" fill="#efe6cc"/>')
        b.append('<path d="M318,104 C346,70 356,36 344,8 C324,44 306,72 288,94 Z" fill="#efe6cc"/>')
    if team_hex and cls not in ("knight", "mage", "warrior", "cleric", "archer", "swordsman"):
        pass
    # rim light from the top left
    b.append('<path d="M178,196 C174,146 200,104 244,86" stroke="#fff1d6" stroke-width="3" fill="none" opacity="0.45" stroke-linecap="round"/>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512"><defs>%s</defs>%s</svg>'
            % ("".join(defs), "".join(b)))


def _face(mood, goblin, brow, sk_sh):
    """Eyes, brows, nose and mouth for a mood (three-quarter view, facing right)."""
    out = []
    near, far = (306, 220), (234, 220)
    if mood == "happy":
        out.append('<path d="M280,224 C292,206 320,206 334,222" stroke="#2a1a12" stroke-width="6" fill="none" stroke-linecap="round"/>')
        out.append('<path d="M214,224 C224,210 242,210 252,222" stroke="#2a1a12" stroke-width="5" fill="none" stroke-linecap="round"/>')
    else:
        lid = {"angry": 8, "determined": 4, "hurt": 3}.get(mood, 0)
        for (cx, cy), w, r in ((near, 30, 13), (far, 20, 10)):
            if mood == "hurt" and (cx, cy) == near:   # this eye squeezed shut
                out.append('<path d="M%d,%d C%d,%d %d,%d %d,%d" stroke="#2a1a12" stroke-width="5" fill="none" stroke-linecap="round"/>'
                           % (cx - w, cy + 2, cx - 8, cy - 6, cx + 8, cy - 6, cx + w, cy + 4))
                continue
            out.append('<path d="M%d,%d C%d,%d %d,%d %d,%d C%d,%d %d,%d %d,%d Z" fill="%s"/>'
                       % (cx - w, cy, cx - w + 12, cy - 14 + lid, cx + w - 10, cy - 16 + lid, cx + w + 2, cy - 4 + lid // 2,
                          cx + w - 6, cy + 16, cx - w + 12, cy + 18, cx - w, cy + 6, "#f2d24a" if goblin else "#fbf8f2"))
            if goblin:
                out.append('<path d="M%d,%d C%d,%d %d,%d %d,%d C%d,%d %d,%d %d,%d Z" fill="#1a0a0a"/>'
                           % (cx, cy - 10 + lid, cx - 4, cy - 2, cx - 4, cy + 6, cx, cy + 12, cx + 4, cy + 6, cx + 4, cy - 2, cx, cy - 10 + lid))
            else:
                out.append('<circle cx="%d" cy="%d" r="%d" fill="url(#iris)"/>' % (cx, cy + 1, r))
                out.append('<circle cx="%d" cy="%d" r="%d" fill="#0d1018"/>' % (cx, cy + 2, r // 2))
                out.append('<circle cx="%d" cy="%d" r="%d" fill="#ffffff"/>' % (cx - r // 3, cy - r // 3, max(2, r // 3)))
            out.append('<path d="M%d,%d C%d,%d %d,%d %d,%d" stroke="#2a1a12" stroke-width="%d" fill="none" stroke-linecap="round"/>'
                       % (cx - w - 4, cy - 4 + lid, cx - w + 12, cy - 18 + lid, cx + w - 8, cy - 20 + lid, cx + w + 6, cy - 6 + lid // 2, 5 if w > 25 else 4))
    # brows
    if mood == "angry":
        out.append('<path d="M278,186 C298,190 320,198 340,206" stroke="%s" stroke-width="8" fill="none" stroke-linecap="round"/>' % brow)
        out.append('<path d="M210,200 C226,194 242,190 256,190" stroke="%s" stroke-width="7" fill="none" stroke-linecap="round"/>' % brow)
    elif mood == "hurt":
        out.append('<path d="M280,184 C298,178 318,184 338,196" stroke="%s" stroke-width="7" fill="none" stroke-linecap="round"/>' % brow)
        out.append('<path d="M212,196 C226,186 242,182 254,184" stroke="%s" stroke-width="6" fill="none" stroke-linecap="round"/>' % brow)
    elif mood == "determined":
        out.append('<path d="M278,188 C298,188 320,192 340,198" stroke="%s" stroke-width="8" fill="none" stroke-linecap="round"/>' % brow)
        out.append('<path d="M210,194 C224,192 242,192 256,194" stroke="%s" stroke-width="7" fill="none" stroke-linecap="round"/>' % brow)
    else:
        out.append('<path d="M276,190 C296,180 322,180 342,190" stroke="%s" stroke-width="7" fill="none" stroke-linecap="round"/>' % brow)
        out.append('<path d="M210,192 C224,184 242,184 254,190" stroke="%s" stroke-width="6" fill="none" stroke-linecap="round"/>' % brow)
    # nose
    out.append('<path d="M288,238 C294,254 300,262 296,272 C290,276 282,274 278,270" stroke="%s" stroke-width="4" fill="none" stroke-linecap="round"/>' % sk_sh)
    # mouth
    lip = "#4a1e14" if goblin else "#a5624f"
    if mood == "happy":
        out.append('<path d="M264,292 C278,310 300,310 312,290 C298,298 278,298 264,292 Z" fill="#7a3a2e"/>')
    elif mood == "angry":
        out.append('<path d="M262,306 C276,296 298,296 312,306" stroke="%s" stroke-width="5" fill="none" stroke-linecap="round"/>' % lip)
        if goblin:
            out.append('<path d="M272,300 L276,314 L282,300 M296,300 L300,314 L306,302" fill="#f6f0de"/>')
    elif mood == "hurt":
        out.append('<ellipse cx="290" cy="302" rx="12" ry="7" fill="#5a2a22"/>')
    elif mood == "determined":
        out.append('<path d="M266,300 C280,298 298,298 310,300" stroke="%s" stroke-width="5" fill="none" stroke-linecap="round"/>' % lip)
    else:
        out.append('<path d="M268,298 C280,304 296,304 308,296" stroke="%s" stroke-width="4" fill="none" stroke-linecap="round"/>' % lip)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for cid in P.PORTRAITS:
        for mood in MOODS:
            name = cid if mood == "neutral" else "%s_%s" % (cid, mood)
            with open(os.path.join(OUT, name + ".svg"), "w") as f:
                f.write(build(cid, mood))
            n += 1
    print("portrait sources written: %d (%d speakers x %d moods)" % (n, len(P.PORTRAITS), len(MOODS)))


if __name__ == "__main__":
    main()
