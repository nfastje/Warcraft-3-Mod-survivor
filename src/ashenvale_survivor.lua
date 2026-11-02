-- Warcraft Survivors
-- A survivors-style run for Warcraft III Reforged, written in Lua.
--
-- Editor setup:
--   1. Scenario > Map Options: set the script language to Lua.
--   2. Paste this whole file into the map-level Custom Script Code area.
--   3. Keep one Map Initialization trigger whose only action is the custom
--      script line: Survivor_Start()
--   4. Disable the default Melee Initialization trigger.
--
-- Everything (lobby, HUD, level-up cards, saves) is built at runtime from
-- Warcraft III's own textures, icons and models, so no imports are needed.
-- Progress is saved to Documents\Warcraft III\CustomMapData\WarcraftSurvivors.
--
-- Never type a percent sign in this file: the World Editor runs custom script
-- through printf and crashes on it. Inside strings write the escape \037
-- instead, and use math.fmod(a, b) for the modulo operator.

do
    ---------------------------------------------------------------------------
    -- Configuration
    ---------------------------------------------------------------------------
    local CFG = {
        TICK = 0.03125,
        RUN_LENGTH = 600.0,          -- the final boss arrives at 10:00
        -- Endless mode (after the final boss): enemy health and damage compound
        -- every minute, a boss comes back on a timer, elites come more often.
        ENDLESS_HP = 1.15,           -- enemy health x1.15 per endless minute
        ENDLESS_DMG = 1.08,          -- enemy damage x1.08 per endless minute
        ENDLESS_BOSS_EVERY = 90.0,
        ENDLESS_ELITE_EVERY = 25.0,
        MAX_ENEMIES = 150,
        MAX_PICKUPS = 220,
        SPELL_SLOTS = 4,             -- spells and blessings have no rank limit
        -- Spells cast on their key (1 to 4) or a click; Shift with the key turns
        -- their autocast on or off. New spells start with it off (on a touch
        -- screen, which has no keys, on). Auras, orbits and passives always work.
        AUTOCAST = false,
        MAX_SUMMONS = 120,           -- pets alive at once (Persistence stacks them up)
        MAX_WORLD_OBJECTS = 6,       -- chests, shrines and treasure lying in the arena at once
        WORLD_OBJECT_REACH = 150.0,  -- walking this close to one uses it
        HIT_FEEDBACK = 0.2,          -- seconds between two blood splashes on the hero
        HAND_SIZE = 3,
        -- Warcraft III attributes (see G.recomputeStats). Health follows the
        -- game's own rule, with Stamina in Strength's place. Spell power is 1
        -- at the hero's level 1 primary attribute.
        HP_BASE = 100,
        HP_PER_STAMINA = 25,
        REGEN_PER_STRENGTH = 0.05,   -- health per second
        ATTACK_SPEED_PER_AGILITY = 0.01,
        ARMOR_PER_AGILITY = 0.15,
        SPELL_POWER_PER_POINT = 0.01,
        -- Mana (see MANA_DATA). Pool and regeneration grow with Intellect as in
        -- Warcraft III, on top of a base regeneration.
        MANA_PER_INTELLECT = 15,
        MANA_REGEN_BASE = 1.0,       -- mana per second
        MANA_REGEN_PER_INTELLECT = 0.05,
        MANA_COST_SCALE = 0.18,      -- share of the Warcraft III mana spent per second of cooldown
        MANA_COST_PER_RANK = 0.12,   -- each rank above 1 costs 12 percent more
        MANA_RATE_MIN = 6.0,         -- Warcraft III mana per second, kept within these bounds (ultimates with long
                                     -- Warcraft III cooldowns would cost almost nothing at their rate)
        MANA_RATE_MAX = 16.0,
        MANA_RUNE = 0.2,             -- a mana rune restores 20 percent of the pool (1 kill in 250 drops one)
        BASE_PICKUP = 170.0,
        BASE_REROLLS = 2,
        BASE_BANISHES = 1,
        XP_RATE = 2,                 -- experience per gem point, as in the original
        -- Difficulty (balance pass, phase 5; tools/smoketest/balance.lua reports
        -- a run minute by minute). Over a run enemy health grows
        -- x(1 + ENEMY_HP_GROWTH x progress^ENEMY_HP_CURVE), damage x(1 + ENEMY_DMG_GROWTH x progress).
        ENEMY_HP_GROWTH = 3.0,
        ENEMY_HP_CURVE = 1.4,
        ENEMY_DMG_GROWTH = 2.0,
        ENEMY_DMG = 1.7,             -- every enemy and boss hits this much harder than its listed damage
        LIFESTEAL_CAP = 0.03,        -- life steal heals at most 3 percent of maximum health a second (G.leech)
        BOSS_HP = 1.5,               -- on top of each boss's own health
        ELITE_HP = 3.0,              -- an elite has three times its kind's health
        ELITE_EVERY = 30.0,          -- seconds between elites
        ELITE_CHEST = 0.35,          -- chance an elite drops a chest (else gold)
        RANK_RARITY = 0.4,           -- share of a card's rarity bonus a rank-up adds to the spell's power
        RANK_BONUS = 0.20,           -- spell damage and healing per rank, the same for every rank
        RANK_CD = 0.03,              -- each rank shortens the cooldown by 3 percent of the base...
        RANK_CD_FLOOR = 0.5,         -- ...down to half
        XP_CURVE = 1.4,              -- see G.xpFor
        CAMERA_DISTANCE = 1850.0,
        DAMAGE_NUMBERS = true,
        NUMBERS_PER_SOURCE = 4,      -- damage numbers each source shows per quarter second (crits 2 more)
        DECOY_REACH = 700.0,         -- enemies this close to a Mirror Image attack it instead of the hero
        IMAGE_DAMAGE_TAKEN = 3.0,    -- Mirror Images take triple damage (300 percent)
        IMAGE_HEALTH = 0.25,         -- of the hero's maximum health
        IMAGE_DURATION = 6.0,        -- seconds before an image fades
        SHOW_MINIMAP = false,
        SHOW_PORTRAIT = true,
        ENEMY_PLAYER = 11,
        -- Version 2 (attributes, 2026-11-01) started every profile over in a
        -- new file: profile.pld, the version 1 save, is left as it was.
        SAVE_FILE = 'WarcraftSurvivors\\profile2.pld',
        SAVE_VERSION = 'WS2',
        FONT = 'Fonts\\FRIZQT__.TTF',
    }

    local TEX = {
        white = 'UI\\Glues\\MainMenu\\MainMenu3D\\white32.blp',
        marble = 'UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp',
        plate = 'UI\\Widgets\\Glues\\loading-namebackground.blp',
        barFill = 'UI\\Feedback\\HPBarConsole\\human-healthbar-fill.blp',
        barFrame = 'UI\\Feedback\\XPBar\\human-xpbar-border.blp',
        iconFrame = 'UI\\Buttons\\HeroLevel\\herolevel-border.blp',
        banner = 'UI\\Glues\\ScoreScreen\\scorescreen-goldbannerborder.blp',
        glow = 'UI\\Glues\\ScoreScreen\\scorescreen-tab-hilight.blp',
        -- Hover and selection light of the escape menu buttons.
        highlight = 'UI\\Widgets\\EscMenu\\Human\\human-options-button-highlight.blp',
        -- Fully transparent: a bordered backdrop with this background is an outline.
        clear = 'UI\\Widgets\\EscMenu\\Human\\blank-background.blp',
        -- Lobby title art (engine only, from src/art like the zone thumbnails).
        title = 'Scripts\\Survivor\\title.tga',
        -- Race crests: the capture-the-flag banners (classic command buttons, also in Reforged).
        emblem = {
            Alliance = 'ReplaceableTextures\\CommandButtons\\BTNHumanCaptureFlag.blp',
            Horde = 'ReplaceableTextures\\CommandButtons\\BTNOrcCaptureFlag.blp',
            Undead = 'ReplaceableTextures\\CommandButtons\\BTNUndeadCaptureFlag.blp',
            ['Night Elf'] = 'ReplaceableTextures\\CommandButtons\\BTNNightElfCaptureFlag.blp',
            Tavern = 'ReplaceableTextures\\CommandButtons\\BTNTavern.blp'
        }
    }

    -- Stock BACKDROP templates (EscMenuTemplates.fdf, QuestDialog.fdf): the
    -- classic Warcraft III menu borders, drawn with their own corner pieces.
    local TPL = {
        panel = 'EscMenuBackdrop',                        -- ornate gold escape-menu frame
        box = 'QuestButtonBaseTemplate',                  -- dark wood plate, thin gold edge
        iron = 'DialogBackdrop',                          -- riveted iron dialog frame (DialogWar3.fdf)
        well = 'EscMenuControlBackdropTemplate',          -- sunken edit-box well
        button = 'EscMenuButtonBackdropTemplate',
        buttonOff = 'EscMenuButtonDisabledBackdropTemplate'
    }

    local FX = {
        blizzard = 'Abilities\\Spells\\Human\\Blizzard\\BlizzardTarget.mdl',
        thunderClap = 'Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl',
        stormBolt = 'Abilities\\Spells\\Human\\StormBolt\\StormBoltMissile.mdl',
        holyLight = 'Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl',
        flameStrike = 'Abilities\\Spells\\Human\\FlameStrike\\FlameStrikeTarget.mdl',
        divineShield = 'Abilities\\Spells\\Human\\DivineShield\\DivineShieldTarget.mdl',
        avatar = 'Abilities\\Spells\\Human\\Avatar\\AvatarCaster.mdl',
        manaShield = 'Abilities\\Spells\\Human\\ManaShield\\ManaShieldCaster.mdl',
        resurrect = 'Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl',
        teleport = 'Abilities\\Spells\\Human\\MassTeleport\\MassTeleportCaster.mdl',
        warStomp = 'Abilities\\Spells\\Orc\\WarStomp\\WarStompCaster.mdl',
        shockwave = 'Abilities\\Spells\\Orc\\Shockwave\\ShockwaveMissile.mdl',
        earthquake = 'Abilities\\Spells\\Orc\\EarthQuake\\EarthQuakeTarget.mdl',
        lightningShield = 'Abilities\\Spells\\Orc\\LightningShield\\LightningShieldTarget.mdl',
        healingWave = 'Abilities\\Spells\\Orc\\HealingWave\\HealingWaveTarget.mdl',
        bloodlust = 'Abilities\\Spells\\Orc\\Bloodlust\\BloodlustTarget.mdl',
        feralSpirit = 'Abilities\\Spells\\Orc\\FeralSpirit\\feralspirittarget.mdl',
        voodoo = 'Abilities\\Spells\\Orc\\Voodoo\\VoodooAuraTarget.mdl',
        mirrorImage = 'Abilities\\Spells\\Orc\\MirrorImage\\MirrorImageCaster.mdl',
        deathCoil = 'Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilMissile.mdl',
        deathCoilHit = 'Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl',
        animateDead = 'Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl',
        carrionSwarm = 'Abilities\\Spells\\Undead\\CarrionSwarm\\CarrionSwarmMissile.mdl',
        vampiric = 'Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl',
        infernal = 'Units\\Demon\\Infernal\\InfernalBirth.mdl',
        frostNova = 'Abilities\\Spells\\Undead\\FrostNova\\FrostNovaTarget.mdl',
        frostArmor = 'Abilities\\Spells\\Undead\\FrostArmor\\FrostArmorTarget.mdl',
        darkRitual = 'Abilities\\Spells\\Undead\\DarkRitual\\DarkRitualTarget.mdl',
        deathAndDecay = 'Abilities\\Spells\\Undead\\DeathandDecay\\DeathandDecayTarget.mdl',
        impale = 'Abilities\\Spells\\Undead\\Impale\\ImpaleMissTarget.mdl',
        sleep = 'Abilities\\Spells\\Undead\\Sleep\\SleepSpecialArt.mdl',
        manaBurn = 'Abilities\\Spells\\NightElf\\ManaBurn\\ManaBurnTarget.mdl',
        immolation = 'Abilities\\Spells\\NightElf\\Immolation\\ImmolationTarget.mdl',
        immolationHit = 'Abilities\\Spells\\Other\\ImmolationRed\\ImmolationRedDamage.mdl',
        entangle = 'Abilities\\Spells\\NightElf\\EntanglingRoots\\EntanglingRootsTarget.mdl',
        tranquility = 'Abilities\\Spells\\NightElf\\Tranquility\\TranquilityTarget.mdl',
        starfall = 'Abilities\\Spells\\NightElf\\Starfall\\StarfallTarget.mdl',
        fanOfKnives = 'Abilities\\Spells\\NightElf\\FanOfKnives\\FanOfKnivesCaster.mdl',
        blink = 'Abilities\\Spells\\NightElf\\Blink\\BlinkCaster.mdl',
        shadowStrike = 'Abilities\\Spells\\NightElf\\shadowstrike\\ShadowStrikeMissile.mdl',
        moonGlaive = 'Abilities\\Weapons\\MoonPriestessMissile\\MoonPriestessMissile.mdl',
        glaive = 'Abilities\\Weapons\\GlaiveMissile\\GlaiveMissile.mdl',
        searingArrow = 'Abilities\\Weapons\\SearingArrow\\SearingArrowMissile.mdl',
        blackArrow = 'Abilities\\Spells\\Other\\BlackArrow\\BlackArrowMissile.mdl',
        tornado = 'Abilities\\Spells\\Other\\Tornado\\TornadoElementalSmall.mdl',
        crushingWave = 'Abilities\\Spells\\Other\\CrushingWave\\CrushingWaveMissile.mdl',
        silence = 'Abilities\\Spells\\Other\\Silence\\SilenceAreaBirth.mdl',
        stampede = 'Abilities\\Spells\\Other\\Stampede\\StampedeMissileDeath.mdl',
        breathOfFire = 'Abilities\\Spells\\Other\\BreathOfFire\\BreathOfFireMissile.mdl',
        drunkenHaze = 'Abilities\\Spells\\Other\\StrongDrink\\BrewmasterTarget.mdl',
        soulBurn = 'Abilities\\Spells\\Other\\SoulBurn\\SoulBurnbuff.mdl',
        volcano = 'Abilities\\Spells\\Other\\Volcano\\VolcanoMissile.mdl',
        incinerate = 'Abilities\\Spells\\Other\\Incinerate\\FireLordDeathExplode.mdl',
        rocket = 'Abilities\\Weapons\\Mortar\\MortarMissile.mdl',
        acidBomb = 'Abilities\\Spells\\Other\\AcidBomb\\BottleMissile.mdl',
        healSpray = 'Abilities\\Spells\\Other\\HealingSpray\\HealBottleMissile.mdl',
        transmute = 'Abilities\\Spells\\Other\\Transmute\\PileofGold.mdl',
        wisp = 'Units\\NightElf\\Wisp\\Wisp.mdl',
        rainOfFire = 'Abilities\\Spells\\Demon\\RainOfFire\\RainOfFireTarget.mdl',
        howl = 'Abilities\\Spells\\Other\\HowlOfTerror\\HowlCaster.mdl',
        doom = 'Abilities\\Spells\\Other\\Doom\\DoomDeath.mdl',
        cleave = 'Abilities\\Spells\\Other\\Cleave\\CleaveDamageTarget.mdl',
        levelUp = 'Abilities\\Spells\\Other\\Levelup\\LevelupCaster.mdl',
        frostBolt = 'Abilities\\Weapons\\FrostWyrmMissile\\FrostWyrmMissile.mdl',
        lichMissile = 'Abilities\\Weapons\\LichMissile\\LichMissile.mdl',
        fireball = 'Abilities\\Weapons\\FireBallMissile\\FireBallMissile.mdl',
        arcane = 'Abilities\\Weapons\\FaerieDragonMissile\\FaerieDragonMissile.mdl',
        spirit = 'Abilities\\Weapons\\SpiritOfVengeanceMissile\\SpiritOfVengeanceMissile.mdl',
        phoenix = 'Abilities\\Weapons\\PhoenixMissile\\Phoenix_Missile.mdl',
        cryptFiend = 'Abilities\\Weapons\\CryptFiendMissile\\CryptFiendMissile.mdl',
        hex = 'Abilities\\Spells\\Orc\\Purge\\PurgeBuffTarget.mdl',
        bolt = 'Abilities\\Weapons\\Bolt\\BoltImpact.mdl',
        genericHit = 'Abilities\\Weapons\\WaterElementalMissile\\WaterElementalMissile.mdl',
        warning = 'Abilities\\Spells\\Human\\FlameStrike\\FlameStrikeTarget.mdl',
        bossAura = 'Abilities\\Spells\\Other\\GeneralAuraTarget\\GeneralAuraTarget.mdl',
        explosion = 'Objects\\Spawnmodels\\Other\\NeutralBuildingExplosion\\NeutralBuildingExplosion.mdl',
        gemSmall = 'Abilities\\Weapons\\GreenDragonMissile\\GreenDragonMissile.mdl',
        gemMedium = 'Abilities\\Weapons\\FaerieDragonMissile\\FaerieDragonMissile.mdl',
        gemLarge = 'Abilities\\Weapons\\RedDragonBreath\\RedDragonMissile.mdl',
        coin = 'Objects\\InventoryItems\\PotofGold\\PotofGold.mdl',
        rune = 'Objects\\InventoryItems\\runicobject\\runicobject.mdl',
        chest = 'Objects\\InventoryItems\\TreasureChest\\treasurechest.mdl',
        -- A hit on the hero: the campaign's blood splash (Forgotten Hollow).
        heroBlood = 'Objects\\Spawnmodels\\Critters\\Albatross\\CritterBloodAlbatross.mdl',
        -- Golden swirl around a world object (chest, shrine, treasure).
        objectGlow = 'Abilities\\Spells\\Other\\GeneralAuraTarget\\GeneralAuraTarget.mdl',
        -- Medivh
        manaFlare = 'Abilities\\Spells\\Human\\ManaFlare\\ManaFlareMissile.mdl',
        manaFlareHit = 'Abilities\\Spells\\Human\\ManaFlare\\ManaFlareBoltImpact.mdl',
        -- Dark crows: the Destroyer's shadow missile (Medivh's power was Sargeras').
        stormCrow = 'Abilities\\Weapons\\AvengerMissile\\AvengerMissile.mdl',
        darkPortal = 'Abilities\\Spells\\Demon\\DarkPortal\\DarkPortalTarget.mdl'
    }

    -- WoW item-quality colours, used for card rarities and zone tiers.
    local RARITY = {
        {key = 'common', name = 'Common', hex = 'e6e6e6', rgb = {230, 230, 230}, bonus = 0.0, weight = 56},
        {key = 'uncommon', name = 'Uncommon', hex = '1eff00', rgb = {30, 255, 0}, bonus = 0.15, weight = 27},
        {key = 'rare', name = 'Rare', hex = '0070dd', rgb = {40, 130, 255}, bonus = 0.30, weight = 12},
        {key = 'epic', name = 'Epic', hex = 'a335ee', rgb = {163, 53, 238}, bonus = 0.50, weight = 4.2},
        {key = 'legendary', name = 'Legendary', hex = 'ff8000', rgb = {255, 128, 0}, bonus = 0.80, weight = 0.8}
    }

    local GOLD = 'ffd27a'
    local GREY = '9c9488'
    local GREEN = '33ff66'
    local RED = 'ff4d4d'

    -- World of Warcraft difficulties, unlocked zone by zone: clear Normal to
    -- open Heroic, Heroic to open Mythic, Mythic to open Mythic+. Keystones
    -- have no cap: every level compounds health and damage.
    local DIFFICULTIES = {
        {key = 'normal', name = 'Normal', hex = 'e6e6e6', hp = 1.0, dmg = 1.0, reward = 1.0, ilvl = 0,
            blurb = 'The zone as it is.'},
        {key = 'heroic', name = 'Heroic', hex = '0070dd', hp = 1.6, dmg = 1.4, reward = 1.5, ilvl = 10,
            blurb = 'Tougher enemies and better loot.'},
        {key = 'mythic', name = 'Mythic', hex = 'a335ee', hp = 2.6, dmg = 1.9, reward = 2.2, ilvl = 20,
            blurb = 'For heroes in their best gear.'},
        {key = 'mplus', name = 'Mythic+', hex = 'ff8000', hp = 2.6, dmg = 1.9, reward = 2.2, ilvl = 20,
            blurb = 'Keystones with no end: every level is harder. Kill the final boss fast to upgrade the key.'}
    }

    -- Keystone timer: seconds after the final boss arrives, and the upgrade
    -- earned for killing it within them.
    local KEY_CHESTS = {{45, 3}, {80, 2}, {120, 1}}

    local FACTIONS = {
        {key = 'Alliance', hex = '6ab0ff', trait = 'Light of the Alliance',
            lines = {'+10\037 experience', '+2 armor'},
            apply = function(s) s.xp = s.xp + 0.10; s.armor = s.armor + 2 end},
        {key = 'Horde', hex = 'ff5c3d', trait = 'Blood and Thunder',
            lines = {'+8\037 damage', '+8\037 attack speed'},
            apply = function(s) s.damage = s.damage + 0.08; s.attackSpeed = s.attackSpeed + 0.08 end},
        {key = 'Undead', hex = '9fe07a', trait = 'Cannibalize',
            lines = {'Every kill heals 1 health', '+5\037 damage reduction'},
            apply = function(s) s.killHeal = s.killHeal + 1; s.dr = s.dr + 0.05 end},
        {key = 'Night Elf', hex = 'c58cff', trait = 'Shadowmeld',
            lines = {'+6\037 dodge', '+6\037 movement speed'},
            apply = function(s) s.dodge = s.dodge + 0.06; s.move = s.move + 0.06 end},
        {key = 'Tavern', hex = 'ffcc33', trait = 'Sellsword',
            lines = {'+20\037 gold', '+5\037 critical strike'},
            apply = function(s) s.gold = s.gold + 0.20; s.crit = s.crit + 0.05 end}
    }

    -- Every hero: rawcode, fallback icon, a starting spell and its four
    -- Warcraft III abilities, the only spells its level-up cards offer.
    -- Attributes are Warcraft III's (UnitBalance.slk): attr at level 1, gain
    -- per level, the primary one. damage is the weapon's own: the primary
    -- attribute adds to it. armor is the unit's own armor.
    local HEROES = {
        {id = 'Hamg', name = 'Archmage', faction = 'Alliance', icon = 'BTNHeroArchMage', role = 'Frost caster',
            primary = 'int', attr = {str = 14, agi = 17, int = 19}, gain = {str = 1.8, agi = 1, int = 3.2}, damage = 7,
            blurb = 'Freezes whole packs in place and lets the storm do the work.',
            start = 'blizzard', pool = {'blizzard', 'water_elemental', 'brilliance', 'arcane_missiles'}},
        {id = 'Hmkg', name = 'Mountain King', faction = 'Alliance', icon = 'BTNHeroMountainKing', role = 'Bruiser',
            primary = 'str', attr = {str = 24, agi = 11, int = 15}, gain = {str = 3, agi = 1.5, int = 1.5}, damage = 10, armor = 1,
            blurb = 'Hammers and thunder. Stuns anything foolish enough to stand close.',
            start = 'storm_bolt', pool = {'storm_bolt', 'thunder_clap', 'bash', 'avatar'}},
        {id = 'Hpal', name = 'Paladin', faction = 'Alliance', icon = 'BTNHeroPaladin', role = 'Holy guardian',
            primary = 'str', attr = {str = 22, agi = 13, int = 17}, gain = {str = 2.7, agi = 1.5, int = 1.8}, damage = 8, armor = 2,
            blurb = 'Hard to kill and harder to outlast. Heals himself between swings.',
            start = 'holy_light', pool = {'holy_light', 'divine_shield', 'devotion_aura', 'resurrection'}},
        {id = 'Hblm', name = 'Blood Mage', faction = 'Alliance', icon = 'BTNHeroBloodElfPrince', role = 'Fire caster',
            primary = 'int', attr = {str = 18, agi = 14, int = 19}, gain = {str = 2, agi = 1, int = 3}, damage = 8,
            blurb = 'Sets the ground ablaze and keeps a phoenix circling close.',
            start = 'flame_strike', pool = {'flame_strike', 'banish', 'siphon_mana', 'phoenix'}},

        {id = 'Obla', name = 'Blademaster', faction = 'Horde', icon = 'BTNHeroBlademaster', role = 'Duelist', castAnim = 'attack slam',
            primary = 'agi', attr = {str = 18, agi = 24, int = 16}, gain = {str = 2, agi = 1.75, int = 2.25}, damage = 12,
            blurb = 'Spins through the horde. Every swing can turn into a critical strike.',
            start = 'bladestorm', pool = {'wind_walk', 'mirror_image', 'critical_strike', 'bladestorm'}},
        {id = 'Ofar', name = 'Far Seer', faction = 'Horde', icon = 'BTNHeroFarseer', role = 'Storm caller',
            primary = 'int', attr = {str = 15, agi = 18, int = 19}, gain = {str = 2, agi = 1, int = 3}, damage = 8,
            blurb = 'Lightning leaps from foe to foe while spirit wolves hold the line.',
            start = 'chain_lightning', pool = {'chain_lightning', 'far_sight', 'feral_spirit', 'earthquake'}},
        {id = 'Otch', name = 'Tauren Chieftain', faction = 'Horde', icon = 'BTNHeroTaurenChieftain', role = 'Juggernaut',
            primary = 'str', attr = {str = 25, agi = 10, int = 15}, gain = {str = 3.2, agi = 1.5, int = 1.3}, damage = 10, armor = 1,
            blurb = 'Shockwaves split the field. Comes back once when he falls.',
            start = 'shockwave', pool = {'shockwave', 'war_stomp', 'endurance_aura', 'reincarnation'}},
        {id = 'Oshd', name = 'Shadow Hunter', faction = 'Horde', icon = 'BTNShadowHunter', role = 'Witch doctor',
            primary = 'agi', attr = {str = 15, agi = 20, int = 17}, gain = {str = 2, agi = 1.5, int = 2.5}, damage = 6,
            blurb = 'Serpent wards and voodoo spirits fight for him. Hard to pin down.',
            start = 'serpent_ward', pool = {'healing_wave', 'hex', 'serpent_ward', 'big_bad_voodoo'}},

        {id = 'Udea', name = 'Death Knight', faction = 'Undead', icon = 'BTNHeroDeathKnight', role = 'Unholy knight',
            primary = 'str', attr = {str = 23, agi = 12, int = 17}, gain = {str = 2.7, agi = 1.5, int = 1.8}, damage = 10, armor = 1,
            blurb = 'Death Coil from range, an army of the dead up close.',
            start = 'death_coil', pool = {'death_coil', 'death_pact', 'unholy_aura', 'animate_dead'}},
        {id = 'Udre', name = 'Dreadlord', faction = 'Undead', icon = 'BTNHeroDreadLord', role = 'Vampire',
            primary = 'str', attr = {str = 20, agi = 16, int = 18}, gain = {str = 2.5, agi = 1, int = 2.5}, damage = 11,
            blurb = 'Bats tear through lines and every blow feeds him.',
            start = 'carrion_swarm', pool = {'carrion_swarm', 'sleep', 'vampiric_aura', 'inferno'}},
        {id = 'Ulic', name = 'Lich', faction = 'Undead', icon = 'BTNLichVersion2', role = 'Frost necromancer',
            primary = 'int', attr = {str = 15, agi = 14, int = 20}, gain = {str = 2, agi = 1, int = 3.4}, damage = 6,
            blurb = 'Frost Nova and orbiting ice shards. Nothing moves fast near him.',
            start = 'frost_nova', pool = {'frost_nova', 'frost_armor', 'dark_ritual', 'death_and_decay'}},
        {id = 'Ucrl', name = 'Crypt Lord', faction = 'Undead', icon = 'BTNHeroCryptLord', role = 'Swarm tank',
            primary = 'str', attr = {str = 26, agi = 14, int = 14}, gain = {str = 3.2, agi = 1.2, int = 1.6}, damage = 7,
            blurb = 'Impales whole lines and hides under a shell of spikes.',
            start = 'impale', pool = {'impale', 'spiked_carapace', 'carrion_beetles', 'locust_swarm'}},

        {id = 'Edem', name = 'Demon Hunter', faction = 'Night Elf', icon = 'BTNHeroDemonHunter', role = 'Burning blade',
            primary = 'agi', attr = {str = 19, agi = 22, int = 16}, gain = {str = 2.4, agi = 1.5, int = 2.1}, damage = 11,
            blurb = 'Burns everything around him and slips through attacks.',
            start = 'immolation', pool = {'mana_burn', 'immolation', 'evasion', 'metamorphosis'}},
        {id = 'Ekee', name = 'Keeper of the Grove', short = 'Keeper', faction = 'Night Elf', icon = 'BTNKeeperOfTheGrove', role = 'Nature caller',
            primary = 'int', attr = {str = 16, agi = 15, int = 19}, gain = {str = 1.8, agi = 1.5, int = 2.7}, damage = 8,
            blurb = 'Roots the swarm in place while treants wade in.',
            start = 'entangling_roots', pool = {'entangling_roots', 'force_of_nature', 'thorns_aura', 'tranquility'}},
        {id = 'Emoo', name = 'Priestess of the Moon', short = 'Priestess', faction = 'Night Elf', icon = 'BTNPriestessOfTheMoon', role = 'Archer',
            primary = 'agi', attr = {str = 18, agi = 19, int = 15}, gain = {str = 1.9, agi = 1.5, int = 2.6}, damage = 11,
            blurb = 'Volleys of searing arrows under a falling sky.',
            start = 'searing_arrows', pool = {'scout', 'searing_arrows', 'trueshot_aura', 'starfall'}},
        {id = 'Ewar', name = 'Warden', faction = 'Night Elf', icon = 'BTNHeroWarden', role = 'Assassin',
            primary = 'agi', attr = {str = 18, agi = 20, int = 15}, gain = {str = 2.4, agi = 1.6, int = 2}, damage = 12,
            blurb = 'Fans of knives in every direction and spirits of vengeance behind.',
            start = 'fan_of_knives', pool = {'fan_of_knives', 'blink_strike', 'shadow_strike', 'vengeance'}},

        {id = 'Nngs', name = 'Naga Sea Witch', faction = 'Tavern', icon = 'BTNNagaSeaWitch', role = 'Tide caller',
            primary = 'int', attr = {str = 15, agi = 16, int = 22}, gain = {str = 2, agi = 1, int = 3}, damage = 5,
            blurb = 'Forked lightning and crushing tides, behind a mana shield.',
            start = 'forked_lightning', pool = {'forked_lightning', 'frost_arrows', 'mana_shield', 'tornado'}},
        {id = 'Nbrn', name = 'Dark Ranger', faction = 'Tavern', icon = 'BTNBansheeRanger', role = 'Ranger',
            primary = 'agi', attr = {str = 18, agi = 21, int = 15}, gain = {str = 1.9, agi = 1.5, int = 2.6}, damage = 9,
            blurb = 'Black arrows and drained life. Never stops shooting.',
            start = 'black_arrow', pool = {'silence', 'black_arrow', 'life_drain', 'charm'}},
        {id = 'Nbst', name = 'Beastmaster', faction = 'Tavern', icon = 'BTNBeastMaster', role = 'Pack leader',
            primary = 'str', attr = {str = 22, agi = 14, int = 15}, gain = {str = 2.9, agi = 1.3, int = 1.8}, damage = 9,
            blurb = 'Brings a bear, a quilbeast and a stampede to every fight.',
            start = 'summon_bear', pool = {'summon_bear', 'summon_quilbeast', 'summon_hawk', 'stampede'}},
        {id = 'Npbm', name = 'Pandaren Brewmaster', short = 'Brewmaster', faction = 'Tavern', icon = 'BTNPandarenBrewmaster', role = 'Brawler',
            primary = 'str', attr = {str = 22, agi = 14, int = 15}, gain = {str = 3, agi = 1.5, int = 1.5}, damage = 10, armor = 1,
            blurb = 'Breathes fire, staggers out of harm and splits into elements.',
            start = 'breath_of_fire', pool = {'breath_of_fire', 'drunken_haze', 'drunken_brawler', 'storm_earth_fire'}},
        {id = 'Nfir', name = 'Firelord', faction = 'Tavern', icon = 'BTNHeroAvatarOfFlame', role = 'Living flame',
            primary = 'agi', attr = {str = 15, agi = 20, int = 18}, gain = {str = 2, agi = 1.6, int = 2.5}, damage = 9,
            blurb = 'Soul Burn, lava spawn and a volcano under the enemy.',
            start = 'soul_burn', pool = {'soul_burn', 'lava_spawn', 'incinerate', 'volcano'}},
        {id = 'Ntin', name = 'Goblin Tinker', faction = 'Tavern', icon = 'BTNHeroTinker', role = 'Engineer',
            primary = 'int', attr = {str = 20, agi = 15, int = 20}, gain = {str = 2.4, agi = 1, int = 2.6}, damage = 8, armor = 2,
            blurb = 'Rockets, a goblin factory and a robot suit when it gets close.',
            start = 'cluster_rockets', pool = {'pocket_factory', 'cluster_rockets', 'engineering', 'robo_goblin'}},
        {id = 'Nalc', name = 'Goblin Alchemist', faction = 'Tavern', icon = 'BTNHeroAlchemist', role = 'Chemist',
            primary = 'str', attr = {str = 25, agi = 10, int = 18}, gain = {str = 3.3, agi = 1, int = 2}, damage = 5,
            blurb = 'Acid, healing spray and a chemical rage. Turns kills into gold.',
            start = 'acid_bomb', pool = {'healing_spray', 'chemical_rage', 'acid_bomb', 'transmute'}},
        {id = 'Nplh', name = 'Pit Lord', faction = 'Tavern', icon = 'BTNPitLord', role = 'Demon',
            primary = 'str', attr = {str = 26, agi = 14, int = 14}, gain = {str = 3.2, agi = 1.3, int = 1.5}, damage = 8,
            blurb = 'Rains fire on the battlefield and cleaves what survives.',
            start = 'rain_of_fire', pool = {'rain_of_fire', 'howl_of_terror', 'cleave', 'doom'}},
        -- Not a Warcraft III hero: the campaign's Prophet (nmed, a plain unit).
        -- His model has no Attack or Spell of its own, only Spell Attack, and a
        -- raven form (the Alternate sequences, see Raven Form).
        {id = 'nmed', name = 'Medivh', faction = 'Tavern', icon = 'BTNMedivh', role = 'Last Guardian',
            attackAnim = 'spell', castAnim = 'spell',
            primary = 'int', attr = {str = 15, agi = 14, int = 22}, gain = {str = 1.6, agi = 1, int = 3.3}, damage = 6,
            blurb = 'The Last Guardian of Tirisfal: arcane fire, a storm of crows, and the portal that let the Horde in.',
            start = 'arcane_barrage', pool = {'arcane_barrage', 'raven_form', 'enchanted_crows', 'dark_portal'}}
    }

    ---------------------------------------------------------------------------
    -- Spells. Each kind has its own runtime behaviour (see the CAST table):
    --   bolt     homing missiles at the nearest enemies
    --   nova     burst around the hero (or around the nearest enemy)
    --   zone     waves on the densest pack, or around the hero
    --   chain    lightning that jumps, or forks from the hero
    --   line     piercing wave towards the nearest enemy
    --   orbit    missiles circling the hero
    --   aura     damage around the hero every interval
    --   summon   temporary units that fight for the hero
    --   heal     restores health when the hero is hurt
    --   buff     temporary stat boost when enemies are close or health is low
    --   passive  permanent stat boost
    -- Values grow with rank, without limit (only the extra lives stop at 1);
    -- rarity adds power when the card is picked.
    -- Summons last as long as their cooldown, so one wave is out at a time;
    -- spell duration (Persistence) keeps them longer and they pile up.
    ---------------------------------------------------------------------------
    local SPELLS = {}
    local SPELL_ORDER = {}
    local function spell(key, def)
        def.key = key
        SPELLS[key] = def
    end

    -- ' / 3' for a spell with a rank limit, nothing for the others.
    local function rankLimit(max)
        return max and (' / ' .. max) or ''
    end

    local function rankNote(max)
        return max and ('  -  up to rank ' .. max) or '  -  no rank limit'
    end

    -- Alliance
    spell('blizzard', {name = 'Blizzard', code = 'AHbz', icon = 'BTNBlizzard', kind = 'zone', cd = 7.0, dmg = 30,
        radius = 260, range = 950, waves = 6, interval = 0.45, spread = 3, fx = FX.blizzard, slow = 0.35, waveSound = 'BlizzardWave',
        desc = 'Calls {waves} waves of ice on the densest pack. Each wave deals {dmg} damage within {radius} and slows by 35\037.'})
    spell('water_elemental', {name = 'Water Elemental', code = 'AHwe', icon = 'BTNSummonWaterElemental', kind = 'summon',
        cd = 16.0, count = 1, countEvery = 3, units = {'hwat', 'hwat', 'hwt2', 'hwt2', 'hwt3'}, dmg = 30, hp = 520,
        birth = FX.teleport, desc = 'Summons {count} Water Elemental for {dur} sec. It hits for {dmg}.'})
    -- Warcraft III's mana regeneration aura.
    spell('brilliance', {name = 'Brilliance Aura', code = 'AHab', icon = 'BTNBrilliance', kind = 'aura', per = 0.8, flat = true,
        interval = 1.0, dmg = 12, radius = 260, fx = FX.arcane,
        apply = function(s, v) s.manaRegen = s.manaRegen + v.amount end,
        desc = 'Arcane sparks hit enemies within {radius} for {dmg} damage every second. You regain {pct} mana per second.'})
    spell('arcane_missiles', {name = 'Mass Teleport', code = 'AHmt', icon = 'BTNMassTeleport', kind = 'bolt', cd = 2.2,
        dmg = 20, count = 3, countEvery = 2, range = 900, missile = FX.arcane, speed = 1100, scale = 0.8,
        desc = 'Opens a rift that hurls {count} arcane bolts at the nearest enemies for {dmg} damage each.'})
    spell('frost_nova', {name = 'Frost Nova', code = 'AUfn', icon = 'BTNGlacier', kind = 'nova', cd = 5.0, dmg = 48,
        radius = 230, range = 800, atTarget = true, fx = FX.frostNova, slow = 0.5, slowDur = 3.0,
        desc = 'Blasts the nearest enemy and everything within {radius} for {dmg} damage, slowing them by 50\037.'})
    spell('mana_shield', {name = 'Mana Shield', code = 'ANms', icon = 'BTNNeutralManaShield', kind = 'aura', per = 0.04,
        interval = 1.0, dmg = 11, radius = 230, fx = FX.manaBurn, attach = FX.manaShield,
        apply = function(s, v) s.dr = s.dr + v.amount end,
        desc = 'The shield shocks enemies within {radius} for {dmg} damage every second. Takes {pct}\037 less damage.'})
    spell('flame_strike', {name = 'Flame Strike', code = 'AHfs', icon = 'BTNWallOfFire', kind = 'zone', cd = 6.0, dmg = 26,
        radius = 220, range = 900, delay = 0.5, waves = 5, interval = 0.5, spread = 1, fx = FX.flameStrike,
        desc = 'Engulfs the densest pack in flames: {waves} bursts of {dmg} damage within {radius}.'})
    spell('banish', {name = 'Banish', code = 'AHbn', icon = 'BTNBanish', kind = 'bolt', cd = 3.0, dmg = 55, count = 1,
        countEvery = 2, range = 800, instant = true, impact = FX.manaBurn, slow = 0.5, slowDur = 2.5,
        desc = 'Banishes {count} nearby enemy into the ether: {dmg} magic damage and slowed by 50\037.'})
    spell('chain_lightning', {name = 'Chain Lightning', code = 'AOcl', icon = 'BTNChainLightning', kind = 'chain', cd = 3.2,
        dmg = 46, count = 4, countEvery = 1, range = 850, jump = 420, falloff = 0.88, lightning = 'CLPB', lightning2 = 'CLSB',
        impact = FX.bolt, desc = 'Lightning strikes the nearest enemy for {dmg} damage and jumps to {count} more.'})
    spell('far_sight', {name = 'Far Sight', code = 'AOfs', icon = 'BTNFarSight', kind = 'zone', cd = 8.0, dmg = 38,
        radius = 320, range = 1200, waves = 3, interval = 0.45, strikes = true, count = 3, countEvery = 2, fx = FX.bolt,
        desc = 'Sees the largest pack within {radius} and calls {waves} rounds of {count} lightning strikes on it, {dmg} damage each.'})

    spell('storm_bolt', {name = 'Storm Bolt', code = 'AHtb', icon = 'BTNStormBolt', kind = 'bolt', cd = 2.6, dmg = 60,
        count = 1, countEvery = 2, range = 800, missile = FX.stormBolt, speed = 1000, stun = 1.0,
        desc = 'Hurls {count} magic hammer at the nearest enemy for {dmg} damage, stunning for {stun} sec.'})
    spell('thunder_clap', {name = 'Thunder Clap', code = 'AHtc', icon = 'BTNThunderclap', kind = 'nova', anim = 'spell slam', cd = 3.8, dmg = 42,
        radius = 260, fx = FX.thunderClap, slow = 0.5, slowDur = 2.5,
        desc = 'Slams the ground for {dmg} damage to enemies within {radius} and slows them by 50\037.'})
    spell('bash', {name = 'Bash', code = 'AHbh', icon = 'BTNBash', kind = 'passive', per = 0.05,
        apply = function(s, v) s.bash = s.bash + v.amount; s.bashDamage = s.bashDamage + 15 * v.rank end,
        desc = 'Attacks have a {pct}\037 chance to stun for 1 sec and deal extra damage.'})
    spell('avatar', {name = 'Avatar', code = 'AHav', icon = 'BTNAvatar', kind = 'buff', cd = 24.0, dur = 8, per = 0.10, basePct = 0.2,
        trigger = 'enemies', fx = FX.avatar, scale = 1.35, dmg = 60, radius = 300, burstFx = FX.thunderClap,
        apply = function(s, v) s.damage = s.damage + v.bonus; s.armor = s.armor + 5 end,
        desc = 'When surrounded, grows huge with a shockwave of {dmg} damage within {radius}, then has +{pct2}\037 damage and +5 armor for {dur} sec.'})
    spell('cleave', {name = 'Cleaving Attack', code = 'ANca', icon = 'BTNCleavingAttack', kind = 'passive', per = 0.12,
        apply = function(s, v) s.cleave = s.cleave + v.amount end,
        desc = 'Basic attacks splash {pct}\037 of their damage to nearby enemies.'})
    spell('war_stomp', {name = 'War Stomp', code = 'AOws', icon = 'BTNWarStomp', kind = 'nova', cd = 6.0, dmg = 40,
        radius = 280, fx = FX.warStomp, stun = 1.2,
        desc = 'Stomps for {dmg} damage within {radius}, stunning enemies for {stun} sec.'})
    spell('devotion_aura', {flat = true, name = 'Devotion Aura', code = 'AHad', icon = 'BTNDevotion', kind = 'aura', per = 2,
        interval = 1.0, dmg = 11, radius = 240, fx = FX.holyLight, attach = 'Abilities\\Spells\\Human\\DevotionAura\\DevotionAura.mdl',
        apply = function(s, v) s.armor = s.armor + v.amount end,
        desc = 'Holy light burns enemies within {radius} for {dmg} damage every second. Grants {pct} armor.'})
    -- Warcraft III's Critical Strike: its own roll on attacks only, a bigger
    -- hit with every rank. Crit chance (Precision) is the other kind: every
    -- hit, spells too, for critical damage. An attack can land both.
    spell('critical_strike', {name = 'Critical Strike', code = 'AOcr', icon = 'BTNCriticalStrike', kind = 'passive',
        basePct = 1.5, per = 0.5,
        apply = function(s, v) s.critStrike = 0.15; s.critStrikeMult = math.max(s.critStrikeMult, v.bonus) end,
        desc = 'Attacks have a 15\037 chance to deal {pct2}\037 damage (cleave too). Spells do not; crit chance can add on top.'})

    spell('holy_light', {name = 'Holy Light', code = 'AHhb', icon = 'BTNHolyBolt', kind = 'heal', cd = 6.0, heal = 60,
        threshold = 0.85, dmg = 45, radius = 260, fx = FX.holyLight,
        desc = 'When hurt or surrounded, heals {heal} health and sears enemies within {radius} for {dmg} damage.'})
    spell('divine_shield', {name = 'Divine Shield', code = 'AHds', icon = 'BTNDivineIntervention', kind = 'buff', cd = 30.0,
        dur = 2.5, trigger = 'enemies', invulnerable = true, fx = FX.divineShield, dmg = 70, radius = 300, burstFx = FX.holyLight,
        desc = 'When surrounded, bursts with holy light for {dmg} damage within {radius} and becomes invulnerable for {dur} sec.'})
    spell('resurrection', {name = 'Resurrection', code = 'AHre', icon = 'BTNResurrection', kind = 'passive', maxRank = 1,
        apply = function(s) s.lives = s.lives + 1 end, desc = 'Return to life once per run with half health.'})
    spell('consecration', {name = 'Consecration', code = 'AHhb', icon = 'BTNHolyBolt', kind = 'aura', interval = 0.75,
        dmg = 14, radius = 230, fx = FX.holyLight, attach = 'Abilities\\Spells\\Human\\DevotionAura\\DevotionAura.mdl',
        desc = 'Holy ground under the hero deals {dmg} damage every 0.75 sec within {radius}.'})
    spell('siphon_mana', {name = 'Siphon Life', code = 'AHdr', icon = 'BTNManaDrain', kind = 'chain', cd = 2.8, dmg = 30,
        count = 2, countEvery = 2, range = 700, fork = true, lightning = 'DRAL', leech = 0.25, manaGain = 4, impact = FX.vampiric,
        desc = 'Drains {count} nearby enemies for {dmg} damage, healing for a quarter of it and taking 4 mana from each.'})
    spell('phoenix', {name = 'Phoenix', code = 'AHpx', icon = 'BTNMarkOfFire', kind = 'orbit', count = 1, countEvery = 4,
        dmg = 34, orbitRadius = 230, hitRadius = 90, speed = 1.6, missile = FX.phoenix, scale = 1.2,
        desc = '{count} phoenix circles the hero, burning enemies it passes for {dmg} damage.'})
    spell('fireball', {name = 'Fireball', code = 'ANfb', icon = 'BTNFireBolt', kind = 'bolt', cd = 2.0, dmg = 42, count = 1,
        countEvery = 2, range = 900, missile = FX.fireball, speed = 900, splash = 140,
        desc = 'Launches {count} fireball for {dmg} damage that splashes nearby enemies.'})
    spell('rain_of_fire', {name = 'Rain of Fire', code = 'ANrf', icon = 'BTNFire', kind = 'zone', cd = 7.0, dmg = 34,
        radius = 280, range = 950, waves = 5, interval = 0.55, spread = 3, fx = FX.rainOfFire, waveSound = 'RainOfFireWave',
        desc = 'Rains fire on the densest pack: {waves} waves of {dmg} damage within {radius}.'})
    spell('immolation', {name = 'Immolation', code = 'AEim', icon = 'BTNImmolationOn', kind = 'aura', interval = 0.5,
        dmg = 11, radius = 220, fx = FX.immolationHit, attach = FX.immolation,
        desc = 'Burns enemies within {radius} for {dmg} damage every 0.5 sec.'})
    spell('incinerate', {flat = true, name = 'Incinerate', code = 'ANic', icon = 'BTNIncinerateOn', kind = 'passive', per = 14,
        apply = function(s, v) s.explode = s.explode + v.amount end,
        desc = 'Slain enemies explode for {pct} damage to enemies near them.'})

    -- Horde
    spell('bladestorm', {name = 'Bladestorm', code = 'AOww', icon = 'BTNWhirlwind', kind = 'zone', cd = 6.5, dmg = 22,
        radius = 230, follow = true, waves = 8, interval = 0.3, fx = FX.mirrorImage, spinAnim = true,
        desc = 'Spins for {waves} strikes of {dmg} damage to everything within {radius}.'})
    spell('wind_walk', {name = 'Wind Walk', code = 'AOwk', icon = 'BTNWindWalkOn', kind = 'buff', cd = 12.0, dur = 4,
        per = 0.08, trigger = 'enemies', fade = 110, dmg = 80, radius = 200, burstFx = FX.cleave, sound = 'WindWalk',
        apply = function(s, v) s.move = s.move + 0.3; s.crit = s.crit + v.amount end,
        desc = 'When surrounded, a backstab deals {dmg} damage within {radius}, then +30\037 movement speed and +{pct}\037 critical chance for {dur} sec.'})
    spell('mirror_image', {name = 'Mirror Image', code = 'AOmi', icon = 'BTNMirrorImage', kind = 'nova', cd = 24.0, dmg = 50,
        radius = 260, fx = FX.mirrorImage, images = true,
        desc = 'Splits into images that slash every enemy within {radius} for {dmg} damage and draw the enemies close by. Images have a quarter of your health and fade after 6 seconds.'})
    spell('endurance_aura', {name = 'Endurance Aura', code = 'AOae', icon = 'BTNCommand', kind = 'aura', per = 0.05,
        interval = 1.0, dmg = 12, radius = 240, fx = FX.cleave,
        apply = function(s, v) s.move = s.move + v.amount; s.attackSpeed = s.attackSpeed + v.amount end,
        desc = 'Nearby enemies within {radius} take {dmg} damage every second. +{pct}\037 movement and attack speed.'})
    spell('bloodlust', {name = 'Bloodlust', code = 'Ablo', icon = 'BTNBloodLust', kind = 'buff', cd = 16.0, dur = 7,
        per = 0.08, basePct = 0.25, trigger = 'enemies', fx = FX.bloodlust, scale = 1.15,
        apply = function(s, v) s.attackSpeed = s.attackSpeed + v.bonus; s.move = s.move + 0.1 end,
        desc = 'Frenzies for {dur} sec: +{pct2}\037 attack speed and +10\037 movement speed.'})
    spell('shockwave', {name = 'Shockwave', code = 'AOsh', icon = 'BTNShockWave', kind = 'line', cd = 3.5, dmg = 55,
        count = 1, countEvery = 2, range = 900, width = 130, speed = 1050, missile = FX.shockwave,
        desc = 'Sends {count} shockwave through enemies in a line for {dmg} damage.'})
    spell('evasion', {name = 'Evasion', code = 'AEev', icon = 'BTNEvasion', kind = 'passive', per = 0.05,
        apply = function(s, v) s.dodge = s.dodge + v.amount end, desc = '{pct}\037 chance to dodge attacks.'})
    spell('feral_spirit', {name = 'Feral Spirit', code = 'AOsf', icon = 'BTNSpiritWolf', kind = 'summon', cd = 15.0, 
        count = 2, countEvery = 2, units = {'osw1', 'osw1', 'osw2', 'osw2', 'osw3'}, dmg = 18, hp = 300, birth = FX.feralSpirit,
        desc = 'Calls {count} spirit wolves for {dur} sec. Each bites for {dmg}.'})
    spell('earthquake', {name = 'Earthquake', code = 'AOeq', icon = 'BTNEarthquake', kind = 'zone', cd = 8.0, dmg = 22,
        radius = 320, range = 900, waves = 7, interval = 0.5, spread = 1, fx = FX.earthquake, slow = 0.5,
        desc = 'Shakes the densest pack: {waves} tremors of {dmg} damage within {radius}, slowing by 50\037.'})
    spell('lightning_shield', {name = 'Lightning Shield', code = 'AOls', icon = 'BTNLightningShield', kind = 'aura',
        interval = 0.5, dmg = 13, radius = 190, fx = FX.bolt, attach = FX.lightningShield,
        desc = 'A crackling shield deals {dmg} damage every 0.5 sec to enemies within {radius}.'})
    spell('forked_lightning', {name = 'Forked Lightning', code = 'ANfl', icon = 'BTNMonsoon', kind = 'chain', cd = 2.6,
        dmg = 34, count = 3, countEvery = 1, range = 750, fork = true, lightning = 'FORK', impact = FX.bolt,
        desc = 'Forks lightning into the {count} nearest enemies for {dmg} damage each.'})
    spell('healing_wave', {name = 'Healing Wave', code = 'AOhw', icon = 'BTNHealingWave', kind = 'heal', cd = 8.0, heal = 80,
        threshold = 0.75, dmg = 40, radius = 280, fx = FX.healingWave,
        desc = 'When hurt or surrounded, a healing wave restores {heal} health and hits enemies within {radius} for {dmg} damage.'})
    spell('reincarnation', {name = 'Reincarnation', code = 'AOre', icon = 'BTNReincarnation', kind = 'passive', maxRank = 1,
        apply = function(s) s.lives = s.lives + 1 end, desc = 'Rise again once per run with half health.'})
    spell('stampede', {name = 'Stampede', code = 'ANst', icon = 'BTNStampede', kind = 'zone', cd = 9.0, dmg = 26,
        radius = 300, range = 900, waves = 8, interval = 0.35, spread = 4, fx = FX.stampede,
        desc = 'Lizards trample the densest pack: {waves} waves of {dmg} damage within {radius}.'})
    spell('serpent_ward', {name = 'Serpent Ward', code = 'AOsw', icon = 'BTNSerpentWard', kind = 'summon', cd = 9.0, 
        count = 1, countEvery = 1, ward = true, units = {'osp1', 'osp1', 'osp2', 'osp2', 'osp3'}, dmg = 18, hp = 120,
        birth = FX.teleport, desc = 'Plants {count} serpent ward for {dur} sec. Each spits for {dmg}.'})
    spell('hex', {name = 'Hex', code = 'AOhx', icon = 'BTNHex', kind = 'bolt', cd = 3.5, dmg = 35, count = 2, countEvery = 2,
        range = 800, missile = FX.lichMissile, speed = 900, slow = 0.7, slowDur = 3.0, impact = FX.hex,
        desc = 'Hexes the {count} nearest enemies for {dmg} damage and cripples them (70\037 slow).'})
    spell('big_bad_voodoo', {name = 'Big Bad Voodoo', code = 'AOvd', icon = 'BTNBigBadVoodooSpell', kind = 'buff', cd = 35.0,
        dur = 3, trigger = 'enemies', invulnerable = true, fx = FX.voodoo, dmg = 75, radius = 320, burstFx = FX.voodoo,
        desc = 'When surrounded, curses enemies within {radius} for {dmg} damage and becomes invulnerable for {dur} sec.'})
    spell('shadow_strike', {name = 'Shadow Strike', code = 'AEsh', icon = 'BTNShadowStrike', kind = 'bolt', cd = 2.6, dmg = 30,
        count = 1, countEvery = 2, range = 850, missile = FX.shadowStrike, speed = 1100, dot = 14, dotDur = 4, slow = 0.4, slowDur = 2,
        desc = 'Throws {count} poisoned dagger: {dmg} damage, then {dot} damage per second for 4 sec.'})
    spell('voodoo_spirits', {name = 'Voodoo Spirits', code = 'AOvd', icon = 'BTNSpiritOfVengeance', kind = 'orbit', count = 2,
        countEvery = 2, dmg = 22, orbitRadius = 200, hitRadius = 80, speed = 2.0, missile = FX.spirit,
        desc = '{count} spirits orbit the hero, hitting enemies for {dmg} damage.'})

    -- Undead
    spell('death_coil', {name = 'Death Coil', code = 'AUdc', icon = 'BTNDeathCoil', kind = 'bolt', cd = 2.2, dmg = 52, count = 1,
        countEvery = 2, range = 900, missile = FX.deathCoil, speed = 900, impact = FX.deathCoilHit, leech = 0.15,
        desc = 'Hurls {count} coil of death for {dmg} damage. Heals for 15\037 of the damage.'})
    spell('death_pact', {name = 'Death Pact', code = 'AUdp', icon = 'BTNDeathPact', kind = 'heal', cd = 14.0, heal = 150,
        threshold = 0.5, dmg = 40, radius = 300, fx = FX.darkRitual,
        desc = 'Below half health, devours life around the hero: {heal} health and {dmg} damage within {radius}.'})
    spell('unholy_aura', {flat = true, name = 'Unholy Aura', code = 'AUau', icon = 'BTNUnholyAura', kind = 'aura', per = 0.6,
        interval = 1.0, dmg = 11, radius = 240, fx = FX.deathCoilHit,
        apply = function(s, v) s.regen = s.regen + v.amount; s.move = s.move + 0.03 * v.rank end,
        desc = 'Rot hits enemies within {radius} for {dmg} damage every second. +{pct} health per second and +{rank3}\037 movement speed.'})
    spell('animate_dead', {name = 'Animate Dead', code = 'AUan', icon = 'BTNAnimateDead', kind = 'summon', cd = 18.0, 
        count = 3, countEvery = 1, units = {'uske'}, dmg = 16, hp = 240, birth = FX.animateDead,
        desc = 'Raises {count} skeletons for {dur} sec. Each strikes for {dmg}.'})
    spell('death_and_decay', {name = 'Death and Decay', code = 'AUdd', icon = 'BTNDeathAndDecay', kind = 'zone', cd = 9.0,
        dmg = 24, radius = 330, range = 900, waves = 8, interval = 0.5, spread = 2, fx = FX.deathAndDecay,
        desc = 'Rots the densest pack: {waves} pulses of {dmg} damage within {radius}.'})
    spell('howl_of_terror', {name = 'Howl of Terror', code = 'ANht', icon = 'BTNHowlOfTerror', kind = 'nova', cd = 7.0,
        dmg = 30, radius = 380, fx = FX.howl, slow = 0.45, slowDur = 4.0,
        desc = 'Howls for {dmg} damage within {radius}, slowing enemies by 45\037 for 4 sec.'})
    spell('vampiric_aura', {name = 'Vampiric Aura', code = 'AUav', icon = 'BTNVampiricAura', kind = 'aura', per = 0.025,
        interval = 1.0, dmg = 12, radius = 240, fx = FX.vampiric,
        apply = function(s, v) s.lifesteal = s.lifesteal + v.amount end,
        desc = 'Drains enemies within {radius} for {dmg} damage every second. Heals for {pct}\037 of all damage dealt.'})
    spell('carrion_swarm', {name = 'Carrion Swarm', code = 'AUcs', icon = 'BTNCarrionSwarm', kind = 'line', cd = 3.2, dmg = 52,
        count = 1, countEvery = 2, range = 850, width = 150, speed = 950, missile = FX.carrionSwarm,
        desc = 'Unleashes {count} swarm of bats through a line of enemies for {dmg} damage.'})
    spell('sleep', {name = 'Sleep', code = 'AUsl', icon = 'BTNSleep', kind = 'nova', cd = 9.0, dmg = 20, radius = 300,
        fx = FX.sleep, stun = 2.0, desc = 'Puts enemies within {radius} to sleep for {stun} sec and deals {dmg} damage.'})
    spell('inferno', {name = 'Inferno', code = 'AUin', icon = 'BTNInfernal', kind = 'summon', cd = 30.0, count = 1,
        countEvery = 4, units = {'ninf'}, dmg = 45, hp = 1200, impactDamage = 120, radius = 260, birth = FX.infernal, nearEnemy = true,
        desc = 'Drops {count} infernal on the enemy for {impact} damage within {radius}. It fights for {dur} sec.'})
    spell('frost_armor', {flat = true, name = 'Frost Armor', code = 'AUfu', icon = 'BTNFrostArmor', kind = 'aura', per = 2,
        interval = 1.0, dmg = 10, radius = 230, fx = FX.frostArmor, slow = 0.25, slowDur = 1.5,
        apply = function(s, v) s.armor = s.armor + v.amount; s.thorns = s.thorns + 6 * v.rank end,
        desc = 'Frost chills enemies within {radius} for {dmg} damage every second. Grants {pct} armor; attackers take {rank6} frost damage.'})
    spell('dark_ritual', {name = 'Dark Ritual', code = 'AUdr', icon = 'BTNDarkRitual', kind = 'heal', cd = 6.0, heal = 40,
        threshold = 0.9, dmg = 35, radius = 260, fx = FX.darkRitual,
        desc = 'When hurt or surrounded, sacrifices dark energy: {heal} health and {dmg} damage within {radius}.'})
    spell('frost_bolt', {name = 'Frost Bolt', code = 'ACfb', icon = 'BTNFrostBolt', kind = 'bolt', cd = 1.6, dmg = 32, count = 1,
        countEvery = 2, range = 900, missile = FX.frostBolt, speed = 1000, slow = 0.4, slowDur = 2.0, scale = 0.7,
        desc = 'Fires {count} frost bolt for {dmg} damage, slowing by 40\037.'})
    spell('frost_orbs', {name = 'Frost Orbs', code = 'AUfn', icon = 'BTNOrbOfFrost', kind = 'orbit', count = 2, countEvery = 2,
        dmg = 20, orbitRadius = 210, hitRadius = 85, speed = 1.8, missile = FX.lichMissile, slow = 0.3,
        desc = '{count} frost orbs circle the hero, hitting for {dmg} and chilling enemies.'})
    spell('impale', {name = 'Impale', code = 'AUim', icon = 'BTNImpale', kind = 'line', cd = 4.0, dmg = 60, count = 1,
        countEvery = 2, range = 800, width = 140, speed = 1200, stun = 0.8, trail = FX.impale, sound = 'ImpaleCast',
        desc = 'Spikes erupt in a line for {dmg} damage, stunning for {stun} sec.'})
    spell('spiked_carapace', {flat = true, name = 'Spiked Carapace', code = 'AUts', icon = 'BTNThornShield', kind = 'aura', per = 2,
        interval = 1.0, dmg = 12, radius = 220, fx = FX.impale,
        apply = function(s, v) s.armor = s.armor + v.amount; s.thorns = s.thorns + 10 * v.rank end,
        desc = 'Spikes hit enemies within {radius} for {dmg} damage every second. Grants {pct} armor; attackers take {rank10} damage.'})
    spell('carrion_beetles', {name = 'Carrion Beetles', code = 'AUcb', icon = 'BTNCarrionScarabs', kind = 'summon', cd = 12.0,
        count = 2, countEvery = 1, units = {'ucs1', 'ucs1', 'ucs2', 'ucs2', 'ucs3'}, dmg = 14, hp = 220,
        birth = FX.animateDead, desc = 'Spawns {count} carrion beetles for {dur} sec. Each bites for {dmg}.'})
    spell('locust_swarm', {name = 'Locust Swarm', code = 'AUls', icon = 'BTNLocustSwarm', kind = 'orbit', count = 4,
        countEvery = 1, dmg = 12, orbitRadius = 260, hitRadius = 70, speed = 2.6, missile = FX.cryptFiend, scale = 0.6,
        leech = 0.2, desc = '{count} locusts swirl around the hero for {dmg} damage, bringing back 20\037 as health.'})

    -- Night Elf
    spell('mana_burn', {name = 'Mana Burn', code = 'AEmb', icon = 'BTNManaBurn', kind = 'bolt', cd = 1.8, dmg = 40, count = 1,
        countEvery = 2, range = 800, missile = FX.arcane, speed = 1200, impact = FX.manaBurn, manaGain = 5,
        desc = 'Burns {count} enemy for {dmg} damage, taking 5 mana from each hit.'})
    spell('metamorphosis', {name = 'Metamorphosis', code = 'AEme', icon = 'BTNMetamorphosis', kind = 'buff', cd = 35.0,
        dur = 10, per = 0.1, basePct = 0.25, trigger = 'enemies', fx = FX.avatar, scale = 1.3, dmg = 70, radius = 300,
        burstFx = FX.immolationHit,
        apply = function(s, v) s.damage = s.damage + v.bonus; s.maxHp = s.maxHp + 200; s.range = s.range + 350 end,
        desc = 'Erupts into a demon for {dmg} damage within {radius}, then has +{pct2}\037 damage, +200 health and ranged attacks for {dur} sec.'})
    spell('glaive_toss', {name = 'Glaive Toss', code = 'AEbl', icon = 'BTNUpgradeMoonGlaive', kind = 'bolt', cd = 2.2, dmg = 34,
        count = 1, countEvery = 3, range = 850, missile = FX.glaive, speed = 1100, bounce = 3,
        desc = 'Throws {count} glaive for {dmg} damage that bounces to 3 more enemies.'})
    spell('fan_of_knives', {name = 'Fan of Knives', code = 'AEfk', icon = 'BTNFanOfKnives', kind = 'nova', cd = 3.0, dmg = 36,
        radius = 300, fx = FX.fanOfKnives, desc = 'Throws knives in every direction for {dmg} damage within {radius}.'})
    spell('entangling_roots', {name = 'Entangling Roots', code = 'AEer', icon = 'BTNEntanglingRoots', kind = 'bolt', cd = 3.0,
        dmg = 30, count = 2, countEvery = 2, range = 800, instant = true, impact = FX.entangle, stun = 1.5, dot = 10, dotDur = 3,
        desc = 'Roots the {count} nearest enemies for {stun} sec, dealing {dmg} plus {dot} per second.'})
    spell('force_of_nature', {name = 'Force of Nature', code = 'AEfn', icon = 'BTNEnt', kind = 'summon', cd = 16.0, 
        count = 2, countEvery = 1, units = {'efon'}, dmg = 20, hp = 350, birth = FX.tranquility,
        desc = 'Awakens {count} treants for {dur} sec. Each strikes for {dmg}.'})
    spell('thorns_aura', {flat = true, name = 'Thorns Aura', code = 'AEah', icon = 'BTNThorns', kind = 'aura', per = 14,
        interval = 1.0, dmg = 12, radius = 240, fx = FX.entangle,
        apply = function(s, v) s.thorns = s.thorns + v.amount end,
        desc = 'Thorns lash enemies within {radius} for {dmg} damage every second. Attackers take {pct} damage.'})
    spell('tranquility', {name = 'Tranquility', code = 'AEtq', icon = 'BTNTranquility', kind = 'heal', cd = 14.0, heal = 140,
        threshold = 0.6, dmg = 45, radius = 340, fx = FX.tranquility,
        desc = 'When hurt or surrounded, calls down rain: {heal} health and {dmg} damage to enemies within {radius}.'})
    spell('starfall', {name = 'Starfall', code = 'AEsf', icon = 'BTNStarfall', kind = 'zone', cd = 9.0, dmg = 30, radius = 520,
        onHero = true, waves = 8, interval = 0.4, strikes = true, count = 4, countEvery = 1, fx = FX.starfall,
        desc = 'Stars fall around the hero: {waves} waves, each striking {count} enemies within {radius} for {dmg} damage.'})
    spell('tornado', {name = 'Cyclone', code = 'ANto', icon = 'BTNTornado', kind = 'zone', cd = 10.0, dmg = 18, radius = 230,
        range = 900, waves = 10, interval = 0.4, spread = 1, fx = FX.tornado, slow = 0.4,
        desc = 'A cyclone tears through the densest pack: {waves} hits of {dmg} damage within {radius}.'})
    spell('searing_arrows', {name = 'Searing Arrows', code = 'AHfa', icon = 'BTNSearingArrows', kind = 'bolt', cd = 1.6,
        dmg = 28, count = 2, countEvery = 2, range = 900, missile = FX.searingArrow, speed = 1300,
        desc = 'Looses {count} burning arrows at the nearest enemies for {dmg} damage each.'})
    spell('scout', {name = 'Scout', code = 'AEst', icon = 'BTNScout', kind = 'bolt', cd = 3.5, dmg = 34, count = 2,
        countEvery = 2, range = 1100, missile = FX.spirit, speed = 900, bounce = 1,
        desc = 'An owl spirit dives on the {count} nearest enemies for {dmg} damage, then on one more.'})
    spell('trueshot_aura', {name = 'Trueshot Aura', code = 'AEar', icon = 'BTNTrueShot', kind = 'aura', per = 0.07,
        interval = 1.0, dmg = 12, radius = 260, fx = FX.searingArrow,
        apply = function(s, v) s.damage = s.damage + v.amount end,
        desc = 'Arrows of light hit enemies within {radius} for {dmg} damage every second. +{pct}\037 damage.'})
    spell('moon_glaives', {name = 'Moon Glaives', code = 'AEsf', icon = 'BTNUpgradeMoonGlaive', kind = 'orbit', count = 2,
        countEvery = 2, dmg = 24, orbitRadius = 240, hitRadius = 85, speed = 2.2, missile = FX.moonGlaive,
        desc = '{count} glaives circle the hero, slicing enemies for {dmg} damage.'})
    spell('barrage', {flat = true, name = 'Barrage', code = 'Aroc', icon = 'BTNScatterRockets', kind = 'passive', per = 1,
        apply = function(s, v) s.multishot = s.multishot + v.rank end,
        desc = 'Attacks and bolts fire {rank} extra projectile(s).'})
    spell('frost_arrows', {flat = true, name = 'Frost Arrows', code = 'ANfa', icon = 'BTNColdArrowsOn', kind = 'passive', per = 6,
        apply = function(s, v) s.attackBonus = s.attackBonus + v.amount; s.attackSlow = math.max(s.attackSlow, 0.3) end,
        desc = 'Attacks deal +{pct} cold damage and slow by 30\037.'})
    spell('vengeance', {name = 'Spirit of Vengeance', code = 'AEsv', icon = 'BTNSpiritOfVengeance', kind = 'summon', cd = 18.0,
        count = 2, countEvery = 1, units = {'espv'}, dmg = 24, hp = 400, birth = FX.blink,
        desc = 'Calls {count} spirits of vengeance for {dur} sec. Each strikes for {dmg}.'})
    spell('blink_strike', {name = 'Blink Strike', code = 'AEbl', icon = 'BTNBlink', kind = 'nova', cd = 4.0, dmg = 55,
        radius = 200, range = 700, atTarget = true, fx = FX.blink,
        desc = 'Blinks into the nearest enemy, dealing {dmg} damage within {radius}.'})

    -- Tavern
    spell('crushing_wave', {name = 'Crushing Wave', code = 'ANcw', icon = 'BTNCrushingWave', kind = 'line', cd = 3.6, dmg = 50,
        count = 1, countEvery = 2, range = 900, width = 150, speed = 950, missile = FX.crushingWave,
        desc = 'Sends {count} wave crashing through a line of enemies for {dmg} damage.'})
    spell('black_arrow', {name = 'Black Arrow', code = 'ANba', icon = 'BTNTheBlackArrow', kind = 'bolt', cd = 1.5, dmg = 30,
        count = 1, countEvery = 2, range = 900, missile = FX.blackArrow, speed = 1300, dot = 12, dotDur = 3,
        desc = 'Shoots {count} cursed arrow for {dmg} damage plus {dot} per second for 3 sec.'})
    spell('life_drain', {name = 'Life Drain', code = 'ANdr', icon = 'BTNLifeDrain', kind = 'chain', cd = 2.4, dmg = 36,
        count = 1, countEvery = 2, range = 650, fork = true, lightning = 'DRAL', leech = 0.5, impact = FX.vampiric,
        desc = 'Drains {count} enemy for {dmg} damage and heals for half of it.'})
    spell('charm', {name = 'Charm', code = 'ANch', icon = 'BTNCharm', kind = 'bolt', cd = 7.0, dmg = 95, count = 1,
        range = 900, instant = true, prefersBoss = true, impact = FX.hex, splash = 200,
        desc = 'Charms the strongest enemy in reach: it turns on its pack and burns out for {dmg} damage, half of it to those around.'})
    spell('silence', {name = 'Silence', code = 'ANsi', icon = 'BTNSilence', kind = 'nova', cd = 8.0, dmg = 26, radius = 300,
        range = 800, atTarget = true, fx = FX.silence, slow = 0.6, slowDur = 3.0,
        desc = 'Silences the nearest pack: {dmg} damage within {radius} and a 60\037 slow.'})
    spell('summon_bear', {name = 'Summon Bear', code = 'ANsg', icon = 'BTNGrizzlyBear', kind = 'summon', cd = 20.0, 
        count = 1, countEvery = 3, units = {'ngz1', 'ngz1', 'ngz2', 'ngz2', 'ngz3'}, dmg = 40, hp = 900, birth = FX.teleport,
        desc = 'Calls {count} bear for {dur} sec. It mauls for {dmg}.'})
    spell('summon_quilbeast', {name = 'Summon Quilbeast', code = 'ANsq', icon = 'BTNQuillBeast', kind = 'summon', cd = 12.0,
        count = 1, countEvery = 2, units = {'nqb1', 'nqb1', 'nqb2', 'nqb2', 'nqb3'}, dmg = 24, hp = 350, birth = FX.teleport,
        desc = 'Calls {count} quilbeast for {dur} sec. It strikes for {dmg}.'})
    spell('summon_hawk', {name = 'Summon Hawk', code = 'ANsw', icon = 'BTNWarEagle', kind = 'bolt', cd = 2.6, dmg = 30, count = 2,
        countEvery = 2, range = 1000, missile = FX.spirit, speed = 1200, scale = 0.9,
        desc = 'A war hawk dives on the {count} nearest enemies for {dmg} damage each.'})
    spell('breath_of_fire', {name = 'Breath of Fire', code = 'ANbf', icon = 'BTNBreathOfFire', kind = 'line', cd = 3.0, dmg = 46,
        count = 1, countEvery = 2, range = 700, width = 180, speed = 900, missile = FX.breathOfFire, dot = 10, dotDur = 3,
        desc = 'Breathes {count} cone of fire for {dmg} damage that keeps burning for {dot} per second.'})
    spell('drunken_haze', {name = 'Drunken Haze', code = 'ANdh', icon = 'BTNStrongDrink', kind = 'nova', cd = 5.0, dmg = 26,
        radius = 260, range = 750, atTarget = true, fx = FX.drunkenHaze, slow = 0.55, slowDur = 4.0,
        desc = 'Douses the nearest pack in brew: {dmg} damage within {radius} and a 55\037 slow.'})
    spell('drunken_brawler', {name = 'Drunken Brawler', code = 'ANdb', icon = 'BTNDrunkenDodge', kind = 'passive', per = 0.035,
        apply = function(s, v) s.dodge = s.dodge + v.amount; s.crit = s.crit + v.amount end,
        desc = '+{pct}\037 dodge and +{pct}\037 critical strike chance.'})
    spell('storm_earth_fire', {name = 'Storm, Earth and Fire', code = 'ANef', icon = 'BTNStormEarth&Fire', kind = 'summon',
        cd = 35.0, count = 3, dur = 12, split = true, units = {'npn1', 'npn2', 'npn3'}, cycleUnits = true, dmg = 55, hp = 900,
        birth = FX.teleport,
        desc = 'Splits into Storm, Earth and Fire for {dur} sec, then the spirits merge back into the Brewmaster. Each strikes for {dmg}.'})
    spell('soul_burn', {name = 'Soul Burn', code = 'ANso', icon = 'BTNSoulBurn', kind = 'bolt', cd = 2.0, dmg = 26, count = 1,
        countEvery = 2, range = 850, missile = FX.fireball, speed = 1000, dot = 18, dotDur = 4, impact = FX.soulBurn,
        desc = 'Sets {count} enemy\'s soul ablaze: {dmg} damage plus {dot} per second for 4 sec.'})
    spell('lava_spawn', {name = 'Lava Spawn', code = 'ANlm', icon = 'BTNLavaSpawn', kind = 'summon', cd = 14.0, 
        count = 2, countEvery = 1, units = {'nlv1', 'nlv1', 'nlv2', 'nlv2', 'nlv3'}, dmg = 22, hp = 300, birth = FX.incinerate,
        desc = 'Spawns {count} lava spawn for {dur} sec. Each hits for {dmg}.'})
    spell('volcano', {name = 'Volcano', code = 'ANvc', icon = 'BTNVolcano', kind = 'zone', cd = 12.0, dmg = 40, radius = 320,
        range = 950, waves = 6, interval = 0.6, spread = 3, fx = FX.volcano, stun = 0.5,
        desc = 'Erupts under the densest pack: {waves} waves of {dmg} damage within {radius}.'})
    spell('cluster_rockets', {name = 'Cluster Rockets', code = 'ANcs', icon = 'BTNClusterRockets', kind = 'zone', cd = 3.5,
        dmg = 34, radius = 230, range = 950, waves = 3, interval = 0.25, spread = 4, fx = FX.rocket,
        desc = 'Showers the densest pack with rockets: {waves} volleys of {dmg} damage within {radius}.'})
    spell('pocket_factory', {name = 'Pocket Factory', code = 'ANsy', icon = 'BTNPocketFactory', kind = 'summon', cd = 12.0,
        count = 2, countEvery = 1, units = {'ncg1', 'ncg1', 'ncg2', 'ncg2', 'ncg3'}, dmg = 18, hp = 260, birth = FX.rocket,
        desc = 'Deploys {count} clockwerk goblins for {dur} sec. Each hits for {dmg}.'})
    spell('robo_goblin', {name = 'Robo-Goblin', code = 'ANrg', icon = 'BTNROBOGOBLIN', kind = 'buff', cd = 25.0, dur = 10,
        per = 0.08, basePct = 0.15, trigger = 'enemies', fx = FX.explosion, scale = 1.2, dmg = 65, radius = 300,
        burstFx = FX.explosion,
        apply = function(s, v) s.armor = s.armor + 6; s.damage = s.damage + v.bonus end,
        desc = 'Lands in a robot suit for {dmg} damage within {radius}, then has +6 armor and +{pct2}\037 damage for {dur} sec.'})
    spell('engineering', {name = 'Engineering Upgrade', code = 'ANeg', icon = 'BTNEngineeringUpgrade', kind = 'passive', per = 0.04,
        apply = function(s, v) s.cdr = s.cdr + v.amount; s.area = s.area + v.amount end,
        desc = 'Spells recharge {pct}\037 faster and cover {pct}\037 more area.'})
    spell('acid_bomb', {name = 'Acid Bomb', code = 'ANab', icon = 'BTNAcidBomb', kind = 'bolt', cd = 2.2, dmg = 36, count = 1,
        countEvery = 2, range = 850, missile = FX.acidBomb, speed = 800, splash = 180, slow = 0.3, slowDur = 3.0,
        desc = 'Lobs {count} acid bomb for {dmg} damage that splashes and slows.'})
    spell('healing_spray', {name = 'Healing Spray', code = 'ANhs', icon = 'BTNHealingSpray', kind = 'heal', cd = 10.0, heal = 120,
        threshold = 0.7, dmg = 30, radius = 280, fx = FX.healSpray,
        desc = 'When hurt, sprays a tonic: {heal} health and {dmg} damage to enemies within {radius}.'})
    spell('chemical_rage', {name = 'Chemical Rage', code = 'ANcr', icon = 'BTNChemicalRage', kind = 'buff', cd = 22.0, dur = 9,
        per = 0.08, basePct = 0.3, trigger = 'enemies', fx = FX.bloodlust, scale = 1.25, dmg = 55, radius = 280,
        burstFx = FX.acidBomb,
        apply = function(s, v) s.attackSpeed = s.attackSpeed + v.bonus; s.move = s.move + 0.15 end,
        desc = 'Smashes the potion for {dmg} damage within {radius}, then has +{pct2}\037 attack speed and +15\037 movement speed for {dur} sec.'})
    spell('transmute', {name = 'Transmute', code = 'ANtm', icon = 'BTNTransmute', kind = 'bolt', cd = 6.0, dmg = 90, count = 1,
        range = 850, instant = true, prefersBoss = true, impact = FX.transmute, per = 0.012,
        apply = function(s, v) s.killGold = s.killGold + v.amount; s.gold = s.gold + v.amount end,
        desc = 'Turns the strongest enemy in reach to gold for {dmg} damage. Kills have a {pct}\037 chance to drop gold; +{pct}\037 gold.'})
    spell('doom', {name = 'Doom', code = 'ANdo', icon = 'BTNDoom', kind = 'bolt', cd = 8.0, dmg = 160, count = 1, countEvery = 3,
        range = 900, instant = true, impact = FX.doom, prefersBoss = true,
        desc = 'Dooms {count} enemy for {dmg} damage. Prefers bosses and elites.'})

    -- Medivh (campaign art only: none of these is one of his abilities in the game).
    spell('arcane_barrage', {name = 'Arcane Barrage', icon = 'BTNManaFlare', kind = 'bolt', cd = 2.2, dmg = 22, count = 3,
        countEvery = 2, range = 900, missile = FX.manaFlare, speed = 1100, impact = FX.manaFlareHit, scale = 0.9,
        desc = 'Looses {count} bolts of arcane fire at the nearest enemies for {dmg} damage each.'})
    spell('raven_form', {name = 'Raven Form', icon = 'BTNRavenForm', kind = 'buff', cd = 18.0, dur = 6, per = 0.05,
        basePct = 0.15, trigger = 'enemies', morph = 'alternate', fly = true, burstFx = FX.blink, dmg = 40, radius = 240,
        apply = function(s, v) s.move = s.move + 0.4; s.dodge = s.dodge + v.bonus end,
        desc = 'When surrounded, bursts into a raven for {dur} sec ({dmg} damage within {radius}): flies over enemies, +40\037 movement speed and +{pct2}\037 dodge.'})
    spell('enchanted_crows', {name = 'Enchanted Crows', icon = 'BTNEnchantedCrows', kind = 'orbit', count = 2, countEvery = 2,
        dmg = 20, orbitRadius = 220, hitRadius = 85, speed = 2.0, missile = FX.stormCrow, scale = 1.1,
        desc = '{count} enchanted storm crows circle Medivh, striking enemies they pass for {dmg} damage.'})
    spell('dark_portal', {name = 'Dark Portal', icon = 'BTNDarkPortal', kind = 'summon', cd = 18.0, count = 2, countEvery = 2,
        units = {'ogru', 'ogru', 'nchg', 'nchg', 'nchg'}, dmg = 26, hp = 520, birth = FX.darkPortal,
        desc = 'Tears open the Dark Portal: {count} orc warriors charge through and fight for {dur} sec. Each strikes for {dmg}.'})

    -- The codex lists, in hero order, only the spells some hero's pool offers.
    for _, hero in ipairs(HEROES) do
        for _, key in ipairs(hero.pool) do
            if SPELLS[key] and not SPELLS[key].listed then
                SPELLS[key].listed = true
                SPELL_ORDER[#SPELL_ORDER + 1] = key
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Mana costs. A spell costs what its Warcraft III ability spends per
    -- second there (cost / cooldown, from AbilityData.slk), over its own
    -- cooldown here, times CFG.MANA_COST_SCALE. Spells that cost much in
    -- Warcraft III cost much here. The rate is kept between CFG.MANA_RATE_MIN
    -- and MAX (ultimates, three-second Mirror Images); an ability with no
    -- cooldown (arrows, Banish) counts its cost once per cast here. Auras,
    -- orbits and passives never cast, so they are free.
    ---------------------------------------------------------------------------
    local MANA_DATA = {
        AHbz = {75, 6}, AHwe = {125, 20}, AHmt = {100, 20}, AUfn = {125, 8}, AHfs = {135, 10}, AHbn = {75, 0},
        AOcl = {120, 9}, AOfs = {0, 60}, AHtb = {75, 9}, AHtc = {90, 6}, AHav = {150, 180}, AOws = {90, 6},
        AHhb = {65, 5}, AHds = {25, 35}, AHdr = {10, 6}, ANfb = {75, 8}, ANrf = {85, 8}, AOww = {200, 180},
        AOwk = {75, 5}, AOmi = {100, 3}, Ablo = {40, 1}, AOsh = {100, 8}, AOsf = {75, 30}, AOeq = {150, 90},
        ANfl = {110, 11}, AOhw = {90, 9}, ANst = {150, 180}, AOsw = {30, 6.5}, AOhx = {70, 7}, AOvd = {200, 180},
        AEsh = {75, 8}, AUdc = {75, 6}, AUdp = {50, 15}, AUan = {175, 180}, AUdd = {250, 150}, ANht = {75, 12},
        AUcs = {100, 10}, AUsl = {80, 4}, AUin = {175, 180}, AUdr = {25, 15}, ACfb = {75, 8}, AUim = {100, 9},
        AUcb = {30, 6}, AEmb = {60, 7}, AEme = {150, 180}, AEbl = {50, 10}, AEfk = {100, 9}, AEer = {75, 8},
        AEfn = {125, 20}, AEtq = {125, 60}, AEsf = {200, 180}, ANto = {200, 120}, AHfa = {8, 0}, AEst = {50, 20},
        AEsv = {150, 180}, ANba = {6, 0}, ANdr = {50, 8}, ANch = {150, 45}, ANsi = {75, 15}, ANsg = {125, 40},
        ANsq = {75, 25}, ANsw = {50, 70}, ANbf = {70, 10}, ANdh = {70, 12}, ANso = {85, 12}, ANlm = {150, 32},
        ANvc = {200, 180}, ANcs = {70, 6}, ANsy = {125, 35}, ANrg = {25, 1}, ANab = {75, 12}, ANhs = {75, 0},
        ANcr = {25, 30}, ANtm = {150, 45}, ANdo = {150, 120}, ANef = {150, 180}
    }
    -- Spells with no Warcraft III ability of their own: the closest one's numbers.
    local MANA_BY_SPELL = {
        crushing_wave = {100, 8},    -- like Shockwave
        arcane_barrage = {100, 20},  -- like the Archmage's arcane bolts
        raven_form = {75, 60},
        dark_portal = {175, 180}     -- an ultimate summon, like Inferno
    }
    local FREE_KINDS = {passive = true, aura = true, orbit = true}
    for _, def in pairs(SPELLS) do
        local data = MANA_BY_SPELL[def.key] or MANA_DATA[def.code or '']
        if data and not FREE_KINDS[def.kind] and def.cd then
            local cost, cooldown = data[1], data[2]
            local rate = cooldown > 0 and cost / cooldown or cost / def.cd
            rate = math.max(CFG.MANA_RATE_MIN, math.min(CFG.MANA_RATE_MAX, rate))
            def.mana = rate * def.cd * CFG.MANA_COST_SCALE
        end
    end

    ---------------------------------------------------------------------------
    -- Blessings: generic stat cards any hero can draw. They take no spell slot.
    -- The five attributes add whole points (rarity rounds them up). Every
    -- pick of a card gives the same as the first.
    -- Icons are the Warcraft III items that give the stat.
    ---------------------------------------------------------------------------
    local BLESSINGS = {
        {key = 'strength', name = 'Strength', code = 'rst1', icon = 'BTNGauntletsOfOgrePower', per = 5, flat = true, attribute = true,
            desc = '+{v} Strength', apply = function(s, x) s.str = s.str + x end},
        {key = 'agility', name = 'Agility', code = 'hcun', icon = 'BTNHoodOfCunning', per = 5, flat = true, attribute = true,
            desc = '+{v} Agility', apply = function(s, x) s.agi = s.agi + x end},
        {key = 'intellect', name = 'Intellect', code = 'ciri', icon = 'BTNRobeOfTheMagi', per = 5, flat = true, attribute = true,
            desc = '+{v} Intellect', apply = function(s, x) s.int = s.int + x end},
        {key = 'stamina', name = 'Stamina', code = 'prvt', icon = 'BTNPeriapt', per = 3, flat = true, attribute = true,
            desc = '+{v} Stamina', apply = function(s, x) s.sta = s.sta + x end},
        {key = 'armor', name = 'Armor', code = 'rde1', icon = 'BTNRingJadeFalcon', per = 2, flat = true, attribute = true,
            desc = '+{v} armor', apply = function(s, x) s.armor = s.armor + x end},
        {key = 'ferocity', name = 'Ferocity', code = 'gcel', icon = 'BTNGlove', per = 0.10,
            desc = '+{v}\037 attack speed', apply = function(s, x) s.attackSpeed = s.attackSpeed + x end},
        {key = 'haste', name = 'Haste', code = 'Ablo', icon = 'BTNBloodLust', per = 0.05,
            desc = 'Spells recharge {v}\037 faster', apply = function(s, x) s.cdr = s.cdr + x end},
        {key = 'reach', name = 'Reach', code = 'ofir', icon = 'BTNOrbOfFire', per = 0.08,
            desc = '+{v}\037 area of effect', apply = function(s, x) s.area = s.area + x end},
        {key = 'swiftness', name = 'Swiftness', code = 'bspd', icon = 'BTNBootsOfSpeed', per = 0.07,
            desc = '+{v}\037 movement speed', apply = function(s, x) s.move = s.move + x end},
        {key = 'regeneration', name = 'Regeneration', code = 'rlif', icon = 'BTNRingGreen', per = 1.2, flat = true,
            desc = '+{v} health per second', apply = function(s, x) s.regen = s.regen + x end},
        {key = 'precision', name = 'Precision', code = 'AOcr', icon = 'BTNCriticalStrike', per = 0.05,
            desc = '+{v}\037 critical strike chance', apply = function(s, x) s.crit = s.crit + x end},
        {key = 'brutality', name = 'Brutality', code = 'ratc', icon = 'BTNClawsOfAttack', per = 0.25,
            desc = '+{v}\037 critical strike damage', apply = function(s, x) s.critMult = s.critMult + x end},
        {key = 'vampirism', name = 'Vampirism', code = 'vamp', icon = 'BTNVampiricPotion', per = 0.02,
            desc = 'Heal for {v}\037 of damage dealt (up to 3\037 of your health a second)', apply = function(s, x) s.lifesteal = s.lifesteal + x end},
        {key = 'magnetism', name = 'Magnetism', code = 'mcou', icon = 'BTNMedalionOfCourage', per = 0.30,
            desc = '+{v}\037 pickup range', apply = function(s, x) s.pickup = s.pickup + x end},
        {key = 'wisdom', name = 'Wisdom', code = 'tkno', icon = 'BTNTome', per = 0.10,
            desc = '+{v}\037 experience', apply = function(s, x) s.xp = s.xp + x end},
        {key = 'greed', name = 'Greed', code = 'pghe', icon = 'BTNChestOfGold', per = 0.15,
            desc = '+{v}\037 gold', apply = function(s, x) s.gold = s.gold + x end},
        {key = 'multishot', name = 'Multishot', code = 'afac', icon = 'BTNAlleriaFlute', per = 1, flat = true,
            desc = '+{v} projectile on attacks and bolts', apply = function(s, x) s.multishot = s.multishot + math.floor(x + 0.01) end},
        {key = 'fortune', name = 'Fortune', code = 'cnob', icon = 'BTNCirclet', per = 0.25,
            desc = '+{v}\037 chance of rarer cards', apply = function(s, x) s.luck = s.luck + x end},
        {key = 'persistence', name = 'Persistence', code = 'hval', icon = 'BTNHelmOfValor', per = 0.15,
            desc = '+{v}\037 spell duration', apply = function(s, x) s.duration = s.duration + x end}
    }
    local BLESSING_BY_KEY = {}
    for _, b in ipairs(BLESSINGS) do
        BLESSING_BY_KEY[b.key] = b
    end
    -- Only the five attributes are offered from the start; every other card
    -- opens with an achievement (Profile.blessingOpen), from the first boss
    -- to a Heroic win, and quests will open some (phase 6).
    local BLESSING_UNLOCKS = {regeneration = 'boss_slain', swiftness = 'hold_out', ferocity = 'slayer', haste = 'survivor',
        precision = 'ascendant', vampirism = 'boss_hunter', reach = 'collector', greed = 'hoarder', wisdom = 'scholar',
        magnetism = 'veteran', persistence = 'zone2', fortune = 'artisan', brutality = 'exterminator', multishot = 'heroic'}
    for key, unlock in pairs(BLESSING_UNLOCKS) do
        BLESSING_BY_KEY[key].unlock = unlock
    end
    -- How often a card is drawn: the hero's primary attribute most, then the
    -- other attributes, then the rest.
    local BLESSING_WEIGHT = {primary = 4.0, attribute = 2.2, other = 1.4}

    ---------------------------------------------------------------------------
    -- Zones. Each one re-themes the same arena: enemies, bosses, fog and time
    -- of day. Winning a zone unlocks the next. Every boss drops gear.
    ---------------------------------------------------------------------------
    local ZONES = {
        {name = 'Ashenvale', subtitle = 'The Long Night', tier = 1, power = 1.0, density = 0.8,
            music = {'NightElf1', 'NightElf2', 'NightElf3', 'NightElfX1'},
            art = 'UI\\Glues\\Loading\\Backgrounds\\Campaigns\\Ashenvale-TopLeft.blp',
            thumb = 'Scripts\\Survivor\\zone_ashenvale.tga',
            fog = {0.10, 0.16, 0.22, 900, 4200}, time = 0.0,
            desc = 'Night has fallen on the forest. Wolves run with the furbolgs, the satyrs of Felwood creep in from the north and the Sentinels shoot at every stranger.',
            enemies = {
                {id = 'nwlt', hp = 40, dmg = 6, xp = 1, from = 0, til = 6, w = 4},
                {id = 'nfrl', hp = 70, dmg = 8, xp = 1, from = 0, til = 7, w = 3},
                {id = 'nsty', hp = 60, dmg = 8, xp = 1, from = 1, til = 8, w = 3},
                {id = 'nfrs', hp = 60, dmg = 9, xp = 2, from = 2, w = 2},
                {id = 'earc', hp = 55, dmg = 9, xp = 2, from = 2, w = 2, extra = true},
                {id = 'nwlg', hp = 110, dmg = 11, xp = 2, from = 3, w = 3},
                {id = 'nsat', hp = 90, dmg = 11, xp = 2, from = 4, w = 2},
                {id = 'nfrb', hp = 140, dmg = 14, xp = 3, from = 5, w = 3},
                {id = 'esen', hp = 150, dmg = 14, xp = 3, from = 5, w = 2, extra = true},
                {id = 'nsts', hp = 160, dmg = 15, xp = 3, from = 6, w = 2},
                {id = 'nfre', hp = 180, dmg = 16, xp = 3, from = 7, w = 2},
                {id = 'nwld', hp = 220, dmg = 18, xp = 3, from = 8, w = 3}
            },
            bosses = {
                {t = 120, id = 'nfrg', name = 'Ursol the Champion', scale = 1.8, hp = 2600, dmg = 30},
                {t = 240, id = 'nwld', name = 'Goretooth', scale = 1.9, hp = 4200, dmg = 38},
                {t = 360, id = 'nstl', name = 'Shadumbra Soulstealer', scale = 1.9, hp = 6500, dmg = 46},
                {t = 480, id = 'nfra', name = 'Old Ursangous', scale = 2.0, hp = 9500, dmg = 55}
            },
            final = {id = 'nsth', name = 'Prince Xavius', scale = 2.3, hp = 26000, dmg = 70}},

        {name = 'Westfall', subtitle = 'The Defias Uprising', tier = 2, power = 1.0, density = 0.9,
            music = {'Human1', 'Human2', 'Human3', 'HumanX1'},
            art = 'UI\\Glues\\Loading\\Backgrounds\\Campaigns\\Lordaeron-TopLeft.blp',
            thumb = 'Scripts\\Survivor\\zone_westfall.tga',
            fog = {0.42, 0.34, 0.22, 1200, 5200}, time = 18.0,
            desc = 'Kobolds pour out of the mines, murlocs crawl up from the coast and the Defias Brotherhood marches on the farms with the farmhands it bought.',
            enemies = {
                {id = 'nkob', hp = 45, dmg = 6, xp = 1, from = 0, til = 6, w = 4},
                {id = 'hpea', hp = 40, dmg = 6, xp = 1, from = 0, til = 6, w = 2, extra = true},
                {id = 'nmrl', hp = 50, dmg = 7, xp = 1, from = 0, til = 7, w = 3},
                {id = 'ngno', hp = 60, dmg = 8, xp = 1, from = 1, til = 8, w = 3},
                {id = 'nkog', hp = 70, dmg = 9, xp = 2, from = 2, w = 2},
                {id = 'nmrr', hp = 100, dmg = 11, xp = 2, from = 3, w = 3},
                {id = 'nban', hp = 110, dmg = 12, xp = 2, from = 3, w = 3},
                {id = 'hrif', hp = 90, dmg = 12, xp = 2, from = 4, w = 2, extra = true},
                {id = 'ngnb', hp = 150, dmg = 14, xp = 3, from = 5, w = 2},
                {id = 'nrog', hp = 160, dmg = 15, xp = 3, from = 6, w = 3},
                {id = 'nenf', hp = 230, dmg = 18, xp = 3, from = 7, w = 2},
                {id = 'nass', hp = 200, dmg = 20, xp = 3, from = 8, w = 2}
            },
            bosses = {
                {t = 120, id = 'ngnv', name = 'Hogger', scale = 1.9, hp = 2600, dmg = 30},
                {t = 240, id = 'nmfs', name = 'Old Murk-Eye', scale = 2.0, hp = 4200, dmg = 38},
                {t = 360, id = 'nogm', name = 'Rhahk\'Zor', scale = 1.7, hp = 6500, dmg = 46},
                {t = 480, id = 'nenf', name = 'Mr. Smite', scale = 1.9, hp = 9500, dmg = 55}
            },
            final = {id = 'nbld', name = 'Edwin VanCleef', scale = 2.1, hp = 26000, dmg = 70}},

        {name = 'The Barrens', subtitle = 'Razormane Stampede', tier = 3, power = 1.4,
            music = {'Orc1', 'Orc2', 'Orc3', 'OrcX1'},
            art = 'UI\\Glues\\Loading\\Backgrounds\\Campaigns\\Barrens-TopLeft.blp',
            thumb = 'Scripts\\Survivor\\zone_barrens.tga',
            fog = {0.55, 0.40, 0.22, 1500, 6000}, time = 13.0,
            desc = 'The quilboar of Razorfen ride with Kolkar centaurs, Grimtotem tauren join the raid and harpies circle overhead looking for stragglers.',
            enemies = {
                {id = 'nrzs', hp = 55, dmg = 7, xp = 1, from = 0, til = 6, w = 4},
                {id = 'nhar', hp = 50, dmg = 7, xp = 1, from = 0, til = 7, w = 3},
                {id = 'ncer', hp = 70, dmg = 9, xp = 1, from = 1, til = 8, w = 3},
                {id = 'nrzb', hp = 110, dmg = 11, xp = 2, from = 2, w = 3},
                {id = 'ohun', hp = 80, dmg = 11, xp = 2, from = 2, w = 2, extra = true},
                {id = 'nhrr', hp = 90, dmg = 11, xp = 2, from = 3, w = 2},
                {id = 'ncea', hp = 100, dmg = 12, xp = 2, from = 3, w = 2},
                {id = 'ncen', hp = 160, dmg = 15, xp = 3, from = 5, w = 3},
                {id = 'nrzm', hp = 150, dmg = 15, xp = 3, from = 6, w = 2},
                {id = 'otau', hp = 280, dmg = 18, xp = 3, from = 6, w = 2, extra = true},
                {id = 'nhrw', hp = 170, dmg = 17, xp = 3, from = 7, w = 2},
                {id = 'ncim', hp = 260, dmg = 20, xp = 3, from = 8, w = 3}
            },
            bosses = {
                {t = 120, id = 'nrzg', name = 'Charlga Razorflank', scale = 1.8, hp = 2600, dmg = 30},
                {t = 240, id = 'nhrq', name = 'Sister Hatelash', scale = 1.9, hp = 4200, dmg = 38},
                {t = 360, id = 'ncks', name = 'Kolkar Stormseer', scale = 1.8, hp = 6500, dmg = 46},
                {t = 480, id = 'ncnk', name = 'Barak Kodobane', scale = 1.8, hp = 9500, dmg = 55}
            },
            final = {id = 'ncnk', name = 'Khan Hratha', scale = 2.4, hp = 26000, dmg = 70}},

        {name = 'Plaguelands', subtitle = 'The Scourge Rises', tier = 4, power = 1.9,
            music = {'Undead1', 'Undead2', 'Undead3', 'UndeadX1'},
            art = 'UI\\Glues\\Loading\\Backgrounds\\Campaigns\\LordaeronExpansion-TopLeft.blp',
            thumb = 'Scripts\\Survivor\\zone_plaguelands.tga',
            fog = {0.20, 0.30, 0.12, 800, 3600}, time = 0.0,
            desc = 'The dead walk the fields of Lordaeron. Ghouls lead the charge and abominations shamble behind.',
            enemies = {
                {id = 'nzom', hp = 60, dmg = 7, xp = 1, from = 0, til = 6, w = 4},
                {id = 'ugho', hp = 70, dmg = 8, xp = 1, from = 0, til = 8, w = 4},
                {id = 'uske', hp = 60, dmg = 8, xp = 1, from = 1, til = 8, w = 3},
                {id = 'ucry', hp = 120, dmg = 12, xp = 2, from = 2, w = 3},
                {id = 'ugar', hp = 90, dmg = 11, xp = 2, from = 3, w = 2},
                {id = 'uban', hp = 100, dmg = 12, xp = 2, from = 4, w = 2},
                {id = 'unec', hp = 110, dmg = 13, xp = 2, from = 4, w = 2},
                {id = 'umtw', hp = 140, dmg = 15, xp = 2, from = 5, w = 2, extra = true},
                {id = 'uabo', hp = 300, dmg = 19, xp = 3, from = 6, w = 3},
                {id = 'uobs', hp = 220, dmg = 17, xp = 3, from = 7, w = 1, extra = true},
                {id = 'nfgu', hp = 280, dmg = 21, xp = 3, from = 8, w = 2}
            },
            bosses = {
                {t = 120, id = 'uabo', name = 'Stitches', scale = 1.8, hp = 2600, dmg = 30},
                {t = 240, id = 'ucry', name = 'Anub\'Rekhan', scale = 2.0, hp = 4200, dmg = 38},
                {t = 360, id = 'unec', name = 'Noth the Plaguebringer', scale = 2.0, hp = 6500, dmg = 46},
                {t = 480, id = 'uabo', name = 'Patchwerk', scale = 2.4, hp = 9500, dmg = 55}
            },
            final = {id = 'ufro', name = 'Sapphiron', scale = 1.7, hp = 26000, dmg = 70}},

        {name = 'Felwood', subtitle = 'The Burning Legion', tier = 5, power = 2.5,
            music = {'Doom', 'Tension', 'DarkAgents', 'IllidansTheme'},
            art = 'UI\\Glues\\Loading\\Backgrounds\\Campaigns\\AshenvaleExpansion-TopLeft.blp',
            thumb = 'Scripts\\Survivor\\zone_felwood.tga',
            fog = {0.28, 0.12, 0.32, 900, 4000}, time = 21.0,
            desc = 'Fel fire burns the canopy. Corrupted druids roam the dying woods, and voidwalkers and infernals answer the call of the satyr hellcallers.',
            enemies = {
                {id = 'nsty', hp = 70, dmg = 8, xp = 1, from = 0, til = 6, w = 4},
                {id = 'nvdl', hp = 80, dmg = 9, xp = 1, from = 0, til = 8, w = 3},
                {id = 'nsts', hp = 110, dmg = 12, xp = 2, from = 2, w = 3},
                {id = 'edoc', hp = 150, dmg = 13, xp = 2, from = 2, w = 2, extra = true},
                {id = 'nvdw', hp = 160, dmg = 14, xp = 2, from = 3, w = 3},
                {id = 'nstl', hp = 170, dmg = 15, xp = 3, from = 4, w = 2},
                {id = 'nfgu', hp = 260, dmg = 19, xp = 3, from = 5, w = 3},
                {id = 'nfel', hp = 240, dmg = 19, xp = 3, from = 6, w = 2, extra = true},
                {id = 'nsth', hp = 240, dmg = 20, xp = 3, from = 7, w = 2},
                {id = 'ninf', hp = 420, dmg = 24, xp = 4, from = 8, w = 2}
            },
            bosses = {
                {t = 120, id = 'nvdg', name = 'Lord Banehollow', scale = 1.8, hp = 2600, dmg = 30},
                {t = 240, id = 'nbal', name = 'Doomguard Commander', scale = 1.6, hp = 4200, dmg = 38},
                {t = 360, id = 'nsth', name = 'Shadow Lord Xavian', scale = 2.0, hp = 6500, dmg = 46},
                {t = 480, id = 'ninf', name = 'Infernal Behemoth', scale = 1.6, hp = 9500, dmg = 55}
            },
            final = {id = 'Nplh', name = 'Mannoroth', scale = 1.8, hp = 26000, dmg = 70}},

        {name = 'Northrend', subtitle = 'The Frozen Throne', tier = 6, power = 3.3,
            music = {'LichKingTheme', 'ArthasTheme', 'SadMystery', 'UndeadX1'},
            art = 'UI\\Glues\\Loading\\Backgrounds\\Campaigns\\IcecrownExpansion-TopLeft.blp',
            thumb = 'Scripts\\Survivor\\zone_northrend.tga',
            fog = {0.55, 0.66, 0.82, 1000, 4600}, time = 0.0,
            desc = 'Ice trolls, Nerubians and the Scourge guard the road to Icecrown. The Lich King is waiting.',
            enemies = {
                {id = 'nitr', hp = 80, dmg = 9, xp = 1, from = 0, til = 7, w = 4},
                {id = 'ugho', hp = 80, dmg = 9, xp = 1, from = 0, til = 6, w = 3},
                {id = 'nnwa', hp = 120, dmg = 12, xp = 2, from = 1, w = 3},
                {id = 'nitp', hp = 110, dmg = 12, xp = 2, from = 2, w = 2},
                {id = 'nnwl', hp = 130, dmg = 13, xp = 2, from = 3, w = 2},
                {id = 'nits', hp = 200, dmg = 17, xp = 3, from = 4, w = 3},
                {id = 'nnwr', hp = 180, dmg = 17, xp = 3, from = 5, w = 2},
                {id = 'uabo', hp = 340, dmg = 21, xp = 3, from = 6, w = 2},
                {id = 'ubsp', hp = 320, dmg = 22, xp = 3, from = 7, w = 2, extra = true},
                {id = 'nnws', hp = 360, dmg = 24, xp = 4, from = 8, w = 2}
            },
            bosses = {
                {t = 120, id = 'nitw', name = 'Warlord Zol\'Maz', scale = 1.8, hp = 2600, dmg = 30},
                {t = 240, id = 'nnws', name = 'Krik\'thir the Gatewatcher', scale = 1.8, hp = 4200, dmg = 38},
                {t = 360, id = 'Udea', name = 'Baron Rivendare', scale = 1.6, hp = 6500, dmg = 46},
                {t = 480, id = 'ufro', name = 'Frost Wyrm', scale = 1.5, hp = 9500, dmg = 55}
            },
            final = {id = 'Ulic', name = 'Kel\'Thuzad', scale = 1.9, hp = 26000, dmg = 70}},

        -- Zones 7-12 came later: they keep these indices in saves and gear ids,
        -- and ZONE_ORDER below places them between the first six.
        {name = 'Tirisfal Glades', subtitle = 'The Scarlet Crusade', tier = 2, power = 1.2, density = 0.95,
            music = {'Comradeship', 'PursuitTheme', 'Human3', 'TragicConfrontation'},
            art = 'UI\\Glues\\Loading\\Backgrounds\\Campaigns\\Quelthalas-TopLeft.blp',
            thumb = 'Scripts\\Survivor\\zone_tirisfal.tga',
            fog = {0.40, 0.30, 0.20, 1100, 5000}, time = 17.0,
            desc = 'The Scarlet Crusade purges the glades. Militia and footmen hold the line while priests and sorceresses keep them fighting.',
            enemies = {
                {id = 'hmil', hp = 50, dmg = 7, xp = 1, from = 0, til = 6, w = 4},
                {id = 'hfoo', hp = 65, dmg = 8, xp = 1, from = 0, til = 8, w = 4},
                {id = 'hrif', hp = 55, dmg = 9, xp = 1, from = 1, til = 9, w = 3},
                {id = 'nchp', hp = 70, dmg = 9, xp = 2, from = 2, w = 2},
                {id = 'hmpr', hp = 60, dmg = 9, xp = 2, from = 2, w = 2},
                {id = 'hsor', hp = 60, dmg = 10, xp = 2, from = 3, w = 2},
                {id = 'hspt', hp = 140, dmg = 13, xp = 2, from = 4, w = 2},
                {id = 'hkni', hp = 200, dmg = 16, xp = 3, from = 5, w = 3},
                {id = 'hmtm', hp = 120, dmg = 15, xp = 3, from = 6, w = 2},
                {id = 'hgry', hp = 240, dmg = 18, xp = 3, from = 7, w = 2}
            },
            bosses = {
                {t = 120, id = 'hrif', name = 'Houndmaster Loksey', scale = 2.0, hp = 2600, dmg = 30},
                {t = 240, id = 'Hamg', name = 'Arcanist Doan', scale = 1.6, hp = 4200, dmg = 38},
                {t = 360, id = 'Hart', name = 'Herod the Scarlet Champion', scale = 1.6, hp = 6500, dmg = 46},
                {t = 480, id = 'hmpr', name = 'High Inquisitor Whitemane', scale = 2.2, hp = 9500, dmg = 55}
            },
            final = {id = 'Huth', name = 'Scarlet Commander Mograine', scale = 2.0, hp = 26000, dmg = 70}},

        {name = 'Stranglethorn Vale', subtitle = 'The Gurubashi Empire', tier = 3, power = 1.65,
            music = {'Orc2', 'NagaTheme', 'OrcX1', 'Tension'},
            art = 'UI\\Glues\\Loading\\Backgrounds\\Campaigns\\DrownedRuinsExpansion-TopLeft.blp',
            thumb = 'Scripts\\Survivor\\zone_stranglethorn.tga',
            fog = {0.18, 0.32, 0.18, 1000, 4600}, time = 15.0,
            desc = 'The Gurubashi trolls stir in their jungle temples. Headhunters and berserkers lead the charge, jungle stalkers hunt beside them and murlocs crawl up from the coast.',
            enemies = {
                {id = 'nftr', hp = 60, dmg = 8, xp = 1, from = 0, til = 6, w = 4},
                {id = 'nmrl', hp = 55, dmg = 7, xp = 1, from = 0, til = 6, w = 3},
                {id = 'ohun', hp = 65, dmg = 9, xp = 1, from = 1, til = 8, w = 3},
                {id = 'njg1', hp = 100, dmg = 11, xp = 2, from = 2, w = 3},
                {id = 'nfsp', hp = 80, dmg = 11, xp = 2, from = 3, w = 2},
                {id = 'otbk', hp = 140, dmg = 14, xp = 2, from = 4, w = 3},
                {id = 'odoc', hp = 110, dmg = 13, xp = 2, from = 4, w = 2},
                {id = 'nftb', hp = 160, dmg = 15, xp = 3, from = 5, w = 3},
                {id = 'otbr', hp = 150, dmg = 16, xp = 3, from = 6, w = 2},
                {id = 'njga', hp = 260, dmg = 20, xp = 3, from = 8, w = 2}
            },
            bosses = {
                {t = 120, id = 'nftk', name = 'Bloodlord Mandokir', scale = 1.8, hp = 2600, dmg = 30},
                {t = 240, id = 'otbr', name = 'High Priestess Jeklik', scale = 2.2, hp = 4200, dmg = 38},
                {t = 360, id = 'Orkn', name = 'Jin\'do the Hexxer', scale = 1.7, hp = 6500, dmg = 46},
                {t = 480, id = 'nhyd', name = 'Gahz\'ranka', scale = 1.6, hp = 9500, dmg = 55}
            },
            final = {id = 'nwgs', name = 'Hakkar the Soulflayer', scale = 2.8, hp = 26000, dmg = 70}},

        {name = 'Alterac Valley', subtitle = 'The Frostwolf Clan', tier = 4, power = 2.2,
            music = {'OrcTheme', 'Orc3', 'War2IntroMusic', 'Comradeship'},
            art = 'UI\\Glues\\Loading\\Backgrounds\\Campaigns\\Northrend-TopLeft.blp',
            thumb = 'Scripts\\Survivor\\zone_alterac.tga',
            fog = {0.62, 0.68, 0.78, 1100, 5000}, time = 10.0,
            desc = 'The Frostwolves defend their valley. Wolves and grunts storm through the snow, wind riders strike from the sky and the tauren break whatever is left.',
            enemies = {
                {id = 'nwwf', hp = 80, dmg = 9, xp = 1, from = 0, til = 6, w = 4},
                {id = 'ogru', hp = 100, dmg = 10, xp = 1, from = 0, til = 8, w = 4},
                {id = 'ohun', hp = 80, dmg = 10, xp = 1, from = 1, til = 8, w = 3},
                {id = 'orai', hp = 140, dmg = 13, xp = 2, from = 2, w = 3},
                {id = 'oshm', hp = 110, dmg = 12, xp = 2, from = 3, w = 2},
                {id = 'nwwg', hp = 150, dmg = 14, xp = 2, from = 3, w = 2},
                {id = 'owyv', hp = 170, dmg = 16, xp = 3, from = 4, w = 2},
                {id = 'otau', hp = 320, dmg = 20, xp = 3, from = 5, w = 3},
                {id = 'ocat', hp = 180, dmg = 18, xp = 3, from = 6, w = 2},
                {id = 'nwwd', hp = 300, dmg = 22, xp = 3, from = 8, w = 2}
            },
            bosses = {
                {t = 120, id = 'nwwd', name = 'Frostwolf Alpha', scale = 1.9, hp = 2600, dmg = 30},
                {t = 240, id = 'ogru', name = 'Captain Galvangar', scale = 2.0, hp = 4200, dmg = 38},
                {t = 360, id = 'nogl', name = 'Korrak the Bloodrager', scale = 1.8, hp = 6500, dmg = 46},
                {t = 480, id = 'Otch', name = 'Warmaster Laggrond', scale = 1.6, hp = 9500, dmg = 55}
            },
            final = {id = 'Odrt', name = 'Drek\'Thar', scale = 2.0, hp = 26000, dmg = 70}},

        {name = 'Dalaran', subtitle = 'The Violet Citadel', tier = 5, power = 2.7,
            music = {'BloodElfTheme', 'SadMystery', 'Human1', 'Comradeship'},
            art = 'UI\\Glues\\Loading\\Backgrounds\\Campaigns\\Dalaran-TopLeft.blp',
            thumb = 'Scripts\\Survivor\\zone_dalaran.tga',
            fog = {0.36, 0.24, 0.46, 1000, 4600}, time = 20.0,
            desc = 'The magi of Dalaran have closed their city. Rogue wizards, golems and summoned elementals guard the streets, and the blood elves answer only to their prince.',
            enemies = {
                {id = 'nwiz', hp = 70, dmg = 9, xp = 1, from = 0, til = 6, w = 4},
                {id = 'ngrk', hp = 110, dmg = 10, xp = 1, from = 0, til = 7, w = 3},
                {id = 'nwzr', hp = 100, dmg = 12, xp = 1, from = 1, til = 8, w = 3},
                {id = 'hsor', hp = 100, dmg = 12, xp = 2, from = 2, w = 2},
                {id = 'hspt', hp = 180, dmg = 15, xp = 2, from = 3, w = 3},
                {id = 'narg', hp = 220, dmg = 16, xp = 2, from = 3, w = 2},
                {id = 'nhym', hp = 140, dmg = 15, xp = 2, from = 4, w = 2},
                {id = 'nwzg', hp = 220, dmg = 18, xp = 3, from = 5, w = 2},
                {id = 'hdhw', hp = 200, dmg = 18, xp = 3, from = 6, w = 2},
                {id = 'hwt3', hp = 320, dmg = 21, xp = 3, from = 6, w = 2},
                {id = 'nggr', hp = 450, dmg = 24, xp = 4, from = 8, w = 2}
            },
            bosses = {
                {t = 120, id = 'nwzd', name = 'Archmage Arugal', scale = 1.7, hp = 2600, dmg = 30},
                {t = 240, id = 'nsgg', name = 'The Violet Construct', scale = 1.6, hp = 4200, dmg = 38},
                {t = 360, id = 'nbel', name = 'Grand Magister Rommath', scale = 1.8, hp = 6500, dmg = 46},
                {t = 480, id = 'Hant', name = 'Archmage Antonidas', scale = 1.7, hp = 9500, dmg = 55}
            },
            final = {id = 'Hkal', name = 'Prince Kael\'thas', scale = 1.9, hp = 26000, dmg = 70}},

        {name = 'Hellfire Peninsula', subtitle = 'The Fel Horde', tier = 5, power = 2.95,
            music = {'Doom', 'TragicConfrontation', 'OrcX1', 'Tension'},
            art = 'UI\\Glues\\Loading\\Backgrounds\\Campaigns\\OutlandExpansion-TopLeft.blp',
            thumb = 'Scripts\\Survivor\\zone_hellfire.tga',
            fog = {0.48, 0.20, 0.12, 1000, 4600}, time = 14.0,
            desc = 'The Fel Horde marches out of Hellfire Citadel. Chaos grunts and wolf riders lead, warlocks call their felhounds and infernals fall from the burning sky.',
            enemies = {
                {id = 'ncpn', hp = 90, dmg = 10, xp = 1, from = 0, til = 6, w = 4},
                {id = 'nchg', hp = 140, dmg = 12, xp = 1, from = 0, til = 8, w = 4},
                {id = 'npfl', hp = 120, dmg = 12, xp = 1, from = 1, til = 8, w = 3},
                {id = 'nchw', hp = 120, dmg = 13, xp = 2, from = 2, w = 3},
                {id = 'nchr', hp = 200, dmg = 16, xp = 2, from = 3, w = 3},
                {id = 'nfel', hp = 220, dmg = 18, xp = 3, from = 4, w = 2},
                {id = 'nckb', hp = 300, dmg = 19, xp = 3, from = 5, w = 2},
                {id = 'npfm', hp = 320, dmg = 21, xp = 3, from = 6, w = 2},
                {id = 'nba2', hp = 380, dmg = 24, xp = 4, from = 7, w = 2},
                {id = 'ninf', hp = 460, dmg = 26, xp = 4, from = 8, w = 2}
            },
            bosses = {
                {t = 120, id = 'nchg', name = 'Watchkeeper Gargolmar', scale = 2.0, hp = 2600, dmg = 30},
                {t = 240, id = 'Nbbc', name = 'Kargath Bladefist', scale = 1.6, hp = 4200, dmg = 38},
                {t = 360, id = 'nbdk', name = 'Nazan', scale = 1.8, hp = 6500, dmg = 46},
                {t = 480, id = 'nba2', name = 'Vazruden the Herald', scale = 1.6, hp = 9500, dmg = 55}
            },
            final = {id = 'Nmag', name = 'Magtheridon', scale = 1.8, hp = 26000, dmg = 70}},

        {name = 'The Black Temple', subtitle = 'Illidan\'s Army', tier = 6, power = 3.1,
            music = {'IllidansTheme', 'NagaTheme', 'BloodElfTheme', 'DarkAgents'},
            art = 'UI\\Glues\\Loading\\Backgrounds\\Campaigns\\OutlandExpansion-TopLeft.blp',
            thumb = 'Scripts\\Survivor\\zone_blacktemple.tga',
            fog = {0.16, 0.26, 0.14, 900, 4200}, time = 0.0,
            desc = 'Illidan rules from the Black Temple. Naga rise from the moat, blood elves hold the halls and the Illidari are ready to die for their master.',
            enemies = {
                {id = 'nmpe', hp = 90, dmg = 10, xp = 1, from = 0, til = 6, w = 4},
                {id = 'nnmg', hp = 120, dmg = 12, xp = 1, from = 0, til = 8, w = 4},
                {id = 'nmyr', hp = 220, dmg = 15, xp = 2, from = 1, w = 3},
                {id = 'nnsw', hp = 130, dmg = 14, xp = 2, from = 2, w = 2},
                {id = 'nsnp', hp = 180, dmg = 16, xp = 2, from = 3, w = 2},
                {id = 'hspt', hp = 220, dmg = 17, xp = 2, from = 3, w = 2},
                {id = 'nwgs', hp = 200, dmg = 17, xp = 3, from = 4, w = 2},
                {id = 'nbel', hp = 280, dmg = 20, xp = 3, from = 5, w = 2},
                {id = 'nhyc', hp = 360, dmg = 22, xp = 3, from = 6, w = 2},
                {id = 'nnrg', hp = 480, dmg = 26, xp = 4, from = 8, w = 3}
            },
            bosses = {
                {t = 120, id = 'nnrg', name = 'High Warlord Naj\'entus', scale = 1.8, hp = 2600, dmg = 30},
                {t = 240, id = 'ninf', name = 'Supremus', scale = 1.7, hp = 4200, dmg = 38},
                {t = 360, id = 'Naka', name = 'Shade of Akama', scale = 1.8, hp = 6500, dmg = 46},
                {t = 480, id = 'Hvsh', name = 'Lady Vashj', scale = 1.8, hp = 9500, dmg = 55}
            },
            final = {id = 'Eevi', name = 'Illidan Stormrage', scale = 1.7, hp = 26000, dmg = 70}}
    }

    -- The order zones are played and unlocked in (ZONES indices). Saves keep
    -- a zone's index; Profile.data.unlocked counts open places in this order.
    local ZONE_ORDER = {1, 2, 7, 3, 8, 4, 9, 5, 10, 11, 12, 6}
    for rank, zi in ipairs(ZONE_ORDER) do
        ZONES[zi].rank = rank
    end

    for _, zone in ipairs(ZONES) do
        -- index: the step on the zone's health ladder. Units marked extra (added
        -- to a tuned roster later) share the step before them.
        local step = 0
        for _, e in ipairs(zone.enemies) do
            if not e.extra or step == 0 then
                step = step + 1
            end
            e.index = step
        end
        zone.final.t = CFG.RUN_LENGTH
    end

    ---------------------------------------------------------------------------
    -- Items. Every boss drops one Warcraft III item. Its item level comes from
    -- the zone tier and the difficulty, and gold upgrades it along a six-step
    -- track. Heroes carry six items, the classic inventory, chosen in the
    -- armory; every hero carries the same six.
    ---------------------------------------------------------------------------
    local INVENTORY_SIZE = 6

    -- What an item stat gives at item level 100 and weight 1 (higher levels
    -- scale it up). Attributes come in whole points.
    local ITEM_STATS = {
        all = {per = 2, flat = true, whole = true, desc = '+{v} all attributes',
            apply = function(s, x) s.str = s.str + x; s.agi = s.agi + x; s.int = s.int + x end},
        str = {per = 3, flat = true, whole = true, desc = '+{v} Strength', apply = function(s, x) s.str = s.str + x end},
        agi = {per = 3, flat = true, whole = true, desc = '+{v} Agility', apply = function(s, x) s.agi = s.agi + x end},
        int = {per = 3, flat = true, whole = true, desc = '+{v} Intellect', apply = function(s, x) s.int = s.int + x end},
        sta = {per = 2, flat = true, whole = true, desc = '+{v} Stamina', apply = function(s, x) s.sta = s.sta + x end},
        damage = {per = 0.05, desc = '+{v}\037 damage', apply = function(s, x) s.damage = s.damage + x end},
        armor = {per = 1.5, flat = true, desc = '+{v} armor', apply = function(s, x) s.armor = s.armor + x end},
        move = {per = 0.03, desc = '+{v}\037 movement speed', apply = function(s, x) s.move = s.move + x end},
        dodge = {per = 0.03, desc = '+{v}\037 dodge', apply = function(s, x) s.dodge = s.dodge + x end},
        regen = {per = 0.5, flat = true, desc = '+{v} health per second', apply = function(s, x) s.regen = s.regen + x end},
        attackSpeed = {per = 0.04, desc = '+{v}\037 attack speed', apply = function(s, x) s.attackSpeed = s.attackSpeed + x end},
        crit = {per = 0.02, desc = '+{v}\037 critical strike chance', apply = function(s, x) s.crit = s.crit + x end},
        cdr = {per = 0.025, desc = '+{v}\037 spell haste', apply = function(s, x) s.cdr = s.cdr + x end},
        manaRegen = {per = 0.6, flat = true, desc = '+{v} mana per second', apply = function(s, x) s.manaRegen = s.manaRegen + x end},
        pickup = {per = 0.1, desc = '+{v}\037 pickup range', apply = function(s, x) s.pickup = s.pickup + x end},
        xp = {per = 0.05, desc = '+{v}\037 experience', apply = function(s, x) s.xp = s.xp + x end},
        area = {per = 0.03, desc = '+{v}\037 area of effect', apply = function(s, x) s.area = s.area + x end},
        lifesteal = {per = 0.01, desc = '+{v}\037 life steal', apply = function(s, x) s.lifesteal = s.lifesteal + x end},
        dr = {per = 0.02, desc = '+{v}\037 damage reduction', apply = function(s, x) s.dr = s.dr + x end},
        gold = {per = 0.08, desc = '+{v}\037 gold', apply = function(s, x) s.gold = s.gold + x end}
    }
    -- Tooltip order, attributes first.
    local ITEM_STAT_ORDER = {'all', 'str', 'agi', 'int', 'sta', 'armor', 'damage', 'attackSpeed', 'crit', 'dodge', 'dr',
        'regen', 'lifesteal', 'manaRegen', 'cdr', 'area', 'move', 'pickup', 'xp', 'gold'}

    -- Signature effects ("Equip:" lines), at item level 100; higher levels
    -- scale them up to max. One without per does not scale. name is shown in
    -- the armory and on the damage meter.
    local ITEM_EFFECTS = {
        frostOrb = {name = 'Frost Orb', per = 0.2, max = 0.5, desc = 'Attacks slow the target by {v}\037 for 2 seconds.',
            apply = function(s, x) s.attackSlow = math.max(s.attackSlow, x) end},
        fireOrb = {name = 'Fire Orb', per = 0.2, max = 1, desc = 'Attacks burst into flames: {v}\037 of their damage around the target.',
            apply = function(s, x) s.fireSplash = s.fireSplash + x end},
        darkOrb = {name = 'Dark Minion', per = 0.03, max = 0.12, desc = 'Kills have a {v}\037 chance to raise a skeleton for 20 seconds.',
            apply = function(s, x) s.darkMinion = s.darkMinion + x end},
        corruptOrb = {name = 'Corruption', per = 0.06, max = 0.3, desc = 'Attacks corrupt the target: it takes {v}\037 more damage for 3 seconds.',
            apply = function(s, x) s.corrupt = s.corrupt + x end},
        vampiric = {name = 'Vampiric Attack', per = 0.08, max = 0.35, desc = 'Attacks heal you for {v}\037 of their damage.',
            apply = function(s, x) s.vampiric = s.vampiric + x end},
        ankh = {name = 'Reincarnation', desc = 'Return to life once per run with half health.',
            apply = function(s) s.lives = s.lives + 1 end},
        escape = {name = 'Escape', desc = 'A hit that would drop you under 30\037 health misses and you blink away. Every 30 seconds.',
            apply = function(s) s.escape = 1 end},
        sanctuary = {name = 'Sanctuary', per = 0.15, max = 0.6, desc = 'Under 30\037 health, heal {v}\037 of your maximum health. Every 60 seconds.',
            apply = function(s, x) s.sanctuary = s.sanctuary + x end},
        cloak = {name = 'Immolation', per = 0.25, max = 1.5, desc = 'Burns enemies near you for {v}\037 of your attack damage every second.',
            apply = function(s, x) s.flames = s.flames + x end},
        drums = {name = 'War Drums', per = 0.15, max = 0.75, desc = 'Your summons deal {v}\037 more damage.',
            apply = function(s, x) s.summonDamage = s.summonDamage + x end},
        mastery = {name = 'Spell Mastery', per = 0.08, max = 0.5, desc = 'Spells cost {v}\037 less mana.',
            apply = function(s, x) s.manaCost = s.manaCost + x end},
        thirst = {name = 'Battle Thirst', per = 0.12, max = 0.8, desc = 'Kills raise your attack speed by {v}\037 for 3 seconds.',
            apply = function(s, x) s.thirst = s.thirst + x end},
        souls = {name = 'Soul Harvest', per = 4, flat = true, whole = true, desc = 'Every 25 kills give 1 Intellect for the rest of the run, up to {v}.',
            apply = function(s, x) s.souls = s.souls + x end},
        immunity = {name = 'Spell Immunity', desc = 'Ignores one heavy hit (a tenth of your health or more) every 15 seconds.',
            apply = function(s) s.spellWard = 1 end},
        frostguard = {name = 'Frost Armor', per = 0.15, max = 0.6, desc = 'Enemies that hit you are slowed by {v}\037 for 3 seconds.',
            apply = function(s, x) s.frostguard = math.max(s.frostguard, x) end},
        searing = {name = 'Searing', per = 0.2, max = 1.5, desc = 'Attacks burn the target for {v}\037 of their damage over 3 seconds.',
            apply = function(s, x) s.searing = s.searing + x end},
        spikes = {name = 'Spiked Shield', per = 12, flat = true, desc = 'Enemies that hit you take {v} damage.',
            apply = function(s, x) s.thorns = s.thorns + x end},
        purge = {name = 'Purge', per = 0.04, max = 0.25, desc = 'Attacks have a {v}\037 chance to stun the target for 1 second.',
            apply = function(s, x) s.bash = s.bash + x end}
    }

    -- Per zone, the items of its four bosses and its final boss, in order:
    -- rawcode (its icon comes from the game data), name, stats (weight 1 is
    -- a full share, after Warcraft III's own item) and an effect.
    local ZONE_ITEMS = {
        {{'ratc', 'Claws of Attack', {damage = 1, str = 0.5}}, {'rde1', 'Ring of Protection', {armor = 1, sta = 0.5}},
            {'bspd', 'Boots of Speed', {move = 1, agi = 0.5}}, {'prvt', 'Periapt of Vitality', {sta = 1.5, regen = 0.5}},
            {'rlif', 'Ring of Regeneration', {regen = 1, str = 0.5}}},
        {{'gcel', 'Gloves of Haste', {attackSpeed = 1, agi = 0.5}}, {'hcun', 'Hood of Cunning', {agi = 1, int = 1}},
            {'rwiz', 'Sobi Mask', {manaRegen = 1, int = 0.5}}, {'mcou', 'Medallion of Courage', {str = 1, int = 1}},
            {'cnob', 'Circlet of Nobility', {all = 1, xp = 0.5}}},
        {{'clfm', 'Cloak of Flames', {sta = 1, armor = 0.5}, 'cloak'}, {'modt', 'Mask of Death', {str = 0.5, sta = 0.5}, 'vampiric'},
            {'brac', 'Runed Bracers', {dr = 1, sta = 0.5, int = 0.5}}, {'bgst', 'Belt of Giant Strength', {str = 2, sta = 0.5}},
            {'lgdh', 'Legion Doom-Horn', {move = 1, attackSpeed = 0.5, str = 0.5}}},
        {{'ciri', 'Robe of the Magi', {int = 2, manaRegen = 0.5}}, {'ofro', 'Orb of Frost', {damage = 0.5, int = 0.5}, 'frostOrb'},
            {'ward', 'Warsong Battle Drums', {damage = 0.5, str = 0.5}, 'drums'},
            {'ajen', 'Ancient Janggo of Endurance', {attackSpeed = 1, move = 0.5, sta = 0.5}},
            {'evtl', 'Talisman of Evasion', {dodge = 1, agi = 0.5}}},
        {{'ofir', 'Orb of Fire', {damage = 0.5, str = 0.5}, 'fireOrb'}, {'odef', 'Orb of Darkness', {damage = 0.5, int = 0.5}, 'darkOrb'},
            {'kpin', 'Khadgar\'s Pipe of Insight', {manaRegen = 1.5, int = 0.5}}, {'hval', 'Helm of Valor', {str = 1, agi = 1, armor = 0.5}},
            {'rhth', 'Khadgar\'s Gem of Health', {sta = 2, regen = 0.5}}},
        {{'frgd', 'Frostguard', {armor = 1, str = 0.5}, 'frostguard'}, {'ckng', 'Crown of Kings', {all = 2.5}},
            {'desc', 'Kelen\'s Dagger of Escape', {agi = 1, move = 0.5}, 'escape'},
            {'ssan', 'Staff of Sanctuary', {int = 1, regen = 0.5}, 'sanctuary'},
            {'ankh', 'Ankh of Reincarnation', {sta = 1, regen = 0.5}, 'ankh'}},
        {{'lnrn', 'Lion\'s Ring', {crit = 1, str = 0.5, armor = 0.5}}, {'schl', 'Scepter of Healing', {regen = 1.5, int = 0.5}},
            {'shhn', 'Shield of Honor', {armor = 1, sta = 0.5, damage = 0.5}}, {'horl', 'Sacred Relic', {xp = 1, all = 0.5}},
            {'lhst', 'The Lion Horn of Stormwind', {armor = 1, dr = 0.5, sta = 0.5}}},
        {{'shcw', 'Shaman Claws', {damage = 1, agi = 0.5}, 'purge'}, {'shtm', 'Shamanic Totem', {int = 1, regen = 0.5, manaRegen = 0.5}},
            {'vddl', 'Voodoo Doll', {lifesteal = 1, int = 0.5}}, {'rots', 'Scepter of the Sea', {area = 1, int = 0.5}},
            {'axas', 'Ancestral Staff', {cdr = 1, int = 0.5, sta = 0.5}}},
        {{'fwss', 'Frost Wyrm Skull Shield', {armor = 1, dr = 0.5, sta = 0.5}}, {'stwa', 'Sturdy War Axe', {damage = 1, str = 1}},
            {'klmm', 'Killmaim', {crit = 1, str = 0.5}, 'vampiric'}, {'srtl', 'Serathil', {attackSpeed = 1, agi = 1}},
            {'dtsb', 'Drek\'Thar\'s Spellbook', {cdr = 1, int = 1}}},
        {{'crys', 'Crystal Ball', {pickup = 1, int = 0.5, xp = 0.5}}, {'arsh', 'Arcanite Shield', {armor = 1.5, sta = 0.5}},
            {'mnsf', 'Mindstaff', {int = 1, manaRegen = 0.5, area = 0.5}}, {'ram4', 'Ring of the Archmagi', {all = 1, manaRegen = 0.5}},
            {'gvsm', 'Gloves of Spell Mastery', {cdr = 0.5, int = 0.5}, 'mastery'}},
        {{'srbd', 'Searing Blade', {damage = 1, str = 0.5}, 'searing'},
            {'frhg', 'Firehand Gauntlets', {attackSpeed = 1, agi = 0.5, armor = 0.5}},
            {'hbth', 'Helm of Battlethirst', {str = 1, sta = 0.5}, 'thirst'},
            {'shdt', 'Shield of the Deathlord', {armor = 1, dr = 0.5, sta = 1}},
            {'gldo', 'Orb of Kil\'jaeden', {damage = 0.5, area = 0.5}, 'fireOrb'}},
        {{'sksh', 'Skull Shield', {armor = 1, sta = 1}, 'spikes'}, {'grsl', 'Grimoire of Souls', {int = 1, lifesteal = 0.5}, 'souls'},
            {'nspi', 'Necklace of Spell Immunity', {dr = 0.5, int = 0.5}, 'immunity'},
            {'ocor', 'Orb of Corruption', {damage = 0.5, agi = 0.5}, 'corruptOrb'},
            {'crdt', 'Crown of the Deathlord', {all = 1.5, gold = 1}}}
    }
    local GEAR_UPGRADES = 6     -- steps on the upgrade track
    local GEAR_STEP_ILVL = 3    -- item levels per step

    local GEAR = {}
    for zi, zone in ipairs(ZONES) do
        local bosses = {zone.bosses[1], zone.bosses[2], zone.bosses[3], zone.bosses[4], zone.final}
        for bi, boss in ipairs(bosses) do
            local entry = ZONE_ITEMS[zi][bi]
            local stats = {}
            for _, key in ipairs(ITEM_STAT_ORDER) do
                if entry[3][key] then
                    stats[#stats + 1] = {key = key, stat = ITEM_STATS[key], w = entry[3][key]}
                end
            end
            local item = {id = 'z' .. zi .. 'b' .. bi, index = #GEAR + 1, zone = zi, boss = boss, code = entry[1],
                name = entry[2], stats = stats, effect = ITEM_EFFECTS[entry[4]], baseIlvl = 100 + 10 * (zone.tier - 1)}
            boss.item = item
            GEAR[#GEAR + 1] = item
        end
    end

    -- Stat multiplier for an item level: 100 is the base, every 40 adds 100 percent.
    local function gearScale(ilvl)
        return 1 + (ilvl - 100) / 40
    end

    -- One stat or effect of an item at an item level (b: an ITEM_STATS or
    -- ITEM_EFFECTS entry, w: its weight): whole points for attributes, never
    -- past an effect's cap.
    local function gearValue(b, w, ilvl)
        if b.per == nil then
            return 0
        end
        local x = b.per * w * gearScale(ilvl)
        if b.whole then
            x = math.floor(x + 0.5)
        end
        if b.max then
            x = math.min(x, b.max)
        end
        return x
    end

    local function gearLevel(p, item)
        local base = p.gear[item.id]
        if base == nil then
            return nil
        end
        return base + GEAR_STEP_ILVL * (p.upg[item.id] or 0)
    end

    -- The carried items, by inventory slot 1..6 (p.inv: slot -> GEAR index).
    local function gearEquipped(p)
        local worn = {}
        for slot = 1, INVENTORY_SIZE do
            local item = GEAR[p.inv[tostring(slot)] or 0]
            if item and p.gear[item.id] then
                worn[slot] = item
            end
        end
        return worn
    end

    local function gearSlotOf(p, item)
        for slot, worn in pairs(gearEquipped(p)) do
            if worn == item then
                return slot
            end
        end
        return nil
    end

    -- Average over the six slots; an empty slot counts as zero.
    local function gearAverage(p)
        local total = 0
        for _, item in pairs(gearEquipped(p)) do
            total = total + gearLevel(p, item)
        end
        return math.floor(total / INVENTORY_SIZE)
    end

    local function gearUpgradeCost(p, item)
        local step = (p.upg[item.id] or 0) + 1
        return math.floor(35 * step * (1 + 0.5 * (ZONES[item.zone].tier - 1)) + 0.5)
    end

    -- Item quality colour by item level.
    local function gearHex(ilvl)
        if ilvl >= 170 then
            return 'ff8000'
        elseif ilvl >= 145 then
            return 'a335ee'
        elseif ilvl >= 125 then
            return '0070dd'
        elseif ilvl >= 110 then
            return '1eff00'
        end
        return 'e6e6e6'
    end

    -- Mythic+ rating: 100 plus 15 per level of each zone's best timed keystone.
    local function keystoneRating(p)
        local rating = 0
        for zi = 1, #ZONES do
            local best = p.keyBest[tostring(zi)] or 0
            if best > 0 then
                rating = rating + 100 + 15 * best
            end
        end
        return rating
    end

    local function maxValue(map)
        local best = 0
        for _, value in pairs(map) do
            best = math.max(best, value)
        end
        return best
    end

    ---------------------------------------------------------------------------
    -- Meta progression
    ---------------------------------------------------------------------------
    -- Talents are bought with gold earned in runs. They apply to every hero.
    -- The five base stats are open from the start; every other talent opens
    -- with the achievement named in unlock (Profile.talentOpen).
    local TALENTS = {
        {key = 'strength', name = 'Strength', code = 'rst1', icon = 'BTNGauntletsOfOgrePower', per = 2, flat = true, max = 5,
            desc = '+{v} Strength', apply = function(s, x) s.str = s.str + x end},
        {key = 'agility', name = 'Agility', code = 'hcun', icon = 'BTNHoodOfCunning', per = 2, flat = true, max = 5,
            desc = '+{v} Agility', apply = function(s, x) s.agi = s.agi + x end},
        {key = 'intellect', name = 'Intellect', code = 'ciri', icon = 'BTNRobeOfTheMagi', per = 2, flat = true, max = 5,
            desc = '+{v} Intellect', apply = function(s, x) s.int = s.int + x end},
        {key = 'stamina', name = 'Stamina', code = 'prvt', icon = 'BTNPeriapt', per = 2, flat = true, max = 5,
            desc = '+{v} Stamina', apply = function(s, x) s.sta = s.sta + x end},
        {key = 'armor', name = 'Armor', code = 'rde1', icon = 'BTNRingJadeFalcon', per = 1, flat = true, max = 5,
            desc = '+{v} armor', apply = function(s, x) s.armor = s.armor + x end},
        {key = 'swiftness', name = 'Swiftness', code = 'bspd', icon = 'BTNBootsOfSpeed', per = 0.03, max = 5, unlock = 'survivor',
            desc = '+{v}\037 movement speed', apply = function(s, x) s.move = s.move + x end},
        {key = 'precision', name = 'Precision', code = 'AOcr', icon = 'BTNCriticalStrike', per = 0.02, max = 5, unlock = 'slayer',
            desc = '+{v}\037 critical strike', apply = function(s, x) s.crit = s.crit + x end},
        {key = 'haste', name = 'Haste', code = 'Ablo', icon = 'BTNBloodLust', per = 0.03, max = 5, unlock = 'ascendant',
            desc = 'Spells recharge {v}\037 faster', apply = function(s, x) s.cdr = s.cdr + x end},
        {key = 'clarity', name = 'Clarity', code = 'rwiz', icon = 'BTNSobiMask', per = 0.3, flat = true, max = 5, unlock = 'veteran',
            desc = '+{v} mana per second', apply = function(s, x) s.manaRegen = s.manaRegen + x end},
        {key = 'regeneration', name = 'Regeneration', code = 'rlif', icon = 'BTNRingGreen', per = 0.3, flat = true, max = 5,
            unlock = 'boss_hunter', desc = '+{v} health per second', apply = function(s, x) s.regen = s.regen + x end},
        {key = 'wisdom', name = 'Wisdom', code = 'tkno', icon = 'BTNTome', per = 0.06, max = 5, unlock = 'scholar',
            desc = '+{v}\037 experience', apply = function(s, x) s.xp = s.xp + x end},
        {key = 'magnetism', name = 'Magnetism', code = 'mcou', icon = 'BTNMedalionOfCourage', per = 0.15, max = 5, unlock = 'zone1',
            desc = '+{v}\037 pickup range', apply = function(s, x) s.pickup = s.pickup + x end},
        {key = 'greed', name = 'Greed', code = 'pghe', icon = 'BTNChestOfGold', per = 0.10, max = 5, unlock = 'hoarder',
            desc = '+{v}\037 gold', apply = function(s, x) s.gold = s.gold + x end},
        {key = 'siphon', name = 'Siphon Life', code = 'AUav', icon = 'BTNVampiricAura', per = 0.01, max = 5, unlock = 'heroic',
            desc = 'Attacks and spells heal for {v}\037 of their damage',
            apply = function(s, x) s.lifesteal = s.lifesteal + x end}
    }
    local TALENT_BY_KEY = {}
    for _, talent in ipairs(TALENTS) do
        TALENT_BY_KEY[talent.key] = talent
    end
    local function talentCost(rank)
        return math.floor(60 * rank ^ 1.6 + 0.5)
    end

    -- Perks are bought with achievement points.
    local PERKS = {
        {key = 'rerolls', name = 'Second Thoughts', code = 'AOre', icon = 'BTNReincarnation', costs = {10, 15, 20},
            desc = '+1 free reroll every run per rank.'},
        {key = 'banish', name = 'Banish', code = 'AHbn', icon = 'BTNBanish', costs = {15, 20, 25},
            desc = '+1 banish every run per rank. A banished card never comes back that run.'},
        {key = 'skip', name = 'Skip', code = 'pghe', icon = 'BTNChestOfGold', costs = {10},
            desc = 'Pass on any hand and take gold instead.'},
        {key = 'opening', name = 'Opening Hand', code = 'tkno', icon = 'BTNTome', costs = {20},
            desc = 'Your first level-up of every run deals four cards.'},
        {key = 'keen', name = 'Keen Eye', code = 'AEst', icon = 'BTNScout', costs = {15, 25},
            desc = 'Bosses are 10\037 more likely to drop gear per rank.'},
        {key = 'lucky', name = 'Lucky Star', code = 'cnob', icon = 'BTNCirclet', costs = {15, 25, 35},
            desc = 'Rarer cards show up more often per rank.'},
        {key = 'wide', name = 'Wide Hand', code = 'AEbl', icon = 'BTNBlink', costs = {60},
            desc = 'Every hand deals four cards.'},
        {key = 'secondwind', name = 'Second Wind', code = 'AHre', icon = 'BTNResurrection', costs = {40},
            desc = 'Return to life once per run at half health.'},
        {key = 'companion', name = 'Wisp Companion', code = 'ewsp', icon = 'BTNWisp', costs = {25, 35, 45},
            desc = 'A wisp fetches experience gems and gold for you. Faster and wider-ranging per rank.'}
    }
    local PERK_BY_KEY = {}
    for _, perk in ipairs(PERKS) do
        PERK_BY_KEY[perk.key] = perk
    end

    -- Achievements: progress(profile) returns current, goal.
    local ACHIEVEMENTS = {}
    local function achievement(key, name, desc, code, icon, points, progress)
        ACHIEVEMENTS[#ACHIEVEMENTS + 1] = {key = key, name = name, desc = desc, code = code, icon = icon,
            points = points, progress = progress}
    end
    local function countKeys(map)
        local n = 0
        for _ in pairs(map) do
            n = n + 1
        end
        return n
    end
    achievement('first_blood', 'First Blood', 'Slay your first enemy.', 'ratc', 'BTNClawsOfAttack', 5,
        function(p) return p.kills, 1 end)
    achievement('boss_slain', 'Boss Slain', 'Slay a boss.', 'AHtb', 'BTNStormBolt', 5,
        function(p) return p.bosses, 1 end)
    achievement('hold_out', 'Hold Out', 'Survive 5:00 in a run.', 'AHds', 'BTNDivineIntervention', 5,
        function(p) return maxValue(p.heroTime), 300 end)
    achievement('slayer', 'Slayer', 'Slay 1,000 enemies.', 'AOcr', 'BTNCriticalStrike', 10,
        function(p) return p.kills, 1000 end)
    achievement('exterminator', 'Exterminator', 'Slay 10,000 enemies.', 'AOww', 'BTNWhirlwind', 20,
        function(p) return p.kills, 10000 end)
    achievement('annihilator', 'Annihilator', 'Slay 50,000 enemies.', 'AUdd', 'BTNDeathAndDecay', 40,
        function(p) return p.kills, 50000 end)
    achievement('survivor', 'Survivor', 'Win a run.', 'AHds', 'BTNDivineIntervention', 10,
        function(p) return p.wins, 1 end)
    for rank, zi in ipairs(ZONE_ORDER) do
        local zone = ZONES[zi]
        achievement('zone' .. zi, zone.name, 'Defeat ' .. zone.final.name .. ' in ' .. zone.name .. '.', 'AHmt', 'BTNMassTeleport',
            5 + rank * 5, function(p) return p.zoneWins[tostring(zi)] or 0, 1 end)
    end
    achievement('boss_hunter', 'Boss Hunter', 'Slay 25 bosses.', 'AHtb', 'BTNStormBolt', 15,
        function(p) return p.bosses, 25 end)
    achievement('giant_slayer', 'Giant Slayer', 'Slay 100 bosses.', 'AHav', 'BTNAvatar', 30,
        function(p) return p.bosses, 100 end)
    achievement('collector', 'Collector', 'Loot 10 pieces of gear.', 'hval', 'BTNHelmOfValor', 15,
        function(p) return countKeys(p.gear), 10 end)
    achievement('curator', 'Curator', 'Loot every piece of gear.', 'Rhme', 'BTNSteelMelee', 50,
        function(p) return countKeys(p.gear), #GEAR end)
    achievement('artisan', 'Artisan', 'Upgrade a piece of gear to the end of its track.', 'brac', 'BTNRunedBracers', 15,
        function(p) return maxValue(p.upg), GEAR_UPGRADES end)
    achievement('well_geared', 'Well Geared', 'Reach an average equipped item level of 130.', 'ciri', 'BTNRobeOfTheMagi', 25,
        function(p) return gearAverage(p), 130 end)
    achievement('scholar', 'Scholar', 'Discover 40 cards in the codex.', 'tkno', 'BTNTome', 15,
        function(p) return countKeys(p.codex), 40 end)
    achievement('loremaster', 'Loremaster', 'Discover 100 cards in the codex.', 'AEst', 'BTNScout', 30,
        function(p) return countKeys(p.codex), 100 end)
    achievement('champion', 'Champion of Azeroth', 'Win with 5 different heroes.', 'AHad', 'BTNDevotion', 30,
        function(p) return countKeys(p.heroWins), 5 end)
    for fi, faction in ipairs(FACTIONS) do
        achievement('faction' .. fi, 'For the ' .. faction.key .. '!', 'Win a run with a ' .. faction.key .. ' hero.',
            'AOae', 'BTNCommand', 10, function(p) return p.factionWins[tostring(fi)] or 0, 1 end)
    end
    achievement('overtime', 'Overtime', 'Reach 15:00 in endless mode.', 'AOww', 'BTNWhirlwind', 15,
        function(p) return maxValue(p.endless), 900 end)
    achievement('unending', 'Unending', 'Reach 20:00 in endless mode.', 'AHad', 'BTNDevotion', 25,
        function(p) return maxValue(p.endless), 1200 end)
    achievement('deathless_hour', 'Deathless', 'Reach 30:00 in endless mode.', 'AHds', 'BTNDivineIntervention', 40,
        function(p) return maxValue(p.endless), 1800 end)
    achievement('ascendant', 'Ascendant', 'Reach level 25 in a single run.', 'AHab', 'BTNBrilliance', 15,
        function(p) return p.bestLevel, 25 end)
    achievement('veteran', 'Veteran', 'Play 25 runs.', 'AOsh', 'BTNShockWave', 10,
        function(p) return p.runs, 25 end)
    achievement('hoarder', 'Hoarder', 'Earn 5,000 gold in total.', 'pghe', 'BTNChestOfGold', 15,
        function(p) return p.goldTotal, 5000 end)
    achievement('heroic', 'Heroic', 'Win a run on Heroic difficulty.', 'AOvd', 'BTNBigBadVoodooSpell', 20,
        function(p) return maxValue(p.zoneDiff) >= 2 and 1 or 0, 1 end)
    achievement('mythic', 'Mythic', 'Win a run on Mythic difficulty.', 'AUin', 'BTNInfernal', 30,
        function(p) return maxValue(p.zoneDiff) >= 3 and 1 or 0, 1 end)
    achievement('keystone_initiate', 'Keystone Initiate', 'Time a Mythic+ keystone.', 'AHmt', 'BTNMassTeleport', 20,
        function(p) return maxValue(p.keyBest) >= 2 and 1 or 0, 1 end)
    achievement('keystone_challenger', 'Keystone Challenger', 'Time a +10 keystone.', 'AHav', 'BTNAvatar', 35,
        function(p) return maxValue(p.keyBest), 10 end)
    achievement('keystone_master', 'Keystone Master', 'Time a +15 keystone.', 'AUin', 'BTNInfernal', 50,
        function(p) return maxValue(p.keyBest), 15 end)
    achievement('keystone_hero', 'Keystone Hero', 'Reach a Mythic+ rating of 1,500.', 'AOvd', 'BTNBigBadVoodooSpell', 60,
        function(p) return keystoneRating(p), 1500 end)

    -- Heroes: the first of each faction is open from the start, the others
    -- join in a chain, each step harder: slay a boss with the first (they
    -- come at 2:00 and 4:00), survive 5:00 with the second, win a run with
    -- the faction. Tavern heroes join one per zone cleared, in play order.
    -- hero.unlock is the achievement that opens it.
    for fi, faction in ipairs(FACTIONS) do
        local list = {}
        for _, hero in ipairs(HEROES) do
            if hero.faction == faction.key then
                list[#list + 1] = hero
            end
        end
        if faction.key == 'Tavern' then
            for i, hero in ipairs(list) do
                hero.unlock = 'zone' .. ZONE_ORDER[i]
            end
        else
            local first, second, third = list[1], list[2], list[3]
            achievement('join_' .. second.id, second.name .. ' Joins', 'Defeat a boss with the ' .. first.name .. '.',
                '', second.icon, 10, function(p) return p.heroBosses[first.id] or 0, 1 end)
            second.unlock = 'join_' .. second.id
            achievement('join_' .. third.id, third.name .. ' Joins', 'Survive 5:00 with the ' .. second.name .. '.',
                '', third.icon, 15, function(p) return p.heroTime[second.id] or 0, 300 end)
            third.unlock = 'join_' .. third.id
            list[4].unlock = 'faction' .. fi
        end
    end
    local ACH_BY_KEY = {}
    for _, a in ipairs(ACHIEVEMENTS) do
        ACH_BY_KEY[a.key] = a
    end

    ---------------------------------------------------------------------------
    -- Utilities
    ---------------------------------------------------------------------------
    local U = {iconCache = {}}

    function U.col(hex, s)
        return '|cff' .. hex .. s .. '|r'
    end

    function U.strip(s)
        return (s:gsub('|c\037x\037x\037x\037x\037x\037x\037x\037x', ''):gsub('|r', ''))
    end

    function U.clamp(x, low, high)
        if x < low then
            return low
        elseif x > high then
            return high
        end
        return x
    end

    function U.num(x)
        if x >= 100 or math.abs(x - math.floor(x + 0.5)) < 0.05 then
            return tostring(math.floor(x + 0.5))
        end
        return string.format('\037.1f', x)
    end

    function U.big(x)
        local s = tostring(math.floor(x + 0.5))
        local out = s:reverse():gsub('(\037d\037d\037d)', '\0371,'):reverse()
        return (out:gsub('^,', ''))
    end

    function U.time(seconds)
        seconds = math.max(0, math.floor(seconds))
        return string.format('\03702d:\03702d', seconds // 60, math.fmod(seconds, 60))
    end

    -- Real icon path of an ability, unit or item rawcode, read from the game
    -- data. Falls back to a CommandButtons icon name when the lookup fails.
    function U.icon(code, fallback)
        local cacheKey = (code or '') .. '|' .. (fallback or '')
        local cached = U.iconCache[cacheKey]
        if cached then
            return cached
        end
        local path = nil
        if code and code ~= '' then
            local ok, result = pcall(BlzGetAbilityIcon, FourCC(code))
            -- Upgrades list one icon per level ("A.blp,B.blp,C.blp"): keep the first.
            if ok and type(result) == 'string' then
                result = result:match('^[^,]*')
            end
            if ok and type(result) == 'string' and result ~= '' and not result:find('BTNTemp') then
                path = result
            end
        end
        if path == nil then
            path = 'ReplaceableTextures\\CommandButtons\\' .. (fallback or 'BTNSelectHeroOn') .. '.blp'
        end
        U.iconCache[cacheKey] = path
        return path
    end

    -- An item's icon, from its rawcode's art in the game data.
    local function gearIcon(item)
        return U.icon(item.code, 'BTNSelectHeroOn')
    end

    function U.heroIcon(hero)
        return U.icon(hero.id, hero.icon)
    end

    function U.spellIcon(def)
        return U.icon(def.code, def.icon)
    end

    function U.factionOf(hero)
        for index, faction in ipairs(FACTIONS) do
            if faction.key == hero.faction then
                return faction, index
            end
        end
        return FACTIONS[1], 1
    end

    -- Level 1 health before any bonus: Stamina starts at Warcraft III Strength.
    function U.heroHealth(hero)
        return math.floor(CFG.HP_BASE + CFG.HP_PER_STAMINA * hero.attr.str)
    end

    -- "Int 19  Str 14  Agi 17": the primary attribute first, in gold.
    local ATTR_SHORT = {str = 'Str', agi = 'Agi', int = 'Int'}
    function U.heroAttributes(hero)
        local parts = {U.col(GOLD, ATTR_SHORT[hero.primary] .. ' ' .. hero.attr[hero.primary])}
        for _, key in ipairs({'str', 'agi', 'int'}) do
            if key ~= hero.primary then
                parts[#parts + 1] = ATTR_SHORT[key] .. ' ' .. hero.attr[key]
            end
        end
        return table.concat(parts, '  ')
    end

    ---------------------------------------------------------------------------
    -- File IO (single player). Writes a Preload file that, when read back with
    -- Preloader, stores its payload in an ability tooltip.
    ---------------------------------------------------------------------------
    local FileIO = {}
    do
        local RAW_PREFIX = ']]i([['
        local RAW_SUFFIX = ']])--[['
        local RAW_SIZE = 200 - #RAW_PREFIX - #RAW_SUFFIX
        local EMPTY = '!@#$, empty data'

        function FileIO.save(path, data)
            local ability = FourCC('ANdc')
            PreloadGenClear()
            Preload('")\nendfunction\n//!beginusercode\nlocal p={} local i=function(s) table.insert(p,s) end--[[')
            for index = 1, #data, RAW_SIZE do
                Preload(RAW_PREFIX .. data:sub(index, index + RAW_SIZE - 1) .. RAW_SUFFIX)
            end
            Preload(']]BlzSetAbilityTooltip(' .. ability .. ', table.concat(p), 0)\n//!endusercode\nfunction a takes nothing returns nothing\n //')
            PreloadGenEnd(path)
        end

        function FileIO.load(path)
            local ability = FourCC('ANdc')
            local original = BlzGetAbilityTooltip(ability, 0)
            BlzSetAbilityTooltip(ability, EMPTY, 0)
            Preloader(path)
            local loaded = BlzGetAbilityTooltip(ability, 0)
            BlzSetAbilityTooltip(ability, original, 0)
            if loaded == EMPTY then
                return nil
            end
            return loaded
        end
    end

    ---------------------------------------------------------------------------
    -- Profile: everything that survives between runs.
    ---------------------------------------------------------------------------
    local Profile = {data = nil}

    function Profile.new()
        return {gold = 0, goldTotal = 0, kills = 0, runs = 0, wins = 0, bosses = 0, bestLevel = 0, unlocked = 1,
            zoneWins = {}, zoneBest = {}, heroWins = {}, factionWins = {}, diffWins = {},
            -- heroTime: hero id -> longest run in seconds; heroBosses: bosses it slew.
            heroTime = {}, heroBosses = {},
            -- zoneDiff: best difficulty cleared per zone (4 = a Mythic+ key).
            -- keyMax: highest keystone a zone may be started at; keyBest: best timed.
            zoneDiff = {}, keyMax = {}, keyBest = {},
            -- endless: zone index -> longest endless run there, in seconds.
            endless = {},
            -- gear: item id -> dropped item level; upg: item id -> upgrade steps.
            gear = {}, upg = {},
            -- opts: sound volumes in percent, keyed as in VOLUMES (missing = 100),
            -- and wasd = 1 when the hero walks with the movement keys.
            -- inv: inventory slot 1..6 -> GEAR index of the item carried there.
            -- starts: hero id -> index in its pool of the spell it starts with.
            -- binds: action key (ACTIONS) -> key code, when not the default.
            ach = {}, perks = {}, talents = {}, codex = {}, opts = {}, inv = {}, starts = {}, binds = {}}
    end

    function Profile.encode(p)
        local keys = {}
        for key in pairs(p) do
            keys[#keys + 1] = key
        end
        table.sort(keys)
        local parts = {CFG.SAVE_VERSION}
        for _, key in ipairs(keys) do
            local value = p[key]
            if type(value) == 'table' then
                local items = {}
                for mapKey, mapValue in pairs(value) do
                    items[#items + 1] = tostring(mapKey) .. ':' .. tostring(math.floor(mapValue))
                end
                table.sort(items)
                parts[#parts + 1] = key .. '=@' .. table.concat(items, ',')
            elseif type(value) == 'number' then
                parts[#parts + 1] = key .. '=' .. tostring(math.floor(value))
            end
        end
        return table.concat(parts, ';')
    end

    function Profile.decode(s)
        local p = Profile.new()
        if type(s) ~= 'string' or s:sub(1, #CFG.SAVE_VERSION) ~= CFG.SAVE_VERSION then
            return p
        end
        for key, value in s:gmatch('([\037w_]+)=([^;]*)') do
            if value:sub(1, 1) == '@' then
                local map = {}
                for mapKey, mapValue in value:sub(2):gmatch('([^,:]+):([^,]*)') do
                    map[mapKey] = tonumber(mapValue) or 0
                end
                p[key] = map
            else
                p[key] = tonumber(value) or 0
            end
        end
        return p
    end

    function Profile.load()
        local ok, raw = pcall(FileIO.load, CFG.SAVE_FILE)
        Profile.data = Profile.decode(ok and raw or nil)
        local p = Profile.data
        -- Saves from before ZONE_ORDER counted unlocked zones by index (the
        -- first six in a row); open the same zone in the new order.
        if p.zones == nil then
            p.unlocked = ZONES[U.clamp(p.unlocked, 1, 6)].rank
            p.zones = 2
        end
        p.unlocked = U.clamp(p.unlocked, 1, #ZONES)
        -- Talents that no longer exist (Might, Vitality) give their gold back.
        for key, rank in pairs(p.talents) do
            if TALENT_BY_KEY[key] == nil then
                for r = 1, rank do
                    p.gold = p.gold + talentCost(r)
                end
                p.talents[key] = nil
            end
        end
        -- Saves from before the inventory carry their six best items.
        if next(p.inv) == nil and next(p.gear) ~= nil then
            local owned = {}
            for _, item in ipairs(GEAR) do
                if p.gear[item.id] then
                    owned[#owned + 1] = item
                end
            end
            table.sort(owned, function(a, b)
                return gearLevel(p, a) > gearLevel(p, b)
            end)
            for slot = 1, math.min(INVENTORY_SIZE, #owned) do
                p.inv[tostring(slot)] = owned[slot].index
            end
        end
    end

    function Profile.save()
        if Profile.data then
            pcall(FileIO.save, CFG.SAVE_FILE, Profile.encode(Profile.data))
        end
    end

    function Profile.inc(map, key, amount)
        key = tostring(key)
        map[key] = (map[key] or 0) + (amount or 1)
    end

    function Profile.perk(key)
        return Profile.data.perks[key] or 0
    end

    function Profile.talent(key)
        return Profile.data.talents[key] or 0
    end

    -- Talents and heroes with an unlock open once that achievement is earned.
    function Profile.talentOpen(talent)
        return talent.unlock == nil or Profile.data.ach[talent.unlock] ~= nil
    end

    function Profile.blessingOpen(b)
        return b.unlock == nil or Profile.data.ach[b.unlock] ~= nil
    end

    function Profile.heroOpen(hero)
        return hero.unlock == nil or Profile.data.ach[hero.unlock] ~= nil
    end

    -- How to open a locked talent or hero: its achievement's own words.
    function Profile.unlockText(unlock)
        local a = ACH_BY_KEY[unlock]
        return a and (a.name .. ': ' .. a.desc) or ''
    end

    function Profile.points()
        local earned = 0
        for _, a in ipairs(ACHIEVEMENTS) do
            if Profile.data.ach[a.key] then
                earned = earned + a.points
            end
        end
        local spent = 0
        for _, perk in ipairs(PERKS) do
            for rank = 1, Profile.perk(perk.key) do
                spent = spent + perk.costs[rank]
            end
        end
        return earned - spent, earned, spent
    end

    function Profile.checkAchievements()
        local earned = {}
        for _, a in ipairs(ACHIEVEMENTS) do
            if not Profile.data.ach[a.key] then
                local current, goal = a.progress(Profile.data)
                if current >= goal then
                    Profile.data.ach[a.key] = 1
                    earned[#earned + 1] = a
                end
            end
        end
        return earned
    end

    function Profile.zoneDiff(zoneIndex)
        return Profile.data.zoneDiff[tostring(zoneIndex)] or 0
    end

    -- Heroic opens after a Normal clear of the zone, Mythic after Heroic,
    -- Mythic+ after Mythic.
    function Profile.difficultyOpen(zoneIndex, difficultyIndex)
        return difficultyIndex == 1 or Profile.zoneDiff(zoneIndex) >= difficultyIndex - 1
    end

    function Profile.keyMax(zoneIndex)
        return math.max(2, Profile.data.keyMax[tostring(zoneIndex)] or 2)
    end

    function Profile.keyBest(zoneIndex)
        return Profile.data.keyBest[tostring(zoneIndex)] or 0
    end

    function Profile.itemLevel(item)
        return gearLevel(Profile.data, item)
    end

    -- Account-wide bonuses from talents, worn gear and perks.
    function Profile.applyBonuses(s)
        for _, talent in ipairs(TALENTS) do
            local rank = Profile.talent(talent.key)
            if rank > 0 then
                talent.apply(s, talent.per * rank)
            end
        end
        for _, item in pairs(gearEquipped(Profile.data)) do
            local ilvl = Profile.itemLevel(item)
            for _, entry in ipairs(item.stats) do
                entry.stat.apply(s, gearValue(entry.stat, entry.w, ilvl))
            end
            if item.effect then
                item.effect.apply(s, gearValue(item.effect, 1, ilvl))
            end
        end
        if Profile.perk('secondwind') > 0 then
            s.lives = s.lives + 1
        end
        s.luck = s.luck + 0.15 * Profile.perk('lucky')
    end

    ---------------------------------------------------------------------------
    -- UI toolkit. All positions use the 4:3 frame space: x from 0 to 0.8,
    -- y from 0 (bottom) to 0.6 (top). "top" is the y of the frame's top edge.
    ---------------------------------------------------------------------------
    local UI = {n = 0, handlers = {}}

    -- Coloured wash laid inside a button: the escape-menu button keeps its own
    -- frame and texture, the wash marks the primary (red) and positive (green) ones.
    local STYLE = {
        dark = {wash = {70, 34, 14, 120}},
        tab = {wash = {70, 34, 14, 120}},
        red = {wash = {170, 24, 12, 125}},
        green = {wash = {40, 140, 40, 105}}
    }

    function UI.init()
        UI.game = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        UI.trigger = CreateTrigger()
        TriggerAddAction(UI.trigger, function()
            local frame = BlzGetTriggerFrame()
            local handler = UI.handlers[frame]
            if handler == nil then
                return
            end
            local event = BlzGetTriggerFrameEvent()
            local action = nil
            if event == FRAMEEVENT_CONTROL_CLICK then
                -- Drop keyboard focus so the clicked button cannot swallow keys.
                if GetTriggerPlayer() == GetLocalPlayer() then
                    BlzFrameSetEnable(frame, false)
                    BlzFrameSetEnable(frame, true)
                end
                action = handler.click
            elseif event == FRAMEEVENT_MOUSE_ENTER then
                action = handler.enter
            elseif event == FRAMEEVENT_MOUSE_LEAVE then
                action = handler.leave
            end
            if action then
                UI.safe(action)
            end
        end)
    end

    function UI.safe(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then
            UI.errors = (UI.errors or 0) + 1
            if UI.errors <= 6 then
                print('|cffff4040Warcraft Survivors error:|r ' .. tostring(err))
            end
        end
    end

    function UI.name()
        UI.n = UI.n + 1
        return 'WS' .. UI.n
    end

    function UI.place(frame, x, top, w, h)
        BlzFrameClearAllPoints(frame)
        BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOPLEFT, x, top)
        BlzFrameSetSize(frame, w, h)
    end

    function UI.group(parent)
        local frame = BlzCreateFrameByType('FRAME', UI.name(), parent or UI.game, '', 0)
        UI.place(frame, 0.0, 0.6, 0.8, 0.6)
        return frame
    end

    function UI.tint(frame, r, g, b, a)
        BlzFrameSetVertexColor(frame, BlzConvertColor(a or 255, r, g, b))
    end

    function UI.box(parent, x, top, w, h, r, g, b, a, texture)
        local frame = BlzCreateFrameByType('BACKDROP', UI.name(), parent, '', 0)
        UI.place(frame, x, top, w, h)
        BlzFrameSetTexture(frame, texture or TEX.white, 0, true)
        UI.tint(frame, r or 255, g or 255, b or 255, a or 255)
        return frame
    end

    function UI.image(parent, texture, x, top, w, h)
        return UI.box(parent, x, top, w, h, 255, 255, 255, 255, texture)
    end

    function UI.text(parent, s, x, top, w, h, size, align, valign)
        local frame = BlzCreateFrameByType('TEXT', UI.name(), parent, '', 0)
        UI.place(frame, x, top, w, h)
        BlzFrameSetFont(frame, CFG.FONT, size or 0.0095, 0)
        BlzFrameSetTextAlignment(frame, valign or TEXT_JUSTIFY_MIDDLE, align or TEXT_JUSTIFY_LEFT)
        BlzFrameSetText(frame, s or '')
        return frame
    end

    -- Classic backdrop from a stock template, which draws its own border.
    function UI.frame(parent, template, x, top, w, h, alpha)
        local frame = BlzCreateFrameByType('BACKDROP', UI.name(), parent, template, 0)
        UI.place(frame, x, top, w, h)
        if alpha then
            BlzFrameSetAlpha(frame, alpha)
        end
        return frame
    end

    -- Edge colours in this file are gold shades; the classic edge is gold
    -- already, so only their brightness is kept (selected rows stay bright).
    function UI.edgeTint(frames, r, g, b, a)
        local v = math.floor(U.clamp((r + g + b) / 474, 0, 1) * 255)
        UI.tintAll(frames, v, v, v, a or 255)
    end

    -- Thin gold outline with no fill, returned as a list for UI.edgeTint.
    function UI.border(parent, x, top, w, h, thickness, r, g, b, a)
        local frame = UI.frame(parent, TPL.box, x, top, w, h)
        BlzFrameSetTexture(frame, TEX.clear, 0, true)
        local edge = {frame}
        UI.edgeTint(edge, r or 214, g or 170, b or 90, a)
        return edge
    end

    function UI.tintAll(frames, r, g, b, a)
        for _, frame in ipairs(frames) do
            UI.tint(frame, r, g, b, a)
        end
    end

    -- The escape-menu window: marble with the ornate gold frame. Its corner
    -- pieces are 0.048 wide, so small panels take the thin plate instead.
    function UI.panel(parent, x, top, w, h, alpha)
        local template = math.min(w, h) >= 0.12 and TPL.panel or TPL.box
        local bg = UI.frame(parent, template, x, top, w, h, alpha)
        return {bg = bg, frames = {bg}}
    end

    -- Dark wood plate with a thin gold edge, for rows and small boxes.
    function UI.plate(parent, x, top, w, h, alpha)
        return UI.frame(parent, TPL.box, x, top, w, h, alpha)
    end

    -- Centered gold heading, as on the stock menu windows.
    function UI.heading(parent, s, x, top, w, size)
        size = size or 0.014
        return UI.text(parent, U.col(GOLD, s), x, top, w, size * 1.6, size, TEXT_JUSTIFY_CENTER)
    end

    -- Gold double rule under a title, centered on cx, w wide.
    function UI.ornament(parent, cx, top, w)
        UI.box(parent, cx - w / 2, top, w, 0.0012, 214, 170, 90, 235)
        UI.box(parent, cx - w * 0.36, top - 0.0035, w * 0.72, 0.0008, 214, 170, 90, 170)
    end

    -- Gold heading set between two thin gold rules, centered in w.
    function UI.rule(parent, title, x, top, w, size)
        size = size or 0.0125
        local text = UI.text(parent, U.col(GOLD, title), x, top, w, 0.02, size, TEXT_JUSTIFY_CENTER)
        local lineW = w / 2 - (string.len(title) * size * 0.38 + 0.01)
        if lineW > 0.01 then
            UI.box(parent, x, top - 0.0102, lineW, 0.0008, 150, 112, 58, 210)
            UI.box(parent, x + w - lineW, top - 0.0102, lineW, 0.0008, 150, 112, 58, 210)
        end
        return text
    end

    -- Lobby panel: the escape menu's stone and gold frame around a dark
    -- fill, with an optional ruled heading inside its top edge. Content
    -- keeps LAY.pad (0.022) clear of the frame.
    function UI.card(parent, x, top, w, h, title)
        local fill = UI.box(parent, x + 0.008, top - 0.008, w - 0.016, h - 0.016, 12, 9, 7, 242)
        local frame = UI.frame(parent, TPL.panel, x, top, w, h)
        BlzFrameSetTexture(frame, TEX.clear, 0, true)
        if title then
            UI.rule(parent, title, x + 0.024, top - 0.018, w - 0.048)
        end
        return frame, fill
    end

    -- Resizes a card from UI.card (same top and width, new height).
    function UI.sizeCard(frame, fill, x, top, w, h)
        UI.place(fill, x + 0.008, top - 0.008, w - 0.016, h - 0.016)
        UI.place(frame, x, top, w, h)
    end

    -- Invisible clickable area; visuals are drawn by the caller underneath.
    function UI.hit(parent, x, top, w, h, onClick, onEnter, onLeave)
        local frame = BlzCreateFrameByType('GLUETEXTBUTTON', UI.name(), parent, 'ScriptDialogButton', 0)
        UI.place(frame, x, top, w, h)
        BlzFrameSetText(frame, '')
        BlzFrameSetAlpha(frame, 0)
        BlzFrameSetLevel(frame, 8)
        UI.handlers[frame] = {click = onClick, enter = onEnter, leave = onLeave}
        BlzTriggerRegisterFrameEvent(UI.trigger, frame, FRAMEEVENT_CONTROL_CLICK)
        BlzTriggerRegisterFrameEvent(UI.trigger, frame, FRAMEEVENT_MOUSE_ENTER)
        BlzTriggerRegisterFrameEvent(UI.trigger, frame, FRAMEEVENT_MOUSE_LEAVE)
        return frame
    end

    -- Escape-menu button: normal and disabled backdrops, a style wash, the
    -- stock highlight for hover and the active tab, and a gold label.
    function UI.button(parent, x, top, w, h, label, onClick, style, size)
        local b = {style = STYLE[style or 'dark'], enabled = true, active = false, hover = false, visible = true,
            raw = label or ''}
        b.bg = UI.frame(parent, TPL.button, x, top, w, h)
        b.off = UI.frame(parent, TPL.buttonOff, x, top, w, h)
        b.wash = UI.box(parent, x, top, w, h, 255, 255, 255, 0)
        b.glow = UI.box(parent, x, top, w, h, 255, 255, 255, 255, TEX.highlight)
        b.label = UI.text(parent, b.raw, x, top, w, h, size or 0.011, TEXT_JUSTIFY_CENTER)
        b.hit = UI.hit(parent, x, top, w, h, function()
            if b.enabled and onClick then
                onClick(b)
            end
        end, function()
            b.hover = true
            UI.paint(b)
        end, function()
            b.hover = false
            UI.paint(b)
        end)
        UI.moveButton(b, x, top, w, h)
        UI.paint(b)
        return b
    end

    function UI.moveButton(b, x, top, w, h)
        local inset = math.min(0.005, h * 0.16)
        UI.place(b.bg, x, top, w, h)
        UI.place(b.off, x, top, w, h)
        UI.place(b.wash, x + inset, top - inset, w - inset * 2, h - inset * 2)
        UI.place(b.glow, x + inset * 0.6, top - inset * 0.6, w - inset * 1.2, h - inset * 1.2)
        UI.place(b.label, x, top, w, h)
        UI.place(b.hit, x, top, w, h)
    end

    function UI.paint(b)
        local live = b.enabled or b.active
        BlzFrameSetVisible(b.bg, b.visible and live)
        BlzFrameSetVisible(b.off, b.visible and not live)
        local wash = b.style.wash
        if wash then
            UI.tint(b.wash, wash[1], wash[2], wash[3], live and wash[4] or wash[4] // 3)
        else
            UI.tint(b.wash, 0, 0, 0, 0)
        end
        BlzFrameSetAlpha(b.glow, b.active and 210 or ((b.hover and b.enabled) and 130 or 0))
        local text = b.raw
        if not b.enabled then
            text = U.col('6e665c', U.strip(b.raw))
        elseif not text:find('|c') then
            text = U.col((b.hover or b.active) and 'ffffff' or 'fcd312', text)
        end
        BlzFrameSetText(b.label, text)
    end

    function UI.setLabel(b, s)
        b.raw = s
        UI.paint(b)
    end

    function UI.setEnabled(b, enabled)
        b.enabled = enabled
        UI.paint(b)
    end

    function UI.setActive(b, active)
        b.active = active
        UI.paint(b)
    end

    function UI.showButton(b, visible)
        b.visible = visible
        BlzFrameSetVisible(b.wash, visible)
        BlzFrameSetVisible(b.glow, visible)
        BlzFrameSetVisible(b.label, visible)
        BlzFrameSetVisible(b.hit, visible)
        UI.paint(b)
    end

    -- Icon with a tinted square frame behind it (used for heroes, spells,
    -- gear and achievements). Returns a table with set/show helpers.
    function UI.icon(parent, texture, x, top, size, onClick, onEnter, onLeave)
        local o = {}
        local pad = size * 0.09
        o.frame = UI.box(parent, x - pad, top + pad, size + pad * 2, size + pad * 2, 140, 110, 64, 255, TEX.iconFrame)
        o.img = UI.image(parent, texture, x, top, size, size)
        if onClick or onEnter then
            o.hit = UI.hit(parent, x, top, size, size, onClick, onEnter, onLeave)
        end
        return o
    end

    function UI.setIcon(o, texture, dim)
        BlzFrameSetTexture(o.img, texture, 0, true)
        if dim then
            UI.tint(o.img, 70, 70, 70, 255)
        else
            UI.tint(o.img, 255, 255, 255, 255)
        end
    end

    function UI.frameColor(o, r, g, b)
        UI.tint(o.frame, r, g, b, 255)
    end

    function UI.showIcon(o, visible)
        BlzFrameSetVisible(o.frame, visible)
        BlzFrameSetVisible(o.img, visible)
        if o.hit then
            BlzFrameSetVisible(o.hit, visible)
        end
    end

    -- Bar with a gold Warcraft frame on top of a tinted fill.
    function UI.bar(parent, x, top, w, h, r, g, b, textSize)
        local o = {w = w, h = h}
        o.back = UI.box(parent, x, top, w, h, 12, 9, 6, 235)
        o.fill = UI.box(parent, x, top, w, h, r, g, b, 255, TEX.barFill)
        o.edge = UI.box(parent, x - h * 0.35, top + h * 0.3, w + h * 0.7, h * 1.6, 255, 255, 255, 255, TEX.barFrame)
        o.text = UI.text(parent, '', x, top, w, h, textSize or 0.0085, TEXT_JUSTIFY_CENTER)
        return o
    end

    function UI.setBar(o, fraction, label)
        BlzFrameSetSize(o.fill, math.max(0.0001, o.w * U.clamp(fraction, 0, 1)), o.h)
        if label then
            BlzFrameSetText(o.text, label)
        end
    end

    -- Hover tooltip: a plate with an icon, a title, a grey line and a body.
    -- Make it last in its parent so it draws over the rest; k scales it.
    function UI.tooltip(parent, k, w, h)
        local tip = {k = k, w = w * k, h = h * k}
        tip.bg = UI.plate(parent, 0, 0, tip.w, tip.h, 245)
        tip.icon = UI.icon(parent, TEX.white, 0, 0, 0.026 * k)
        tip.title = UI.text(parent, '', 0, 0, tip.w, 0.015 * k, 0.0098 * k)
        tip.sub = UI.text(parent, '', 0, 0, tip.w, 0.012 * k, 0.0074 * k)
        tip.body = UI.text(parent, '', 0, 0, tip.w, tip.h, 0.0078 * k, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        tip.frames = {tip.bg, tip.icon.frame, tip.icon.img, tip.title, tip.sub, tip.body}
        UI.hideTooltip(tip)
        return tip
    end

    -- Shows the tooltip with its bottom-left corner at (x, bottom).
    function UI.showTooltip(tip, x, bottom, icon, title, sub, body)
        local k = tip.k
        local top = bottom + tip.h
        local size = 0.026 * k
        local pad = size * 0.09
        UI.place(tip.bg, x, top, tip.w, tip.h)
        UI.place(tip.icon.frame, x + 0.011 * k - pad, top - 0.011 * k + pad, size + pad * 2, size + pad * 2)
        UI.place(tip.icon.img, x + 0.011 * k, top - 0.011 * k, size, size)
        UI.place(tip.title, x + 0.046 * k, top - 0.010 * k, tip.w - 0.056 * k, 0.015 * k)
        UI.place(tip.sub, x + 0.046 * k, top - 0.025 * k, tip.w - 0.056 * k, 0.012 * k)
        UI.place(tip.body, x + 0.011 * k, top - 0.046 * k, tip.w - 0.022 * k, tip.h - 0.054 * k)
        UI.setIcon(tip.icon, icon)
        BlzFrameSetText(tip.title, title)
        BlzFrameSetText(tip.sub, U.col(GREY, sub))
        BlzFrameSetText(tip.body, U.col('d8cfc0', body))
        for _, f in ipairs(tip.frames) do
            BlzFrameSetVisible(f, true)
        end
    end

    function UI.hideTooltip(tip)
        for _, f in ipairs(tip.frames) do
            BlzFrameSetVisible(f, false)
        end
    end

    ---------------------------------------------------------------------------
    -- Game engine
    ---------------------------------------------------------------------------
    local G = {}
    local Hud, Cards, Finale, Lobby, Engine, Options, Keys, Updater = {}, {}, {}, {}, {}, {}, {}, {}
    local R = nil -- the current run, nil while in the lobby
    -- keys: action -> held; down: key code -> held (to tell a press from its repeats).
    local S = {heroIndex = 1, faction = 'Alliance', zone = 1, difficulty = 1, keyLevel = 2, tab = 'character', keys = {},
        down = {}}
    local TWO_PI = 6.28318530718

    function G.initWorld()
        local area = bj_mapInitialPlayableArea
        G.cx = GetRectCenterX(area)
        G.cy = GetRectCenterY(area)
        G.minX = GetRectMinX(area) + 160
        G.maxX = GetRectMaxX(area) - 160
        G.minY = GetRectMinY(area) + 160
        G.maxY = GetRectMaxY(area) - 160
        G.PLAYER = Player(0)
        G.ENEMY = Player(CFG.ENEMY_PLAYER)
        G.zLoc = Location(0, 0)
        G.pathItem = CreateItem(FourCC('afac'), G.cx, G.cy)
        if G.pathItem then
            SetItemVisible(G.pathItem, false)
        end
        SetPlayerAllianceStateBJ(G.ENEMY, G.PLAYER, bj_ALLIANCE_UNALLIED)
        SetPlayerAllianceStateBJ(G.PLAYER, G.ENEMY, bj_ALLIANCE_UNALLIED)
        FogEnable(false)
        FogMaskEnable(false)
        SuspendTimeOfDay(true)
    end

    function G.groundZ(x, y)
        MoveLocation(G.zLoc, x, y)
        return GetLocationZ(G.zLoc)
    end

    -- Terrain, cliffs, trees and doodads all block; uses a hidden item probe.
    function G.walkable(x, y)
        if x < G.minX or x > G.maxX or y < G.minY or y > G.maxY then
            return false
        end
        if IsTerrainPathable(x, y, PATHING_TYPE_WALKABILITY) then
            return false
        end
        if G.pathItem == nil then
            return true
        end
        SetItemPosition(G.pathItem, x, y)
        local dx = GetItemX(G.pathItem) - x
        local dy = GetItemY(G.pathItem) - y
        SetItemVisible(G.pathItem, false)
        return dx * dx + dy * dy < 100
    end

    function G.after(delay, fn)
        local list = R.sched
        list[#list + 1] = {t = R.time + delay, fn = fn}
    end

    function G.runScheduled()
        local list = R.sched
        local due = nil
        local i = 1
        while i <= #list do
            local entry = list[i]
            if entry.t <= R.time then
                due = due or {}
                due[#due + 1] = entry.fn
                list[i] = list[#list]
                list[#list] = nil
            else
                i = i + 1
            end
        end
        if due then
            for _, fn in ipairs(due) do
                fn()
            end
        end
    end

    function G.fx(model, x, y, scale)
        local fx = AddSpecialEffect(model, x, y)
        if scale and scale ~= 1 then
            BlzSetSpecialEffectScale(fx, scale)
        end
        DestroyEffect(fx)
    end

    -- Loops a playlist of the game's own soundtrack (Sound\Music\mp3Music),
    -- starting on a random track. The same list keeps playing undisturbed.
    function G.playMusic(names)
        if names == nil or #names == 0 then
            return
        end
        local key = table.concat(names, ';')
        if G.music == key then
            return
        end
        G.music = key
        local first = GetRandomInt(1, #names)
        local list = {}
        for i = 0, #names - 1 do
            list[#list + 1] = 'Sound\\Music\\mp3Music\\' .. names[math.fmod(first - 1 + i, #names) + 1] .. '.mp3'
        end
        ClearMapMusic()
        StopMusic(false)
        PlayMusic(table.concat(list, ';'))
    end

    -- A Warcraft III sound by its label (UI\SoundInfo\AbilitySounds.slk), at a
    -- point. Most spell effect models carry their own sound; this is for the
    -- spells whose art is silent (def.sound on cast, def.waveSound per wave).
    -- The engine replays one handle per label; Reforged makes one per play.
    -- The engine plays it without a position: there a positioned script sound
    -- goes out tagged with the player's entity 0, which the client rejects
    -- halfway through the message. The rest of the packet was then misread,
    -- and a stray byte read as a disconnect dropped the game to the main menu
    -- (Blizzard's waves sent one every 0.45 s).
    G.sounds = {}
    function G.sound(label, x, y)
        local snd = G.sounds[label]
        if snd == nil then
            snd = CreateSoundFromLabel(label, false, true, true, 10, 10)
            if snd == nil then
                return
            end
            if Engine.active() then
                G.sounds[label] = snd
            end
        end
        if not Engine.active() then
            SetSoundPosition(snd, x, y, 50)
        end
        StartSound(snd)
        if not Engine.active() then
            KillSoundWhenDone(snd)
        end
    end

    function G.timedFx(model, x, y, scale, duration)
        local fx = AddSpecialEffect(model, x, y)
        if scale and scale ~= 1 then
            BlzSetSpecialEffectScale(fx, scale)
        end
        R.fx[fx] = true
        local run = R
        G.after(duration, function()
            if run.fx[fx] then
                run.fx[fx] = nil
                DestroyEffect(fx)
            end
        end)
    end

    function G.lightning(code, x1, y1, z1, x2, y2, z2, duration)
        local bolt = AddLightningEx(code, false, x1, y1, z1, x2, y2, z2)
        if bolt == nil then
            return
        end
        R.lightnings[bolt] = true
        local run = R
        G.after(duration or 0.3, function()
            if run.lightnings[bolt] then
                run.lightnings[bolt] = nil
                DestroyLightning(bolt)
            end
        end)
    end

    function G.floatText(x, y, s, size, r, g, b)
        -- Warcraft III keeps 100 text tags; leave room for the game's own.
        if R.tagCount >= 75 then
            return
        end
        local tag = CreateTextTag()
        if tag == nil then
            return
        end
        R.tagCount = R.tagCount + 1
        SetTextTagText(tag, s, size * 0.0031)
        SetTextTagPos(tag, x + GetRandomReal(-20, 20), y, 60)
        SetTextTagColor(tag, r, g, b, 255)
        SetTextTagVelocity(tag, 0, 0.04)
        SetTextTagPermanent(tag, false)
        SetTextTagLifespan(tag, 0.8)
        SetTextTagFadepoint(tag, 0.45)
        local run = R
        G.after(0.85, function()
            run.tagCount = run.tagCount - 1
        end)
    end

    ---------------------------------------------------------------------------
    -- Stats
    ---------------------------------------------------------------------------
    -- str, agi, int and sta start as bonuses only: G.recomputeStats adds the
    -- hero's own attributes for its level once every bonus is in.
    function G.baseStats()
        return {str = 0, agi = 0, int = 0, sta = 0, maxMana = 0, manaRegen = 0,
            damage = 0, attackSpeed = 0, cdr = 0, area = 0, move = 0, maxHp = 0, regen = 0, armor = 0,
            crit = 0.05, critMult = 1.75, lifesteal = 0, pickup = 0, xp = 0, gold = 0, luck = 0, dodge = 0,
            thorns = 0, multishot = 0, duration = 0, dr = 0, cleave = 0, bash = 0, bashDamage = 0,
            attackSlow = 0, attackBonus = 0, killHeal = 0, killGold = 0, explode = 0, lives = 0, range = 0,
            -- Item effects (ITEM_EFFECTS).
            fireSplash = 0, darkMinion = 0, corrupt = 0, vampiric = 0, escape = 0, sanctuary = 0, flames = 0,
            summonDamage = 0, manaCost = 0, thirst = 0, souls = 0, spellWard = 0, frostguard = 0, searing = 0,
            -- Critical Strike (the Blademaster's passive).
            critStrike = 0, critStrikeMult = 1}
    end

    function G.spellValues(def, rank, power, s)
        local r = rank - 1
        -- Spell power is nil while G.recomputeStats is still adding bonuses.
        local spellPower = s.spellPower or 1
        -- Ranks never stop, and each one adds the same RANK_BONUS.
        local rankMult = 1 + CFG.RANK_BONUS * r
        local dmgMult = rankMult * power * (1 + s.damage) * spellPower
        local v = {rank = rank}
        v.dmg = (def.dmg or 0) * dmgMult
        v.dot = (def.dot or 0) * dmgMult
        v.impact = (def.impactDamage or 0) * dmgMult
        v.heal = (def.heal or 0) * rankMult * power * spellPower
        v.radius = (def.radius or 0) * (1 + 0.06 * r) * (1 + s.area)
        v.range = def.range or 900
        v.count = (def.count or 1) + math.floor(r / (def.countEvery or 99))
        if def.kind == 'bolt' or def.kind == 'line' then
            v.count = v.count + s.multishot
        end
        -- RANK_CD faster per rank, down to half the cooldown.
        v.cd = (def.cd or 1) * math.max(CFG.RANK_CD_FLOOR, 1 - CFG.RANK_CD * r) * (1 - math.min(0.6, s.cdr))
        -- Whole mana points (MANA_DATA), a little more with every rank, less
        -- with Spell Mastery.
        v.mana = def.mana and math.max(1, math.floor(def.mana * (1 + CFG.MANA_COST_PER_RANK * r)
            * (1 - math.min(0.5, s.manaCost or 0)) + 0.5)) or 0
        if def.kind == 'summon' and not def.split then
            -- Out for exactly one cooldown, so they cannot pile up on their own;
            -- spell duration (Persistence) lets the waves overlap. A split
            -- (Storm, Earth and Fire) lasts its own duration.
            v.dur = v.cd * (1 + s.duration)
        elseif def.split then
            -- Ranks make the spirits stronger, not the split longer.
            v.dur = def.dur * (1 + s.duration)
        else
            v.dur = (def.dur or 0) * (1 + 0.1 * r) * (1 + s.duration)
        end
        v.stun = (def.stun or 0) * (1 + 0.1 * r)
        v.amount = (def.per or 0) * rank * power
        v.bonus = (def.basePct or 0) + v.amount
        -- Channeled areas (Bladestorm, Blizzard, Earthquake...) last longer
        -- with spell duration: more waves at the same pace.
        v.waves = def.waves or 1
        if def.kind == 'zone' then
            v.waves = math.floor(v.waves * (1 + s.duration) + 0.5)
        end
        return v
    end

    local KIND_NAMES = {bolt = 'Missile', nova = 'Burst', zone = 'Area', chain = 'Lightning', line = 'Wave',
        orbit = 'Orbit', aura = 'Aura', summon = 'Summon', heal = 'Heal', buff = 'Buff', passive = 'Passive'}

    function G.describe(def, v)
        local show = {
            dmg = v.dmg, dot = v.dot, impact = v.impact, heal = v.heal, radius = v.radius, count = v.count,
            dur = v.dur, stun = v.stun, waves = v.waves, rank = v.rank,
            pct = def.flat and v.amount or v.amount * 100, pct2 = v.bonus * 100, pct2b = v.amount * 200,
            rank3 = v.rank * 3, rank6 = v.rank * 6, rank10 = v.rank * 10
        }
        return (def.desc:gsub('{(\037w+)}', function(key)
            local value = show[key]
            if value == nil then
                return '?'
            end
            return U.col('ffffff', U.num(value))
        end))
    end

    function G.blessingValue(b, x)
        return b.flat and x or x * 100
    end

    -- What one more pick of a stat card adds (current: the run's picks of it
    -- so far, or nil, unused: every pick gives the same): attributes in whole
    -- points.
    function G.blessingGain(b, current, bonus)
        if b.attribute then
            return math.floor(b.per * (1 + bonus) + 0.5)
        end
        return b.per * (1 + bonus)
    end

    function G.describeBlessing(b, x)
        return (b.desc:gsub('{v}', U.col('ffffff', U.num(G.blessingValue(b, x)))))
    end

    -- What x points of an attribute card do for the hero in this run, as
    -- G.recomputeStats counts them (nil for other cards): the primary
    -- attribute also adds attack damage and spell power.
    function G.attributeEffects(key, x)
        local s, def = R.stats, R.def
        local parts = {}
        local attr = ({strength = 'str', agility = 'agi', intellect = 'int'})[key]
        if attr and attr == def.primary then
            parts[#parts + 1] = '+' .. U.num(x * (1 + s.damage)) .. ' attack damage'
            local k = CFG.SPELL_POWER_PER_POINT
            parts[#parts + 1] = '+' .. U.num(100 * k * x / (1 + k * def.attr[def.primary])) .. '\037 spell power'
        end
        if key == 'strength' then
            parts[#parts + 1] = '+' .. U.num(CFG.REGEN_PER_STRENGTH * x) .. ' health/s'
        elseif key == 'agility' then
            parts[#parts + 1] = '+' .. U.num(100 * CFG.ATTACK_SPEED_PER_AGILITY * x) .. '\037 attack speed'
            parts[#parts + 1] = '+' .. U.num(CFG.ARMOR_PER_AGILITY * x) .. ' armor'
        elseif key == 'intellect' then
            parts[#parts + 1] = '+' .. U.num(CFG.MANA_PER_INTELLECT * x) .. ' mana'
            parts[#parts + 1] = '+' .. U.num(CFG.MANA_REGEN_PER_INTELLECT * x) .. ' mana/s'
        elseif key == 'stamina' then
            parts[#parts + 1] = '+' .. U.num(CFG.HP_PER_STAMINA * x) .. ' health'
        elseif key == 'armor' then
            -- Warcraft III armor: each point takes a little less off a hit.
            local function reduction(a)
                return a >= 0 and 0.06 * a / (1 + 0.06 * a) or 0
            end
            parts[#parts + 1] = 'Attacks deal ' .. U.num(100 * reduction(s.armor)) .. '\037  >  '
                .. U.num(100 * reduction(s.armor + x)) .. '\037 less damage'
        else
            return nil
        end
        return table.concat(parts, ', ')
    end

    -- An item's stats on one line: "+4 Strength, +2 Stamina, +6 percent damage".
    function G.describeItem(item, ilvl)
        local parts = {}
        for _, entry in ipairs(item.stats) do
            parts[#parts + 1] = G.describeBlessing(entry.stat, gearValue(entry.stat, entry.w, ilvl))
        end
        return table.concat(parts, ', ')
    end

    -- Its effect, if any, as a green Equip line (nil without one).
    function G.describeItemEffect(item, ilvl)
        local e = item.effect
        if e == nil then
            return nil
        end
        local text = e.desc:gsub('{v}', U.num(G.blessingValue(e, gearValue(e, 1, ilvl))))
        return U.col(GREEN, 'Equip: ' .. text)
    end

    -- What the next upgrade raises: only what changes (whole attributes and
    -- capped effects can stay put for a step), or nil.
    function G.describeItemNext(item, ilvl)
        local parts = {}
        for _, entry in ipairs(item.stats) do
            local x = gearValue(entry.stat, entry.w, ilvl + GEAR_STEP_ILVL)
            if x ~= gearValue(entry.stat, entry.w, ilvl) then
                parts[#parts + 1] = G.describeBlessing(entry.stat, x)
            end
        end
        local e = item.effect
        if e and e.per then
            local x = gearValue(e, 1, ilvl + GEAR_STEP_ILVL)
            if x ~= gearValue(e, 1, ilvl) then
                parts[#parts + 1] = e.name .. ' ' .. U.col('ffffff', U.num(G.blessingValue(e, x)) .. (e.flat and '' or '\037'))
            end
        end
        return #parts > 0 and table.concat(parts, ', ') or nil
    end

    function G.recomputeStats()
        local s = G.baseStats()
        if R.melee then
            s.cleave = 0.35
        end
        U.factionOf(R.def).apply(s)
        Profile.applyBonuses(s)
        for key, b in pairs(R.blessings) do
            BLESSING_BY_KEY[key].apply(s, b.value)
        end
        for _, inst in ipairs(R.spells) do
            -- Passives, and auras or bolts that also grant a stat; buffs apply while active.
            if inst.def.apply and inst.def.kind ~= 'buff' then
                inst.def.apply(s, G.spellValues(inst.def, inst.rank, inst.power, s))
            end
        end
        for _, buff in pairs(R.buffs) do
            if buff.def.apply then
                buff.def.apply(s, buff.v)
            end
        end
        -- Intellect harvested by the Grimoire of Souls this run.
        s.int = s.int + R.souls
        -- Warcraft III attributes: the hero's own, grown by its level, on top
        -- of every bonus. Stamina takes Strength's numbers (and its health),
        -- so level 1 health is Warcraft III's.
        local def, grown = R.def, R.level - 1
        for _, key in ipairs({'str', 'agi', 'int'}) do
            s[key] = s[key] + def.attr[key] + def.gain[key] * grown
        end
        s.sta = s.sta + def.attr.str + def.gain.str * grown
        s.primary = s[def.primary]
        s.regen = s.regen + CFG.REGEN_PER_STRENGTH * s.str
        s.maxMana = s.maxMana + CFG.MANA_PER_INTELLECT * s.int
        s.manaRegen = s.manaRegen + CFG.MANA_REGEN_BASE + CFG.MANA_REGEN_PER_INTELLECT * s.int
        s.attackSpeed = s.attackSpeed + CFG.ATTACK_SPEED_PER_AGILITY * s.agi
        s.armor = s.armor + (def.armor or 0) + CFG.ARMOR_PER_AGILITY * s.agi
        local k = CFG.SPELL_POWER_PER_POINT
        s.spellPower = (1 + k * s.primary) / (1 + k * def.attr[def.primary])
        s.attackDamage = (def.damage + s.primary + s.attackBonus) * (1 + s.damage)
        s.cdr = math.min(s.cdr, 0.6)
        s.dodge = math.min(s.dodge, 0.6)
        s.dr = math.min(s.dr, 0.7)
        R.stats = s

        local hero = R.hero
        local maxHp = math.floor(CFG.HP_BASE + CFG.HP_PER_STAMINA * s.sta + s.maxHp)
        local oldMax = BlzGetUnitMaxHP(hero)
        if maxHp ~= oldMax then
            local life = GetWidgetLife(hero)
            BlzSetUnitMaxHP(hero, maxHp)
            if maxHp > oldMax then
                SetWidgetLife(hero, life + (maxHp - oldMax))
            else
                SetWidgetLife(hero, math.min(life, maxHp))
            end
        end
        -- Mana is the script's own (R.mana); a bigger pool fills by the
        -- difference, like health.
        if R.maxMana == nil then
            R.mana = s.maxMana
        elseif s.maxMana > R.maxMana then
            R.mana = R.mana + (s.maxMana - R.maxMana)
        end
        R.maxMana = s.maxMana
        R.mana = math.min(R.mana, s.maxMana)
        BlzSetUnitArmor(hero, s.armor)
        R.moveSpeed = R.baseMove * (1 + s.move)
        R.pickupRange = CFG.BASE_PICKUP * (1 + s.pickup)
        for _, inst in ipairs(R.spells) do
            inst.v = G.spellValues(inst.def, inst.rank, inst.power, s)
        end
    end

    ---------------------------------------------------------------------------
    -- Enemy queries. Positions are cached once per tick.
    ---------------------------------------------------------------------------
    function G.refreshEnemyCache()
        local list, xs, ys = R.elist, R.ex, R.ey
        local n = 0
        for u in pairs(R.enemies) do
            n = n + 1
            list[n] = u
            xs[n] = GetUnitX(u)
            ys[n] = GetUnitY(u)
        end
        for i = n + 1, R.en do
            list[i] = nil
        end
        R.en = n
    end

    function G.nearest(x, y, range, count, exclude)
        local found = {}
        local r2 = range * range
        for i = 1, R.en do
            local u = R.elist[i]
            if R.enemies[u] and not (exclude and exclude[u]) then
                local dx = R.ex[i] - x
                local dy = R.ey[i] - y
                local d2 = dx * dx + dy * dy
                if d2 <= r2 then
                    found[#found + 1] = {u = u, d = d2, x = R.ex[i], y = R.ey[i]}
                end
            end
        end
        if #found > 1 then
            table.sort(found, function(a, b)
                return a.d < b.d
            end)
        end
        for i = #found, count + 1, -1 do
            found[i] = nil
        end
        return found
    end

    -- Bosses and elites first, then the nearest.
    function G.priorityTargets(range, count)
        local list = G.nearest(R.hx, R.hy, range, 999)
        table.sort(list, function(a, b)
            local ia, ib = R.enemies[a.u], R.enemies[b.u]
            local pa = (ia and (ia.boss or ia.elite)) and 1 or 0
            local pb = (ib and (ib.boss or ib.elite)) and 1 or 0
            if pa ~= pb then
                return pa > pb
            end
            return a.d < b.d
        end)
        for i = #list, count + 1, -1 do
            list[i] = nil
        end
        return list
    end

    function G.inRange(x, y, radius, fn)
        local r2 = radius * radius
        for i = 1, R.en do
            local dx = R.ex[i] - x
            local dy = R.ey[i] - y
            if dx * dx + dy * dy <= r2 then
                local u = R.elist[i]
                if R.enemies[u] then
                    fn(u, R.ex[i], R.ey[i])
                end
            end
        end
    end

    function G.countInRange(x, y, radius)
        local count = 0
        local r2 = radius * radius
        for i = 1, R.en do
            local dx = R.ex[i] - x
            local dy = R.ey[i] - y
            if dx * dx + dy * dy <= r2 then
                count = count + 1
            end
        end
        return count
    end

    function G.densest(range, radius)
        local hx, hy = R.hx, R.hy
        local r2 = range * range
        local rad2 = radius * radius
        local n = R.en
        local step = n > 70 and 2 or 1
        local best, bestCount = nil, 0
        for i = 1, n, step do
            local dx = R.ex[i] - hx
            local dy = R.ey[i] - hy
            if dx * dx + dy * dy <= r2 then
                local count = 0
                local cx, cy = R.ex[i], R.ey[i]
                for j = 1, n do
                    local ox = R.ex[j] - cx
                    local oy = R.ey[j] - cy
                    if ox * ox + oy * oy <= rad2 then
                        count = count + 1
                    end
                end
                if count > bestCount then
                    bestCount = count
                    best = i
                end
            end
        end
        if best then
            return R.ex[best], R.ey[best]
        end
        return nil, nil
    end

    ---------------------------------------------------------------------------
    -- Damage, crowd control and healing
    ---------------------------------------------------------------------------
    function G.damage(u, amount, source, canCrit)
        local info = R.enemies[u]
        if info == nil or amount <= 0 then
            return
        end
        local s = R.stats
        -- Orb of Corruption: a corrupted target takes more from everything.
        if info.corruptUntil and R.time < info.corruptUntil then
            amount = amount * (1 + s.corrupt)
        end
        local crit = false
        if canCrit ~= false and GetRandomReal(0, 1) < s.crit then
            amount = amount * s.critMult
            crit = true
        end
        R.dmgSource = source
        R.dmgCrit = crit
        -- The basic attack carries the hero's weapon type, so its hits clash
        -- like a native attack (other damage is silent).
        local weapon = source == 'attack' and R.weaponType or WEAPON_TYPE_WHOKNOWS
        UnitDamageTarget(R.hero, u, amount, false, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, weapon)
        R.dmgSource = nil
        R.dmgCrit = false
    end

    function G.slow(u, pct, duration)
        local info = R.enemies[u]
        if info == nil then
            return
        end
        if info.boss then
            pct = pct * 0.5
        end
        if R.time >= info.slowUntil or pct > info.slowPct then
            info.slowPct = pct
        end
        info.slowUntil = math.max(info.slowUntil, R.time + duration)
        SetUnitMoveSpeed(u, info.speed * (1 - info.slowPct))
    end

    function G.stun(u, duration)
        local info = R.enemies[u]
        if info == nil or duration <= 0 then
            return
        end
        if info.boss then
            duration = duration * 0.3
        end
        info.stunUntil = math.max(info.stunUntil, R.time + duration)
        if not info.stunned then
            info.stunned = true
            G.updateHeld(u, info)
        end
    end

    -- An enemy stands still while stunned or while a boss casts. Reforged counts
    -- BlzPauseUnitEx calls and the engine keeps a flag, so it is called only when
    -- the wanted state changes.
    function G.updateHeld(u, info)
        local want = (info.stunned or info.casting) and R.enemies[u] ~= nil
        if want ~= (info.held == true) then
            info.held = want
            BlzPauseUnitEx(u, want)
        end
    end

    function G.dot(u, dps, duration, source)
        local info = R.enemies[u]
        if info == nil or dps <= 0 then
            return
        end
        info.dots = info.dots or {}
        info.dots[source] = {dps = dps, untilT = R.time + duration}
    end

    function G.heal(amount)
        if amount <= 0 or R.hero == nil then
            return
        end
        local life = GetWidgetLife(R.hero)
        if life <= 0.405 then
            return
        end
        SetWidgetLife(R.hero, math.min(BlzGetUnitMaxHP(R.hero), life + amount))
    end

    -- Life steal heals from every hit, so an area spell on a pack would heal
    -- without end: it heals up to LIFESTEAL_CAP of the hero's maximum health
    -- a second (a budget that refills, one second's worth at most).
    function G.leech(amount)
        local cap = CFG.LIFESTEAL_CAP * BlzGetUnitMaxHP(R.hero)
        local budget = math.min(cap, (R.leechBudget or cap) + (R.time - (R.leechAt or R.time)) * cap)
        local heal = math.min(amount, budget)
        R.leechBudget, R.leechAt = budget - heal, R.time
        G.heal(heal)
    end

    function G.addGold(amount)
        R.gold = R.gold + amount * (1 + R.stats.gold)
    end

    ---------------------------------------------------------------------------
    -- World objects (after the campaign's Forgotten Hollow): chests, shrines
    -- and treasure lying in the arena. Walking up to one uses it. Stock 1.29
    -- doodads and items, a golden light over each and a yellow ring on the
    -- ground (an engine telegraph that never fills; Reforged shows no ring).
    -- Paid ones cost run gold, more for every chest opened, and show the price.
    ---------------------------------------------------------------------------
    local WORLD_OBJECTS = {
        chest = {name = 'Wooden Chest', model = FX.chest, scale = 2.0},
        barrel = {name = 'Barrel', model = {
            'Buildings\\Other\\BarrelsUnit1\\BarrelsUnit1.mdl',
            'Buildings\\Other\\BarrelsUnit\\BarrelsUnit.mdl',
            'Buildings\\Other\\BarrelsUnit0\\BarrelsUnit0.mdl'}, scale = 1.0},
        treasure = {name = 'Pile of Treasure', model = {
            'Doodads\\Dungeon\\Props\\TreasurePile\\TreasurePile0.mdl',
            'Doodads\\Dungeon\\Props\\TreasurePile\\TreasurePile1.mdl'}, scale = 1.0},
        wealth = {name = 'Standard of Wealth', model = {
            'Doodads\\Outland\\Props\\Standard\\Standard0.mdl',
            'Doodads\\Outland\\Props\\Standard\\Standard1.mdl'}, scale = 1.35},
        -- The campaign's Gold Vein is a rock; a loaded mine cart reads as gold.
        vein = {name = 'Mine Cart', model = 'Doodads\\Dungeon\\Props\\MineCart\\MineCart.mdl', scale = 1.1},
        chance = {name = 'Shrine of Chance', model = 'Doodads\\Ruins\\Props\\RuinFountain\\RuinFountain.mdl', scale = 0.9},
        protection = {name = 'Shrine of Protection', model = 'Doodads\\Ruins\\Props\\Statue\\Statue0.mdl', scale = 0.85}
    }
    local WORLD_OBJECT_KINDS = {'barrel', 'treasure', 'vein', 'chest', 'chance', 'protection', 'wealth'}

    -- Price of a paid object: chests climb with every chest (or shrine) used.
    function G.worldObjectPrice(object)
        -- Lua's ^ gives a float: whole gold, or the label reads "40.0 gold".
        local base = math.floor((R.worldChestsOpened + 1) ^ 2 * 40 + 0.5)
        if object.kind == 'chest' then
            return base
        elseif object.kind == 'chance' then
            return math.floor(base * 0.68)
        end
        return nil
    end

    function G.updateWorldObjectPrice(object)
        local cost = G.worldObjectPrice(object)
        if cost == nil or object.price == cost then
            return
        end
        object.price = cost
        if object.priceTag == nil then
            object.priceTag = CreateTextTag()
        end
        if object.priceTag then
            SetTextTagText(object.priceTag, U.col(GOLD, tostring(cost) .. ' gold'), 0.026)
            SetTextTagPos(object.priceTag, object.x - 60, object.y, 210)
            SetTextTagVelocity(object.priceTag, 0, 0)
            SetTextTagPermanent(object.priceTag, true)
            SetTextTagVisibility(object.priceTag, true)
        end
    end

    function G.updateWorldObjectPrices()
        for _, object in ipairs(R.interactables) do
            G.updateWorldObjectPrice(object)
        end
    end

    -- Open walkable ground for an object, away from the others.
    function G.worldObjectPoint(minR, maxR)
        local x, y
        for _ = 1, 10 do
            x, y = G.spawnPoint(minR, maxR)
            local clear = G.walkable(x, y)
            for _, other in ipairs(R.interactables) do
                local dx, dy = other.x - x, other.y - y
                if dx * dx + dy * dy < 250 * 250 then
                    clear = false
                end
            end
            if clear then
                break
            end
        end
        return x, y
    end

    function G.spawnWorldObject(kind, x, y, force)
        local def = WORLD_OBJECTS[kind]
        if R == nil or def == nil or (#R.interactables >= CFG.MAX_WORLD_OBJECTS and not force) then
            return nil
        end
        local model = def.model
        if type(model) == 'table' then
            model = model[GetRandomInt(1, #model)]
        end
        local fx = AddSpecialEffect(model, x, y)
        BlzSetSpecialEffectScale(fx, def.scale)
        local glow = AddSpecialEffect(FX.objectGlow, x, y)
        local object = {kind = kind, name = def.name, x = x, y = y, fx = fx, glow = glow, active = true,
            expires = R.time + 100, time = 0, progress = 0, nextHint = 0}
        object.ring = G.objectRing(x, y)
        R.interactables[#R.interactables + 1] = object
        G.updateWorldObjectPrice(object)
        return object
    end

    -- The yellow ground ring under an object, for as long as it lies there.
    function G.objectRing(x, y)
        if Engine.active() and type(rawget(_G, 'EngineTelegraph')) == 'function' then
            return EngineTelegraph({shape = 'ring', x = x, y = y, radius = 96, inner = 78, duration = 100000,
                r = 255, g = 214, b = 60, a = 200, flash = false})
        end
        return nil
    end

    function G.removeWorldObject(object)
        if object == nil or not object.active then
            return
        end
        object.active = false
        DestroyEffect(object.fx)
        DestroyEffect(object.glow)
        if object.ring then
            G.cancelTelegraph(object.ring)
            object.ring = nil
        end
        if object.priceTag then
            DestroyTextTag(object.priceTag)
            object.priceTag = nil
        end
        local list = R.interactables
        for i, item in ipairs(list) do
            if item == object then
                table.remove(list, i)
                break
            end
        end
        if R.protectionShrine == object then
            R.protectionShrine = nil
        end
    end

    -- Paid objects take run gold; without enough, a hint at most every 2.5 s.
    function G.spendRunGold(cost, object)
        if R.gold < cost then
            if R.time >= object.nextHint then
                Hud.banner(U.col(RED, 'Not enough gold') .. '  -  ' .. object.name .. ' costs ' .. cost)
                object.nextHint = R.time + 2.5
            end
            return false
        end
        R.gold = R.gold - cost
        return true
    end

    function G.activateWorldObject(object)
        if not object.active or object.challenge then
            return
        end
        local kind = object.kind
        if kind == 'chest' or kind == 'chance' then
            local cost = G.worldObjectPrice(object)
            if not G.spendRunGold(cost, object) then
                return
            end
            R.worldChestsOpened = R.worldChestsOpened + 1
            if kind == 'chest' or GetRandomReal(0, 1) < 0.55 then
                R.pendingChests = R.pendingChests + 1
                Hud.banner(U.col(GOLD, kind == 'chest' and 'Wooden Chest opened' or 'The fountain grants a card hand')
                    .. '  -  ' .. cost .. ' gold')
                G.after(0.3, G.tryOpenHand)
            else
                Hud.banner(U.col('bfb6a8', 'The fountain keeps your offering') .. '  -  ' .. cost .. ' gold')
            end
            G.fx(FX.teleport, object.x, object.y, 0.8)
            G.removeWorldObject(object)
            G.updateWorldObjectPrices()
        elseif kind == 'protection' then
            if R.protectionShrine then
                if R.time >= object.nextHint then
                    Hud.banner(U.col('bfb6a8', 'Another shrine of protection is already awake'))
                    object.nextHint = R.time + 2.5
                end
                return
            end
            object.challenge = true
            object.time = 18
            object.progress = 0
            object.expires = R.time + 30
            R.protectionShrine = object
            Hud.banner(U.col('ffe680', 'Protect the shrine') .. '  -  keep enemies away from it for 10 seconds')
        else
            local ranges = {vein = {50, 100}, barrel = {15, 25}, treasure = {100, 200}, wealth = {250, 500}}
            local range = ranges[kind]
            local amount = GetRandomInt(range[1], range[2])
            G.addGold(amount)
            Hud.banner(U.col(GOLD, object.name) .. '  -  ' .. amount .. ' gold')
            G.fx((kind == 'vein' or kind == 'barrel') and FX.explosion or FX.teleport, object.x, object.y, 0.5)
            G.removeWorldObject(object)
        end
    end

    function G.updateWorldObjects(dt)
        local list = R.interactables
        local reach = CFG.WORLD_OBJECT_REACH
        -- The nearest object in reach is used (one per tick).
        local nearby, nearbyD = nil, reach * reach
        for _, object in ipairs(list) do
            if not object.challenge then
                local dx, dy = R.hx - object.x, R.hy - object.y
                local d2 = dx * dx + dy * dy
                if d2 <= nearbyD then
                    nearby, nearbyD = object, d2
                end
            end
        end
        if nearby then
            G.activateWorldObject(nearby)
        end
        local i = 1
        while i <= #list do
            local object = list[i]
            if object.challenge then
                -- Shrine of Protection: 10 s with no enemy within 230 of it,
                -- before its 18 s run out; pressure drains the progress.
                object.time = object.time - dt
                if G.countInRange(object.x, object.y, 230) > 0 then
                    object.progress = math.max(0, object.progress - dt * 2)
                else
                    object.progress = object.progress + dt
                end
                if R.time >= object.nextHint then
                    object.nextHint = R.time + 2
                    Hud.banner(U.col('ffe680', 'Protect the shrine') .. '  -  '
                        .. math.ceil(math.max(0, 10 - object.progress)) .. ' seconds')
                end
                if object.progress >= 10 then
                    G.addGold(100)
                    G.heal(BlzGetUnitMaxHP(R.hero) * 0.15)
                    G.fx(FX.holyLight, object.x, object.y, 1.0)
                    Hud.banner(U.col(GREEN, 'Shrine protected') .. '  -  100 gold and healing')
                    G.removeWorldObject(object)
                elseif object.time <= 0 or R.time >= object.expires then
                    Hud.banner(U.col('bfb6a8', 'The shrine falls silent'))
                    G.removeWorldObject(object)
                end
            elseif R.time >= object.expires then
                G.removeWorldObject(object)
            end
            if list[i] == object then
                i = i + 1
            end
        end
        if R.time >= R.objectClock then
            R.objectClock = R.time + GetRandomReal(58, 78)
            if #list < CFG.MAX_WORLD_OBJECTS then
                local x, y = G.worldObjectPoint(360, 700)
                G.spawnWorldObject(WORLD_OBJECT_KINDS[GetRandomInt(1, #WORLD_OBJECT_KINDS)], x, y)
            end
        end
    end

    function G.clearWorldObjects()
        while #R.interactables > 0 do
            G.removeWorldObject(R.interactables[1])
        end
    end

    -- Every damage instance in the game passes through here.
    function G.onDamage()
        if R == nil or R.ended then
            return
        end
        local target = BlzGetEventDamageTarget()
        local source = GetEventDamageSource()
        local amount = GetEventDamage()
        if R.images[target] then
            -- Mirror Images are illusions: every hit on them counts triple.
            if amount > 0 then
                BlzSetEventDamage(amount * CFG.IMAGE_DAMAGE_TAKEN)
            end
            return
        end
        if target == R.hero then
            if amount <= 0 then
                return
            end
            local s = R.stats
            if s.dodge > 0 and GetRandomReal(0, 1) < s.dodge then
                BlzSetEventDamage(0)
                if CFG.DAMAGE_NUMBERS then
                    G.floatText(R.hx, R.hy, 'Dodge', 9, 180, 220, 255)
                end
                return
            end
            amount = amount * (1 - s.dr)
            local maxHp = BlzGetUnitMaxHP(R.hero)
            -- Necklace of Spell Immunity: a heavy hit now and then does nothing.
            if s.spellWard > 0 and amount >= 0.1 * maxHp and R.time >= R.wardReady then
                R.wardReady = R.time + 15
                BlzSetEventDamage(0)
                local shield = AddSpecialEffectTarget(FX.divineShield, R.hero, 'origin')
                G.after(1.0, function()
                    DestroyEffect(shield)
                end)
                if CFG.DAMAGE_NUMBERS then
                    G.floatText(R.hx, R.hy, 'Immune', 9, 255, 230, 140)
                end
                return
            end
            if s.thorns > 0 and source and R.enemies[source] then
                local attacker = source
                local thorns = s.thorns * (1 + s.damage)
                G.after(0, function()
                    G.damage(attacker, thorns, 'thorns', false)
                end)
            end
            if s.frostguard > 0 and source and R.enemies[source] then
                G.slow(source, s.frostguard, 3.0)
            end
            -- Kelen's Dagger and the Staff of Sanctuary answer a hit that
            -- would leave the hero under 30 percent health.
            local life = GetWidgetLife(R.hero)
            if life - amount < 0.3 * maxHp then
                if s.escape > 0 and R.time >= R.escapeReady then
                    R.escapeReady = R.time + 30
                    BlzSetEventDamage(0)
                    G.after(0, G.escape)
                    return
                end
                if s.sanctuary > 0 and R.time >= R.sanctuaryReady then
                    R.sanctuaryReady = R.time + 60
                    SetWidgetLife(R.hero, math.min(maxHp, life + maxHp * s.sanctuary))
                    DestroyEffect(AddSpecialEffectTarget(FX.healingWave, R.hero, 'origin'))
                end
            end
            if amount >= GetWidgetLife(R.hero) - 1 and R.livesUsed < s.lives then
                BlzSetEventDamage(0)
                G.revive()
                return
            end
            BlzSetEventDamage(amount)
            R.damageTaken = R.damageTaken + amount
            -- Blood splashes off the hero (at most one every HIT_FEEDBACK).
            if amount > 0 and R.time >= R.hitFeedbackAt then
                R.hitFeedbackAt = R.time + CFG.HIT_FEEDBACK
                DestroyEffect(AddSpecialEffectTarget(FX.heroBlood, R.hero, 'origin'))
            end
            return
        end

        local key = R.dmgSource
        if key == nil then
            if source == R.hero then
                key = 'attack'
            elseif source and R.summons[source] then
                key = R.summons[source].key
                -- Warsong Battle Drums.
                if R.stats.summonDamage > 0 and amount > 0 then
                    amount = amount * (1 + R.stats.summonDamage)
                    BlzSetEventDamage(amount)
                end
            end
        end
        if key and R.enemies[target] then
            local dealt = math.min(amount, GetWidgetLife(target))
            R.meter[key] = (R.meter[key] or 0) + dealt
            R.damageDone = R.damageDone + dealt
            if R.stats.lifesteal > 0 then
                G.leech(dealt * R.stats.lifesteal)
            end
            -- Every hit shows its number (damage over time ticks do not).
            -- The game shows 100 text tags at once: an area spell hitting a
            -- pack would take them all and the numbers would flicker. Each
            -- source shows a few numbers every quarter second, crits first.
            if R.time >= (R.numbersAt or 0) then
                R.numbersAt, R.numbers = R.time + 0.25, {}
            end
            local shown = R.numbers[key] or 0
            if CFG.DAMAGE_NUMBERS and not R.dmgTick and amount >= 1
                and shown < (R.dmgCrit and CFG.NUMBERS_PER_SOURCE + 2 or CFG.NUMBERS_PER_SOURCE) then
                R.numbers[key] = shown + 1
                local x, y = GetUnitX(target), GetUnitY(target)
                if R.dmgCrit then
                    G.floatText(x, y, U.num(amount) .. '!', 12, 255, 150, 40)
                else
                    G.floatText(x, y, U.num(amount), 9, 255, 240, 200)
                end
            end
        end
    end

    function G.revive()
        R.livesUsed = R.livesUsed + 1
        SetWidgetLife(R.hero, BlzGetUnitMaxHP(R.hero) * 0.5)
        R.invulnUntil = math.max(R.invulnUntil, R.time + 2.5)
        DestroyEffect(AddSpecialEffectTarget(FX.resurrect, R.hero, 'origin'))
        G.inRange(R.hx, R.hy, 400, function(u)
            G.damage(u, 200 * (1 + R.stats.damage), 'revive', false)
            G.stun(u, 1.5)
        end)
        Hud.banner(U.col(GOLD, 'Second chance!') .. '  You rise again.')
    end

    -- Kelen's Dagger of Escape: a blink away from the enemies close by, to
    -- the first walkable spot of eight directions, and a moment of safety.
    function G.escape()
        if R == nil or R.ended then
            return
        end
        local ax, ay = 0, 0
        G.inRange(R.hx, R.hy, 500, function(_, x, y)
            ax, ay = ax + (R.hx - x), ay + (R.hy - y)
        end)
        local angle = (ax == 0 and ay == 0) and GetRandomReal(0, TWO_PI) or Atan2(ay, ax)
        for k = 0, 7 do
            local a = angle + (k // 2 + math.fmod(k, 2)) * (math.fmod(k, 2) == 0 and -1 or 1) * TWO_PI / 8
            local x = U.clamp(R.hx + math.cos(a) * 550, G.minX, G.maxX)
            local y = U.clamp(R.hy + math.sin(a) * 550, G.minY, G.maxY)
            if not IsTerrainPathable(x, y, PATHING_TYPE_WALKABILITY) then
                G.fx(FX.blink, R.hx, R.hy, 1.0)
                SetUnitX(R.hero, x)
                SetUnitY(R.hero, y)
                R.hx, R.hy = x, y
                R.clickX, R.clickY = nil, nil
                G.fx(FX.blink, x, y, 1.0)
                break
            end
        end
        R.invulnUntil = math.max(R.invulnUntil, R.time + 1.5)
    end

    -- Orb of Darkness: a skeleton rises from a kill and fights for a while.
    function G.raiseMinion(x, y)
        local alive = 0
        for _ in pairs(R.summons) do
            alive = alive + 1
        end
        if alive >= CFG.MAX_SUMMONS then
            return
        end
        local u = CreateUnit(G.PLAYER, FourCC('uske'), x, y, 270)
        if u == nil then
            return
        end
        UnitApplyTimedLife(u, FourCC('BTLF'), 20)
        BlzSetUnitBaseDamage(u, math.max(1, math.floor(R.stats.attackDamage * 0.5)), 0)
        local hp = math.floor(200 * R.stats.spellPower)
        BlzSetUnitMaxHP(u, hp)
        SetWidgetLife(u, hp)
        G.fx(FX.animateDead, x, y, 0.8)
        if R.paused then
            PauseUnit(u, true)
        end
        R.summons[u] = {key = 'darkOrb'}
        local target = G.nearest(x, y, 1200, 1)[1]
        if target then
            IssuePointOrder(u, 'attack', target.x, target.y)
        end
    end

    ---------------------------------------------------------------------------
    -- Enemies
    ---------------------------------------------------------------------------
    function G.spawnPoint(minR, maxR)
        for _ = 1, 8 do
            local angle = GetRandomReal(0, TWO_PI)
            local radius = GetRandomReal(minR, maxR)
            local x = R.hx + math.cos(angle) * radius
            local y = R.hy + math.sin(angle) * radius
            if x > G.minX and x < G.maxX and y > G.minY and y < G.maxY
                and not IsTerrainPathable(x, y, PATHING_TYPE_WALKABILITY) then
                return x, y
            end
        end
        return U.clamp(R.hx + GetRandomReal(-maxR, maxR), G.minX, G.maxX),
            U.clamp(R.hy + GetRandomReal(-maxR, maxR), G.minY, G.maxY)
    end

    -- WoW difficulty for a run. Mythic+ compounds 10 percent health and 8 percent damage per
    -- keystone level, with no upper limit.
    function G.difficulty(index, keyLevel)
        local base = DIFFICULTIES[index]
        local d = {index = index, key = base.key, name = base.name, hex = base.hex, hp = base.hp, dmg = base.dmg,
            reward = base.reward, ilvl = base.ilvl, level = 0}
        if base.key == 'mplus' then
            local level = math.max(2, keyLevel or 2)
            d.level = level
            d.name = 'Mythic +' .. level
            d.hp = base.hp * 1.10 ^ (level - 1)
            d.dmg = base.dmg * 1.08 ^ (level - 1)
            d.reward = base.reward + 0.15 * (level - 1)
            -- Loot item level stops climbing at +10, like the end-of-dungeon chest.
            d.ilvl = base.ilvl + 2 * math.min(level, 10)
        end
        return d
    end

    -- How far through the run: 0 at the start, 1 when the final boss arrives.
    function G.progress()
        return math.max(0, R.time / CFG.RUN_LENGTH)
    end

    -- Endless mode's health and damage multipliers: they compound with every
    -- minute since the final boss fell (1, 1 outside endless mode).
    function G.endlessScale()
        if not R.endless then
            return 1, 1
        end
        local minutes = (R.time - R.endlessAt) / 60
        return CFG.ENDLESS_HP ^ minutes, CFG.ENDLESS_DMG ^ minutes
    end

    -- Three neighbouring roster tiers that walk up the roster in thirty steps.
    function G.wavePool()
        local n = #R.zone.enemies
        local step = math.floor(G.progress() * 30)
        local span = math.max(0, n - 3)
        local low = math.min(span, math.floor(math.max(0, step - 1) * span / 27))
        return low + 1, math.min(n, low + 3)
    end

    function G.pickEnemyType()
        local low, high = G.wavePool()
        return R.zone.enemies[GetRandomInt(low, high)]
    end

    -- How many enemies the spawner keeps alive. The curve eases in: about 14
    -- at 1:30, 36 at 4:00, 88 at 8:00 and 120 when the final boss comes,
    -- fewer in the first zones (zone.density).
    function G.targetAlive()
        if R.endless then
            return CFG.MAX_ENEMIES
        end
        local density = R.zone.density or 1
        return math.min(CFG.MAX_ENEMIES, math.floor(8 + 112 * density * G.progress() ^ 1.5))
    end

    function G.createEnemy(def, x, y, opts)
        local facing = bj_RADTODEG * Atan2(R.hy - y, R.hx - x)
        local u = CreateUnit(G.ENEMY, FourCC(def.id), x, y, facing)
        if u == nil then
            u = CreateUnit(G.ENEMY, FourCC(R.zone.enemies[1].id), x, y, facing)
        end
        if u == nil then
            u = CreateUnit(G.ENEMY, FourCC('nwlt'), x, y, facing)
        end
        if u == nil then
            return nil
        end
        -- The original's scaling: health and damage grow with run progress on
        -- top of the roster's tier ladder, then the difficulty applies.
        local progress = G.progress()
        local minute = R.time / 60
        local zone, diff = R.zone, R.diff
        local hp, dmg
        if opts.boss then
            hp = opts.boss.hp * CFG.BOSS_HP * zone.power * diff.hp
            dmg = opts.boss.dmg * CFG.ENEMY_DMG * zone.power ^ 0.7 * diff.dmg
        else
            hp = def.hp * 1.12 ^ ((def.index or 1) - 1) * (1 + CFG.ENEMY_HP_GROWTH * progress ^ CFG.ENEMY_HP_CURVE)
                * zone.power * diff.hp * (opts.elite and CFG.ELITE_HP or 1)
            dmg = def.dmg * CFG.ENEMY_DMG * (1 + CFG.ENEMY_DMG_GROWTH * progress) * zone.power ^ 0.7 * diff.dmg
        end
        local endlessHp, endlessDmg = G.endlessScale()
        hp, dmg = hp * endlessHp, dmg * endlessDmg
        BlzSetUnitMaxHP(u, math.max(1, math.floor(hp)))
        SetWidgetLife(u, hp)
        BlzSetUnitBaseDamage(u, math.max(1, math.floor(dmg)), 0)
        BlzSetUnitArmor(u, opts.boss and 4 or 0)
        local speed = U.clamp(GetUnitDefaultMoveSpeed(u), 200, 300) * (1 + minute * 0.01)
        if opts.boss then
            speed = 270
        end
        SetUnitMoveSpeed(u, speed)
        IssueTargetOrder(u, 'attack', R.hero)
        if R.paused then
            PauseUnit(u, true)
        end
        local info = {xp = def.xp or 1, speed = speed, slowPct = 0, slowUntil = 0, stunUntil = 0, stunned = false,
            boss = opts.boss, final = opts.final, elite = opts.elite, target = R.hero, radius = G.unitRadius(u, 24)}
        R.enemies[u] = info
        R.enemyCount = R.enemyCount + 1
        return u, info
    end

    function G.spawnBoss(def, isFinal)
        local x, y = G.spawnPoint(650, 800)
        local u, info = G.createEnemy(def, x, y, {boss = def, final = isFinal})
        if u == nil then
            return
        end
        SetUnitScale(u, def.scale, def.scale, def.scale)
        -- A bigger body blocks more of the way (native collision ignores scale).
        info.radius = info.radius * math.min(def.scale or 1, 2)
        BlzSetUnitName(u, def.name)
        info.xp = isFinal and 80 or 40
        info.aura = AddSpecialEffectTarget(FX.bossAura, u, 'origin')
        info.slamAt = R.time + 5.0
        info.slamDamage = def.dmg * R.zone.power ^ 0.7 * R.diff.dmg * 2.2 * select(2, G.endlessScale())
        R.boss = u
        G.fx(FX.teleport, x, y, 1.5)
        if isFinal then
            Hud.banner(U.col(RED, def.name) .. ' has come. Defeat them to win!')
        else
            Hud.banner(U.col(RED, def.name) .. ' has entered the fight!')
        end
    end

    function G.spawnElite()
        local x, y = G.spawnPoint(800, 1000)
        local u, info = G.createEnemy(G.pickEnemyType(), x, y, {elite = true})
        if u then
            SetUnitScale(u, 1.4, 1.4, 1.4)
            info.radius = info.radius * 1.4
            SetUnitVertexColor(u, 255, 220, 90, 255)
            info.xp = 12
            info.aura = AddSpecialEffectTarget(FX.bossAura, u, 'origin')
        end
    end

    function G.updateSpawns(dt)
        -- Keep the horde topped up to the target, a few at a time; refills
        -- come slowly early on and faster as the run goes.
        R.spawnClock = R.spawnClock - dt
        if R.spawnClock <= 0 then
            R.spawnClock = 0.5 - 0.3 * math.min(1, G.progress())
            local target = G.targetAlive()
            if R.enemyCount < target then
                local n = math.min(3, math.ceil((target - R.enemyCount) / 6))
                for _ = 1, n do
                    local x, y = G.spawnPoint(950, 1250)
                    G.createEnemy(G.pickEnemyType(), x, y, {})
                end
            end
        end

        -- Half way between bosses, a closing ring of the moment's weakest.
        local ringsDue = math.floor((R.time + 60) / 120)
        if ringsDue > R.rings and (R.endless or not R.finalSpawned) then
            R.rings = ringsDue
            local weakest = R.zone.enemies[(G.wavePool())]
            local n = math.min(12 + math.floor(G.progress() * 40), CFG.MAX_ENEMIES + 40 - R.enemyCount)
            for i = 1, n do
                local angle = i / n * TWO_PI
                local x = U.clamp(R.hx + math.cos(angle) * 850, G.minX, G.maxX)
                local y = U.clamp(R.hy + math.sin(angle) * 850, G.minY, G.maxY)
                G.createEnemy(weakest, x, y, {})
            end
            if n > 0 then
                Hud.banner('They are surrounding you!')
            end
        end

        if R.time >= R.nextElite then
            R.nextElite = R.nextElite + (R.endless and CFG.ENDLESS_ELITE_EVERY or CFG.ELITE_EVERY)
            G.spawnElite()
        end

        -- Endless mode: the zone's bosses, then its final boss, come back in
        -- turn on a timer, each stronger with the endless minutes.
        if R.endless then
            if R.time >= R.nextEndlessBoss then
                R.nextEndlessBoss = R.time + CFG.ENDLESS_BOSS_EVERY
                local cycle = #R.zone.bosses + 1
                R.endlessBoss = math.fmod(R.endlessBoss, cycle) + 1
                G.spawnBoss(R.zone.bosses[R.endlessBoss] or R.zone.final, false)
            end
            return
        end

        local boss = R.zone.bosses[R.nextBoss]
        if boss and R.time >= boss.t then
            R.nextBoss = R.nextBoss + 1
            G.spawnBoss(boss, false)
        end
        if not R.finalSpawned and R.time >= CFG.RUN_LENGTH then
            R.finalSpawned = true
            R.finalAt = R.time
            G.spawnBoss(R.zone.final, true)
        end
    end

    -- Slow/stun/dot upkeep, leash and re-orders. Runs four times a second.
    function G.updateEnemies()
        local t = R.time
        local hx, hy = R.hx, R.hy
        local burns = {}
        for u, info in pairs(R.enemies) do
            if info.stunned and t >= info.stunUntil then
                info.stunned = false
                G.updateHeld(u, info)
            end
            if info.slowPct > 0 and t >= info.slowUntil then
                info.slowPct = 0
                SetUnitMoveSpeed(u, info.speed)
            end
            if info.dots then
                for source, d in pairs(info.dots) do
                    if t >= d.untilT then
                        info.dots[source] = nil
                    else
                        burns[#burns + 1] = {u, d.dps * 0.25, source}
                    end
                end
            end
            local x, y = GetUnitX(u), GetUnitY(u)
            local dx, dy = x - hx, y - hy
            if dx * dx + dy * dy > 2000 * 2000 and not info.boss then
                local nx, ny = G.spawnPoint(900, 1100)
                SetUnitPosition(u, nx, ny)
                info.target = R.hero
                IssueTargetOrder(u, 'attack', R.hero)
            elseif not info.stunned and not info.casting then
                -- Mirror Images draw every enemy near them away from the hero.
                local want = G.decoyNear(x, y, CFG.DECOY_REACH) or R.hero
                if want ~= info.target or GetUnitCurrentOrder(u) == 0 then
                    info.target = want
                    IssueTargetOrder(u, 'attack', want)
                end
            end
            if info.boss and t >= info.slamAt and not info.stunned and not info.casting then
                info.slamAt = t + (info.final and 5.5 or 6.5)
                G.bossCast(u, info)
            end
        end
        R.dmgTick = true
        for _, burn in ipairs(burns) do
            G.damage(burn[1], burn[2], burn[3], false)
        end
        R.dmgTick = false
    end

    -- Ground telegraphs, World of Warcraft style: the shape is drawn on the
    -- ground, a fill sweeps from its origin to the edge over the cast and the hit
    -- lands on whoever still stands inside when it flashes. spec: shape ('circle'
    -- radius, 'ring' radius + inner hole, 'cone' radius + arc in degrees, 'line'
    -- length + width), x, y (center, or the start of a cone or line), angle in
    -- degrees, duration (the cast, seconds). The engine draws it (EngineTelegraph,
    -- returns an id); Reforged marks the area with Flame Strike art instead.
    function G.telegraph(spec)
        if Engine.active() and type(rawget(_G, 'EngineTelegraph')) == 'function' then
            return EngineTelegraph(spec)
        end
        local a = math.rad(spec.angle or 0)
        local ca, sa = math.cos(a), math.sin(a)
        if spec.shape == 'line' then
            local n = math.max(2, math.floor(spec.length / 160))
            for i = 0, n - 1 do
                local d = (i + 0.5) * spec.length / n
                G.timedFx(FX.warning, spec.x + ca * d, spec.y + sa * d, spec.width / 150, spec.duration)
            end
        elseif spec.shape == 'cone' then
            for _, f in ipairs({0.4, 0.75}) do
                local d = spec.radius * f
                G.timedFx(FX.warning, spec.x + ca * d, spec.y + sa * d,
                    math.max(0.8, d * math.sin(math.rad(spec.arc / 2)) / 150), spec.duration)
            end
        elseif spec.shape == 'ring' then
            local mid = (spec.radius + spec.inner) / 2
            for i = 0, 7 do
                G.timedFx(FX.warning, spec.x + mid * math.cos(i * math.pi / 4), spec.y + mid * math.sin(i * math.pi / 4),
                    (spec.radius - spec.inner) / 300, spec.duration)
            end
        else
            G.timedFx(FX.warning, spec.x, spec.y, spec.radius / 150, spec.duration)
        end
        return 0
    end

    -- Fades a telegraph out early, without its impact flash (the caster died).
    function G.cancelTelegraph(id)
        if id and id ~= 0 and type(rawget(_G, 'EngineTelegraphStop')) == 'function' then
            EngineTelegraphStop(id, 0.25)
        end
    end

    -- Whether a point lies inside a telegraph's shape, give or take the hero's size.
    function G.inTelegraph(spec, px, py)
        local pad = 24
        local a = math.rad(spec.angle or 0)
        local dx, dy = px - spec.x, py - spec.y
        local fx, fy = dx * math.cos(a) + dy * math.sin(a), dy * math.cos(a) - dx * math.sin(a)
        if spec.shape == 'line' then
            return fx >= -pad and fx <= spec.length + pad and math.abs(fy) <= spec.width / 2 + pad
        end
        local d = math.sqrt(dx * dx + dy * dy)
        if spec.shape == 'ring' then
            return d <= spec.radius + pad and d >= spec.inner - pad
        elseif spec.shape == 'cone' then
            return d <= spec.radius + pad and (d < 2 * pad or math.abs(math.atan(fy, fx)) <= math.rad(spec.arc / 2) + pad / d)
        end
        return d <= spec.radius + pad
    end

    -- Boss spells, cast in turn every few seconds (G.updateEnemies). cast: the
    -- telegraph's duration; dmg: times the boss's slam damage. Slam lands under
    -- the hero; cleave is a cone from the boss toward the hero; charge is a line
    -- the boss rushes along; nova is a ring around the boss whose middle is safe.
    -- The boss stands still while it casts the aimed ones.
    G.bossSpells = {
        slam = {cast = 1.3, dmg = 1.0},
        cleave = {cast = 1.6, dmg = 1.1, radius = 480, arc = 80},
        charge = {cast = 1.4, dmg = 0.9, width = 170},
        nova = {cast = 2.0, dmg = 1.0, radius = 560, inner = 200},
    }
    G.bossKits = {
        boss = {'slam', 'cleave', 'slam', 'charge'},
        final = {'slam', 'cleave', 'nova', 'charge'},
    }

    function G.bossCast(u, info)
        local kit = info.final and G.bossKits.final or G.bossKits.boss
        info.kitStep = math.fmod(info.kitStep or 0, #kit) + 1
        local key = kit[info.kitStep]
        local spell = G.bossSpells[key]
        local bx, by = GetUnitX(u), GetUnitY(u)
        local hx, hy = R.hx, R.hy
        local facing = math.deg(math.atan(hy - by, hx - bx))
        local spec
        if key == 'cleave' then
            spec = {shape = 'cone', x = bx, y = by, angle = facing, radius = spell.radius, arc = spell.arc}
        elseif key == 'charge' then
            local dist = math.sqrt((hx - bx) * (hx - bx) + (hy - by) * (hy - by))
            spec = {shape = 'line', x = bx, y = by, angle = facing, length = math.min(dist + 250, 1000), width = spell.width}
        elseif key == 'nova' then
            spec = {shape = 'ring', x = bx, y = by, radius = spell.radius, inner = spell.inner}
        else
            spec = {shape = 'circle', x = hx, y = hy, radius = 240}
        end
        spec.duration = spell.cast
        info.telegraph = G.telegraph(spec)
        local rooted = key ~= 'slam'
        if rooted then
            info.casting = true
            BlzSetUnitFacingEx(u, facing)
            G.updateHeld(u, info)
        end
        local run = R
        G.after(spell.cast, function()
            if R ~= run or R.enemies[u] == nil then
                return
            end
            info.telegraph = nil
            if rooted then
                info.casting = false
                G.updateHeld(u, info)
            end
            G.bossImpact(u, info, key, spec)
            if spec.shape ~= 'line' and G.inTelegraph(spec, R.hx, R.hy) then
                UnitDamageTarget(u, R.hero, info.slamDamage * spell.dmg, false, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            end
        end)
    end

    -- The art of a boss spell's hit; a charge also moves the boss down its line
    -- and hurts the hero if it is still in the way.
    function G.bossImpact(u, info, key, spec)
        local a = math.rad(spec.angle or 0)
        if key == 'slam' then
            G.fx(FX.warStomp, spec.x, spec.y, 1.4)
        elseif key == 'cleave' then
            SetUnitAnimation(u, 'attack slam')
            for _, f in ipairs({0.35, 0.65, 0.9}) do
                G.fx(FX.incinerate, spec.x + math.cos(a) * spec.radius * f, spec.y + math.sin(a) * spec.radius * f, 0.9)
            end
        elseif key == 'nova' then
            SetUnitAnimation(u, 'spell slam')
            for i = 0, 11 do
                local r = (spec.radius + spec.inner) / 2
                G.fx(FX.warStomp, spec.x + r * math.cos(i * math.pi / 6), spec.y + r * math.sin(i * math.pi / 6), 0.9)
            end
        elseif key == 'charge' then
            local hit = G.inTelegraph(spec, R.hx, R.hy)
            local steps = 6
            local run = R
            local stopped = false
            for i = 1, steps do
                G.after(0.05 * i, function()
                    if R ~= run or R.enemies[u] == nil or stopped then
                        return
                    end
                    -- The rush stops at a tree, a cliff or the map's edge.
                    local d = spec.length * i / steps
                    local x, y = spec.x + math.cos(a) * d, spec.y + math.sin(a) * d
                    if not G.walkable(x, y) then
                        stopped = true
                        return
                    end
                    SetUnitPosition(u, x, y)
                    G.fx(FX.stampede, x, y, 0.8)
                end)
            end
            if hit then
                UnitDamageTarget(u, R.hero, info.slamDamage * G.bossSpells.charge.dmg, false, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            end
        end
    end

    function G.onDeath()
        if R == nil then
            return
        end
        local u = GetTriggerUnit()
        local info = R.enemies[u]
        if info == nil then
            if R.summons[u] then
                R.summons[u] = nil
            end
            if R.images[u] then
                -- A fallen image vanishes like Warcraft III's (no corpse).
                R.images[u] = nil
                G.fx(FX.mirrorImage, GetUnitX(u), GetUnitY(u), 0.8)
                RemoveUnit(u)
            end
            return
        end
        R.enemies[u] = nil
        R.enemyCount = R.enemyCount - 1
        G.updateHeld(u, info)
        if info.telegraph then
            G.cancelTelegraph(info.telegraph)
            info.telegraph = nil
        end
        if info.aura then
            DestroyEffect(info.aura)
        end
        if R.ended then
            return
        end
        R.kills = R.kills + 1
        local x, y = GetUnitX(u), GetUnitY(u)
        local s = R.stats
        G.dropXp(x, y, info.xp * CFG.XP_RATE)
        if s.killHeal > 0 then
            G.heal(s.killHeal)
        end
        if s.killGold > 0 and GetRandomReal(0, 1) < s.killGold then
            G.addGold(1)
        end
        if s.thirst > 0 then
            R.thirstUntil = R.time + 3.0
        end
        if s.souls > R.souls then
            R.soulKills = R.soulKills + 1
            if R.soulKills >= 25 then
                R.soulKills = 0
                R.souls = R.souls + 1
                G.recomputeStats()
            end
        end
        if s.darkMinion > 0 and GetRandomReal(0, 1) < s.darkMinion then
            G.raiseMinion(x, y)
        end
        local roll = GetRandomReal(0, 1)
        if roll < 0.002 then
            G.dropPickup('magnet', x, y, 0)
        elseif roll < 0.014 then
            G.dropPickup('heal', x, y, 0)
        elseif roll < 0.018 then
            G.dropPickup('mana', x, y, 0)
        elseif roll < 0.08 then
            G.dropPickup('gold', x, y, GetRandomInt(1, 3))
        end
        if info.elite then
            -- Some elites carry a chest (a card hand); the others a pile of gold.
            if GetRandomReal(0, 1) < CFG.ELITE_CHEST then
                G.dropPickup('chest', x, y, 0)
            else
                G.dropPickup('gold', x, y, GetRandomInt(8, 15))
            end
        end
        if info.boss then
            G.onBossDeath(u, info, x, y)
        end
        if s.explode > 0 and not R.exploding then
            R.exploding = true
            G.fx(FX.incinerate, x, y, 0.8)
            G.inRange(x, y, 170 * (1 + s.area), function(other)
                G.damage(other, s.explode * (1 + s.damage), 'incinerate', false)
            end)
            R.exploding = false
        end
        R.corpses[u] = true
        local run = R
        G.after(3.0, function()
            if run.corpses[u] then
                run.corpses[u] = nil
                RemoveUnit(u)
            end
        end)
    end

    function G.onBossDeath(u, info, x, y)
        R.bosses = R.bosses + 1
        G.fx(FX.explosion, x, y, 1.0)
        G.dropPickup('chest', x, y, 0)
        G.dropPickup('gold', x + 60, y, 25)
        local item = info.boss.item
        local chance = (R.diff.key == 'mplus' and 0.65 or 0.5) + 0.10 * Profile.perk('keen') + (info.final and 0.25 or 0)
        if item and GetRandomReal(0, 1) < chance then
            G.lootItem(item)
        end
        if R.boss == u then
            R.boss = nil
            for other, otherInfo in pairs(R.enemies) do
                if otherInfo.boss then
                    R.boss = other
                end
            end
        end
        if info.final then
            local run = R
            G.after(1.5, function()
                if R == run then
                    G.endRun(true)
                end
            end)
        end
    end

    ---------------------------------------------------------------------------
    -- Pickups: experience gems, gold, healing runes, magnets and chests
    ---------------------------------------------------------------------------
    -- Boss loot. A higher item level replaces the piece you own; a duplicate
    -- at or below it is salvaged for gold.
    function G.lootItem(item)
        local p = Profile.data
        local ilvl = item.baseIlvl + R.diff.ilvl
        local owned = p.gear[item.id]
        local icon = gearIcon(item)
        if owned == nil or ilvl > owned then
            p.gear[item.id] = ilvl
            R.loot[#R.loot + 1] = {item = item, ilvl = ilvl, previous = owned}
            -- A new item goes into a free inventory slot by itself.
            if owned == nil and gearSlotOf(p, item) == nil then
                for slot = 1, INVENTORY_SIZE do
                    if gearEquipped(p)[slot] == nil then
                        p.inv[tostring(slot)] = item.index
                        break
                    end
                end
            end
            local title = 'Loot: ' .. U.col(gearHex(ilvl), item.name) .. U.col(GREY, '  item level ' .. ilvl)
            if owned then
                title = title .. U.col(GREEN, '  (up from ' .. owned .. ')')
            end
            local detail = G.describeItem(item, ilvl)
            if item.effect then
                detail = detail .. ', ' .. U.col(GREEN, item.effect.name)
            end
            Hud.toast(icon, title, detail)
            Hud.refreshGear()
        else
            local gold = 10 * ZONES[item.zone].tier
            G.addGold(gold)
            Hud.toast(icon, U.col(GREY, item.name .. ' (' .. ilvl .. ')'), 'Already owned  -  salvaged for ' .. gold .. ' gold')
        end
    end

    function G.dropXp(x, y, value)
        if value >= 20 then
            G.dropPickup('xp', x, y, value, FX.gemLarge, 1.0)
        elseif value >= 4 then
            G.dropPickup('xp', x, y, value, FX.gemMedium, 0.75)
        else
            G.dropPickup('xp', x, y, value, FX.gemSmall, 0.55)
        end
    end

    function G.dropPickup(kind, x, y, value, model, scale)
        local list = R.pickups
        if #list >= CFG.MAX_PICKUPS then
            if kind == 'xp' then
                for i = #list, 1, -1 do
                    if list[i].kind == 'xp' then
                        list[i].value = list[i].value + value
                        return
                    end
                end
            elseif kind == 'gold' then
                G.addGold(value)
                return
            elseif kind ~= 'chest' then
                return
            end
        end
        if model == nil then
            if kind == 'gold' then
                model, scale = FX.coin, 0.6
            elseif kind == 'chest' then
                model, scale = FX.chest, 1.0
            else
                model, scale = FX.rune, 0.7
            end
        end
        local fx = AddSpecialEffect(model, x, y)
        BlzSetSpecialEffectScale(fx, scale or 1)
        BlzSetSpecialEffectZ(fx, G.groundZ(x, y) + 25)
        if kind == 'heal' then
            BlzSetSpecialEffectColor(fx, 255, 80, 80)
        elseif kind == 'mana' then
            BlzSetSpecialEffectColor(fx, 150, 110, 255)
        elseif kind == 'magnet' then
            BlzSetSpecialEffectColor(fx, 90, 170, 255)
        end
        list[#list + 1] = {kind = kind, x = x, y = y, value = value, fx = fx, flying = false, speed = 0}
    end

    function G.collect(p)
        if p.kind == 'xp' then
            G.gainXp(p.value)
        elseif p.kind == 'gold' then
            G.addGold(p.value)
        elseif p.kind == 'heal' then
            G.heal(BlzGetUnitMaxHP(R.hero) * 0.25)
            DestroyEffect(AddSpecialEffectTarget(FX.healingWave, R.hero, 'origin'))
        elseif p.kind == 'mana' then
            G.addMana(R.maxMana * CFG.MANA_RUNE)
            DestroyEffect(AddSpecialEffectTarget(FX.manaFlareHit, R.hero, 'origin'))
        elseif p.kind == 'magnet' then
            R.magnetUntil = R.time + 3.0
            Hud.banner('Every gem flies to you!')
        elseif p.kind == 'chest' then
            G.addGold(10)
            R.pendingChests = R.pendingChests + 1
            G.tryOpenHand()
        end
    end

    function G.updatePickups(dt)
        local list = R.pickups
        local hx, hy = R.hx, R.hy
        local r2 = R.pickupRange * R.pickupRange
        local magnet = R.time < R.magnetUntil
        local i = 1
        while i <= #list do
            local p = list[i]
            local dx, dy = hx - p.x, hy - p.y
            local d2 = dx * dx + dy * dy
            local collected = false
            if p.flying or d2 <= r2 or (magnet and p.kind == 'xp') then
                p.flying = true
                p.speed = math.min(p.speed + 2600 * dt, 1500)
                local d = math.sqrt(d2)
                local step = p.speed * dt
                if d <= step + 45 then
                    collected = true
                else
                    p.x = p.x + dx / d * step
                    p.y = p.y + dy / d * step
                    BlzSetSpecialEffectPosition(p.fx, p.x, p.y, G.groundZ(p.x, p.y) + 45)
                end
            end
            if collected then
                list[i] = list[#list]
                list[#list] = nil
                DestroyEffect(p.fx)
                G.collect(p)
                if R == nil or R.ended then
                    return
                end
            else
                i = i + 1
            end
        end
    end

    -- Wisp Companion perk: a wisp fetches experience gems and gold lying
    -- outside the pickup range; whatever it touches flies to the hero.
    function G.spawnCompanion()
        local rank = Profile.perk('companion')
        if rank <= 0 then
            return
        end
        local x, y = R.hx - 90, R.hy + 70
        local fx = AddSpecialEffect(FX.wisp, x, y)
        BlzSetSpecialEffectScale(fx, 0.75)
        R.companion = {fx = fx, x = x, y = y, speed = 380 + 90 * rank, reach = 900 + 250 * rank,
            target = nil, clock = 0, bob = 0}
    end

    -- The nearest gem or coin to the wisp within its reach of the hero.
    function G.companionTarget(c)
        local best, bestD = nil, nil
        local reach2 = c.reach * c.reach
        local near2 = R.pickupRange * R.pickupRange
        for _, p in ipairs(R.pickups) do
            if (p.kind == 'xp' or p.kind == 'gold') and not p.flying then
                local hx, hy = p.x - R.hx, p.y - R.hy
                local h2 = hx * hx + hy * hy
                if h2 <= reach2 and h2 > near2 then
                    local dx, dy = p.x - c.x, p.y - c.y
                    local d2 = dx * dx + dy * dy
                    if bestD == nil or d2 < bestD then
                        best, bestD = p, d2
                    end
                end
            end
        end
        return best
    end

    function G.updateCompanion(dt)
        local c = R.companion
        if c == nil then
            return
        end
        -- A target already on its way (pickup range, a magnet) is dropped.
        if c.target and c.target.flying then
            c.target = nil
        end
        c.clock = c.clock - dt
        if c.target == nil and c.clock <= 0 then
            c.clock = 0.25
            c.target = G.companionTarget(c)
        end
        local t = c.target
        local tx, ty, speed
        if t then
            tx, ty, speed = t.x, t.y, c.speed
        else
            -- Idle: floats behind the hero's shoulder, easing in.
            tx, ty = R.hx - 90, R.hy + 70
        end
        local dx, dy = tx - c.x, ty - c.y
        local d = math.sqrt(dx * dx + dy * dy)
        speed = speed or math.min(d * 4, c.speed * 2)
        local step = speed * dt
        if t and d <= step + 30 then
            t.flying = true
            c.target = nil
            c.x, c.y = t.x, t.y
        elseif d > 1 then
            local f = math.min(1, step / d)
            c.x, c.y = c.x + dx * f, c.y + dy * f
            BlzSetSpecialEffectYaw(c.fx, Atan2(dy, dx))
        end
        c.bob = c.bob + dt * 4
        BlzSetSpecialEffectPosition(c.fx, c.x, c.y, G.groundZ(c.x, c.y) + 80 + 12 * math.sin(c.bob))
    end

    -- The original's Vampire Survivors curve: cheap early, steeper after 20 and 40.
    -- Experience from one level to the next: grows faster with every level
    -- (about 30 levels in a 10-minute run).
    function G.xpFor(level)
        local k = level - 1
        return math.floor(5 + 9 * k + CFG.XP_CURVE * k * k)
    end

    function G.gainXp(amount)
        R.xp = R.xp + amount * (1 + R.stats.xp)
        local leveled = false
        while R.xp >= R.xpNext do
            R.xp = R.xp - R.xpNext
            R.level = R.level + 1
            R.xpNext = G.xpFor(R.level)
            R.pendingLevels = R.pendingLevels + 1
            leveled = true
            DestroyEffect(AddSpecialEffectTarget(FX.levelUp, R.hero, 'origin'))
        end
        -- Every level grows the hero's attributes, as in Warcraft III.
        if leveled then
            G.recomputeStats()
        end
        G.tryOpenHand()
    end

    ---------------------------------------------------------------------------
    -- Projectiles
    ---------------------------------------------------------------------------
    function G.launch(p)
        p.z = p.z or (G.groundZ(p.x, p.y) + 70)
        p.fx = AddSpecialEffect(p.model, p.x, p.y)
        if p.scale then
            BlzSetSpecialEffectScale(p.fx, p.scale)
        end
        BlzSetSpecialEffectPosition(p.fx, p.x, p.y, p.z)
        p.tz = p.tz or (G.groundZ(p.tx, p.ty) + 50)
        R.projectiles[#R.projectiles + 1] = p
    end

    function G.updateProjectiles(dt)
        local list = R.projectiles
        local i = 1
        while i <= #list do
            local p = list[i]
            if p.target and R.enemies[p.target] then
                p.tx, p.ty = GetUnitX(p.target), GetUnitY(p.target)
                p.tz = BlzGetUnitZ(p.target) + 50
            else
                p.target = nil
            end
            local dx, dy, dz = p.tx - p.x, p.ty - p.y, p.tz - p.z
            local dist = math.sqrt(dx * dx + dy * dy)
            local step = p.speed * dt
            if dist <= step + 10 then
                list[i] = list[#list]
                list[#list] = nil
                BlzSetSpecialEffectPosition(p.fx, p.tx, p.ty, p.tz)
                DestroyEffect(p.fx)
                if p.target then
                    p.onHit(p.target, p.tx, p.ty)
                end
                if R == nil or R.ended then
                    return
                end
            else
                local f = step / dist
                p.x = p.x + dx * f
                p.y = p.y + dy * f
                p.z = p.z + dz * f
                BlzSetSpecialEffectPosition(p.fx, p.x, p.y, p.z)
                BlzSetSpecialEffectYaw(p.fx, Atan2(dy, dx))
                i = i + 1
            end
        end
    end

    -- Piercing waves travelling in a straight line.
    function G.launchLine(p)
        p.dx, p.dy = math.cos(p.angle), math.sin(p.angle)
        p.left = p.range
        p.hit = {}
        p.trailStep = 0
        if p.model then
            p.fx = AddSpecialEffect(p.model, p.x, p.y)
            BlzSetSpecialEffectYaw(p.fx, p.angle)
            if p.scale then
                BlzSetSpecialEffectScale(p.fx, p.scale)
            end
        end
        R.lines[#R.lines + 1] = p
    end

    function G.updateLines(dt)
        local list = R.lines
        local i = 1
        while i <= #list do
            local p = list[i]
            local step = p.speed * dt
            p.x = p.x + p.dx * step
            p.y = p.y + p.dy * step
            p.left = p.left - step
            if p.fx then
                BlzSetSpecialEffectPosition(p.fx, p.x, p.y, G.groundZ(p.x, p.y) + 40)
            end
            if p.trail then
                p.trailStep = p.trailStep + step
                if p.trailStep >= 75 then
                    p.trailStep = 0
                    G.fx(p.trail, p.x, p.y, 1.0)
                end
            end
            G.inRange(p.x, p.y, p.width, function(u, x, y)
                if not p.hit[u] then
                    p.hit[u] = true
                    p.onHit(u, x, y)
                end
            end)
            if p.left <= 0 or p.x < G.minX or p.x > G.maxX or p.y < G.minY or p.y > G.maxY then
                list[i] = list[#list]
                list[#list] = nil
                if p.fx then
                    DestroyEffect(p.fx)
                end
            else
                i = i + 1
            end
            if R == nil or R.ended then
                return
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Spell behaviours
    ---------------------------------------------------------------------------
    local CAST = {}

    local function applyHitEffects(def, v, u)
        if def.slow then
            G.slow(u, def.slow, def.slowDur or 2.0)
        end
        if def.stun then
            G.stun(u, v.stun)
        end
        if def.dot then
            G.dot(u, v.dot, def.dotDur or 3.0, def.key)
        end
    end

    function G.boltHit(def, v, u, x, y, bounces, hitSet)
        G.damage(u, v.dmg, def.key)
        if def.impact then
            G.fx(def.impact, x, y, 1.0)
        end
        if def.splash then
            local splash = def.splash * (1 + R.stats.area)
            G.inRange(x, y, splash, function(other)
                if other ~= u then
                    G.damage(other, v.dmg * 0.5, def.key)
                    if def.slow then
                        G.slow(other, def.slow, def.slowDur or 2.0)
                    end
                end
            end)
            G.fx(FX.incinerate, x, y, 0.6)
        end
        applyHitEffects(def, v, u)
        if def.leech then
            G.heal(v.dmg * def.leech)
        end
        if def.manaGain then
            G.addMana(def.manaGain)
        end
        if bounces and bounces > 0 then
            hitSet = hitSet or {}
            hitSet[u] = true
            local nextTarget = G.nearest(x, y, 450, 1, hitSet)[1]
            if nextTarget then
                G.launch({model = def.missile, x = x, y = y, target = nextTarget.u, tx = nextTarget.x, ty = nextTarget.y,
                    speed = def.speed or 1000, scale = def.scale, onHit = function(nu, nx, ny)
                        G.boltHit(def, v, nu, nx, ny, bounces - 1, hitSet)
                    end})
            end
        end
    end

    CAST.bolt = function(inst, v)
        local def = inst.def
        local targets
        if def.prefersBoss then
            targets = G.priorityTargets(v.range, v.count)
        else
            targets = G.nearest(R.hx, R.hy, v.range, v.count)
        end
        if #targets == 0 then
            return false
        end
        for _, t in ipairs(targets) do
            if def.instant then
                G.boltHit(def, v, t.u, t.x, t.y)
            else
                G.launch({model = def.missile, x = R.hx, y = R.hy, target = t.u, tx = t.x, ty = t.y,
                    speed = def.speed or 1000, scale = def.scale, onHit = function(u, x, y)
                        G.boltHit(def, v, u, x, y, def.bounce)
                    end})
            end
        end
        return true
    end

    CAST.nova = function(inst, v)
        local def = inst.def
        local cx, cy = R.hx, R.hy
        if def.atTarget then
            local t = G.nearest(R.hx, R.hy, v.range, 1)[1]
            if t == nil then
                return false
            end
            cx, cy = t.x, t.y
            if def.key == 'blink_strike' then
                G.fx(FX.blink, R.hx, R.hy, 1.0)
            end
        elseif G.countInRange(cx, cy, v.radius) == 0 then
            return false
        end
        G.fx(def.fx, cx, cy, v.radius / 250)
        if def.images then
            G.mirrorImages(1 + math.min(3, inst.rank), v.radius)
        end
        G.inRange(cx, cy, v.radius, function(u)
            G.damage(u, v.dmg, def.key)
            applyHitEffects(def, v, u)
        end)
        return true
    end

    -- Bladestorm: a ring of slashes on the edge of the area, turning a little
    -- every wave. It sits on the damage radius, so area upgrades widen it.
    function G.bladeRing(x, y, radius, wave)
        local n = math.max(8, math.min(24, math.floor(TWO_PI * radius / 70)))
        local turn = wave * 0.4
        for k = 1, n do
            local angle = turn + TWO_PI * k / n
            local fx = AddSpecialEffect(FX.cleave, x + math.cos(angle) * radius * 0.85, y + math.sin(angle) * radius * 0.85)
            BlzSetSpecialEffectYaw(fx, angle + TWO_PI / 4)
            DestroyEffect(fx)
        end
        G.fx(FX.mirrorImage, x, y, radius / 220)
    end

    -- Mirror Image: copies of the hero, with its full health, that fight on
    -- their own and draw every enemy near them (G.updateEnemies) until they
    -- die. A cast tops them up to the rank's count; living ones stay.
    function G.mirrorImages(count, radius)
        local alive = 0
        for _ in pairs(R.images) do
            alive = alive + 1
        end
        local id = GetUnitTypeId(R.hero)
        -- A way out now and then, not a wall: weak and short-lived.
        local hp = BlzGetUnitMaxHP(R.hero) * CFG.IMAGE_HEALTH
        local s = R.stats
        local damage = s.attackDamage * 0.4
        local spin = GetRandomReal(0, TWO_PI)
        for k = 1, count - alive do
            local angle = spin + TWO_PI * k / (count - alive)
            local x = U.clamp(R.hx + math.cos(angle) * radius * 0.5, G.minX, G.maxX)
            local y = U.clamp(R.hy + math.sin(angle) * radius * 0.5, G.minY, G.maxY)
            local u = CreateUnit(G.PLAYER, id, x, y, bj_RADTODEG * angle)
            if u then
                SuspendHeroXP(u, true)
                UnitRemoveAbility(u, FourCC('Ashm'))
                SetUnitVertexColor(u, 150, 180, 255, 170)
                SetUnitScale(u, R.baseScale, R.baseScale, R.baseScale)
                BlzSetUnitMaxHP(u, math.max(1, math.floor(hp)))
                SetWidgetLife(u, hp)
                BlzSetUnitBaseDamage(u, math.max(1, math.floor(damage)), 0)
                UnitApplyTimedLife(u, FourCC('BTLF'), CFG.IMAGE_DURATION)
                if R.paused then
                    PauseUnit(u, true)
                end
                G.fx(FX.mirrorImage, x, y, 0.8)
                R.images[u] = true
                R.summons[u] = {key = 'mirror_image'}
                local target = G.nearest(x, y, 1100, 1)[1]
                if target then
                    IssuePointOrder(u, 'attack', target.x, target.y)
                end
            end
        end
    end

    -- The living image nearest to (x, y) within reach, if any. While the
    -- hero is split (Storm, Earth and Fire), its spirits draw enemies the
    -- same way, from any distance: the hidden hero cannot be fought.
    function G.decoyNear(x, y, reach)
        local best, bestD = nil, reach * reach
        for u in pairs(R.images) do
            local dx, dy = GetUnitX(u) - x, GetUnitY(u) - y
            local d = dx * dx + dy * dy
            if d < bestD and GetWidgetLife(u) > 0.405 then
                best, bestD = u, d
            end
        end
        if R.split then
            bestD = math.huge
            for _, u in ipairs(R.split.units) do
                local dx, dy = GetUnitX(u) - x, GetUnitY(u) - y
                local d = dx * dx + dy * dy
                if d < bestD and R.summons[u] and GetWidgetLife(u) > 0.405 then
                    best, bestD = u, d
                end
            end
        end
        return best
    end

    CAST.zone = function(inst, v)
        local def = inst.def
        local cx, cy
        if def.onHero or def.follow then
            if G.countInRange(R.hx, R.hy, v.radius + 60) == 0 then
                return false
            end
            cx, cy = R.hx, R.hy
        else
            cx, cy = G.densest(v.range, v.radius)
            if cx == nil then
                return false
            end
        end
        local run = R
        if def.spinAnim and R.time < R.spinUntil then
            -- Spell duration can outlast the cooldown: the spin goes on
            -- and the next one starts when it ends.
            return false
        end
        if def.spinAnim then
            -- Bladestorm: the hero whirls (its "Attack Walk Stand Spin"
            -- sequence) for every wave, walking or not.
            local length = (def.delay or 0) + v.waves * (def.interval or 0.5)
            R.spinUntil = R.time + length
            R.spinAnim = 'attack walk stand spin'
            G.heroAnim(R.spinAnim, length)
        end
        for wave = 1, v.waves do
            G.after((def.delay or 0) + (wave - 1) * (def.interval or 0.5), function()
                if R ~= run or R.ended then
                    return
                end
                local x, y = cx, cy
                if def.follow or def.onHero then
                    x, y = R.hx, R.hy
                end
                if def.waveSound then
                    G.sound(def.waveSound, x, y)
                end
                if def.strikes then
                    local pool = {}
                    G.inRange(x, y, v.radius, function(u, ux, uy)
                        pool[#pool + 1] = {u, ux, uy}
                    end)
                    for _ = 1, math.min(v.count, #pool) do
                        local pick = table.remove(pool, GetRandomInt(1, #pool))
                        G.timedFx(def.fx, pick[2], pick[3], 0.8, 1.0)
                        G.damage(pick[1], v.dmg, def.key)
                        applyHitEffects(def, v, pick[1])
                    end
                    return
                end
                local spread = def.spread or 1
                for _ = 1, spread do
                    local ox, oy = x, y
                    if spread > 1 then
                        local angle = GetRandomReal(0, TWO_PI)
                        local dist = GetRandomReal(0, v.radius * 0.7)
                        ox = x + math.cos(angle) * dist
                        oy = y + math.sin(angle) * dist
                    end
                    if def.spinAnim then
                        G.bladeRing(ox, oy, v.radius, wave)
                    elseif def.follow then
                        G.fx(def.fx, ox, oy, v.radius / 220)
                    else
                        G.timedFx(def.fx, ox, oy, spread > 1 and 0.8 or v.radius / 240, 1.4)
                    end
                end
                if def.follow and not def.spinAnim then
                    G.heroSwing(R.attackAnim, 0.3)
                end
                G.inRange(x, y, v.radius, function(u)
                    G.damage(u, v.dmg, def.key)
                    applyHitEffects(def, v, u)
                end)
            end)
        end
        return true
    end

    CAST.chain = function(inst, v)
        local def = inst.def
        local first = G.nearest(R.hx, R.hy, v.range, def.fork and v.count or 1)
        if #first == 0 then
            return false
        end
        local hz = G.groundZ(R.hx, R.hy) + 90
        if def.fork then
            for _, t in ipairs(first) do
                G.lightning(def.lightning, R.hx, R.hy, hz, t.x, t.y, G.groundZ(t.x, t.y) + 50, 0.35)
                G.damage(t.u, v.dmg, def.key)
                if def.impact then
                    G.fx(def.impact, t.x, t.y, 1.0)
                end
                if def.leech then
                    G.heal(v.dmg * def.leech)
                end
                if def.manaGain then
                    G.addMana(def.manaGain)
                end
            end
            return true
        end
        local hit = {}
        local fromX, fromY, fromZ = R.hx, R.hy, hz
        local damage = v.dmg
        local current = first[1]
        for jump = 1, v.count + 1 do
            local z = G.groundZ(current.x, current.y) + 50
            G.lightning(jump == 1 and def.lightning or (def.lightning2 or def.lightning), fromX, fromY, fromZ,
                current.x, current.y, z, 0.3)
            G.damage(current.u, damage, def.key)
            if def.impact then
                G.fx(def.impact, current.x, current.y, 1.0)
            end
            hit[current.u] = true
            fromX, fromY, fromZ = current.x, current.y, z
            damage = damage * (def.falloff or 1)
            local nextTarget = G.nearest(current.x, current.y, def.jump or 420, 1, hit)[1]
            if nextTarget == nil then
                break
            end
            current = nextTarget
        end
        return true
    end

    CAST.line = function(inst, v)
        local def = inst.def
        local t = G.nearest(R.hx, R.hy, v.range, 1)[1]
        if t == nil then
            return false
        end
        local base = Atan2(t.y - R.hy, t.x - R.hx)
        local n = v.count
        for k = 1, n do
            G.launchLine({model = def.missile, trail = def.trail, scale = def.scale, x = R.hx, y = R.hy,
                angle = base + (k - (n + 1) / 2) * 0.32, speed = def.speed or 1000, range = v.range,
                width = (def.width or 120) * (1 + R.stats.area * 0.5), onHit = function(u)
                    G.damage(u, v.dmg, def.key)
                    applyHitEffects(def, v, u)
                end})
        end
        return true
    end

    CAST.summon = function(inst, v)
        local def = inst.def
        if G.countInRange(R.hx, R.hy, 1000) == 0 then
            return false
        end
        local cx, cy = R.hx, R.hy
        if def.nearEnemy then
            local t = G.nearest(R.hx, R.hy, 900, 1)[1]
            if t then
                cx, cy = t.x, t.y
            end
        end
        local alive = 0
        for _ in pairs(R.summons) do
            alive = alive + 1
        end
        local n = math.min(v.count, CFG.MAX_SUMMONS - alive)
        if def.split then
            -- The hero itself becomes the spirits: never short of one.
            if R.split then
                return false
            end
            n = v.count
        end
        if n <= 0 then
            return false
        end
        local spirits = {}
        for k = 1, n do
            local code
            if def.cycleUnits then
                code = def.units[math.fmod(k - 1, #def.units) + 1]
            else
                code = def.units[math.min(inst.rank, #def.units)]
            end
            local angle = TWO_PI * k / n
            local x = U.clamp(cx + math.cos(angle) * 120, G.minX, G.maxX)
            local y = U.clamp(cy + math.sin(angle) * 120, G.minY, G.maxY)
            local u = CreateUnit(G.PLAYER, FourCC(code), x, y, 270)
            if u == nil and code ~= def.units[1] then
                u = CreateUnit(G.PLAYER, FourCC(def.units[1]), x, y, 270)
            end
            if u then
                -- A split's spirits are taken back by G.endSplit; the timed
                -- life is only a safety net.
                UnitApplyTimedLife(u, FourCC('BTLF'), def.split and v.dur + 2 or v.dur)
                BlzSetUnitBaseDamage(u, math.max(1, math.floor(v.dmg)), 0)
                local hp = math.floor(def.hp * (1 + 0.25 * (inst.rank - 1)) * R.stats.spellPower)
                BlzSetUnitMaxHP(u, hp)
                SetWidgetLife(u, hp)
                if def.birth then
                    G.fx(def.birth, x, y, 1.0)
                end
                if R.paused then
                    PauseUnit(u, true)
                end
                R.summons[u] = {key = def.key, ward = def.ward, split = def.split}
                spirits[#spirits + 1] = u
                local target = G.nearest(x, y, 1200, 1)[1]
                if target and not def.ward then
                    IssuePointOrder(u, 'attack', target.x, target.y)
                end
            end
        end
        if def.impactDamage then
            local run = R
            G.after(0.6, function()
                if R ~= run or R.ended then
                    return
                end
                G.inRange(cx, cy, v.radius, function(u)
                    G.damage(u, v.impact, def.key)
                    G.stun(u, 1.0)
                end)
            end)
        end
        if def.split and #spirits > 0 then
            G.startSplit(spirits, v.dur)
        end
        return true
    end

    -- Storm, Earth and Fire: the hero vanishes (hidden, invulnerable, no
    -- attacks or casts) while its spirits fight; the player still steers
    -- the spot they gather around. When the time is up or every spirit has
    -- fallen, they merge back into the hero.
    function G.startSplit(spirits, dur)
        R.split = {units = spirits, untilT = R.time + dur}
        R.invulnUntil = math.max(R.invulnUntil, R.split.untilT)
        SetUnitVertexColor(R.hero, 255, 255, 255, 0)
        G.fx(FX.teleport, R.hx, R.hy, 1.0)
    end

    function G.updateSplit()
        local split = R.split
        if split == nil then
            return
        end
        local alive = 0
        for _, u in ipairs(split.units) do
            if R.summons[u] and GetWidgetLife(u) > 0.405 then
                alive = alive + 1
            end
        end
        if alive == 0 or R.time >= split.untilT then
            G.endSplit()
        end
    end

    function G.endSplit()
        local split = R.split
        R.split = nil
        for _, u in ipairs(split.units) do
            if R.summons[u] then
                R.summons[u] = nil
                if GetWidgetLife(u) > 0.405 then
                    G.fx(FX.teleport, GetUnitX(u), GetUnitY(u), 0.8)
                end
                RemoveUnit(u)
            end
        end
        -- Spirits that all fell early end the split's invulnerability too.
        if R.invulnUntil == split.untilT then
            R.invulnUntil = R.time
        end
        local alpha = 255
        for _, buff in pairs(R.buffs) do
            if buff.def.fade then
                alpha = buff.def.fade
            end
        end
        SetUnitVertexColor(R.hero, 255, 255, 255, alpha)
        G.fx(FX.teleport, R.hx, R.hy, 1.0)
    end

    CAST.heal = function(inst, v, manual)
        local def = inst.def
        -- Autocast heals fire when hurt, those that also hurt when a pack closes in.
        local hurt = GetWidgetLife(R.hero) < BlzGetUnitMaxHP(R.hero) * (def.threshold or 0.8)
        local crowded = def.dmg and def.radius and G.countInRange(R.hx, R.hy, v.radius) >= 3
        if not manual and not hurt and not crowded then
            return false
        end
        G.heal(v.heal)
        if def.fx then
            DestroyEffect(AddSpecialEffectTarget(def.fx, R.hero, 'origin'))
        end
        if def.dmg and def.radius then
            G.inRange(R.hx, R.hy, v.radius, function(u)
                G.damage(u, v.dmg, def.key)
            end)
        end
        return true
    end

    CAST.buff = function(inst, v, manual)
        local def = inst.def
        if R.buffs[def.key] then
            return false
        end
        -- Autocast waits for low health or a pack close by; a key casts at once.
        if not manual then
            if def.trigger == 'lowhp' then
                if GetWidgetLife(R.hero) > BlzGetUnitMaxHP(R.hero) * 0.35 then
                    return false
                end
            elseif G.countInRange(R.hx, R.hy, 450) < 4 then
                return false
            end
        end
        local buff = {def = def, v = v, untilT = R.time + v.dur, icon = U.spellIcon(def)}
        if def.fx then
            buff.fx = AddSpecialEffectTarget(def.fx, R.hero, 'origin')
        end
        R.buffs[def.key] = buff
        -- Some buffs strike everything close as they begin.
        if def.dmg and def.radius then
            if def.burstFx then
                G.fx(def.burstFx, R.hx, R.hy, v.radius / 250)
            end
            G.inRange(R.hx, R.hy, v.radius, function(u)
                G.damage(u, v.dmg, def.key)
                applyHitEffects(def, v, u)
            end)
        end
        if def.invulnerable then
            R.invulnUntil = math.max(R.invulnUntil, buff.untilT)
        end
        if def.scale then
            local scale = R.baseScale * def.scale
            SetUnitScale(R.hero, scale, scale, scale)
        end
        if def.fade then
            -- Wind Walk: the hero turns see-through while the buff lasts.
            SetUnitVertexColor(R.hero, 255, 255, 255, def.fade)
        end
        if def.morph then
            G.setMorph(def.morph, true)
        end
        G.recomputeStats()
        return true
    end

    -- Raven Form: the model's Alternate sequences (the raven) take over;
    -- its only attack is Attack Alternate, used for casts too. The current
    -- clip is picked again at once (walk stays walk).
    function G.setMorph(tag, on)
        AddUnitAnimationProperties(R.hero, tag, on)
        R.morph = on and tag or nil
        R.attackAnim = on and 'attack' or (R.def.attackAnim or 'attack')
        R.castAnim = on and 'attack' or R.def.castAnim
        if R.upperAnim then
            R.upperAnim(R.hero, '')
        end
        R.anim = ''
        R.animLock = R.time
        G.fx(FX.blink, R.hx, R.hy, 1.0)
    end

    function G.updateBuffs()
        local changed = false
        for key, buff in pairs(R.buffs) do
            if R.time >= buff.untilT then
                if buff.fx then
                    DestroyEffect(buff.fx)
                end
                if buff.def.scale then
                    SetUnitScale(R.hero, R.baseScale, R.baseScale, R.baseScale)
                end
                if buff.def.fade then
                    SetUnitVertexColor(R.hero, 255, 255, 255, 255)
                end
                if buff.def.morph then
                    G.setMorph(buff.def.morph, false)
                end
                R.buffs[key] = nil
                changed = true
            end
        end
        if changed then
            G.recomputeStats()
        end
    end

    function G.updateOrbit(inst, dt)
        local def, v = inst.def, inst.v
        inst.orbs = inst.orbs or {}
        local orbs = inst.orbs
        while #orbs < v.count do
            local fx = AddSpecialEffect(def.missile, R.hx, R.hy)
            if def.scale then
                BlzSetSpecialEffectScale(fx, def.scale)
            end
            orbs[#orbs + 1] = fx
        end
        while #orbs > v.count do
            DestroyEffect(table.remove(orbs))
        end
        inst.angle = (inst.angle or 0) + def.speed * dt
        if R.time >= (inst.hitsReset or 0) then
            inst.hits = {}
            inst.hitsReset = R.time + 6
        end
        local area = 1 + R.stats.area * 0.5
        local radius = def.orbitRadius * area
        local hitRadius = def.hitRadius * area
        local z = G.groundZ(R.hx, R.hy) + 70
        local n = #orbs
        for k = 1, n do
            local angle = inst.angle + (k - 1) * TWO_PI / n
            local x = R.hx + math.cos(angle) * radius
            local y = R.hy + math.sin(angle) * radius
            BlzSetSpecialEffectPosition(orbs[k], x, y, z)
            BlzSetSpecialEffectYaw(orbs[k], angle + 1.5708)
            G.inRange(x, y, hitRadius, function(u)
                if (inst.hits[u] or 0) <= R.time then
                    inst.hits[u] = R.time + 0.5
                    G.damage(u, v.dmg, def.key)
                    if def.slow then
                        G.slow(u, def.slow, 1.5)
                    end
                    if def.leech then
                        G.heal(v.dmg * def.leech)
                    end
                end
            end)
        end
    end

    function G.updateAura(inst, dt)
        local def, v = inst.def, inst.v
        if inst.attachFx == nil and def.attach then
            inst.attachFx = AddSpecialEffectTarget(def.attach, R.hero, 'origin')
        end
        -- The aura's art grows with its radius (ranks and area upgrades).
        local scale = v.radius / def.radius
        if inst.attachFx and inst.attachScale ~= scale then
            inst.attachScale = scale
            BlzSetSpecialEffectScale(inst.attachFx, scale)
        end
        inst.cd = inst.cd - dt
        if inst.cd > 0 then
            return
        end
        inst.cd = def.interval * (1 - R.stats.cdr * 0.5)
        local shown = 0
        G.inRange(R.hx, R.hy, v.radius, function(u, x, y)
            G.damage(u, v.dmg, def.key)
            shown = shown + 1
            if shown <= 3 and def.fx then
                G.fx(def.fx, x, y, 0.8)
            end
        end)
    end

    function G.updateSpells(dt)
        for _, inst in ipairs(R.spells) do
            local kind = inst.def.kind
            if kind == 'orbit' then
                G.updateOrbit(inst, dt)
            elseif kind == 'aura' then
                G.updateAura(inst, dt)
            elseif kind ~= 'passive' then
                -- The split's own cooldown starts once the spirits merge back.
                if not (R.split and inst.def.split) then
                    inst.cd = inst.cd - dt
                end
                -- A ready spell waits for its key, or casts itself with autocast
                -- on. Short of mana it waits too (its slot turns blue). A split
                -- hero (Storm, Earth and Fire) casts nothing until it merges.
                inst.waiting = R.mana < inst.v.mana
                if inst.cd <= 0 then
                    inst.cd = 0
                    if inst.auto and not R.split and not inst.waiting and not G.cast(inst, false) then
                        inst.cd = 0.3
                    end
                end
            end
            if R == nil or R.ended then
                return
            end
        end
    end

    -- One cast of a spell; false when it found nothing to cast on. A cast
    -- from its key (manual) skips the conditions autocast waits for: a heal
    -- heals at once, a buff starts with no pack close by.
    function G.cast(inst, manual)
        local run = R
        if not CAST[inst.def.kind](inst, inst.v, manual) then
            return false
        end
        run.mana = run.mana - inst.v.mana
        inst.cd = inst.v.cd
        -- A standing hero shows the cast (Spell, Spell Slam, ...).
        if R and not R.ended then
            G.heroSwing(inst.def.anim or R.castAnim or 'spell', 0.5)
            if inst.def.sound then
                G.sound(inst.def.sound, R.hx, R.hy)
            end
        end
        return true
    end

    -- A spell's key or a click on its slot: casts it if ready and paid for.
    function G.castSpell(i)
        local inst = R and not R.ended and not R.paused and R.slots[i]
        if not G.canToggle(inst) or R.split or inst.cd > 0 or R.mana < inst.v.mana then
            return
        end
        G.cast(inst, true)
    end

    function G.addMana(amount)
        R.mana = math.max(0, math.min(R.maxMana, R.mana + amount))
    end

    -- Spells that cast (not auras, orbits or passives) have a key and an
    -- autocast to turn on or off.
    function G.canToggle(inst)
        return inst ~= nil and inst ~= false and not FREE_KINDS[inst.def.kind]
    end

    function G.toggleSpell(i)
        local inst = R and not R.ended and R.slots[i]
        if not G.canToggle(inst) then
            return
        end
        inst.auto = not inst.auto
        Hud.refreshSlotStates()
    end

    function G.learnSpell(key, power)
        local inst = {def = SPELLS[key], rank = 1, power = power or 1.0, cd = 0.5,
            auto = CFG.AUTOCAST or Engine.touch() or (Engine.active() and EngineCvar('survivor_autocast') == '1')}
        R.spells[#R.spells + 1] = inst
        R.spellByKey[key] = inst
        -- Every spell has its own slot (and key): its place in the hero's
        -- Warcraft III command card order (def.pool), whatever order they
        -- are learned in. A spell from outside the pool takes the first free slot.
        local slot = nil
        for i, poolKey in ipairs(R.def.pool) do
            if poolKey == key and i <= CFG.SPELL_SLOTS and R.slots[i] == nil then
                slot = i
            end
        end
        for i = 1, CFG.SPELL_SLOTS do
            if slot == nil and R.slots[i] == nil then
                slot = i
            end
        end
        if slot then
            R.slots[slot] = inst
        end
        G.recomputeStats()
        return inst
    end

    function G.updateSummons()
        for u, info in pairs(R.summons) do
            if GetWidgetLife(u) <= 0.405 then
                R.summons[u] = nil
            elseif not info.ward then
                -- Split spirits stay close to the spot the player steers.
                local leash = info.split and 450 or 900
                local dx, dy = GetUnitX(u) - R.hx, GetUnitY(u) - R.hy
                if dx * dx + dy * dy > leash * leash then
                    IssuePointOrder(u, 'move', R.hx, R.hy)
                elseif GetUnitCurrentOrder(u) == 0 then
                    local t = G.nearest(GetUnitX(u), GetUnitY(u), 1100, 1)[1]
                    if t then
                        IssuePointOrder(u, 'attack', t.x, t.y)
                    end
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Hero: movement, animation and the automatic basic attack
    ---------------------------------------------------------------------------
    function G.heroAnim(name, lock)
        if R.upperAnim then
            -- A whole-body sequence ends a swing still playing on the upper body.
            R.upperAnim(R.hero, '')
        end
        SetUnitAnimation(R.hero, name)
        R.anim = name
        R.animLock = R.time + (lock or 0.4)
    end

    -- A swing or a cast: whole body while the hero stands. Walking, the full
    -- sequence would plant the feet (the hero seems to stop and turn), so it
    -- plays on the upper body only (standalone engine) or not at all.
    function G.heroSwing(name, lock, speed)
        if R.time < R.spinUntil then
            return
        end
        if not R.moving then
            G.heroAnim(name, lock)
        elseif R.upperAnim then
            R.upperAnim(R.hero, name, speed or 1.0)
        end
    end

    -- A unit's collision radius from the game data (the engine's pathing
    -- value; Reforged has a native for it), or the fallback.
    function G.unitRadius(u, fallback)
        local engineCollision = rawget(_G, 'EngineUnitCollision')
        if Engine.active() and type(engineCollision) == 'function' then
            local r = engineCollision(u)
            if type(r) == 'number' and r > 0 then
                return r
            end
        end
        local reforged = rawget(_G, 'BlzGetUnitCollisionSize')
        if not Engine.active() and type(reforged) == 'function' then
            local ok, r = pcall(reforged, u)
            if ok and type(r) == 'number' and r > 0 then
                return r
            end
        end
        return fallback
    end

    -- Bodies block as in Warcraft III (always on):
    -- the hero cannot walk through enemies and slides along them. Only a step
    -- toward an enemy is held back, so a hero an enemy walked into can
    -- always step away. Raven Form flies and Wind Walk slips through, as the
    -- real spells do; the split hero is not there at all.
    function G.collide(x, y, nx, ny)
        if R.split then
            return nx, ny
        end
        for _, buff in pairs(R.buffs) do
            if buff.def.fly or buff.def.fade then
                return nx, ny
            end
        end
        local rh = R.heroRadius or 32
        for _ = 1, 3 do
            local pushed = false
            for i = 1, R.en do
                local info = R.enemies[R.elist[i]]
                if info then
                    local ex, ey = R.ex[i], R.ey[i]
                    local reach = rh + (info.radius or 24)
                    local dx, dy = nx - ex, ny - ey
                    local d2 = dx * dx + dy * dy
                    if d2 < reach * reach then
                        local ox, oy = x - ex, y - ey
                        local old2 = ox * ox + oy * oy
                        if d2 < old2 - 0.01 then
                            local d = math.sqrt(d2)
                            if d < 0.01 then
                                dx, dy, d = ox, oy, math.sqrt(old2)
                            end
                            if d >= 0.01 then
                                -- Back out to the edge (or to where it stood, if
                                -- it already overlapped): it slides around.
                                local keep = math.min(reach, math.sqrt(old2))
                                nx, ny = ex + dx / d * keep, ey + dy / d * keep
                                pushed = true
                            end
                        end
                    end
                end
            end
            if not pushed then
                break
            end
        end
        return nx, ny
    end

    function G.updateMovement(dt)
        -- A right-click gave the hero a native order: cancel it, or the
        -- engine moves the hero too and the two speeds add up.
        -- (The standalone engine never starts that order: R.scriptOrders.)
        if R.cancelOrder then
            R.cancelOrder = false
            if not R.scriptOrders then
                IssueImmediateOrder(R.hero, 'stop')
                -- Both orders reset the unit's animation: a spin picks up again.
                if R.time < R.spinUntil then
                    SetUnitAnimation(R.hero, R.spinAnim)
                else
                    R.anim = ''
                end
            end
        end
        -- The hero walks to the last right-click, like a Warcraft III unit,
        -- or (keyboard movement, Options) while the movement keys are held.
        local step = R.moveSpeed * dt
        local dx, dy = 0, 0
        if Keys.wasd() then
            R.clickX, R.clickY = nil, nil
            dx, dy = Keys.direction()
        elseif R.clickX then
            dx, dy = R.clickX - R.hx, R.clickY - R.hy
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= step then
                -- Arrives this tick.
                step = dist
                R.clickX, R.clickY = nil, nil
            end
            if dist < 1 then
                dx, dy = 0, 0
            end
        end
        R.moving = dx ~= 0 or dy ~= 0
        if R.moving then
            local length = math.sqrt(dx * dx + dy * dy)
            dx, dy = dx / length, dy / length
            local x, y = R.hx, R.hy
            local nx, ny = G.collide(x, y, x + dx * step, y + dy * step)
            if not G.walkable(nx, ny) then
                if G.walkable(nx, y) then
                    ny = y
                elseif G.walkable(x, ny) then
                    nx = x
                else
                    nx, ny = x, y
                    -- Walked into a wall: drop the click target.
                    R.clickX, R.clickY = nil, nil
                end
            end
            SetUnitX(R.hero, nx)
            SetUnitY(R.hero, ny)
            R.hx, R.hy = nx, ny
            -- A walking hero always faces where it goes. Starting to walk
            -- ends a swing or a cast at once; only a spin keeps playing.
            BlzSetUnitFacingEx(R.hero, bj_RADTODEG * Atan2(dy, dx))
            if R.time < R.animLock and R.time >= R.spinUntil then
                R.animLock = R.time
            end
        end
        if R.time >= R.animLock then
            local want = R.moving and 'walk' or 'stand'
            if R.anim ~= want then
                SetUnitAnimation(R.hero, want)
                R.anim = want
            end
        end
        if R.moving then
            SetUnitTimeScale(R.hero, U.clamp(R.moveSpeed / R.baseMove, 0.8, 1.8))
        else
            SetUnitTimeScale(R.hero, 1.0)
        end
    end

    function G.attackHit(u, x, y, damage)
        local s = R.stats
        if s.critStrike > 0 and GetRandomReal(0, 1) < s.critStrike then
            damage = damage * s.critStrikeMult
            if CFG.DAMAGE_NUMBERS then
                G.floatText(x, y + 40, 'Critical!', 10, 255, 80, 40)
            end
            G.damage(u, damage, 'critical_strike')
        else
            G.damage(u, damage, 'attack')
        end
        if s.vampiric > 0 then
            G.heal(damage * s.vampiric)
        end
        local info = R.enemies[u]
        if info and s.corrupt > 0 then
            info.corruptUntil = R.time + 3.0
        end
        if s.searing > 0 then
            G.dot(u, damage * s.searing / 3, 3.0, 'searing')
        end
        if s.bash > 0 and GetRandomReal(0, 1) < s.bash then
            G.stun(u, 1.0)
            G.damage(u, s.bashDamage * (1 + s.damage), 'bash', false)
        end
        if s.attackSlow > 0 then
            G.slow(u, s.attackSlow, 2.0)
        end
        if s.cleave > 0 then
            G.inRange(x, y, 170 * (1 + s.area), function(other)
                if other ~= u then
                    G.damage(other, damage * s.cleave, 'cleave', false)
                end
            end)
            if R.melee then
                G.fx(FX.cleave, x, y, 1.0)
            end
        end
        if s.fireSplash > 0 then
            G.fx(FX.immolationHit, x, y, 0.8)
            G.inRange(x, y, 150 * (1 + s.area), function(other)
                if other ~= u then
                    G.damage(other, damage * s.fireSplash, 'fireOrb', false)
                end
            end)
        end
    end

    function G.updateAttack(dt)
        R.attackClock = R.attackClock - dt
        if R.attackClock > 0 or R.split then
            return
        end
        local s = R.stats
        local ranged = (not R.melee) or s.range > 0
        local range = ranged and (math.max(R.attackRange, 600) + (R.melee and 0 or s.range)) or R.attackRange
        local targets = G.nearest(R.hx, R.hy, range, 1 + s.multishot)
        if #targets == 0 then
            R.attackClock = 0.1
            return
        end
        -- Battle Thirst: faster for a few seconds after a kill.
        local thirst = R.time < R.thirstUntil and s.thirst or 0
        R.attackClock = R.attackCooldown / (1 + s.attackSpeed + thirst)
        local damage = s.attackDamage
        for _, t in ipairs(targets) do
            if ranged then
                G.launch({model = R.missile, x = R.hx, y = R.hy, target = t.u, tx = t.x, ty = t.y, speed = R.missileSpeed,
                    onHit = function(u, x, y)
                        G.attackHit(u, x, y, damage)
                    end})
            else
                G.attackHit(t.u, t.x, t.y, damage)
            end
        end
        -- Attacks never stop the hero. Walking, it keeps facing its way and
        -- swings with the upper body (or, without that, a slash marks a melee
        -- hit); standing, it turns to its target and swings. A spin
        -- (Bladestorm) is never cut short.
        if R.moving then
            if R.time < R.spinUntil then
                return
            end
            if R.upperAnim then
                G.heroSwing(R.attackAnim, 0, 1 + s.attackSpeed)
            elseif R.melee and s.cleave <= 0 then
                G.fx(FX.cleave, targets[1].x, targets[1].y, 0.8)
            end
        elseif R.time >= R.spinUntil then
            local t = targets[1]
            BlzSetUnitFacingEx(R.hero, bj_RADTODEG * Atan2(t.y - R.hy, t.x - R.hx))
            G.heroAnim(R.attackAnim, math.min(ranged and 0.5 or 0.65, R.attackClock))
        end
    end

    function G.updateHero(dt)
        local s = R.stats
        local life = GetWidgetLife(R.hero)
        if s.regen > 0 and life > 0.405 then
            SetWidgetLife(R.hero, math.min(BlzGetUnitMaxHP(R.hero), life + s.regen * dt))
        end
        G.addMana(s.manaRegen * dt)
        -- Cloak of Flames: a burn around the hero every second.
        if s.flames > 0 then
            R.flamesClock = R.flamesClock - dt
            if R.flamesClock <= 0 then
                R.flamesClock = 1.0
                local shown = 0
                R.dmgTick = true
                G.inRange(R.hx, R.hy, 220 * (1 + s.area), function(u, x, y)
                    G.damage(u, s.attackDamage * s.flames, 'cloak', false)
                    shown = shown + 1
                    if shown <= 3 then
                        G.fx(FX.immolationHit, x, y, 0.7)
                    end
                end)
                R.dmgTick = false
            end
        end
        local invulnerable = R.time < R.invulnUntil
        if invulnerable ~= R.invulnerable then
            R.invulnerable = invulnerable
            SetUnitInvulnerable(R.hero, invulnerable)
        end
    end

    ---------------------------------------------------------------------------
    -- Run lifecycle
    ---------------------------------------------------------------------------
    function G.setPaused(paused)
        R.paused = paused
        for u in pairs(R.enemies) do
            PauseUnit(u, paused)
        end
        for u in pairs(R.summons) do
            PauseUnit(u, paused)
        end
        PauseUnit(R.hero, paused)
        Hud.showWorldFrames(not paused)
    end

    function G.tryOpenHand()
        if R == nil or R.ended or R.hand then
            return
        end
        if R.pendingChests > 0 then
            R.pendingChests = R.pendingChests - 1
            Cards.open('chest')
        elseif R.pendingLevels > 0 then
            R.pendingLevels = R.pendingLevels - 1
            Cards.open('level')
        end
    end

    function G.tick()
        if R == nil or R.ended or R.paused then
            return
        end
        local dt = CFG.TICK
        R.time = R.time + dt
        R.hx, R.hy = GetUnitX(R.hero), GetUnitY(R.hero)
        -- Diagnostic for the browser black-world reports: a non-finite hero
        -- position would blank the camera and stop every pickup. Logged once.
        if not R.badPos and (R.hx ~= R.hx or R.hy ~= R.hy or math.abs(R.hx) > 1e7 or math.abs(R.hy) > 1e7) then
            R.badPos = true
            print('SURVIVOR hero position invalid at ' .. string.format('\0371.1f', R.time) .. ' s: '
                .. tostring(R.hx) .. ' ' .. tostring(R.hy))
        end
        if GetWidgetLife(R.hero) <= 0.405 then
            G.endRun(false)
            return
        end
        G.refreshEnemyCache()
        G.runScheduled()
        if R == nil or R.ended or R.paused then
            return
        end
        G.updateMovement(dt)
        G.updateHero(dt)
        G.updateProjectiles(dt)
        if R == nil or R.ended then
            return
        end
        G.updateLines(dt)
        if R == nil or R.ended then
            return
        end
        G.updateAttack(dt)
        G.updateSpells(dt)
        if R == nil or R.ended then
            return
        end
        G.updateSplit()
        G.updatePickups(dt)
        if R == nil or R.ended then
            return
        end
        G.updateWorldObjects(dt)
        G.updateCompanion(dt)
        R.slowClock = R.slowClock - dt
        if R.slowClock <= 0 then
            R.slowClock = 0.25
            G.updateEnemies()
            G.updateBuffs()
            if R == nil or R.ended then
                return
            end
        end
        R.summonClock = R.summonClock - dt
        if R.summonClock <= 0 then
            R.summonClock = 1.0
            G.updateSummons()
        end
        G.updateSpawns(dt)
        R.hudClock = R.hudClock - dt
        if R.hudClock <= 0 then
            R.hudClock = 0.1
            Hud.update()
        end
    end

    function G.readWeapon(u)
        local range, missile, speed = 100, '', 1000
        if UNIT_WEAPON_RF_ATTACK_RANGE ~= nil then
            local ok, value = pcall(BlzGetUnitWeaponRealField, u, UNIT_WEAPON_RF_ATTACK_RANGE, 0)
            if ok and type(value) == 'number' then
                range = value
            end
        end
        if UNIT_WEAPON_SF_ATTACK_PROJECTILE_ART ~= nil then
            local ok, value = pcall(BlzGetUnitWeaponStringField, u, UNIT_WEAPON_SF_ATTACK_PROJECTILE_ART, 0)
            if ok and type(value) == 'string' then
                missile = value
            end
        end
        if UNIT_WEAPON_RF_ATTACK_PROJECTILE_SPEED ~= nil then
            local ok, value = pcall(BlzGetUnitWeaponRealField, u, UNIT_WEAPON_RF_ATTACK_PROJECTILE_SPEED, 0)
            if ok and type(value) == 'number' and value > 0 then
                speed = value
            end
        end
        return range, missile, speed, BlzGetUnitAttackCooldown(u, 0)
    end

    -- Weapon types in common.j order (WEAPON_TYPE_WHOKNOWS = 0 is silent).
    local WEAPON_TYPES = {'METAL_LIGHT_CHOP', 'METAL_MEDIUM_CHOP', 'METAL_HEAVY_CHOP', 'METAL_LIGHT_SLICE',
        'METAL_MEDIUM_SLICE', 'METAL_HEAVY_SLICE', 'METAL_MEDIUM_BASH', 'METAL_HEAVY_BASH', 'METAL_MEDIUM_STAB',
        'METAL_HEAVY_STAB', 'WOOD_LIGHT_SLICE', 'WOOD_MEDIUM_SLICE', 'WOOD_HEAVY_SLICE', 'WOOD_LIGHT_BASH',
        'WOOD_MEDIUM_BASH', 'WOOD_HEAVY_BASH', 'WOOD_LIGHT_STAB', 'WOOD_MEDIUM_STAB', 'CLAW_LIGHT_SLICE',
        'CLAW_MEDIUM_SLICE', 'CLAW_HEAVY_SLICE', 'AXE_MEDIUM_CHOP', 'ROCK_HEAVY_BASH'}

    -- The unit's weapon sound as a weapontype, for UnitDamageTarget.
    function G.readWeaponType(u)
        if UNIT_WEAPON_IF_ATTACK_WEAPON_SOUND ~= nil then
            local ok, value = pcall(BlzGetUnitWeaponIntegerField, u, UNIT_WEAPON_IF_ATTACK_WEAPON_SOUND, 0)
            if ok and type(value) == 'number' and WEAPON_TYPES[value] then
                return _G['WEAPON_TYPE_' .. WEAPON_TYPES[value]] or WEAPON_TYPE_WHOKNOWS
            end
        end
        return WEAPON_TYPE_WHOKNOWS
    end

    -- The spell a hero starts with: the one picked in the lobby, else its default.
    function G.startSpell(hero)
        local key = hero.pool[Profile.data.starts[hero.id] or 0]
        if key and SPELLS[key] then
            return key
        end
        return hero.start
    end

    function G.startRun()
        if Engine.active() and not G.inArena then
            -- Standalone engine: the menu map loads the zone's own map first.
            Engine.enterZone()
            return
        end
        local def = HEROES[S.heroIndex]
        local zone = ZONES[S.zone]
        Lobby.hide()
        R = {def = def, zone = zone, zoneIndex = S.zone, diff = G.difficulty(S.difficulty, S.keyLevel), diffIndex = S.difficulty,
            time = 0, paused = false, ended = false, level = 1, xp = 0, xpNext = G.xpFor(1),
            kills = 0, gold = 0, bosses = 0, damageDone = 0, damageTaken = 0,
            spells = {}, slots = {}, spellByKey = {}, blessings = {}, blessingOrder = {}, buffs = {}, banished = {},
            enemies = {}, enemyCount = 0, elist = {}, ex = {}, ey = {}, en = 0,
            summons = {}, corpses = {}, pickups = {}, projectiles = {}, lines = {}, fx = {}, lightnings = {}, sched = {},
            meter = {}, loot = {}, pendingLevels = 0, pendingChests = 0, hand = nil, handsDealt = 0,
            rerolls = CFG.BASE_REROLLS + Profile.perk('rerolls'), banishes = CFG.BASE_BANISHES + Profile.perk('banish'),
            livesUsed = 0, invulnUntil = 0, invulnerable = false, magnetUntil = 0, tagCount = 0,
            attackClock = 0.5, spawnClock = 1.0, slowClock = 0, summonClock = 1.0, hudClock = 0,
            rings = 0, finalAt = nil, nextElite = 75, nextBoss = 1, finalSpawned = false, boss = nil,
            moving = false, anim = '', animLock = 0, spinUntil = 0, images = {},
            attackAnim = def.attackAnim or 'attack', castAnim = def.castAnim, morph = nil,
            interactables = {}, worldChestsOpened = 0, objectClock = GetRandomReal(58, 78), hitFeedbackAt = 0,
            -- Item effects: when each is ready again, and their counters.
            thirstUntil = 0, souls = 0, soulKills = 0, wardReady = 0, escapeReady = 0, sanctuaryReady = 0, flamesClock = 1}

        G.playMusic(zone.music)
        local f = zone.fog
        SetTerrainFogEx(0, f[4], f[5], 0.5, f[1], f[2], f[3])
        SetFloatGameState(GAME_STATE_TIME_OF_DAY, zone.time)

        local hero = CreateUnit(G.PLAYER, FourCC(def.id), G.cx, G.cy, 270)
        if hero == nil then
            hero = CreateUnit(G.PLAYER, FourCC('Hamg'), G.cx, G.cy, 270)
        end
        R.hero = hero
        R.hx, R.hy = G.cx, G.cy
        local range, missile, speed, cooldown = G.readWeapon(hero)
        R.melee = range <= 250
        R.attackRange = R.melee and 230 or U.clamp(range, 550, 700)
        R.missile = missile ~= '' and missile or FX.arcane
        R.missileSpeed = U.clamp(speed, 700, 1500)
        R.attackCooldown = U.clamp(cooldown * 0.6, 0.7, 1.3)
        R.weaponType = G.readWeaponType(hero)
        -- Movement and attacks are scripted, so the native ones go away. This
        -- is what lets the hero attack while walking.
        UnitRemoveAbility(hero, FourCC('Aatk'))
        UnitRemoveAbility(hero, FourCC('Amov'))
        -- Night Elf heroes (Warden, Priestess) carry Shadowmeld: a hero the
        -- script moves never walks natively, so at night it stayed hidden.
        UnitRemoveAbility(hero, FourCC('Ashm'))
        -- Standalone engine: right-clicks only report the point (no native
        -- walk that resets the animation and needs a stop), and swings and
        -- casts can play on the upper body while the legs keep walking.
        local scriptOrders = rawget(_G, 'EngineUnitScriptOrders')
        if Engine.active() and type(scriptOrders) == 'function' then
            scriptOrders(hero, true)
            R.scriptOrders = true
        end
        local upper = rawget(_G, 'EngineUnitUpperAnimation')
        if Engine.active() and type(upper) == 'function' then
            R.upperAnim = upper
        end
        SuspendHeroXP(hero, true)
        UnitModifySkillPoints(hero, -GetHeroSkillPoints(hero))
        R.baseMove = U.clamp(GetUnitDefaultMoveSpeed(hero), 260, 330)
        R.baseScale = 1.0
        if UNIT_RF_SCALING_VALUE ~= nil then
            local ok, scale = pcall(BlzGetUnitRealField, hero, UNIT_RF_SCALING_VALUE)
            if ok and type(scale) == 'number' and scale > 0 then
                R.baseScale = scale
            end
        end

        G.recomputeStats()
        local start = G.startSpell(def)
        G.learnSpell(start, 1.0)
        Profile.data.codex[start] = 1
        if Engine.active() then
            -- Test aid: +set survivor_spells "thunder_clap mirror_image" adds spells.
            for key in tostring(EngineCvar('survivor_spells') or ''):gmatch('[a-z_]+') do
                if SPELLS[key] and R.spellByKey[key] == nil then
                    G.learnSpell(key, 1.0)
                end
            end
            -- Test aid: +set survivor_boss 2 (a zone boss) or final brings it in 3 s after the start.
            local bossAid = tostring(EngineCvar('survivor_boss') or '')
            if bossAid ~= '' then
                G.after(3, function()
                    local index = tonumber(bossAid)
                    if bossAid == 'final' then
                        G.spawnBoss(R.zone.final, true)
                    elseif index and R.zone.bosses[index] then
                        G.spawnBoss(R.zone.bosses[index], false)
                    end
                end)
            end
        end
        SetWidgetLife(hero, BlzGetUnitMaxHP(hero))

        EnableSelect(true, true)
        SelectUnitForPlayerSingle(hero, G.PLAYER)
        EnableSelect(false, false)
        ResetToGameCamera(0)
        SetCameraTargetController(hero, 0, 0, false)
        SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, CFG.CAMERA_DISTANCE, 0)
        SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, 304, 0)
        SetCameraField(CAMERA_FIELD_ROTATION, 90, 0)
        SetCameraField(CAMERA_FIELD_ZOFFSET, 0, 0)
        SetCameraField(CAMERA_FIELD_FARZ, 5000, 0)

        -- Script movement (SetUnitX/Y) skips pathing, so the hero collides
        -- with enemies by hand (G.collide), with the game's own radii.
        R.heroRadius = G.unitRadius(hero, 32)

        for _ = 1, 4 do
            local x, y = G.spawnPoint(550, 750)
            G.createEnemy(G.pickEnemyType(), x, y, {})
        end
        -- A gold vein, a barrel and a wooden chest lie near the start, as in
        -- the campaign's Forgotten Hollow; more turn up during the run.
        if Engine.active() and EngineCvar('survivor_objects') == 'all' then
            -- Test aid: +set survivor_objects all lays every kind in a ring.
            for i, kind in ipairs(WORLD_OBJECT_KINDS) do
                local a = TWO_PI * i / #WORLD_OBJECT_KINDS
                G.spawnWorldObject(kind, R.hx + math.cos(a) * 420, R.hy + math.sin(a) * 420, true)
            end
        else
            for _, kind in ipairs({'vein', 'barrel', 'chest'}) do
                local x, y = G.worldObjectPoint(300, 520)
                G.spawnWorldObject(kind, x, y)
            end
        end
        G.spawnCompanion()
        Hud.show()
        Hud.banner(U.col(GOLD, zone.name) .. '  -  ' .. zone.subtitle .. '  -  ' .. U.col(R.diff.hex, R.diff.name))
    end

    -- quiet: bank the run without the end screen (leaving endless mode from
    -- the game menu). An endless run's victory was banked when the final
    -- boss fell, so its end only adds what came after.
    function G.endRun(victory, quiet)
        if R == nil or R.ended then
            return
        end
        R.ended = true
        R.victory = victory or R.endless
        victory = victory and not R.endless
        if R.hand then
            R.hand = nil
            Cards.hide()
        end
        for u in pairs(R.enemies) do
            PauseUnit(u, true)
        end
        for u in pairs(R.summons) do
            PauseUnit(u, true)
        end
        PauseUnit(R.hero, true)
        Hud.showWorldFrames(false)

        local p = Profile.data
        local banked = R.banked or {gold = 0, kills = 0, bosses = 0}
        local gold = math.floor((R.gold - banked.gold) * R.diff.reward + 0.5)
        if victory then
            gold = gold + math.floor(50 * R.zone.tier * R.diff.reward)
        end
        R.goldEarned = gold
        p.gold = p.gold + gold
        p.goldTotal = p.goldTotal + gold
        p.kills = p.kills + R.kills - banked.kills
        p.bosses = p.bosses + R.bosses - banked.bosses
        p.heroTime[R.def.id] = math.max(p.heroTime[R.def.id] or 0, math.floor(R.time))
        Profile.inc(p.heroBosses, R.def.id, R.bosses - banked.bosses)
        if not R.endless then
            p.runs = p.runs + 1
        end
        R.banked = {gold = R.gold, kills = R.kills, bosses = R.bosses}
        p.bestLevel = math.max(p.bestLevel, R.level)
        if R.endless then
            local zoneKey = tostring(R.zoneIndex)
            p.endless[zoneKey] = math.max(p.endless[zoneKey] or 0, math.floor(R.time))
        end
        if victory then
            local _, factionIndex = U.factionOf(R.def)
            p.wins = p.wins + 1
            Profile.inc(p.zoneWins, R.zoneIndex)
            Profile.inc(p.heroWins, R.def.id)
            Profile.inc(p.factionWins, factionIndex)
            Profile.inc(p.diffWins, R.diffIndex)
            p.unlocked = math.max(p.unlocked, math.min(#ZONES, R.zone.rank + 1))
            local zoneKey = tostring(R.zoneIndex)
            local best = p.zoneBest[zoneKey]
            if best == nil or R.time < best then
                p.zoneBest[zoneKey] = math.floor(R.time)
            end
            p.zoneDiff[zoneKey] = math.max(p.zoneDiff[zoneKey] or 0, R.diff.index)
            -- Keystone timer: the faster the final boss falls, the bigger the upgrade.
            if R.diff.key == 'mplus' then
                local taken = R.time - (R.finalAt or CFG.RUN_LENGTH)
                R.keyUpgrade = 0
                for _, chest in ipairs(KEY_CHESTS) do
                    if taken <= chest[1] then
                        R.keyUpgrade = chest[2]
                        break
                    end
                end
                if R.keyUpgrade > 0 then
                    p.keyBest[zoneKey] = math.max(p.keyBest[zoneKey] or 0, R.diff.level)
                    p.keyMax[zoneKey] = math.max(p.keyMax[zoneKey] or 2, R.diff.level + R.keyUpgrade)
                end
            end
        end
        R.newAchievements = Profile.checkAchievements()
        Profile.save()
        if not quiet then
            Finale.show()
        end
    end

    -- The end screen's Endless button: the won run goes on where it stopped.
    function G.continueEndless()
        if R == nil or not R.ended or not R.victory or R.endless then
            return
        end
        Finale.hide()
        R.ended = false
        R.endless = true
        R.endlessAt = R.time
        R.nextEndlessBoss = R.time + 60
        R.endlessBoss = 0
        R.nextElite = R.time + 20
        -- The end screen lists only what endless mode adds.
        R.loot = {}
        R.newAchievements = nil
        for u in pairs(R.enemies) do
            PauseUnit(u, R.paused)
        end
        for u in pairs(R.summons) do
            PauseUnit(u, R.paused)
        end
        PauseUnit(R.hero, R.paused)
        Hud.showWorldFrames(not R.paused)
        Hud.banner(U.col(RED, 'Endless mode') .. '  -  the horde grows stronger every minute')
        G.tryOpenHand()
    end

    function G.cleanup()
        if R == nil then
            return
        end
        for u, info in pairs(R.enemies) do
            if info.aura then
                DestroyEffect(info.aura)
            end
            RemoveUnit(u)
        end
        for u in pairs(R.corpses) do
            RemoveUnit(u)
        end
        for u in pairs(R.summons) do
            RemoveUnit(u)
        end
        for _, p in ipairs(R.pickups) do
            DestroyEffect(p.fx)
        end
        if R.companion then
            DestroyEffect(R.companion.fx)
        end
        for _, p in ipairs(R.projectiles) do
            DestroyEffect(p.fx)
        end
        for _, p in ipairs(R.lines) do
            if p.fx then
                DestroyEffect(p.fx)
            end
        end
        for _, inst in ipairs(R.spells) do
            if inst.orbs then
                for _, fx in ipairs(inst.orbs) do
                    DestroyEffect(fx)
                end
            end
            if inst.attachFx then
                DestroyEffect(inst.attachFx)
            end
        end
        for _, buff in pairs(R.buffs) do
            if buff.fx then
                DestroyEffect(buff.fx)
            end
        end
        for fx in pairs(R.fx) do
            DestroyEffect(fx)
        end
        for bolt in pairs(R.lightnings) do
            DestroyLightning(bolt)
        end
        for u in pairs(R.images) do
            RemoveUnit(u)
        end
        G.clearWorldObjects()
        RemoveUnit(R.hero)
        R = nil
        Hud.hide()
        Cards.hide()
        Finale.hide()
    end


    local SOURCE_NAMES = {attack = 'Auto Attack', thorns = 'Thorns', revive = 'Second Chance'}
    for key, effect in pairs(ITEM_EFFECTS) do
        SOURCE_NAMES[key] = effect.name
    end
    local function sourceName(key)
        if SOURCE_NAMES[key] then
            return SOURCE_NAMES[key]
        end
        local def = SPELLS[key]
        return def and def.name or key
    end

    -- Character stats panel rows: label, icon (the blessing card that raises
    -- the stat, else an ability), and the value as shown. base is the value
    -- the hero starts with (a number, or a function of the hero): anything
    -- better shows in green. attr marks the three attributes: the hero's
    -- primary one has a gold label.
    local function statPct(x)
        return U.num(x * 100) .. '\037'
    end
    local function statBonus(x)
        return (x >= 0 and '+' or '') .. statPct(x)
    end
    local function statWhole(x)
        return tostring(math.floor(x + 0.0001))
    end
    local STAT_ROWS = {
        {label = 'Strength', bless = 'strength', attr = 'str', base = function(h) return h.attr.str end,
            get = function(s) return s.str, statWhole(s.str) end},
        {label = 'Agility', bless = 'agility', attr = 'agi', base = function(h) return h.attr.agi end,
            get = function(s) return s.agi, statWhole(s.agi) end},
        {label = 'Intellect', bless = 'intellect', attr = 'int', base = function(h) return h.attr.int end,
            get = function(s) return s.int, statWhole(s.int) end},
        {label = 'Stamina', bless = 'stamina', base = function(h) return h.attr.str end,
            get = function(s) return s.sta, statWhole(s.sta) end},
        {label = 'Armor', bless = 'armor', base = function(h) return (h.armor or 0) + CFG.ARMOR_PER_AGILITY * h.attr.agi end,
            get = function(s) return s.armor, U.num(s.armor) end},
        {label = 'Attack damage', code = 'AOae', icon = 'BTNCommand', base = function(h) return h.damage + h.attr[h.primary] end,
            get = function(s) return s.attackDamage, statWhole(s.attackDamage) end},
        -- No code: Sorceress training's own art starts with the Adept icon,
        -- which the trimmed game data does not have.
        {label = 'Spell power', icon = 'BTNSorceressMaster',
            get = function(s) return s.spellPower - 1, statBonus(s.spellPower - 1) end},
        {label = 'Mana', code = 'ANms', icon = 'BTNNeutralManaShield', base = function(h) return CFG.MANA_PER_INTELLECT * h.attr.int end,
            get = function(s) return s.maxMana, statWhole(s.maxMana) end},
        {label = 'Mana regeneration', code = 'AHab', icon = 'BTNBrilliance',
            base = function(h) return CFG.MANA_REGEN_BASE + CFG.MANA_REGEN_PER_INTELLECT * h.attr.int end,
            get = function(s) return s.manaRegen, U.num(s.manaRegen) .. ' /s' end},
        {label = 'Damage bonus', code = 'AEar', icon = 'BTNTrueShot', get = function(s) return s.damage, statBonus(s.damage) end},
        {label = 'Attack speed', bless = 'ferocity', get = function(s) return s.attackSpeed, statBonus(s.attackSpeed) end},
        {label = 'Critical chance', bless = 'precision', base = 0.05, get = function(s) return s.crit, statPct(s.crit) end},
        {label = 'Critical damage', bless = 'brutality', base = 1.75, get = function(s) return s.critMult, statPct(s.critMult) end},
        {label = 'Spell haste', bless = 'haste', get = function(s) return s.cdr, statBonus(s.cdr) end},
        {label = 'Area', bless = 'reach', get = function(s) return s.area, statBonus(s.area) end},
        {label = 'Spell duration', bless = 'persistence', get = function(s) return s.duration, statBonus(s.duration) end},
        {label = 'Projectiles', bless = 'multishot', get = function(s) return s.multishot, '+' .. s.multishot end},
        {label = 'Dodge', code = 'AEev', icon = 'BTNEvasion', get = function(s) return s.dodge, statPct(s.dodge) end},
        {label = 'Damage reduction', code = 'AHad', icon = 'BTNDevotion', get = function(s) return s.dr, statPct(s.dr) end},
        {label = 'Regeneration', bless = 'regeneration', get = function(s) return s.regen, U.num(s.regen) .. ' /s' end},
        {label = 'Life steal', bless = 'vampirism', get = function(s) return s.lifesteal, statPct(s.lifesteal) end},
        {label = 'Movement speed', bless = 'swiftness', get = function(s) return s.move, statBonus(s.move) end},
        {label = 'Pickup range', bless = 'magnetism', get = function(s) return s.pickup, statBonus(s.pickup) end}
    }

    ---------------------------------------------------------------------------
    -- In-run HUD
    ---------------------------------------------------------------------------
    -- Frame-space x of the visible screen's left and right edges. Reforged
    -- shows the 4:3 area; the engine widens it with the window (vid_aspect).
    function Hud.edges()
        local aspect = Engine.active() and tonumber(EngineCvar('vid_aspect')) or nil
        if aspect and aspect > 4 / 3 then
            return 0.4 - 0.3 * aspect, 0.4 + 0.3 * aspect
        end
        return 0.0, 0.8
    end

    -- The HUD is built in groups pinned to a screen corner or edge; every
    -- offset and size is multiplied by the interface size (Options, 'hud').
    function Hud.build()
        -- One holder made at boot keeps the HUD under the cards and menus
        -- (frames draw in tree order) when a new interface size rebuilds it.
        Hud.holder = Hud.holder or UI.group(UI.game)
        local root = UI.group(Hud.holder)
        Hud.root = root
        local k = Options.value('hud') / 100
        local left, right = Hud.edges()
        Hud.builtLeft = left

        -- Hero frame, top left corner: portrait, health, mana, buffs.
        local ax, ay = left + 0.004, 0.597
        local function tl(dx, dtop)
            return ax + dx * k, ay + dtop * k
        end
        -- The panel's gold line sits about 0.006 inside its edge (0.0125
        -- corner pieces): the portrait's frame keeps 0.0095 on every side.
        local x, top = tl(0, 0)
        UI.panel(root, x, top, 0.236 * k, 0.078 * k, 215)
        x, top = tl(0.014, -0.014)
        Hud.portrait = UI.icon(root, TEX.white, x, top, 0.05 * k)
        Hud.portraitAt = {x, top, 0.05 * k}
        x, top = tl(0.044, -0.052)
        Hud.levelBox = UI.frame(root, TPL.well, x, top, 0.026 * k, 0.018 * k)
        x, top = tl(0.046, -0.054)
        Hud.levelText = UI.text(root, '1', x, top, 0.022 * k, 0.014 * k, 0.0085 * k, TEXT_JUSTIFY_CENTER)
        x, top = tl(0.077, -0.008)
        Hud.name = UI.text(root, '', x, top, 0.152 * k, 0.014 * k, 0.0095 * k)
        x, top = tl(0.079, -0.026)
        Hud.health = UI.bar(root, x, top, 0.146 * k, 0.012 * k, 40, 190, 50, 0.0078 * k)
        x, top = tl(0.079, -0.044)
        Hud.mana = UI.bar(root, x, top, 0.146 * k, 0.009 * k, 50, 90, 220, 0.0066 * k)
        x, top = tl(0.077, -0.058)
        Hud.lives = UI.text(root, '', x, top, 0.152 * k, 0.012 * k, 0.0078 * k)
        Hud.buffIcons = {}
        for i = 1, 6 do
            x, top = tl(0.008 + (i - 1) * 0.023, -0.088)
            local o = UI.icon(root, TEX.white, x, top, 0.019 * k)
            UI.showIcon(o, false)
            Hud.buffIcons[i] = o
        end

        -- Character stats, under the hero frame and its buffs; the stats key
        -- (C) shows or hides them (Profile.data.opts.stats = 0 when hidden).
        Hud.statsRoot = UI.group(root)
        local rowH = 0.0118 * k
        x, top = tl(0, -0.114)
        UI.plate(Hud.statsRoot, x, top, 0.156 * k, 0.03 * k + #STAT_ROWS * rowH, 215)
        x, top = tl(0.01, -0.12)
        Hud.statsTitle = UI.text(Hud.statsRoot, '', x, top, 0.136 * k, 0.014 * k, 0.0082 * k)
        Hud.statRows = {}
        Hud.statLabels = {}
        for i, row in ipairs(STAT_ROWS) do
            local rowTop = -0.137 - (i - 1) * 0.0118
            local b = row.bless and BLESSING_BY_KEY[row.bless]
            x, top = tl(0.01, rowTop + 0.0005)
            UI.image(Hud.statsRoot, b and U.icon(b.code, b.icon) or U.icon(row.code, row.icon), x, top, 0.0098 * k, 0.0098 * k)
            x, top = tl(0.024, rowTop)
            Hud.statLabels[i] = UI.text(Hud.statsRoot, U.col('bfb6a8', row.label), x, top, 0.09 * k, rowH, 0.0072 * k)
            x, top = tl(0.104, rowTop)
            Hud.statRows[i] = UI.text(Hud.statsRoot, '', x, top, 0.042 * k, rowH, 0.0072 * k, TEXT_JUSTIFY_RIGHT)
        end
        Hud.statText = {}

        -- Clock and boss, top center.
        local function tc(dx, dtop)
            return 0.4 + dx * k, 0.6 + dtop * k
        end
        x, top = tc(-0.1, -0.002)
        Hud.clock = UI.text(root, '00:00', x, top, 0.2 * k, 0.03 * k, 0.022 * k, TEXT_JUSTIFY_CENTER)
        if Engine.touch() then
            -- A phone has no Escape key: this opens the game menu.
            x, top = tc(0.07, -0.006)
            UI.button(root, x, top, 0.05 * k, 0.022 * k, 'Menu', function()
                G.onAction('menu')
            end, 'dark', 0.0088 * k)
        end
        x, top = tc(-0.15, -0.032)
        Hud.subline = UI.text(root, '', x, top, 0.3 * k, 0.014 * k, 0.0085 * k, TEXT_JUSTIFY_CENTER)
        x, top = tc(-0.13, -0.047)
        Hud.bossName = UI.text(root, '', x, top, 0.26 * k, 0.013 * k, 0.009 * k, TEXT_JUSTIFY_CENTER)
        x, top = tc(-0.11, -0.062)
        Hud.bossBar = UI.bar(root, x, top, 0.22 * k, 0.011 * k, 200, 40, 30, 0.0075 * k)
        Hud.bossFrames = {Hud.bossName, Hud.bossBar.back, Hud.bossBar.fill, Hud.bossBar.edge, Hud.bossBar.text}

        -- Zone name, top right corner.
        Hud.zoneLabel = UI.text(root, '', right - 0.012 - 0.2 * k, 0.597, 0.2 * k, 0.016 * k, 0.0095 * k, TEXT_JUSTIFY_RIGHT)

        -- Center banner and toast.
        x, top = tc(-0.3, -0.15)
        Hud.bannerText = UI.text(root, '', x, top, 0.6 * k, 0.03 * k, 0.016 * k, TEXT_JUSTIFY_CENTER)
        Hud.toastFrames = {}
        x, top = tc(-0.145, -0.082)
        local toast = UI.panel(root, x, top, 0.29 * k, 0.042 * k, 235)
        x, top = tc(-0.138, -0.089)
        Hud.toastIcon = UI.icon(root, TEX.white, x, top, 0.028 * k)
        x, top = tc(-0.102, -0.087)
        Hud.toastTitle = UI.text(root, '', x, top, 0.24 * k, 0.015 * k, 0.0092 * k)
        x, top = tc(-0.102, -0.103)
        Hud.toastText = UI.text(root, '', x, top, 0.24 * k, 0.014 * k, 0.0082 * k)
        for _, f in ipairs({toast.bg, Hud.toastIcon.frame, Hud.toastIcon.img, Hud.toastTitle, Hud.toastText}) do
            Hud.toastFrames[#Hud.toastFrames + 1] = f
        end

        -- Spell slots and experience bar, bottom center, close to the edge.
        Hud.slots = {}
        local size, gap = 0.032 * k, 0.007 * k
        local x0 = 0.4 - (CFG.SPELL_SLOTS * size + (CFG.SPELL_SLOTS - 1) * gap) / 2
        local slotTop = (0.03 + 0.016 + 0.034) * k
        Hud.slotTop = slotTop
        for i = 1, CFG.SPELL_SLOTS do
            local sx = x0 + (i - 1) * (size + gap)
            -- Hovering a slot shows what its spell does (Hud.spellTip);
            -- clicking casts it, like its key (G.castSpell).
            local slot = UI.icon(root, TEX.white, sx, slotTop, size, function()
                G.castSpell(i)
            end, function()
                Hud.spellTip(i)
            end, Hud.hideTip)
            slot.shade = UI.box(root, sx, slotTop, size, size, 0, 0, 0, 170)
            -- The key on a dark corner, readable over bright icons.
            slot.keyBox = UI.box(root, sx, slotTop, 0.0105 * k, 0.0115 * k, 0, 0, 0, 175)
            slot.keyText = UI.text(root, '', sx + 0.002 * k, slotTop - 0.001 * k, size, 0.011 * k, 0.0072 * k)
            slot.autoText = UI.text(root, '', sx, slotTop + 0.012 * k, size, 0.011 * k, 0.0072 * k, TEXT_JUSTIFY_CENTER)
            slot.rank = UI.text(root, '', sx, slotTop - size + 0.011 * k, size - 0.002 * k, 0.011 * k, 0.0078 * k, TEXT_JUSTIFY_RIGHT)
            slot.x, slot.size = sx, size
            Hud.slots[i] = slot
        end
        Hud.xp = UI.bar(root, 0.4 - 0.2 * k, 0.03 * k, 0.4 * k, 0.013 * k, 120, 84, 230, 0.0082 * k)

        -- Blessings and counters, bottom left corner.
        local bx = left + 0.01
        Hud.blessingIcons = {}
        for i = 1, #BLESSINGS do
            local column = math.fmod(i - 1, 9)
            local row = (i - 1) // 9
            local ix = bx + column * 0.022 * k
            local itop = (0.078 - row * 0.026) * k
            local o = UI.icon(root, TEX.white, ix, itop, 0.018 * k, nil, function()
                Hud.blessingTip(i)
            end, Hud.hideTip)
            o.rank = UI.text(root, '', ix, itop - 0.009 * k, 0.018 * k, 0.009 * k, 0.0068 * k, TEXT_JUSTIFY_RIGHT)
            UI.showIcon(o, false)
            Hud.blessingIcons[i] = o
        end
        Hud.counters = UI.text(root, '', bx, 0.024 * k, 0.2 * k, 0.014 * k, 0.0088 * k)

        -- Damage meter, bottom right corner: the thin plate, so the rows keep
        -- clear of its edge (the ornate escape-menu frame is too thick here).
        local function br(dx, dtop)
            return right - 0.006 + dx * k, dtop * k
        end
        x, top = br(-0.194, 0.146)
        UI.plate(root, x, top, 0.194 * k, 0.136 * k, 225)
        x, top = br(-0.183, 0.136)
        UI.text(root, U.col(GOLD, 'Damage Done'), x, top, 0.09 * k, 0.014 * k, 0.0082 * k)
        x, top = br(-0.101, 0.136)
        Hud.dps = UI.text(root, '', x, top, 0.09 * k, 0.014 * k, 0.0075 * k, TEXT_JUSTIFY_RIGHT)
        Hud.meterRows = {}
        Hud.meterW = 0.176 * k
        local colors = {{200, 60, 50}, {60, 100, 210}, {210, 160, 50}, {80, 170, 80}, {150, 80, 210}, {130, 130, 130}}
        for i = 1, 6 do
            local rowTop = 0.118 - (i - 1) * 0.0165
            local row = {}
            x, top = br(-0.185, rowTop)
            row.bar = UI.box(root, x, top, Hud.meterW, 0.0135 * k, colors[i][1], colors[i][2], colors[i][3], 190, TEX.barFill)
            x, top = br(-0.181, rowTop)
            row.name = UI.text(root, '', x, top, 0.1 * k, 0.0135 * k, 0.0072 * k)
            x, top = br(-0.104, rowTop)
            row.value = UI.text(root, '', x, top, 0.092 * k, 0.0135 * k, 0.0072 * k, TEXT_JUSTIFY_RIGHT)
            Hud.meterRows[i] = row
        end

        -- Inventory, under the zone name: the six items carried into the
        -- run, two by three as on the Warcraft III console.
        local invW, invH, cell, step = 0.084 * k, 0.128 * k, 0.028 * k, 0.034 * k
        local ix0, itop0 = right - 0.006 - invW, 0.597 - 0.02 * k
        Hud.invAt = {ix0, itop0, invH}
        UI.plate(root, ix0, itop0, invW, invH, 225)
        UI.text(root, U.col(GOLD, 'Inventory'), ix0, itop0 - 0.005 * k, invW, 0.014 * k, 0.0078 * k, TEXT_JUSTIFY_CENTER)
        Hud.gearIcons = {}
        for slot = 1, INVENTORY_SIZE do
            local column = math.fmod(slot - 1, 2)
            local row = (slot - 1) // 2
            local o = UI.icon(root, TEX.white, ix0 + 0.011 * k + column * step, itop0 - 0.024 * k - row * (cell + 0.005 * k),
                cell, nil, function()
                    Hud.gearTip(slot)
                end, Hud.hideTip)
            Hud.gearIcons[slot] = o
        end

        -- Tooltip of the hovered spell slot or blessing, made last so it
        -- draws over the rest of the HUD; Hud.showTip moves it into place.
        Hud.tip = UI.tooltip(root, k, 0.25, 0.1)

        BlzFrameSetVisible(root, false)
    end

    -- Shows the tooltip with its bottom-left corner at (x, bottom).
    function Hud.showTip(x, bottom, icon, title, sub, body)
        UI.showTooltip(Hud.tip, x, bottom, icon, title, sub, body)
    end

    function Hud.hideTip()
        if Hud.tip then
            UI.hideTooltip(Hud.tip)
        end
    end

    -- A spell slot: its name and rank, kind and cooldown, and what it does
    -- at its current rank and power.
    function Hud.spellTip(i)
        local inst = R and R.slots[i]
        if inst == nil then
            return
        end
        local def = inst.def
        local v = inst.v or G.spellValues(def, inst.rank, inst.power, R.stats)
        local sub = KIND_NAMES[def.kind] or ''
        local body = G.describe(def, v)
        if G.canToggle(inst) then
            if v.cd and v.cd > 0 then
                sub = sub .. '  -  every ' .. U.num(v.cd) .. ' s'
            end
            if v.mana > 0 then
                sub = sub .. '  -  ' .. U.col('8fb4ff', v.mana .. ' mana')
            end
            body = body .. '\n' .. U.col(GREY, 'Click or press ' .. Keys.label('spell' .. i) .. ' to cast.  '
                .. Keys.label('auto' .. i) .. ' turns autocast ' .. (inst.auto and 'off.' or 'on.'))
        else
            body = body .. '\n' .. U.col(GREY, 'Always on.')
        end
        Hud.showTip(0.4 - Hud.tip.w / 2, Hud.slotTop + 0.016 * Hud.tip.k, U.spellIcon(def),
            U.col(GOLD, def.name) .. U.col(GREY, '   rank ' .. inst.rank .. rankLimit(def.maxRank)), sub, body)
    end

    function Hud.blessingTip(i)
        local key = R and R.blessingOrder[i]
        local entry = key and R.blessings[key]
        if entry == nil then
            return
        end
        local b = BLESSING_BY_KEY[key]
        local k = Hud.tip.k
        local left = Hud.edges()
        Hud.showTip(left + 0.01, 0.094 * k, U.icon(b.code, b.icon),
            U.col(GOLD, b.name) .. U.col(GREY, '   rank ' .. entry.rank), 'Blessing',
            G.describeBlessing(b, entry.value))
    end

    -- The carried items; an empty slot is a dark square.
    function Hud.refreshGear()
        if Hud.gearIcons == nil then
            return
        end
        local worn = gearEquipped(Profile.data)
        for slot, o in ipairs(Hud.gearIcons) do
            local item = worn[slot]
            if item then
                UI.setIcon(o, gearIcon(item))
            else
                UI.setIcon(o, TEX.white)
                UI.tint(o.img, 16, 12, 9, 235)
            end
        end
    end

    function Hud.gearTip(slot)
        local item = gearEquipped(Profile.data)[slot]
        if item == nil then
            return
        end
        local ilvl = Profile.itemLevel(item)
        local at = Hud.invAt
        local body = G.describeItem(item, ilvl)
        local effect = G.describeItemEffect(item, ilvl)
        if effect then
            body = body .. '\n' .. effect
        end
        Hud.showTip(at[1] - Hud.tip.w - 0.004, at[2] - Hud.tip.h, gearIcon(item), U.col(gearHex(ilvl), item.name),
            'Item level ' .. ilvl .. '  -  ' .. ZONES[item.zone].name, body)
    end

    -- The stats panel's values; a row only gets new text when it changed.
    function Hud.refreshStats()
        local shown = Profile.data.opts.stats ~= 0
        BlzFrameSetVisible(Hud.statsRoot, shown)
        if not shown or R == nil or R.stats == nil then
            return
        end
        local texts = Hud.statText
        local title = U.col(GOLD, 'Stats') .. U.col(GREY, '   ' .. Keys.label('stats') .. ' to hide')
        if texts.title ~= title then
            texts.title = title
            BlzFrameSetText(Hud.statsTitle, title)
        end
        for i, row in ipairs(STAT_ROWS) do
            local value, text = row.get(R.stats)
            local base = type(row.base) == 'function' and row.base(R.def) or row.base or 0
            text = U.col(value > base + 0.0001 and GREEN or 'd8cfc0', text)
            if texts[i] ~= text then
                texts[i] = text
                BlzFrameSetText(Hud.statRows[i], text)
            end
            local label = U.col(row.attr and row.attr == R.def.primary and GOLD or 'bfb6a8', row.label)
            if texts['label' .. i] ~= label then
                texts['label' .. i] = label
                BlzFrameSetText(Hud.statLabels[i], label)
            end
        end
    end

    function Hud.toggleStats()
        local opts = Profile.data.opts
        opts.stats = (opts.stats == 0) and 1 or 0
        if R and Hud.statsRoot then
            Hud.refreshStats()
        end
        Profile.save()
    end

    -- A new interface size: build the HUD again in place.
    function Hud.rebuild()
        if Hud.root then
            BlzDestroyFrame(Hud.root)
        end
        Hud.build()
        if R then
            Hud.show()
            Hud.updateMeter()
        end
    end

    function Hud.placeWorldFrames()
        if CFG.SHOW_PORTRAIT then
            local portrait = BlzGetOriginFrame(ORIGIN_FRAME_PORTRAIT, 0)
            local at = Hud.portraitAt
            UI.place(portrait, at[1] + 0.001, at[2] - 0.001, at[3] - 0.002, at[3] - 0.002)
        end
        if CFG.SHOW_MINIMAP then
            local minimap = BlzGetOriginFrame(ORIGIN_FRAME_MINIMAP, 0)
            UI.place(minimap, 0.686, 0.581, 0.106, 0.106)
        end
    end

    function Hud.showWorldFrames(visible)
        if CFG.SHOW_PORTRAIT then
            BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_PORTRAIT, 0), visible)
        end
        if CFG.SHOW_MINIMAP then
            BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_MINIMAP, 0), visible)
        end
    end

    function Hud.show()
        local faction = U.factionOf(R.def)
        UI.setIcon(Hud.portrait, U.heroIcon(R.def))
        BlzFrameSetText(Hud.name, U.col(faction.hex, R.def.name))
        BlzFrameSetText(Hud.zoneLabel, U.col(GOLD, R.zone.name) .. U.col(GREY, '  ' .. R.diff.name))
        BlzFrameSetText(Hud.bannerText, '')
        for _, f in ipairs(Hud.toastFrames) do
            BlzFrameSetVisible(f, false)
        end
        Hud.hideTip()
        Hud.refreshSpells()
        Hud.refreshGear()
        Hud.update()
        BlzFrameSetVisible(Hud.root, true)
        Hud.placeWorldFrames()
        Hud.showWorldFrames(true)
    end

    function Hud.hide()
        BlzFrameSetVisible(Hud.root, false)
        Hud.showWorldFrames(false)
    end

    function Hud.banner(s)
        BlzFrameSetText(Hud.bannerText, s)
        Hud.bannerId = (Hud.bannerId or 0) + 1
        local id = Hud.bannerId
        TimerStart(CreateTimer(), 3.5, false, function()
            if Hud.bannerId == id then
                BlzFrameSetText(Hud.bannerText, '')
            end
            DestroyTimer(GetExpiredTimer())
        end)
    end

    function Hud.toast(icon, title, text)
        UI.setIcon(Hud.toastIcon, icon)
        BlzFrameSetText(Hud.toastTitle, title)
        BlzFrameSetText(Hud.toastText, U.col(GREY, text or ''))
        for _, f in ipairs(Hud.toastFrames) do
            BlzFrameSetVisible(f, true)
        end
        Hud.toastId = (Hud.toastId or 0) + 1
        local id = Hud.toastId
        TimerStart(CreateTimer(), 4.0, false, function()
            if Hud.toastId == id then
                for _, f in ipairs(Hud.toastFrames) do
                    BlzFrameSetVisible(f, false)
                end
            end
            DestroyTimer(GetExpiredTimer())
        end)
    end

    -- Spell slots: the key that casts it in the corner, AUTO above it and a
    -- brighter frame while autocast is on, blue while the hero cannot pay for
    -- it (as Warcraft III shows a spell short of mana). Auras, orbits and
    -- passives have no key.
    function Hud.refreshSlotStates()
        if R == nil or Hud.slots == nil then
            return
        end
        for i, slot in ipairs(Hud.slots) do
            local inst = R.slots[i]
            local castable = G.canToggle(inst)
            local state = 'empty'
            if castable then
                state = (inst.waiting and 'mana' or 'ready') .. (inst.auto and ' auto' or '') .. ' ' .. Keys.label('spell' .. i)
            elseif inst then
                state = 'always'
            end
            if slot.state ~= state then
                slot.state = state
                if inst then
                    local blue = castable and inst.waiting
                    UI.tint(slot.img, blue and 90 or 255, blue and 110 or 255, 255, 255)
                    if castable and inst.auto then
                        UI.frameColor(slot, 255, 226, 120)
                    else
                        UI.frameColor(slot, 214, 170, 90)
                    end
                end
                BlzFrameSetText(slot.autoText, castable and inst.auto and U.col(GOLD, 'AUTO') or '')
                BlzFrameSetText(slot.keyText, castable and U.col('e6e6e6', Keys.label('spell' .. i)) or '')
                BlzFrameSetVisible(slot.keyBox, castable)
            end
        end
    end

    function Hud.refreshSpells()
        for i, slot in ipairs(Hud.slots) do
            local inst = R.slots[i]
            -- A new icon resets the tint: Hud.refreshSlotStates paints it again.
            slot.state = nil
            if inst then
                UI.setIcon(slot, U.spellIcon(inst.def))
                UI.frameColor(slot, 214, 170, 90)
                BlzFrameSetText(slot.rank, U.col(GOLD, tostring(inst.rank)))
            else
                BlzFrameSetTexture(slot.img, TEX.white, 0, true)
                UI.tint(slot.img, 18, 14, 10, 230)
                UI.frameColor(slot, 90, 70, 44)
                BlzFrameSetText(slot.rank, '')
                BlzFrameSetText(slot.keyText, '')
                BlzFrameSetText(slot.autoText, '')
                BlzFrameSetVisible(slot.keyBox, false)
                BlzFrameSetVisible(slot.shade, false)
            end
        end
        for i, o in ipairs(Hud.blessingIcons) do
            local key = R.blessingOrder[i]
            if key then
                local b = BLESSING_BY_KEY[key]
                UI.setIcon(o, U.icon(b.code, b.icon))
                BlzFrameSetText(o.rank, tostring(R.blessings[key].rank))
                UI.showIcon(o, true)
                BlzFrameSetVisible(o.rank, true)
            else
                UI.showIcon(o, false)
                BlzFrameSetVisible(o.rank, false)
            end
        end
    end

    function Hud.update()
        if R == nil then
            return
        end
        -- The window size reaches the script a few frames after boot, and the
        -- window may be resized: keep the HUD pinned to the real screen edges.
        if Hud.edges() ~= Hud.builtLeft then
            Hud.rebuild()
            return
        end
        local hero = R.hero
        BlzFrameSetText(Hud.clock, U.col(GOLD, U.time(R.time)))

        local nextBoss = R.zone.bosses[R.nextBoss]
        if R.endless then
            local hpScale = G.endlessScale()
            local boss = R.zone.bosses[math.fmod(R.endlessBoss, #R.zone.bosses + 1) + 1] or R.zone.final
            BlzFrameSetText(Hud.subline, U.col(RED, 'Endless') .. U.col(GREY, '  -  enemy health x' .. U.num(hpScale)
                .. '  -  ' .. boss.name .. ' in ' .. U.time(math.max(0, R.nextEndlessBoss - R.time))))
        elseif nextBoss then
            BlzFrameSetText(Hud.subline, U.col(GREY, 'next boss in ' .. U.time(nextBoss.t - R.time) .. '  -  ' .. nextBoss.name))
        elseif not R.finalSpawned then
            BlzFrameSetText(Hud.subline, U.col(RED, R.zone.final.name .. ' arrives in ' .. U.time(CFG.RUN_LENGTH - R.time)))
        elseif R.diff.key == 'mplus' then
            -- Keystone timer: show the best upgrade still in reach.
            local taken = R.time - (R.finalAt or CFG.RUN_LENGTH)
            local line = U.col(RED, 'Keystone depleted') .. U.col(GREY, '  -  defeat ' .. R.zone.final.name)
            for _, chest in ipairs(KEY_CHESTS) do
                if taken <= chest[1] then
                    line = U.col('ff8000', '+' .. chest[2] .. ' upgrade') .. U.col(GREY, ' if ' .. R.zone.final.name
                        .. ' falls in ' .. U.time(chest[1] - taken))
                    break
                end
            end
            BlzFrameSetText(Hud.subline, line)
        else
            BlzFrameSetText(Hud.subline, U.col(RED, 'Defeat ' .. R.zone.final.name .. '!'))
        end

        local boss = R.boss
        local showBoss = boss ~= nil and R.enemies[boss] ~= nil
        for _, f in ipairs(Hud.bossFrames) do
            BlzFrameSetVisible(f, showBoss)
        end
        if showBoss then
            local life, maxLife = GetWidgetLife(boss), BlzGetUnitMaxHP(boss)
            BlzFrameSetText(Hud.bossName, U.col('ff6050', GetUnitName(boss)))
            UI.setBar(Hud.bossBar, life / maxLife, U.big(life) .. ' / ' .. U.big(maxLife))
        end

        local life, maxLife = GetWidgetLife(hero), BlzGetUnitMaxHP(hero)
        UI.setBar(Hud.health, life / math.max(1, maxLife), U.big(math.max(0, life)) .. ' / ' .. U.big(maxLife))
        local mana, maxMana = R.mana or 0, R.maxMana or 0
        UI.setBar(Hud.mana, maxMana > 0 and mana / maxMana or 0,
            maxMana > 0 and (U.big(math.max(0, mana)) .. ' / ' .. U.big(maxMana)) or '')
        BlzFrameSetText(Hud.levelText, U.col(GOLD, tostring(R.level)))
        local livesLeft = R.stats.lives - R.livesUsed
        local parts = {}
        if livesLeft > 0 then
            parts[#parts + 1] = U.col(GOLD, livesLeft .. (livesLeft == 1 and ' extra life' or ' extra lives'))
        end
        if R.invulnerable then
            parts[#parts + 1] = U.col('ffe680', 'Invulnerable')
        end
        BlzFrameSetText(Hud.lives, table.concat(parts, '   '))

        UI.setBar(Hud.xp, R.xp / R.xpNext, 'Level ' .. R.level .. '     ' .. math.floor(R.xp) .. ' / ' .. R.xpNext)

        for i, slot in ipairs(Hud.slots) do
            local inst = R.slots[i]
            if inst then
                local kind = inst.def.kind
                local fraction = 0
                if kind ~= 'passive' and kind ~= 'orbit' and kind ~= 'aura' and inst.v and inst.v.cd > 0 then
                    fraction = U.clamp(inst.cd / inst.v.cd, 0, 1)
                end
                if fraction > 0.02 then
                    BlzFrameSetVisible(slot.shade, true)
                    BlzFrameSetSize(slot.shade, slot.size, slot.size * fraction)
                else
                    BlzFrameSetVisible(slot.shade, false)
                end
            end
        end
        Hud.refreshSlotStates()

        local index = 0
        for _, buff in pairs(R.buffs) do
            index = index + 1
            if index <= #Hud.buffIcons then
                UI.setIcon(Hud.buffIcons[index], buff.icon)
                UI.showIcon(Hud.buffIcons[index], true)
            end
        end
        for i = index + 1, #Hud.buffIcons do
            UI.showIcon(Hud.buffIcons[i], false)
        end

        BlzFrameSetText(Hud.counters, U.col(GREY, 'Kills ') .. U.big(R.kills) .. U.col(GREY, '    Gold ')
            .. U.col(GOLD, U.big(R.gold)) .. U.col(GREY, '    Rerolls ') .. R.rerolls)
        Hud.refreshStats()

        Hud.meterClock = (Hud.meterClock or 0) - 1
        if Hud.meterClock <= 0 then
            Hud.meterClock = 5
            Hud.updateMeter()
        end
    end

    function Hud.updateMeter()
        local rows = {}
        for key, amount in pairs(R.meter) do
            rows[#rows + 1] = {key = key, amount = amount}
        end
        table.sort(rows, function(a, b)
            return a.amount > b.amount
        end)
        local top = rows[1] and rows[1].amount or 1
        local total = math.max(1, R.damageDone)
        BlzFrameSetText(Hud.dps, U.col(GREY, U.big(R.damageDone / math.max(1, R.time)) .. ' dps'))
        for i, row in ipairs(Hud.meterRows) do
            local entry = rows[i]
            if entry then
                BlzFrameSetVisible(row.bar, true)
                BlzFrameSetSize(row.bar, math.max(0.002, Hud.meterW * entry.amount / top), Hud.meterW * 0.0135 / 0.176)
                BlzFrameSetText(row.name, i .. '. ' .. sourceName(entry.key))
                BlzFrameSetText(row.value, U.big(entry.amount) .. U.col(GREY, ' (' .. math.floor(entry.amount / total * 100 + 0.5) .. '\037)'))
            else
                BlzFrameSetVisible(row.bar, false)
                BlzFrameSetText(row.name, '')
                BlzFrameSetText(row.value, '')
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Level-up cards
    ---------------------------------------------------------------------------
    local CARD_W, CARD_H, CARD_GAP = 0.165, 0.25, 0.017

    local function cardPart(card, frame, dx, dtop, w, h)
        card.parts[#card.parts + 1] = {frame, dx, dtop, w, h}
        return frame
    end

    function Cards.buildCard(root, index)
        local card = {parts = {}, index = index}
        local w, h = CARD_W, CARD_H
        -- Escape-menu frame around one dark fill; only the icon frame and the
        -- texts carry the rarity colour. The inner gold outline lights on hover.
        card.fill = cardPart(card, UI.box(root, 0, 0.6, w - 0.016, h - 0.016, 12, 9, 7, 245), 0.008, -0.008, w - 0.016, h - 0.016)
        card.bg = cardPart(card, UI.frame(root, TPL.panel, 0, 0.6, w, h), 0, 0, w, h)
        BlzFrameSetTexture(card.bg, TEX.clear, 0, true)
        card.edge = {cardPart(card, UI.border(root, 0, 0.6, w - 0.02, h - 0.02)[1], 0.01, -0.01, w - 0.02, h - 0.02)}
        -- The card's key (Ctrl+1 by default), set by Cards.render.
        cardPart(card, UI.frame(root, TPL.well, 0, 0.6, 0.036, 0.02), 0.012, -0.014, 0.036, 0.02)
        card.badge = cardPart(card, UI.text(root, tostring(index), 0, 0.6, 0.036, 0.02, 0.0072, TEXT_JUSTIFY_CENTER), 0.012, -0.014, 0.036, 0.02)
        card.iconFrame = cardPart(card, UI.box(root, 0, 0.6, 0.064, 0.064, 255, 255, 255, 255, TEX.iconFrame), w / 2 - 0.032, -0.03, 0.064, 0.064)
        card.icon = cardPart(card, UI.image(root, TEX.white, 0, 0.6, 0.054, 0.054), w / 2 - 0.027, -0.035, 0.054, 0.054)
        card.rarityText = cardPart(card, UI.text(root, '', 0, 0.6, w, 0.012, 0.0074, TEXT_JUSTIFY_CENTER), 0, -0.097, w, 0.012)
        card.name = cardPart(card, UI.text(root, '', 0, 0.6, w - 0.02, 0.02, 0.0135, TEXT_JUSTIFY_CENTER), 0.01, -0.108, w - 0.02, 0.02)
        card.sub = cardPart(card, UI.text(root, '', 0, 0.6, w, 0.012, 0.0085, TEXT_JUSTIFY_CENTER), 0, -0.128, w, 0.012)
        card.desc = cardPart(card, UI.text(root, '', 0, 0.6, w - 0.042, 0.064, 0.0084, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP), 0.021, -0.146, w - 0.042, 0.064)
        card.foot = cardPart(card, UI.text(root, '', 0, 0.6, w, 0.014, 0.0076, TEXT_JUSTIFY_CENTER), 0, -0.212, w, 0.014)
        card.hit = cardPart(card, UI.hit(root, 0, 0.6, w, h, function()
            Cards.pick(index)
        end, function()
            card.hover = true
            Cards.paintCard(card)
        end, function()
            card.hover = false
            Cards.paintCard(card)
        end), 0, 0, w, h)
        card.banish = UI.button(root, 0, 0.6, 0.074, 0.022, '', function()
            Cards.banish(index)
        end, 'red', 0.0085)
        return card
    end

    function Cards.build()
        local root = UI.group(UI.game)
        Cards.root = root
        UI.box(root, -0.3, 0.6, 1.4, 0.6, 0, 0, 0, 205)
        Cards.pill = UI.box(root, 0.36, 0.536, 0.08, 0.02, 255, 210, 122, 255)
        Cards.pillText = UI.text(root, '', 0.36, 0.536, 0.08, 0.02, 0.0095, TEXT_JUSTIFY_CENTER)
        Cards.title = UI.text(root, '', 0.15, 0.512, 0.5, 0.05, 0.032, TEXT_JUSTIFY_CENTER)
        UI.ornament(root, 0.4, 0.457, 0.2)
        Cards.subtitle = UI.text(root, '', 0.12, 0.438, 0.56, 0.016, 0.0095, TEXT_JUSTIFY_CENTER)
        Cards.cards = {}
        for i = 1, 4 do
            Cards.cards[i] = Cards.buildCard(root, i)
        end
        UI.text(root, U.col(GREY, 'S P E L L S'), 0.13, 0.113, 0.07, 0.024, 0.0078)
        Cards.slots = {}
        for i = 1, CFG.SPELL_SLOTS do
            Cards.slots[i] = UI.icon(root, TEX.white, 0.2 + (i - 1) * 0.03, 0.112, 0.024)
        end
        Cards.skip = UI.button(root, 0.4, 0.118, 0.11, 0.032, '', function()
            Cards.skipHand()
        end, 'dark', 0.0105)
        Cards.reroll = UI.button(root, 0.52, 0.118, 0.11, 0.032, '', function()
            Cards.rerollHand()
        end, 'dark', 0.0105)
        BlzFrameSetVisible(root, false)
    end

    function Cards.moveCard(card, x, top)
        for _, part in ipairs(card.parts) do
            UI.place(part[1], x + part[2], top + part[3], part[4], part[5])
        end
        UI.moveButton(card.banish, x + (CARD_W - 0.074) / 2, top - CARD_H - 0.01, 0.074, 0.022)
    end

    function Cards.showCard(card, visible)
        for _, part in ipairs(card.parts) do
            BlzFrameSetVisible(part[1], visible)
        end
        UI.showButton(card.banish, visible)
    end

    function Cards.paintCard(card)
        UI.edgeTint(card.edge, 214, 170, 90, card.hover and 255 or 90)
        local lit = card.hover and 255 or 205
        UI.tint(card.bg, lit, lit, lit, 255)
    end

    function Cards.rollRarity(minimum)
        local luck = R.stats.luck
        local weights, total = {}, 0
        for i, rarity in ipairs(RARITY) do
            local w = rarity.weight
            if i >= 3 then
                w = w * (1 + luck)
            end
            if i < (minimum or 1) then
                w = 0
            end
            weights[i] = w
            total = total + w
        end
        local roll = GetRandomReal(0, total)
        for i, w in ipairs(weights) do
            roll = roll - w
            if roll <= 0 and w > 0 then
                return i
            end
        end
        return #RARITY
    end

    function Cards.options(exclude)
        local list = {}
        local slotsFree = #R.spells < CFG.SPELL_SLOTS
        for _, key in ipairs(R.def.pool) do
            if not R.banished[key] and not exclude[key] and SPELLS[key] then
                local inst = R.spellByKey[key]
                if inst then
                    if inst.def.maxRank == nil or inst.rank < inst.def.maxRank then
                        list[#list + 1] = {type = 'spell', key = key, w = 4}
                    end
                elseif slotsFree then
                    list[#list + 1] = {type = 'spell', key = key, w = #R.spells < 3 and 7 or 3}
                end
            end
        end
        local primary = ({str = 'strength', agi = 'agility', int = 'intellect'})[R.def.primary]
        for _, b in ipairs(BLESSINGS) do
            if not R.banished[b.key] and not exclude[b.key] and Profile.blessingOpen(b) then
                local w = b.key == primary and BLESSING_WEIGHT.primary
                    or b.attribute and BLESSING_WEIGHT.attribute or BLESSING_WEIGHT.other
                list[#list + 1] = {type = 'blessing', key = b.key, w = w}
            end
        end
        return list
    end

    function Cards.draw(count, exclude, minimum)
        local options = Cards.options(exclude or {})
        local picked = {}
        for _ = 1, count do
            local total = 0
            for _, o in ipairs(options) do
                total = total + o.w
            end
            if total <= 0 then
                break
            end
            local roll = GetRandomReal(0, total)
            local chosen = #options
            for index, o in ipairs(options) do
                roll = roll - o.w
                if roll <= 0 then
                    chosen = index
                    break
                end
            end
            local o = table.remove(options, chosen)
            picked[#picked + 1] = {type = o.type, key = o.key, rarity = Cards.rollRarity(minimum)}
            Profile.data.codex[o.key] = 1
        end
        if #picked == 0 then
            picked = {{type = 'gold', key = 'gold', rarity = 1}, {type = 'heal', key = 'heal', rarity = 1}}
        end
        return picked
    end

    function Cards.open(kind)
        local size = CFG.HAND_SIZE
        if Profile.perk('wide') > 0 or (R.handsDealt == 0 and Profile.perk('opening') > 0) then
            size = 4
        end
        R.handsDealt = R.handsDealt + 1
        local minimum = kind == 'chest' and 3 or 1
        R.hand = {kind = kind, size = size, minimum = minimum, cards = Cards.draw(size, nil, minimum)}
        G.setPaused(true)
        Cards.render()
        BlzFrameSetVisible(Cards.root, true)
        -- Test aid (engine): +set survivor_autopick 1 takes the first card,
        -- so long unattended runs never stall on a hand.
        if Engine.active() and EngineCvar('survivor_autopick') == '1' then
            local hand = R.hand
            TimerStart(CreateTimer(), 0.3, false, function()
                DestroyTimer(GetExpiredTimer())
                if R and R.hand == hand then
                    UI.safe(Cards.pick, 1)
                end
            end)
        end
    end

    function Cards.hide()
        if Cards.root then
            BlzFrameSetVisible(Cards.root, false)
        end
    end

    function Cards.fill(card, c)
        local rarity = RARITY[c.rarity]
        card.rarityIndex = c.rarity
        local r, g, b = rarity.rgb[1], rarity.rgb[2], rarity.rgb[3]
        UI.tint(card.iconFrame, r, g, b, 255)
        BlzFrameSetText(card.rarityText, U.col(rarity.hex, (rarity.name:upper():gsub('(.)', '\0371 '))))
        local icon, name, sub, desc, foot
        if c.type == 'spell' then
            local def = SPELLS[c.key]
            local inst = R.spellByKey[c.key]
            local rank = inst and inst.rank + 1 or 1
            local power = (inst and inst.power or 1) + rarity.bonus
            local v = G.spellValues(def, rank, power, R.stats)
            icon = U.spellIcon(def)
            name = def.name
            if inst then
                sub = 'Rank ' .. inst.rank .. '  >  ' .. rank
                foot = 'Rank ' .. rank .. rankLimit(def.maxRank)
            else
                sub = def.kind == 'passive' and 'New passive' or 'New spell'
                foot = 'Takes a spell slot  -  ' .. (#R.spells + 1) .. '/' .. CFG.SPELL_SLOTS
            end
            if v.mana > 0 then
                sub = sub .. '  -  ' .. U.col('8fb4ff', v.mana .. ' mana')
            end
            desc = G.describe(def, v)
        elseif c.type == 'blessing' then
            local def = BLESSING_BY_KEY[c.key]
            local current = R.blessings[c.key]
            local amount = G.blessingGain(def, current, rarity.bonus)
            icon = U.icon(def.code, def.icon)
            name = def.name
            sub = 'Blessing'
            desc = G.describeBlessing(def, amount)
            local effects = G.attributeEffects(c.key, amount)
            if effects then
                desc = desc .. '\n' .. U.col('bfb6a8', effects)
            end
            if current then
                desc = desc .. '\n' .. U.col(GREY, 'Total: ') .. G.describeBlessing(def, current.value + amount)
            end
            foot = 'No spell slot  -  rank ' .. (current and current.rank + 1 or 1)
        elseif c.type == 'gold' then
            icon, name, sub = U.icon('pghe', 'BTNChestOfGold'), 'Purse of Gold', 'Nothing left to learn'
            desc, foot = 'Take ' .. U.col('ffffff', '25') .. ' gold.', ''
        else
            icon, name, sub = U.icon('AHhb', 'BTNHolyBolt'), 'Second Wind', 'Nothing left to learn'
            desc, foot = 'Restore ' .. U.col('ffffff', '40\037') .. ' of your health.', ''
        end
        BlzFrameSetTexture(card.icon, icon, 0, true)
        BlzFrameSetText(card.name, U.col(rarity.hex, name))
        BlzFrameSetText(card.sub, U.col(GREY, sub))
        BlzFrameSetText(card.desc, U.col('d8cfc0', desc))
        BlzFrameSetText(card.foot, U.col(GREY, foot))
        Cards.paintCard(card)
    end

    function Cards.render()
        local hand = R.hand
        local n = #hand.cards
        if hand.kind == 'chest' then
            BlzFrameSetText(Cards.pillText, U.col('140f0a', 'T R E A S U R E'))
            BlzFrameSetText(Cards.title, U.col(GOLD, 'Cache Opened!'))
            BlzFrameSetText(Cards.subtitle, U.col(GREY, 'A cache of power. Every card in it is rare or better.'))
        else
            BlzFrameSetText(Cards.pillText, U.col('140f0a', 'L E V E L  ' .. R.level))
            BlzFrameSetText(Cards.title, U.col(GOLD, 'Level Up!'))
            BlzFrameSetText(Cards.subtitle, U.col(GREY, 'Choose a card (' .. Keys.label('card1') .. ' to '
                .. Keys.label('card4') .. ' or a click). Its rarity decides how strong it is.'))
        end
        local total = n * CARD_W + (n - 1) * CARD_GAP
        local x0 = 0.4 - total / 2
        for i, card in ipairs(Cards.cards) do
            local c = hand.cards[i]
            if c then
                Cards.moveCard(card, x0 + (i - 1) * (CARD_W + CARD_GAP), 0.415)
                Cards.fill(card, c)
                BlzFrameSetText(card.badge, Keys.label('card' .. i))
                Cards.showCard(card, true)
                local canBanish = R.banishes > 0 and (c.type == 'spell' or c.type == 'blessing')
                UI.showButton(card.banish, R.banishes > 0)
                UI.setLabel(card.banish, 'Banish  (' .. R.banishes .. ')')
                UI.setEnabled(card.banish, canBanish)
            else
                Cards.showCard(card, false)
            end
        end
        for i, slot in ipairs(Cards.slots) do
            local inst = R.slots[i]
            if inst then
                UI.setIcon(slot, U.spellIcon(inst.def))
            else
                BlzFrameSetTexture(slot.img, TEX.white, 0, true)
                UI.tint(slot.img, 18, 14, 10, 230)
            end
        end
        local canSkip = Profile.perk('skip') > 0
        UI.showButton(Cards.skip, canSkip)
        UI.setLabel(Cards.skip, 'Skip  ' .. U.col(GOLD, '+' .. (10 + R.level) .. ' gold'))
        UI.setLabel(Cards.reroll, 'Reroll  ' .. R.rerolls .. U.col(GREY, '  [' .. Keys.label('reroll') .. ']'))
        UI.setEnabled(Cards.reroll, R.rerolls > 0)
    end

    function G.applyCard(c)
        local bonus = RARITY[c.rarity].bonus
        if c.type == 'spell' then
            local inst = R.spellByKey[c.key]
            if inst then
                inst.rank = inst.rank + 1
                inst.power = inst.power + bonus * CFG.RANK_RARITY
            else
                G.learnSpell(c.key, 1 + bonus)
            end
        elseif c.type == 'blessing' then
            local b = R.blessings[c.key]
            if b == nil then
                b = {rank = 0, value = 0}
                R.blessings[c.key] = b
                R.blessingOrder[#R.blessingOrder + 1] = c.key
            end
            local gain = G.blessingGain(BLESSING_BY_KEY[c.key], b, bonus)
            b.rank = b.rank + 1
            b.value = b.value + gain
        elseif c.type == 'gold' then
            G.addGold(25)
        elseif c.type == 'heal' then
            G.heal(BlzGetUnitMaxHP(R.hero) * 0.4)
        end
        G.recomputeStats()
    end

    function Cards.closeHand()
        R.hand = nil
        BlzFrameSetVisible(Cards.root, false)
        Hud.refreshSpells()
        Hud.update()
        if R.pendingLevels > 0 or R.pendingChests > 0 then
            G.tryOpenHand()
        else
            G.setPaused(false)
        end
    end

    function Cards.pick(index)
        if R == nil or R.hand == nil or R.ended then
            return
        end
        local c = R.hand.cards[index]
        if c == nil then
            return
        end
        G.applyCard(c)
        Cards.closeHand()
    end

    function Cards.rerollHand()
        if R == nil or R.hand == nil or R.rerolls <= 0 then
            return
        end
        R.rerolls = R.rerolls - 1
        R.hand.cards = Cards.draw(R.hand.size, nil, R.hand.minimum)
        Cards.render()
    end

    function Cards.banish(index)
        if R == nil or R.hand == nil or R.banishes <= 0 then
            return
        end
        local c = R.hand.cards[index]
        if c == nil or (c.type ~= 'spell' and c.type ~= 'blessing') then
            return
        end
        R.banishes = R.banishes - 1
        R.banished[c.key] = true
        local exclude = {}
        for _, other in ipairs(R.hand.cards) do
            exclude[other.key] = true
        end
        local replacement = Cards.draw(1, exclude, R.hand.minimum)[1]
        if replacement and (replacement.type == 'spell' or replacement.type == 'blessing') then
            R.hand.cards[index] = replacement
        elseif #R.hand.cards > 1 then
            table.remove(R.hand.cards, index)
        else
            R.hand.cards[index] = replacement
        end
        Cards.render()
    end

    function Cards.skipHand()
        if R == nil or R.hand == nil or Profile.perk('skip') <= 0 then
            return
        end
        G.addGold(10 + R.level)
        Cards.closeHand()
    end

    ---------------------------------------------------------------------------
    -- End of run
    ---------------------------------------------------------------------------
    function Finale.build()
        local root = UI.group(UI.game)
        Finale.root = root
        UI.box(root, -0.3, 0.6, 1.4, 0.6, 0, 0, 0, 190)
        UI.panel(root, 0.14, 0.555, 0.52, 0.47, 245)
        Finale.title = UI.text(root, '', 0.17, 0.528, 0.46, 0.045, 0.03, TEXT_JUSTIFY_CENTER)
        UI.ornament(root, 0.4, 0.478, 0.22)
        Finale.subtitle = UI.text(root, '', 0.17, 0.468, 0.46, 0.016, 0.0095, TEXT_JUSTIFY_CENTER)
        UI.rule(root, 'RUN', 0.176, 0.44, 0.212, 0.011)
        Finale.statsLeft = UI.text(root, '', 0.186, 0.414, 0.11, 0.14, 0.009, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        Finale.statsRight = UI.text(root, '', 0.27, 0.414, 0.108, 0.14, 0.009, TEXT_JUSTIFY_RIGHT, TEXT_JUSTIFY_TOP)
        UI.rule(root, 'REWARDS', 0.412, 0.44, 0.212, 0.011)
        Finale.rewards = UI.text(root, '', 0.422, 0.414, 0.196, 0.05, 0.009, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        Finale.lootIcons = {}
        for i = 1, 5 do
            local o = UI.icon(root, TEX.white, 0.426 + (i - 1) * 0.036, 0.356, 0.028)
            o.ilvl = UI.text(root, '', 0.422 + (i - 1) * 0.036, 0.325, 0.036, 0.011, 0.0068, TEXT_JUSTIFY_CENTER)
            Finale.lootIcons[i] = o
        end
        Finale.achievements = UI.text(root, '', 0.422, 0.31, 0.196, 0.07, 0.0085, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        UI.rule(root, 'DAMAGE', 0.176, 0.27, 0.448, 0.011)
        Finale.meter = UI.text(root, '', 0.196, 0.246, 0.408, 0.074, 0.0085, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        Finale.camp = UI.button(root, 0.205, 0.163, 0.18, 0.038, U.col(GOLD, 'Return to Camp'), function()
            if Engine.active() then
                Engine.returnToMenu()
                return
            end
            G.cleanup()
            Lobby.show()
        end, 'red', 0.012)
        Finale.again = UI.button(root, 0.415, 0.163, 0.18, 0.038, 'Play Again', function()
            G.cleanup()
            G.startRun()
        end, 'dark', 0.012)
        -- After a victory, a third button keeps the run going (endless mode).
        Finale.endless = UI.button(root, 0.485, 0.163, 0.14, 0.038, U.col(RED, 'Endless Mode'), function()
            G.continueEndless()
        end, 'red', 0.012)
        BlzFrameSetVisible(root, false)
    end

    -- Two buttons side by side, or three when endless mode is offered.
    function Finale.layoutButtons(offerEndless)
        if offerEndless then
            UI.moveButton(Finale.camp, 0.175, 0.163, 0.14, 0.038)
            UI.moveButton(Finale.again, 0.33, 0.163, 0.14, 0.038)
        else
            UI.moveButton(Finale.camp, 0.205, 0.163, 0.18, 0.038)
            UI.moveButton(Finale.again, 0.415, 0.163, 0.18, 0.038)
        end
        UI.showButton(Finale.endless, offerEndless)
    end

    function Finale.show()
        local run = R
        Finale.layoutButtons(run.victory and not run.endless)
        if run.endless then
            BlzFrameSetText(Finale.title, U.col(RED, 'ENDLESS') .. U.col(GREY, '  -  ') .. U.col(GOLD, U.time(run.time)))
        elseif run.victory then
            BlzFrameSetText(Finale.title, U.col('5cff7a', 'VICTORY'))
        else
            BlzFrameSetText(Finale.title, U.col(RED, 'DEFEAT'))
        end
        BlzFrameSetText(Finale.subtitle, U.col(GOLD, run.def.name) .. U.col(GREY, '  in  ') .. run.zone.name
            .. U.col(GREY, '  -  ') .. U.col(run.diff.hex, run.diff.name))
        BlzFrameSetText(Finale.statsLeft, U.col(GREY, 'Time\nLevel\nKills\nBosses\nDamage dealt\nDamage taken\nSpells'))
        BlzFrameSetText(Finale.statsRight, U.time(run.time) .. '\n' .. run.level .. '\n' .. U.big(run.kills) .. '\n'
            .. run.bosses .. '\n' .. U.big(run.damageDone) .. '\n' .. U.big(run.damageTaken) .. '\n' .. #run.spells)
        BlzFrameSetText(Finale.rewards, U.col(GOLD, '+' .. U.big(run.goldEarned) .. ' gold') .. U.col(GREY, '  (')
            .. U.big(Profile.data.gold) .. U.col(GREY, ' banked)') .. '\n'
            .. (#run.loot > 0 and 'Loot:' or U.col(GREY, 'No new gear this time.')))
        for i, o in ipairs(Finale.lootIcons) do
            local drop = run.loot[i]
            if drop then
                UI.setIcon(o, gearIcon(drop.item))
                UI.frameColor(o, 214, 170, 90)
                BlzFrameSetText(o.ilvl, U.col(gearHex(drop.ilvl), tostring(drop.ilvl)))
            else
                BlzFrameSetText(o.ilvl, '')
            end
            UI.showIcon(o, drop ~= nil)
        end
        local lines = {}
        if run.endless then
            lines[#lines + 1] = U.col(GREY, 'Endless mode for ') .. U.time(run.time - run.endlessAt)
                .. U.col(GREY, '  -  best here ') .. U.time(Profile.data.endless[tostring(run.zoneIndex)] or 0)
        elseif run.diff.key == 'mplus' then
            if run.victory and (run.keyUpgrade or 0) > 0 then
                lines[#lines + 1] = U.col('ff8000', 'Keystone +' .. run.diff.level .. ' timed!') .. U.col(GREEN, '  +'
                    .. run.keyUpgrade .. '  -  up to +' .. Profile.keyMax(run.zoneIndex) .. ' is open')
            elseif run.victory then
                lines[#lines + 1] = U.col(RED, 'Keystone +' .. run.diff.level .. ' depleted') .. U.col(GREY, '  -  not in time')
            end
        end
        local rank = ZONES[run.zoneIndex].rank
        local zoneLine = nil
        if run.victory and not run.endless and rank < #ZONES and Profile.data.unlocked > rank then
            zoneLine = U.col(GREEN, ZONES[ZONE_ORDER[rank + 1]].name .. ' is open.')
        end
        -- The box ends at the DAMAGE rule: three lines under the loot, five
        -- without loot (it moves up). Achievements get a line each while
        -- they fit, else one line that names the first three.
        local budget = #run.loot > 0 and 3 or 5
        local earned = run.newAchievements or {}
        if #lines + #earned + (zoneLine and 1 or 0) <= budget then
            for _, a in ipairs(earned) do
                lines[#lines + 1] = U.col(GOLD, 'Achievement: ') .. a.name .. U.col(GREY, '  +' .. a.points)
            end
        else
            local names, points = {}, 0
            for i, a in ipairs(earned) do
                points = points + a.points
                if i <= 3 then
                    names[#names + 1] = a.name
                end
            end
            lines[#lines + 1] = U.col(GOLD, #earned .. ' achievements') .. U.col(GREY, '  +' .. points .. ': ')
                .. table.concat(names, ', ') .. (#earned > 3 and U.col(GREY, ' and ' .. (#earned - 3) .. ' more') or '')
        end
        lines[#lines + 1] = zoneLine
        UI.place(Finale.achievements, 0.422, #run.loot > 0 and 0.31 or 0.37, 0.196, #run.loot > 0 and 0.04 or 0.1)
        BlzFrameSetText(Finale.achievements, table.concat(lines, '\n'))
        local rows = {}
        for key, amount in pairs(run.meter) do
            rows[#rows + 1] = {key = key, amount = amount}
        end
        table.sort(rows, function(a, b)
            return a.amount > b.amount
        end)
        local meterLines = {}
        for i = 1, math.min(5, #rows) do
            meterLines[#meterLines + 1] = i .. '.  ' .. sourceName(rows[i].key) .. U.col(GREY, '   ' .. U.big(rows[i].amount))
        end
        BlzFrameSetText(Finale.meter, table.concat(meterLines, '\n'))
        BlzFrameSetVisible(Finale.root, true)
    end

    function Finale.hide()
        if Finale.root then
            BlzFrameSetVisible(Finale.root, false)
        end
    end

    ---------------------------------------------------------------------------
    -- Options (Escape, in the lobby and during a run): a game menu with its
    -- buttons stacked in one column, as in World of Warcraft. Audio, Keybinds
    -- and Interface each open their own page in its place; Back or Escape
    -- returns to the menu. The engine mixes each sound group by its cvar
    -- (s_spellvolume and the rest) under s_volume, the master volume;
    -- Reforged uses volume groups. Sliders follow an audio taper (the gain
    -- is the square of the setting), so 10 is really quiet.
    ---------------------------------------------------------------------------
    local VOLUMES = {
        {key = 'master', label = 'Master volume', cvar = 's_volume', default = 60},
        {key = 'music', label = 'Music', cvar = 's_musicvolume'},
        {key = 'spells', label = 'Spells', cvar = 's_spellvolume', groups = {'SOUND_VOLUMEGROUP_SPELLS'}},
        {key = 'ambience', label = 'Ambience', cvar = 's_ambiencevolume', groups = {'SOUND_VOLUMEGROUP_AMBIENTSOUNDS'}},
        {key = 'units', label = 'Units and enemies', cvar = 's_unitvolume',
            groups = {'SOUND_VOLUMEGROUP_UNITSOUNDS', 'SOUND_VOLUMEGROUP_COMBAT', 'SOUND_VOLUMEGROUP_UNITMOVEMENT'}}
    }
    -- Slider rows and the page each sits on: the volumes, then the interface (HUD) size.
    local OPTION_ROWS = {}
    for _, v in ipairs(VOLUMES) do
        v.min, v.max, v.default, v.page = 0, 100, v.default or 100, 'audio'
        OPTION_ROWS[#OPTION_ROWS + 1] = v
    end
    OPTION_ROWS[#OPTION_ROWS + 1] = {key = 'hud', label = 'Interface size', min = 70, max = 140, default = 100,
        page = 'interface'}
    local OPTION_BY_KEY = {}
    for _, row in ipairs(OPTION_ROWS) do
        OPTION_BY_KEY[row.key] = row
    end
    local OPTION_STEP = 10

    -- Every key the script listens to: {OSKEY name, key code (the OSKEY
    -- value, a Windows virtual-key code), label}. Escape always opens the
    -- menu; any other key can be bound to an action.
    local KEY_ESCAPE = 27
    local KEY_LIST = {{'ESCAPE', KEY_ESCAPE, 'Esc'}, {'SPACE', 32, 'Space'}, {'UP', 38, 'Up'}, {'DOWN', 40, 'Down'},
        {'LEFT', 37, 'Left'}, {'RIGHT', 39, 'Right'}}
    for c in ('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'):gmatch('.') do
        KEY_LIST[#KEY_LIST + 1] = {c, string.byte(c), c}
    end
    for i = 1, 4 do
        KEY_LIST[#KEY_LIST + 1] = {'F' .. i, 111 + i, 'F' .. i}
    end
    local KEY_LABEL = {}
    for _, entry in ipairs(KEY_LIST) do
        KEY_LABEL[entry[2]] = entry[3]
    end
    -- A binding is a key code plus META_STEP times the modifiers held with it
    -- (Reforged meta keys: 1 Shift, 2 Ctrl), so Shift+1 and Ctrl+1 are keys of
    -- their own. Every key is registered with each of these modifiers.
    local META_SHIFT, META_CTRL, META_STEP = 1, 2, 256
    local META_KEYS = {0, META_SHIFT, META_CTRL}
    local META_LABEL = {[0] = '', [META_SHIFT] = 'Shift+', [META_CTRL] = 'Ctrl+'}

    -- Rebindable actions, in the order the Keybinds page lists them. The
    -- movement keys only walk with keyboard movement on.
    local ACTIONS = {
        {key = 'up', label = 'Move up', default = 87, dx = 0, dy = 1},
        {key = 'left', label = 'Move left', default = 65, dx = -1, dy = 0},
        {key = 'down', label = 'Move down', default = 83, dx = 0, dy = -1},
        {key = 'right', label = 'Move right', default = 68, dx = 1, dy = 0},
        {key = 'spell1', label = 'Cast spell 1', default = 49},
        {key = 'spell2', label = 'Cast spell 2', default = 50},
        {key = 'spell3', label = 'Cast spell 3', default = 51},
        {key = 'spell4', label = 'Cast spell 4', default = 52},
        {key = 'auto1', label = 'Spell 1 autocast on or off', default = META_STEP * META_SHIFT + 49},
        {key = 'auto2', label = 'Spell 2 autocast on or off', default = META_STEP * META_SHIFT + 50},
        {key = 'auto3', label = 'Spell 3 autocast on or off', default = META_STEP * META_SHIFT + 51},
        {key = 'auto4', label = 'Spell 4 autocast on or off', default = META_STEP * META_SHIFT + 52},
        {key = 'card1', label = 'Pick card 1', default = META_STEP * META_CTRL + 49},
        {key = 'card2', label = 'Pick card 2', default = META_STEP * META_CTRL + 50},
        {key = 'card3', label = 'Pick card 3', default = META_STEP * META_CTRL + 51},
        {key = 'card4', label = 'Pick card 4', default = META_STEP * META_CTRL + 52},
        {key = 'reroll', label = 'Reroll the cards', default = 82},
        {key = 'stats', label = 'Show or hide the stats', default = 67},
        {key = 'play', label = 'Enter the zone (lobby)', default = 32}
    }
    local ACTION_BY_KEY = {}
    for _, a in ipairs(ACTIONS) do
        ACTION_BY_KEY[a.key] = a
    end

    -- Movement is either the mouse (right-click a point) or the keyboard
    -- (hold the movement keys), never both.
    function Keys.wasd()
        -- A touch screen has no movement keys: fingers always steer.
        return Profile.data ~= nil and Profile.data.opts.wasd == 1 and not Engine.touch()
    end

    function Keys.code(action)
        return Profile.data.binds[action] or ACTION_BY_KEY[action].default
    end

    -- 'Shift+1' for a binding with its modifiers.
    function Keys.comboLabel(code)
        local meta = code // META_STEP
        return (META_LABEL[meta] or '') .. (KEY_LABEL[code - meta * META_STEP] or '?')
    end

    function Keys.label(action)
        return Keys.comboLabel(Keys.code(action))
    end

    -- The four movement keys, as 'W A S D'.
    function Keys.moveLabel()
        return Keys.label('up') .. ' ' .. Keys.label('left') .. ' ' .. Keys.label('down') .. ' ' .. Keys.label('right')
    end

    -- Key code -> action, rebuilt whenever a binding changes.
    function Keys.rebuild()
        Keys.actionOf = {}
        for _, a in ipairs(ACTIONS) do
            Keys.actionOf[Keys.code(a.key)] = a.key
        end
        S.keys = {}
    end

    -- Only keys that differ from the default are saved.
    local function storeBind(action, code)
        if code == ACTION_BY_KEY[action].default then
            Profile.data.binds[action] = nil
        else
            Profile.data.binds[action] = code
        end
    end

    -- Binds an action to a key; the action that had the key takes the old one.
    function Keys.bind(action, code)
        local other = Keys.actionOf[code]
        if other and other ~= action then
            storeBind(other, Keys.code(action))
        end
        storeBind(action, code)
        Keys.rebuild()
    end

    function Keys.reset()
        Profile.data.binds = {}
        Keys.rebuild()
    end

    -- Walking direction of the held movement keys (opposite keys cancel).
    function Keys.direction()
        local dx, dy = 0, 0
        for _, a in ipairs(ACTIONS) do
            if a.dx and S.keys[a.key] then
                dx, dy = dx + a.dx, dy + a.dy
            end
        end
        return dx, dy
    end

    -- A saved option in percent (Profile.data.opts), or its default.
    function Options.value(key)
        local row = OPTION_BY_KEY[key]
        local value = Profile.data and Profile.data.opts[key]
        return value and U.clamp(value, row.min, row.max) or row.default
    end

    -- A volume setting as a gain, on the audio taper.
    function Options.gain(key)
        local level = Options.value(key) / 100
        return level * level
    end

    -- Pushes every saved volume to the sound system.
    function Options.apply()
        local master = Options.gain('master')
        for _, v in ipairs(VOLUMES) do
            local level = Options.gain(v.key)
            if v.key == 'master' then
                -- The engine scales every sound effect by s_volume; Reforged
                -- has no master control, so each group takes it below.
                if Engine.active() then
                    EngineCvar(v.cvar, string.format('\037.4f', level))
                end
            elseif Engine.active() then
                -- Music plays outside s_volume: the master applies here.
                if v.groups == nil then
                    level = level * master
                end
                EngineCvar(v.cvar, string.format('\037.4f', level))
            elseif v.groups == nil then
                SetMusicVolume(math.floor(127 * level * master + 0.5))
            else
                level = level * master
                for _, name in ipairs(v.groups) do
                    local group = rawget(_G, name)
                    if group then
                        VolumeGroupSetVolume(group, level)
                    end
                end
            end
        end
    end

    -- The game menu column: left edge, top, width; buttons and their step.
    local MENU = {x = 0.3, top = 0.47, w = 0.2, bh = 0.03, step = 0.037}

    -- One page of the options window: a group with its own card, shown alone.
    local function optionsPage(root, key, x, top, w, h, title)
        local group = UI.group(root)
        local frame, fill = UI.card(group, x, top, w, h, title)
        Options.pages[key] = {group = group, frame = frame, fill = fill, x = x, top = top, w = w}
        return group
    end

    function Options.build()
        local root = UI.group(UI.game)
        Options.root = root
        Options.pages = {}
        Options.rows = {}
        Options.page = 'main'
        UI.box(root, -0.3, 0.6, 1.4, 0.6, 0, 0, 0, 170)
        -- Swallows clicks meant for the screen behind. Level 0: siblings stack
        -- by level, and at UI.hit's level 8 it lay over the pages and took
        -- every click on their buttons.
        BlzFrameSetLevel(UI.hit(root, -0.3, 0.6, 1.4, 0.6), 0)

        -- Game menu: one column of buttons; Options.render stacks the shown ones.
        local main = optionsPage(root, 'main', MENU.x, MENU.top, MENU.w, 0.3, 'GAME MENU')
        local bx, bw = MENU.x + 0.024, MENU.w - 0.048
        local function menuButton(label, onClick, style)
            return UI.button(main, bx, MENU.top, bw, MENU.bh, label, onClick, style or 'dark', 0.0105)
        end
        Options.resume = menuButton('Resume', function()
            Options.hide()
        end)
        Options.audio = menuButton('Audio', function()
            Options.setPage('audio')
        end)
        Options.keybinds = menuButton('Keybinds', function()
            Options.setPage('keys')
        end)
        Options.interface = menuButton('Interface', function()
            Options.setPage('interface')
        end)
        -- Leaving endless mode keeps what it earned (the victory is banked already).
        local function bankEndless()
            if R and R.endless and not R.ended then
                G.endRun(false, true)
            end
        end
        Options.restart = menuButton('Restart Run', function()
            Options.hide()
            bankEndless()
            G.cleanup()
            G.startRun()
        end)
        Options.menu = menuButton('Main Menu', function()
            Options.hide()
            bankEndless()
            if Engine.active() then
                Engine.returnToMenu()
                return
            end
            G.cleanup()
            Lobby.show()
        end)
        Options.quit = menuButton(U.col(GOLD, 'Quit Game'), function()
            Options.quitGame()
        end, 'red')
        -- A wider gap sets the run and quit buttons apart from the settings.
        Options.menuButtons = {Options.resume, Options.audio, Options.keybinds, Options.interface, 'gap',
            Options.restart, Options.menu, Options.quit}
        Options.hint = UI.text(main, U.col(GREY, 'Esc closes this menu'), bx, MENU.top, bw, 0.012, 0.0072,
            TEXT_JUSTIFY_CENTER)

        Options.buildSliders(root, 'audio', 'AUDIO')
        Options.buildSliders(root, 'interface', 'INTERFACE')
        Options.buildKeys(root)
        Options.setPage('main')
        BlzFrameSetVisible(root, false)
    end

    -- A page of slider rows (the rows whose page is key) and a Back button.
    function Options.buildSliders(root, key, title)
        local list = {}
        for _, v in ipairs(OPTION_ROWS) do
            if v.page == key then
                list[#list + 1] = v
            end
        end
        local x, top, w = 0.24, MENU.top, 0.32
        -- Rows, the Back button, then the hint line clear of the frame's edge.
        local h = 0.048 + #list * 0.032 + 0.094
        local page = optionsPage(root, key, x, top, w, h, title)
        local ix, iw = x + 0.024, w - 0.048
        for i, v in ipairs(list) do
            local rowKey = v.key
            local rowTop = top - 0.048 - (i - 1) * 0.032
            local row = {}
            UI.text(page, U.col('d8cfc0', v.label), ix, rowTop, 0.1, 0.024, 0.0088)
            row.down = UI.button(page, ix + 0.102, rowTop - 0.001, 0.022, 0.022, '-', function()
                Options.step(rowKey, -OPTION_STEP)
            end, 'dark', 0.013)
            row.bar = UI.bar(page, ix + 0.132, rowTop - 0.006, 0.078, 0.012, 214, 170, 90, 0.0072)
            row.up = UI.button(page, ix + 0.218, rowTop - 0.001, 0.022, 0.022, '+', function()
                Options.step(rowKey, OPTION_STEP)
            end, 'dark', 0.013)
            row.value = UI.text(page, '', ix + 0.242, rowTop, iw - 0.242, 0.024, 0.0085, TEXT_JUSTIFY_RIGHT)
            Options.rows[rowKey] = row
        end
        local by = top - 0.048 - #list * 0.032 - 0.016
        UI.button(page, ix + iw / 4, by, iw / 2, 0.03, 'Back', function()
            Options.setPage('main')
        end, 'dark', 0.0105)
        UI.text(page, U.col(GREY, 'Esc returns to the menu'), ix, by - 0.038, iw, 0.012, 0.0072, TEXT_JUSTIFY_CENTER)
    end

    -- Keybinds: mouse or keyboard movement, then one row per action with
    -- its key. Clicking a key waits for the next key pressed (G.onKey).
    function Options.buildKeys(root)
        local x, top, w = 0.21, 0.55, 0.38
        -- Rows shrink to keep every action on the screen.
        local rowH = math.min(0.025, 0.33 / (#ACTIONS + 1))
        local h = 0.106 + (#ACTIONS + 1) * rowH + 0.09
        local page = optionsPage(root, 'keys', x, top, w, h, 'KEYBINDS')
        local ix, iw = x + 0.024, w - 0.048
        local t = top - 0.048
        UI.text(page, U.col('d8cfc0', 'Movement'), ix, t, 0.09, 0.026, 0.0088)
        local mw = (iw - 0.098) / 2
        Options.mouseMode = UI.button(page, ix + 0.09, t, mw, 0.026, 'Mouse', function()
            Options.setMovement(false)
        end, 'tab', 0.0092)
        Options.keyMode = UI.button(page, ix + 0.098 + mw, t, mw, 0.026, 'Keyboard', function()
            Options.setMovement(true)
        end, 'tab', 0.0092)
        t = t - 0.03
        Options.modeHint = UI.text(page, '', ix, t, iw, 0.018, 0.0072, TEXT_JUSTIFY_CENTER)
        t = t - 0.028
        Options.binds = {}
        local kw = 0.1
        for _, a in ipairs(ACTIONS) do
            local action = a.key
            local row = {}
            row.label = UI.text(page, '', ix, t, iw - kw, rowH - 0.003, 0.0085)
            row.key = UI.button(page, ix + iw - kw, t, kw, rowH - 0.003, '', function()
                Options.waiting = action
                Options.renderKeys()
            end, 'dark', 0.009)
            Options.binds[action] = row
            t = t - rowH
        end
        UI.text(page, U.col('6e665c', 'Options menu'), ix, t, iw - kw, rowH - 0.003, 0.0085)
        UI.setEnabled(UI.button(page, ix + iw - kw, t, kw, rowH - 0.003, 'Esc', nil, 'dark', 0.009), false)
        t = t - rowH - 0.014
        local bw = (iw - 0.012) / 2
        UI.button(page, ix, t, bw, 0.03, 'Reset to Defaults', function()
            Options.waiting = nil
            Keys.reset()
            Options.changedKeys()
        end, 'dark', 0.0098)
        UI.button(page, ix + bw + 0.012, t, bw, 0.03, 'Back', function()
            Options.setPage('main')
        end, 'dark', 0.0105)
        Options.keysHint = UI.text(page, '', ix, t - 0.036, iw, 0.012, 0.0072, TEXT_JUSTIFY_CENTER)
    end

    function Options.setPage(key)
        Options.page = key
        Options.waiting = nil
        for name, p in pairs(Options.pages) do
            BlzFrameSetVisible(p.group, name == key)
        end
        Options.render()
    end

    function Options.setMovement(wasd)
        Profile.data.opts.wasd = wasd and 1 or 0
        if R then
            R.clickX, R.clickY = nil, nil
        end
        Options.changedKeys()
    end

    -- The key pressed while a binding waits for one (Escape cancels).
    function Options.capture(code)
        local action = Options.waiting
        Options.waiting = nil
        if action and code ~= KEY_ESCAPE then
            Keys.bind(action, code)
        end
        Options.changedKeys()
    end

    function Options.changedKeys()
        Options.renderKeys()
        Lobby.updateFooter()
    end

    function Options.step(key, delta)
        local row = OPTION_BY_KEY[key]
        Profile.data.opts[key] = U.clamp(Options.value(key) + delta, row.min, row.max)
        if key == 'hud' then
            Hud.rebuild()
        else
            Options.apply()
        end
        Options.render()
    end

    function Options.renderKeys()
        local wasd = Keys.wasd()
        UI.setActive(Options.mouseMode, not wasd)
        UI.setActive(Options.keyMode, wasd)
        BlzFrameSetText(Options.modeHint, U.col(GREY, wasd
            and ('Hold ' .. Keys.moveLabel() .. ' to walk. Right-clicks do not move the hero.')
            or (Engine.active() and 'Right-click the ground to walk there, or hold it: the hero follows the cursor.'
                or 'Right-click the ground to walk there. The movement keys do nothing.')))
        for _, a in ipairs(ACTIONS) do
            local row = Options.binds[a.key]
            local waiting = Options.waiting == a.key
            BlzFrameSetText(row.label, U.col((a.dx and not wasd) and '6e665c' or 'd8cfc0', a.label))
            UI.setLabel(row.key, waiting and U.col('ffffff', 'Press a key') or Keys.label(a.key))
            UI.setActive(row.key, waiting)
        end
        BlzFrameSetText(Options.keysHint, U.col(GREY, Options.waiting and 'Press the new key. Esc cancels.'
            or 'Click a key to change it. Esc returns to the menu.'))
    end

    function Options.render()
        for _, v in ipairs(OPTION_ROWS) do
            local row = Options.rows[v.key]
            local value = Options.value(v.key)
            UI.setBar(row.bar, (value - v.min) / (v.max - v.min))
            BlzFrameSetText(row.value, value == 0 and U.col(GREY, 'Off') or (value .. '\037'))
            UI.setEnabled(row.down, value > v.min)
            UI.setEnabled(row.up, value < v.max)
        end
        -- In the lobby there is no run to restart or leave: Close, the
        -- settings and Quit. The window shrinks to the shown buttons.
        local inRun = R ~= nil and not R.ended
        UI.setLabel(Options.resume, inRun and 'Resume' or 'Close')
        UI.showButton(Options.restart, inRun)
        UI.showButton(Options.menu, inRun)
        -- A browser page cannot close itself (the engine froze): no Quit there.
        UI.showButton(Options.quit, not Engine.web())
        local p = Options.pages.main
        local bx, bw = p.x + 0.024, p.w - 0.048
        local top = p.top - 0.05
        local gap = false
        for _, b in ipairs(Options.menuButtons) do
            if b == 'gap' then
                gap = true
            elseif b.visible then
                if gap then
                    top = top - 0.01
                    gap = false
                end
                UI.moveButton(b, bx, top, bw, MENU.bh)
                top = top - MENU.step
            end
        end
        UI.place(Options.hint, bx, top - 0.004, bw, 0.012)
        UI.sizeCard(p.frame, p.fill, p.x, p.top, p.w, p.top - top + 0.04)
        Options.renderKeys()
    end

    function Options.show()
        Options.open = true
        if R and not R.ended then
            G.setPaused(true)
        end
        Options.setPage('main')
        BlzFrameSetVisible(Options.root, true)
    end

    function Options.hide()
        Options.open = false
        Options.waiting = nil
        BlzFrameSetVisible(Options.root, false)
        Profile.save()
        -- A level-up hand keeps the run paused until a card is picked.
        if R and not R.ended and not R.hand then
            G.setPaused(false)
        end
    end

    -- Escape: a settings page returns to the game menu, the game menu closes.
    function Options.toggle()
        if not Options.open then
            Options.show()
        elseif Options.page ~= 'main' then
            Options.setPage('main')
        else
            Options.hide()
        end
    end

    function Options.quitGame()
        Profile.save()
        local quit = rawget(_G, 'EngineQuit')
        if type(quit) == 'function' then
            quit()
        else
            EndGame(false)
        end
    end

    ---------------------------------------------------------------------------
    -- Lobby
    ---------------------------------------------------------------------------
    local TABS = {
        {key = 'character', label = 'Character'},
        {key = 'collection', label = 'Armory'},
        {key = 'codex', label = 'Codex'},
        {key = 'talents', label = 'Talents'},
        {key = 'achievements', label = 'Achievements'},
        {key = 'rewards', label = 'Rewards'}
    }

    local TIER_HEX = {'e6e6e6', '1eff00', '0070dd', 'a335ee', 'ff8000', 'e6cc80'}
    local TIER_NAME = {'Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic'}

    -- Lobby layout. The engine draws the whole widescreen window, so the menu
    -- spans 0.96 of frame width there (it fits 16:10 and 16:9); Reforged keeps
    -- the 4:3 area from 0 to 0.8. Every page sits between LAY.top and LAY.bottom.
    local LAY = {}

    function LAY.init()
        local wide = Engine.active()
        LAY.wide = wide
        LAY.x0 = wide and -0.08 or 0.0
        LAY.x1 = wide and 0.88 or 0.8
        LAY.w = LAY.x1 - LAY.x0
        LAY.top = 0.53
        LAY.bottom = 0.104
        LAY.h = LAY.top - LAY.bottom
        LAY.gap = 0.012
        LAY.pad = 0.022
        -- Character page: two side columns and the hero in the middle.
        LAY.side = wide and 0.29 or 0.24
        LAY.mid = LAY.w - 2 * LAY.side - 2 * LAY.gap
        LAY.center = LAY.x0 + LAY.side + LAY.gap
        LAY.right = LAY.x1 - LAY.side
        -- Other pages: a main panel and a details panel on the right.
        LAY.mainW = LAY.w - LAY.side - LAY.gap
        -- Achievements and rewards: a narrow summary column on the left.
        LAY.summary = wide and 0.24 or 0.2
    end

    local function heroesOf(factionKey)
        local list = {}
        for index, hero in ipairs(HEROES) do
            if hero.faction == factionKey then
                list[#list + 1] = index
            end
        end
        return list
    end

    -- Plain vertical gradient over the whole window: the world stays hidden
    -- behind the menu. One warm color scaled by a single factor keeps the hue
    -- fixed, so the 8-bit steps between strips do not show as lines.
    function Lobby.buildBackground(root)
        local strips = 40
        local step = 0.6 / strips
        for i = 0, strips - 1 do
            local v = 1 - 0.85 * i / (strips - 1)
            UI.box(root, -0.4, 0.6 - i * step, 1.6, step + 0.0005,
                math.floor(46 * v + 0.5), math.floor(23 * v + 0.5), math.floor(14 * v + 0.5), 255)
        end
    end

    function Lobby.build()
        LAY.init()
        local root = UI.group(UI.game)
        Lobby.root = root
        Lobby.pages = {}
        Lobby.buildBackground(root)
        if Engine.active() then
            -- The title in the Warcraft III logo's style (tools/make_title.py,
            -- 8:1 with room for the glow); Reforged keeps the gold text.
            Lobby.title = UI.image(root, TEX.title, 0.24, 0.601, 0.32, 0.04)
        else
            Lobby.title = UI.text(root, U.col(GOLD, 'WARCRAFT SURVIVORS'), LAY.x0, 0.598, LAY.w, 0.032, 0.024, TEXT_JUSTIFY_CENTER)
        end
        -- Browser only: a download of the Windows build, top right; the
        -- rating moves to its left.
        local download = Engine.web() and SURVIVOR_ENGINE.download
        local goldRight = LAY.x1
        if download and rawget(_G, 'EngineOpenURL') then
            goldRight = LAY.x1 - 0.122
            UI.button(root, goldRight + 0.008, 0.596, 0.114, 0.024, U.col(GOLD, 'Download for Windows'), function()
                EngineOpenURL(download)
            end, 'dark', 0.0088)
        end
        Lobby.gold = UI.text(root, '', goldRight - 0.3, 0.594, 0.3, 0.014, 0.0085, TEXT_JUSTIFY_RIGHT)
        UI.button(root, LAY.x0, 0.596, 0.1, 0.024, 'Options  ' .. U.col(GREY, '[Esc]'), function()
            Options.show()
        end, 'dark', 0.0088)
        -- Portable build: an update the player put off stays one click away.
        if Updater.enabled() then
            Lobby.updateButton = UI.button(root, LAY.x0 + 0.108, 0.596, 0.11, 0.024, U.col(GREEN, 'Update available'), function()
                Updater.show()
            end, 'green', 0.0088)
            UI.showButton(Lobby.updateButton, false)
        end
        Lobby.tabs = {}
        local tabW, tabGap = 0.104, 0.008
        local x0 = 0.4 - (#TABS * tabW + (#TABS - 1) * tabGap) / 2
        for i, tab in ipairs(TABS) do
            local key = tab.key
            Lobby.tabs[key] = UI.button(root, x0 + (i - 1) * (tabW + tabGap), 0.563, tabW, 0.027, tab.label, function()
                Lobby.setTab(key)
            end, 'tab', 0.0102)
        end
        for _, tab in ipairs(TABS) do
            Lobby.pages[tab.key] = UI.group(root)
        end
        Lobby.buildCharacter(Lobby.pages.character)
        Lobby.buildCollection(Lobby.pages.collection)
        Lobby.buildCodex(Lobby.pages.codex)
        Lobby.buildTalents(Lobby.pages.talents)
        Lobby.buildAchievements(Lobby.pages.achievements)
        Lobby.buildRewards(Lobby.pages.rewards)
        Lobby.buildDifficulty(root)
        Lobby.footer = UI.text(root, '', LAY.x0, 0.029, LAY.w, 0.012, 0.0076, TEXT_JUSTIFY_CENTER)
        Lobby.updateFooter()
        if Engine.active() and SURVIVOR_ENGINE.version then
            UI.text(root, U.col(GREY, 'v' .. SURVIVOR_ENGINE.version), LAY.x1 - 0.1, 0.016, 0.1, 0.012, 0.0072, TEXT_JUSTIFY_RIGHT)
        end
        BlzFrameSetVisible(root, false)
    end

    -- Controls line under the lobby, with the player's own keys.
    function Lobby.updateFooter()
        if Lobby.footer == nil then
            return
        end
        if Engine.touch() then
            BlzFrameSetText(Lobby.footer, U.col(GREY, 'Touch and hold the ground: your hero follows your finger'
                .. '  -  attacks and spells cast themselves  -  tap a card to pick it'))
            return
        end
        local move = Keys.wasd() and (Keys.moveLabel() .. ' to move')
            or (Engine.active() and 'Right-click or hold right-click to move' or 'Right-click to move')
        BlzFrameSetText(Lobby.footer, U.col(GREY, move .. '  -  '
            .. Keys.label('spell1') .. ' to ' .. Keys.label('spell4') .. ' or a click casts a spell  -  '
            .. Keys.label('auto1') .. ' to ' .. Keys.label('auto4') .. ' autocast  -  '
            .. Keys.label('card1') .. ' to ' .. Keys.label('card4') .. ' picks a card  -  '
            .. Keys.label('reroll') .. ' rerolls  -  ' .. Keys.label('play') .. ' to play  -  Esc for options'))
    end

    function Lobby.setTab(key)
        S.tab = key
        for _, tab in ipairs(TABS) do
            BlzFrameSetVisible(Lobby.pages[tab.key], tab.key == key)
            UI.setActive(Lobby.tabs[tab.key], tab.key == key)
        end
        Lobby.refresh()
    end

    function Lobby.show()
        S.screen = 'lobby'
        G.playMusic({'War3XMainScreen'})
        Hud.showWorldFrames(false)
        BlzFrameSetVisible(Lobby.root, true)
        Lobby.updatePreview()
        Lobby.setTab(S.tab)
    end

    function Lobby.hide()
        S.screen = 'run'
        BlzFrameSetVisible(Lobby.root, false)
    end

    -- Player color of the portrait model's team-colored parts, per faction.
    local FACTION_TEAM = {Alliance = 1, Horde = 0, Undead = 3, ['Night Elf'] = 2, Tavern = 4}

    -- The hero's portrait: its own model in a frame (engine), or its icon
    -- (Reforged, where model frames cannot be framed without the editor).
    function Lobby.updatePreview()
        local C = Lobby.C
        local hero = HEROES[S.heroIndex]
        if C.model then
            if C.modelHero ~= hero.id then
                C.modelHero = hero.id
                BlzFrameSetModel(C.model, EngineUnitModel(FourCC(hero.id)), 0)
                EngineFrameSetTeamColor(C.model, FACTION_TEAM[hero.faction] or 0)
            end
        elseif C.portrait then
            BlzFrameSetTexture(C.portrait, U.heroIcon(hero), 0, true)
        end
    end

    function Lobby.refresh()
        BlzFrameSetText(Lobby.gold, U.col(GREY, 'Mythic+ rating ') .. U.col('ff8000', tostring(keystoneRating(Profile.data)))
            .. U.col(GREY, '    Gold ') .. U.col(GOLD, U.big(Profile.data.gold)))
        local points = Profile.points()
        UI.setLabel(Lobby.tabs.rewards, points > 0 and ('Rewards ' .. U.col(GREEN, '(' .. points .. ')')) or 'Rewards')
        local page = S.tab
        if page == 'character' then
            Lobby.refreshCharacter()
        elseif page == 'collection' then
            Lobby.refreshCollection()
        elseif page == 'codex' then
            Lobby.refreshCodex()
        elseif page == 'talents' then
            Lobby.refreshTalents()
        elseif page == 'achievements' then
            Lobby.refreshAchievements()
        elseif page == 'rewards' then
            Lobby.refreshRewards()
        end
    end

    -- Dark inset well in the escape menu's thin gold control frame, for
    -- stats, rows and cells. Returned as a list for UI.edgeTint.
    local function well(page, x, top, w, h)
        return {UI.frame(page, TPL.well, x, top, w, h)}
    end

    ---------------------------------------------------------------------------
    -- Character tab
    ---------------------------------------------------------------------------
    function Lobby.buildCharacter(page)
        local C = {}
        Lobby.C = C
        local P, T = LAY.pad, LAY.top

        -- Heroes column: faction crests, the faction's heroes, the chosen
        -- hero's blurb, stats and spell pool.
        local x, w = LAY.x0, LAY.side
        local ix, iw = x + P, w - 2 * P
        UI.card(page, x, T, w, LAY.h, 'HEROES')
        C.factions = {}
        local crest = 0.028
        local crestStep = math.min(0.046, iw / #FACTIONS)
        local crestX = x + w / 2 - (crestStep * (#FACTIONS - 1) + crest) / 2
        for i, faction in ipairs(FACTIONS) do
            local key = faction.key
            local cx = crestX + (i - 1) * crestStep
            local o = {}
            o.ring = UI.box(page, cx - 0.004, T - 0.038, crest + 0.008, crest + 0.008, 255, 255, 255, 0, TEX.highlight)
            o.img = UI.image(page, TEX.emblem[key], cx, T - 0.042, crest, crest)
            o.hit = UI.hit(page, cx, T - 0.042, crest, crest, function()
                S.faction = key
                local list = heroesOf(key)
                if HEROES[S.heroIndex].faction ~= key and list[1] then
                    S.heroIndex = list[1]
                end
                Lobby.updatePreview()
                Lobby.refresh()
            end)
            C.factions[i] = o
        end
        C.factionName = UI.text(page, '', ix, T - 0.074, iw, 0.013, 0.0088, TEXT_JUSTIFY_CENTER)

        C.cells = {}
        local cellW = iw / 3
        local size = 0.036
        for i = 1, 9 do
            local column = math.fmod(i - 1, 3)
            local row = (i - 1) // 3
            local cellX = ix + column * cellW
            local top = T - 0.093 - row * 0.054
            local cell = {}
            cell.glow = UI.box(page, cellX + 0.003, top + 0.004, cellW - 0.006, 0.054, 255, 255, 255, 0, TEX.highlight)
            cell.icon = UI.icon(page, TEX.white, cellX + (cellW - size) / 2, top, size, function()
                if cell.heroIndex then
                    S.heroIndex = cell.heroIndex
                    Lobby.updatePreview()
                    Lobby.refresh()
                end
            end, function()
                cell.hover = true
                Lobby.paintCell(cell)
            end, function()
                cell.hover = false
                Lobby.paintCell(cell)
            end)
            cell.name = UI.text(page, '', cellX, top - size - 0.004, cellW, 0.011, 0.0072, TEXT_JUSTIFY_CENTER)
            C.cells[i] = cell
        end

        UI.box(page, ix, T - 0.26, iw, 0.0008, 150, 112, 58, 200)
        C.heroName = UI.text(page, '', ix, T - 0.264, iw, 0.018, 0.0135)
        C.heroRole = UI.text(page, '', ix, T - 0.264, iw, 0.018, 0.0078, TEXT_JUSTIFY_RIGHT)
        C.blurb = UI.text(page, '', ix, T - 0.284, iw, 0.03, 0.0078, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        C.stats = {}
        -- The starting spell shows in the middle panel, so this row has room
        -- for the attributes.
        local labels = {'HEALTH', 'ATTACK', 'ATTRIBUTES'}
        local shares = {0.27, 0.27, 0.46}
        local sx = ix
        local sgap = 0.006
        for i = 1, 3 do
            local sw = (iw - 2 * sgap) * shares[i]
            well(page, sx, T - 0.32, sw, 0.038)
            UI.text(page, U.col(GREY, labels[i]), sx + 0.009, T - 0.328, sw - 0.018, 0.01, 0.0062)
            C.stats[i] = UI.text(page, '', sx + 0.009, T - 0.339, sw - 0.018, 0.014, 0.009)
            sx = sx + sw + sgap
        end
        UI.text(page, U.col(GREY, 'SPELL POOL  -  click one to start with it'), ix, T - 0.364, iw, 0.011, 0.0066)
        C.pool = {}
        local step = math.min(0.03, iw / 8)
        local poolSize = step - 0.006
        for i = 1, 8 do
            local slot = i
            -- As in Warcraft III, the hero learns the spell of the player's choice first.
            C.pool[i] = UI.icon(page, TEX.white, ix + 0.002 + (i - 1) * step, T - 0.379, poolSize, function()
                local hero = HEROES[S.heroIndex]
                if hero.pool[slot] and SPELLS[hero.pool[slot]] then
                    Profile.data.starts[hero.id] = slot
                    Profile.save()
                    Lobby.refresh()
                    Lobby.showSpellInfo(hero.pool[slot])
                end
            end, function()
                Lobby.showSpellInfo(HEROES[S.heroIndex].pool[slot])
            end, function()
                Lobby.showTraitInfo()
            end)
        end

        -- Middle: the hero's portrait and card, then the faction or the
        -- hovered spell.
        x, w = LAY.center, LAY.mid
        ix, iw = x + P, w - 2 * P
        UI.card(page, x, T, w, LAY.h)
        local pw, ph = LAY.wide and 0.13 or 0.105, LAY.wide and 0.16 or 0.13
        local ptop = T - P
        -- The iron dialog frame is a glue template the Reforged game UI does not load.
        UI.frame(page, Engine.active() and TPL.iron or TPL.well, ix, ptop, pw, ph)
        if Engine.active() then
            C.model = BlzCreateFrameByType('SPRITE', UI.name(), page, '', 0)
            UI.place(C.model, ix + 0.009, ptop - 0.009, pw - 0.018, ph - 0.018)
        else
            local s = pw - 0.024
            C.portrait = UI.image(page, TEX.white, ix + 0.012, ptop - (ph - s) / 2, s, s)
        end
        C.showEmblem = UI.image(page, TEX.emblem.Alliance, ix + pw - 0.038, ptop - ph + 0.04, 0.026, 0.026)
        local tx = ix + pw + 0.014
        local tw = ix + iw - tx
        C.showName = UI.text(page, '', tx, ptop - 0.002, tw, 0.022, 0.0165)
        C.showLine = UI.text(page, '', tx, ptop - 0.026, tw, 0.013, 0.0085)
        C.record = UI.text(page, '', tx, ptop - 0.042, tw, 0.012, 0.0072)
        UI.box(page, tx, ptop - 0.062, tw, 0.0008, 150, 112, 58, 160)
        UI.text(page, U.col(GREY, 'STARTS WITH'), tx, ptop - 0.068, tw, 0.01, 0.0062)
        C.startIcon = UI.icon(page, TEX.white, tx + 0.002, ptop - 0.082, 0.03, nil, function()
            Lobby.showSpellInfo(G.startSpell(HEROES[S.heroIndex]))
        end, function()
            Lobby.showTraitInfo()
        end)
        C.startName = UI.text(page, '', tx + 0.042, ptop - 0.082, tw - 0.042, 0.015, 0.0098)
        C.startKind = UI.text(page, '', tx + 0.042, ptop - 0.098, tw - 0.042, 0.012, 0.0072)

        local itop = ptop - ph - 0.014
        local ih = itop - (LAY.bottom + P)
        well(page, ix, itop, iw, ih)
        C.infoIcon = UI.icon(page, TEX.white, ix + 0.012, itop - 0.012, 0.032)
        C.infoTitle = UI.text(page, '', ix + 0.056, itop - 0.012, iw - 0.068, 0.016, 0.0115)
        C.infoSub = UI.text(page, '', ix + 0.056, itop - 0.029, iw - 0.068, 0.012, 0.0078)
        C.infoBody = UI.text(page, '', ix + 0.012, itop - 0.056, iw - 0.024, ih - 0.066, 0.0082, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)

        -- Zones column: the chosen zone on top, the list below it.
        x, w = LAY.right, LAY.side
        ix, iw = x + P, w - 2 * P
        UI.card(page, x, T, w, LAY.h, 'ZONE')
        -- The zone list: two columns in play order (ZONE_ORDER), top to bottom.
        local rowStep = 0.028
        local rows = math.ceil(#ZONES / 2)
        local colGap = 0.004
        local colW = (iw - colGap) / 2
        local ctop = T - 0.044
        local ch = LAY.h - 0.044 - P - rows * rowStep - 0.006
        well(page, ix, ctop, iw, ch)
        -- Zone picture in its own proportions, left of the name: the arena
        -- shot (2:1) when there is one, else the campaign art's square corner.
        C.zoneArtX, C.zoneArtTop = ix + 0.007, ctop - 0.007
        C.zoneArt = UI.image(page, ZONES[1].art, C.zoneArtX, C.zoneArtTop, 0.094, 0.047)
        C.zoneArtEdge = UI.border(page, C.zoneArtX - 0.002, C.zoneArtTop + 0.002, 0.098, 0.051)
        local tx = ix + 0.108
        C.zoneName = UI.text(page, '', tx, ctop - 0.006, ix + iw - 0.009 - tx, 0.022, 0.016)
        C.zoneTier = UI.text(page, '', tx, ctop - 0.006, ix + iw - 0.009 - tx, 0.022, 0.0068, TEXT_JUSTIFY_RIGHT)
        C.zoneSub = UI.text(page, '', tx, ctop - 0.032, ix + iw - 0.009 - tx, 0.014, 0.0085)
        C.zoneDesc = UI.text(page, '', ix + 0.009, ctop - 0.062, iw - 0.018, 0.044, 0.0074, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        C.zoneBosses = UI.text(page, '', ix + 0.009, ctop - 0.108, iw - 0.018, ch - 0.128, 0.0072, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        C.zoneRecord = UI.text(page, '', ix + 0.009, ctop - ch + 0.017, iw - 0.018, 0.012, 0.0068)
        C.zoneRows = {}
        for rank, zi in ipairs(ZONE_ORDER) do
            local rx = ix + ((rank - 1) // rows) * (colW + colGap)
            local top = ctop - ch - 0.006 - math.fmod(rank - 1, rows) * rowStep
            local row = {zone = zi}
            row.edge = well(page, rx, top, colW, rowStep - 0.004)
            row.glow = UI.box(page, rx + 0.003, top - 0.003, colW - 0.006, rowStep - 0.01, 255, 255, 255, 0, TEX.highlight)
            row.name = UI.text(page, '', rx + 0.007, top, colW - 0.014, rowStep - 0.004, 0.0084)
            row.status = UI.text(page, '', rx + colW * 0.6, top, colW * 0.4 - 0.007, rowStep - 0.004, 0.0062, TEXT_JUSTIFY_RIGHT)
            row.hit = UI.hit(page, rx, top, colW, rowStep - 0.004, function()
                if rank <= Profile.data.unlocked then
                    S.zone = zi
                    Lobby.clampDifficulty()
                    Lobby.refresh()
                end
            end)
            C.zoneRows[rank] = row
        end

        -- Bottom row: difficulty, enter, random hero.
        local by, bh = 0.094, 0.044
        local ew, sw, gap = 0.3, 0.15, LAY.gap
        local ex = 0.4 - ew / 2
        local dx = ex - gap - sw
        -- Opens the difficulty window (Lobby.buildDifficulty).
        C.difficulty = UI.button(page, dx, by, sw, bh, '', function()
            Lobby.openDifficulty()
        end, 'dark', 0.0088)
        C.keyHint = UI.text(page, '', dx - 0.1, by - bh - 0.003, sw + 0.2, 0.011, 0.0066, TEXT_JUSTIFY_CENTER)
        C.enter = UI.button(page, ex, by, ew, bh, '', function()
            Lobby.enter()
        end, 'red', 0.0155)
        UI.place(C.enter.label, ex, by - 0.004, ew, 0.022)
        C.enterSub = UI.text(page, '', ex, by - 0.027, ew, 0.013, 0.0074, TEXT_JUSTIFY_CENTER)
        C.random = UI.button(page, ex + ew + gap, by, sw, bh, 'Random Hero', function()
            local open = {}
            for index, hero in ipairs(HEROES) do
                if Profile.heroOpen(hero) then
                    open[#open + 1] = index
                end
            end
            S.heroIndex = open[GetRandomInt(1, #open)]
            S.faction = HEROES[S.heroIndex].faction
            Lobby.updatePreview()
            Lobby.refresh()
        end, 'dark', 0.0102)
    end

    -- Enter Zone (button or key): only with a hero that has joined.
    function Lobby.enter()
        if Profile.heroOpen(HEROES[S.heroIndex]) then
            G.startRun()
        end
    end

    function Lobby.paintCell(cell)
        local selected = cell.heroIndex == S.heroIndex
        BlzFrameSetAlpha(cell.glow, selected and 170 or (cell.hover and 70 or 0))
        if selected then
            UI.frameColor(cell.icon, 255, 214, 120)
        else
            UI.frameColor(cell.icon, 120, 92, 52)
        end
    end

    -- Keep the chosen difficulty and keystone legal for the selected zone.
    function Lobby.clampDifficulty()
        while S.difficulty > 1 and not Profile.difficultyOpen(S.zone, S.difficulty) do
            S.difficulty = S.difficulty - 1
        end
        S.keyLevel = U.clamp(S.keyLevel, 2, Profile.keyMax(S.zone))
    end

    ---------------------------------------------------------------------------
    -- Difficulty window, from the lobby's difficulty button: every difficulty
    -- of the chosen zone with what it changes, how to open the locked ones,
    -- and the keystone level for Mythic+. Done or Escape closes it.
    ---------------------------------------------------------------------------
    local DW = {x = 0.14, top = 0.545, w = 0.52, rowH = 0.06, step = 0.067, rows = 0.094}

    function Lobby.buildDifficulty(root)
        local D = {rows = {}, open = false}
        Lobby.D = D
        local group = UI.group(root)
        -- Above the tabs and the Options button, whose hits sit at level 8 on the lobby root.
        BlzFrameSetLevel(group, 9)
        D.group = group
        UI.box(group, -0.3, 0.6, 1.4, 0.6, 0, 0, 0, 170)
        BlzFrameSetLevel(UI.hit(group, -0.3, 0.6, 1.4, 0.6), 0)
        local x, T, w = DW.x, DW.top, DW.w
        local n = #DIFFICULTIES
        UI.card(group, x, T, w, DW.rows + n * DW.step + 0.062, 'DIFFICULTY')
        local ix, iw = x + LAY.pad, w - 2 * LAY.pad
        D.zone = UI.text(group, '', ix, T - 0.038, iw, 0.018, 0.0115, TEXT_JUSTIFY_CENTER)
        D.intro = UI.text(group, '', ix, T - 0.058, iw, 0.03, 0.0076, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP)
        local chipX = ix + 0.13
        for i = 1, n do
            local top = T - DW.rows - (i - 1) * DW.step
            local index = i
            local row = {}
            row.edge = {UI.frame(group, TPL.well, ix, top, iw, DW.rowH)}
            row.glow = UI.box(group, ix + 0.004, top - 0.004, iw - 0.008, DW.rowH - 0.008, 255, 255, 255, 0, TEX.highlight)
            row.name = UI.text(group, '', ix + 0.014, top - 0.009, chipX - ix - 0.014, 0.024, 0.0135)
            row.state = UI.text(group, '', ix + 0.014, top - 0.034, chipX - ix - 0.014, 0.016, 0.0074)
            row.chips = UI.text(group, '', chipX, top - 0.009, iw - 0.24, 0.02, 0.0082)
            row.desc = UI.text(group, '', chipX, top - 0.031, iw - 0.24, 0.024, 0.0074, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
            row.hit = UI.hit(group, ix, top, iw, DW.rowH, function()
                Lobby.chooseDifficulty(index)
            end)
            D.rows[i] = row
        end
        -- Keystone level at the right end of the Mythic+ row, over its click area.
        local ktop = T - DW.rows - (n - 1) * DW.step - 0.016
        local kx = ix + iw - 0.104
        D.keyDown = UI.button(group, kx, ktop, 0.028, 0.028, '-', function()
            S.keyLevel = math.max(2, S.keyLevel - 1)
            Lobby.refresh()
        end, 'dark', 0.014)
        D.keyText = UI.text(group, '', kx + 0.028, ktop, 0.048, 0.028, 0.0115, TEXT_JUSTIFY_CENTER)
        D.keyUp = UI.button(group, kx + 0.076, ktop, 0.028, 0.028, '+', function()
            S.keyLevel = math.min(Profile.keyMax(S.zone), S.keyLevel + 1)
            Lobby.refresh()
        end, 'dark', 0.014)
        UI.button(group, 0.4 - 0.07, T - DW.rows - n * DW.step - 0.004, 0.14, 0.032, U.col(GOLD, 'Done'), function()
            Lobby.closeDifficulty()
        end, 'red', 0.0115)
        BlzFrameSetVisible(group, false)
    end

    function Lobby.openDifficulty()
        Lobby.D.open = true
        BlzFrameSetVisible(Lobby.D.group, true)
        Lobby.renderDifficulty()
    end

    function Lobby.closeDifficulty()
        Lobby.D.open = false
        BlzFrameSetVisible(Lobby.D.group, false)
        Lobby.refresh()
    end

    -- A click on a row picks it when it is open; Mythic+ starts at the highest key.
    function Lobby.chooseDifficulty(index)
        if not Profile.difficultyOpen(S.zone, index) then
            return
        end
        if DIFFICULTIES[index].key == 'mplus' and S.difficulty ~= index then
            S.keyLevel = Profile.keyMax(S.zone)
        end
        S.difficulty = index
        Lobby.refresh()
    end

    function Lobby.renderDifficulty()
        local D = Lobby.D
        if not (D and D.open) then
            return
        end
        local zone = ZONES[S.zone]
        local cleared = Profile.zoneDiff(S.zone)
        BlzFrameSetText(D.zone, U.col(GOLD, zone.name) .. U.col(GREY, '  -  ' .. zone.subtitle))
        BlzFrameSetText(D.intro, U.col('d8cfc0', 'Each difficulty opens when you win ' .. zone.name
            .. ' on the one before it. Enemies hit harder and live longer; loot and gold grow with them.'))
        local function mult(label, value)
            return U.col(GREY, label .. ' ') .. U.col('ffffff', 'x' .. string.format('\037.2f', value))
        end
        for i, row in ipairs(D.rows) do
            local base = DIFFICULTIES[i]
            local d = G.difficulty(i, S.keyLevel)
            local open = Profile.difficultyOpen(S.zone, i)
            local selected = i == S.difficulty
            local keystone = base.key == 'mplus'
            BlzFrameSetText(row.name, U.col(open and base.hex or '6e665c', base.name))
            local state = ''
            if selected then
                state = U.col(GOLD, 'Selected')
            elseif not open then
                state = U.col('6e665c', 'Locked')
            elseif (keystone and Profile.keyBest(S.zone) > 0) or (not keystone and cleared >= i) then
                state = U.col(GREEN, 'Cleared')
            end
            BlzFrameSetText(row.state, state)
            local ilvl = 100 + 10 * (zone.tier - 1) + d.ilvl
            BlzFrameSetText(row.chips, (keystone and U.col('ff8000', '+' .. d.level .. '  ') or '')
                .. mult('Health', d.hp) .. '  ' .. mult('Damage', d.dmg) .. '  ' .. mult('Loot', d.reward)
                .. '  ' .. U.col(GREY, 'ilvl ') .. U.col('ffffff', tostring(ilvl)))
            local desc
            if not open then
                desc = U.col('b06a5a', 'Win ' .. zone.name .. ' on ' .. DIFFICULTIES[i - 1].name .. ' to open it.')
            elseif keystone then
                local best = Profile.keyBest(S.zone)
                desc = U.col(GREY, 'No end: kill the final boss in time to open the next keys (up to +'
                    .. Profile.keyMax(S.zone) .. ' now' .. (best > 0 and (', best timed +' .. best) or '') .. ').')
            else
                desc = U.col(GREY, base.blurb)
            end
            BlzFrameSetText(row.desc, desc)
            BlzFrameSetAlpha(row.glow, selected and 150 or 0)
            UI.edgeTint(row.edge, selected and 214 or 110, selected and 170 or 84, selected and 90 or 46, 255)
            if keystone then
                local showKey = open and selected
                UI.showButton(D.keyDown, showKey)
                UI.showButton(D.keyUp, showKey)
                BlzFrameSetVisible(D.keyText, showKey)
                BlzFrameSetText(D.keyText, U.col('ff8000', '+' .. S.keyLevel))
                UI.setEnabled(D.keyDown, S.keyLevel > 2)
                UI.setEnabled(D.keyUp, S.keyLevel < Profile.keyMax(S.zone))
            end
        end
    end

    function Lobby.showTraitInfo()
        local C = Lobby.C
        local hero = HEROES[S.heroIndex]
        local faction = U.factionOf(hero)
        BlzFrameSetTexture(C.infoIcon.img, TEX.emblem[faction.key], 0, true)
        UI.tint(C.infoIcon.img, 255, 255, 255, 255)
        BlzFrameSetText(C.infoTitle, U.col(faction.hex, faction.key))
        BlzFrameSetText(C.infoSub, U.col(GOLD, faction.trait))
        local lines = {}
        for _, line in ipairs(faction.lines) do
            lines[#lines + 1] = U.col(GOLD, '-  ') .. line
        end
        lines[#lines + 1] = ''
        lines[#lines + 1] = U.col(GREY, 'The basic attack fires on its own, even while walking. Hover a spell to read it.')
        BlzFrameSetText(C.infoBody, table.concat(lines, '\n'))
    end

    function Lobby.showSpellInfo(key)
        local def = SPELLS[key]
        if def == nil then
            return
        end
        local C = Lobby.C
        UI.setIcon(C.infoIcon, U.spellIcon(def))
        BlzFrameSetText(C.infoTitle, U.col(GOLD, def.name))
        BlzFrameSetText(C.infoSub, U.col(GREY, (KIND_NAMES[def.kind] or '') .. rankNote(def.maxRank)))
        local v = G.spellValues(def, 1, 1, G.baseStats())
        BlzFrameSetText(C.infoBody, U.col('d8cfc0', G.describe(def, v)))
    end

    function Lobby.refreshCharacter()
        local C = Lobby.C
        local hero = HEROES[S.heroIndex]
        local faction = U.factionOf(hero)
        for i, faction2 in ipairs(FACTIONS) do
            local o = C.factions[i]
            local selected = faction2.key == S.faction
            BlzFrameSetAlpha(o.ring, selected and 200 or 0)
            local v = selected and 255 or 140
            UI.tint(o.img, v, v, v, 255)
        end
        local current = FACTIONS[1]
        for _, f in ipairs(FACTIONS) do
            if f.key == S.faction then
                current = f
            end
        end
        BlzFrameSetText(C.factionName, U.col(current.hex, current.key))
        local list = heroesOf(S.faction)
        for i, cell in ipairs(C.cells) do
            local index = list[i]
            cell.heroIndex = index
            if index then
                -- A hero that has not joined yet is dim, its name grey.
                local open = Profile.heroOpen(HEROES[index])
                UI.setIcon(cell.icon, U.heroIcon(HEROES[index]), not open)
                -- Grid labels hold one line: long names use their short form.
                local label = HEROES[index].short or HEROES[index].name
                BlzFrameSetText(cell.name, index == S.heroIndex and U.col(GOLD, label) or (open and label or U.col('6e665c', label)))
                UI.showIcon(cell.icon, true)
                BlzFrameSetVisible(cell.name, true)
            else
                UI.showIcon(cell.icon, false)
                BlzFrameSetVisible(cell.name, false)
            end
            BlzFrameSetVisible(cell.glow, index ~= nil)
            Lobby.paintCell(cell)
        end

        BlzFrameSetText(C.heroName, U.col(GOLD, hero.name))
        BlzFrameSetText(C.heroRole, U.col(GREY, hero.role))
        BlzFrameSetText(C.blurb, U.col('d8cfc0', hero.blurb))
        local startKey = G.startSpell(hero)
        local start = SPELLS[startKey]
        BlzFrameSetText(C.stats[1], tostring(U.heroHealth(hero)))
        BlzFrameSetText(C.stats[2], tostring(hero.damage + hero.attr[hero.primary]))
        BlzFrameSetText(C.stats[3], U.heroAttributes(hero))
        for i, o in ipairs(C.pool) do
            local key = hero.pool[i]
            if key and SPELLS[key] then
                UI.setIcon(o, U.spellIcon(SPELLS[key]))
                local chosen = key == startKey
                UI.frameColor(o, chosen and 255 or 130, chosen and 214 or 100, chosen and 120 or 56)
                UI.showIcon(o, true)
            else
                UI.showIcon(o, false)
            end
        end

        BlzFrameSetText(C.showName, U.col(GOLD, hero.name))
        BlzFrameSetText(C.showLine, U.col(faction.hex, hero.faction) .. U.col(GREY, '  -  ' .. hero.role))
        BlzFrameSetTexture(C.showEmblem, TEX.emblem[hero.faction], 0, true)
        local p = Profile.data
        BlzFrameSetText(C.record, U.col(GREY, 'Runs ') .. p.runs .. U.col(GREY, '    Wins ') .. p.wins
            .. U.col(GREY, '    Wins with this hero ') .. (p.heroWins[hero.id] or 0))
        UI.setIcon(C.startIcon, U.spellIcon(start))
        UI.frameColor(C.startIcon, 255, 214, 120)
        BlzFrameSetText(C.startName, U.col(GOLD, start.name))
        BlzFrameSetText(C.startKind, U.col(GREY, (KIND_NAMES[start.kind] or '') .. rankNote(start.maxRank)))
        Lobby.showTraitInfo()

        local zone = ZONES[S.zone]
        -- The arena shot ships with the engine build only (Scripts\Survivor).
        local thumb = Engine.active() and zone.thumb
        BlzFrameSetTexture(C.zoneArt, thumb or zone.art, 0, true)
        BlzFrameSetSize(C.zoneArt, thumb and 0.094 or 0.047, 0.047)
        UI.place(C.zoneArtEdge[1], C.zoneArtX - 0.002, C.zoneArtTop + 0.002, (thumb and 0.094 or 0.047) + 0.004, 0.051)
        local tierHex = TIER_HEX[zone.tier]
        BlzFrameSetText(C.zoneName, U.col(GOLD, zone.name))
        BlzFrameSetText(C.zoneTier, U.col(tierHex, TIER_NAME[zone.tier]:upper()))
        BlzFrameSetText(C.zoneSub, U.col(tierHex, zone.subtitle))
        BlzFrameSetText(C.zoneDesc, U.col('d8cfc0', zone.desc))
        local chips = {}
        for _, boss in ipairs(zone.bosses) do
            chips[#chips + 1] = U.col(GOLD, U.time(boss.t)) .. ' ' .. boss.name
        end
        chips[#chips + 1] = U.col(RED, U.time(CFG.RUN_LENGTH) .. ' ' .. zone.final.name)
        BlzFrameSetText(C.zoneBosses, table.concat(chips, U.col(GREY, '  -  ')))
        local marks = {}
        local cleared = Profile.zoneDiff(S.zone)
        for index = 1, 3 do
            local d = DIFFICULTIES[index]
            marks[#marks + 1] = cleared >= index and U.col(d.hex, d.name) or U.col('6e665c', d.name)
        end
        local keyBest = Profile.keyBest(S.zone)
        marks[#marks + 1] = keyBest > 0 and U.col('ff8000', 'best +' .. keyBest) or U.col('6e665c', 'no key timed')
        BlzFrameSetText(C.zoneRecord, table.concat(marks, U.col(GREY, '  -  ')))
        for rank, row in ipairs(C.zoneRows) do
            local z = ZONES[row.zone]
            local unlocked = rank <= p.unlocked
            local selected = row.zone == S.zone
            BlzFrameSetAlpha(row.glow, selected and 150 or 0)
            -- Half-width rows: the status is one short word (best cleared
            -- difficulty or timed key); the card above has the full record.
            if unlocked then
                BlzFrameSetText(row.name, selected and U.col(GOLD, z.name) or z.name)
                local zoneCleared = Profile.zoneDiff(row.zone)
                local zoneKey = Profile.keyBest(row.zone)
                if zoneKey > 0 then
                    BlzFrameSetText(row.status, U.col('ff8000', '+' .. zoneKey))
                elseif zoneCleared > 0 then
                    local d = DIFFICULTIES[math.min(3, zoneCleared)]
                    BlzFrameSetText(row.status, U.col(d.hex, d.name))
                else
                    BlzFrameSetText(row.status, '')
                end
            else
                BlzFrameSetText(row.name, U.col('6e665c', z.name))
                BlzFrameSetText(row.status, '')
            end
            UI.edgeTint(row.edge, selected and 214 or 110, selected and 170 or 84, selected and 90 or 46, 255)
        end

        Lobby.clampDifficulty()
        local diff = G.difficulty(S.difficulty, S.keyLevel)
        UI.setLabel(C.difficulty, U.col(diff.hex, diff.name) .. '\n' .. U.col(GREY, 'rewards x' .. string.format('\037.2f', diff.reward)
            .. '  ilvl ' .. (100 + 10 * (zone.tier - 1) + diff.ilvl)))
        local keystone = diff.key == 'mplus'
        if keystone then
            BlzFrameSetText(C.keyHint, U.col(GREY, 'Time a key to open the next ones: up to +' .. Profile.keyMax(S.zone)))
        elseif not Profile.difficultyOpen(S.zone, S.difficulty + 1) and S.difficulty < #DIFFICULTIES then
            BlzFrameSetText(C.keyHint, U.col(GREY, 'Win on ' .. diff.name .. ' to open ' .. DIFFICULTIES[S.difficulty + 1].name))
        else
            BlzFrameSetText(C.keyHint, '')
        end
        local sub = zone.subtitle .. '  -  ' .. zone.final.name .. ' awaits at ' .. U.time(CFG.RUN_LENGTH)
        if keystone then
            sub = 'Keystone +' .. diff.level .. '  -  ' .. zone.final.name .. ' awaits at ' .. U.time(CFG.RUN_LENGTH)
        end
        if Profile.heroOpen(hero) then
            UI.setLabel(C.enter, U.col(GOLD, 'ENTER ' .. zone.name:upper()))
        else
            UI.setLabel(C.enter, U.col(GREY, 'LOCKED HERO'))
            sub = Profile.unlockText(hero.unlock)
        end
        UI.setEnabled(C.enter, Profile.heroOpen(hero))
        BlzFrameSetText(C.enterSub, U.col(GREY, sub))
        Lobby.renderDifficulty()
    end

    -- Details panel shared by the armory and the codex: an icon, a name, a
    -- subtitle and a body, in the right column.
    local function detailsPanel(page, D)
        local x, w, P, T = LAY.right, LAY.side, LAY.pad, LAY.top
        UI.card(page, x, T, w, LAY.h, 'DETAILS')
        D.icon = UI.icon(page, TEX.white, x + P + 0.003, T - 0.048, 0.04)
        D.name = UI.text(page, '', x + P + 0.054, T - 0.047, w - 2 * P - 0.054, 0.016, 0.0105)
        D.sub = UI.text(page, '', x + P + 0.054, T - 0.065, w - 2 * P - 0.054, 0.024, 0.0072, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        D.body = UI.text(page, '', x + P, T - 0.1, w - 2 * P, 0.078, 0.0082, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        return x + P, w - 2 * P
    end

    -- Progress line along the bottom of a main panel.
    local function progressBar(page, x, w)
        local bar = UI.bar(page, x, LAY.bottom + 0.032, w, 0.008, 214, 170, 90, 0.0068)
        local text = UI.text(page, '', x, LAY.bottom + 0.05, w, 0.012, 0.0076, TEXT_JUSTIFY_RIGHT)
        return bar, text
    end

    ---------------------------------------------------------------------------
    -- Armory tab: the items bosses drop, the six carried into every run (the
    -- classic inventory), item levels and the upgrade track
    ---------------------------------------------------------------------------
    function Lobby.buildCollection(page)
        local K = {}
        Lobby.K = K
        local P, T = LAY.pad, LAY.top
        local x, w = LAY.x0, LAY.mainW
        local ix, iw = x + P, w - 2 * P
        UI.card(page, x, T, w, LAY.h, 'ARMORY')
        UI.text(page, U.col(GREY, 'Every boss drops an item. Carry any six into your runs: pick an item, then Equip.'),
            ix, T - 0.042, iw, 0.013, 0.0072, TEXT_JUSTIFY_CENTER)
        K.icons = {}
        -- Two columns of zones in play order, each a name and its five items.
        local rows = math.ceil(#ZONES / 2)
        local colGap = 0.016
        local colW = (iw - colGap) / 2
        local labelW = colW * 0.34
        local step = (colW - labelW) / 5
        local size = math.min(0.031, step - 0.006)
        for rank, zi in ipairs(ZONE_ORDER) do
            local zone = ZONES[zi]
            local cx = ix + ((rank - 1) // rows) * (colW + colGap)
            local top = T - 0.066 - math.fmod(rank - 1, rows) * 0.048
            UI.text(page, U.col(GOLD, zone.name), cx, top, labelW, 0.016, 0.0088)
            UI.text(page, U.col(GREY, 'Item level ' .. (100 + 10 * (zone.tier - 1)) .. '+'), cx, top - 0.017, labelW, 0.012, 0.0066)
            local bosses = {zone.bosses[1], zone.bosses[2], zone.bosses[3], zone.bosses[4], zone.final}
            for bi, boss in ipairs(bosses) do
                local item = boss.item
                local bx = cx + labelW + (bi - 1) * step + (step - size) / 2
                -- Hover previews an item; click selects it for Equip and Upgrade.
                local o = UI.icon(page, gearIcon(item), bx, top, size, function()
                    Lobby.selectItem(item)
                end, function()
                    Lobby.showItem(item)
                end, function()
                    if K.selected then
                        Lobby.showItem(K.selected)
                    end
                end)
                o.worn = UI.text(page, '', bx + size - 0.012, top - 0.001, 0.011, 0.011, 0.0072, TEXT_JUSTIFY_RIGHT)
                o.ilvl = UI.text(page, '', bx - 0.012, top - size - 0.003, size + 0.024, 0.01, 0.0064, TEXT_JUSTIFY_CENTER)
                o.item = item
                K.icons[#K.icons + 1] = o
            end
        end
        K.progress, K.progressText = progressBar(page, ix, iw)

        local dx, dw = detailsPanel(page, K)
        K.equip = UI.button(page, dx, T - 0.17, dw, 0.028, '', function()
            Lobby.toggleEquip()
        end, 'dark', 0.0092)
        K.upgrade = UI.button(page, dx, T - 0.203, dw, 0.028, '', function()
            Lobby.upgradeItem()
        end, 'green', 0.0088)
        UI.rule(page, 'INVENTORY', dx, T - 0.238, dw, 0.011)
        K.average = UI.text(page, '', dx, T - 0.254, dw, 0.012, 0.0074, TEXT_JUSTIFY_CENTER)
        -- Two columns of three, like the hero inventory of the game.
        K.slots = {}
        local slotSize, slotGap = 0.036, 0.008
        for slot = 1, INVENTORY_SIZE do
            local column = math.fmod(slot - 1, 2)
            local row = (slot - 1) // 2
            local sx = dx + 0.008 + column * (slotSize + slotGap)
            local stop = T - 0.274 - row * (slotSize + slotGap)
            local o = UI.icon(page, TEX.white, sx, stop, slotSize, function()
                local item = gearEquipped(Profile.data)[slot]
                if item then
                    Lobby.selectItem(item)
                end
            end)
            K.slots[slot] = o
        end
        local listX = dx + 0.008 + 2 * slotSize + slotGap + 0.012
        K.worn = UI.text(page, '', listX, T - 0.266, dx + dw - listX, 3 * slotSize + 2 * slotGap + 0.01, 0.0064,
            TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
    end

    function Lobby.selectItem(item)
        Lobby.K.selected = item
        Lobby.refreshCollection()
    end

    function Lobby.showItem(item)
        local K = Lobby.K
        local p = Profile.data
        local ilvl = Profile.itemLevel(item)
        local steps = p.upg[item.id] or 0
        UI.setIcon(K.icon, gearIcon(item), ilvl == nil)
        BlzFrameSetText(K.name, ilvl and U.col(gearHex(ilvl), item.name) or U.col('6e665c', item.name))
        BlzFrameSetText(K.sub, U.col(GREY, 'Dropped by ') .. item.boss.name
            .. U.col(GREY, '\nin ' .. ZONES[item.zone].name .. ' at ' .. U.time(item.boss.t)))
        local lines = {}
        if ilvl then
            lines[#lines + 1] = U.col(GOLD, 'Item level ' .. ilvl) .. U.col(GREY, '   upgrade ' .. steps .. '/' .. GEAR_UPGRADES
                .. '   ') .. (gearSlotOf(p, item) and U.col(GREEN, 'Carried') or U.col(GREY, 'In the armory'))
            lines[#lines + 1] = G.describeItem(item, ilvl)
            lines[#lines + 1] = G.describeItemEffect(item, ilvl)
            local nextText = steps < GEAR_UPGRADES and G.describeItemNext(item, ilvl)
            if nextText then
                lines[#lines + 1] = U.col(GREY, 'Next: ') .. nextText
            end
        else
            lines[#lines + 1] = U.col(GREY, 'Not looted yet. At item level ' .. item.baseIlvl .. ':')
            lines[#lines + 1] = G.describeItem(item, item.baseIlvl)
            lines[#lines + 1] = G.describeItemEffect(item, item.baseIlvl)
            lines[#lines + 1] = U.col(GREY, 'Drops at item level ') .. item.baseIlvl .. U.col(GREY, ' on Normal, ')
                .. (item.baseIlvl + 10) .. U.col(GREY, ' Heroic, ') .. (item.baseIlvl + 20) .. U.col(GREY, ' Mythic, up to ')
                .. (item.baseIlvl + 40) .. U.col(GREY, ' from a +10 keystone.')
        end
        BlzFrameSetText(K.body, table.concat(lines, '\n'))
        -- The buttons act on the selected item, not the hovered one.
        local selected = K.selected
        local owned = selected and Profile.itemLevel(selected) ~= nil
        if not owned then
            UI.setLabel(K.equip, 'Loot it first')
            UI.setEnabled(K.equip, false)
            UI.setLabel(K.upgrade, 'Upgrade')
            UI.setEnabled(K.upgrade, false)
            return
        end
        if gearSlotOf(p, selected) then
            UI.setLabel(K.equip, 'Unequip')
            UI.setEnabled(K.equip, true)
        elseif Lobby.freeSlot() then
            UI.setLabel(K.equip, 'Equip')
            UI.setEnabled(K.equip, true)
        else
            UI.setLabel(K.equip, 'Inventory full  -  unequip an item')
            UI.setEnabled(K.equip, false)
        end
        if (p.upg[selected.id] or 0) >= GEAR_UPGRADES then
            UI.setLabel(K.upgrade, 'Fully upgraded')
            UI.setEnabled(K.upgrade, false)
        else
            local cost = gearUpgradeCost(p, selected)
            UI.setLabel(K.upgrade, 'Upgrade  +' .. GEAR_STEP_ILVL .. ' item level  -  ' .. U.col(GOLD, cost .. ' gold'))
            UI.setEnabled(K.upgrade, p.gold >= cost)
        end
    end

    function Lobby.freeSlot()
        local worn = gearEquipped(Profile.data)
        for slot = 1, INVENTORY_SIZE do
            if worn[slot] == nil then
                return slot
            end
        end
        return nil
    end

    function Lobby.toggleEquip()
        local item = Lobby.K.selected
        local p = Profile.data
        if item == nil or p.gear[item.id] == nil then
            return
        end
        local slot = gearSlotOf(p, item)
        if slot then
            p.inv[tostring(slot)] = nil
        else
            slot = Lobby.freeSlot()
            if slot == nil then
                return
            end
            p.inv[tostring(slot)] = item.index
        end
        Profile.checkAchievements()
        Profile.save()
        Lobby.refresh()
    end

    function Lobby.upgradeItem()
        local item = Lobby.K.selected
        local p = Profile.data
        if item == nil or p.gear[item.id] == nil or (p.upg[item.id] or 0) >= GEAR_UPGRADES then
            return
        end
        local cost = gearUpgradeCost(p, item)
        if p.gold < cost then
            return
        end
        p.gold = p.gold - cost
        p.upg[item.id] = (p.upg[item.id] or 0) + 1
        Profile.checkAchievements()
        Profile.save()
        Lobby.refresh()
    end

    function Lobby.refreshCollection()
        local K = Lobby.K
        local p = Profile.data
        local owned = 0
        for _, o in ipairs(K.icons) do
            local ilvl = Profile.itemLevel(o.item)
            UI.setIcon(o, gearIcon(o.item), ilvl == nil)
            if ilvl then
                owned = owned + 1
                local hex = gearHex(ilvl)
                UI.frameColor(o, tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
                BlzFrameSetText(o.ilvl, U.col(hex, tostring(ilvl)))
                BlzFrameSetText(o.worn, gearSlotOf(p, o.item) and U.col(GOLD, 'E') or '')
            else
                UI.frameColor(o, 70, 60, 50)
                BlzFrameSetText(o.ilvl, U.col('6e665c', U.time(o.item.boss.t)))
                BlzFrameSetText(o.worn, '')
            end
            if o.item == K.selected then
                UI.frameColor(o, 255, 255, 255)
            end
        end
        UI.setBar(K.progress, owned / #GEAR)
        BlzFrameSetText(K.progressText, U.col(GREY, 'Looted ') .. owned .. ' / ' .. #GEAR)
        BlzFrameSetText(K.average, U.col(GREY, 'Average item level ') .. U.col(GOLD, tostring(gearAverage(p))))
        -- Beside the six slots, what they add up to: every stat summed, then
        -- the effects by name.
        local worn = gearEquipped(p)
        local totals, effects = {}, {}
        for slot = 1, INVENTORY_SIZE do
            local item = worn[slot]
            local o = K.slots[slot]
            if item then
                local ilvl = Profile.itemLevel(item)
                UI.setIcon(o, gearIcon(item))
                UI.frameColor(o, item == K.selected and 255 or 214, item == K.selected and 255 or 170, item == K.selected and 255 or 90)
                for _, entry in ipairs(item.stats) do
                    local x = gearValue(entry.stat, entry.w, ilvl)
                    -- All attributes count into each of the three.
                    for _, key in ipairs(entry.key == 'all' and {'str', 'agi', 'int'} or {entry.key}) do
                        totals[key] = (totals[key] or 0) + x
                    end
                end
                if item.effect then
                    effects[#effects + 1] = item.effect.name
                end
            else
                BlzFrameSetTexture(o.img, TEX.white, 0, true)
                UI.tint(o.img, 18, 14, 10, 230)
                UI.frameColor(o, 90, 70, 44)
            end
        end
        local lines = {}
        for _, key in ipairs(ITEM_STAT_ORDER) do
            if totals[key] then
                lines[#lines + 1] = G.describeBlessing(ITEM_STATS[key], totals[key])
            end
        end
        -- One stat a line, then the effects by name (about 28 letters a line);
        -- ten lines fit beside the slots, so a long list of effects shrinks to
        -- a count (each item's details name its own).
        if #effects > 0 then
            local names = table.concat(effects, ', ')
            if #lines + math.ceil(#names / 28) > 10 then
                names = #effects .. ' effects'
            end
            lines[#lines + 1] = U.col(GREEN, names)
        end
        BlzFrameSetText(K.worn, #lines > 0 and table.concat(lines, '\n') or U.col('6e665c', 'Nothing carried yet.'))
        local selected = K.selected
        if selected == nil then
            -- Open on the first item owned, so Equip and Upgrade are in reach.
            for _, item in ipairs(GEAR) do
                if p.gear[item.id] then
                    selected = item
                    break
                end
            end
        end
        K.selected = selected or GEAR[1]
        Lobby.showItem(K.selected)
    end

    ---------------------------------------------------------------------------
    -- Codex tab: every card a run has ever offered
    ---------------------------------------------------------------------------
    function Lobby.buildCodex(page)
        local X = {}
        Lobby.X = X
        local P, T = LAY.pad, LAY.top
        local x, w = LAY.x0, LAY.mainW
        local ix, iw = x + P, w - 2 * P
        UI.card(page, x, T, w, LAY.h, 'CODEX')
        UI.text(page, U.col(GREY, 'SPELLS'), ix, T - 0.042, 0.2, 0.012, 0.0072)
        X.icons = {}
        local size, step = 0.025, 0.0302
        local perRow = math.floor((iw + step - size) / step)
        local gridX = ix + (iw - (perRow - 1) * step - size) / 2
        for i, key in ipairs(SPELL_ORDER) do
            local column = math.fmod(i - 1, perRow)
            local row = (i - 1) // perRow
            local o = UI.icon(page, U.spellIcon(SPELLS[key]), gridX + column * step, T - 0.058 - row * step, size, nil, function()
                Lobby.showCodexEntry(key)
            end)
            o.key = key
            X.icons[#X.icons + 1] = o
        end
        local rows = (#SPELL_ORDER + perRow - 1) // perRow
        local blessTop = T - 0.058 - rows * step - 0.02
        UI.text(page, U.col(GREY, 'BLESSINGS') .. U.col('a83a2c', '   red frame: opens with an achievement'), ix,
            blessTop + 0.016, 0.3, 0.012, 0.0072)
        for i, b in ipairs(BLESSINGS) do
            local column = math.fmod(i - 1, perRow)
            local row = (i - 1) // perRow
            local key = b.key
            local o = UI.icon(page, U.icon(b.code, b.icon), gridX + column * step, blessTop - row * step, size, nil, function()
                Lobby.showCodexEntry(key)
            end)
            o.key = key
            o.blessing = b
            X.icons[#X.icons + 1] = o
        end
        X.progress, X.progressText = progressBar(page, ix, iw)

        local dx, dw = detailsPanel(page, X)
        X.heroes = UI.text(page, '', dx, T - 0.19, dw, LAY.h - 0.19 - P, 0.0076, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
    end

    function Lobby.showCodexEntry(key)
        local X = Lobby.X
        local seen = Profile.data.codex[key] ~= nil
        local def = SPELLS[key]
        if def then
            UI.setIcon(X.icon, U.spellIcon(def), not seen)
            BlzFrameSetText(X.name, seen and U.col(GOLD, def.name) or U.col('6e665c', def.name))
            BlzFrameSetText(X.sub, U.col(GREY, (KIND_NAMES[def.kind] or def.kind) .. rankNote(def.maxRank)))
            BlzFrameSetText(X.body, U.col('d8cfc0', G.describe(def, G.spellValues(def, 1, 1, G.baseStats()))))
            local names = {}
            for _, hero in ipairs(HEROES) do
                for _, poolKey in ipairs(hero.pool) do
                    if poolKey == key then
                        names[#names + 1] = hero.name
                    end
                end
            end
            BlzFrameSetText(X.heroes, U.col(GREY, 'Offered to: ') .. table.concat(names, ', ')
                .. (seen and '' or ('\n\n' .. U.col('6e665c', 'Not offered yet.'))))
        else
            local b = BLESSING_BY_KEY[key]
            UI.setIcon(X.icon, U.icon(b.code, b.icon), not seen)
            BlzFrameSetText(X.name, seen and U.col(GOLD, b.name) or U.col('6e665c', b.name))
            BlzFrameSetText(X.sub, U.col(GREY, 'Blessing' .. rankNote(nil)))
            BlzFrameSetText(X.body, U.col('d8cfc0', G.describeBlessing(b, b.per) .. ' per rank.'))
            BlzFrameSetText(X.heroes, U.col(GREY, 'Offered to every hero. Takes no spell slot.')
                .. (Profile.blessingOpen(b) and '' or ('\n\n' .. U.col(RED, 'Locked.  ') .. U.col(GREY, 'Opens with ')
                    .. Profile.unlockText(b.unlock))))
        end
    end

    function Lobby.refreshCodex()
        local X = Lobby.X
        local seen = 0
        for _, o in ipairs(X.icons) do
            local has = Profile.data.codex[o.key] ~= nil
            if has then
                seen = seen + 1
            end
            local texture = o.blessing and U.icon(o.blessing.code, o.blessing.icon) or U.spellIcon(SPELLS[o.key])
            -- A stat card its achievement has not opened yet: dark, with a red frame.
            local locked = o.blessing and not Profile.blessingOpen(o.blessing)
            UI.setIcon(o, texture, not has or locked)
            if locked then
                UI.frameColor(o, 150, 36, 28)
            else
                UI.frameColor(o, has and 150 or 60, has and 112 or 50, has and 58 or 40)
            end
        end
        UI.setBar(X.progress, seen / #X.icons)
        BlzFrameSetText(X.progressText, U.col(GREY, 'Discovered ') .. seen .. ' / ' .. #X.icons)
        Lobby.showCodexEntry(SPELL_ORDER[1])
    end

    ---------------------------------------------------------------------------
    -- Talents tab: permanent upgrades bought with gold
    ---------------------------------------------------------------------------
    function Lobby.buildTalents(page)
        local T = {rows = {}}
        Lobby.T = T
        local P, top0 = LAY.pad, LAY.top
        local x, w = LAY.x0, LAY.w
        local ix, iw = x + P, w - 2 * P
        UI.card(page, x, top0, w, LAY.h, 'TALENTS')
        T.info = UI.text(page, '', ix, top0 - 0.042, iw, 0.013, 0.0078, TEXT_JUSTIFY_CENTER)
        local rowW = (iw - LAY.gap) / 2
        -- Seven rows of two fit above the refund button.
        local rowH = 0.044
        for i, talent in ipairs(TALENTS) do
            local column = math.fmod(i - 1, 2)
            local row = (i - 1) // 2
            local rx = ix + column * (rowW + LAY.gap)
            local top = top0 - 0.062 - row * 0.047
            local o = {}
            well(page, rx, top, rowW, rowH)
            o.icon = UI.icon(page, U.icon(talent.code, talent.icon), rx + 0.01, top - 0.007, 0.032)
            local textW = rowW - 0.052 - 0.1
            o.name = UI.text(page, '', rx + 0.052, top - 0.003, textW, 0.016, 0.0102)
            o.rank = UI.text(page, '', rx + 0.052, top - 0.016, textW, 0.012, 0.0072)
            o.desc = UI.text(page, '', rx + 0.052, top - 0.027, textW, 0.014, 0.0074)
            -- Hovering the row shows what every rank gives; the buy button
            -- is made after, so it stays on top and clickable.
            UI.hit(page, rx, top, rowW, rowH, nil, function()
                Lobby.talentTip(i, rx, top, rowH)
            end, function()
                UI.hideTooltip(T.tip)
            end)
            local key = talent.key
            o.buy = UI.button(page, rx + rowW - 0.092, top - 0.009, 0.082, 0.028, '', function()
                Lobby.buyTalent(key)
            end, 'green', 0.0092)
            T.rows[i] = o
        end
        T.refund = UI.button(page, 0.4 - 0.08, LAY.bottom + 0.03, 0.16, 0.026, 'Refund all talents', function()
            local p = Profile.data
            for _, talent in ipairs(TALENTS) do
                for rank = 1, Profile.talent(talent.key) do
                    p.gold = p.gold + talentCost(rank)
                end
                p.talents[talent.key] = nil
            end
            Profile.save()
            Lobby.refresh()
        end, 'dark', 0.0088)
        T.tip = UI.tooltip(page, 1, 0.3, 0.12)
    end

    -- A talent's ranks: what it gives now, per rank, at the next rank and at max.
    function Lobby.talentTip(i, rx, top, rowH)
        local T = Lobby.T
        local talent = TALENTS[i]
        local rank = Profile.talent(talent.key)
        local lines = {'Each rank: ' .. G.describeBlessing(talent, talent.per)}
        if not Profile.talentOpen(talent) then
            lines[#lines + 1] = U.col(RED, 'Locked.') .. ' Opens with ' .. U.col(GOLD, Profile.unlockText(talent.unlock))
        end
        if rank > 0 then
            lines[#lines + 1] = 'Now: ' .. G.describeBlessing(talent, talent.per * rank)
        end
        if rank < talent.max then
            lines[#lines + 1] = 'Next rank: ' .. G.describeBlessing(talent, talent.per * (rank + 1))
                .. U.col(GREY, '  (') .. U.col(GOLD, U.big(talentCost(rank + 1)) .. ' gold') .. U.col(GREY, ')')
        end
        lines[#lines + 1] = 'At rank ' .. talent.max .. ': ' .. G.describeBlessing(talent, talent.per * talent.max)
        -- Under the row, or over it when the row sits low on the page.
        local bottom = top - rowH - 0.004 - T.tip.h
        if bottom < LAY.bottom + 0.01 then
            bottom = top + 0.004
        end
        UI.showTooltip(T.tip, rx, bottom, U.icon(talent.code, talent.icon), U.col(GOLD, talent.name),
            'Talent  -  rank ' .. rank .. ' / ' .. talent.max, table.concat(lines, '\n'))
    end

    function Lobby.buyTalent(key)
        for _, talent in ipairs(TALENTS) do
            if talent.key == key then
                local rank = Profile.talent(key)
                local cost = talentCost(rank + 1)
                if Profile.talentOpen(talent) and rank < talent.max and Profile.data.gold >= cost then
                    Profile.data.gold = Profile.data.gold - cost
                    Profile.data.talents[key] = rank + 1
                    Profile.save()
                    Lobby.refresh()
                end
                return
            end
        end
    end

    function Lobby.refreshTalents()
        local T = Lobby.T
        BlzFrameSetText(T.info, U.col(GREY, 'Gold from every run buys permanent talents for all heroes.   You have ')
            .. U.col(GOLD, U.big(Profile.data.gold) .. ' gold'))
        for i, talent in ipairs(TALENTS) do
            local o = T.rows[i]
            local rank = Profile.talent(talent.key)
            local open = Profile.talentOpen(talent)
            UI.setIcon(o.icon, U.icon(talent.code, talent.icon), not open)
            BlzFrameSetText(o.name, U.col(open and GOLD or '6e665c', talent.name))
            BlzFrameSetText(o.rank, U.col(GREY, 'Rank ') .. rank .. ' / ' .. talent.max)
            local current = rank > 0 and G.describeBlessing(talent, talent.per * rank) or U.col(GREY, 'Not learned')
            -- A locked talent names the achievement that opens it.
            if not open then
                current = U.col(GREY, 'Opens with ' .. ACH_BY_KEY[talent.unlock].name)
            end
            BlzFrameSetText(o.desc, current)
            if not open then
                UI.setLabel(o.buy, 'Locked')
                UI.setEnabled(o.buy, false)
            elseif rank >= talent.max then
                UI.setLabel(o.buy, 'Max')
                UI.setEnabled(o.buy, false)
            else
                local cost = talentCost(rank + 1)
                UI.setLabel(o.buy, U.col(GOLD, U.big(cost)) .. ' gold')
                UI.setEnabled(o.buy, Profile.data.gold >= cost)
            end
        end
    end

    -- Summary column of the achievements and rewards pages: a big number,
    -- a line under it, and a note.
    local function summaryPanel(page, title, note)
        local x, w, P, T = LAY.x0, LAY.summary, LAY.pad, LAY.top
        UI.card(page, x, T, w, LAY.h, title)
        local big = UI.text(page, '', x, T - 0.044, w, 0.05, 0.04, TEXT_JUSTIFY_CENTER)
        UI.text(page, U.col(GREY, note), x + P, LAY.bottom + 0.11, w - 2 * P, 0.085, 0.0074, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        return big, x + P, w - 2 * P
    end

    -- Two columns of cells in the list panel right of the summary.
    local function listPanel(page, title)
        local x = LAY.x0 + LAY.summary + LAY.gap
        local w = LAY.x1 - x
        UI.card(page, x, LAY.top, w, LAY.h, title)
        local ix, iw = x + LAY.pad, w - 2 * LAY.pad
        return ix, (iw - LAY.gap) / 2
    end

    ---------------------------------------------------------------------------
    -- Achievements tab
    ---------------------------------------------------------------------------
    local ACH_PER_PAGE = 12

    function Lobby.buildAchievements(page)
        local A = {cells = {}, page = 1}
        Lobby.A = A
        local sx, sw
        A.points, sx, sw = summaryPanel(page, 'ACHIEVEMENTS', 'Every hero earns them for the whole account. Spend the points on the Rewards tab.')
        A.pointsSub = UI.text(page, '', sx, LAY.top - 0.098, sw, 0.013, 0.008, TEXT_JUSTIFY_CENTER)
        A.progress = UI.bar(page, sx + 0.006, LAY.top - 0.124, sw - 0.012, 0.008, 214, 170, 90, 0.0068)
        A.count = UI.text(page, '', sx, LAY.top - 0.14, sw, 0.013, 0.008, TEXT_JUSTIFY_CENTER)

        local lx, cw = listPanel(page, 'ALL ACHIEVEMENTS')
        for i = 1, ACH_PER_PAGE do
            local column = math.fmod(i - 1, 2)
            local row = (i - 1) // 2
            local x = lx + column * (cw + LAY.gap)
            local top = LAY.top - 0.046 - row * 0.054
            local o = {}
            o.edge = well(page, x, top, cw, 0.048)
            o.icon = UI.icon(page, TEX.white, x + 0.008, top - 0.008, 0.032)
            local textW = cw - 0.05 - 0.05
            o.name = UI.text(page, '', x + 0.05, top - 0.004, textW, 0.015, 0.0094)
            o.desc = UI.text(page, '', x + 0.05, top - 0.018, textW, 0.012, 0.007)
            o.bar = UI.bar(page, x + 0.052, top - 0.035, textW - 0.066, 0.006, 214, 170, 90, 0.006)
            o.barText = UI.text(page, '', x + 0.052 + textW - 0.058, top - 0.031, 0.058, 0.012, 0.0064)
            o.points = UI.text(page, '', x + cw - 0.048, top - 0.004, 0.04, 0.02, 0.0115, TEXT_JUSTIFY_RIGHT)
            A.cells[i] = o
        end
        local mid = lx + cw + LAY.gap / 2
        A.prev = UI.button(page, mid - 0.115, LAY.bottom + 0.05, 0.075, 0.026, '< Prev', function()
            A.page = math.max(1, A.page - 1)
            Lobby.refresh()
        end, 'dark', 0.0088)
        A.pageText = UI.text(page, '', mid - 0.035, LAY.bottom + 0.05, 0.07, 0.026, 0.0088, TEXT_JUSTIFY_CENTER)
        A.next = UI.button(page, mid + 0.04, LAY.bottom + 0.05, 0.075, 0.026, 'Next >', function()
            A.page = math.min(math.ceil(#ACHIEVEMENTS / ACH_PER_PAGE), A.page + 1)
            Lobby.refresh()
        end, 'dark', 0.0088)
    end

    function Lobby.refreshAchievements()
        local A = Lobby.A
        local p = Profile.data
        local _, earnedPoints = Profile.points()
        local totalPoints, earnedCount = 0, 0
        for _, a in ipairs(ACHIEVEMENTS) do
            totalPoints = totalPoints + a.points
            if p.ach[a.key] then
                earnedCount = earnedCount + 1
            end
        end
        BlzFrameSetText(A.points, U.col(GOLD, tostring(earnedPoints)))
        BlzFrameSetText(A.pointsSub, U.col(GREY, 'of ' .. totalPoints .. ' points'))
        UI.setBar(A.progress, earnedPoints / math.max(1, totalPoints))
        BlzFrameSetText(A.count, earnedCount .. U.col(GREY, ' of ' .. #ACHIEVEMENTS .. ' earned'))
        local pages = math.ceil(#ACHIEVEMENTS / ACH_PER_PAGE)
        BlzFrameSetText(A.pageText, A.page .. ' / ' .. pages)
        UI.setEnabled(A.prev, A.page > 1)
        UI.setEnabled(A.next, A.page < pages)
        for i, o in ipairs(A.cells) do
            local a = ACHIEVEMENTS[(A.page - 1) * ACH_PER_PAGE + i]
            local visible = a ~= nil
            for _, f in ipairs({o.name, o.desc, o.barText, o.points, o.bar.back, o.bar.fill, o.bar.edge, o.bar.text}) do
                BlzFrameSetVisible(f, visible)
            end
            for _, f in ipairs(o.edge) do
                BlzFrameSetVisible(f, visible)
            end
            UI.showIcon(o.icon, visible)
            if a then
                local earned = p.ach[a.key] ~= nil
                local current, goal = a.progress(p)
                current = math.min(current, goal)
                UI.setIcon(o.icon, U.icon(a.code, a.icon), not earned)
                UI.frameColor(o.icon, earned and 214 or 70, earned and 170 or 60, earned and 90 or 50)
                BlzFrameSetText(o.name, earned and U.col(GOLD, a.name) or a.name)
                BlzFrameSetText(o.desc, U.col(GREY, a.desc))
                UI.setBar(o.bar, current / goal)
                BlzFrameSetText(o.barText, U.col(GREY, U.big(current) .. '/' .. U.big(goal)))
                BlzFrameSetText(o.points, earned and U.col(GOLD, tostring(a.points)) or U.col('6e665c', tostring(a.points)))
                UI.edgeTint(o.edge, earned and 214 or 110, earned and 170 or 84, earned and 90 or 46, 255)
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Rewards tab: perks bought with achievement points
    ---------------------------------------------------------------------------
    function Lobby.buildRewards(page)
        local W = {rows = {}}
        Lobby.W = W
        local sx, sw
        W.points, sx, sw = summaryPanel(page, 'REWARDS', 'Perks belong to the account: every hero of every faction has them. Earn achievements for more points.')
        W.sub = UI.text(page, '', sx, LAY.top - 0.098, sw, 0.03, 0.008, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP)
        W.reset = UI.button(page, sx + 0.01, LAY.top - 0.142, sw - 0.02, 0.028, 'Reset perks', function()
            Profile.data.perks = {}
            Profile.save()
            Lobby.refresh()
        end, 'dark', 0.0088)

        local lx, cw = listPanel(page, 'PERKS')
        for i, perk in ipairs(PERKS) do
            local column = math.fmod(i - 1, 2)
            local row = (i - 1) // 2
            local x = lx + column * (cw + LAY.gap)
            local top = LAY.top - 0.046 - row * 0.072
            local o = {}
            well(page, x, top, cw, 0.066)
            o.icon = UI.icon(page, U.icon(perk.code, perk.icon), x + 0.01, top - 0.01, 0.034)
            local textW = cw - 0.054 - 0.01
            o.name = UI.text(page, '', x + 0.054, top - 0.006, textW - 0.08, 0.015, 0.0096)
            o.rank = UI.text(page, '', x + cw - 0.09, top - 0.006, 0.08, 0.015, 0.0072, TEXT_JUSTIFY_RIGHT)
            o.desc = UI.text(page, U.col('d8cfc0', perk.desc), x + 0.054, top - 0.021, textW, 0.022, 0.0072, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
            local key = perk.key
            o.buy = UI.button(page, x + cw - 0.1, top - 0.042, 0.09, 0.02, '', function()
                Lobby.buyPerk(key)
            end, 'green', 0.0082)
            W.rows[i] = o
        end
    end

    function Lobby.buyPerk(key)
        local perk = PERK_BY_KEY[key]
        local rank = Profile.perk(key)
        local cost = perk.costs[rank + 1]
        if cost and Profile.points() >= cost then
            Profile.data.perks[key] = rank + 1
            Profile.save()
            Lobby.refresh()
        end
    end

    function Lobby.refreshRewards()
        local W = Lobby.W
        local free, earned, spent = Profile.points()
        BlzFrameSetText(W.points, U.col(GOLD, tostring(free)))
        BlzFrameSetText(W.sub, U.col(GREY, 'points to spend\n' .. earned .. ' earned  -  ' .. spent .. ' spent'))
        for i, perk in ipairs(PERKS) do
            local o = W.rows[i]
            local rank = Profile.perk(perk.key)
            BlzFrameSetText(o.name, rank > 0 and U.col(GOLD, perk.name) or perk.name)
            BlzFrameSetText(o.rank, U.col(GREY, 'Rank ' .. rank .. ' / ' .. #perk.costs))
            local cost = perk.costs[rank + 1]
            if cost then
                UI.setLabel(o.buy, 'Buy  ' .. U.col(GOLD, cost .. ' pts'))
                UI.setEnabled(o.buy, free >= cost)
            else
                UI.setLabel(o.buy, 'Max rank')
                UI.setEnabled(o.buy, false)
            end
            UI.setIcon(o.icon, U.icon(perk.code, perk.icon), rank == 0)
        end
    end

    ---------------------------------------------------------------------------
    -- Keyboard shortcuts (cards, reroll, play, menu). The hero moves with the
    -- mouse only: it walks to the last right-click.
    ---------------------------------------------------------------------------
    local KEY_HANDLES = {}

    -- Keys go through the bindings (Keys.actionOf); Escape always opens the
    -- menu. While a binding waits (Options > Keybinds), the next key pressed
    -- becomes its key.
    function G.onKey()
        local key = BlzGetTriggerPlayerKey()
        local down = BlzGetTriggerPlayerIsKeyDown()
        local code = nil
        for _, entry in ipairs(KEY_HANDLES) do
            if key == entry[1] then
                code = entry[2]
                break
            end
        end
        if code == nil then
            return
        end
        -- Holding a key repeats key-down events; act only on the press.
        local pressed = down and not S.down[code]
        S.down[code] = down
        local meta = BlzGetTriggerPlayerMetaKey() or 0
        local combo = code + META_STEP * meta
        if Options.waiting then
            if pressed then
                Options.capture(combo)
            end
            return
        end
        if code == KEY_ESCAPE then
            if pressed then
                G.onAction('menu')
            end
            return
        end
        local name = Keys.actionOf and Keys.actionOf[combo]
        -- Movement keys keep walking while Shift or Ctrl is held.
        if name == nil and meta ~= 0 then
            local plain = Keys.actionOf and Keys.actionOf[code]
            if plain and ACTION_BY_KEY[plain].dx then
                name = plain
            end
        end
        if name then
            S.keys[name] = down
            if pressed then
                G.onAction(name)
            end
        end
    end

    -- A right-click order on the hero: its native move is cancelled (the
    -- script moves the hero) and the clicked point becomes the walk target.
    function G.onOrder(onTarget)
        if R == nil or R.ended or GetTriggerUnit() ~= R.hero then
            return
        end
        R.cancelOrder = true
        if Keys.wasd() then
            -- Keyboard movement: right-clicks do not walk.
            return
        end
        local x, y
        -- A click on a unit, a tree, a doodad or an item walks to it. A target
        -- order has no point: reading one gave (0, 0), the middle of the map,
        -- and pulled the hero back toward the spawn.
        if onTarget then
            local target = GetOrderTarget()
            if target then
                x, y = GetWidgetX(target), GetWidgetY(target)
            end
        else
            x, y = GetOrderPointX(), GetOrderPointY()
        end
        if type(x) == 'number' and type(y) == 'number' then
            R.clickX = U.clamp(x, G.minX, G.maxX)
            R.clickY = U.clamp(y, G.minY, G.maxY)
        end
    end

    function G.onAction(name)
        -- The difficulty window takes Escape and keeps Space from starting a run behind it.
        local difficultyOpen = Lobby.D and Lobby.D.open and not Options.open
        -- The update window takes Escape as Later (not while downloading).
        if Updater.open then
            if name == 'menu' and Updater.state == 'offer' then
                Updater.later()
            end
            return
        end
        if name == 'menu' then
            if difficultyOpen then
                Lobby.closeDifficulty()
            else
                Options.toggle()
            end
            return
        end
        if Options.open or difficultyOpen then
            return
        end
        if name == 'stats' then
            Hud.toggleStats()
            return
        end
        if name:sub(1, 5) == 'spell' then
            G.castSpell(tonumber(name:sub(6)))
            return
        end
        if name:sub(1, 4) == 'auto' then
            G.toggleSpell(tonumber(name:sub(5)))
            return
        end
        if R and R.hand then
            if name == 'reroll' then
                Cards.rerollHand()
            elseif name:sub(1, 4) == 'card' then
                Cards.pick(tonumber(name:sub(5)))
            end
        elseif R == nil and S.screen == 'lobby' and S.tab == 'character' and name == 'play' then
            Lobby.enter()
        end
    end

    function G.registerKeys()
        local trigger = CreateTrigger()
        KEY_HANDLES = {}
        -- Reforged fires a key event only for the exact modifiers it was
        -- registered with: every key is registered plain, with Shift and with Ctrl.
        for _, entry in ipairs(KEY_LIST) do
            local handle = _G['OSKEY_' .. entry[1]]
            if handle then
                KEY_HANDLES[#KEY_HANDLES + 1] = {handle, entry[2]}
                for _, meta in ipairs(META_KEYS) do
                    BlzTriggerRegisterPlayerKeyEvent(trigger, G.PLAYER, handle, meta, true)
                    BlzTriggerRegisterPlayerKeyEvent(trigger, G.PLAYER, handle, meta, false)
                end
            end
        end
        TriggerAddAction(trigger, function()
            UI.safe(G.onKey)
        end)

        local pointOrders = CreateTrigger()
        TriggerRegisterPlayerUnitEvent(pointOrders, G.PLAYER, EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER, nil)
        TriggerAddAction(pointOrders, function()
            UI.safe(G.onOrder, false)
        end)
        local targetOrders = CreateTrigger()
        TriggerRegisterPlayerUnitEvent(targetOrders, G.PLAYER, EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
        TriggerAddAction(targetOrders, function()
            UI.safe(G.onOrder, true)
        end)
    end

    ---------------------------------------------------------------------------
    -- Boot
    ---------------------------------------------------------------------------
    function G.boot()
        G.initWorld()
        UI.init()
        Profile.load()
        if #Profile.checkAchievements() > 0 then
            Profile.save()
        end
        Keys.rebuild()
        Options.apply()
        if ZONES[S.zone].rank > Profile.data.unlocked then
            S.zone = ZONE_ORDER[Profile.data.unlocked]
        end

        -- Hide the default console and let the world fill the whole screen.
        BlzHideOriginFrames(true)
        BlzFrameSetAllPoints(BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0))
        local consoleBackdrop = BlzGetFrameByName('ConsoleUIBackdrop', 0)
        if consoleBackdrop then
            BlzFrameSetVisible(consoleBackdrop, false)
        end
        local resourceBar = BlzGetFrameByName('ResourceBarFrame', 0)
        if resourceBar then
            BlzFrameSetVisible(resourceBar, false)
        end
        EnableSelect(false, false)
        ClearTextMessages()
        -- Standalone engine: F1-F11 keep none of their melee binds (hero
        -- select, quick save, the stock game menu, quests, allies).
        if Engine.active() then
            EngineCvar('cl_fkeys', '0')
            -- Holding the right button (or a finger on the ground, on a touch
            -- screen) keeps sending the point under it: the hero follows.
            EngineCvar('cl_smart_hold', '1')
            EngineCvar('cl_touch_smart', '1')
        end

        Hud.build()
        Cards.build()
        Finale.build()
        Lobby.build()
        Options.build()
        Updater.build()

        local damage = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(damage, EVENT_PLAYER_UNIT_DAMAGED)
        TriggerAddAction(damage, function()
            UI.safe(G.onDamage)
        end)
        local death = CreateTrigger()
        TriggerRegisterPlayerUnitEvent(death, G.ENEMY, EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerRegisterPlayerUnitEvent(death, G.PLAYER, EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerAddAction(death, function()
            UI.safe(G.onDeath)
        end)
        G.registerKeys()

        TimerStart(CreateTimer(), CFG.TICK, true, function()
            UI.safe(G.tick)
        end)
        local gearAid = ''
        if Engine.active() then
            -- Camera input stays with the script: the lobby holds the showcase
            -- and the run follows the hero. Clicks and keys still arrive.
            EnableUserControl(false)
            -- Test runs can open a lobby tab directly: +set survivor_tab codex
            local tab = EngineCvar('survivor_tab')
            if Lobby.pages[tab] then
                S.tab = tab
            end
            -- +set survivor_gear "ofro desc clfm" loots every item at its base
            -- level and carries the ones named (rawcodes), the first selected.
            gearAid = tostring(EngineCvar('survivor_gear') or '')
            if gearAid ~= '' then
                local p = Profile.data
                p.inv = {}
                for _, item in ipairs(GEAR) do
                    p.gear[item.id] = item.baseIlvl
                end
                for code in gearAid:gmatch('[a-z0-9]+') do
                    for _, item in ipairs(GEAR) do
                        if item.code == code and gearSlotOf(p, item) == nil then
                            local slot = 1
                            while p.inv[tostring(slot)] do
                                slot = slot + 1
                            end
                            if slot <= INVENTORY_SIZE then
                                p.inv[tostring(slot)] = item.index
                            end
                        end
                    end
                end
            end
        end
        if Engine.takeRun() then
            G.inArena = true
            G.startRun()
        else
            Lobby.show()
            local first = gearEquipped(Profile.data)[1]
            if gearAid ~= '' and Lobby.K and first then
                Lobby.selectItem(first)
            end
        end
        if Engine.active() then
            -- Test runs can open an options page directly: +set survivor_menu keys
            local page = EngineCvar('survivor_menu')
            if Options.pages[page] then
                Options.show()
                Options.setPage(page)
            elseif page == 'difficulty' and S.screen == 'lobby' then
                -- +set survivor_menu difficulty opens the difficulty window.
                Lobby.openDifficulty()
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Standalone engine (engine/, see CLAUDE.md). engine_boot.lua sets
    -- SURVIVOR_ENGINE; the engine adds EngineCvar. The menu runs on a quiet
    -- map load, and entering a zone loads that zone's own map behind a
    -- loading screen. Console variables outlive the map change, so they carry
    -- the chosen run; the profile is saved to disk in between.
    ---------------------------------------------------------------------------
    -- rawget: unknown globals fall back to natives in the engine (and to stubs in the smoke test).
    function Engine.active()
        local config = rawget(_G, 'SURVIVOR_ENGINE')
        return type(config) == 'table' and config.menu ~= nil and type(rawget(_G, 'EngineCvar')) == 'function'
    end

    -- The browser build (port/web/site/survivor.js sets survivor_web 1).
    function Engine.web()
        return Engine.active() and EngineCvar('survivor_web') == '1'
    end

    -- A phone or tablet (survivor.js: a finger is the main pointer).
    function Engine.touch()
        return Engine.web() and EngineCvar('survivor_touch') == '1'
    end

    function Engine.loadingScreen(zone, background)
        EngineCvar('wc3_loading_quiet', zone and '0' or '1')
        EngineCvar('wc3_loading_title', zone and zone.name or '')
        EngineCvar('wc3_loading_subtitle', zone and zone.subtitle or '')
        EngineCvar('wc3_loading_text', zone and zone.desc or '')
        EngineCvar('wc3_loading_background', zone and tostring(background) or '')
    end

    function Engine.enterZone()
        local arenas = SURVIVOR_ENGINE.arenas
        local arena = arenas[S.zone] or arenas[1]
        EngineCvar('survivor_run', S.heroIndex .. ' ' .. S.zone .. ' ' .. S.difficulty .. ' ' .. S.keyLevel)
        Engine.loadingScreen(ZONES[S.zone], arena.loading)
        Profile.save()
        ChangeLevel(arena.map, false)
    end

    function Engine.returnToMenu()
        EngineCvar('survivor_run', '')
        Engine.loadingScreen(nil)
        Profile.save()
        ChangeLevel(SURVIVOR_ENGINE.menu, false)
    end

    -- On a zone map: take the run chosen in the menu (once), or nil.
    function Engine.takeRun()
        if not Engine.active() then
            return nil
        end
        local text = EngineCvar('survivor_run')
        EngineCvar('survivor_run', '')
        local hero, zone, difficulty, key = text:match('^(\037d+) (\037d+) (\037d+) (\037d+)$')
        if hero == nil or HEROES[tonumber(hero)] == nil or ZONES[tonumber(zone)] == nil then
            return nil
        end
        S.heroIndex, S.zone = tonumber(hero), tonumber(zone)
        S.difficulty, S.keyLevel = tonumber(difficulty), tonumber(key)
        S.faction = HEROES[S.heroIndex].faction
        return true
    end

    ---------------------------------------------------------------------------
    -- Updater (portable Windows build only). The launcher
    -- (tools/release/warcraft_survivors_launcher.cs) starts the engine with
    -- +set survivor_updater <token>, checks the uploaded release in the
    -- background and talks to the game through preload files under
    -- CustomMapData\WarcraftSurvivors\Update: info.pld (a newer version, its
    -- notes and download size, or state 'none'), request.pld (written here by
    -- Download & restart) and progress.pld (the download, then ready or error).
    -- Each file carries the token, so a file left by another session is
    -- ignored. Once the files are in, the game quits and the launcher swaps
    -- them and starts the new version.
    ---------------------------------------------------------------------------
    local UPDATE_DIR = 'WarcraftSurvivors\\Update\\'
    local UW = {x = 0.22, top = 0.43, w = 0.36, h = 0.2}

    function Updater.enabled()
        return Engine.active() and not Engine.web() and (EngineCvar('survivor_updater') or '') ~= ''
    end

    -- Runs one of the launcher's files; its Lua block sets a global table.
    function Updater.read(file, global)
        rawset(_G, global, nil)
        Preloader(UPDATE_DIR .. file)
        local t = rawget(_G, global)
        if type(t) == 'table' and t.token == Updater.token then
            return t
        end
        return nil
    end

    function Updater.mb(bytes)
        return string.format('\037.1f MB', (bytes or 0) / 1048576)
    end

    function Updater.build()
        if not Updater.enabled() then
            return
        end
        Updater.token = EngineCvar('survivor_updater')
        Updater.attempt = 0
        local W = {}
        Updater.W = W
        local group = UI.group(UI.game)
        BlzFrameSetLevel(group, 10)
        W.group = group
        UI.box(group, -0.3, 0.6, 1.4, 0.6, 0, 0, 0, 170)
        BlzFrameSetLevel(UI.hit(group, -0.3, 0.6, 1.4, 0.6), 0)
        local x, T, w = UW.x, UW.top, UW.w
        UI.card(group, x, T, w, UW.h)
        local ix, iw = x + 0.024, w - 0.048
        W.title = UI.text(group, '', x, T - 0.02, w, 0.03, 0.019, TEXT_JUSTIFY_CENTER)
        W.versions = UI.text(group, '', x, T - 0.052, w, 0.02, 0.012, TEXT_JUSTIFY_CENTER)
        W.notes = UI.text(group, '', ix, T - 0.08, iw, 0.05, 0.0088, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP)
        W.size = UI.text(group, '', ix, T - 0.132, iw, 0.014, 0.0078, TEXT_JUSTIFY_CENTER)
        W.download = UI.button(group, 0.29, T - 0.152, 0.14, 0.032, U.col(GOLD, 'Download & restart'), function()
            Updater.download()
        end, 'red', 0.0105)
        W.later = UI.button(group, 0.44, T - 0.152, 0.07, 0.032, U.col(GOLD, 'Later'), function()
            Updater.later()
        end, 'dark', 0.0105)
        W.percent = UI.text(group, '', x, T - 0.078, w, 0.026, 0.016, TEXT_JUSTIFY_CENTER)
        W.bar = UI.bar(group, ix + 0.01, T - 0.116, iw - 0.02, 0.012, 255, 196, 64)
        W.detail = UI.text(group, '', ix, T - 0.142, iw, 0.014, 0.0078, TEXT_JUSTIFY_CENTER)
        BlzFrameSetVisible(group, false)
        TimerStart(CreateTimer(), 0.25, true, function()
            UI.safe(Updater.poll)
        end)
    end

    -- offer: notes and the two buttons; progress: percent and bar.
    function Updater.setMode(mode)
        local W = Updater.W
        local offer = mode == 'offer'
        BlzFrameSetVisible(W.notes, offer)
        BlzFrameSetVisible(W.size, offer)
        UI.showButton(W.download, offer)
        UI.showButton(W.later, offer)
        for _, f in ipairs({W.percent, W.detail, W.bar.back, W.bar.fill, W.bar.edge, W.bar.text}) do
            BlzFrameSetVisible(f, not offer)
        end
    end

    function Updater.offer(errorText)
        local W, info = Updater.W, Updater.info
        Updater.setMode('offer')
        BlzFrameSetText(W.title, U.col(GOLD, errorText and 'The download failed' or 'A new version is out!'))
        BlzFrameSetText(W.versions, U.col('d8cfc0', 'v' .. tostring(SURVIVOR_ENGINE.version or '?')) .. '   '
            .. U.col(GOLD, '>') .. '   ' .. U.col(GREEN, 'v' .. tostring(info.version)))
        BlzFrameSetText(W.notes, errorText and U.col(RED, errorText) or U.col('ffffff', tostring(info.notes or '')))
        local files = tonumber(info.files) or 0
        BlzFrameSetText(W.size, U.col(GREY, Updater.mb(info.size) .. ' download (' .. files
            .. (files == 1 and ' file' or ' files') .. ')  -  the game restarts when it is done'))
        UI.setLabel(W.download, U.col(GOLD, errorText and 'Retry' or 'Download & restart'))
    end

    function Updater.show()
        Updater.open = true
        Updater.state = 'offer'
        UI.showButton(Lobby.updateButton, false)
        Updater.offer()
        BlzFrameSetVisible(Updater.W.group, true)
        -- Test aid: +set survivor_update_auto 1 presses Download & restart.
        if EngineCvar('survivor_update_auto') == '1' then
            Updater.download()
        end
    end

    -- Later: the lobby keeps an Update button; the choice outlives the map
    -- change of a run (a console variable), so the window does not come back.
    function Updater.later()
        EngineCvar('survivor_update_later', tostring(Updater.info.version))
        Updater.open = false
        Updater.state = 'later'
        BlzFrameSetVisible(Updater.W.group, false)
        UI.showButton(Lobby.updateButton, true)
    end

    function Updater.download()
        local W = Updater.W
        Updater.attempt = Updater.attempt + 1
        PreloadGenClear()
        Preload(Updater.token .. ' ' .. Updater.attempt)
        PreloadGenEnd(UPDATE_DIR .. 'request.pld')
        Updater.state = 'downloading'
        Updater.setMode('progress')
        BlzFrameSetText(W.title, U.col(GOLD, 'Downloading'))
        BlzFrameSetText(W.percent, U.col('ffffff', '0\037'))
        BlzFrameSetText(W.detail, U.col(GREY, 'Starting...'))
        UI.setBar(W.bar, 0)
    end

    function Updater.progress(p)
        local W = Updater.W
        if p.state == 'ready' then
            Updater.state = 'restarting'
            BlzFrameSetText(W.title, U.col(GOLD, 'Restarting'))
            BlzFrameSetText(W.percent, U.col('ffffff', '100\037'))
            BlzFrameSetText(W.detail, U.col(GREY, 'Installing v' .. tostring(Updater.info.version) .. '...'))
            UI.setBar(W.bar, 1)
            Profile.save()
            TimerStart(CreateTimer(), 0.6, false, function()
                UI.safe(rawget(_G, 'EngineQuit'))
            end)
        elseif p.state == 'error' then
            Updater.state = 'offer'
            Updater.offer(tostring(p.error or 'Unknown error'))
        else
            local total = math.max(1, tonumber(p.total) or 1)
            local done = math.min(total, tonumber(p.done) or 0)
            local speed = tonumber(p.speed) or 0
            BlzFrameSetText(W.percent, U.col('ffffff', math.floor(100 * done / total) .. '\037'))
            local detail = Updater.mb(done) .. ' of ' .. Updater.mb(total)
            if speed > 0 then
                detail = detail .. '  -  ' .. Updater.mb(speed) .. '/s  -  '
                    .. math.ceil((total - done) / speed) .. 's left'
            end
            BlzFrameSetText(W.detail, U.col(GREY, detail))
            UI.setBar(W.bar, done / total)
        end
    end

    -- Lobby only: runs play on other maps, and the menu map reboots the script.
    function Updater.poll()
        if S.screen ~= 'lobby' or R ~= nil then
            return
        end
        Updater.clock = (Updater.clock or 0) + 1
        if Updater.state == nil then
            -- Once a second until the launcher has checked.
            if math.fmod(Updater.clock, 4) ~= 1 then
                return
            end
            local info = Updater.read('info.pld', 'SurvivorUpdateInfo')
            if info == nil then
                return
            end
            Updater.info = info
            if info.state ~= 'update' or info.version == nil then
                Updater.state = 'none'
            elseif EngineCvar('survivor_update_later') == tostring(info.version) then
                Updater.state = 'later'
                UI.showButton(Lobby.updateButton, true)
            else
                Updater.show()
            end
        elseif Updater.state == 'downloading' then
            local p = Updater.read('progress.pld', 'SurvivorUpdateProgress')
            if p and tonumber(p.attempt) == Updater.attempt then
                Updater.progress(p)
            end
        end
    end

    -- Entry point: call Survivor_Start() from a Map Initialization trigger.
    function Survivor_Start()
        TimerStart(CreateTimer(), 0.0, false, function()
            DestroyTimer(GetExpiredTimer())
            UI.safe(G.boot)
        end)
    end
end
