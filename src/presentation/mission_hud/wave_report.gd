class_name WaveReport
extends Control

## Post-wave tower breakdown (design/quick-specs/wave-report-2026-11-05.md):
## the "Endless Theorist" feedback surface tower.md Rule 23 assigns to the
## Mission HUD. After each wave it lists every tower's damage share, kills and
## idle share, so the intermission build decision has evidence behind it.
##
## Pure presentation: subscribes to EventBus itself, emits nothing, never takes
## input (MOUSE_FILTER_IGNORE on the whole subtree). Mounted by MissionHud._ready(),
## same as WaveCallout.
##
## Usage: `hud.add_child(WaveReport.new())`

const MAX_ROWS: int = 8
## Idle share at or above this is shown in the warning colour.
const IDLE_WARN_RATIO: float = 0.5
const PANEL_WIDTH: float = 340.0
const BAR_WIDTH: float = 70.0
const COLOR_IDLE_WARN: Color = Color(1.0, 0.55, 0.35)
const COLOR_MUTED: Color = Color(0.75, 0.75, 0.75)
const COLOR_BAR_BG: Color = Color(1, 1, 1, 0.12)

## tower_id -> {&"name": String, &"archetype": String, &"rank": int}, from tower_placed / tower_ranked_up.
var _towers: Dictionary[int, Dictionary] = {}
## tower_id -> kills credited this wave.
var _kills: Dictionary[int, int] = {}
## Summaries received since the current wave started.
var _summaries: Array[TowerWaveSummary] = []
var _wave_number: int = 0

var _panel: PanelContainer
var _title: Label
var _rows: VBoxContainer


func _ready() -> void:
	name = &"WaveReport"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false
	for pair: Array in _subscriptions():
		(pair[0] as Signal).connect(pair[1])


func _exit_tree() -> void:
	for pair: Array in _subscriptions():
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])


func _subscriptions() -> Array:
	return [
		[GEventBus.tower_placed, _on_tower_placed],
		[GEventBus.tower_ranked_up, _on_tower_ranked_up],
		[GEventBus.tower_wave_summary, _on_tower_wave_summary],
		[GEventBus.monster_died, _on_monster_died],
		[GEventBus.monsters_died_batch, _on_monsters_died_batch],
		[GEventBus.wave_started, _on_wave_started],
		[GEventBus.wave_completed, _on_wave_completed],
		[GEventBus.mission_phase_changed, _on_mission_phase_changed],
	]


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = &"Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_panel.position = Vector2(16.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.82)
	style.border_color = Color(0.85, 0.7, 0.3, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 4)
	_panel.add_child(body)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	body.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("separation", 3)
	body.add_child(_rows)


# ---------------------------------------------------------------------------
# Event intake
# ---------------------------------------------------------------------------

func _on_tower_placed(payload: TowerPlacedEvent) -> void:
	_towers[payload.tower_id] = {
		&"name": payload.display_name if not payload.display_name.is_empty() else weapon_display_name(payload.weapon_component_id),
		&"archetype": payload.archetype,
		&"rank": 0,
	}


func _on_tower_ranked_up(tower_id: int, rank: int) -> void:
	if _towers.has(tower_id):
		_towers[tower_id][&"rank"] = rank


func _on_tower_wave_summary(payload: TowerWaveSummary) -> void:
	_summaries.append(payload)


func _on_monster_died(payload: MonsterDiedEvent) -> void:
	_credit_kill(payload)


## ADR-0001 Rule 5: busy frames arrive batched; count each entry.
func _on_monsters_died_batch(payloads: Array[MonsterDiedEvent]) -> void:
	for payload: MonsterDiedEvent in payloads:
		_credit_kill(payload)


func _credit_kill(payload: MonsterDiedEvent) -> void:
	if payload.killer_tower_id >= 0:
		_kills[payload.killer_tower_id] = int(_kills.get(payload.killer_tower_id, 0)) + 1


func _on_wave_started(wave_number: int, _total_waves: int, _difficulty: float) -> void:
	_wave_number = wave_number
	_summaries.clear()
	_kills.clear()
	visible = false


## TowerSystem emits its summaries from its own wave_completed handler, which
## may run after this one: build the report at the end of the frame.
func _on_wave_completed(wave_number: int, _enemies_remaining: int, _was_boss_breached: bool) -> void:
	_wave_number = wave_number
	show_report.call_deferred()


func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	match new_phase:
		"SCOUT":
			_towers.clear()
			_summaries.clear()
			_kills.clear()
			visible = false
		"WAVE_ACTIVE", "MISSION_COMPLETE", "DEFEAT":
			visible = false


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

