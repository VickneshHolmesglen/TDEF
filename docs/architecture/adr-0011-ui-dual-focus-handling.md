# ADR-0011: UI Dual-Focus Handling (Input-Mode-Aware Focus Rings)

## Status
Accepted

## Date
2026-07-13

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | UI |
| **Knowledge Risk** | HIGH — post-LLM-cutoff. Godot 4.6 introduced a dual-focus system: mouse/touch focus is now separate from keyboard/gamepad focus. `grab_focus()` only ever sets keyboard/gamepad focus; mouse hover is tracked independently via `mouse_entered`/`mouse_exited`, and both can be active simultaneously on different controls. |
| **References Consulted** | `docs/engine-reference/godot/modules/ui.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None new — this ADR uses only stable `Control`/`InputEvent` APIs (`grab_focus()`, `focus_neighbor_*`, `focus_entered`/`focus_exited`, `mouse_entered`/`mouse_exited`, `_input()`). The dependency is on Godot 4.6's **behavioral** change to focus semantics (the mouse/keyboard-gamepad split), not on any new API surface. |
| **Verification Required** | (1) Confirm `focus_entered` still fires correctly when focus moves via a gamepad `ui_up`/`ui_down`/etc. action under 4.6's dual-focus model — the reference docs confirm the split conceptually but do not document signal-firing order at this level of detail; do one live smoke test with a gamepad before Story 007 merges: press `ui_down` with no mouse near the control and confirm the focus ring appears. (2) Confirm `mouse_entered`/`mouse_exited` and `focus_entered`/`focus_exited` remain fully independent (never suppress one another) for a representative `Button`/`TextureButton` grid. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None. Loosely referenced by ADR-0010 ("Enables: ADR-0011 — UI dual-focus, Hero stat display"), but that framing is corrected here — see Context. |
| **Enables** | Fully unblocks Epic 03 Story 007 (Two-Panel Screen Presentation) — the only remaining `Status: Blocked` story in Epic 03. Establishes the pattern any future interactive UI screen (Sanctuary UI, Tarot Deck UI, Mission HUD's interactive elements if any) must follow. |
| **Blocks** | None |
| **Ordering Note** | Should be Accepted before Story 007's implementation begins, and referenced by any future UX spec (`design/ux/hud.md`, `design/ux/pause-menu.md`, etc.) involving gamepad-navigable widgets. |

## Context

### Problem Statement

Godot 4.6 split focus into two independent tracks: keyboard/gamepad focus (moved by `grab_focus()` and `focus_neighbor_*` traversal) and mouse/touch focus (tracked via `mouse_entered`/`mouse_exited`, wholly separate). `.claude/docs/technical-preferences.md` mandates full keyboard/mouse + gamepad parity for all UI — no hover-only or touch-only interactions. `design/gdd/inventory.md`'s own UI Requirements section already fully specifies the *interaction* model for Epic 03's Story 007 (D-pad/left-stick moves selection via 2D spatial adjacency, wrapping at grid edges to switch tabs; shoulder buttons cycle tabs directly; a single confirm button opens a context menu with no drag-equivalent; keyboard mirrors the same adjacency model) and explicitly requires: *"Focus always renders a visible, non-color-dependent highlight (outline + slight scale), distinct from hover."* No ADR exists codifying the Godot-level mechanism that satisfies that last requirement — this ADR supplies the implementation layer only; it does not redesign the already-specified UX.

**Correction to ADR-0010's framing**: ADR-0010 lists this ADR as enabling "Hero stat display." That framing does not hold up — Mission HUD's hero stat display (HP bar, skill cooldown fill) is non-interactive (`Label`/`ProgressBar`/`TextureProgressBar`), has no focus target, and needs no dual-focus handling at all. The concrete, current driver is Story 007's interactive inventory grid; this ADR's scope is "any interactive, focusable UI widget," which happens to have zero overlap with Hero's HUD display elements.

### Constraints
- Godot 4.6's dual-focus split means a custom focus-ring implementation that assumes "focus == what the mouse is over" (a pre-4.6 mental model) is exactly the "Common Mistake" the engine reference docs flag.
- `technical-preferences.md`: full K/M + gamepad parity; no hover-only or touch-only interactions; Touch Support is explicitly "None" for this project.
- `inventory.md`'s UI Requirements are already authored and must not be redesigned by this ADR — only implemented.
- Must not require a new Autoload — Presentation-layer concerns are already classified scene-instanced by ADR-0002's Autoload/Scene-Instanced Boundary table, and a screen's "what input method is the player currently using" state has no meaning outside that screen's own lifetime.

### Requirements
- Every interactive UI screen must be able to answer, at any moment: is the player's most recent input mouse, or keyboard/gamepad?
- Focus-ring visibility must be conditional on that answer: shown when the last input was keyboard/gamepad, independent of whatever the mouse happens to be resting on.
- Mouse hover must remain its own, separate visual signal — never merged with the focus ring into a single "highlighted" boolean.
- The mechanism must be reusable across screens (Inventory now; Sanctuary UI, Tarot Deck UI later) without duplicating detection logic per screen.
- Must not require a new Autoload.

## Decision

### Reusable `InputModeTracker` helper, instanced per interactive UI screen

A small reusable GDScript class, `InputModeTracker` (`src/ui/input_mode_tracker.gd`), is instanced as a child node of each interactive UI screen that needs input-mode-aware focus rings — starting with Inventory's two-panel screen (Story 007), extending to Sanctuary UI and Tarot Deck UI once those are designed. It is **not** an Autoload: this matches ADR-0002's existing classification of "All Presentation (HUD, UI)" as scene-instanced.

**Detection — `_input()`, not `_unhandled_input()`.** Godot-specialist review flagged that `_unhandled_input()` would miss mouse-button transitions on Controls with `mouse_filter = STOP` (the default for `Button`/`TextureButton`) — a click on a focusable widget is consumed by the widget before it reaches `_unhandled_input`. Using `_input()` on the tracker (a sibling-level Node, not itself a Control competing for input) observes every event regardless of what a child Control consumes.

```gdscript
class_name InputModeTracker
extends Node

