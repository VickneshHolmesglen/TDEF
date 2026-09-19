# RPG Game Design Document: Classes & Core Stats System

This document outlines the standard statistical frameworks, resource mechanics, and class structures for an RPG system. It is formatted for direct ingestion and reference by AI development tools (like Claude Code) during implementation.

---

## 1. Core Statistical Framework

### Primary Attributes
Players allocate points into these baseline attributes upon leveling up or character creation.

*   **Strength (STR):** Measures physical power. Governs melee damage scaling, physical carry capacity, and heavy armor requirements.
*   **Dexterity (DEX):** Measures precision, balance, and fine motor skills. Governs ranged weapon scaling, physical accuracy, and critical hit multipliers.
*   **Agility (AGL):** Measures raw speed, reflex, and movement velocity. Governs evasion rates, turn order (initiative), and attack speed.
*   **Constitution (CON):** Measures physical durability and metabolic thresholds. Dictates maximum health scaling and physical damage reduction.
*   **Intelligence (INT):** Measures cognitive power and arcane affinity. Governs offensive magic scaling and spell penetration.
*   **Wisdom (WIS):** Measures spiritual awareness and mental fortitude. Governs healing potency, maximum mana, and magic defense thresholds.
*   **Charisma (CHA):** Measures social presence and leadership. Impacts vendor pricing, dialogue vectors, and minion/summon scaling.
*   **Luck (LUK):** Measures high-variance situational probability. Governs loot drop rates, status effect infliction chances, and random critical triggers.

### Derived & Secondary Stats (Calculated)
```
[STR] ──────────────────────────► Physical Attack (ATK)
[DEX] ──────────────────────────► Critical Strike Chance (CRIT%) / Accuracy (HIT)
[AGL] ──────────────────────────► Evasion Rate (EVA) / Action Speed (SPD)
[CON] ──────────────────────────► Max Hit Points (HP) / Physical Defense (DEF)
[INT] ──────────────────────────► Magic Attack (MATK)
[WIS] ──────────────────────────► Max Magic/Mana Points (MP) / Magic Defense (MDEF)
```

---

## 2. The Four Fundamental Classes

| Class Archetype | Core Attributes | Resource System | Primary Tactical Role | Sub-Class Specialisations |
| :--- | :--- | :--- | :--- | :--- |
| **🛡️ Warrior** | STR, CON | **Rage / Stamina** (Generates from combat) | Frontline Tank, Crowd Control, Threat (Aggro) Management | Guardian (Defense), Berserker (High-risk DPS), Weapon Master (Versatile) |
| **🔮 Mage** | INT, WIS | **Mana (MP)** (Fixed pool, slow regeneration) | Ranged Burst Damage, Area-of-Effect (AoE), Elemental Status | Pyromancer (DoT/Burst), Cryomancer (Control), Sorcerer (Speed/Chaining) |
| **🗡️ Rogue** | DEX, AGL, LUK | **Energy & Combo Points** (Fast cycle) | Flanking, Single-Target Burst, Evasion, Debuff Infliction | Assassin (Stealth Crit), Saboteur (Traps/Utility), Duellist (Parry Counter) |
| **☀️ Cleric** | WIS, CON | **Faith / Devotion** (Behavior-driven) | Party Healing, Cleansing, Buffs, Anti-Fiend/Undead Utility | Priest (Pure Healer), Inquisitor (Holy DPS), Druid/Shaman (HoTs/Totems) |

---

## 3. Advanced Hybrid Classes

### 🔨 The Paladin (Warrior + Cleric)
*   **Core Attributes:** STR, WIS, CON
*   **Tactical Role:** Frontline Support & Secondary Tank.
*   **Unique Mechanic:** *Auras*. Passive radial buffers that provide persistent stat enhancements (e.g., +DEF, +RES) to all party members within a specific proximity grid.

### ⚡ The Spellblade / Magus (Warrior + Mage)
*   **Core Attributes:** STR, INT, AGL
*   **Tactical Role:** Close-quarters Magic Skirmisher.
*   **Unique Mechanic:** *Elemental Imbues*. Instantly channels spell patterns directly into weapon steel, changing physical strikes into high-frequency elemental properties (e.g., Chain Lightning triggers on sword hit).

