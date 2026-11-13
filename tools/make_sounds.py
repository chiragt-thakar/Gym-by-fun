"""Synthesises Joynetic's original arcade sound effects (no samples)."""
import math
import random
import struct
import sys
import wave

RATE = 22050
OUT = sys.argv[1]
random.seed(7)


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.85 / peak
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))


def n(sec):
    return int(sec * RATE)


def env(i, total, attack=0.005, decay=6.0):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-decay * t / (total / RATE))


def tone(freq, sec, decay=6.0, harmonics=((1, 1.0),), attack=0.004, bend=0.0):
    total = n(sec)
    out = []
    phase = [0.0] * len(harmonics)
    for i in range(total):
        e = env(i, total, attack, decay)
        f = freq * (1 + bend * (1 - i / total))
        s = 0.0
        for k, (mult, amp) in enumerate(harmonics):
            phase[k] += 2 * math.pi * f * mult / RATE
            s += amp * math.sin(phase[k])
        out.append(s * e)
    return out


def noise(sec, decay=8.0, lp=0.5, attack=0.002):
    total = n(sec)
    out, y = [], 0.0
    for i in range(total):
        y = y + lp * (random.uniform(-1, 1) - y)
        out.append(y * env(i, total, attack, decay))
    return out


def mix(*tracks):
    length = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0 for t in tracks) for i in range(length)]


# Pentatonic pops (C5 D5 E5 G5 A5): plucky with a soft bell overtone.
for k, f in enumerate([523.25, 587.33, 659.25, 783.99, 880.0]):
    write(f"a_pop{k}", tone(f, 0.28, decay=7, harmonics=((1, 1), (2, 0.3), (3, 0.12))))

# Dhol-like low drum: pitch drops, with a skin thump.
write("a_drum", mix(tone(95, 0.35, decay=7, bend=0.8, harmonics=((1, 1), (1.5, 0.25))), noise(0.05, decay=10, lp=0.2)))
# Tabla-like tick: short ringing mid tone.
write("a_tick", tone(620, 0.12, decay=9, harmonics=((1, 1), (2.7, 0.35)), bend=0.15))
# Clap: three tight noise bursts.
clap = []
for d in (0, 0.012, 0.024):
    burst = [0.0] * n(d) + noise(0.09, decay=12, lp=0.9)
    clap = mix(clap, burst) if clap else burst
write("a_clap", clap)
write("a_shaker", noise(0.07, decay=9, lp=0.95, attack=0.01))
# Bell: bright inharmonic partials.
write("a_bell", tone(1046, 0.9, decay=4, harmonics=((1, 1), (2.76, 0.5), (5.4, 0.25), (8.9, 0.1))))
# Chime: rising three-note arpeggio.
chime = []
for k, f in enumerate([659.25, 783.99, 1046.5]):
    part = [0.0] * n(0.09 * k) + tone(f, 0.6, decay=5, harmonics=((1, 1), (2, 0.25)))
    chime = mix(chime, part) if chime else part
write("a_chime", chime)
# Whoosh: band-limited noise swelling then fading.
total = n(0.45)
wh, y = [], 0.0
for i in range(total):
    t = i / total
    lp = 0.05 + 0.5 * t
    y = y + lp * (random.uniform(-1, 1) - y)
    wh.append(y * math.sin(math.pi * t))
write("a_whoosh", wh)
# Bat on tape ball: wooden knock.
write("a_bat", mix(tone(430, 0.16, decay=10, harmonics=((1, 1), (2.3, 0.5), (4.1, 0.2))), noise(0.03, decay=14, lp=0.8)))
# Burst (confetti / pataka): pop + sparkle.
sparkle = []
for k in range(6):
    f = 1500 + 300 * k
    sparkle = mix(sparkle, [0.0] * n(0.03 * k) + tone(f, 0.18, decay=8)) if sparkle else tone(f, 0.18, decay=8)
write("a_burst", mix(noise(0.12, decay=9, lp=0.7), [s * 0.4 for s in sparkle]))
# UI tones.
write("a_select", tone(880, 0.12, decay=6, harmonics=((1, 1), (2, 0.2))))
write("a_rotate", tone(520, 0.1, decay=8, bend=-0.3, harmonics=((1, 1), (3, 0.15))))
write("a_count", tone(740, 0.1, decay=9, harmonics=((1, 1), (2.5, 0.3))))
weld = tone(300, 0.7, decay=2.5, bend=-0.6, harmonics=((1, 1), (2, 0.4), (3, 0.2)))
write("a_weld", mix(weld, [s * 0.3 for s in noise(0.7, decay=3, lp=0.6)]))
# Soft thud: low, padded, never harsh.
write("a_thud", tone(70, 0.3, decay=8, bend=0.5, harmonics=((1, 1), (2, 0.2))))
print("ok")
