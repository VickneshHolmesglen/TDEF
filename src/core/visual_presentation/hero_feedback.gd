class_name HeroFeedback
extends Node

## Hero-side combat feedback (wind-up presentation spec §5): damage flash, directional particles,
## flinch, big-hit shake, low-HP vignette and the death sequence. Event-driven and presentation
## only: it never changes Hero state. One instance per mission scene; both mission scenes add it
## with a single call (see Task 8 wiring). Values are design/gdd/hero.md's Event Feedback table.
##
## Usage:
##   var fb := HeroFeedback.new()
##   fb.setup(_hero, _camera, _monster_manager.get_monster_world_position)
##   _gameplay_root.add_child(fb)

const FRAME_SECONDS: float = 1.0 / 60.0
const FLASH_FRAMES: int = 2
const BIG_FLASH_FRAMES: int = 4
const BIG_HIT_FRACTION: float = 0.25
const LOW_HP_FRACTION: float = 0.20
## 334 ms keeps damage flashes at 3 per second or fewer (WCAG 2.3.1 general flash threshold).
const MIN_FLASH_GAP_MSEC: int = 334
const PARTICLE_COUNT: int = 5
const PARTICLE_LIFETIME: float = 0.3
const PARTICLE_SPEED_MIN: float = 90.0
const PARTICLE_SPEED_MAX: float = 160.0
const FLINCH_FRAMES: int = 3
const FLINCH_DISTANCE: float = 4.0
const SHAKE_MAGNITUDE: float = 2.0
const SHAKE_FRAMES: int = 6
const FEEDBACK_LAYER: int = 0
const DEATH_FLASH_FRAMES: int = 4
const DEATH_FADE_FRAMES: int = 12
const DEATH_RING_FRAMES: int = 16
const DEATH_RING_RADIUS: float = 128.0
const DEATH_DESATURATE: float = 0.4
const VIGNETTE_MIN: float = 0.4
const VIGNETTE_MAX: float = 0.7
const VIGNETTE_PERIOD: float = 1.5
const VIGNETTE_FADE_SECONDS: float = 0.3
const LOW_HP_SPRITE_TINT: Color = Color(1.0, 0.75, 0.75)
const FLASH_TINT: Color = Color(1.0, 0.55, 0.55)
const HIT_FLASH_SHADER: Shader = preload("res://src/shaders/hit_flash.gdshader")

var _hero: Node2D = null
var _camera: Camera2D = null
var _source_position_provider: Callable = Callable()
var _sprite: Sprite2D = null
var _sprite_rest_position: Vector2 = Vector2.ZERO
var _flash_material: ShaderMaterial = null
var _flash_tween: Tween = null
var _flinch_tween: Tween = null
var _shake_tween: Tween = null
var _last_flash_msec: int = -MIN_FLASH_GAP_MSEC
var _last_source_entity_id: int = -1
var _max_hp: float = 0.0
var _layer: CanvasLayer = null
var _screen_rect: ColorRect = null
var _screen_material: ShaderMaterial = null
var _low_hp: bool = false
var _vignette_fade: float = 0.0
var _pulse_time: float = 0.0
var _dead: bool = false
var _death_tween: Tween = null


## True when a single hit removed strictly more than 25% of max HP. Unknown max never counts.
static func is_big_hit(amount: int, max_hp: float) -> bool:
	return max_hp > 0.0 and float(amount) > max_hp * BIG_HIT_FRACTION


## True below 20% of max HP (Task 6).
static func is_low_hp(current: float, max_hp: float) -> bool:
	return max_hp > 0.0 and current > 0.0 and current / max_hp < LOW_HP_FRACTION


static func flash_frames(big_hit: bool) -> int:
	return BIG_FLASH_FRAMES if big_hit else FLASH_FRAMES


## Flash restarts are limited to one per MIN_FLASH_GAP_MSEC so overlapping attackers cannot push
## the Hero past the 3-flashes-per-second limit. Records the restart when it returns true.
func can_restart_flash(now_msec: int) -> bool:
	if now_msec - _last_flash_msec < MIN_FLASH_GAP_MSEC:
		return false
	_last_flash_msec = now_msec
	return true


