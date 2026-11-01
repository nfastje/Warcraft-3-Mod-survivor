-- Balance report: plays heroes on a fresh profile (no talents, no gear) and
-- prints, minute by minute, what the run looks like. Run it with
--   python tools/smoketest/run.py --balance [zone] [difficulty] [hero ids...]
-- The mock has no unit AI, so this file plays the enemies: they walk at
-- their own speed (slows and stuns hold them), and a melee enemy in reach
-- hits every 1.5 s for its damage after the hero's armor. The hero kites
-- away from the nearest pack and picks random cards. A hit that would kill
-- the hero counts a death and refills its health, so the run goes on.
math.randomseed(11)

local function upvalue(fn, name)
    for i = 1, 200 do
        local n, v = debug.getupvalue(fn, i)
        if n == nil then return nil end
        if n == name then return v end
    end
end

Survivor_Start()
MOCK.advance(0.1)
local G = upvalue(Survivor_Start, 'G')
local function R() return upvalue(G.tick, 'R') end
local S = upvalue(G.startRun, 'S')
local HEROES = upvalue(G.startRun, 'HEROES')
local CFG = upvalue(G.learnSpell, 'CFG')
local CTRL = 2
-- Players turn autocast on for the spells they keep; the report does it for all.
CFG.AUTOCAST = true


