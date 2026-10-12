extends SceneTree

## Rebuilds the project UI theme from Hd2dTheme.build() and saves it.
##   Godot --headless --path . --script tools/ui/build_hd2d_theme.gd


func _initialize() -> void:
	var theme: Theme = Hd2dTheme.build()
	var err: int = ResourceSaver.save(theme, Hd2dTheme.THEME_PATH)
	print("[build_hd2d_theme] saved %s -> %s" % [Hd2dTheme.THEME_PATH, error_string(err)])
	quit(0 if err == OK else 1)
