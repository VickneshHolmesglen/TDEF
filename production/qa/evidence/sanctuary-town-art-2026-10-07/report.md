# Sanctuary art batch — 7 October 2026

Saved in G:/TDef. All 35 town-building tier PNGs are present with genuine alpha and wired into all seven SanctuaryBuildingResource tier_textures arrays. Castle was already completed by Claude Code; its preserved source sheet and five final files were checked, and its completed tracker status retained. Codex generated and integrated the remaining 30 tiers using the built-in image generator.

Raw building sheets: assets/source/sanctuary/town/sanctuary_<building>_sheet.png.
Processed game art: assets/art/sanctuary/town/<building>_tier_<1..5>.png.
Buildings: castle, armoury, menagerie, keep, blacksmith, training_hall, seers_tower.
Wiring: assets/data/sanctuary_buildings/<building>.tres.

Five tiers per building share one bottom-centred canvas to preserve relative growth. Footprint aspect matches each canvas. The normal cutter uses magenta-excess keying; Seer's Tower uses the saved cut_violet_town_sheet.py colour-distance variation to preserve violet roofs and starlight. All cutouts were visually inspected on green.

The older Skills tab icon is generated, palette-normalized to flat #DDD4B0/#252D3D, processed to 64x64, saved in assets/art/ui/tab_hero_skills.png, and wired at TAB_ICON_TEXTURES[5]. Its raw is in assets/source/ui/tab_hero_skills.png.

Settings and Exit Game plates were regenerated with Continue as reference, alpha-cropped, normalized to 913x216 plate area on 923x216 canvases, and saved in assets/art/main_menu/btn_settings.png and btn_exit_game.png. Raw output and previous-version backups are in assets/source/main_menu. All five main menu buttons share 280x74 minimum and runtime dimensions.

The old standalone Castle centerpiece request is marked superseded by the newer five-tier Castle system; no duplicate standalone sprite was fabricated.

Verification: pinned Godot 4.6.2 editor import; real SanctuaryUI scene and TownBuildingView renderer at all five forced tiers (35/35 art=true), all five tier screenshots, and real MainMenu screenshot with 5/5 button sizes confirmed. Final import stderr is empty; runtime has no errors and only an MCP bridge teardown warning on quit. Screenshots show tier growth, clean cutouts, in-bounds placement, and the Skills glyph. QA harness only forces presentation tiers in memory; no gameplay progress or save is edited.

Tracker: production/art-overhaul-status.md. New work is marked processed + wired + live-verified, awaiting commit. No commit or push was made; repository instructions require user direction for commits. Castle retains its pre-existing done status. No generation or processing backlog remains in this queue.
