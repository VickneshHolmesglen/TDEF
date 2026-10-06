"""Builds the two ambient beds from real CC0 recordings (2026-10-07).

Replaces the synthesized placeholder beds (tools/audio/synth_stems.sh, removed 2026-10-07).

- ambient_base_bed: "Wind Whoosh Loop" by SketchMan3 (OpenGameArt, CC0),
  softened with a low-pass so it sits under everything as outdoor air; two
  layers (original tiled 4x + a slowed copy) so the ~23 s loop doesn't audibly
  repeat every 5.7 s.
- ambient_combat_layer: a composed 24 s distant-battle bed. Real CC0 Kenney
  impact recordings (metal/plate/wood/punch hits, blade swishes, chops; already
  logged for the SFX in assets/audio/sfx/LICENSE.txt) are muffled, scattered at
  random times and distances over a low wind rumble, with echo taps for
  distance. Everything is mixed into a CIRCULAR buffer (events and echoes that
  run past the end wrap to the start), so the loop is seamless by construction.

Both are gain-matched to the old beds' loudness so the mix balance is unchanged,
then encoded Ogg Vorbis q5, 48 kHz stereo. Looping is enabled at runtime by
MusicAmbientController.

Usage (repo root): KENNEY_DIR=<flattened Kenney .ogg dir> python tools/audio/build_ambient_beds.py
"""
import os
import random
import re
import subprocess
import tempfile
import urllib.request

import numpy as np

FFMPEG = os.environ.get("FFMPEG", "C:/ffmpeg-8.0.1-full_build/bin/ffmpeg")
KENNEY_DIR = os.environ["KENNEY_DIR"]
SR = 48000
OUT_DIR = "assets/audio/ambient"
WIND_URL = "https://opengameart.org/sites/default/files/wind%20woosh%20loop.ogg"

BASE_BED_LUFS = -43.0      # the synthesized bed's measured level: keep the mix balance
COMBAT_LAYER_LUFS = -36.0  # likewise
COMBAT_LOOP_S = 24.0
BASE_TILES = 4         # base bed = 4 x the ~5.7 s wind loop (~23 s)
SLOW_RATE = 0.83       # second wind layer: ~17% slower and lower, drifts against the first
COMBAT_EVENTS_PER_S = 3.0
SEED = 20261007
CLASH_POOL = (
    [f"impactMetal_heavy_00{i}.ogg" for i in range(5)] + [f"impactPlate_heavy_00{i}.ogg" for i in range(5)]
    + [f"impactWood_heavy_00{i}.ogg" for i in range(5)] + [f"impactPunch_heavy_00{i}.ogg" for i in range(5)]
    + ["knifeSlice.ogg", "knifeSlice2.ogg", "drawKnife1.ogg", "drawKnife2.ogg", "drawKnife3.ogg", "chop.ogg"]
)