## `source_position_provider(entity_id: int) -> Vector2` returns Vector2.INF for an unknown or
## freed monster (MonsterManager.get_monster_world_position).
func setup(hero: Node2D, camera: Camera2D, source_position_provider: Callable) -> void:
	_hero = hero
	_camera = camera
	_source_position_provider = source_position_provider
	_sprite = hero.get_node_or_null("Sprite2D") as Sprite2D
	if _sprite != null:
		_sprite_rest_position = _sprite.position


func _ready() -> void:
	GEventBus.hero_incoming_damage.connect(_on_incoming_damage)
	GEventBus.hero_damage_taken.connect(_on_damage_taken)
	GEventBus.hero_health_changed.connect(_on_health_changed)
	GEventBus.hero_died.connect(_on_hero_died)
	GEventBus.wave_started.connect(_on_wave_started)
	_layer = CanvasLayer.new()
	_layer.layer = FEEDBACK_LAYER
	add_child(_layer)
	_screen_rect = ColorRect.new()
	_screen_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Transparent by default: if the shader ever fails to compile the rect falls back to drawing
	# this color, and it must degrade to "no effect" instead of an opaque white screen.
	_screen_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = preload("res://src/shaders/hero_screen_fx.gdshader")
	_screen_rect.material = _screen_material
	_screen_rect.visible = false
	_layer.add_child(_screen_rect)


func _exit_tree() -> void:
	if GEventBus.hero_incoming_damage.is_connected(_on_incoming_damage):
		GEventBus.hero_incoming_damage.disconnect(_on_incoming_damage)
	if GEventBus.hero_damage_taken.is_connected(_on_damage_taken):
		GEventBus.hero_damage_taken.disconnect(_on_damage_taken)
	if GEventBus.hero_health_changed.is_connected(_on_health_changed):
		GEventBus.hero_health_changed.disconnect(_on_health_changed)
	if GEventBus.hero_died.is_connected(_on_hero_died):
		GEventBus.hero_died.disconnect(_on_hero_died)
	if GEventBus.wave_started.is_connected(_on_wave_started):
		GEventBus.wave_started.disconnect(_on_wave_started)
	_kill_tween(_flash_tween)
	_kill_tween(_flinch_tween)
	_kill_tween(_shake_tween)
	_kill_tween(_death_tween)
	# Killed tweens leave the nodes wherever they stopped: put the cosmetic state back.
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.position = _sprite_rest_position
		_sprite.modulate = Color.WHITE


func _on_incoming_damage(payload: HeroIncomingDamageEvent) -> void:
	_last_source_entity_id = payload.source_entity_id


func _on_health_changed(current: float, max_hp: float) -> void:
	_max_hp = max_hp
	_low_hp = is_low_hp(current, max_hp)
	if _sprite != null and not _dead:
		_sprite.modulate = _resting_sprite_modulate()


func _on_damage_taken(amount: int, _source_type: int) -> void:
	if _dead:
		return  # Hero emits hero_died before this handler runs on a killing blow; do not cancel the death sequence
	if _hero == null or not is_instance_valid(_hero):
		return
	var direction: Vector2 = _direction_to_source()
	var big: bool = is_big_hit(amount, _max_hp)
	if can_restart_flash(Time.get_ticks_msec()):
		_play_flash(flash_frames(big))
	_spawn_particles(direction)
	_play_flinch(direction)
	if big and not ReduceMotion.enabled():
		_play_shake()
	_last_source_entity_id = -1


## Unit vector from the Hero toward the damage source, or ZERO when the source is unknown/gone.
func _direction_to_source() -> Vector2:
	if _last_source_entity_id < 0 or not _source_position_provider.is_valid():
		return Vector2.ZERO
	var source_pos: Vector2 = _source_position_provider.call(_last_source_entity_id)
	if source_pos == Vector2.INF:
		return Vector2.ZERO
	return (source_pos - _hero.global_position).normalized()


