class_name RoomLifecycleStubRoom
extends Control

## Test-only stub room for Story 007's RoomHost lifecycle tests (epic-10-
## sanctuary-ui). Real room content (Inventory & Crafting, Menagerie, Defense
## Building, Equipment Forge) is Story 005's own separate scope and doesn't
## exist yet -- this stub exercises RoomHost's generic mount/unmount contract
## exactly the way a real room eventually will: it implements
## disconnect_own_subscriptions(), records call order so tests can assert the
## exact ADR-0032 Section 1 sequence, and tracks its own nested-state field to
## verify Core Rule 6's "always resumes at root, nested state never survives
## a lateral switch" guarantee.

## Shared across instances via a static Array so a test can inspect the call
## order even after an instance is queue_free()'d -- reset explicitly by each
## test's own before_test(), matching TabStrip's static-var-with-test-reset
## precedent from Story 002.
static var call_log: Array[String] = []

## Simulates a room's own nested UI state (e.g. Menagerie's breeding-pen
## flow) -- a fresh instance always starts at "root", proving the
## destroy-and-recreate lifecycle makes persistence structurally impossible,
## not merely policy.
var nested_state: String = "root"


func _ready() -> void:
	call_log.append("ready")


func disconnect_own_subscriptions() -> void:
	call_log.append("disconnect_own_subscriptions")


func _exit_tree() -> void:
	call_log.append("exit_tree")


static func reset_call_log() -> void:
	call_log.clear()
