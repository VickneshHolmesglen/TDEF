class_name Encyclopedia
extends Node

## Encyclopedia — the game's passive, cross-cutting discovery log.
##
## GDD source: design/gdd/encyclopedia.md. No dedicated ADR exists yet
## (matches Sanctuary UI/Tarot Deck UI/Audio System's own precedent).
## Implements Stories 001-003 (epic-13-encyclopedia): discovery-event
## ingestion with duplicate suppression (Core Rules 1/3, AC Groups 1-2),
## the `encyclopedia_entry_added` emission contract and the read-only
## `get_entries()`/`is_discovered()` query contract (Core Rules 2/4, AC
## Group 3 + part of 5), and Save & Persistence integration at
## `restore_order = 35` (Interactions table, AC Group 4 + remainder of 5).
##
## Registered as a real Autoload (`GEncyclopedia`) — this system must
## receive discovery events continuously in both Sanctuary and Mission
## contexts (`systems-index.md` lists it "Cross-Cutting"), matching every
## other cross-cutting persisted system in this project (Menagerie,
## Inventory, Defense Building, etc.), not a per-scene node.
##
## Entries are keyed by the `(category, entry_id)` composite (Core Rule 2's
## own stated collision-safety guarantee) — a `constellation_rune`'s
## `rune_id` and a `tarot_rune`'s `rune_id` can never collide even if they
## reuse the same string, since they land in different ledger keys.

## `save-persistence.md`'s own authoritative table — the highest (last)
## restore order of any currently-registered system, since Encyclopedia's
## data only ever references what every other system already restored.
const RESTORE_ORDER: int = 35

## Every possible entry, keyed by `"[category]:[entry_id]"`. Each value is
## exactly `{category: String, entry_id: String, discovered_at: int}` —
## Core Rule 2's own "3 fields, no more, no fewer" data model.
var _ledger: Dictionary[String, Dictionary] = {}


func _ready() -> void:
	GSavePersistence.register(self, RESTORE_ORDER)
	_connect_events()


func _exit_tree() -> void:
	GSavePersistence.unregister(self)
	_disconnect_events()


func _connect_events() -> void:
	GEventBus.skill_unlocked.connect(_on_skill_unlocked)
	GEventBus.constellation_rune_discovered.connect(_on_constellation_rune_discovered)
	GEventBus.tarot_rune_discovered.connect(_on_tarot_rune_discovered)
	GEventBus.recipe_discovered.connect(_on_recipe_discovered)
	GEventBus.creature_acquired.connect(_on_creature_acquired)
	GEventBus.creature_bred.connect(_on_creature_bred)
	GEventBus.tech_unlocked.connect(_on_tech_unlocked)


func _disconnect_events() -> void:
	if GEventBus.skill_unlocked.is_connected(_on_skill_unlocked):
		GEventBus.skill_unlocked.disconnect(_on_skill_unlocked)
	if GEventBus.constellation_rune_discovered.is_connected(_on_constellation_rune_discovered):
		GEventBus.constellation_rune_discovered.disconnect(_on_constellation_rune_discovered)
	if GEventBus.tarot_rune_discovered.is_connected(_on_tarot_rune_discovered):
		GEventBus.tarot_rune_discovered.disconnect(_on_tarot_rune_discovered)
	if GEventBus.recipe_discovered.is_connected(_on_recipe_discovered):
		GEventBus.recipe_discovered.disconnect(_on_recipe_discovered)
	if GEventBus.creature_acquired.is_connected(_on_creature_acquired):
		GEventBus.creature_acquired.disconnect(_on_creature_acquired)
	if GEventBus.creature_bred.is_connected(_on_creature_bred):
		GEventBus.creature_bred.disconnect(_on_creature_bred)
	if GEventBus.tech_unlocked.is_connected(_on_tech_unlocked):
		GEventBus.tech_unlocked.disconnect(_on_tech_unlocked)


func _on_skill_unlocked(skill_id: String, _source_tower_id: int) -> void:
	_try_add_entry("skill", skill_id)


