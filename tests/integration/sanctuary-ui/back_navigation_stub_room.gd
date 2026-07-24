class_name BackNavigationStubRoom
extends Control

## Test-only stub room for Story 008's Cancel-idiom tests (epic-10-
## sanctuary-ui). Real rooms with genuine nested state (Equipment Forge's
## staged imbue confirmation, Menagerie's breeding-pen flow) don't exist yet
## as scenes -- this stub exercises SanctuaryUI's handle_cancel() contract
## exactly the way a real room eventually will: one nested stage, consumed by
## the first Cancel, root reached by the second.

var has_nested_state: bool = true


## Returns true (Cancel consumed, stepped back one stage, stays in this room)
## exactly once per nested-state entry; false thereafter (nothing left to
## step back from -- shell should exit to OVERVIEW).
func handle_cancel() -> bool:
	if has_nested_state:
		has_nested_state = false
		return true
	return false
