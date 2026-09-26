extends GdUnitTestSuite

## Unit tests for ReduceMotion (wind-up presentation spec §6).

var _original: Variant = null
var _had_setting: bool = false


func before_test() -> void:
	_had_setting = ProjectSettings.has_setting(ReduceMotion.SETTING_KEY)
	_original = ProjectSettings.get_setting(ReduceMotion.SETTING_KEY) if _had_setting else null


func after_test() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, _original if _had_setting else null)


func test_defaults_to_false_when_the_setting_is_absent() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, null)
	assert_bool(ReduceMotion.enabled()).is_false()


func test_reads_true_from_the_project_setting() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, true)
	assert_bool(ReduceMotion.enabled()).is_true()


func test_reads_false_from_the_project_setting() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, false)
	assert_bool(ReduceMotion.enabled()).is_false()
