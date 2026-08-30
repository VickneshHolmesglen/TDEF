# Tower Layer Render Evidence

Captured 2026-08-30 with the project-pinned Godot 4.6.2 stable Windows binary.

## Evidence

- `tower-layer-shape-families.png` — all nine Foundation-selected Base/Shaft/Top families.
- `tower-layer-weapon-tops.png` — siege cannon, railgun laser, arcane lance, storm emitter, firestorm emitter, and frost emitter crowns on representative bodies.
- Runtime composite height is 64 world units and bottom-centred. The sheets display that production geometry at 2x zoom for join inspection.
- Contrasting panels and ground lines make transparent gaps and bottom-anchor drift visible.

## Visual inspection result

Pass. Square/Bulwark and Hex-plank/Siege now seat into their pedestals; Triangle/Longshot and the railgun crown meet their narrow mounts; the remaining families and weapon crowns join without floating gaps or destructive over-embedding.

The first rendered pass proved that a universal overlap could not compensate for each generated asset's different transparent padding. `TowerInstance` now uses a complete deterministic profile for every silhouette family and every dedicated weapon crown. Unknown/future components retain a conservative modular fallback profile.

## Reproduction

```powershell
& 'C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe' --path 'G:\TDef' res://production/qa/evidence/TowerLayerRenderCapture.tscn
```

The capture harness resolves textures and transforms through a live `TowerInstance`. It uses capture-only flattened `TextureRect` proxies because nested CanvasItems were unreliable in an offscreen SubViewport on the pinned Windows renderer; this does not alter runtime composition.

## Automated verification

`tests/unit/tower/tower_instance_test.gd`: 26/26 passing, including complete profile coverage for nine families and six dedicated crowns plus 64-unit height/bottom-anchor invariants across every mapping.

`tests/integration/mission_scene/mission_scene_the_gap_test.gd`: 16/16 passing, confirming the live placement/removal path still creates real tower visuals with component presentation identity.
