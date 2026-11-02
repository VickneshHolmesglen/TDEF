"""Read and write WaveConfig .tres files (assets/data/waves/*_waves.tres).

A wave file is a long list of sub_resources that is tedious to edit by hand.
This module turns one into plain Python data and back:

    waves = [                         # one list per wave
        [("goblin_runner", 0.0), ("goblin_runner", 2.5), ...],   # (monster_id, pre_delay)
        ...
    ]

Optional per-entry extras (difficulty_tier, spawn_cell_index) round-trip as a
third tuple element, a dict.

CLI: print a compact summary of every wave file.

    python tools/balance/wave_builder.py
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
WAVES_DIR = ROOT / "assets/data/waves"

Entry = tuple  # (monster_id, pre_delay[, extras dict])


def parse(path: pathlib.Path) -> dict:
    """Returns {"waves": [[Entry...]...], "growth": float, "budget": float}."""
    text = path.read_text(encoding="utf-8")
    blocks = re.split(r"\n(?=\[)", text)
    subs: dict[str, dict] = {}
    resource: dict[str, str] = {}
    for block in blocks:
        head = block.split("\n", 1)[0]
        body = block.split("\n", 1)[1] if "\n" in block else ""
        props = dict(re.findall(r"^(\w+) = (.*)$", body, re.M))
        m = re.match(r'\[sub_resource type="Resource" id="([^"]+)"\]', head)
        if m:
            subs[m.group(1)] = props
        elif head.startswith("[resource]"):
            resource = props
    order = re.findall(r'SubResource\("([^"]+)"\)', resource.get("wave_scripts", ""))
    waves = []
    for wid in order:
        entries = []
        for eid in re.findall(r'SubResource\("([^"]+)"\)', subs[wid].get("entries", "")):
            p = subs[eid]
            mid = re.search(r'&"(\w+)"', p["monster_id"]).group(1)
            delay = float(p.get("pre_delay", "0.0"))
            extras = {k: int(p[k]) for k in ("difficulty_tier", "spawn_cell_index") if k in p}
            entries.append((mid, delay, extras) if extras else (mid, delay))
        waves.append(entries)
    return {
        "waves": waves,
        "growth": float(resource.get("difficulty_growth_rate", "0.2")),
        "budget": float(resource.get("wave_time_budget", "90.0")),
    }


def write(path: pathlib.Path, prefix: str, waves: list[list[Entry]], growth: float, budget: float) -> None:
    """Writes a WaveConfig .tres with stable, readable sub_resource ids."""
    out = [
        '[gd_resource type="Resource" script_class="WaveConfig" format=3]',
        "",
        '[ext_resource type="Script" path="res://src/gameplay/wave_config.gd" id="1_config"]',
        '[ext_resource type="Script" path="res://src/gameplay/wave_script.gd" id="2_script"]',
        '[ext_resource type="Script" path="res://src/gameplay/wave_spawn_entry.gd" id="3_entry"]',
        "",
    ]
    wave_ids = []
    for w, entries in enumerate(waves, start=1):
        entry_ids = []
        for e, entry in enumerate(entries, start=1):
            mid, delay = entry[0], entry[1]
            extras = entry[2] if len(entry) > 2 else {}
            eid = f"Resource_{prefix}_w{w}_e{e}"
            entry_ids.append(eid)
            out.append(f'[sub_resource type="Resource" id="{eid}"]')
            out.append('script = ExtResource("3_entry")')
            out.append(f'monster_id = &"{mid}"')
            if delay:
                out.append(f"pre_delay = {float(delay)}")
            for key, value in extras.items():
                out.append(f"{key} = {value}")
            out.append("")
        wid = f"Resource_{prefix}_wave_{w}"
        wave_ids.append(wid)
        out.append(f'[sub_resource type="Resource" id="{wid}"]')
        out.append('script = ExtResource("2_script")')
        refs = ", ".join(f'SubResource("{i}")' for i in entry_ids)
        out.append(f'entries = Array[ExtResource("3_entry")]([{refs}])')
        out.append("")
    out.append("[resource]")
    out.append('script = ExtResource("1_config")')
    refs = ", ".join(f'SubResource("{i}")' for i in wave_ids)
    out.append(f'wave_scripts = Array[ExtResource("2_script")]([{refs}])')
    out.append(f"difficulty_growth_rate = {growth}")
    out.append(f"wave_time_budget = {budget}")
    out.append("reward_base = 1.0")
    path.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")


def group(monster_id: str, count: int, spacing: float, lead: float = 0.0) -> list[Entry]:
    """`count` of one monster, the first after `lead` seconds, then `spacing` apart."""
    return [(monster_id, lead if i == 0 else spacing) for i in range(count)]


def summarize(waves: list[list[Entry]]) -> str:
    lines = []
    for i, entries in enumerate(waves, start=1):
        counts: dict[str, int] = {}
        for entry in entries:
            counts[entry[0]] = counts.get(entry[0], 0) + 1
        lines.append(f"  wave {i}: " + ", ".join(f"{k} x{v}" for k, v in counts.items()))
    return "\n".join(lines)


if __name__ == "__main__":
    for f in sorted(WAVES_DIR.glob("*_waves.tres")):
        data = parse(f)
        print(f"{f.name}: {len(data['waves'])} waves, growth {data['growth']}, budget {data['budget']}")
        print(summarize(data["waves"]))
    sys.exit(0)