## Pulsing 0.4..0.7 opacity on a 1.5 s sine; a steady midpoint under reduced motion.
static func vignette_strength(t: float, reduce: bool) -> float:
	if reduce:
		return (VIGNETTE_MIN + VIGNETTE_MAX) * 0.5
	var s: float = 0.5 + 0.5 * sin(TAU * t / VIGNETTE_PERIOD)
	return lerpf(VIGNETTE_MIN, VIGNETTE_MAX, s)


## True while the Hero is below the low-HP threshold.
func is_low_hp_active() -> bool:
	return _low_hp


## Vignette fade-in/out progress, 0..1.
func get_vignette_fade() -> float:
	return _vignette_fade


## Current vignette_strength shader parameter.
func get_vignette_strength() -> float:
	return float(_screen_material.get_shader_parameter("vignette_strength"))


## The full-screen effect material (vignette + death desaturation).
func get_screen_fx_material() -> ShaderMaterial:
	return _screen_material


func _process(delta: float) -> void:
	advance(delta)


## Advances the vignette pulse and fade. The body of _process so tests can drive time directly.
func advance(delta: float) -> void:
	if _dead:
		return  # Task 7: the vignette freezes at maximum opacity on death
	var target: float = 1.0 if _low_hp else 0.0
	_vignette_fade = move_toward(_vignette_fade, target, delta / VIGNETTE_FADE_SECONDS)
	_pulse_time += delta
	_apply_screen_fx(vignette_strength(_pulse_time, ReduceMotion.enabled()) * _vignette_fade, 0.0)


func _apply_screen_fx(vignette: float, desaturate: float) -> void:
	_screen_material.set_shader_parameter("vignette_strength", vignette)
	_screen_material.set_shader_parameter("desaturate", desaturate)
	_screen_rect.visible = vignette > 0.001 or desaturate > 0.001


func _play_flash(frames: int) -> void:
	if _sprite == null:
		return
	_ensure_flash_material()
	_kill_tween(_flash_tween)
	var duration: float = float(frames) * FRAME_SECONDS
	_flash_material.set_shader_parameter("flash_amount", 1.0)
	_sprite.modulate = FLASH_TINT
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(v: float) -> void: _flash_material.set_shader_parameter("flash_amount", v), 1.0, 0.0, duration)
	_flash_tween.parallel().tween_property(_sprite, "modulate", _resting_sprite_modulate(), duration)
	# The resting tint is read when the flash ENDS so a low-HP tint set mid-flash is not lost.
	_flash_tween.tween_callback(func() -> void:
			if _sprite != null and is_instance_valid(_sprite) and not _dead:
				_sprite.modulate = _resting_sprite_modulate())


## Lazily creates the hit-flash material shared by the damage flash and the death flash.
func _ensure_flash_material() -> void:
	if _flash_material != null or _sprite == null:
		return
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = HIT_FLASH_SHADER
	if _sprite.material == null:
		_sprite.material = _flash_material


## The resting tint: the low-HP tint while low, otherwise white.
func _resting_sprite_modulate() -> Color:
	return LOW_HP_SPRITE_TINT if _low_hp else Color.WHITE


func _spawn_particles(direction: Vector2) -> void:
	var parent: Node = _hero.get_parent()
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = PARTICLE_COUNT
	p.lifetime = PARTICLE_LIFETIME
	p.explosiveness = 1.0
	p.initial_velocity_min = PARTICLE_SPEED_MIN
	p.initial_velocity_max = PARTICLE_SPEED_MAX
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(1.0, 0.45, 0.4)
	if direction == Vector2.ZERO:
		p.direction = Vector2.UP
		p.spread = 180.0
	else:
		p.direction = direction
		p.spread = 25.0
	parent.add_child(p)
	p.global_position = _hero.global_position
	p.emitting = true
	p.finished.connect(p.queue_free)


## 3-frame recoil opposite the damage direction, then back to rest. Cosmetic: it moves only the
## sprite, never the Hero body, so movement and auto-attack are unaffected.
func _play_flinch(direction: Vector2) -> void:
	if _sprite == null:
		return
	_kill_tween(_flinch_tween)
	_sprite.position = _sprite_rest_position
	var away: Vector2 = -direction * FLINCH_DISTANCE if direction != Vector2.ZERO else Vector2.ZERO
	var step: float = float(FLINCH_FRAMES) * FRAME_SECONDS
	_flinch_tween = create_tween()
	_flinch_tween.tween_property(_sprite, "position", _sprite_rest_position + away, step * 0.5)
	_flinch_tween.tween_property(_sprite, "position", _sprite_rest_position, step * 0.5)


