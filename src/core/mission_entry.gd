class_name MissionEntry
extends Resource

## Static, immutable mission catalogue entry — boot-loaded via GameDataRegistry.
##
## Story: production/epics/epic-07-cross-cutting-flow/story-008-missionselect-catalogue-cell-size.md
## Governing ADR: docs/architecture/adr-0028-mission-select-runtime-state.md
## GDD source: design/gdd/mission-select.md (Rule 1 — static fields only;
## `completion_records` deliberately excluded here per ADR-0028's static/runtime
## split, mirroring ADR-0027's Tarot fix — see MissionSelect's own runtime
## CompletionLedger for that mutable state instead).
##
## Distinct from MissionResource (src/core/mission_resource.gd, S5-02): that
## Resource owns player-facing objective text only. This Resource owns the
## structural/gameplay catalogue data (grid footprint, wave linkage, difficulty).
## Both are keyed by the same mission_id but loaded from separate directories
## to avoid GameDataRegistry directory-scan collisions — see
## GameDataRegistry.DEFAULT_MISSION_ENTRIES_DIR.

## Unique mission identifier — matches the mission_launched EventBus payload key.
@export var mission_id: String = ""
## Player-facing catalogue display name (distinct from MissionResource.objective_text).
@export var display_name: String = ""
## Embedded grid footprint. cell_size must always be 64.0 (GDD Rule 2 — closes
## Grid System OQ-4); grid_cols/grid_rows/_cell_types are the actual per-mission lever.
@export var grid_config: GridConfig = null
## Path to this mission's WaveConfig resource (assets/data/waves/{mission_id}_waves.tres).
@export var wave_config_path: String = ""
## Display cache only — must match the linked WaveConfig.wave_scripts.size() at
## content-authoring time. Wave Manager's loaded WaveConfig remains the sole
## runtime source of truth; Mission Select never reads WaveConfig at runtime.
@export var base_wave_count: int = 5
## Suggested difficulty tier (1-3) shown in the catalogue UI.
@export var recommended_difficulty_tier: int = 1
## design/gdd/mission-select.md "Mission list presentation": "a small flat
## environment-motif icon (silhouette-level, not a diorama render)" shown per
## card. Optional at load time (null renders as no icon, not an error) since
## not every mission entry is guaranteed art-complete the moment it's
## authored — matches this project's established "content can lag code"
## tolerance for other optional per-entry art fields.
## Lazy-loaded (2026-10-11, VRAM step B): the .tres stores only the file
## path, so loading every definition at boot no longer pulls its art into
## VRAM. The texture loads on first read and is then kept; assigning a
## texture directly (tests, generated definitions) overrides the path.
@export_file("*.png") var icon_path: String = ""
var icon: Texture2D:
	get:
		if not _icon_loaded:
			_icon_loaded = true
			if icon_path != "":
				_icon = load(icon_path) as Texture2D
		return _icon
	set(value):
		_icon = value
		_icon_loaded = true
var _icon: Texture2D = null
var _icon_loaded: bool = false


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009 pattern).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if mission_id == "":
		errors.append("mission_id must not be empty")
	if display_name == "":
		errors.append("display_name must not be empty")
	if grid_config == null:
		errors.append("grid_config must not be null")
	elif grid_config.cell_size != 64.0:
		errors.append("grid_config.cell_size must be exactly 64.0 (got %f) — GDD Rule 2" % grid_config.cell_size)
	if wave_config_path == "":
		errors.append("wave_config_path must not be empty")
	if base_wave_count <= 0:
		errors.append("base_wave_count must be > 0 (got %d)" % base_wave_count)
	if recommended_difficulty_tier < 1 or recommended_difficulty_tier > 3:
		errors.append("recommended_difficulty_tier must be in [1,3] (got %d)" % recommended_difficulty_tier)
	return errors
