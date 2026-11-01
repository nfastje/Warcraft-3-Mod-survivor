# Balance and mechanics pass (plan, 2026-11-01)

Goal: Normal stops being a steamroll, progression is earned, and the Warcraft III stat
system (Strength, Agility, Intellect, plus Stamina and Armor) drives every hero. Mana costs
make Intellect and mana regeneration matter. Items each feel different.

All of it lives in `src/ashenvale_survivor.lua`, so it works the same in the standalone
engine and in Reforged. The rule about `%` in that file still applies.

## Decisions

| Topic | Decision |
| --- | --- |
| Spell and attack scaling | Each hero's spells **and** auto attack scale with its **primary attribute** |
| Unlocks | **Talents and heroes** unlock through achievements. Perks stay as they are (achievement points) |
| Existing saves | **Full reset**: new save version, the old profile kept as a backup file |
| Normal difficulty | **Hard, roguelite-style**: early runs are expected to fail; meta progression carries you |
| Names | Strength, Agility, **Intellect** (WoW's word for Warcraft III's Intelligence), Stamina, Armor |
| Icons | The Warcraft III item that gives the stat: Gauntlets of Ogre Strength, Hood of Cunning, Robe of the Magi, Periapt of Vitality, Ring of Protection. Only icons already in the trimmed game data (`tools/web_trace_reads.txt`) |

## Why Normal is a steamroll today

From the current code:

- **About 70 level-ups per 10-minute run.** `G.xpFor` is gentle and the smoke test's Normal run
  ends at level 68 to 72. Every level is a card.
- **Spells grow without limit, fast.** Each rank adds +35 percent damage (`G.spellValues`), and the
  cooldown shrinks 5 percent per rank, compounding. Rarity adds up to +80 percent on top.
- **Stat cards stack without limit.** Might is +10 percent damage per pick, forever.
- **Everything is open on day one.** All 11 talents can be bought from the first run, and all 25 heroes are playable.
- **Enemies barely scale.** Over a run, enemy health grows only x1.75 (`1 + 0.75 x progress` in
  `G.createEnemy`) and damage x1.9. Ashenvale runs at power 0.7 and density 0.8.

So player power grows by an order of magnitude while enemies grow less than 2x.

## 1. Attributes (phase 1, done 2026-11-01)

As built:

- `HEROES` carries `primary`, `attr` (level 1), `gain` (per level), `damage` (the weapon: weapon plus the
  primary attribute equals the old level 1 attack) and `armor`. Tuning numbers are in `CFG` (`HP_BASE`,
  `HP_PER_STAMINA`, `REGEN_PER_STRENGTH`, `ATTACK_SPEED_PER_AGILITY`, `ARMOR_PER_AGILITY`,
  `SPELL_POWER_PER_POINT`, `STACK_FALLOFF`).
- Spell power is `(1 + 0.01 x primary) / (1 + 0.01 x level 1 primary)`: exactly 1 at level 1, so each
  hero starts as strong as before. It scales spell damage, heals and summon health.
- Stat cards: Strength, Agility, Intellect (+5, rounded up by rarity), Stamina (+3), Armor (+2). Every
  other card gives 85 percent of the previous pick of it. Might, Vigor and Fortitude are gone; talents
  and items still give their damage bonus (shown as "Damage bonus").
- The HUD stats panel lists the five stats first (primary in gold), then attack damage, spell power and
  the rest. The lobby shows health, attack and attributes.
- Faction traits are unchanged: they already use armor, attack speed, dodge and the like.
- Saves: version `WS2` in `profile2.pld`. The old `profile.pld` is left untouched as the backup.
- Measured (no bonuses): attack damage grows about x4.5 from level 1 to 30, spell power x1.7. With
  today's 50 to 70 levels a run, heroes end stronger than before. Phase 5 sets the pacing.

Planned:

### Hero attributes (Warcraft III 1.29 `UnitBalance.slk`)

Every hero keeps its real Warcraft III numbers: base value, and gain per level.

