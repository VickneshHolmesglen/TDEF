class_name SnapshotChip
extends Node

## Current Build Snapshot chip -- the shell's own cross-screen bridge (Story
## 005, epic-11-tarot-deck-ui).
##
## GDD source: design/gdd/tarot-deck-ui.md -- Core Rule 7, AC Group 5.
## Story: production/epics/epic-11-tarot-deck-ui/story-005-current-build-snapshot.md
##
## Pure reads of state each wrapped system already derives for its own
## purposes -- this class introduces no new formula, no new EventBus event,
## no new data ownership (matches the GDD's own "no formulas" framing).
##
## Ultimate half is fully real: GHeroSkillBuild is a genuine Autoload
## (confirmed in project.godot) exposing get_all_slot_bindings()["U"] as a
## live-derived read ("EMPTY" sentinel matches this class's own
## EMPTY_ULTIMATE constant exactly, per hero_skill_build.gd's own doc
## comment -- never a stored field, always freshly derived on call).
##
## Tarot-risk half is a REAL, FLAGGED GAP, not fabricated: Tarot is
## scene-instanced (ADR-0027), has no Autoload registration anywhere in
## project.godot, and no Tarot screen/instance exists yet in this project
## (OQ-5) -- there is genuinely no live Tarot instance anywhere to query.
## get_tarot_risk_summary() returns an explicit "not available" result rather
## than a fabricated 0/default value that could be mistaken for a real read.

const EMPTY_ULTIMATE: String = "EMPTY"


## Hero Skill Build's currently-derived ultimate_id, or EMPTY_ULTIMATE when
## fewer than 4 slots are filled (hero_skill_build.gd's own defined value).
## Always a live read, never cached -- matches the GDD's own "reads it, never
## computes it" requirement exactly.
func get_ultimate_id() -> String:
	return GHeroSkillBuild.get_all_slot_bindings().get("U", EMPTY_ULTIMATE)


## Tarot's current aggregate risk readout. Returns { "available": false }
## today -- see class doc for why. A future story wiring a real Tarot
## instance into this shell should update this method to read that
## instance's own get_active_card_count() (or an eventual dedicated
## aggregate-risk getter) directly, not add a new mechanism here.
func get_tarot_risk_summary() -> Dictionary:
	return {"available": false}
