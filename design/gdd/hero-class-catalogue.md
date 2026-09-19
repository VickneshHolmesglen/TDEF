# Hero Class Catalogue

> **Type**: Content Catalogue (not a System GDD — see `hero.md` Group 4, Rule 23: "The Hero System GDD specifies the mechanics; the class catalogue specifies the content"). Does not duplicate mechanics already defined in `hero.md`; only adds the content this project's Tower-Synced Class System needs to actually run.
> **Governing GDD**: `hero.md` (Group 4 "Tower-Synced Class System", Group 5 "Tower Affinity", Formula 1, Tuning Knobs, Class Identity Display section)
> **Status**: Draft — first-pass content catalogue. Perk mechanics and safe ranges are specified and playtestable; **exact perk magnitudes are pending the same first-playable-mission balance-calibration pass `hero.md`'s own OQ-2 (base stats) is already deferred to** — not invented numbers presented as final.
> **Author**: Game Designer (this session)
> **Last Updated**: 2026-08-27

---

## Scope

`hero.md` Rule 13 gives the hero no fixed class; class identity is earned via proximity to towers of a given archetype. Rule 22's table names four class identities mapped to the four tower archetypes that exist in the shipped schema (`FoundationComponent.archetype: String = "physical" | "ranged" | "elemental" | "support"` — confirmed via `src/core/tower/foundation_component.gd`, 4 possible values, no sub-archetypes). **This catalogue therefore defines exactly 4 classes — one per existing archetype, not more** — Formula 3's own worked example ("Frost class UNLOCKED") is illustrative flavor text in the GDD, not a claim that per-element sub-classes (Frost/Fire/Storm distinct from a single "Mage" class) exist in the current schema. A richer sub-archetype class system is a legitimate future expansion, out of scope here.

## Naming Reconciliation (real finding, flagged not silently resolved)

`hero.md`'s own "Class Identity Display" section names the required foundation-layer badge assets as `warrior.png`, `archer.png`, `mage.png`, `support.png`, implying `class_id ∈ {warrior, archer, mage, support}`. The shipped implementation (`hero.gd::_update_class_proximity()`) does not use those strings — it sets `_primary_class` directly from the tower's own `archetype` field and emits it unchanged via `hero_class_unlocked(arch, ...)`, so the **real runtime `class_id` values are `physical`, `ranged`, `elemental`, `support`** — the archetype strings, not the flavor names.

**Resolution used by this catalogue**: `class_id` = the archetype string (matches shipped code, zero code changes required). The flavor name (Warrior/Archer/Mage/Support) is a `display_name` only. This means `hero.md`'s own badge-asset list is stale and should be corrected to `physical.png`/`ranged.png`/`elemental.png`/`support.png` (asset path convention: `assets/ui/class_badges/[class_id].png`, per the doc's own existing pattern) — flagged here for the next `hero.md` revision pass, not changed unilaterally in that file by this catalogue.

---

## The 4 Classes

### `physical` — Warrior

**Archetype match** (Rule 22): Physical / melee towers (`archer`, `bulwark`, `siege_cannon` in the current 13-blueprint set — see `tower-content-catalogue.md`).
**Flavor**: A hero who fights alongside physical-tower fortifications — front-line durability, steady damage.

| Perk | Effect | Mechanism | Safe Range |
|---|---|---|---|
| **Primary — Bulwark Stance** | Flat Armor bonus | `flat_bonus` on Hero stat #6 (Armor), via Formula 1 | +8 – +20 flat Armor |
| **Secondary — Battle-Hardened** | % max HP bonus | `additive_bonus_total` contribution on Hero stat #1 (Health) | +10% – +20% |

### `ranged` — Archer

**Archetype match**: Ranged towers (`longshot_sniper`, `volley_crossbow`).
**Flavor**: A hero who plays the same long-range, high-precision game as ranged towers.

| Perk | Effect | Mechanism | Safe Range |
|---|---|---|---|
| **Primary — Extended Reach** | % Attack Range bonus | `additive_bonus_total` on Hero stat #8 (Attack Range) | +15% – +30% |
| **Secondary — Steady Aim** | % Crit Chance bonus | `additive_bonus_total` on Hero stat #5 (Crit Chance) | +5% – +12% (respects the 80% Crit Chance cap already in `hero.md` Tuning Knobs) |

### `elemental` — Mage

**Archetype match**: Elemental towers (`arcane_lance`, `firebolt_turret`, `firestorm_spire`, `frostbolt_turret`, `storm_turret`, `venomdart_turret`) — by far the largest archetype group in the current catalogue (6 of 13 towers).
**Flavor**: A hero whose skills hit harder alongside the game's most numerous and varied tower archetype.

