# EventBus System GDD — Review Log

---

## Review — 2026-05-14 (pass 1) — Verdict: NEEDS REVISION → APPROVED (in-session)
Scope signal: L
Specialists: None (lean mode)
Blocking items: 2 (both resolved in-session) | Recommended: 4
Summary: First review pass. Two blockers resolved in-session: B1 — `monster_damage_taken` payload in the D&S catalogue section still referenced the deprecated `hero_bonus_applied: bool` field (replaced by `hero_bonus_tier: int` across D&S, Monster, and entities.yaml in prior sessions); field updated to `hero_bonus_tier: int`. B2 — `hero_auto_attacked` payload in the Hero System catalogue section still referenced the deprecated `hero_damage_bonus_eligible: bool` field; field updated to `hero_bonus_tier: int`. These two fixes close the last open EventBus cross-GDD follow-ups from D&S pass 6. R1 applied in-session: catalogue count corrected from 67 → 70 events and 16 → 19 publishing systems (three events added after the count was last written: `wave_stalled`, `wave_preview_available`, `tower_wave_summary`); AC-08 updated to reference "70-event catalogue". A `hero_bonus_tier` values note (0=STANDARD, 1=ELITE, 2=BOSS) added alongside the existing `source_type` note. Four recommended items outstanding: wave_manager.md D&S subscription note (Wave Manager re-review); ADR-0002 (dispatch policy, payload contract, Autoload order); `hero_class_unlocked` EventBus catalogue registration (OQ-4 from Hero GDD); `hero_health_changed` ownership confirmation.
Prior verdict resolved: N/A — first review
