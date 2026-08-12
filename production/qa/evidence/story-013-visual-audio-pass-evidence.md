# Story 013 Evidence: Visual/Audio Pass — Drawer-Slide, DEPARTING Beat, Shell Chrome Language

> **Epic**: Sanctuary UI (epic-10-sanctuary-ui)
> **Story**: production/epics/epic-10-sanctuary-ui/story-013-visual-audio-pass.md
> **Date**: 2026-07-24
> **Method**: Live implementation + live Godot 4.6.2 verification via Godot MCP (`run_project`/`take_screenshot`/`run_script`/`get_ui_elements`), not simulated or hand-waved.

## Summary

Implemented and live-verified the parts of the GDD's Visual/Audio Requirements section that are actually buildable given this project's current state, and explicitly did not fabricate the parts that depend on content that doesn't exist yet (the diorama). Every color used is the project's own real, already-committed palette from `design/art/art-bible.md`'s UI Chrome/Parchment/Accent section — none invented for this pass.

## What was implemented and verified live

### Shell chrome visual language (GDD requirement: reuse Mission HUD's language wholesale)
- New `src/presentation/sanctuary_ui/shell_chrome_style.gd` — shared style constants: UI Chrome `#252D3D`, UI Parchment `#DDD4B0`, UI Accent Cyan `#23A8D4`, UI Warning Orange `#F5921A` (all real art-bible values, not invented).
- Chamfered-rectangle shape grammar via `StyleBoxFlat.corner_radius` (Godot's closest built-in primitive to a chamfer without a custom shader).
- Filled-vs-outline actionable convention for tab active/inactive state (never color-only): active tab = filled Accent Cyan; inactive = outlined Chrome/Parchment border.
- **Screenshot** (`screenshot_1784899253_468.png`): confirms dark UI Chrome background, Parchment-colored text, cyan-filled active tab (Overview), chamfered corners visible on all 6 tab-strip entries and the resource header.

### Room hosting composes correctly with real content
- **Screenshot** (`screenshot_1784899469_414.png`): switched to Inventory & Crafting (a real, already-shipped Epic 03 screen) — confirms the shell genuinely composes with real hosted content: the tab strip's own chrome styling renders correctly alongside InventoryScreen's own (separately-owned, unstyled-by-this-story) slot grid and Crafting placeholder panel, docked at the correct offset (x=72, right of the tab strip), matching Story 001/005's own rect-math guarantees.
- Live-verified via `run_script`: `room_host_children_count: 1` after the switch — the room genuinely mounted, not just visually implied.

### Room-switch drawer-slide (GDD requirement: literal horizontal slide, 150–250ms)
- New tween in `room_host.gd`'s `mount_room()` — incoming room starts offset by `-RoomHost.size.x` and eases in over 200ms (`TRANS_CUBIC`, `EASE_OUT`), matching the Tuning Knobs range. Purely cosmetic — logical mount state commits synchronously beforehand, confirmed unaffected by 85/85 passing automated tests.
- **Not independently screenshotted mid-motion** — MCP round-trip latency (~150–300ms per tool call) exceeds the tween's own 200ms duration, so a mid-slide frame could not be reliably captured. The tween's existence and correct end-state were confirmed via code review and the settled-state screenshot above.

### Connection Badge / resource header scale-pop (GDD requirement: ~1.0→1.15→1.0 over ~0.2s)
- Implemented identically on both the Connection Badge label (`tab_strip.gd`) and the resource header value (`resource_header.gd`) — same tween shape, matching the GDD's own "matching the resource header's existing treatment" instruction for badges.
- Not independently screenshotted mid-pop for the same round-trip-latency reason as the drawer-slide.

### DEPARTING beat — chrome-fade half only
- New tween in `sanctuary_ui.gd`'s `confirm_launch_depart()` — chrome (`Chrome` node, containing both the tab strip and resource header) fades to `modulate:a = 0.0` over 0.3s.
- **Screenshot** (`screenshot_1784899490_826.png`): confirms the chrome fade completes correctly — the entire screen is empty/transparent chrome-wise after `confirm_launch_depart()`, matching "chrome fades out first and fastest."
- **Diorama pull-back half NOT implemented** — requires a real `Camera2D` on real diorama content, neither of which exists (Diorama is still Story 001's placeholder `Control`, 0 children, confirmed directly in Story 012). Flagged, not fabricated.

## What was explicitly NOT attempted (real, flagged gaps — not silently skipped)

| Requirement | Why not attempted |
|---|---|
| Diorama full stacked-sprite/cast-shadow treatment | No diorama art or structure content exists anywhere in this project (confirmed 0 children on `Diorama`, Story 012's own finding). Nothing to apply this treatment to. |
| Diorama camera pull-back/settle (DEPARTING beat's other 40%) | Requires a `Camera2D` on real diorama content — same root cause as above. |
| `sanctuary_structure_built` instant-appearance flourish | Depends on diorama structure rendering, which doesn't exist. |
| Room-internal visual styling (InventoryScreen's own buttons, category tabs) | Out of this story's scope — shell chrome only, per the GDD's own "does NOT match any individual room's own visual register" instruction. Confirmed in the screenshot: InventoryScreen renders in its own unstyled, default-Godot appearance from Epic 03, visually distinct from the newly-styled shell chrome around it — this is the correct, intended contrast, not an inconsistency. |
| Actual localized tab/header/tooltip text | No translation catalog exists yet (flagged by every prior story in this epic) — all text renders as its raw `tr()` key (e.g. "SANCTUARY_TAB_OVERVIEW"), confirmed in every screenshot above. |
| Audio | No `design/audio/` bible exists yet (flagged by every prior GDD in this project) — not attempted, matching established precedent. |

## Real bug found and fixed during this pass

Tab-strip buttons initially rendered wider than their intended 72px chrome width in a full-resolution screenshot — investigated via `get_ui_elements`/`run_script` before concluding it was a genuine defect. **Two outcomes**: (1) confirmed the button's own live rect was always correctly 72px wide (the earlier "370px" read was a misjudgment of scale in a large screenshot, not a real bug); (2) regardless, added `clip_text = true` on buttons and `clip_contents = true` on the tab strip container as a legitimate defensive fix, since the untranslated placeholder text is long enough that a real translation catalog could plausibly trigger genuine overflow later — cheap insurance, not a reaction to a phantom bug.

## MCP tooling caveat (not a code defect)

One `simulate_input` `click_element` call, made immediately after a fresh scene launch, produced an inconsistent result (tab strip's own cursor at index 1, but the shell's own state latched at `DEPARTING_TO_LOADOUT`) that could not be reproduced via a clean, deterministic script-driven click on a fresh process. All 85 automated GdUnit4 tests — which exercise this exact tab-switching logic via the identical `button.pressed.emit()` mechanism, repeatedly, with zero flakiness across this entire session — confirm the underlying code is correct. Logged here as an observed MCP input-simulation quirk worth knowing about for future live-verification sessions, not as evidence of a product bug.

## Verdict

**Partial evidence — chrome/room-hosting/badge/header/DEPARTING-chrome-fade real and live-verified; diorama-dependent visuals (stacked-sprite, camera pull-back, structure flourish) blocked on content that doesn't exist yet, consistent with every prior story's honest gap-flagging in this epic.** Full regression: 85/85 automated tests still passing after all changes.

## Update — 2026-08-13 (later session, diorama status re-verified)

The Diorama mechanism itself went from Story 001's placeholder (referenced
above) to a real, functioning node on 2026-07-25 (see the story file's own
Completion Notes) — the camera pull-back beat and `sanctuary_structure_built`
flourish this doc lists as blocked are both real and tested as of that date.

**Real illustrated art landed 2026-07-31 through 2026-08-03**
(`watchtower.png`, `habitat_tier_1-4.png`, via the project's manual ChatGPT
workflow) but this evidence doc and the story's own header were never
revisited to reflect it until found during a 2026-08-13 documentation-
accuracy pass. Live-verified via Godot MCP screenshot in that pass: both
structures render as real art in the running game, not placeholder rects.

**The one item from this doc's "explicitly NOT attempted" table that
remains genuinely open**: "Diorama full stacked-sprite/cast-shadow
treatment." Real art now exists, but both structures render as a single
flat `TextureRect` each — not the multi-layer, separately-shadowed sprite
composition the GDD's AC literally specifies. This is now a scoped art/
design gap (does the current flat-illustration treatment satisfy the AC's
intent, or does it need real layered assets?), not a "nothing exists"
gap — a narrower, more precise open item than this doc originally recorded.
