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
  `SPELL_POWER_PER_POINT`; `STACK_FALLOFF` until the phase 5 play test).
- Spell power is `(1 + 0.01 x primary) / (1 + 0.01 x level 1 primary)`: exactly 1 at level 1, so each
  hero starts as strong as before. It scales spell damage, heals and summon health.
- Stat cards: Strength, Agility, Intellect (+5, rounded up by rarity), Stamina (+3), Armor (+2). Every
  other card gave 85 percent of the previous pick of it until the phase 5 play test (now every pick gives the
  same). Might, Vigor and Fortitude are gone; talents
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

## 2. Mana (phase 2, done 2026-11-01)

As built (decision: Warcraft III costs, rate-matched, with spells that can be turned off):

- `MANA_DATA` holds each ability's Warcraft III cost and cooldown (`AbilityData.slk`). A spell costs that
  ability's mana per second, kept within 2.5 to 16, times its cooldown here, times 0.12
  (`CFG.MANA_COST_SCALE`), +6 percent per rank. Abilities without a cooldown (arrows, Banish) count their
  cost once per cast. `MANA_BY_SPELL` covers spells with no ability of their own (Medivh's, Crushing
  Wave). Auras, orbits and passives never cast and are free.
- Pool 15 per Intellect, regeneration 1 + 0.05 per Intellect per second (`CFG.MANA_*`). Every hero can
  keep its starting spell going at level 1 (Lich: Frost Nova 1.80 per second against 2.00).
- A spell short of mana stays ready and waits (its slot turns blue).
- Keys (changed the same day, at the user's request): spells cast on 1 to 4 or a click on their slot;
  Shift+1 to 4 turns a spell's autocast on or off (off when learned, so mana goes where the player
  sends it; on for touch screens, which have no keys); Ctrl+1 to 4 picks a card. Auras, orbits and
  passives are always on and have no key. A cast from its key skips autocast's conditions (a heal heals
  at once, a buff starts with no pack close by).
- Mana sources: violet mana runes (30 percent of the pool), Brilliance Aura (+0.8 mana per second per
  rank instead of spell haste, as in Warcraft III), Siphon Life (4 mana per enemy), Mana Burn (5 per hit),
  Sobi Mask and Khadgar's Pipe of Insight (mana regeneration instead of spell haste).
- HUD: the mana bar shows the script's pool; spell cards and tooltips show the cost; the stats panel
  adds Mana and Mana regeneration, and Spell power moves to the Sorceress Master icon.
- The smoke test checks waiting, paying, turning off, and that every casting spell has a cost.

Planned:

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

## 3. Unlocks and progression (phase 3, done 2026-11-01)

As built, following the tables below:

