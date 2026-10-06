"""Builds the four Music Energy stems from CC0 OpenGameArt loops (2026-10-07).

Replaces the synthesized placeholder stems (tools/audio/synth_stems.sh, removed 2026-10-07) in
assets/audio/music/. For each stem: download the CC0 source, decode to 48 kHz
stereo, make the loop seam click-free with a short end->start crossfade,
loudness-normalize to TARGET_LUFS, and encode Ogg Vorbis (~q5). Looping itself
is enabled at runtime by MusicAmbientController (no .import loop settings).

Usage (from the repo root):  python tools/audio/build_music_stems.py
Needs: ffmpeg on PATH or FFMPEG env var; numpy. Sources/licenses are logged in
assets/audio/sfx/SOURCES.md.
"""
import os
import subprocess
import tempfile
import urllib.request

import numpy as np

FFMPEG = os.environ.get("FFMPEG", "C:/ffmpeg-8.0.1-full_build/bin/ffmpeg")
SR = 48000
TARGET_LUFS = -17.0
SEAM_CROSSFADE_S = 0.06
OUT_DIR = "assets/audio/music"

# stem -> (CC0 source URL, author, title)
STEMS = {
    "contemplative": ("https://opengameart.org/sites/default/files/A%20Brand%20New%20Wisdom.ogg",
                      "hernandack", "A Brand New Wisdom (Short Loops Background Music Pack)"),
    "measured": ("https://opengameart.org/sites/default/files/heartfelt-battle_loop.ogg",
                 "request", "Heartfelt Battle (loop)"),
    "urgent": ("https://opengameart.org/sites/default/files/determined_pursuit_loop.wav",
               "Emma_MA", "Determined Pursuit (epic orchestra loop)"),
    "measured_urgent": ("https://opengameart.org/sites/default/files/Winter%20Dust_0.ogg",
                        "hernandack", "Winter Dust (Short Loops Background Music Pack)"),
}


def decode(path: str) -> np.ndarray:
    raw = subprocess.run([FFMPEG, "-v", "error", "-i", path, "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def trim_trailing_silence(x: np.ndarray, threshold_db: float = -60.0) -> np.ndarray:
    level = np.abs(x).max(axis=1)
    loud = np.nonzero(level > 10 ** (threshold_db / 20))[0]
    return x[: loud[-1] + 1] if len(loud) else x


def seamless(x: np.ndarray) -> np.ndarray:
    """Blend the last N samples into the first N: the result's end flows into its own start."""
    n = int(SEAM_CROSSFADE_S * SR)
    fade = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
    y = x[n:].copy()
    y[-n:] = x[-n:] * (1.0 - fade) + x[:n] * fade
    return y


def encode(x: np.ndarray, out_path: str) -> None:
    with tempfile.NamedTemporaryFile(suffix=".f32", delete=False) as tmp:
        tmp.write(x.astype(np.float32).tobytes())
        raw_path = tmp.name
    try:
        subprocess.run([FFMPEG, "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", raw_path,
                        "-af", f"loudnorm=I={TARGET_LUFS}:TP=-1.5:LRA=11",
                        "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "5", out_path], check=True)
    finally:
        os.remove(raw_path)


def main() -> None:
    with tempfile.TemporaryDirectory() as work:
        for stem, (url, author, title) in STEMS.items():
            src = os.path.join(work, stem + os.path.splitext(url)[1])
            urllib.request.urlretrieve(url, src)
            audio = seamless(trim_trailing_silence(decode(src)))
            encode(audio, os.path.join(OUT_DIR, stem + ".ogg"))
            print(f"{stem}: {title} by {author} ({len(audio) / SR:.1f}s)")


if __name__ == "__main__":
    main()