| Perk | Effect | Mechanism | Safe Range |
|---|---|---|---|
| **Primary — Arcane Attunement** | % Magic Attack bonus | `additive_bonus_total` on Hero stat #7 (renamed Magic Attack, formerly Skill Power — Hero Combat & Stats Redesign, 2026-09-18) | +15% – +30% |
| **Secondary — Elemental Ward** | Flat bonus, all 5 Elemental Resistances | `flat_bonus` on Hero stat #9 (Elemental Resistances), applied uniformly across fire/frost/poison/lightning/arcane | +5% – +12% each (respects the 75%-per-element cap already in `hero.md` Tuning Knobs) |

### `support` — Support

**Archetype match**: Support towers (`barrier_ward`, `rally_banner`).
**Flavor**: A hero who reinforces the team the way support towers reinforce the field — utility and sustain over raw damage.

| Perk | Effect | Mechanism | Safe Range |
|---|---|---|---|
| **Primary — Field Medic** | % Lifesteal bonus | `additive_bonus_total` on Hero stat #10 (Lifesteal) | +8% – +15% (respects the 40% Lifesteal cap already in `hero.md` Tuning Knobs) |
| **Secondary — Efficient Casting** | % Cooldown Reduction bonus | `additive_bonus_total` on Hero stat #4 (CDR) | +8% – +15% (respects the 75% CDR cap already in `hero.md` Tuning Knobs) |

---

## Worked Example (Formula 1 applied to a class perk)

`physical` class designated Primary — Bulwark Stance active (+14 flat Armor, mid-range pick):

```
base_armor = 30 (TBD-at-production base, illustrative), flat_bonus = +14, additive_bonus_total = 0.0 (no other Armor bonuses this example)
effective_armor = (30 + 14) × (1 + 0.0) = 44
```

Matches `hero.md` Formula 1 exactly — class perks are just another `flat_bonus`/`additive_bonus_total` contributor, no new formula needed.

---

## Palette & Badge Data (Art Bible-gated — placeholders only)

`hero.md`'s Class Identity Display section requires `assets/data/class_palettes.tres` (hue rotation/saturation per class) and 4 badge icons — **neither exists yet** (confirmed: no matching file under `assets/`). Both are explicitly gated on the Art Bible per `hero.md`'s own "Art Bible Dependencies" note (#2: "Class palette lookup table values (requires master color palette and colorblind accessibility standards)"). This catalogue does not invent final colors; it only pins the `class_id` keys the eventual `class_palettes.tres` must use:

| `class_id` | Badge asset (corrected path) | Palette key |
|---|---|---|
| `physical` | `assets/ui/class_badges/physical.png` | `class_palettes.tres["physical"]` |
| `ranged` | `assets/ui/class_badges/ranged.png` | `class_palettes.tres["ranged"]` |
| `elemental` | `assets/ui/class_badges/elemental.png` | `class_palettes.tres["elemental"]` |
| `support` | `assets/ui/class_badges/support.png` | `class_palettes.tres["support"]` |

---

## Open Items (honestly carried forward, not resolved here)

1. **Perk magnitudes are first-draft, not calibrated** — same status as `hero.md` OQ-2 (base stats). Both should be set together at the same first-playable-mission balance pass, since class perks and base stats interact (a Warrior's Bulwark Stance is only meaningful relative to the base Armor value OQ-2 hasn't set yet). **Partially consumed 2026-09-20**: the Hero Leveling System's every-5th-level class bonus (`hero.md` Rule 33, `hero.gd`'s `CLASS_LEVEL_BONUS`) now retargets each class's per-level reward to that class's own Primary perk identity from this catalogue (Bulwark Stance/Extended Reach/Arcane Attunement/Field Medic), rather than the ad-hoc placeholder stats that mechanism originally invented before this catalogue was reconciled against it. The perk MAGNITUDES used there are still this system's own placeholder per-level increments, not a calibrated value from this catalogue — that calibration pass remains open.
2. **`hero.md`'s badge-asset naming is stale** vs. shipped `class_id` values — flagged above, not edited in `hero.md` by this catalogue (a `hero.md` revision, not a catalogue concern).
3. **`assets/data/class_palettes.tres` and the 4 badge PNGs remain unauthored** — blocked on the Art Bible, per `hero.md`'s own existing dependency note. This catalogue pins the keys they'll need.
4. Does **not** resolve `hero.md` OQ-9 (Tower Affinity vs. cost-efficiency tension) — that OQ is about the Tower Affinity *formula*, not class perk content, and remains a deliberately deferred design decision per the user's 2026-07-15 choice.