def decode(path: str, filters: str = "") -> np.ndarray:
    cmd = [FFMPEG, "-v", "error", "-i", path]
    if filters:
        cmd += ["-af", filters]
    cmd += ["-ac", "2", "-ar", str(SR), "-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def lufs(x: np.ndarray) -> float:
    with tempfile.NamedTemporaryFile(suffix=".f32", delete=False) as tmp:
        tmp.write(x.astype(np.float32).tobytes())
        path = tmp.name
    try:
        err = subprocess.run([FFMPEG, "-hide_banner", "-nostats", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", path,
                              "-af", "ebur128", "-f", "null", "-"], capture_output=True, text=True).stderr
    finally:
        os.remove(path)
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", err)[-1])


def to_loudness(x: np.ndarray, target: float) -> np.ndarray:
    return x * (10 ** ((target - lufs(x)) / 20))


def seam_crossfade(x: np.ndarray, seconds: float = 0.25) -> np.ndarray:
    """Repairs a filter's start-up edge: blend the last N samples into the first N."""
    n = int(seconds * SR)
    fade = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
    y = x[n:].copy()
    y[-n:] = x[-n:] * (1.0 - fade) + x[:n] * fade
    return y


def add_circular(buf: np.ndarray, sound: np.ndarray, at: int, gain: float) -> None:
    for i in range(0, len(sound), len(buf)):
        chunk = sound[i : i + len(buf)] * gain
        start = (at + i) % len(buf)
        first = min(len(chunk), len(buf) - start)
        buf[start : start + first] += chunk[:first]
        buf[: len(chunk) - first] += chunk[first:]


def encode(x: np.ndarray, out_path: str) -> None:
    with tempfile.NamedTemporaryFile(suffix=".f32", delete=False) as tmp:
        tmp.write(x.astype(np.float32).tobytes())
        path = tmp.name
    try:
        subprocess.run([FFMPEG, "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", path,
                        "-c:a", "libvorbis", "-q:a", "5", out_path], check=True)
    finally:
        os.remove(path)


def main() -> None:
    rng = random.Random(SEED)
    with tempfile.TemporaryDirectory() as work:
        wind_path = os.path.join(work, "wind.ogg")
        urllib.request.urlretrieve(WIND_URL, wind_path)

        # The wind recording is only ~5.7 s, too short a loop (the content test
        # wants >= 8 s and the repetition is audible). Layer it with a slowed,
        # lower copy whose gusts drift against the first: tile the seamless
        # original BASE_TILES times, and crossfade the slowed layer into a loop
        # of the same length, so the pair only repeats every ~23 s.
        single = seam_crossfade(decode(wind_path, "lowpass=f=2500"))
        layer_a = np.tile(single, (BASE_TILES, 1))
        length = len(layer_a)
        slow = decode(wind_path, f"lowpass=f=2000,asetrate={SR}*{SLOW_RATE},aresample={SR}")
        cross = int(1.0 * SR)
        reps = int(np.ceil((length + cross) / len(slow)))
        layer_b = seam_crossfade(np.tile(slow, (reps, 1))[: length + cross], 1.0)
        base = layer_a * 0.8 + layer_b * 0.6
        encode(to_loudness(base, BASE_BED_LUFS), os.path.join(OUT_DIR, "ambient_base_bed.ogg"))
        print(f"ambient_base_bed: {len(base) / SR:.1f}s")

        length = int(COMBAT_LOOP_S * SR)
        bed = np.zeros((length, 2), dtype=np.float32)
        rumble = seam_crossfade(decode(wind_path, "lowpass=f=260,volume=6dB"))
        for start in range(0, length, len(rumble)):
            add_circular(bed, rumble, start, 1.0)
        clashes = {name: decode(os.path.join(KENNEY_DIR, name), "lowpass=f=2200,highpass=f=90") for name in CLASH_POOL}
        for _ in range(int(COMBAT_LOOP_S * COMBAT_EVENTS_PER_S)):
            sound = clashes[rng.choice(CLASH_POOL)]
            at = rng.randrange(length)
            gain = 10 ** (rng.uniform(-22.0, -8.0) / 20)
            pan = rng.uniform(-0.6, 0.6)
            panned = sound * np.array([1.0 - max(pan, 0.0), 1.0 + min(pan, 0.0)], dtype=np.float32)
            add_circular(bed, panned, at, gain)
            for delay_s, tap_db in ((0.09, -10.0), (0.21, -16.0)):  # distance echoes
                add_circular(bed, panned, at + int(delay_s * SR), gain * 10 ** (tap_db / 20))
        encode(to_loudness(bed, COMBAT_LAYER_LUFS), os.path.join(OUT_DIR, "ambient_combat_layer.ogg"))
        print(f"ambient_combat_layer: {COMBAT_LOOP_S:.0f}s, {int(COMBAT_LOOP_S * COMBAT_EVENTS_PER_S)} clash events")


if __name__ == "__main__":
    main()
