# Memory Index

- [Pathfinding AC Review Findings](project_pathfinding_ac_review.md) — fifth review 2026-05-20: 6 blockers (AC-2 internal state, AC-4/AC-17 hardware doc absent, AC-11 push_warning infra gap, AC-16 headless frame undefined, AC-20 cross-system velocity assertion)
- [Tower System AC Review Findings](project_tower_ac_review.md) — 9 blocking findings: AC#3 trigger contradiction (3 specs disagree), AC#1 EventBus payload mismatch (OQ-1), AC#14 no HP polling API, AC#23 Constellation undesigned, AC#24 no measurement method
- [Wave Manager AC Review Findings](project_wave_manager_ac_review.md) — 9 blockers: AC-5/6/7 internal state, AC-12 cross-system assert, AC-18 no mocked timer spec, AC-19b wrong document (tooling), AC-22 duration conflict (20s vs 30s), AC-8 same-frame ordering unspecified, missing AC for boss fast-path + wave_preview_available
