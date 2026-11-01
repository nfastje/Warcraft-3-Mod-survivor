-- Warcraft Survivors: entry point for the standalone engine (engine/).
--
-- The engine runs this after src/ashenvale_survivor.lua on top of an official
-- melee map (see CLAUDE.md, "Standalone engine"). The map keeps its own JASS
-- config, so players and start locations stay as Blizzard authored them; this
-- main replaces the map's melee main, so no town halls or melee rules start.
--
-- Same rule as the main script: never type a percent sign in this file.

-- The game starts on the menu map behind a quiet (black) load; entering a
-- zone loads its arena map behind a loading screen. loading is the row of
-- [LoadingScreens] in UI\WorldEditData.txt drawn behind the zone's text.
-- Each zone plays on an official melee map of its own tileset. The hero spawns
-- at the map's center, so an arena needs open, walkable ground there
-- (tools/engine_tests/test_arena_probe.lua rates a map).
SURVIVOR_ENGINE = {
    menu = 'Maps\\FrozenThrone\\(6)Moonglade.w3x',
    -- The browser lobby's Download button: the portable Windows build
    -- (tools/release/make_portable.ps1, zipped), uploaded beside the page.
    download = 'https://warcraftsurvivor.para-bellum.eu/download/WarcraftSurvivors.zip',
    -- This build's version and what is new in it. tools/release/portable_manifest.py
    -- copies both into the portable build's version.json; the portable launcher
    -- compares it with the one under update (the uploaded release) and the
    -- lobby offers the newer one (Updater). Raise the version for every release.
    version = '1.3.0',
    notes = 'New Tavern hero: Medivh, the Last Guardian (Arcane Barrage, Raven Form, Enchanted Crows, Dark Portal). Chests, shrines and treasure now lie in every zone: walk up to one to use it. Hold the right mouse button and your hero follows the cursor; on a phone or tablet, hold a finger on the ground. Enemies block your way as in Warcraft III. Blood splashes when you are hit. Transmute gives less gold.',
    update = 'https://warcraftsurvivor.para-bellum.eu/download/portable/',
    arenas = {
        [1] = {map = 'Maps\\FrozenThrone\\(6)Moonglade.w3x', loading = 34},   -- Ashenvale: Ashenvale tileset, Night Elf art
        [2] = {map = 'Maps\\FrozenThrone\\(2)TerenasStand.w3x', loading = 2}, -- Westfall: Village tileset (farms), Lordaeron art
        [3] = {map = 'Maps\\FrozenThrone\\(6)CopperCanyon.w3x', loading = 24}, -- The Barrens: Barrens tileset, Orc art
        [4] = {map = 'Maps\\(8)Plaguelands.w3m', loading = 67},               -- Plaguelands: blighted Felwood tileset, Scourge art
        [5] = {map = 'Maps\\(8)BloodvenomFalls.w3m', loading = 46},           -- Felwood: Felwood tileset, Night Elf TFT art
        [6] = {map = 'Maps\\(12)IceCrown.w3m', loading = 72},                 -- Northrend: Northrend tileset, Icecrown art
        [7] = {map = 'Maps\\(4)HarvestMoon.w3m', loading = 17},               -- Tirisfal Glades: Lordaeron Fall, Quel'Thalas art
        [8] = {map = 'Maps\\FrozenThrone\\(6)StranglethornVale.w3x', loading = 47}, -- Stranglethorn Vale: Sunken Ruins, Drowned Ruins art
        [9] = {map = 'Maps\\(4)Frostsabre.w3m', loading = 12},                -- Alterac Valley: Lordaeron Winter, Northrend art
        [10] = {map = 'Maps\\FrozenThrone\\(6)WizardsRetreat.w3x', loading = 22}, -- Dalaran: Dalaran tileset, Dalaran art
        [11] = {map = 'Maps\\FrozenThrone\\(4)DevilsCauldron.w3x', loading = 62}, -- Hellfire Peninsula: Outland, Outland art
        [12] = {map = 'Maps\\FrozenThrone\\(6)Demon\'sCrossing.w3x', loading = 65}, -- The Black Temple: Black Citadel, Outland art
    },
}

function main()
    InitBlizzard()

    -- Melee maps place creep camps; the survivor waves own the arena instead.
    local creeps = CreateGroup()
    GroupEnumUnitsOfPlayer(creeps, Player(PLAYER_NEUTRAL_AGGRESSIVE), nil)
    ForGroup(creeps, function()
        RemoveUnit(GetEnumUnit())
    end)
    DestroyGroup(creeps)

    Survivor_Start()
end