## Rebuilds and shows the panel from what this wave delivered. Hidden when no
## tower reported (nothing to say).
func show_report() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	var rows: Array[Dictionary] = build_rows(_summaries, _towers, _kills)
	if rows.is_empty():
		visible = false
		return
	_title.text = tr("HUD_WAVE_REPORT_TITLE") % _wave_number
	for i: int in mini(rows.size(), MAX_ROWS):
		_rows.add_child(_make_row(rows[i]))
	if rows.size() > MAX_ROWS:
		var more := Label.new()
		more.text = tr("HUD_WAVE_REPORT_MORE") % (rows.size() - MAX_ROWS)
		more.add_theme_color_override("font_color", COLOR_MUTED)
		more.add_theme_font_size_override("font_size", 12)
		_rows.add_child(more)
	visible = true


## One row per summary, highest damage first: {&"tower_id", &"name",
## &"archetype", &"rank", &"damage", &"share", &"kills", &"idle_ratio",
## &"pulses", &"support"}. `share` is of the wave's total tower damage;
## `support` rows (no damage, some aura pulses) report pulses instead.
static func build_rows(summaries: Array[TowerWaveSummary], towers: Dictionary, kills: Dictionary) -> Array[Dictionary]:
	var total: float = 0.0
	for summary: TowerWaveSummary in summaries:
		total += summary.damage_dealt
	var rows: Array[Dictionary] = []
	for summary: TowerWaveSummary in summaries:
		var info: Dictionary = towers.get(summary.tower_id, {})
		var attempts: int = summary.shots_fired + summary.idle_ticks
		rows.append({
			&"tower_id": summary.tower_id,
			&"name": String(info.get(&"name", "#%d" % summary.tower_id)),
			&"archetype": String(info.get(&"archetype", "")),
			&"rank": int(info.get(&"rank", 0)),
			&"damage": summary.damage_dealt,
			&"share": summary.damage_dealt / total if total > 0.0 else 0.0,
			&"kills": int(kills.get(summary.tower_id, 0)),
			&"idle_ratio": float(summary.idle_ticks) / float(attempts) if attempts > 0 else 0.0,
			&"pulses": summary.aura_applications_this_wave,
			&"support": is_zero_approx(summary.damage_dealt) and summary.aura_applications_this_wave > 0,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a[&"damage"]), float(b[&"damage"])):
			return float(a[&"damage"]) > float(b[&"damage"])
		return int(a[&"tower_id"]) < int(b[&"tower_id"]))
	return rows


## Fallback name when the placement payload has no display_name:
## "weap_frost_bolt" -> "Frost Bolt".
static func weapon_display_name(weapon_component_id: String) -> String:
	var bare: String = weapon_component_id.trim_prefix("weap_")
	if bare.is_empty():
		return "?"
	return bare.replace("_", " ").capitalize()


func _make_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 6)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(6.0, 18.0)
	swatch.color = ProjectileVisual.ARCHETYPE_COLORS.get(String(row[&"archetype"]), COLOR_MUTED)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(swatch)

	var name_label := Label.new()
	name_label.text = String(row[&"name"]) + ("  " + "^".repeat(int(row[&"rank"])) if int(row[&"rank"]) > 0 else "")
	name_label.custom_minimum_size.x = 110.0
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 13)
	line.add_child(name_label)

	if bool(row[&"support"]):
		line.add_child(_small_label(tr("HUD_WAVE_REPORT_PULSES") % int(row[&"pulses"]), COLOR_MUTED))
		return line

	var bar_bg := ColorRect.new()
	bar_bg.color = COLOR_BAR_BG
	bar_bg.custom_minimum_size = Vector2(BAR_WIDTH, 10.0)
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := ColorRect.new()
	bar.color = swatch.color
	bar.size = Vector2(BAR_WIDTH * clampf(float(row[&"share"]), 0.0, 1.0), 10.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(bar)
	line.add_child(bar_bg)

	line.add_child(_small_label(tr("HUD_WAVE_REPORT_DAMAGE") % [roundi(float(row[&"damage"])), roundi(float(row[&"share"]) * 100.0)], Color.WHITE))
	line.add_child(_small_label(tr("HUD_WAVE_REPORT_KILLS") % int(row[&"kills"]), Color.WHITE))
	var idle: float = float(row[&"idle_ratio"])
	line.add_child(_small_label(tr("HUD_WAVE_REPORT_IDLE") % roundi(idle * 100.0),
		COLOR_IDLE_WARN if idle >= IDLE_WARN_RATIO else COLOR_MUTED))
	return line


func _small_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label
