"""Generates Joynetic's original placeholder sound cues (no third-party audio).

Each obstacle type has its own shape so players can play by ear:
  beam      low falling "whoosh" tone  -> squat
  laneBlock two deep knocks            -> lean
  orb       rising sparkle             -> raise arms
  gate      three-note bell            -> raise arms
Usage: python3 tools/gen_cues.py app/assets/audio
"""
import math, struct, sys, wave, random, os

RATE = 22050

def write(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 30000)) for s in samples))

def env(i, n, a=0.02, r=0.3):
    t = i / RATE; d = n / RATE
    return min(1, t / a) * min(1, max(0, (d - t) / (d * r)))

def tone(f0, f1, dur, shape="sine", vol=0.7):
    n = int(dur * RATE); out = []; ph = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * i / n
        ph += 2 * math.pi * f / RATE
        v = math.sin(ph) if shape == "sine" else (1 if math.sin(ph) > 0 else -1) * 0.5
        out.append(v * env(i, n) * vol)
    return out

def knock(dur=0.12, f=90):
    n = int(dur * RATE)
    return [math.sin(2 * math.pi * f * i / RATE) * math.exp(-i / (RATE * 0.03)) * 0.9 for i in range(n)]

def silence(d): return [0.0] * int(d * RATE)

def mix(*parts):
    n = max(len(p) for p in parts); out = [0.0] * n
    for p in parts:
        for i, v in enumerate(p): out[i] += v
    return out

random.seed(7)
out = sys.argv[1] if len(sys.argv) > 1 else "app/assets/audio"
os.makedirs(out, exist_ok=True)
noise = [random.uniform(-1, 1) * 0.25 * env(i, int(0.6 * RATE)) for i in range(int(0.6 * RATE))]
write(f"{out}/cue_beam.wav", mix(tone(520, 140, 0.6), noise))
write(f"{out}/cue_laneBlock.wav", knock() + silence(0.08) + knock())
write(f"{out}/cue_orb.wav", tone(660, 1320, 0.18) + tone(990, 1760, 0.22))
write(f"{out}/cue_gate.wav", tone(523, 523, 0.16) + tone(659, 659, 0.16) + tone(784, 784, 0.3))
write(f"{out}/clear.wav", tone(880, 1175, 0.12, vol=0.5))
write(f"{out}/hit.wav", tone(200, 90, 0.25, shape="square", vol=0.5))
write(f"{out}/checkpoint.wav", tone(523, 523, 0.12) + tone(784, 784, 0.12) + tone(1047, 1047, 0.3))
write(f"{out}/tracking.wav", tone(440, 440, 0.12, vol=0.4) + silence(0.1) + tone(440, 440, 0.12, vol=0.4))
print("cues written to", out)
