extends GdUnitTestSuite

## ADR-0042 unit pass: contact shadows and the per-mission unit light.


func test_ground_shadow_attach_twice_reuses_one_node_and_resizes() -> void:
	# Arrange
	var host: Node2D = auto_free(Node2D.new())
	add_child(host)

	# Act
	var first: GroundShadow = GroundShadow.attach(host, 20.0, 10.0)
	var second: GroundShadow = GroundShadow.attach(host, 40.0, 30.0)

	# Assert
	assert_object(second).is_same(first)
	assert_int(host.find_children("GroundShadow", "GroundShadow", false, false).size()).is_equal(1)
	assert_float(second.position.y).is_greater(30.0)
	assert_int(second.z_index).is_equal(-1)


func test_ground_shadow_sits_toward_lower_right_of_the_feet() -> void:
	var host: Node2D = auto_free(Node2D.new())
	add_child(host)
	var shadow: GroundShadow = GroundShadow.attach(host, 30.0, 25.0)
	assert_float(shadow.position.x).is_greater(0.0)
	assert_float(shadow.position.y).is_greater(25.0)


func test_apply_unit_light_creates_one_canvas_modulate_and_updates_it() -> void:
	# Arrange
	var host: Node2D = auto_free(Node2D.new())
	add_child(host)

	# Act
	Hd2dScenery.apply_unit_light(host, Color(0.8, 0.9, 1.0))
	Hd2dScenery.apply_unit_light(host, Color.WHITE)

	# Assert
	var lights: Array[Node] = host.find_children("UnitLight", "CanvasModulate", false, false)
	assert_int(lights.size()).is_equal(1)
	assert_object((lights[0] as CanvasModulate).color).is_equal(Color.WHITE)
