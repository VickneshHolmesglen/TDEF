class_name MissionHudTestHelper
extends RefCounted

## Builds a fully-scaffolded MissionHud matching the current real
## the_gap.tscn structure (CombatCluster, PlanningClusterHost, Banner+Label,
## BannerTimer), for tests that need a live scene-tree instance.
##
## Introduced after this exact class of regression recurred twice (Story 002
## broke Story 001's bare-fixture tests when it added @onready-resolved
## PlanningClusterHost/CombatCluster; Story 005 broke Stories 001-003's own
## fixtures the same way when it added Banner/BannerTimer) — Story 008 adds
## InputModeTracker, Story 009 adds CombatCluster/UltimateButton, Story 011
## adds the full Chrome/TowerHpBarsHost/DamageNumberHost/ToastHost tree,
## Story 012 adds RetryButton, here directly rather than risking a further
## recurrence — every Mission
## HUD test file that instantiates a live MissionHud should build it via this
## helper instead of hand-rolling the child list, so a future story's new
## @onready dependency only needs to be added here once, not in every test
## file that predates it.
##
## Usage: var hud := MissionHudTestHelper.build_hud(); test_suite.add_child(hud)
static func build_hud() -> MissionHud:
	var hud := MissionHud.new()
	hud.name = "HUD"

	var combat_cluster := Control.new()
	combat_cluster.name = "CombatCluster"
	hud.add_child(combat_cluster)

	var ultimate_button := Button.new()
	ultimate_button.name = "UltimateButton"
	combat_cluster.add_child(ultimate_button)

	# Story 011: Chrome hosts every static combat-readout Label; TowerHpBarsHost
	# nests inside it (matching the real the_gap.tscn layout exactly).
	var chrome := VBoxContainer.new()
	chrome.name = "Chrome"
	combat_cluster.add_child(chrome)
	for label_name: String in ["PhaseLabel", "WaveLabel", "PhaseTimerLabel", "HeroHpLabel", "BreachCounterLabel", "BossBarLabel", "GoldLabel", "MaterialsLabel"]:
		var chrome_label := Label.new()
		chrome_label.name = label_name
		chrome.add_child(chrome_label)

	var skill_cooldown_host := HBoxContainer.new()
	skill_cooldown_host.name = "SkillCooldownHost"
	chrome.add_child(skill_cooldown_host)
	for i: int in range(4):
		var slot_label := Label.new()
		slot_label.name = "Slot%d" % i
		skill_cooldown_host.add_child(slot_label)

	var tower_hp_bars_host := VBoxContainer.new()
	tower_hp_bars_host.name = "TowerHpBarsHost"
	chrome.add_child(tower_hp_bars_host)

	var damage_number_host := Control.new()
	damage_number_host.name = "DamageNumberHost"
	combat_cluster.add_child(damage_number_host)

	var toast_host := VBoxContainer.new()
	toast_host.name = "ToastHost"
	combat_cluster.add_child(toast_host)

	var planning_host := Node.new()
	planning_host.name = "PlanningClusterHost"
	hud.add_child(planning_host)

	var input_mode_tracker := InputModeTracker.new()
	input_mode_tracker.name = "InputModeTracker"
	hud.add_child(input_mode_tracker)

	var banner := Control.new()
	banner.name = "Banner"
	var label := Label.new()
	label.name = "Label"
	banner.add_child(label)
	hud.add_child(banner)

	var banner_timer := Timer.new()
	banner_timer.name = "BannerTimer"
	hud.add_child(banner_timer)

	var retry_button := Button.new()
	retry_button.name = "RetryButton"
	hud.add_child(retry_button)

	return hud