func _on_constellation_rune_discovered(rune_id: String, _pattern_id: String) -> void:
	_try_add_entry("constellation_rune", rune_id)


func _on_tarot_rune_discovered(rune_id: String, _card_id: String) -> void:
	_try_add_entry("tarot_rune", rune_id)


func _on_recipe_discovered(recipe_id: String, _recipe_category: String) -> void:
	_try_add_entry("recipe", recipe_id)


## Core Rule 8: species-level discovery, not instance-level — keyed by
## `species`, never `creature_id`.
func _on_creature_acquired(_creature_id: int, species: String) -> void:
	_try_add_entry("creature", species)


## Core Rule 8: same species-keyed rule as `_on_creature_acquired()`.
func _on_creature_bred(_offspring_id: int, species: String) -> void:
	_try_add_entry("creature", species)


func _on_tech_unlocked(tech_id: String, _tech_category: String) -> void:
	_try_add_entry("tech", tech_id)


## The single insert path every inbound handler funnels through — this is
## where Core Rule 3's duplicate suppression and Core Rule 4's emission
## contract both live. A repeat call for an already-`DISCOVERED`
## `(category, entry_id)` is a no-op: no duplicate entry, no mutated
## `discovered_at`, and `encyclopedia_entry_added` does not re-fire.
func _try_add_entry(category: String, entry_id: String) -> void:
	var key: String = "%s:%s" % [category, entry_id]
	if _ledger.has(key):
		return
	_ledger[key] = {
		"category": category,
		"entry_id": entry_id,
		"discovered_at": int(Time.get_unix_time_from_system()),
	}
	GEventBus.encyclopedia_entry_added.emit(category, entry_id)


## Core Rule 2's read-only query contract. Returns all entries, or only
## those in `category` if provided — generic across all 6 categories, no
## per-category special-casing.
func get_entries(category: String = "") -> Array[Dictionary]:
	if category == "":
		return _ledger.values()
	var result: Array[Dictionary] = []
	for entry: Dictionary in _ledger.values():
		if entry.category == category:
			result.append(entry)
	return result


## Core Rule 2's read-only query contract.
func is_discovered(category: String, entry_id: String) -> bool:
	return _ledger.has("%s:%s" % [category, entry_id])


## Story 005 (Save & Persistence integration): the discovery-fact key.
func get_save_key() -> String:
	return "encyclopedia"


## Story 005: serializes the full ledger. Fresh-install default (Edge
## Cases): an empty ledger produces `{"entries": []}`, not a special-cased
## branch.
func get_save_data() -> Dictionary:
	return {"entries": _ledger.values()}


## Story 005, AC-15a: restore never re-fires any of the 7 inbound discovery
## events, and never emits `encyclopedia_entry_added` — every entry in the
## save data is, by definition, already known from that data's own
## perspective, not a "genuinely new" discovery this restore is causing.
func restore_save_data(data: Dictionary) -> bool:
	if not data.has("entries") or not (data.entries is Array):
		return false

	var new_ledger: Dictionary[String, Dictionary] = {}
	for entry_raw: Variant in (data.entries as Array):
		if not (entry_raw is Dictionary):
			return false
		var entry: Dictionary = entry_raw as Dictionary
		if not (entry.has("category") and entry.has("entry_id") and entry.has("discovered_at")):
			return false
		if not (entry.category is String and entry.entry_id is String and (entry.discovered_at is int or entry.discovered_at is float)):
			return false
		var key: String = "%s:%s" % [entry.category, entry.entry_id]
		new_ledger[key] = {
			"category": entry.category as String,
			"entry_id": entry.entry_id as String,
			"discovered_at": int(entry.discovered_at),
		}

	_ledger = new_ledger
	return true


## Fresh-install default (Edge Cases): identical empty-ledger result to
## `restore_save_data({"entries": []})`.
func reset_to_defaults() -> void:
	_ledger.clear()


## Test/inspection accessor.
func get_category_count(category: String) -> int:
	return get_entries(category).size()
