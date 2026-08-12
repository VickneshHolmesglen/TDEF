## Unit tests for StructureCastShadow (pure view component, no EventBus
## subscriptions) -- closes the art bible's Principle 1 stacked-sprite/
## cast-shadow requirement for Diorama structures.
##
## Instantiated directly (no add_child()), matching TowerMasteryArc's own
## established convention for pure view components.
extends GdUnitTestSuite

var _shadow: StructureCastShadow


func before_test() -> void:
	_shadow = StructureCastShadow.new()


func after_test() -> void:
	if _shadow != null and is_instance_valid(_shadow):
		_shadow.free()
	_shadow = null


func test_default_ellipse_size_is_set() -> void:
	assert_float(_shadow.ellipse_size.x).is_greater(0.0)
	assert_float(_shadow.ellipse_size.y).is_greater(0.0)


func test_ellipse_size_is_settable() -> void:
	_shadow.ellipse_size = Vector2(100.0, 30.0)
	assert_vector(_shadow.ellipse_size).is_equal(Vector2(100.0, 30.0))


## Real gap found live 2026-08-13: an earlier draft defined its own
## same-named draw_ellipse() helper, which Godot rejected at compile time
## as an incompatible override of CanvasItem's own native draw_ellipse()
## (a post-LLM-cutoff Godot 4.6 API). This test doesn't assert pixel output
## (not feasible in a headless unit test) but confirms _draw() itself is
## callable without error -- the actual regression-catching value here.
func test_draw_does_not_error() -> void:
	_shadow.size = Vector2(48.0, 16.0)
	_shadow._draw()
