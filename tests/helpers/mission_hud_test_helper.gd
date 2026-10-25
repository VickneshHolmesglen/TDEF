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
	for label_name: String in ["PhaseLabel", "WaveLabel", "PhaseTimerLabel", "HeroHpLabel", "BreachCounterLabel", "BossBarLabel"]:
		var chrome_label := Label.new()
		chrome_label.name = label_name
		chrome.add_child(chrome_label)

	# 2026-08-16: MaterialsLabel (plain text) replaced with MaterialsRow
	# (icon+quantity chips; an HFlowContainer since 2026-10-09), then later the same day pulled
	# out of Chrome entirely and repositioned as a direct CombatCluster child
	# ("UI Changes.PNG" yellow box) -- matched here so
	# $CombatCluster/MaterialsRow resolves the same way in both the fixture
	# and the real MissionScene.tscn/the_gap.tscn.
	var materials_row := HFlowContainer.new()
	materials_row.name = "MaterialsRow"
	combat_cluster.add_child(materials_row)

	# 2026-08-06: GoldLabel moved under a GoldRow wrapper (GoldIcon + GoldLabel)
	# in the real scene (design/quick-specs/gold-currency-icon-2026-08-06.md) —
	# matched here so $CombatCluster/Chrome/GoldRow/GoldLabel resolves the same
	# way in both the fixture and the real MissionScene.tscn.
	var gold_row := HBoxContainer.new()
	gold_row.name = "GoldRow"
	chrome.add_child(gold_row)
	var gold_label := Label.new()
	gold_label.name = "GoldLabel"
	gold_row.add_child(gold_label)

	# 2026-08-16: the 4 skill-slot icon tiles are now built procedurally by
	# MissionHud._build_skill_slots() in _ready() (matching planning_cluster.
	# gd's established BuildList precedent) -- SkillCooldownHost starts empty
	# here, same as in the real .tscn.
	var skill_cooldown_host := HBoxContainer.new()
	skill_cooldown_host.name = "SkillCooldownHost"
	chrome.add_child(skill_cooldown_host)

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

	var breach_flash_overlay := Control.new()
	breach_flash_overlay.name = "BreachFlashOverlay"
	hud.add_child(breach_flash_overlay)
	for edge_name: String in ["TopEdge", "BottomEdge", "LeftEdge", "RightEdge"]:
		var edge := ColorRect.new()
		edge.name = edge_name
		breach_flash_overlay.add_child(edge)

	return hud