local args = BALANCE_ARGS or {}
local zone = tonumber(args[1]) or 1
local difficulty = tonumber(args[2]) or 1
-- "geared" among the hero ids: every talent at its last rank and six late
-- items carried at their base item level, as a profile that has played a while.
local ids, geared = {}, false
for i = 3, #args do
    if args[i] == 'geared' then geared = true else ids[#ids + 1] = args[i] end
end
if geared then
    local Profile = upvalue(G.endRun, 'Profile')
    for _, talent in ipairs(upvalue(Profile.applyBonuses, 'TALENTS')) do
        Profile.data.talents[talent.key] = talent.max
    end
    local GEAR = upvalue(Profile.load, 'GEAR')
    local slot = 0
    for _, code in ipairs({'ckng', 'hval', 'rhth', 'srbd', 'ofir', 'ankh'}) do
        for _, item in ipairs(GEAR) do
            if item.code == code then
                slot = slot + 1
                Profile.data.gear[item.id] = item.baseIlvl
                Profile.data.inv[tostring(slot)] = item.index
            end
        end
    end
end
if #ids == 0 then ids = {'Hamg', 'Obla', 'Udea', 'Edem'} end

-- Enemy health spawned, summed by createEnemy.
local spawnedHp = 0
local createEnemy = G.createEnemy
G.createEnemy = function(...)
    local u, info = createEnemy(...)
    if u then spawnedHp = spawnedHp + BlzGetUnitMaxHP(u) end
    return u, info
end

-- Any hit on the hero (boss slams too) that would kill it counts a death and
-- refills its health instead: a buffer of health goes on for the hit.
local deathAt, firstKiller = nil, nil
local realDamage = UnitDamageTarget
function UnitDamageTarget(src, target, amount, ...)
    local run = R()
    if run == nil or target ~= run.hero then
        return realDamage(src, target, amount, ...)
    end
    target.life = target.life + 1e6
    local result = realDamage(src, target, amount, ...)
    target.life = target.life - 1e6
    if target.life <= 1 then
        local info = run.enemies[src]
        if deathAt == nil or #deathAt == 0 then
            firstKiller = string.format('%s%s for %.0f', tostring(src and src.id), info and info.boss and ' (boss)' or '',
                amount)
        end
        target.life = target.maxHp
        deathAt = deathAt or {}
        deathAt[#deathAt + 1] = run.time
    end
    return result
end

local function armorFactor(a)
    if a >= 0 then return 1 - 0.06 * a / (1 + 0.06 * a) end
    return 2 - 0.94 ^ -a
end

local out = {}
local function line(s) out[#out + 1] = s end

local function playHero(index, quiet)
    local function row(s) if not quiet then line(s) end end
    S.heroIndex, S.zone, S.difficulty, S.keyLevel = index, zone, difficulty, 2
    G.startRun()
    local run = R()
    local hero = run.hero
    local nextHit = {}
    deathAt = {}
    local minute, lastDone, lastTaken, lastHp, lastKills = 1, 0, 0, 0, 0
    spawnedHp = 0
    local manaSum, manaN, waitSum = 0, 0, 0
    row(string.format('%s in %s (%s)', run.def.name, run.zone.name, run.diff.name))
    row(' min  lvl  kills  alive  enemy hp/s   dps  taken/s  mana  spells waiting  deaths')
    local t = 0
    while t < CFG.RUN_LENGTH + 90 do
        MOCK.advance(0.25)
        t = t + 0.25
        run = R()
        if run == nil or run.ended then break end
        if run.hand then
            -- A focused player: ranks the spell that deals the most damage,
            -- fills empty slots, then other ranks, then damage stats.
            local topKey, topDone = nil, -1
            for key, amount in pairs(run.meter) do
                if run.spellByKey[key] and amount > topDone then topKey, topDone = key, amount end
            end
            local best, bestScore = 1, -1
            for i, c in ipairs(run.hand.cards) do
                local score = 1 + math.random() * 0.5
                if c.type == 'spell' then
                    if c.key == topKey then score = 5
                    elseif not run.spellByKey[c.key] then score = 4
                    else score = 2.5 end
                elseif c.key == 'might' or c.key == 'haste' or c.key == 'reach' or c.key == 'persistence' then
                    score = 2
                end
                score = score + (c.rarity or 1) * 0.2
                if score > bestScore then best, bestScore = i, score end
            end
            MOCK.tap(({OSKEY_1, OSKEY_2, OSKEY_3, OSKEY_4})[best], CTRL)
        end
        -- Enemies walk and hit.
        local cx, cy, near, close = 0, 0, 0, 0
        for u, info in pairs(run.enemies) do
            local dx, dy = run.hx - u.x, run.hy - u.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d < 600 then
                cx, cy, near = cx + u.x, cy + u.y, near + 1
            end
            if d < 350 then
                close = close + 1
            end
            if not info.stunned and not info.casting then
                local reach = info.boss and 140 or 100
                if d > reach then
                    local step = info.speed * (1 - info.slowPct) * 0.25
                    u.x, u.y = u.x + dx / d * math.min(step, d - reach), u.y + dy / d * math.min(step, d - reach)
                elseif run.time >= (nextHit[u] or 0) then
                    nextHit[u] = run.time + 1.5
                    local amount = (u.damage or 1) * armorFactor(run.stats.armor)
                    UnitDamageTarget(u, hero, amount, true, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                end
            end
        end
        -- Kite: every half second, walk away from the pack close by; with
        -- nothing close, go for the nearest gem, coin or chest.
        if t % 0.5 == 0 then
            local tx, ty
            local best, bestD = nil, 1000 * 1000
            -- A few enemies close by do not stop a player from sweeping gems (up
            -- to 700 away then); a pack does.
            if close <= 2 then
                bestD = close == 0 and 1000 * 1000 or 700 * 700
                for _, p in ipairs(run.pickups) do
                    local dx, dy = p.x - run.hx, p.y - run.hy
                    if dx * dx + dy * dy < bestD then best, bestD = p, dx * dx + dy * dy end
                end
            end
            if best then
                tx, ty = best.x, best.y
            elseif near > 0 then
                local ax, ay = run.hx - cx / near, run.hy - cy / near
                local d = math.max(1, math.sqrt(ax * ax + ay * ay))
                tx, ty = run.hx + ax / d * 400, run.hy + ay / d * 400
            else
                tx, ty = run.hx + math.cos(t / 7) * 400, run.hy + math.sin(t / 7) * 400
            end
            -- Near a wall, turn along it.
            tx = math.max(G.minX + 200, math.min(G.maxX - 200, tx))
            ty = math.max(G.minY + 200, math.min(G.maxY - 200, ty))
            MOCK.order(hero, tx, ty)
        end
        manaSum, manaN = manaSum + run.mana / math.max(1, run.maxMana), manaN + 1
        for _, inst in ipairs(run.spells) do
            if inst.waiting then waitSum = waitSum + 1 end
        end
        if run.time >= minute * 60 then
            row(string.format('%4d  %3d  %5d  %5d  %10.0f  %5.0f  %7.1f  %3.0f%%  %14.1f  %6d', minute, run.level, run.kills,
                run.enemyCount, (spawnedHp - lastHp) / 60, (run.damageDone - lastDone) / 60,
                (run.damageTaken - lastTaken) / 60, manaSum / manaN * 100, waitSum / manaN, #deathAt))
            lastHp, lastDone, lastTaken, lastKills = spawnedHp, run.damageDone, run.damageTaken, run.kills
            manaSum, manaN, waitSum = 0, 0, 0
            minute = minute + 1
        end
    end
    run = R()
    local summary = string.format('  => level %d, %d kills, %d deaths (first at %s), %s', run.level, run.kills, #deathAt,
        deathAt[1] and string.format('%d:%02d', math.floor(deathAt[1] / 60), math.floor(deathAt[1]) % 60) or 'never',
        run.ended and (run.victory and 'won' or 'lost') or 'unfinished at ' .. math.floor(run.time) .. ' s')
    row(summary .. (firstKiller and ', killed by ' .. firstKiller or ''))
    firstKiller = nil
    -- What the hero ended with: spells (rank, power), stat cards, damage by source.
    local parts = {}
    for _, inst in ipairs(run.spells) do
        parts[#parts + 1] = string.format('%s r%d x%.2f (%d mana / %.1f s)', inst.def.key, inst.rank, inst.power,
            inst.v.mana or 0, inst.v.cd or 0)
    end
    row(string.format('  mana: pool %.0f, %.1f per second', run.maxMana, run.stats.manaRegen))
    row('  spells: ' .. table.concat(parts, ', '))
    parts = {}
    for key, b in pairs(run.blessings) do
        parts[#parts + 1] = string.format('%s %d', key, b.rank or 0)
    end
    table.sort(parts)
    row('  cards: ' .. table.concat(parts, ', '))
    local s = run.stats
    row(string.format('  stats: damage +%.0f%%  spell power x%.2f  attack %.0f  crit %.0f%% x%.2f  cdr %.0f%%  area +%.0f%%  hands %d',
        s.damage * 100, s.spellPower, s.attackDamage, s.crit * 100, s.critMult, s.cdr * 100, s.area * 100, run.handsDealt))
    parts = {}
    for key, amount in pairs(run.meter) do parts[#parts + 1] = {key, amount} end
    table.sort(parts, function(a, b) return a[2] > b[2] end)
    local top = {}
    for i = 1, math.min(5, #parts) do
        top[#top + 1] = string.format('%s %.0f%%', parts[i][1], parts[i][2] / math.max(1, run.damageDone) * 100)
    end
    row('  damage: ' .. table.concat(top, ', '))
    row('')
    local result = {level = run.level, death = deathAt[1], deaths = #deathAt, won = run.ended and run.victory, time = run.time}
    if not run.ended then G.endRun(false) end
    MOCK.click('Return to Camp')
    return result
end

-- Each hero plays SEEDS runs: the first in full, the others summed up in
-- one line (first death, level at the end).
local SEEDS = 3
local function clock(t)
    return t and string.format('%d:%02d', math.floor(t / 60), math.floor(t) % 60) or 'never'
end
local summary = {}
for _, id in ipairs(ids) do
    for index, hero in ipairs(HEROES) do
        if hero.id == id then
            local deaths, levels = {}, {}
            for seed = 1, SEEDS do
                math.randomseed(10 + seed)
                local r = playHero(index, seed > 1)
                deaths[#deaths + 1] = clock(r.death)
                levels[#levels + 1] = r.level .. (r.time < CFG.RUN_LENGTH and ' (ended ' .. clock(r.time) .. ')' or '')
            end
            summary[#summary + 1] = string.format('%-18s first death %s   level %s', hero.name,
                table.concat(deaths, ' / '), table.concat(levels, ' / '))
        end
    end
end
line('Summary (' .. SEEDS .. ' runs each)')
for _, s in ipairs(summary) do line('  ' .. s) end
line('script errors: ' .. #MOCK.printed)
return table.concat(out, '\n')
