-- Test aid (add-on): a hero run that cannot end (any unit of the player is
-- healed ten times a second, so plain units like Medivh stay alive too). Logs
-- MEDIVH lines every 0.5 s: time, the hero's position, the sequence it plays
-- and its upper-body clip, plus the enemy count. Every medivh_pack seconds
-- (default 8) six wolves appear next to the hero, so "when surrounded" spells
-- (Raven Form) fire. medivh_spawn "ogru nchg" adds one of each unit type for
-- the player at 2 s (summons a low rank never calls, for the web trace).
-- Quits after medivh_len seconds (default 40).
-- Run (Medivh = hero 25): +set survivor_run "25 1 1 2" +set survivor_autopick 1
--      +set survivor_spells "raven_form enchanted_crows dark_portal"
--      +set wc3_lua_script ".../ashenvale_survivor.lua,.../engine_boot.lua,.../test_medivh.lua"
local old = Survivor_Start
function Survivor_Start()
    old()
    local length = tonumber(EngineCvar('medivh_len')) or 40
    local packEvery = tonumber(EngineCvar('medivh_pack')) or 8
    local heroId = FourCC(EngineCvar('medivh_hero') ~= '' and EngineCvar('medivh_hero') or 'nmed')
    local enemy = Player(11)
    local elapsed = 0
    local function hero()
        local found = nil
        local g = CreateGroup()
        GroupEnumUnitsOfPlayer(g, Player(0), nil)
        ForGroup(g, function()
            if GetUnitTypeId(GetEnumUnit()) == heroId then
                found = GetEnumUnit()
            end
        end)
        DestroyGroup(g)
        return found
    end
    TimerStart(CreateTimer(), 0.1, true, function()
        local g = CreateGroup()
        GroupEnumUnitsOfPlayer(g, Player(0), nil)
        ForGroup(g, function()
            local u = GetEnumUnit()
            if GetWidgetLife(u) > 0.405 then
                SetWidgetLife(u, BlzGetUnitMaxHP(u))
            end
        end)
        DestroyGroup(g)
    end)
    TimerStart(CreateTimer(), 0.5, true, function()
        elapsed = elapsed + 0.5
        local h = hero()
        local enemies = 0
        local g = CreateGroup()
        GroupEnumUnitsOfPlayer(g, enemy, nil)
        ForGroup(g, function()
            if GetWidgetLife(GetEnumUnit()) > 0.405 then
                enemies = enemies + 1
            end
        end)
        DestroyGroup(g)
        if h and elapsed == 2 then
            for id in (EngineCvar('medivh_spawn') or ''):gmatch('[A-Za-z0-9]+') do
                local u = CreateUnit(Player(0), FourCC(id), GetUnitX(h) + 200, GetUnitY(h), 0)
                print('MEDIVH spawned ' .. id .. ' ' .. tostring(u ~= nil))
            end
        end
        if h then
            local anim, frame, upper = EngineUnitAnimation(h)
            print(string.format('MEDIVH t \0375.1f pos \0377.0f \0377.0f anim [\037s] \037d upper [\037s] enemies \037d',
                elapsed, GetUnitX(h), GetUnitY(h), anim, frame, upper, enemies))
            if math.fmod(elapsed, packEvery) == 3 then
                local x, y = GetUnitX(h), GetUnitY(h)
                for i = 1, 6 do
                    local a = i * 1.05
                    local u = CreateUnit(enemy, FourCC('nwlf'), x + math.cos(a) * 160, y + math.sin(a) * 160, 0)
                    if u then
                        IssueTargetOrder(u, 'attack', h)
                    end
                end
                print('MEDIVH pack of wolves at ' .. elapsed)
            end
        else
            print('MEDIVH t ' .. elapsed .. ' no hero')
        end
        if elapsed >= length then
            print('MEDIVH done')
            EngineQuit()
        end
    end)
end
