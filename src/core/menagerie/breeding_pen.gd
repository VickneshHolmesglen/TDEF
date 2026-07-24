class_name BreedingPen
extends RefCounted

## Runtime breeding-pen slot (ADR-0026). Fixed 2 instances on Menagerie, not
## expandable (GDD Rule 12, Tuning Knobs). Plain RefCounted, mirrors
## CreatureInstance's precedent.
##
## Full pairing/countdown logic is Story 015's scope — this file declares
## only the data shape needed by earlier stories that reference
## Menagerie._breeding_pens (e.g. Story 007's Lure action never targets a
## pen, but Menagerie's field list must exist from the start per ADR-0026's
## Key Interfaces).

var occupant_ids: Array[int] = []       # 0-2 creature_ids
var breeding_missions_remaining: int = -1  # -1 = not active (fewer than 2 occupants)