enum InputMode { MOUSE, KEYBOARD_GAMEPAD }

signal input_mode_changed(mode: InputMode)

# Defaults to KEYBOARD_GAMEPAD: matches inventory.md's own default — "input focus
# defaulting to the first occupied slot in the active tab" on screen open, before
# any mouse motion has occurred.
var _current_mode: InputMode = InputMode.KEYBOARD_GAMEPAD

func _input(event: InputEvent) -> void:
    var detected: InputMode
    if event is InputEventMouseMotion or event is InputEventMouseButton:
        detected = InputMode.MOUSE
    elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
        detected = InputMode.KEYBOARD_GAMEPAD
    else:
        return  # ignore other event types (e.g. InputEventScreenTouch — out of scope, Touch Support: None)
    if detected != _current_mode:
        _current_mode = detected
        input_mode_changed.emit(_current_mode)

func is_focus_ring_visible() -> bool:
    return _current_mode == InputMode.KEYBOARD_GAMEPAD
```

**Per-widget visibility rule.** Each focusable widget (an Inventory slot `Button`/`TextureButton`, or any future screen's focusable control) connects to its screen's `InputModeTracker.input_mode_changed` signal and to its own `focus_entered`/`focus_exited` signals, showing its focus-ring overlay only when `has_focus() AND tracker.is_focus_ring_visible()` is true. Mouse hover is driven entirely separately by the widget's own `mouse_entered`/`mouse_exited` signals, producing a distinct hover highlight. The two visual states are never merged into a single "highlighted" boolean — this directly mirrors Godot 4.6's own dual-focus split rather than fighting it.

**Explicit `focus_neighbor_*` wiring.** `focus_neighbor_top/bottom/left/right` are set explicitly per interactive grid at scene-build time — never left to Godot's automatic nearest-neighbor traversal. This is required regardless of the 4.6 dual-focus change (`focus_neighbor_*` resolution is listed as "unchanged" in 4.6 per the engine reference docs); it is necessary because `inventory.md`'s "wrapping at grid edges to switch tabs" behavior cannot be expressed by automatic traversal.

**Connect `input_mode_changed` ONCE per screen, never once per widget.** Discovered during Story 007's live implementation (2026-07-15), not anticipated when this ADR was first written: `Signal.connect()` deduplicates by `(target object, method)` and ignores differing `.bind()` arguments. A naive per-widget connection loop — e.g. `tracker.input_mode_changed.connect(_on_input_mode_changed.bind(widget, ring))` called once per grid slot — silently fails for every widget after the first; Godot logs an "already connected" error and drops the connection, with no compile-time warning. **Correct pattern**: make exactly ONE connection for the whole screen (typically in `_ready()`, to a bare `_on_input_mode_changed(mode)` handler with no bound args), and have that single handler iterate every tracked widget internally (e.g. via parallel arrays or a stored list of `{widget, ring}` pairs) to update each one's ring visibility. `focus_entered`/`focus_exited`/`mouse_entered`/`mouse_exited` connections remain safely per-widget, since each widget's own signal is a distinct emitter — the dedup risk is specific to fanning multiple widgets out from one SHARED signal (the tracker's).

### Architecture Diagram

```
UI Screen (e.g. InventoryScreen.tscn)
├── InputModeTracker (Node) — instanced per screen, NOT an Autoload
│     signal input_mode_changed(mode: InputMode)
│     _input(event) sniffs event type; emits only on mode change
├── InventoryGrid (GridContainer)
│     └── [Slot Button/TextureButton × N]
│           focus_neighbor_top/bottom/left/right — wired explicitly, not auto
│           connects: InputModeTracker.input_mode_changed, self.focus_entered/exited, self.mouse_entered/exited
│           shows focus ring when:    has_focus() AND InputModeTracker.is_focus_ring_visible()
│           shows hover highlight when: mouse currently over this slot (independent of focus ring)
└── CraftingPanel (right panel) — shares the same InputModeTracker instance
```

### Key Interfaces

```gdscript
# InputModeTracker.gd — reusable helper, instanced per interactive UI screen
class_name InputModeTracker
extends Node

