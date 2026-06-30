## GridConfig — mission-specific grid layout data passed to Grid.initialize().
## Construct programmatically in Mission Select System or author as a .tres file.
## Follows ADR-0009 persistent-data Resource pattern: typed fields + validate().
class_name GridConfig
extends Resource

## Grid width in cells.
@export var cols: int = 16
## Grid height in cells.
@export var rows: int = 12
## World-space size of one cell side in pixels.
@export var cell_size: float = 64.0
## Cell type map. Key: Vector2i coordinate. Value: Grid.CellType (as int).
## Cells absent from this dict are implicitly Grid.CellType.BLOCKED.
var cells: Dictionary[Vector2i, int] = {}  # values are Grid.CellType

## Returns validation errors. Empty array means the config is valid.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if cols <= 0:
		errors.append("cols must be > 0 (got %d)" % cols)
	if rows <= 0:
		errors.append("rows must be > 0 (got %d)" % rows)
	if cell_size <= 0.0:
		errors.append("cell_size must be > 0.0 (got %f)" % cell_size)
	return errors
