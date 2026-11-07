#!/usr/bin/env python3
"""Generates placeholder chiptune music and sound effects into assets/audio/.

Standard library only. Original melodies, written for this project.
    python3 tools/make_audio.py
"""
import math, os, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def tone(midi, dur, wave_kind="square", vol=0.3, decay=3.0):
    n = int(RATE * dur)
    if midi is None:
        return [0.0] * n
    f = freq(midi)
    out = []
    for i in range(n):
        t = i / RATE
        ph = (t * f) % 1.0
        if wave_kind == "square":
            s = 1.0 if ph < 0.5 else -1.0
        elif wave_kind == "triangle":
            s = 4 * abs(ph - 0.5) - 1
        elif wave_kind == "noise":
            s = ((hash((i * 7919) % 104729) % 2000) / 1000.0) - 1
        else:
            s = math.sin(2 * math.pi * ph)
        env = math.exp(-decay * t) * min(1.0, i / 200)   # quick attack, exponential decay
        out.append(s * vol * env)
    return out


def seq(notes, beat, kind, vol, decay):
    out = []
    for midi, beats in notes:
        out += tone(midi, beats * beat, kind, vol, decay)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    peak = max(1e-9, max(abs(v) for v in out))
    return [v / peak * 0.8 for v in out]


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in samples))
    print("wrote", name)


def loop(melody, bass, beat, repeats=2):
    m = seq(melody * repeats, beat, "square", 0.22, 2.5)
    b = seq(bass * repeats, beat, "triangle", 0.35, 1.2)
    return mix(m, b)


# --- music (C=60) ----------------------------------------------------------------
# Camp: calm, C major, 4/4
camp_m = [(64, 1), (67, 1), (72, 2), (71, 1), (67, 1), (69, 2),
          (65, 1), (69, 1), (72, 1), (69, 1), (67, 4),
          (64, 1), (65, 1), (67, 2), (72, 1), (71, 1), (69, 2),
          (67, 1), (65, 1), (64, 1), (62, 1), (60, 4)]
camp_b = [(48, 4), (45, 4), (41, 4), (43, 4), (48, 4), (45, 4), (43, 4), (48, 4)]

# Battle: driving, A minor
battle_m = [(69, 0.5), (69, 0.5), (72, 0.5), (69, 0.5), (76, 1), (74, 1),
            (72, 0.5), (71, 0.5), (69, 0.5), (71, 0.5), (72, 2),
            (69, 0.5), (69, 0.5), (72, 0.5), (76, 0.5), (79, 1), (77, 1),
            (76, 0.5), (74, 0.5), (72, 0.5), (71, 0.5), (69, 2)]
battle_b = [(45, 0.5), (57, 0.5)] * 4 + [(41, 0.5), (53, 0.5)] * 4 + \
           [(43, 0.5), (55, 0.5)] * 4 + [(45, 0.5), (57, 0.5)] * 4

# Boss: tense, D minor, chromatic
boss_m = [(62, 0.5), (63, 0.5), (62, 0.5), (69, 0.5), (68, 1), (65, 1),
          (62, 0.5), (63, 0.5), (65, 0.5), (66, 0.5), (67, 2),
          (70, 0.5), (69, 0.5), (68, 0.5), (67, 0.5), (66, 1), (65, 1),
          (62, 0.5), (61, 0.5), (62, 0.5), (57, 0.5), (62, 2)]
boss_b = [(38, 0.5), (38, 0.5), (50, 0.5), (38, 0.5)] * 2 + [(39, 0.5), (39, 0.5), (51, 0.5), (39, 0.5)] * 2 + \
         [(34, 0.5), (34, 0.5), (46, 0.5), (34, 0.5)] * 2 + [(33, 0.5), (33, 0.5), (45, 0.5), (33, 0.5)] * 2

save("music_camp", loop(camp_m, camp_b, 0.45))
save("music_battle", loop(battle_m, battle_b, 0.3))
save("music_boss", loop(boss_m, boss_b, 0.28))

# --- sound effects ------------------------------------------------------------------
save("sfx_hit", mix(tone(45, 0.12, "noise", 0.6, 25), tone(40, 0.12, "square", 0.3, 20)))
save("sfx_crit", mix(tone(45, 0.2, "noise", 0.7, 12), seq([(76, 0.06), (83, 0.12)], 1, "square", 0.3, 8)))
save("sfx_miss", seq([(72, 0.06), (67, 0.08)], 1, "triangle", 0.3, 15))
save("sfx_heal", seq([(72, 0.08), (76, 0.08), (79, 0.08), (84, 0.2)], 1, "sine", 0.4, 4))
save("sfx_level_up", seq([(72, 0.1), (76, 0.1), (79, 0.1), (84, 0.1), (88, 0.35)], 1, "square", 0.3, 3))
save("sfx_chest", seq([(79, 0.08), (84, 0.08), (91, 0.25)], 1, "square", 0.3, 5))
save("sfx_select", seq([(84, 0.04)], 1, "square", 0.2, 30))
# UI sounds (step 18): short and quiet
save("sfx_hover", seq([(96, 0.025)], 1, "triangle", 0.12, 60))
save("sfx_confirm", seq([(79, 0.035), (86, 0.05)], 1, "square", 0.18, 30))
save("sfx_cancel", seq([(81, 0.035), (74, 0.05)], 1, "square", 0.16, 30))
save("sfx_open", seq([(72, 0.03), (79, 0.03), (84, 0.06)], 1, "triangle", 0.18, 18))
save("sfx_victory", seq([(72, 0.15), (72, 0.15), (72, 0.15), (72, 0.45), (68, 0.45), (70, 0.45), (72, 0.3), (70, 0.15), (72, 0.9)], 1, "square", 0.3, 1.5))
save("sfx_defeat", seq([(67, 0.4), (66, 0.4), (65, 0.4), (64, 1.2)], 1, "triangle", 0.4, 1.0))
