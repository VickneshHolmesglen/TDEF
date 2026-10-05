#!/usr/bin/env bash
# Placeholder cue pass (2026-10-05): gives every unvoiced gameplay event, the
# per-skill / per-status-effect variant slots, and the shared-file stand-ins
# their own CC0 Kenney sound. Everything here is PLACEHOLDER pending a human
# listening pass (see assets/audio/sfx/SOURCES.md).
#
# Usage: KENNEY_DIR=<dir with the packs' .ogg files flattened> build_placeholder_cues.sh
# Packs: rpg-audio, music-jingles, impact-sounds, interface-sounds,
# sci-fi-sounds, digital-audio (all https://kenney.nl, CC0).
set -euo pipefail
cd "$(dirname "$0")/../.."
source tools/audio/lib.sh
FFMPEG="${FFMPEG:-/c/ffmpeg-8.0.1-full_build/bin/ffmpeg}"
K="${KENNEY_DIR:?set KENNEY_DIR to the flattened Kenney .ogg directory}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# layer <out.wav> <file>:<delay_ms>:<gain_db> ...  -- mixes layers, then
# trims/normalizes into assets/audio/sfx/<out>.
layer() {
  local out="$1"; shift
  local inputs=() filters="" labels="" i=0 spec f d g
  for spec in "$@"; do
    IFS=: read -r f d g <<< "$spec"
    inputs+=(-i "$K/$f")
    filters+="[$i:a]aresample=44100,aformat=channel_layouts=mono,adelay=${d}|${d},volume=${g}dB[l$i];"
    labels+="[l$i]"
    i=$((i + 1))
  done
  "$FFMPEG" -hide_banner -loglevel error -y "${inputs[@]}" \
    -filter_complex "${filters}${labels}amix=inputs=$i:normalize=0,alimiter=limit=0.9[o]" \
    -map "[o]" "$tmp/$out"
  tools/audio/process_sound.sh "$tmp/$out" "assets/audio/sfx/$out" mono
}

one() { tools/audio/process_sound.sh "$K/$2" "assets/audio/sfx/$1" mono; }

# clip <file.wav> <seconds>  -- cuts a long/looping source down with a fade-out.
clip() {
  local f="assets/audio/sfx/$1" fade
  fade=$(awk -v d="$2" 'BEGIN{printf "%.3f", d * 0.4}')
  "$FFMPEG" -hide_banner -loglevel error -y -i "$f"     -af "atrim=0:$2,afade=t=out:st=$(awk -v d="$2" -v f="$fade" 'BEGIN{printf "%.3f", d - f}'):d=$fade"     -c:a pcm_s16le "$tmp/clip.wav"
  mv "$tmp/clip.wav" "$f"
}

# --- per-skill variants (hero_skill_activated_<skill_id>) ---
layer hero_skill_activated_fireball.wav thrusterFire_000.ogg:0:0 impactSoft_heavy_001.ogg:90:-4
clip hero_skill_activated_fireball.wav 0.7
layer hero_skill_activated_frost_nova.wav glass_004.ogg:0:-2 impactGlass_heavy_000.ogg:60:0
layer hero_skill_activated_chain_lightning.wav zap1.ogg:0:-3 forceField_000.ogg:0:-6
layer hero_skill_activated_earth_slam.wav lowFrequency_explosion_000.ogg:0:0 impactMining_000.ogg:30:-3
one hero_skill_activated_shield_bash.wav impactPlate_heavy_001.ogg
# generic fallback: a magic swell instead of the old blade whoosh (weak match)
layer hero_skill_activated.wav forceField_001.ogg:0:-2 glass_002.ogg:40:-6

# --- per-status-effect variants (tower_attacked_<effect_type>) ---
one tower_attacked_burn.wav thrusterFire_001.ogg
clip tower_attacked_burn.wav 0.35
one tower_attacked_poison.wav slime_000.ogg
one tower_attacked_slow.wav impactGlass_light_000.ogg

# --- combat events with no cue until now ---
one wave_started.wav jingles_HIT03.ogg
one wave_completed.wav jingles_PIZZI04.ogg
proc_cue monster_died mono "$K/impactSoft_heavy_000.ogg" "$K/impactSoft_heavy_002.ogg" "$K/impactSoft_medium_001.ogg"
layer monster_breached.wav impactMetal_heavy_002.ogg:0:0 error_006.ogg:60:-3
one tower_destroyed.wav explosionCrunch_000.ogg
layer hero_ultimate_activated.wav lowFrequency_explosion_001.ogg:0:0 forceField_002.ogg:0:-4 glass_004.ogg:150:-6
one hero_leveled_up.wav jingles_PIZZI10.ogg
one mission_complete.wav jingles_PIZZI02.ogg
one mission_defeat.wav jingles_PIZZI01.ogg

