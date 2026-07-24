class_name WaveScript
extends Resource

## One wave's spawn composition — embedded inside WaveConfig.wave_scripts
## (ADR-0009: "WaveConfig — Embedded Nested Resources"). No separate .tres
## file per wave; all of a mission's waves colocate in one WaveConfig.tres.
##
## GDD source: design/gdd/wave-manager.md
## Governing ADR: docs/architecture/adr-0009-resource-data-model.md (Accepted)

@export var entries: Array[WaveSpawnEntry] = []