| Hero | Primary | Str (+lvl) | Agi (+lvl) | Int (+lvl) |
| --- | --- | --- | --- | --- |
| Archmage | Int | 14 (+1.8) | 17 (+1) | 19 (+3.2) |
| Mountain King | Str | 24 (+3) | 11 (+1.5) | 15 (+1.5) |
| Paladin | Str | 22 (+2.7) | 13 (+1.5) | 17 (+1.8) |
| Blood Mage | Int | 18 (+2) | 14 (+1) | 19 (+3) |
| Blademaster | Agi | 18 (+2) | 24 (+1.75) | 16 (+2.25) |
| Far Seer | Int | 15 (+2) | 18 (+1) | 19 (+3) |
| Tauren Chieftain | Str | 25 (+3.2) | 10 (+1.5) | 15 (+1.3) |
| Shadow Hunter | Agi | 15 (+2) | 20 (+1.5) | 17 (+2.5) |
| Death Knight | Str | 23 (+2.7) | 12 (+1.5) | 17 (+1.8) |
| Dreadlord | Str | 20 (+2.5) | 16 (+1) | 18 (+2.5) |
| Lich | Int | 15 (+2) | 14 (+1) | 20 (+3.4) |
| Crypt Lord | Str | 26 (+3.2) | 14 (+1.2) | 14 (+1.6) |
| Demon Hunter | Agi | 19 (+2.4) | 22 (+1.5) | 16 (+2.1) |
| Keeper of the Grove | Int | 16 (+1.8) | 15 (+1.5) | 19 (+2.7) |
| Priestess of the Moon | Agi | 18 (+1.9) | 19 (+1.5) | 15 (+2.6) |
| Warden | Agi | 18 (+2.4) | 20 (+1.6) | 15 (+2) |
| Naga Sea Witch | Int | 15 (+2) | 16 (+1) | 22 (+3) |
| Dark Ranger | Agi | 18 (+1.9) | 21 (+1.5) | 15 (+2.6) |
| Beastmaster | Str | 22 (+2.9) | 14 (+1.3) | 15 (+1.8) |
| Pandaren Brewmaster | Str | 22 (+3) | 14 (+1.5) | 15 (+1.5) |
| Firelord | Agi | 15 (+2) | 20 (+1.6) | 18 (+2.5) |
| Goblin Tinker | Int | 20 (+2.4) | 15 (+1) | 20 (+2.6) |
| Goblin Alchemist | Str | 25 (+3.3) | 10 (+1) | 18 (+2) |
| Pit Lord | Str | 26 (+3.2) | 14 (+1.3) | 14 (+1.5) |
| Medivh (campaign unit, no data) | Int | 15 (+1.6) | 14 (+1) | 22 (+3.3) *(proposed)* |

10 Strength heroes, 7 Agility, 8 Intellect.

### What each stat does (starting values, tuned in phase 5)

| Stat | Effect |
| --- | --- |
| Primary attribute | +1 auto-attack damage per point (Warcraft III), and **spell power**: spells deal x(1 + k x primary), k about 0.02 |
| Strength | +0.05 health regeneration per second per point |
| Agility | +1 attack speed per point (percent) and +0.15 armor per point |
| Intellect | +15 maximum mana and +0.05 mana per second per point (Warcraft III) |
| Stamina | +25 maximum health per point. A hero's base Stamina and gain per level are its Warcraft III Strength numbers, so level 1 health equals Warcraft III's (Archmage 450, Pit Lord 750) |
| Armor | Damage taken x 1 / (1 + 0.06 x armor), the Warcraft III formula |

- Every level-up grants the hero's per-level attributes automatically, as in Warcraft III, on top of the card.
- Summons (Water Elemental, Feral Spirit, treants...) scale with the hero's spell power.
- Stat cards (blessings) change: Might, Vigor and Fortitude become **+Strength, +Agility, +Intellect,
  +Stamina, +Armor** cards. Secondary cards stay (critical strike, haste, area, duration, projectiles,
  life steal, pickup, experience, gold, luck) with diminishing returns instead of flat stacking.
- The character panel shows the five stats on top (primary highlighted), derived values below.
- Faction traits move onto the new stats (Alliance +Armor, Horde attack speed, ...).

## 2. Mana (phase 2)