# --- shared-file stand-ins get their own sound ---
layer hero_died.wav impactPunch_heavy_000.ogg:0:0 jingles_PIZZI14.ogg:200:-2
one monster_attack_whiff.wav knifeSlice2.ogg
one monster_windup_warning.wav drawKnife1.ogg
layer boss_died.wav impactPlate_heavy_000.ogg:0:-2 jingles_STEEL02.ogg:200:0

# --- sanctuary / progression events with no cue until now ---
one recipe_discovered.wav jingles_PIZZI12.ogg
one tarot_rune_discovered.wav jingles_STEEL10.ogg
one constellation_rune_discovered.wav jingles_STEEL12.ogg
one creature_acquired.wav jingles_PIZZI15.ogg
one creature_bred.wav jingles_PIZZI08.ogg
layer creature_sacrificed.wav impactSoft_medium_002.ogg:0:0 minimize_006.ogg:80:-4
layer tech_unlocked.wav maximize_006.ogg:0:0 glass_003.ogg:90:-5
layer item_rune_imbued.wav impactGlass_light_002.ogg:0:-2 confirmation_003.ogg:100:0
layer tower_assembled.wav metalLatch.ogg:0:0 confirmation_001.ogg:120:-2
one constellation_deactivated.wav minimize_005.ogg
one equipment_slot_changed.wav cloth2.ogg
one tower_sell_requested.wav handleCoins.ogg

# --- cue entries: <event> <family> <bus> <spatial> <db> <files...> ---
A=tools/audio/author_cue.sh
S=assets/audio/sfx
for s in fireball frost_nova chain_lightning earth_slam shield_bash; do
  $A hero_skill_activated_$s combat_impact SFX true -4 $S/hero_skill_activated_$s.wav
done
for e in burn poison slow; do
  $A tower_attacked_$e combat_impact SFX true -9 $S/tower_attacked_$e.wav
done
$A wave_started combat_impact SFX false -4 $S/wave_started.wav
$A wave_completed progress_blip UI false -3 $S/wave_completed.wav
$A monster_died combat_impact SFX false -12 $S/monster_died_v1.wav $S/monster_died_v2.wav $S/monster_died_v3.wav
$A monster_breached combat_impact SFX false -4 $S/monster_breached.wav
$A tower_destroyed combat_impact SFX true -3 $S/tower_destroyed.wav
$A hero_ultimate_activated combat_impact SFX false -2 $S/hero_ultimate_activated.wav
$A hero_leveled_up progress_blip UI false -3 $S/hero_leveled_up.wav
$A mission_phase_changed_MISSION_COMPLETE discovery_fanfare UI false 0 $S/mission_complete.wav
$A mission_phase_changed_DEFEAT discovery_fanfare UI false 0 $S/mission_defeat.wav
$A hero_died hero_death SFX false -2 $S/hero_died.wav
$A monster_attack_whiff combat_impact SFX false -9 $S/monster_attack_whiff.wav
$A monster_windup_warning combat_impact SFX false -6 $S/monster_windup_warning.wav
$A recipe_discovered discovery_fanfare UI false -2 $S/recipe_discovered.wav
$A tarot_rune_discovered discovery_fanfare UI false -2 $S/tarot_rune_discovered.wav
$A constellation_rune_discovered discovery_fanfare UI false -2 $S/constellation_rune_discovered.wav
$A creature_acquired progress_blip UI false -3 $S/creature_acquired.wav
$A creature_bred progress_blip UI false -3 $S/creature_bred.wav
$A creature_sacrificed activation_confirm UI false -3 $S/creature_sacrificed.wav
$A tech_unlocked progress_blip UI false -3 $S/tech_unlocked.wav
$A item_rune_imbued progress_blip UI false -3 $S/item_rune_imbued.wav
$A tower_assembled progress_blip UI false -3 $S/tower_assembled.wav
$A constellation_deactivated activation_confirm UI false -4 $S/constellation_deactivated.wav
$A equipment_slot_changed ui_confirm_cancel UI false -6 $S/equipment_slot_changed.wav
$A tower_sell_requested ui_confirm_cancel UI false -4 $S/tower_sell_requested.wav
echo "placeholder cue pass: OK"