- `TALENTS`: Strength, Agility, Intellect (+2 per rank), Stamina (+2), Armor (+1) open from the start;
  the others carry `unlock` (an achievement key) and show "Opens with ..." and a Locked button until it is
  earned. Clarity is new (+0.3 mana per second per rank). Might and Vitality are gone: a save that bought
  them gets the gold back on load. Haste moved to the Bloodlust icon (the Sobi Mask is Clarity's now).
- Heroes carry `unlock` too, set after the achievements: new "<Hero> Joins" achievements (a boss slain with
  the faction's first hero, 5:00 survived with its second; 10 and 15 points; swapped the same day, since the
  bosses come at 2:00 and 4:00, surviving 5:00 is the harder step), the faction's "For the ...!" win for
  the fourth, the zone achievements in `ZONE_ORDER` for the Tavern. The profile keeps `heroTime` (longest run
  per hero) and `heroBosses`. Locked heroes are dim in the grid; selecting one shows LOCKED HERO and its
  requirement, and neither the button nor Space starts a run. Random Hero picks among open heroes.
- Ascendant asks for level 25 (was 30).
- The smoke test checks the starting four heroes and five talents, that a locked hero cannot enter a zone,
  and what the first win opens.

Planned:

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
  1. **Defeat a boss** with the faction's first hero: unlocks the second.
  2. **Survive 5:00** with the second: unlocks the third.
  3. **Win a run** with any hero of the faction: unlocks the fourth.
- The nine Tavern heroes unlock one per zone cleared, in play order (`ZONE_ORDER`):
  Naga Sea Witch, Dark Ranger, Beastmaster, Pandaren Brewmaster, Firelord, Goblin Tinker,
  Goblin Alchemist, Pit Lord, Medivh.
- Locked heroes show in the lobby with their requirement, like locked zones.

### Saves

- Done in phase 1: version `WS2` in a new file, `profile2.pld`; the old `profile.pld` stays as it was.

## 4. Items (phase 4, done 2026-11-01)

As built:

- Every item has two or three stats (Crown of Kings: all attributes) with a weight each, after its
  Warcraft III self: `ZONE_ITEMS` entries are `{code, name, {stat = weight}, effect}`. A stat's value is
  `per x weight x gearScale(ilvl)` (`gearValue`); Strength, Agility, Intellect (3 per weight), all attributes
  (2) and Stamina (2) come in whole points. New item stats: the attributes, all attributes, Stamina, dodge.
  The old health stat is gone (Stamina gives health). Ids, item levels, the upgrade track and loot work as before.
- 20 items carry an effect (`ITEM_EFFECTS`, shown as a green "Equip:" line). It scales with item level like a
  stat, up to a cap (`max`); Reincarnation, Escape and Spell Immunity do not scale. Effects show by name on the
  damage meter. Two items can share one (Orb of Fire and Orb of Kil'jaeden; Mask of Death and Killmaim): the
  values add.

| Effect | Items | At base item level | Hook |
| --- | --- | --- | --- |
| Frost Orb | Orb of Frost | attacks slow 35 percent, 2 s | `G.attackHit` (`attackSlow`) |
| Fire Orb | Orb of Fire, Orb of Kil'jaeden | 40 percent of the hit around the target | `G.attackHit` |
| Dark Minion | Orb of Darkness | 6 percent of kills raise a skeleton (20 s) | `G.onDeath`, `G.raiseMinion` |
| Corruption | Orb of Corruption | target takes 13.5 percent more from everything, 3 s | `G.attackHit`, `G.damage` |
| Vampiric Attack | Mask of Death, Killmaim | attacks heal 12 / 14 percent of their damage | `G.attackHit` |
| Reincarnation | Ankh of Reincarnation | one revive per run | `s.lives` |
| Escape | Kelen's Dagger of Escape | the hit that would drop you under 30 percent misses, blink away (30 s) | `G.onDamage`, `G.escape` |
| Sanctuary | Staff of Sanctuary | under 30 percent health, heal 34 percent (60 s) | `G.onDamage` |
| Immolation | Cloak of Flames | 37.5 percent of attack damage per second around you | `G.updateHero` |
| War Drums | Warsong Battle Drums | summons deal 26 percent more | `G.onDamage` |
| Spell Mastery | Gloves of Spell Mastery | spells cost 16 percent less mana (cap 50) | `G.spellValues` |
| Battle Thirst | Helm of Battlethirst | kills give 24 percent attack speed for 3 s | `G.onDeath`, `G.updateAttack` |
| Soul Harvest | Grimoire of Souls | 1 Intellect per 25 kills for the run, up to 9 | `G.onDeath`, `G.recomputeStats` |
| Spell Immunity | Necklace of Spell Immunity | ignores a hit of a tenth of your health or more (15 s) | `G.onDamage` |
| Frost Armor | Frostguard | attackers slowed 34 percent, 3 s | `G.onDamage` |
| Searing | Searing Blade | attacks burn for 40 percent of the hit over 3 s | `G.attackHit` (`G.dot`) |
| Spiked Shield | Skull Shield | attackers take 27 damage | `s.thorns` |
| Purge | Shaman Claws | 6 percent of attacks stun 1 s | `s.bash` |

- Armory: the details show the stats on one line, the effect, and "Next:" with only what the next upgrade
  raises (whole attributes and capped effects can stay put for a step). Beside the six slots, the carried items'
  totals, one stat a line, then the effects by name (a count when they would not fit). The in-run tooltip and the
  loot toast show the stats too.
- Test aid: `+set survivor_gear "ofro desc clfm"` (engine) loots every item at its base level and carries the
  ones named.
- The smoke test checks every item's text and ten of the effects in a run.

Planned:

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

## 5. Difficulty and pacing (phase 5, first round done 2026-11-01)

As built (numbers in `CFG`, under "Difficulty"):

- Experience: `G.xpFor(level) = 5 + 9k + 1.4k^2` (k = level - 1), `XP_CURVE`.
- Spell ranks (changed after play test 1, below): +25 percent damage and healing per rank up to rank 5, +10 percent after (`RANK_BONUS`,
  `RANK_STEEP`, `RANK_BONUS_LATE`); cooldowns shrink 5 percent a rank down to half (`RANK_CD_FLOOR`). A rank-up
  card adds 40 percent of its rarity bonus to the spell's power (`RANK_RARITY`); a new spell still gets all of it.
  Power had reached x3 from rank-ups alone.
- Enemies: health x(1 + 3.0 x progress^1.4), damage x(1 + 2.0 x progress) over a run (`ENEMY_HP_GROWTH`,
  `ENEMY_HP_CURVE`, `ENEMY_DMG_GROWTH`); bosses x1.5 health (`BOSS_HP`); an elite every 30 s (was 45) with three
  times the health (`ELITE_HP`), and only 35 percent of elites drop a chest, the others 8 to 15 gold
  (`ELITE_CHEST`): a run had dealt about 60 card hands. Ashenvale power 1.0 (was 0.7). Other zones keep their power
  for now; the growth curve applies everywhere.
- Mana: costs x1.5 (`MANA_COST_SCALE` 0.18) and +12 percent a rank (was 6): late in a run the Archmage's pool
  now runs down (Blizzard at rank 14 costs 40 every 3.6 s).
- Balance report: `python tools/smoketest/run.py --balance [zone] [difficulty] [hero ids] [geared]` plays each
  hero three times on a fresh profile (or `geared`: every talent at its last rank and six late items) and prints
  a minute-by-minute table for the first run, then a summary (first death, final level). The mock has no unit
  AI, so the report plays the enemies (they walk at their speed, melee hits every 1.5 s after armor) and the
  hero (kites from packs, sweeps gems when few enemies are near, ranks its top damage spell). A hit that would
  kill counts a death and the run goes on. Summons and ranged enemies do not fight in it: heroes that lean on
  them (Death Knight, Archmage's Water Elemental) read weaker than they are.

Before and after, Ashenvale Normal, fresh profile (Archmage, Blademaster, Death Knight, Demon Hunter):

| | Level at 10:00 | First death (would-be) |
| --- | --- | --- |
| Before | 63 to 73 | never |
| After | 19 to 37, about 30 | 3:05 to never, mostly 4 to 7 minutes |
| After, geared (Ashenvale) | 30 to 42 | never |
| After, geared, Northrend Normal | 28 to 43 | never for three heroes, 6:40 or later for the Death Knight |
| After, geared, Northrend Mythic | 20 to 39 | 1:17 to 9:19 |

### Play test 1 (2026-11-01, Blademaster, Ashenvale Normal)

Won with no danger: every spell on autocast and never out of mana, the Mirror Images had the hero's health and
held the enemies' attention, Bladestorm did all the damage, one Vampirism card kept the hero at full health
against the bosses, damage numbers came and went. The player found diminishing returns on cards bad and asked
for linear gains instead. Changed:

- Mirror Image: cooldown 24 s (was 6), images have a quarter of the hero's health (`IMAGE_HEALTH`) and fade
  after 6 s (`IMAGE_DURATION`): a way out now and then, not a wall.
- Life steal heals at most 3 percent of maximum health a second (`LIFESTEAL_CAP`, `G.leech`); the card says so.
  An area spell on a pack had healed without end.
- Enemies and bosses hit 1.7 times their listed damage (`ENEMY_DMG`).
- Mana: a mana rune drops from 1 kill in 250 (was 1 in 80) and restores 20 percent (was 30): late in a run they
  had refilled about 300 mana every 10 s. `MANA_RATE_MIN` 6 (was 2.5): Bladestorm, whose Warcraft III cooldown is
  180 s, had cost 3 mana a cast; now 7 at rank 1.
- Linear gains: every pick of a stat card gives the same (`STACK_FALLOFF` is gone), every spell rank +20 percent
  (`RANK_BONUS`), cooldowns 3 percent of the base shorter per rank down to half (`RANK_CD`, `RANK_CD_FLOOR`). To
  fit, Ferocity gives 10 percent attack speed (was 12), Haste 5 percent (was 6), Reach 8 percent area (was 12).
- Damage numbers: each source shows up to 4 numbers a quarter second (crits 2 more, `NUMBERS_PER_SOURCE`): an area
  spell on a pack had used up the game's text tags.

Balance report after it: with every spell on autocast the Blademaster's mana sits near 10 percent from minute 3;
first would-be deaths 2:30 to 6:40. The report hit harder than the game last round (it said 5 to 9 minutes
when the play test never felt threatened), so the enemies stay this strong until the next play test.

### Play test 1, second round (2026-11-01)

- Spells sit in fixed slots: a spell's slot and key are its place in the hero's Warcraft III order (`def.pool`,
  `R.slots`), whatever order it is learned in. `R.spells` stays the list in learning order.
- Cards show their key (Ctrl+1 by default, from the binding).
- End screen: achievements get a line each while they fit above the DAMAGE rule (three lines under the loot,
  five without loot), else one line naming the first three.
- Stat cards: the hero's primary attribute is drawn most (weight 4), the other attributes next (2.2), the rest
  1.4 (`BLESSING_WEIGHT`). Only the five attributes, Ferocity, Swiftness and Regeneration are offered from the
  start; the others open with an achievement (`BLESSING_UNLOCKS`): Haste (Slayer), Reach (Survivor), Precision
  (Ascendant), Vampirism (Boss Hunter), Brutality (Exterminator), Magnetism (Veteran), Wisdom (Scholar), Greed
  (Hoarder), Fortune (Collector), Persistence (Westfall), Multishot (Heroic). The codex says what opens a locked
  one. Quests (phase 6) will open some of them too.

Next: more play tests, then more rounds (zone powers past Ashenvale, hero outliers such as Blizzard and
Bladestorm, Heroic and Mythic multipliers).

Planned:

Targets for a fresh profile on Normal: lose the first Ashenvale runs around minutes 5 to 8; win once a
few talent ranks and items are in. About **30 level-ups** per 10-minute run instead of 70.

- **Experience:** a steeper `G.xpFor` (about 30 levels per run).
- **Spell ranks:** (superseded by play test 1: linear) keep "no rank limit", with diminishing returns: +25 percent damage per rank up to
  rank 5, then +10 percent. Cooldown reduction from ranks stops at 50 percent.
- **Enemies:** health x(1 + 2.5 x progress^1.4) and damage x(1 + 1.5 x progress) over a run, Ashenvale
  power from 0.7 to 1.0, elites more often, bosses tougher. Heroic and Mythic keep their multipliers on top.
- **Balance report:** the smoke test already plays every hero automatically. It gets a report per hero and
  minute: level, damage per second, enemy health spawned per second, damage taken, mana spent and
  available, and the minute the hero would die without the test's healing. Every tuning change is
  checked against the targets above, then confirmed in a few real engine runs.

## 6. Scripted events and quests (phase 6, added 2026-11-01)

Goal: runs get Warcraft III-style quests and scripted events between the waves. Finishing them earns
achievements, and those unlock content, as in phase 3.

What exists: the engine already implements Warcraft III's quest natives (`CreateQuest`, `QuestSetTitle`,
`QuestSetDescription`, `QuestSetCompleted` / `Failed`, `QuestCreateItem`, `QuestItemSetCompleted`,
`FlashQuestDialogButton`), timer dialogs, multiboards, leaderboards, regions with enter events, minimap pings and
timed text. The script can use them as a Reforged map would, so the same code works in both.

Proposal:

- **Quest tracker:** a small HUD panel (like WoW's objective tracker) with each active quest and its
  progress, plus the quests in the Warcraft III quest log. The engine's stock quest key stays off
  (`cl_fkeys`); a rebindable action opens the log.
- **Events** (a few per run, announced with a timer dialog, a minimap ping and a line of text):
  - *Rescue:* captives in a cage; stand by them for some seconds while the horde pushes in.
  - *Defend:* a shrine, caravan or moonwell with its own health bar, for a minute.
  - *Hunt:* a rare creep that runs; kill it before the timer ends.
  - *Ritual:* destroy three totems, crystals or corrupted moonwells around the arena in time.
- **Zone quests:** two or three named quests per zone from its lore (Ashenvale's Sentinels, Westfall's
  Defias, the Scourge's necropolises), counted across a run: slay so many of a unit, free the captives,
  defeat a boss before a time.
- **Rewards:** in the run, gold, a card hand, healing or a better boss drop. Between runs, achievements
  (per zone's quests, quest totals, flawless events) that unlock content.
- **Decisions for later:** what quest achievements unlock (heroes, talents, zones, cosmetic hero skins),
  how many events per run, and whether the tracker or the Warcraft III quest log is the main view.

Comes after phase 5, because events change the pacing that phase 5 tunes.

## Order of work

Each phase is playable, tested (smoke test, engine runs) and committed on its own.

1. **Attributes and stats.** Includes the save reset, the stat cards and the character panel.
2. **Mana.**
3. **Unlocks.** Talents, heroes, and the new achievements.
4. **Items.**
5. **Difficulty tuning** with the balance report, then more rounds after play testing.
6. **Events and quests.**

Phase 1 comes first because everything else uses the new stats. Phases 2 to 4 can then go in any order.

## Notes

- The smoke test checks today's numbers (level reached, armory upgrade, all heroes played). Each phase
  updates it.
- Card, talent and item texts, the codex and the achievements list all change with these phases.
- This reworks large parts of the script, so later updates from the original author (`git merge upstream/main`)
  will conflict more often. Merging stays possible; conflicts are resolved by hand.