enum InputMode { MOUSE, KEYBOARD_GAMEPAD }
signal input_mode_changed(mode: InputMode)

func _input(event: InputEvent) -> void: ...     # see Decision for full body
func is_focus_ring_visible() -> bool: ...       # true when current mode == KEYBOARD_GAMEPAD

# Consumer pattern (any focusable widget on a screen with an InputModeTracker):
func _on_focus_entered() -> void:
    _update_ring_visibility()

func _on_input_mode_changed(_mode: InputModeTracker.InputMode) -> void:
    _update_ring_visibility()

func _update_ring_visibility() -> void:
    focus_ring.visible = has_focus() and input_mode_tracker.is_focus_ring_visible()
```

## Alternatives Considered

### Alternative 1: Always-visible focus ring, no input-mode detection
- **Description**: Wire `focus_neighbor_*` for gamepad/keyboard traversal as usual, but always render the focus-ring overlay on whichever control currently `has_focus()`, regardless of what input method is active.
- **Pros**: Zero detection code; simplest possible implementation.
- **Cons**: Does not satisfy `inventory.md`'s own explicit requirement that the focus ring be "distinct from hover" — under mouse-only play, the ring would sit on whatever control last received keyboard/gamepad focus (e.g., the first slot on screen open) while the mouse hovers somewhere else entirely, reading as a stray, unexplained highlight.
- **Rejection Reason**: Directly contradicts an already-Approved-adjacent GDD requirement; not a real option once that requirement is taken seriously.

### Alternative 2: Project-wide `FocusManager` Autoload
- **Description**: A new Autoload tracks input mode once for the whole game; all UI screens read from it.
- **Pros**: Single shared instance; no per-screen instancing step to remember.
- **Cons**: This project's UI screens are inherently scene-instanced and context-specific (Sanctuary vs Mission), matching ADR-0002's existing boundary classification — there is no cross-scene state to actually share here (a screen's "what is the player doing right now" input mode has no meaning once that screen is torn down). Adding a 9th Autoload for a concern with no cross-scene lifetime requires an ADR-0002 boot-order revision for no structural benefit.
- **Rejection Reason**: Ownership should sit at the scope where the state actually matters — the individual screen — not be promoted to global scope by default.

### Alternative 3: Per-widget `mouse_entered`/`focus_entered` signals only, no centralized tracker
- **Description**: Each widget independently tracks "was my own last relevant event a mouse or keyboard/gamepad event" with no shared, screen-level source of truth.
- **Pros**: No new helper class at all.
- **Cons**: On a 40-slot inventory grid (Inventory's maximum tier), this means 40 independent pieces of "am I in mouse mode" logic that must all agree with each other and with the tab bar and Crafting panel — any drift (e.g., one widget's local detection lagging behind another's) produces visibly inconsistent focus-ring behavior across the grid.
- **Rejection Reason**: A single, authoritative source of truth per screen is cheap (one small helper node) and eliminates an entire class of cross-widget consistency bugs.

## Consequences

### Positive
- Satisfies `inventory.md`'s "distinct from hover" focus requirement exactly, using Godot 4.6's dual-focus split as the mechanism rather than working around it.
- Reusable across all future interactive UI screens without duplicating detection logic.
- No new Autoload, no boot-order revision.
- The pattern is engine-version-agnostic in its core technique (input-event-type sniffing); only the *reason it's now necessary* is 4.6-specific (pre-4.6, focus and hover weren't split, so a naive single "highlighted" boolean happened to look correct by accident).

### Negative
- Each screen needing this must remember to instance `InputModeTracker` and wire the `has_focus() AND is_focus_ring_visible()` check per widget — a convention enforced by code review, not by the engine or type system.
- Slight duplication: one small tracker node per screen rather than one shared global instance. Accepted — this matches the project's existing Presentation-layer scene-instanced boundary rather than introducing a service locator for a screen-scoped concern.

### Risks
- **Risk**: A future widget forgets the `is_focus_ring_visible()` check and always shows its ring regardless of input mode, silently reintroducing Alternative 1's problem for just that widget. **Mitigation**: Document the convention in `control-manifest.md`'s Presentation layer section once it is next regenerated (it is currently stale — last updated 2026-05-16, `ADRs Covered: 0001–0004` — see `architecture-review-2026-07-13.md`'s standing recommendation to run `/create-control-manifest`); code review is the enforcement mechanism until then.
- **Risk**: Gamepad-driven `focus_entered` firing under 4.6's dual-focus split is not explicitly documented at the signal-order level in the project's engine reference docs (flagged by godot-specialist review). **Mitigation**: Verification Required item above — one live smoke test with a gamepad before Story 007 merges.
- **Risk**: Touch input (out of scope per `technical-preferences.md`) arriving as `InputEventScreenTouch`/`InputEventScreenDrag` is silently ignored by the tracker's `_input()` handler (falls through the `else: return` branch). **Mitigation**: This is intentional, not an oversight — documented here so a future contributor doesn't "fix" it into an unsupported touch-mode branch.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| inventory.md | "Focus always renders a visible, non-color-dependent highlight... distinct from hover" | `InputModeTracker` + per-widget `has_focus() AND is_focus_ring_visible()` check |
| inventory.md | "D-pad/left-stick moves selection via 2D spatial adjacency... wrapping at grid edges to switch tabs" | Explicit `focus_neighbor_*` wiring per grid, not automatic traversal |
| inventory.md | "Keyboard-only input mirrors the same grid-adjacency model" | Same `focus_neighbor_*` wiring serves both keyboard and gamepad — both are `KEYBOARD_GAMEPAD` mode in this ADR's model |
| technical-preferences.md | Full K/M + gamepad parity; no hover-only interactions | Focus ring (keyboard/gamepad) and hover highlight (mouse) are deliberately separate, non-conflated visual channels |

## Performance Implications
- **CPU**: Negligible. One `_input()` handler per active UI screen instance, only active while that screen is open; no per-frame polling.
- **Memory**: One small `Node` instance per open interactive screen. Negligible.
- **Load Time**: None.
- **Network**: Not applicable (single-player).

## Migration Plan
Greenfield — no existing focus-handling code to migrate. Story 007 (Inventory's two-panel screen) is the first consumer. `InputModeTracker` should be authored once, generically, so Sanctuary UI and Tarot Deck UI can reuse it verbatim when those GDDs/screens are built.

## Validation Criteria
- Switching from a mouse click to a keyboard arrow-key press within one screen toggles `InputModeTracker`'s mode and emits `input_mode_changed` exactly once (not on every subsequent keypress in the same mode).
- Visual verification: focus ring visible after a gamepad D-pad press with the mouse stationary over an unrelated slot; ring hidden after a subsequent mouse click elsewhere, even though keyboard/gamepad focus has not moved.
- Tab-wrap: pressing left-stick/D-pad past the grid's left edge on the leftmost column switches to the previous tab (per `inventory.md`), confirmed via `focus_neighbor_*` wiring — not relying on automatic traversal.
- Live gamepad smoke test (per Verification Required): `ui_down` action moves focus and the ring renders with no mouse input at all.

## Related Decisions
- ADR-0002 — Scene and Autoload structure (precedent for classifying Presentation-layer concerns as scene-instanced, not Autoload)
- ADR-0010 — Hero Tower-Synced Class (original loose reference to this ADR as "Hero stat display" — corrected here; Hero's HUD stat elements are non-interactive and need no focus handling)
- `design/gdd/inventory.md` — Story 007's UI Requirements, the concrete driver for this decision
- `.claude/docs/technical-preferences.md` — K/M + gamepad parity mandate
