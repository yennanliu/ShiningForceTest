"""Palette and character looks for the placeholder art (doc/05 §3–§5). Original designs.

Each entry: class, team, skin, hair, hair style, outfit color, extra details.
Hair styles: short, long, spiky, tied, bob, bald, hood. Ids match data/units and dialogue speaker ids.
"""
from pixel import hexc

OUTLINE = hexc("#1b1622")
PLAYER = hexc("#3b6fd8")
ENEMY = hexc("#c8423a")
GOLD = hexc("#ffd34a")
WHITE = hexc("#f4f1e8")

SKIN = {"light": hexc("#f2c9a0"), "tan": hexc("#d9a27a"), "brown": hexc("#a86f4c"),
        "dark": hexc("#6e4630"), "goblin": hexc("#8aa04a")}
HAIR = {"black": hexc("#2b2224"), "brown": hexc("#6b3e26"), "copper": hexc("#b8682e"),
        "flax": hexc("#e3c77a"), "silver": hexc("#b8b8c8"), "plum": hexc("#5a4a7a")}
CLOTH = {"moss": hexc("#4e6b3a"), "leather": hexc("#8a5a3c"), "heather": hexc("#6c5b7b"),
         "slate": hexc("#3d5a6c"), "ochre": hexc("#b07a3a"), "linen": hexc("#e8e0cc")}
METAL = {"steel": hexc("#9aa4b0"), "dark": hexc("#5c6470"), "brass": hexc("#d8b04a")}
FUR = hexc("#7a7480")
BOOT = hexc("#4a3428")

# id: (class, team, skin, hair, style, outfit, extras)
CHARACTERS = {
    # party (player team)
    "aldric":  ("swordsman", "player", "light", "brown", "short", "slate", {}),
    "brina":   ("knight", "player", "tan", "flax", "tied", "leather", {}),
    "corin":   ("archer", "player", "brown", "black", "spiky", "moss", {}),
    "dara":    ("cleric", "player", "light", "silver", "bob", "linen", {}),
    "eamon":   ("mage", "player", "tan", "plum", "short", "heather", {}),
    "fiora":   ("swordsman", "player", "light", "copper", "long", "ochre", {}),
    "garret":  ("warrior", "player", "dark", "black", "bald", "leather", {"beard": True}),
    "hale":    ("archer", "player", "light", "flax", "short", "slate", {"scarf": True}),
    # enemies
    "goblin":         ("swordsman", "enemy", "goblin", "black", "bald", "leather", {"ears": True}),
    "goblin_archer":  ("archer", "enemy", "goblin", "black", "bald", "moss", {"ears": True}),
    "goblin_stinger": ("archer", "enemy", "goblin", "plum", "hood", "heather", {"ears": True}),
    "bandit":         ("warrior", "enemy", "tan", "brown", "hood", "slate", {"mask": True}),
    "goblin_chief":   ("swordsman", "enemy", "goblin", "black", "bald", "ochre", {"ears": True, "horns": True, "beard": True}),
    "wolf":           ("beast", "enemy", None, None, None, None, {}),
    # neutral guests and townspeople (no team trim)
    "villager": ("civilian", "neutral", "tan", "brown", "short", "linen", {}),
    "elder":    ("civilian", "neutral", "light", "silver", "bald", "heather", {"beard": True}),
    "smith":    ("civilian", "neutral", "brown", "black", "short", "leather", {"apron": True}),
    "mayor":    ("civilian", "neutral", "light", "brown", "short", "ochre", {}),
    "child":    ("civilian", "neutral", "tan", "copper", "spiky", "moss", {}),
    "hunter":   ("civilian", "neutral", "dark", "black", "tied", "moss", {}),
}

# Units that appear on the battle map (get a sprite sheet).
SPRITES = ["aldric", "brina", "corin", "dara", "eamon", "fiora", "garret", "hale",
           "goblin", "goblin_archer", "goblin_stinger", "bandit", "goblin_chief", "wolf", "villager"]
# Speakers that get a portrait, and extra moods (doc/05 §5).
PORTRAITS = ["aldric", "brina", "corin", "dara", "eamon", "fiora", "garret", "hale",
             "goblin_chief", "villager", "elder", "smith", "mayor", "child", "hunter"]
MOODS = {"aldric": ["happy", "angry"], "brina": ["happy", "angry"], "goblin_chief": ["angry", "hurt"]}


def team_color(team):
    return {"player": PLAYER, "enemy": ENEMY}.get(team)