- Every active spell costs mana. Auras and passives are free.
- **Cost** = the ability's Warcraft III cost x about 0.25 x (1 + 0.06 per rank above 1). Spells with no
  Warcraft III original (Medivh's) get costs by analogy.
- Spells still cast themselves, but **wait for mana**: a spell without enough mana stays ready and goes
  off as soon as the mana is there. Its HUD icon dims while it waits.
- Mana pool and regeneration come from Intellect, plus a small base regeneration.
- The HUD mana bar (already there) is driven by the script, so it shows the same in both engines.
- New sources: **mana runes** (a pickup, like healing runes), Brilliance Aura, Sobi Mask and similar items,
  and a mana regeneration talent. Siphon Mana and Mana Burn return mana.

Sample Warcraft III costs (`AbilityData.slk`): Blizzard 75, Water Elemental 125, Mass Teleport 100,
Storm Bolt 75, Thunder Clap 90, Chain Lightning 120, Shockwave 100, Death Coil 75, Carrion Swarm 100,
Frost Nova 125, Impale 100, Entangling Roots 75, Forked Lightning 110, Breath of Fire 70, Soul Burn 85,
Rain of Fire 85, Immolation 25.

## 3. Unlocks and progression (phase 3)

### Talents

- At the start only the five base talents exist: **Strength, Agility, Intellect, Stamina, Armor**
  (gold, five ranks each).
- Every other talent appears locked with its achievement shown, and unlocks when it is earned:

| Talent | Unlocked by |
| --- | --- |
| Swiftness (movement) | Survivor: win a run |
| Precision (critical strike) | Slayer: 1,000 kills |
| Haste (spell recharge) | Ascendant: reach level 25 in a run (was 30) |
| Clarity (mana regeneration, new) | Veteran: play 25 runs |
| Regeneration | Boss Hunter: 25 bosses |
| Wisdom (experience) | Scholar: 40 codex cards |
| Magnetism (pickup) | Ashenvale: defeat its final boss |
| Greed (gold) | Hoarder: earn 5,000 gold |
| Siphon Life | Heroic: win on Heroic |

### Heroes

- Start with four heroes, one per main faction, covering all three primary attributes:
  **Archmage** (Int), **Blademaster** (Agi), **Death Knight** (Str), **Demon Hunter** (Agi).
- The rest of each faction unlocks in a chain, with new hero achievements (each also gives points):
  1. **Survive 5:00** with the faction's first hero: unlocks the second.
  2. **Defeat a boss** with the second: unlocks the third.
  3. **Win a run** with any hero of the faction: unlocks the fourth.
- The nine Tavern heroes unlock one per zone cleared, in play order (`ZONE_ORDER`):
  Naga Sea Witch, Dark Ranger, Beastmaster, Pandaren Brewmaster, Firelord, Goblin Tinker,
  Goblin Alchemist, Pit Lord, Medivh.
- Locked heroes show in the lobby with their requirement, like locked zones.

### Saves

- Done in phase 1: version `WS2` in a new file, `profile2.pld`; the old `profile.pld` stays as it was.

## 4. Items (phase 4)

Kept: 60 items (one per boss), item level from zone tier and difficulty, the six-step gold upgrade track
(+3 item levels per step), six slots, quality colours.

New:

- Each item has **two or three stats** from its Warcraft III identity: an attribute (Belt of Giant
  Strength: Strength, Robe of the Magi: Intellect), Stamina or Armor, and often one secondary.
  The stat budget grows with item level, as now.
- **Signature items get a unique effect.** Examples:

| Item | Effect |
| --- | --- |
| Orb of Frost | Attacks slow enemies |
| Orb of Fire | Attacks splash fire around the target |
| Orb of Darkness | Kills sometimes raise a dark minion |
| Orb of Corruption | Attacks lower enemy armor |
| Mask of Death | Attacks heal for part of their damage |
| Ankh of Reincarnation | Revive once per run |
| Kelen's Dagger of Escape | Below 30 percent health, blink away (cooldown) |
| Necklace of Spell Immunity | Ignore one boss ability every 20 seconds |
| Cloak of Flames | Burns nearby enemies |
| Crown of Kings | All three attributes |
| Gloves of Spell Mastery | Spells cost less mana |
| Khadgar's Pipe of Insight | Mana regeneration aura (summons too) |
| Warsong Battle Drums | Damage aura (summons too) |
| Helm of Battlethirst | Kills grant attack speed for a few seconds |
| Grimoire of Souls | Kills grant Intellect for the rest of the run |

- Effects hook into existing points in the script: attack hit, kill, damage taken, low health, cast.
- Items stay the same entries (`z<zone>b<boss>`), so loot and the upgrade track work unchanged.

## 5. Difficulty and pacing (phase 5, then ongoing)

Targets for a fresh profile on Normal: lose the first Ashenvale runs around minutes 5 to 8; win once a
few talent ranks and items are in. About **30 level-ups** per 10-minute run instead of 70.

- **Experience:** a steeper `G.xpFor` (about 30 levels per run).
- **Spell ranks:** keep "no rank limit", with diminishing returns: +25 percent damage per rank up to
  rank 5, then +10 percent. Cooldown reduction from ranks stops at 50 percent.
- **Enemies:** health x(1 + 2.5 x progress^1.4) and damage x(1 + 1.5 x progress) over a run, Ashenvale
  power from 0.7 to 1.0, elites more often, bosses tougher. Heroic and Mythic keep their multipliers on top.
- **Balance report:** the smoke test already plays every hero automatically. It gets a report per hero and
  minute: level, damage per second, enemy health spawned per second, damage taken, mana spent and
  available, and the minute the hero would die without the test's healing. Every tuning change is
  checked against the targets above, then confirmed in a few real engine runs.

## Order of work

Each phase is playable, tested (smoke test, engine runs) and committed on its own.

1. **Attributes and stats.** Includes the save reset, the stat cards and the character panel.
2. **Mana.**
3. **Unlocks.** Talents, heroes, and the new achievements.
4. **Items.**
5. **Difficulty tuning** with the balance report, then more rounds after play testing.

Phase 1 comes first because everything else uses the new stats. Phases 2 to 4 can then go in any order.

## Notes

- The smoke test checks today's numbers (level reached, armory upgrade, all heroes played). Each phase
  updates it.
- Card, talent and item texts, the codex and the achievements list all change with these phases.
- This reworks large parts of the script, so later updates from the original author (`git merge upstream/main`)
  will conflict more often. Merging stays possible; conflicts are resolved by hand.
