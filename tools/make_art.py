#!/usr/bin/env python3
"""Generates placeholder pixel art (doc/05): map sprite sheets and dialogue portraits.

Standard library only, deterministic (same output bytes every run). Original designs,
built from the class silhouettes and character looks in tools/art_palette.py.
    python3 tools/make_art.py
Outputs:
    assets/textures/units/<id>.png          432x256 sheet: 9 frames x 4 directions of 48x64
    assets/textures/portraits/<id>.png      256x256 (drawn on 64x64, scaled x4); <id>_<mood>.png
    assets/textures/icons/head_<name>.png   24x24 head bubbles: poison, sleep, adv, bond; leader star
    assets/textures/battle/<id>.png         2112x192 cut-in poses: 11 frames of 192x192, facing left
    assets/textures/backdrops/<kind>.png    1280x600 cut-in backdrops (plain, forest, hill, sand, shallow, ruins)
Final art replaces these files one for one (same names and sizes).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel import Canvas, shade, light, hexc  # noqa: E402
import art_palette as P  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FW, FH = 48, 64
DIRS = ["down", "left", "right", "up"]
# column -> pose: bob (px down), step (-1/0/1), arm (rest/raise/thrust), lean (px), hurt
POSES = [
    dict(bob=0), dict(bob=1),                                      # idle
    dict(step=-1), dict(step=0, bob=1), dict(step=1), dict(step=0, bob=1),  # walk
    dict(arm="raise"), dict(arm="thrust", lean=2),                 # attack
    dict(hurt=True, lean=-2),                                      # hurt
]


class Look:
    def __init__(self, cid):
        cls, team, skin, hair, style, outfit, extra = P.CHARACTERS[cid]
        self.id, self.cls, self.team, self.style, self.extra = cid, cls, team, style, extra
        self.skin = P.SKIN.get(skin) if skin else None
        self.hair = P.HAIR.get(hair) if hair else None
        self.cloth = P.CLOTH.get(outfit) if outfit else None
        self.trim = P.team_color(team)
        self.robe = cls in ("cleric", "mage")


# --- map sprites --------------------------------------------------------------

def _prop_behind(c, lk, d, pose, oy):
    """Props drawn before the body (on the back / far side)."""
    if lk.cls == "swordsman" and lk.trim and d in ("down", "up", "left"):
        if d == "up":
            c.rect(14, 36 + oy, 34, 56 + oy, lk.trim)
            c.rect(14, 36 + oy, 15, 56 + oy, shade(lk.trim))
        elif d == "down":
            c.rect(14, 38 + oy, 34, 54 + oy, shade(lk.trim))
        else:
            c.poly([(26, 37 + oy), (33, 37 + oy), (36, 56 + oy), (27, 56 + oy)], lk.trim)
    if lk.cls == "archer" and pose.get("arm", "rest") == "rest":
        bow = P.CLOTH["leather"]
        if d == "up":
            c.rect(20, 32 + oy, 23, 46 + oy, P.CLOTH["leather"])  # quiver
            c.line(14, 30 + oy, 33, 50 + oy, bow, 2)
        else:
            c.line(31, 28 + oy, 36, 34 + oy, bow, 2)


def _head(c, lk, d, oy, hurt):
    cx = 24 if d in ("down", "up") else 23
    cy = 25 + oy
    sk = lk.skin
    if lk.extra.get("ears"):
        for s in ((-1,) if d == "left" else (-1, 1)) if d != "up" else (-1, 1):
            ex = cx + s * 10
            c.poly([(ex, cy - 2), (ex + s * 8, cy - 7), (ex, cy + 3)], sk)
    c.ellipse(cx, cy, 11 if d in ("down", "up") else 10, 11, sk)
    c.rect(cx + 6, cy - 3, cx + 9, cy + 6, shade(sk)) if d == "down" else None
    style, hc = lk.style, lk.hair
    if d == "up":
        if style == "hood":
            c.ellipse(cx, cy, 12, 12, shade(lk.cloth))
        elif style != "bald":
            c.ellipse(cx, cy - 1, 11, 11, hc)
            if style in ("long", "tied", "bob"):
                c.rect(cx - 8, cy, cx + 8, cy + (12 if style == "long" else 7), hc)
    else:
        top = cy - 11
        if style == "hood":
            c.ellipse(cx + (2 if d == "left" else 0), cy - 2, 12, 11, shade(lk.cloth))
            c.ellipse(cx - (2 if d == "left" else 0), cy + 2, 8, 8, sk)
        elif style != "bald":
            c.ellipse(cx + (3 if d == "left" else 0), cy - 6, 11, 6, hc)   # cap stops above the eyes
            if d == "down":
                c.rect(cx - 9, cy - 5, cx + 9, cy - 3, hc)  # fringe
            if style == "spiky":
                for k in range(-8, 9, 4):
                    c.poly([(cx + k - 2, top + 3), (cx + k, top - 3), (cx + k + 2, top + 3)], hc)
            if style == "long":
                xs = (cx + 5, cx + 11) if d == "left" else (cx - 11, cx + 11)
                c.rect(xs[0], cy - 2, xs[0] + 3, cy + 12, hc)
                c.rect(xs[1] - 3, cy - 2, xs[1], cy + 12, hc)
            if style == "tied":
                c.ellipse(cx + (11 if d == "left" else 0), cy + (0 if d == "left" else -12), 3, 4, hc)
            if style == "bob":
                c.rect(cx - 11 + (6 if d == "left" else 0), cy - 3, cx + 10, cy + 5, hc)
                c.ellipse(cx - (2 if d == "left" else 0), cy + 2, 7, 6, sk)
        if lk.extra.get("beard"):
            c.ellipse(cx - (3 if d == "left" else 0), cy + 8, 6, 3, hc if hc else P.HAIR["black"])
        if lk.extra.get("mask"):
            c.rect(cx - 9 - (2 if d == "left" else 0), cy + 3, cx + 9, cy + 7, shade(lk.cloth))
        # eyes
        if hurt:
            if d == "down":
                c.rect(cx - 6, cy + 1, cx - 4, cy + 1, P.OUTLINE)
                c.rect(cx + 3, cy + 1, cx + 5, cy + 1, P.OUTLINE)
            else:
                c.rect(cx - 8, cy + 1, cx - 6, cy + 1, P.OUTLINE)
        elif d == "down":
            c.rect(cx - 5, cy, cx - 4, cy + 2, P.OUTLINE)
            c.rect(cx + 3, cy, cx + 4, cy + 2, P.OUTLINE)
        else:
            c.rect(cx - 7, cy, cx - 6, cy + 2, P.OUTLINE)
    # headgear
    if lk.cls == "knight":
        c.ellipse(cx, cy - 5, 12, 8, P.METAL["steel"])
        c.rect(cx - 12, cy - 4, cx + 12, cy - 3, P.METAL["dark"])
    if lk.cls == "mage":
        c.ellipse(cx, cy - 8, 15, 3, lk.cloth)
        c.poly([(cx - 8, cy - 8), (cx + (5 if d == "left" else 1), cy - 24), (cx + 8, cy - 8)], lk.cloth)
        c.rect(cx - 8, cy - 10, cx + 8, cy - 9, lk.trim or shade(lk.cloth))
    if lk.extra.get("horns"):
        c.poly([(cx - 9, cy - 7), (cx - 14, cy - 17), (cx - 6, cy - 10)], P.CLOTH["linen"])
        c.poly([(cx + 9, cy - 7), (cx + 14, cy - 17), (cx + 6, cy - 10)], P.CLOTH["linen"])


def _body(c, lk, d, pose, oy):
    cl, sk = lk.cloth, lk.skin
    side = d in ("left", "right")
    step = pose.get("step", 0)
    # legs / robe
    if lk.robe:
        c.poly([(16, 36 + oy), (32, 36 + oy), (35, 59), (13, 59)], cl)
        c.poly([(27, 36 + oy), (32, 36 + oy), (35, 59), (29, 59)], shade(cl))
        c.rect(18 + step, 58, 21 + step, 60, P.BOOT)
        c.rect(27 - step, 58, 30 - step, 60, P.BOOT)
    else:
        if side:
            c.rect(21 + 2 * step, 50 + oy, 24 + 2 * step, 60, shade(cl))
            c.rect(24 - 2 * step, 50 + oy, 27 - 2 * step, 60, cl)
            c.rect(20 + 2 * step, 57, 24 + 2 * step, 60, P.BOOT)
            c.rect(23 - 2 * step, 57, 27 - 2 * step, 60, P.BOOT)
        else:
            c.rect(18, 50 + oy, 22, 60 - max(0, step) * 2, shade(cl))
            c.rect(26, 50 + oy, 30, 60 - max(0, -step) * 2, shade(cl))
            c.rect(18, 57 - max(0, step) * 2, 22, 60 - max(0, step) * 2, P.BOOT)
            c.rect(26, 57 - max(0, -step) * 2, 30, 60 - max(0, -step) * 2, P.BOOT)
    # torso
    x0, x1 = (19, 29) if side else (15, 33)
    c.rect(x0, 36 + oy, x1, 51 + oy, cl)
    c.rect(x1 - 2, 36 + oy, x1, 51 + oy, shade(cl))
    c.rect(x0, 36 + oy, x1, 37 + oy, light(cl))
    c.rect(x0, 48 + oy, x1, 49 + oy, P.CLOTH["leather"] if lk.cloth != P.CLOTH["leather"] else shade(cl, 0.5))
    if lk.extra.get("apron"):
        c.rect(x0 + 3, 40 + oy, x1 - 3, 53 + oy, P.CLOTH["linen"])
    if lk.extra.get("scarf"):
        c.rect(x0, 35 + oy, x1, 38 + oy, P.CLOTH["ochre"])
    # team trim: a sash (swordsmen wear a cape, knights a shield emblem instead)
    if lk.trim and lk.cls not in ("swordsman", "knight") and not side and d == "down":
        c.line(x0 + 1, 37 + oy, x1 - 1, 47 + oy, lk.trim, 2)
    if lk.trim and lk.cls not in ("swordsman", "knight") and (side or d == "up"):
        c.rect(x0, 44 + oy, x1, 45 + oy, lk.trim)
    # arms
    arm = sk if lk.cls == "warrior" else cl
    raise_ = pose.get("arm") == "raise"
    if side:
        if raise_:
            c.rect(19, 30 + oy, 22, 40 + oy, arm)
        else:
            c.rect(21, 38 + oy, 24, 48 + oy, shade(arm))
            c.rect(21, 47 + oy, 24, 49 + oy, sk)
    else:
        c.rect(11, 37 + oy, 14, 47 + oy, arm)
        c.rect(11, 47 + oy, 14, 49 + oy, sk)
        if raise_:
            c.rect(34, 28 + oy, 37, 38 + oy, arm)
            c.rect(34, 26 + oy, 37, 28 + oy, sk)
        else:
            c.rect(34, 37 + oy, 37, 47 + oy, shade(arm))
            c.rect(34, 47 + oy, 37, 49 + oy, sk)


def _prop_front(c, lk, d, pose, oy):
    arm = pose.get("arm", "rest")
    side = d in ("left", "right")
    hx, hy = ((22, 48) if arm != "raise" else (20, 30)) if side else ((35, 48) if arm != "raise" else (35, 27))
    hy += oy
    st, dk, lt = P.METAL["steel"], P.METAL["dark"], P.CLOTH["leather"]
    if lk.cls == "swordsman":
        if arm == "raise":
            c.line(hx, hy, hx + (-4 if side else 4), hy - 16, st, 2)
        elif arm == "thrust":
            c.line(hx, hy - 2, hx - 14 if side else hx + 10, hy + (0 if side else 8), st, 2)
        else:
            c.line(hx + (0 if side else 2), hy - 3, hx + (0 if side else 2), hy + 9, st, 2)
        c.rect(hx - 2, hy - 1, hx + 2, hy, P.METAL["brass"])
    elif lk.cls == "knight":
        tip = (hx - 16, hy + 2) if (arm == "thrust" and side) else ((hx + 8, hy + 8) if arm == "thrust" else (hx + (0 if side else 2), hy - 30))
        c.line(hx + (0 if side else 2), hy + 10, tip[0], tip[1], lt, 1)
        c.poly([(tip[0] - 2, tip[1] + 3), (tip[0], tip[1] - 3), (tip[0] + 2, tip[1] + 3)], st)
        if d != "up":
            sx = 13 if side else 8
            c.rect(sx, 38 + oy, sx + 9, 52 + oy, st)
            c.rect(sx, 38 + oy, sx + 9, 39 + oy, light(st))
            c.rect(sx + 3, 42 + oy, sx + 6, 48 + oy, lk.trim or dk)
    elif lk.cls == "archer" and arm != "rest":
        bx = 10 if not side else 13
        c.line(bx + 2, 30 + oy, bx, 41 + oy, lt, 2)
        c.line(bx, 41 + oy, bx + 2, 52 + oy, lt, 2)
        c.line(bx + 3, 31 + oy, bx + 3, 51 + oy, P.WHITE, 1)
        if arm == "thrust":
            c.line(bx + 3, 41 + oy, bx + 14, 41 + oy, st, 1)
    elif lk.cls in ("cleric", "mage"):
        lift = -5 if arm == "raise" else 0
        c.line(hx + (0 if side else 3), hy - 22 + lift, hx + (0 if side else 3), hy + 11 + lift, lt, 2)
        top = (hx + (0 if side else 3), hy - 25 + lift)
        if lk.cls == "cleric":
            c.ellipse(top[0] + 0.5, top[1], 3, 3, st)
            c.ellipse(top[0] + 0.5, top[1], 1.5, 1.5, (0, 0, 0, 0))
        else:
            c.ellipse(top[0] + 0.5, top[1], 3, 3, light(lk.cloth, 0.5))
    elif lk.cls == "warrior":
        if arm == "thrust":
            a, b = (hx, hy - 4), (hx - 14, hy + 6) if side else (hx + 9, hy + 8)
        elif arm == "raise":
            a, b = (hx, hy + 4), (hx + (-2 if side else 2), hy - 14)
        else:
            a, b = (hx - 1, hy - 2), (hx + (-6 if side else 5), hy - 20)
        c.line(a[0], a[1], b[0], b[1], lt, 2)
        c.poly([(b[0] - 4, b[1] - 3), (b[0] + 4, b[1] - 4), (b[0] + 3, b[1] + 5), (b[0] - 3, b[1] + 4)], st)


def _wolf(c, d, pose):
    fur, dk = P.FUR, shade(P.FUR)
    step, oy = pose.get("step", 0), pose.get("bob", 0)
    lunge = -3 if pose.get("arm") == "thrust" else 0
    if d in ("left", "right"):
        for i, x in enumerate((14, 18, 30, 34)):
            s = step * (1 if i % 2 else -1)
            c.rect(x + s, 50, x + s + 2, 60, dk if i % 2 else fur)
        c.ellipse(25, 46 + oy, 14, 7, fur)
        c.poly([(37, 42 + oy), (46, 36 + oy), (40, 46 + oy)], fur)  # tail
        c.ellipse(12 + lunge, 40 + oy, 7, 6, fur)
        c.poly([(7 + lunge, 39 + oy), (1 + lunge, 43 + oy), (8 + lunge, 45 + oy)], fur)  # snout
        c.poly([(10 + lunge, 35 + oy), (12 + lunge, 28 + oy), (15 + lunge, 35 + oy)], dk)
        if not pose.get("hurt"):
            c.rect(9 + lunge, 39 + oy, 10 + lunge, 40 + oy, P.ENEMY)
    else:
        c.ellipse(24, 47 + oy, 10, 9, fur if d == "up" else dk)
        for x in (17, 29):
            c.rect(x + step, 52, x + step + 2, 60, dk)
        if d == "up":
            c.poly([(22, 40 + oy), (24, 30 + oy), (27, 40 + oy)], fur)
            c.ellipse(24, 38 + oy, 7, 6, dk)
        else:
            c.ellipse(24, 40 + oy - lunge, 8, 7, fur)
            c.ellipse(24, 45 + oy - lunge, 4, 3, light(fur))
            for s in (-1, 1):
                c.poly([(24 + s * 3, 35 + oy), (24 + s * 7, 28 + oy), (24 + s * 8, 37 + oy)], dk)
            if not pose.get("hurt"):
                c.rect(20, 39 + oy, 21, 40 + oy, P.ENEMY)
                c.rect(27, 39 + oy, 28, 40 + oy, P.ENEMY)


def frame(cid, d, pose):
    c = Canvas(FW, FH)
    if d == "right":
        return frame(cid, "left", pose).mirrored()
    lk = Look(cid)
    if lk.cls == "beast":
        _wolf(c, d, pose)
    else:
        oy = pose.get("bob", 0)
        _prop_behind(c, lk, d, pose, oy)
        _body(c, lk, d, pose, oy)
        _head(c, lk, d, oy, pose.get("hurt", False))
        if d != "up" or lk.cls in ("cleric", "mage", "knight"):
            _prop_front(c, lk, d, pose, oy)
    c.outline(P.OUTLINE)
    lean = pose.get("lean", 0)
    if lean and d != "up":
        shifted = Canvas(FW, FH)
        shifted.blit(c, -lean if d in ("left", "down") else lean, 0)
        c = shifted
    return c


def sprite_sheet(cid):
    sheet = Canvas(FW * len(POSES), FH * len(DIRS))
    for row, d in enumerate(DIRS):
        for col, pose in enumerate(POSES):
            sheet.blit(frame(cid, d, pose), col * FW, row * FH)
    return sheet


# --- portraits ---------------------------------------------------------------------

def portrait(cid, mood="neutral"):
    lk = Look(cid)
    bg = Canvas(64, 64, shade(lk.cloth, 0.38))
    bg.rect(0, 40, 63, 63, shade(lk.cloth, 0.46))
    f = Canvas(64, 64)
    cl, sk, hc = lk.cloth, lk.skin, lk.hair
    # hair that falls behind the head
    if lk.style == "long":
        f.rect(16, 18, 28, 52, shade(hc))
    if lk.style == "tied":
        f.ellipse(14, 30, 5, 9, hc)
    # shoulders
    f.poly([(4, 64), (9, 50), (22, 45), (44, 45), (56, 50), (61, 64)], cl)
    f.poly([(4, 64), (9, 50), (22, 45), (26, 64)], shade(cl))
    if lk.cls == "knight":
        f.ellipse(12, 52, 9, 6, P.METAL["steel"])
        f.ellipse(52, 52, 9, 6, P.METAL["steel"])
    if lk.cls == "warrior":
        f.ellipse(12, 53, 8, 6, sk)
        f.line(16, 64, 44, 46, P.CLOTH["leather"], 3)
    if lk.cls == "archer":
        f.line(20, 46, 48, 64, P.CLOTH["leather"], 3)
        f.rect(8, 40, 10, 50, P.CLOTH["linen"])
    if lk.extra.get("apron"):
        f.rect(22, 50, 44, 64, P.CLOTH["linen"])
    if lk.extra.get("scarf"):
        f.ellipse(32, 47, 14, 4, P.CLOTH["ochre"])
    # neck + collar trim
    f.rect(27, 38, 37, 47, shade(sk))
    if lk.trim:
        f.poly([(22, 45), (32, 53), (44, 45), (44, 48), (32, 56), (22, 48)], lk.trim)
    # head (three-quarter view, facing right)
    if lk.extra.get("ears"):
        f.poly([(19, 24), (4, 14), (20, 33)], sk)
        f.poly([(45, 24), (54, 17), (46, 31)], sk)
    f.ellipse(32, 27, 14, 16, sk)
    f.poly([(36, 38), (45, 32), (40, 42), (32, 43)], sk)  # jaw toward the viewer's right
    f.rect(18, 22, 21, 34, shade(sk))                       # far-side shadow
    f.rect(42, 31, 43, 32, shade(sk))                       # nose
    # hair on top
    style = lk.style
    if style == "hood":
        f.ellipse(30, 22, 17, 15, shade(cl))
        f.ellipse(34, 30, 10, 11, sk)
    elif style != "bald":
        f.ellipse(30, 17, 16, 10, hc)
        f.rect(16, 16, 22, 30, hc)
        if style == "spiky":
            for x in range(16, 46, 6):
                f.poly([(x - 3, 14), (x + 2, 2), (x + 3, 14)], hc)
        if style == "bob":
            f.rect(15, 18, 22, 40, hc)
            f.rect(42, 18, 46, 32, hc)
        if style == "short" or style == "tied":
            f.poly([(30, 20), (46, 18), (44, 24)], hc)
        else:
            f.poly([(28, 20), (47, 17), (45, 26)], hc)
        f.ellipse(26, 12, 5, 2, light(hc))
    if lk.extra.get("beard"):
        f.poly([(28, 37), (44, 33), (42, 45), (32, 47)], hc or P.HAIR["black"])
    if lk.extra.get("mask"):
        f.rect(22, 34, 47, 41, shade(cl))
    if lk.cls == "knight":
        f.ellipse(31, 15, 16, 9, P.METAL["steel"])
        f.rect(15, 17, 47, 19, P.METAL["dark"])
    if lk.cls == "mage":
        f.ellipse(32, 13, 22, 4, cl)
        f.poly([(20, 13), (44, 0), (44, 13)], cl)
        f.rect(20, 10, 44, 11, lk.trim or shade(cl))
    if lk.extra.get("horns"):
        f.poly([(20, 14), (10, 0), (25, 10)], P.CLOTH["linen"])
        f.poly([(42, 12), (50, 0), (45, 15)], P.CLOTH["linen"])
    # face by mood
    eye_y = 28
    eyes = [(27, 28), (37, 39)]
    for x0, x1 in eyes:
        if mood == "happy":
            f.rect(x0, eye_y, x1, eye_y, P.OUTLINE)
            f.set(x0, eye_y + 1, P.OUTLINE)
            f.set(x1 + 0, eye_y + 1, P.OUTLINE)
        elif mood == "hurt" and x0 == 37:
            f.rect(x0, eye_y + 1, x1 + 1, eye_y + 1, P.OUTLINE)
        else:
            f.rect(x0, eye_y - 1, x1, eye_y + 1, P.WHITE)
            f.rect(x1, eye_y - 1, x1, eye_y + 1, P.OUTLINE)
    brow = hc if hc and style != "hood" else P.OUTLINE
    if mood == "angry":
        f.line(26, eye_y - 4, 29, eye_y - 2, brow, 1)
        f.line(36, eye_y - 2, 40, eye_y - 4, brow, 1)
    else:
        f.rect(26, eye_y - 4, 29, eye_y - 4, brow)
        f.rect(36, eye_y - 4, 40, eye_y - 4, brow)
    if not lk.extra.get("mask"):
        mouth = shade(sk, 0.55)
        if mood == "happy":
            f.line(35, 36, 37, 37, mouth)
            f.line(37, 37, 40, 35, mouth)
        elif mood == "angry":
            f.rect(35, 37, 40, 37, mouth)
            f.set(35, 36, mouth)
        elif mood == "hurt":
            f.rect(36, 36, 38, 38, mouth)
        else:
            f.rect(36, 37, 39, 37, mouth)
    f.outline(P.OUTLINE)
    bg.blit(f, 0, 0)
    return bg.scaled(4)


# --- head icons (24x24, doc/05 §7: a shape + a color, never color alone) -----------

def _bubble(fill):
    c = Canvas(24, 24)
    c.ellipse(12, 10.5, 10, 9, fill)
    c.poly([(9, 17), (12, 23), (15, 17)], fill)   # tail toward the head below
    c.outline(P.OUTLINE)
    return c


def _symbol(draw):
    s = Canvas(24, 24)
    draw(s)
    s.outline(P.OUTLINE)
    return s


def head_icon(name):
    if name == "leader":   # a star, no bubble (drawn beside the HP bar)
        def star(s):
            s.poly([(12, 2), (14.6, 8.8), (21.8, 9.2), (16.2, 13.8), (18.1, 20.8), (12, 16.8),
                    (5.9, 20.8), (7.8, 13.8), (2.2, 9.2), (9.4, 8.8)], P.GOLD)
        return _symbol(star)
    poison, sleep = hexc("#8be36b"), hexc("#8fb8ff")
    c = _bubble(P.GOLD if name == "adv" else P.WHITE)
    if name == "poison":       # a drop
        sym = _symbol(lambda s: (s.ellipse(12, 12.5, 4, 4, poison), s.poly([(8.5, 11), (12, 4), (15.5, 11)], poison)))
    elif name == "sleep":      # a Z
        sym = _symbol(lambda s: (s.rect(7, 5, 16, 6, sleep), s.line(15, 7, 8, 14, sleep, 2), s.rect(7, 14, 16, 15, sleep)))
    elif name == "adv":        # an exclamation mark
        sym = _symbol(lambda s: (s.rect(11, 3, 13, 11, P.OUTLINE), s.rect(11, 14, 13, 16, P.OUTLINE)))
    elif name == "bond":       # a heart
        heart = hexc("#e86a8a")
        sym = _symbol(lambda s: (s.ellipse(9, 8, 3.5, 3.5, heart), s.ellipse(15, 8, 3.5, 3.5, heart),
                                 s.poly([(5.5, 9), (18.5, 9), (12, 16)], heart)))
    else:
        raise ValueError(name)
    c.blit(sym, 0, 0)
    return c


HEAD_ICONS = ["poison", "sleep", "adv", "bond", "leader"]


# --- battle poses for the cut-in scene (doc/05 §8, step 16) ---------------------------
# 11 frames of 192x192, side view facing LEFT (the code mirrors them for the left side):
BATTLE_POSES = [
    dict(), dict(bob=1),                                             # 0-1 idle
    dict(arm="raise"), dict(arm="raise", lean=-2),                   # 2-3 wind up
    dict(arm="thrust", lean=2), dict(arm="thrust", lean=3),          # 4-5 strike
    dict(arm="raise"), dict(arm="raise", bob=1), dict(arm="thrust"),  # 6-8 cast
    dict(hurt=True, lean=-3),                                        # 9 hurt
    dict(lean=-4, step=1),                                           # 10 dodge
]


def battle_sheet(cid):
    sheet = Canvas(64 * len(BATTLE_POSES), 64)
    for i, pose in enumerate(BATTLE_POSES):
        sheet.blit(frame(cid, "left", pose), i * 64 + 8, 0)
    return sheet.scaled(3)


# --- cut-in backdrops: 320x150 pixel art, exported x4 = 1280x600 -------------------------

def _bands(c, top, bottom, colors):
    h = (bottom - top) / len(colors)
    for i, col in enumerate(colors):
        c.rect(0, int(top + i * h), c.w - 1, int(top + (i + 1) * h), col)


def _ridge(c, base, amp, f1, f2, phase, col):
    import math
    for x in range(c.w):
        y = base - amp * (0.6 * math.sin(x * f1 + phase) + 0.4 * math.sin(x * f2 + phase * 2.3))
        c.rect(x, int(y), x, base + 60, col)


def backdrop(kind):
    W, H, GROUND = 320, 150, 104
    c = Canvas(W, H)
    sky = [hexc(h) for h in ("#6fa8dc", "#83b6e2", "#98c4e8", "#aed2ee", "#c4dff3", "#d8eaf6")]
    _bands(c, 0, GROUND, sky)
    _ridge(c, 74, 12, 0.031, 0.083, 0.7, hexc("#8fa7c4"))              # far mountains
    terr = {"plain": "#7cb35a", "forest": "#3f7f3a", "hill": "#b08e5c", "sand": "#d9c48a",
            "shallow": "#5aa0d8", "ruins": "#8a9a6a"}[kind]
    ground = hexc(terr)
    if kind == "forest":
        _ridge(c, 92, 6, 0.05, 0.13, 1.9, hexc("#2f5f30"))
        for i, x in enumerate(range(-6, W + 6, 15)):
            h = 26 + (i * 7) % 12
            c.poly([(x - 9, 98), (x + 2, 98 - h), (x + 13, 98)], hexc("#2f6a33") if i % 2 else hexc("#27582b"))
            c.rect(x + 1, 98, x + 3, 104, hexc("#4a3428"))
    elif kind in ("plain", "ruins"):
        _ridge(c, 94, 8, 0.022, 0.071, 2.4, hexc("#5f9b46"))
    elif kind == "hill":
        _ridge(c, 96, 22, 0.018, 0.047, 0.3, hexc("#8f7046"))
        _ridge(c, 100, 10, 0.035, 0.09, 1.1, hexc("#a3824f"))
    elif kind == "sand":
        _ridge(c, 98, 10, 0.02, 0.055, 1.7, hexc("#c9b27a"))
        _ridge(c, 102, 5, 0.04, 0.1, 0.4, hexc("#e2d09b"))
    elif kind == "shallow":
        _ridge(c, 96, 5, 0.03, 0.08, 2.0, hexc("#5f9b46"))
    if kind == "ruins":
        stone, dark = hexc("#9a9a94"), hexc("#6b6b6b")
        for x, h in ((40, 40), (86, 22), (210, 46), (262, 30)):
            c.rect(x, 104 - h, x + 12, 104, stone)
            c.rect(x + 9, 104 - h, x + 12, 104, dark)
            c.rect(x - 2, 104 - h - 3, x + 14, 104 - h, stone)
        c.rect(120, 90, 180, 104, stone)
        for x in range(120, 181, 10):
            c.rect(x, 90, x, 104, dark)
    c.rect(0, GROUND, W - 1, H - 1, ground)
    c.rect(0, GROUND, W - 1, GROUND + 1, shade(ground, 0.85))
    for i in range(70):   # ground texture, deterministic
        x, y = (i * 97) % W, GROUND + 4 + (i * 53) % (H - GROUND - 6)
        if kind == "shallow":
            c.rect(x, y, x + 6, y, light(ground, 0.35))
        elif kind == "sand":
            c.set(x, y, shade(ground, 0.85))
        else:
            c.rect(x, y, x, y + 2, shade(ground, 0.8))
    return c.scaled(4)


BACKDROPS = ["plain", "forest", "hill", "sand", "shallow", "ruins"]


def main():
    units = os.path.join(ROOT, "assets", "textures", "units")
    portraits = os.path.join(ROOT, "assets", "textures", "portraits")
    os.makedirs(units, exist_ok=True)
    os.makedirs(portraits, exist_ok=True)
    icons = os.path.join(ROOT, "assets", "textures", "icons")
    os.makedirs(icons, exist_ok=True)
    for name in HEAD_ICONS:
        head_icon(name).save_png(os.path.join(icons, "head_%s.png" % name))
    battle = os.path.join(ROOT, "assets", "textures", "battle")
    backdrops = os.path.join(ROOT, "assets", "textures", "backdrops")
    os.makedirs(battle, exist_ok=True)
    os.makedirs(backdrops, exist_ok=True)
    for kind in BACKDROPS:
        backdrop(kind).save_png(os.path.join(backdrops, kind + ".png"))
    for cid in P.SPRITES:
        sprite_sheet(cid).save_png(os.path.join(units, cid + ".png"))
        battle_sheet(cid).save_png(os.path.join(battle, cid + ".png"))
    for cid in P.PORTRAITS:
        portrait(cid).save_png(os.path.join(portraits, cid + ".png"))
        for mood in P.MOODS.get(cid, []):
            portrait(cid, mood).save_png(os.path.join(portraits, "%s_%s.png" % (cid, mood)))
    print("art written: %d sprite sheets, %d battle sheets, %d portraits, %d head icons, %d backdrops" % (
        len(P.SPRITES), len(P.SPRITES), len(P.PORTRAITS) + sum(len(v) for v in P.MOODS.values()),
        len(HEAD_ICONS), len(BACKDROPS)))


if __name__ == "__main__":
    main()