### 🎵 The Bard (Rogue + Cleric)
*   **Core Attributes:** CHA, AGL, DEX
*   **Tactical Role:** Force Multiplier / Tactical Buffer.
*   **Unique Mechanic:** *Song Stacking*. Weaves unique rhythm mechanics into combat rotations. Activating consecutive chords provides compounding baseline bonuses to teammates or progressive debuffs to enemies.

### 💀 The Necromancer (Mage + Rogue/Warrior)
*   **Core Attributes:** INT, WIS, CON
*   **Tactical Role:** Attrition, Curse Allocation, & Minion Mastery.
*   **Unique Mechanic:** *Soul Harvest / Corpse Explosion*. Uses the physical remains of defeated enemies as variable resources, transforming units into grid-based explosions or rebuilding them into temporary pets.

---

## 4. Unconventional & Technical Classes

### ⚙️ The Artificer / Machinist (Mage + Rogue)
*   **Core Attributes:** INT, DEX, LUK
*   **Tactical Role:** Zone Denial & Automated Support.
*   **Unique Mechanic:** *Turret Deployment & Scrap Management*. Collects raw scrap items from the battlefield to construct or upgrade fixed position machinery (e.g., upgrading an automated projectile turret into a flamethrower or directional shield).

### 🧪 The Alchemist / Plague Doctor (Cleric + Rogue)
*   **Core Attributes:** INT, WIS, DEX
*   **Tactical Role:** Damage-Over-Time (DoT) & Unconventional Healing.
*   **Unique Mechanic:** *Volatile Concoctions*. Throws mixed chemical reagents to spawn surface hazards (e.g., throwing a grease puddle reagent, then igniting it with a fire-based catalyst to cause an expanding field block).

### ☯️ The Monk / Martial Artist (Warrior + Rogue)
*   **Core Attributes:** STR, AGL, DEX
*   **Tactical Role:** Combo-Chaining & Sustained Melee DPS.
*   **Unique Mechanic:** *Stance Dancing*. Rotates dynamically through specific fluid states. Each stance alters underlying stat modifiers (e.g., Tiger Stance boosts CRIT%, Crane Stance increases EVA, Turtle Stance adds flat DEF mitigation).

### 💨 The Windwalker / Blade Dancer (Rogue + Mage)
*   **Core Attributes:** AGL, DEX, INT
*   **Tactical Role:** Extreme Mobility Skirmisher.
*   **Unique Mechanic:** *Velocity Scaling*. Translates real-time movement frames directly into attack output modifiers. The class must maintain constant spatial repositioning to unlock maximum skill damage tiers.

### 🌌 The Astrologer / Oracle (Mage + Cleric)
*   **Core Attributes:** INT, WIS, CHA
*   **Tactical Role:** Dynamic Buff Allocation & Delayed Scaling.
*   **Unique Mechanic:** *Cosmic Alignment*. Spells cycle in power alongside rolling internal stellar phases. Features abilities like *Fate Weaving*, allowing the player to tag a target unit with a massive buff or debuff designed to trigger exactly X seconds in the future.

### ⏳ The Chronomancer / Time Weaver (Mage + Rogue)
*   **Core Attributes:** INT, AGL, WIS
*   **Tactical Role:** Cooldown Manipulation & Spatial Management.
*   **Unique Mechanic:** *Time Rewind & Paradox*. Records position and status parameters of units. Can snapshot a unit and instantly force its coordinates, HP, and MP states back to that exact data point 5 seconds prior. Overusing time commands fills a *Paradox* gauge, resulting in self-inflicted cosmic backlashes.

### 🩸 The Blood Mage / Hemomancer (Mage + Warrior)
*   **Core Attributes:** INT, CON, STR
*   **Tactical Role:** High-Damage Burst & Self-Sustaining Attrition.
*   **Unique Mechanic:** *Vampiric Resource Swap*. Removes traditional mana requirements entirely. Spells cost a percentage of the caster's active health pool. Employs draining tethers to siphon health vectors away from enemies to replenish their own vital assets.

### 🎲 The Gambler / Corsair (Rogue + Luck)
*   **Core Attributes:** LUK, DEX, AGL
*   **Tactical Role:** High-Variance High-Reward Burst.
*   **Unique Mechanic:** *Loaded Dice / Jackpot RNG*. Relies heavily on procedural random number generation. Attacks generate random dice variables; building complete poker hands or matching slot symbols triggers immense party-wide hyper-buffs, whereas failure chains risk temporary weapon jamming or backfires.