## 2-pixel, 6-frame decaying-sine shake on Camera2D.offset (the boss-death shake's precedent).
func _play_shake() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_kill_tween(_shake_tween)
	_shake_tween = create_tween()
	for i in range(SHAKE_FRAMES):
		var decay: float = 1.0 - float(i) / float(SHAKE_FRAMES)
		var offset := Vector2(sin(float(i) * PI * 0.9) * SHAKE_MAGNITUDE * decay, 0.0)
		_shake_tween.tween_property(_camera, "offset", offset, FRAME_SECONDS)
	_shake_tween.tween_property(_camera, "offset", Vector2.ZERO, FRAME_SECONDS)


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


## True once the death sequence has started (until a new wave resets it).
func is_dead() -> bool:
	return _dead


func _on_hero_died() -> void:
	if _dead:
		return
	_dead = true
	_kill_tween(_flash_tween)
	_kill_tween(_flinch_tween)
	_kill_tween(_shake_tween)
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO
	# The vignette freezes at maximum opacity; desaturation eases in over 0.5 s.
	_apply_screen_fx(VIGNETTE_MAX, 0.0)
	_death_tween = create_tween()
	_death_tween.tween_method(func(v: float) -> void: _apply_screen_fx(VIGNETTE_MAX, v), 0.0, DEATH_DESATURATE, 0.5)
	if _sprite != null:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_ensure_flash_material()
		if _flash_material != null:
			_flash_material.set_shader_parameter("flash_amount", 1.0)
		var flash_time: float = float(DEATH_FLASH_FRAMES) * FRAME_SECONDS
		var fade_time: float = float(DEATH_FADE_FRAMES) * FRAME_SECONDS
		var sprite_tween := create_tween()
		sprite_tween.tween_interval(flash_time)
		sprite_tween.tween_callback(func() -> void:
				if _flash_material != null:
					_flash_material.set_shader_parameter("flash_amount", 0.0))
		sprite_tween.tween_property(_sprite, "modulate:a", 0.3, fade_time)
		_flash_tween = sprite_tween  # killed on reset / exit
	if not ReduceMotion.enabled():
		_spawn_death_ring()


func _spawn_death_ring() -> void:
	var parent: Node = _hero.get_parent() if _hero != null else null
	if parent == null:
		return
	var ring := _DeathRing.new()
	ring.radius_target = DEATH_RING_RADIUS
	parent.add_child(ring)
	ring.global_position = _hero.global_position
	var t := ring.create_tween()
	t.tween_property(ring, "progress", 1.0, float(DEATH_RING_FRAMES) * FRAME_SECONDS)
	t.tween_callback(ring.queue_free)


## A Retry after death (the scene and Hero are reused) or a fresh attempt at wave 1 clears all
## feedback state. Later waves of a live attempt leave it alone so low-HP feedback persists.
func _on_wave_started(wave_number: int, _total_waves: int, _wave_difficulty: float) -> void:
	if not _dead and wave_number != 1:
		return
	_dead = false
	_low_hp = false
	_vignette_fade = 0.0
	_kill_tween(_death_tween)
	_kill_tween(_flash_tween)
	_pulse_time = 0.0
	_kill_tween(_flinch_tween)
	_kill_tween(_shake_tween)
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.position = _sprite_rest_position
	if _sprite != null:
		_sprite.modulate = Color.WHITE
	if _flash_material != null:
		_flash_material.set_shader_parameter("flash_amount", 0.0)
	_apply_screen_fx(0.0, 0.0)


## Expanding shockwave ring for the death sequence (hero.md: 2x cell_size over 16 frames).
class _DeathRing extends Node2D:
	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()
	var radius_target: float = 128.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius_target * progress, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 1.0 - progress), 3.0)
