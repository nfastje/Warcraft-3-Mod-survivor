-- Plays the map script through the mock: lobby, tabs, runs on every
-- difficulty, level-ups, bosses, victory, defeat, saving and every hero.
math.randomseed(7)

local function upvalue(fn, name)
    for i = 1, 200 do
        local n, v = debug.getupvalue(fn, i)
        if n == nil then return nil end
        if n == name then return v end
    end
end

Survivor_Start()
MOCK.advance(0.1)
local UI = upvalue(Survivor_Start, 'UI')
local G = upvalue(Survivor_Start, 'G')
local function R() return upvalue(G.tick, 'R') end
local S = upvalue(G.startRun, 'S')
local HEROES = upvalue(G.startRun, 'HEROES')
local SPELLS = upvalue(G.learnSpell, 'SPELLS')
local Profile = upvalue(G.endRun, 'Profile')
assert(UI and G and S and HEROES and SPELLS and Profile, 'internals not found')
-- Cards are picked with Ctrl+1 to 4 (meta key 2). Spells start with
-- autocast off for players; the test's runs need them to cast on their own.
local CTRL = 2
upvalue(G.learnSpell, 'CFG').AUTOCAST = true

local realDamage = UnitDamageTarget
function UnitDamageTarget(src, target, amount, ...)
    local result = realDamage(src, target, amount, ...)
    if target.hero and target.owner == Player(0) and not target.alive and not target.reported then
        target.reported = true
        MOCK.heroDeath = string.format('hero killed by %s (%s) for %.0f, max hp %d', tostring(src.name), tostring(src.id), amount, target.maxHp)
    end
    return result
end
local report = {}
local function note(s) report[#report + 1] = s end
local function check(cond, msg) if not cond then error('CHECK FAILED: ' .. msg .. ' REPORT: ' .. table.concat(report, ' | '), 2) end end
local function errors() return #MOCK.printed end

check(MOCK.findText('WARCRAFT SURVIVORS'), 'lobby title visible')
for _, tab in ipairs({'Armory', 'Codex', 'Talents', 'Achievements', 'Rewards', 'Character'}) do
    MOCK.click(tab)
    MOCK.pokeAll()
end
note('lobby tabs ok, errors=' .. errors())

-- Simulate a run: hold a direction, take hits, pick cards as they come.
local function play(seconds, opts)
    opts = opts or {}
    local keys = {OSKEY_1, OSKEY_2, OSKEY_3}
    local hands, elapsed = 0, 0
    while elapsed < seconds do
        MOCK.advance(0.25)
        elapsed = elapsed + 0.25
        local run = R()
        if run == nil or run.ended then break end
        if run.hand then
            hands = hands + 1
            if math.random() < 0.15 and run.rerolls > 0 then MOCK.tap(OSKEY_R) end
            if math.random() < 0.1 and run.banishes > 0 then
                upvalue(G.tryOpenHand, 'Cards').banish(1)
            end
            MOCK.tap(keys[math.random(1, #run.hand.cards)], CTRL)
        end
        -- Mock enemies have no AI: walk them toward the hero.
        for u in pairs(run.enemies) do
            local dx, dy = run.hx - u.x, run.hy - u.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > 90 then
                u.x, u.y = u.x + dx / d * 75, u.y + dy / d * 75
            end
        end
        -- Enemies hit the hero now and then.
        if math.random() < 0.3 then
            for u, info in pairs(run.enemies) do
                UnitDamageTarget(u, run.hero, opts.hit or 4, true, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                break
            end
        end
        if opts.immortal then
            run.hero.maxHp = 1e6
            run.hero.life = 1e6
        elseif not opts.mortal and math.floor(elapsed) % 20 == 0 then
            SetWidgetLife(run.hero, BlzGetUnitMaxHP(run.hero))
        end
        -- Help the mock hero finish bosses so the run can end.
        if opts.slayBosses and run.time > (opts.slayAfter or 0) then
            for u, info in pairs(run.enemies) do
                if info.boss then
                    UnitDamageTarget(run.hero, u, 1e7, false, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                end
            end
        end
        -- Kite in a square: a right-click 600 away every three seconds.
        if elapsed % 3 == 0 then
            local square = {{0, 600}, {600, 0}, {0, -600}, {-600, 0}}
            local side = square[math.floor(elapsed / 3) % 4 + 1]
            MOCK.order(run.hero, run.hx + side[1], run.hy + side[2])
        end
    end
    return hands
end

-- 0. Options: Escape opens them over the lobby, and Space does not start a run behind them.
MOCK.tap(OSKEY_ESCAPE)
check(MOCK.findText('Esc closes this menu'), 'escape opens options in the lobby')
check(not MOCK.findText('Restart Run'), 'no restart in the lobby')
MOCK.tap(OSKEY_SPACE)
check(R() == nil, 'space is ignored while options are open')
MOCK.tap(OSKEY_ESCAPE)
check(not MOCK.findText('Esc closes this menu'), 'escape closes options')

-- Unlocks on a fresh profile: four heroes (one per main faction) and the
-- five base talents. A hero that has not joined cannot enter a zone.
local openHeroes, openTalents = {}, 0
for index, hero in ipairs(HEROES) do
    if Profile.heroOpen(hero) then openHeroes[#openHeroes + 1] = hero.id end
end
for _, talent in ipairs(upvalue(Profile.applyBonuses, 'TALENTS')) do
    if Profile.talentOpen(talent) then openTalents = openTalents + 1 end
end
table.sort(openHeroes)
check(table.concat(openHeroes, ' ') == 'Edem Hamg Obla Udea', 'starting heroes: ' .. table.concat(openHeroes, ' '))
check(openTalents == 5, 'five talents open at the start, got ' .. openTalents)
for index, hero in ipairs(HEROES) do
    if hero.id == 'Hmkg' then S.heroIndex = index end
end
MOCK.tap(OSKEY_SPACE)
check(R() == nil, 'a locked hero cannot enter a zone')
S.heroIndex = 1

-- 1. Normal run to victory.
MOCK.tap(OSKEY_SPACE)
check(R() ~= nil, 'space starts a run')
local run = R()
-- Options during a run pause it; a volume step is saved; Resume unpauses.
MOCK.tap(OSKEY_ESCAPE)
check(run.paused and MOCK.findText('Restart Run'), 'options pause the run')
-- The game menu stacks its pages: Audio opens in its place, Escape comes back.
MOCK.click('Audio')
check(not MOCK.findText('Restart Run') and MOCK.findText('Esc returns to the menu'), 'audio page replaces the menu')
MOCK.click('-')
check(Profile.data.opts.master == 50, 'master volume stepped to 50, got ' .. tostring(Profile.data.opts.master))
Profile.data.opts.master = nil
MOCK.tap(OSKEY_ESCAPE)
check(run.paused and MOCK.findText('Restart Run'), 'escape returns from a page to the menu')
MOCK.click('Resume')
check(not run.paused, 'resume unpauses the run')
Profile.data.opts.music = nil
-- Mouse movement (the default): WASD does nothing, a right-click walks to the clicked point.
local x0, y0 = GetUnitX(run.hero), GetUnitY(run.hero)
MOCK.key(OSKEY_W, true)
MOCK.advance(0.5)
MOCK.key(OSKEY_W, false)
check(GetUnitY(run.hero) == y0 and GetUnitX(run.hero) == x0, 'W does not move the hero')
MOCK.order(run.hero, x0 + 200, y0)
MOCK.advance(0.4)
check(GetUnitX(run.hero) > x0 + 50, 'right-click walks the hero there')
check(GetUnitX(run.hero) <= x0 + 200.5, 'the hero stops at the click')
MOCK.advance(1.0)
check(math.abs(GetUnitX(run.hero) - (x0 + 200)) < 1, 'the hero arrives at the click')
-- Keyboard movement: W walks north, right-clicks do nothing; then W rebound to I.
MOCK.tap(OSKEY_ESCAPE)
MOCK.click('Keybinds')
MOCK.click('Keyboard')
check(Profile.data.opts.wasd == 1, 'keyboard movement on')
MOCK.tap(OSKEY_ESCAPE)
MOCK.click('Resume')
x0, y0 = GetUnitX(run.hero), GetUnitY(run.hero)
MOCK.order(run.hero, x0 + 300, y0)
MOCK.advance(0.5)
check(GetUnitX(run.hero) == x0 and GetUnitY(run.hero) == y0, 'right-click does not move with keyboard movement')
MOCK.key(OSKEY_W, true)
MOCK.advance(0.5)
MOCK.key(OSKEY_W, false)
check(GetUnitY(run.hero) > y0 + 50 and GetUnitX(run.hero) == x0, 'W walks the hero north')
MOCK.tap(OSKEY_ESCAPE)
MOCK.click('Keybinds')
MOCK.click('W')
check(MOCK.findText('Press a key'), 'a key waits for the new one')
MOCK.tap(OSKEY_I)
check(Profile.data.binds.up == 73, 'move up rebound to I, got ' .. tostring(Profile.data.binds.up))
MOCK.tap(OSKEY_ESCAPE)
MOCK.click('Resume')
y0 = GetUnitY(run.hero)
MOCK.key(OSKEY_W, true)
MOCK.advance(0.3)
MOCK.key(OSKEY_W, false)
check(GetUnitY(run.hero) == y0, 'W no longer walks')
MOCK.key(OSKEY_I, true)
MOCK.advance(0.3)
MOCK.key(OSKEY_I, false)
check(GetUnitY(run.hero) > y0 + 30, 'I walks north')
-- Binding a key another action has swaps them; Reset restores the defaults.
MOCK.tap(OSKEY_ESCAPE)
MOCK.click('Keybinds')
MOCK.click('I')
MOCK.tap(OSKEY_R)
check(Profile.data.binds.up == 82 and Profile.data.binds.reroll == 73, 'R swapped with reroll')
MOCK.click('Reset to Defaults')
check(next(Profile.data.binds) == nil, 'defaults restored')
MOCK.click('Mouse')
check(Profile.data.opts.wasd == 0, 'mouse movement back on')
MOCK.tap(OSKEY_ESCAPE)
MOCK.click('Resume')
check(not run.paused, 'run resumes after the keybinds')
check(MOCK.music and MOCK.music:find('NightElf', 1, true), 'zone music plays')
note('options ok')
-- The stats panel shows under the hero frame; C hides and shows it.
MOCK.advance(0.2)
check(MOCK.findText('Critical chance') and MOCK.findText('175'), 'stats panel lists critical strike')
MOCK.tap(OSKEY_C)
check(not MOCK.findText('Critical chance') and Profile.data.opts.stats == 0, 'C hides the stats')
MOCK.tap(OSKEY_C)
check(MOCK.findText('Critical chance'), 'C shows the stats again')
-- Hovering a spell slot shows what the spell does.
local hud = upvalue(G.startRun, 'Hud')
UI.safe(function() hud.spellTip(1) end)
check(MOCK.findText(run.spells[1].def.name .. '   rank 1'), 'spell slot tooltip')
UI.safe(function() hud.hideTip() end)
check(not MOCK.findText(run.spells[1].def.name .. '   rank 1'), 'tooltip hides')
note('run started: ' .. run.def.name .. ' in ' .. run.zone.name .. ' (' .. run.diff.name .. ')')
local hands = play(700, {slayBosses = true, slayAfter = 0})
run = R()
note(string.format('normal run: time %.0f level %d kills %d bosses %d hands %d spells %d ended=%s victory=%s loot=%d',
    run.time, run.level, run.kills, run.bosses, hands, #run.spells, tostring(run.ended), tostring(run.victory), #run.loot))
if not (run.ended and run.victory) then return table.concat(report, ' | ') .. ' | FINAL BOSS SPAWNED=' .. tostring(run.finalSpawned) .. ' hero life=' .. GetWidgetLife(run.hero) .. ' enemies=' .. run.enemyCount .. ' paused=' .. tostring(run.paused) .. ' hand=' .. tostring(run.hand ~= nil) end
check(run.ended and run.victory, 'normal run ends in victory')
check(MOCK.findText('VICTORY'), 'victory screen')
MOCK.pokeAll()
-- Endless mode: the won run goes on, stronger every minute, bosses on a timer;
-- its end adds only what came after the victory.
local runsBefore, killsBanked, goldBefore = Profile.data.runs, run.kills, Profile.data.gold
local bossesBefore = run.bosses
MOCK.click('Endless Mode')
check(R() == run and not run.ended and run.endless, 'endless mode resumes the run')
play(200, {slayBosses = true, immortal = true})
check(not run.ended, 'endless run still going')
check(run.bosses > bossesBefore, 'endless bosses come back, slain ' .. (run.bosses - bossesBefore))
local hpScale = G.endlessScale()
check(hpScale > 1.4, 'endless health grows, x' .. hpScale)
local endlessGold = run.gold - run.banked.gold
run.hero.invulnerable = false
run.invulnUntil = 0
UnitDamageTarget(next(run.enemies), run.hero, 1e8, true, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
MOCK.advance(0.1)
check(run.ended and run.victory, 'endless ends, still a victory')
check(MOCK.findText('ENDLESS'), 'endless end screen')
check(not MOCK.findText('Endless Mode'), 'no endless button after endless')
check(Profile.data.runs == runsBefore, 'endless is the same run')
check(Profile.data.endless['1'] and Profile.data.endless['1'] >= 790, 'endless time saved, got ' .. tostring(Profile.data.endless['1']))
check(math.abs(Profile.data.gold - goldBefore - math.floor(endlessGold * run.diff.reward + 0.5)) <= 1, 'endless gold banked once')
note(string.format('endless: %.0f s, health x%.2f, +%d kills, +%d bosses', run.time - run.endlessAt, hpScale,
    run.kills - killsBanked, run.bosses - bossesBefore))
MOCK.click('Return to Camp')
check(R() == nil and S.screen == 'lobby', 'back in lobby')
-- The Archmage's win opens the Mountain King (a boss slain), the Blood
-- Mage (an Alliance win), Naga (the first zone cleared) and two talents.
local function heroById(id)
    for _, hero in ipairs(HEROES) do
        if hero.id == id then return hero end
    end
end
for _, id in ipairs({'Hmkg', 'Hblm', 'Nngs'}) do
    check(Profile.heroOpen(heroById(id)), id .. ' joins after the win')
end
check(not Profile.heroOpen(heroById('Hpal')), 'the Paladin waits for 5:00 survived with the Mountain King')
for _, talent in ipairs(upvalue(Profile.applyBonuses, 'TALENTS')) do
    if talent.key == 'swiftness' or talent.key == 'magnetism' then
        check(Profile.talentOpen(talent), talent.key .. ' opens after the win')
    end
end
note('profile after win: zoneDiff1=' .. tostring(Profile.data.zoneDiff['1']) .. ' unlocked=' .. Profile.data.unlocked
    .. ' gold=' .. Profile.data.gold .. ' gear=' .. (function() local n = 0 for _ in pairs(Profile.data.gear) do n = n + 1 end return n end)())

-- 2. Save round trip.
local saved = Profile.encode(Profile.data)
Profile.load()
check(Profile.encode(Profile.data) == saved, 'save/load round trip')
note('save round trip ok (' .. #saved .. ' chars)')

-- 3. Heroic is open now; pick it in the difficulty window, then unlock Mythic+ and push a +12 key.
MOCK.click('rewards x1.00')
check(MOCK.findText('Win Ashenvale on Heroic to open it.'), 'difficulty window lists the locked ones')
MOCK.click('Mythic')
check(S.difficulty == 1, 'a locked difficulty cannot be picked')
MOCK.click('Heroic')
check(S.difficulty == 2, 'picked Heroic, got ' .. S.difficulty)
MOCK.click('Done')
check(not MOCK.findText('Win Ashenvale on Heroic to open it.'), 'Done closes the difficulty window')
check(MOCK.findText('Win on Heroic to open Mythic'), 'mythic lock hint')
Profile.data.zoneDiff['1'] = 3
Profile.data.keyMax['1'] = 12
Profile.data.gold = 5000
UI.safe(function() upvalue(G.startRun, 'Lobby').refresh() end)
MOCK.click('rewards x1.50')
MOCK.click('Mythic+')
check(S.difficulty == 4 and S.keyLevel == 12, 'Mythic+ at +12, got ' .. S.difficulty .. ' +' .. S.keyLevel)
MOCK.click('-')
check(S.keyLevel == 11, 'key down')
MOCK.click('+')
MOCK.click('+')
check(S.keyLevel == 12, 'key capped at max')
MOCK.tap(OSKEY_SPACE)
check(R() == nil, 'space does not start a run behind the difficulty window')
MOCK.tap(OSKEY_ESCAPE)
check(not MOCK.findText('Esc closes this menu') and not MOCK.findText('No end: kill the final boss'), 'escape closes the difficulty window only')
MOCK.tap(OSKEY_SPACE)
run = R()
note('mythic+ run: ' .. run.diff.name .. ' hp x' .. string.format('%.2f', run.diff.hp) .. ' lives=' .. run.stats.lives)
check(run.diff.level == 12, 'keystone +12 run')
play(640, {slayBosses = true, slayAfter = 605, immortal = true})
run = R()
note(tostring(MOCK.heroDeath)); note(string.format('mythic+ state: time %.1f ended=%s victory=%s finalSpawned=%s finalAt=%s life=%.0f hand=%s paused=%s',
    run.time, tostring(run.ended), tostring(run.victory), tostring(run.finalSpawned), tostring(run.finalAt),
    GetWidgetLife(run.hero), tostring(run.hand ~= nil), tostring(run.paused)))
check(run.ended and run.victory, 'mythic+ victory')
note(string.format('mythic+ result: upgrade +%d keyBest=%s keyMax=%s',
    run.keyUpgrade or -1, tostring(Profile.data.keyBest['1']), tostring(Profile.data.keyMax['1'])))
check(MOCK.findText('timed'), 'keystone timed line')
MOCK.click('Play Again')
check(R() ~= nil and not R().ended, 'play again starts a run')
play(20)
run = R()
UnitDamageTarget(next(run.enemies), run.hero, 1e7, true, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
MOCK.advance(0.1)
check(R().ended and not R().victory, 'defeat')
check(MOCK.findText('DEFEAT'), 'defeat screen')
MOCK.click('Return to Camp')

-- 4. Armory upgrades and talents.
MOCK.click('Armory')
MOCK.pokeAll()
local before = Profile.data.gold
MOCK.click('Upgrade')
note('armory upgrade spent ' .. (before - Profile.data.gold) .. ' gold')
check(before > Profile.data.gold, 'upgrade costs gold')
-- Looted items go straight into the six-slot inventory; Unequip and Equip move them.
local function carried()
    local n = 0
    for _ in pairs(Profile.data.inv) do n = n + 1 end
    return n
end
local looted = 0
for _ in pairs(Profile.data.gear) do looted = looted + 1 end
check(carried() == math.min(6, looted), 'loot fills the inventory, carried ' .. carried() .. ' of ' .. looted)
local carriedBefore = carried()
MOCK.click('Unequip')
check(carried() == carriedBefore - 1, 'unequip frees a slot')
MOCK.click('Equip')
check(carried() == carriedBefore, 'equip fills it again')
note('inventory ok: ' .. carried() .. ' carried')
MOCK.click('Talents')
MOCK.click('gold')
MOCK.click('Rewards')
MOCK.click('Character')

-- Wisp Companion perk: gems and coins beyond the pickup range reach the hero.
Profile.data.perks.companion = 3
S.heroIndex, S.difficulty = 1, 1
G.startRun()
run = R()
check(run.companion ~= nil, 'the companion perk spawns a wisp')
MOCK.pokeAll()
G.dropPickup('gold', run.hx + 900, run.hy, 50)
local farCoin = run.pickups[#run.pickups]
G.dropPickup('xp', run.hx - 600, run.hy + 500, 3)
local farGem = run.pickups[#run.pickups]
local function lying(p)
    for _, q in ipairs(R().pickups) do
        if q == p then return true end
    end
    return false
end
for _ = 1, 60 do
    MOCK.advance(0.25)
    if R().hand then MOCK.tap(OSKEY_1, CTRL) end
    if not lying(farCoin) and not lying(farGem) then break end
end
check(not lying(farCoin) and not lying(farGem), 'the wisp fetched the far coin and gem')
note('companion fetched far pickups')
G.endRun(false)
MOCK.click('Return to Camp')
Profile.data.perks.companion = nil

-- World objects: three lie near the start; walking onto a free one pays out,
-- a paid chest waits for the gold, then opens a card hand.
S.heroIndex, S.difficulty = 1, 1
G.startRun()
run = R()
check(#run.interactables == 3, 'a run starts with three world objects, got ' .. #run.interactables)
local function objectOf(kind)
    for _, o in ipairs(run.interactables) do
        if o.kind == kind then return o end
    end
end
local function standOn(o)
    SetUnitX(run.hero, o.x)
    SetUnitY(run.hero, o.y)
end
local vein = objectOf('vein')
local goldBefore = run.gold
standOn(vein)
MOCK.advance(0.1)
check(objectOf('vein') == nil and run.gold > goldBefore, 'walking onto the gold vein mines it')
check(vein.fx.dead and vein.glow.dead, 'a used object takes its art away')
local chest = objectOf('chest')
check(chest.price == 40 and chest.priceTag ~= nil, 'the chest shows its price')
run.gold = 0
standOn(chest)
MOCK.advance(0.5)
check(objectOf('chest') == chest, 'a chest without the gold stays shut')
run.gold = 1000
MOCK.advance(0.5)
check(objectOf('chest') == nil and run.worldChestsOpened == 1, 'the chest opens once the gold is there')
check(run.hand ~= nil or run.pendingChests > 0, 'the chest deals a card hand')
check(chest.priceTag == nil, 'its price tag goes with it')
if run.hand then MOCK.tap(OSKEY_1, CTRL) end
-- Bodies block: a step into an enemy is held back, and a step away is free.
G.refreshEnemyCache()
local blocker = run.elist[1]
SetUnitX(blocker, run.hx + 40)
SetUnitY(blocker, run.hy)
G.refreshEnemyCache()
local nx = G.collide(run.hx, run.hy, run.hx + 20, run.hy)
check(nx <= run.hx + 0.01, 'an enemy in the way blocks the hero, moved ' .. (nx - run.hx))
nx = G.collide(run.hx, run.hy, run.hx - 20, run.hy)
check(math.abs(nx - (run.hx - 20)) < 0.01, 'the hero can always step away')
-- A save from 1.3.0 test builds that turned collision off no longer matters.
Profile.data.opts.collide = 0
nx = G.collide(run.hx, run.hy, run.hx + 20, run.hy)
check(nx <= run.hx + 0.01, 'collision cannot be turned off, moved ' .. (nx - run.hx))
Profile.data.opts.collide = nil
G.endRun(false)
MOCK.click('Return to Camp')
check(#MOCK.liveTags() == 0, 'no price tag is left after the run')
note('world objects: vein mined, chest opened for 40 gold, collision blocks')

-- Mana and casting: a spell short of mana waits, casts once the mana is
-- there; with autocast off (Shift+1) it waits for its key (1), which casts
-- it. New spells start with autocast off. Every spell that casts costs mana.
S.heroIndex, S.difficulty = 1, 1
G.startRun()
run = R()
local spellInst = run.spells[1]
check(spellInst.v.mana > 0, spellInst.def.key .. ' costs mana')
check(run.maxMana > 0 and run.mana == run.maxMana, 'a run starts with a full mana pool')
G.createEnemy(run.zone.enemies[1], run.hx + 200, run.hy, {})
G.refreshEnemyCache()
run.mana = 0
spellInst.cd = 0
MOCK.advance(0.1)
check(spellInst.waiting and spellInst.cd == 0, 'a spell short of mana waits, ready')
run.mana = run.maxMana
MOCK.advance(0.1)
check(spellInst.cd > 0 and not spellInst.waiting and run.mana < run.maxMana, 'it casts and pays once the mana is there')
local SHIFT = 1
check(spellInst.auto, 'the test runs with autocast on')
MOCK.tap(OSKEY_1, SHIFT)
check(not spellInst.auto, 'Shift+1 turns autocast off')
spellInst.cd = 0
run.mana = run.maxMana
MOCK.advance(0.5)
check(spellInst.cd == 0 and run.mana >= run.maxMana - 0.001, 'with autocast off a ready spell waits for its key')
MOCK.tap(OSKEY_1)
check(spellInst.cd > 0 and run.mana < run.maxMana, '1 casts spell 1 and pays for it')
MOCK.tap(OSKEY_1, SHIFT)
check(spellInst.auto, 'Shift+1 turns autocast back on')
local CFG = upvalue(G.learnSpell, 'CFG')
CFG.AUTOCAST = false
local fresh = G.learnSpell('water_elemental', 1.0)
check(not fresh.auto, 'for players, a new spell starts with autocast off')
CFG.AUTOCAST = true
for key, def in pairs(SPELLS) do
    if def.kind ~= 'passive' and def.kind ~= 'aura' and def.kind ~= 'orbit' then
        check((def.mana or 0) > 0, key .. ' casts, so it costs mana')
    end
end
G.endRun(false)
MOCK.click('Return to Camp')
note('mana and keys: waits when short, 1 casts, Shift+1 autocast, new spells manual')

-- Items: every one has two or three stats (or all attributes) and a tooltip;
-- the signature ones carry an effect, and each effect works in a run.
local GEAR = upvalue(Profile.load, 'GEAR')
local savedGear, savedInv = Profile.data.gear, Profile.data.inv
local function itemByCode(code)
    for _, item in ipairs(GEAR) do
        if item.code == code then return item end
    end
end
local effects = 0
for _, item in ipairs(GEAR) do
    check(#item.stats >= 1 and #item.stats <= 3, item.name .. ' has one to three stats')
    local text = G.describeItem(item, item.baseIlvl)
    check(#text > 0 and not text:find('?', 1, true), item.name .. ' describes its stats: ' .. text)
    if item.effect then
        effects = effects + 1
        check(G.describeItemEffect(item, item.baseIlvl):find('Equip: ', 1, true), item.name .. ' describes its effect')
    end
end
check(effects >= 15, 'signature items have effects, got ' .. effects)
local function wear(codes)
    Profile.data.gear, Profile.data.inv = {}, {}
    for slot, code in ipairs(codes) do
        local item = itemByCode(code)
        Profile.data.gear[item.id] = item.baseIlvl
        Profile.data.inv[tostring(slot)] = item.index
    end
end
-- A test enemy too sturdy to die from the effects themselves.
local function foe(dx, dy)
    local u = G.createEnemy(run.zone.enemies[1], run.hx + dx, run.hy + dy, {})
    u.maxHp, u.life = 1e5, 1e5
    G.refreshEnemyCache()
    return u
end
local function kill(u)
    UnitDamageTarget(run.hero, u, 1e7, false, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
end
-- Fire, Darkness, Mask of Death, Kelen's Dagger, Grimoire of Souls, Corruption.
wear({'ofir', 'odef', 'modt', 'desc', 'grsl', 'ocor'})
MOCK.click('Armory')
MOCK.pokeAll()
check(MOCK.findText('Fire Orb') and MOCK.findText('Strength'), 'the armory sums the carried stats and names the effects')
S.heroIndex, S.difficulty = 1, 1
G.startRun()
run = R()
local s = run.stats
check(s.fireSplash > 0 and s.darkMinion > 0 and s.vampiric > 0 and s.escape > 0 and s.souls > 0 and s.corrupt > 0,
    'worn effects reach the run stats')
local target, beside = foe(150, 0), foe(170, 20)
local besideLife = beside.life
G.attackHit(target, target.x, target.y, 20)
check(beside.life < besideLife and (run.meter.fireOrb or 0) > 0, 'Orb of Fire splashes around the target')
check(run.enemies[target].corruptUntil > run.time, 'Orb of Corruption marks the target')
local intBefore = run.stats.int
for _ = 1, 25 do kill(foe(300, 0)) end
check(run.souls == 1 and run.stats.int >= intBefore + 1, 'Grimoire of Souls: 25 kills give 1 Intellect')
run.stats.darkMinion = 1
kill(foe(300, 0))
local minion = nil
for u, info in pairs(run.summons) do
    if info.key == 'darkOrb' then minion = u end
end
check(minion ~= nil, 'Orb of Darkness raises a skeleton')
local maxHp = BlzGetUnitMaxHP(run.hero)
SetWidgetLife(run.hero, maxHp * 0.35)
local hx = run.hx
UnitDamageTarget(target, run.hero, maxHp * 0.1, true, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
check(GetWidgetLife(run.hero) >= maxHp * 0.35 - 0.01, "Kelen's Dagger: the hit that would drop under 30 percent misses")
MOCK.advance(0.1)
check(math.abs(GetUnitX(run.hero) - hx) > 100 and run.invulnUntil > run.time, "Kelen's Dagger blinks the hero away")
G.endRun(false)
MOCK.click('Return to Camp')
-- Cloak of Flames, Searing Blade, Battlethirst, Spell Immunity, Sanctuary, Spell Mastery.
wear({'clfm', 'srbd', 'hbth', 'nspi', 'ssan', 'gvsm'})
G.startRun()
run = R()
s = run.stats
local spell = run.spells[1]
local plain = {}
for k, v in pairs(s) do plain[k] = v end
plain.manaCost = 0
check(spell.v.mana < G.spellValues(spell.def, spell.rank, spell.power, plain).mana, 'Spell Mastery lowers mana costs')
target = foe(120, 0)
foe(100, 60)
G.attackHit(target, target.x, target.y, 30)
MOCK.advance(1.5)
check((run.meter.searing or 0) > 0, 'Searing Blade burns the target')
check((run.meter.cloak or 0) > 0, 'Cloak of Flames burns nearby enemies')
kill(foe(300, 0))
check(run.thirstUntil > run.time, 'Battlethirst: a kill raises attack speed')
maxHp = BlzGetUnitMaxHP(run.hero)
SetWidgetLife(run.hero, maxHp)
UnitDamageTarget(target, run.hero, maxHp * 0.2, true, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
check(GetWidgetLife(run.hero) >= maxHp - 0.01 and run.wardReady > run.time, 'Spell Immunity ignores a heavy hit')
SetWidgetLife(run.hero, maxHp * 0.35)
UnitDamageTarget(target, run.hero, maxHp * 0.08, true, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
check(GetWidgetLife(run.hero) > maxHp * 0.35, 'Staff of Sanctuary heals under 30 percent health')
-- Life steal heals at most 3 percent of maximum health a second, however
-- many enemies an area spell hits.
SetWidgetLife(run.hero, 1)
run.stats.lifesteal = 1
for _ = 1, 30 do G.damage(foe(150, 0), 1000, 'attack', false) end
local healed = GetWidgetLife(run.hero) - 1
check(healed <= maxHp * 0.03 + 1, 'life steal is capped, healed ' .. healed .. ' of ' .. maxHp)
G.endRun(false)
MOCK.click('Return to Camp')
Profile.data.gear, Profile.data.inv = savedGear, savedInv
note('items: ' .. effects .. ' effects; fire, corruption, souls, minion, escape, burns, thirst, immunity, sanctuary, mastery')

-- 5. Every hero with every spell of its pool at a high rank (no rank limit).
for index, hero in ipairs(HEROES) do
    S.heroIndex = index
    S.difficulty = 1
    -- The starting spell is the one picked in the lobby.
    local pick = (index - 1) % #hero.pool + 1
    Profile.data.starts[hero.id] = pick
    G.startRun()
    run = R()
    check(run.spells[1].def.key == hero.pool[pick], hero.name .. ' starts with ' .. hero.pool[pick])
    for _, key in ipairs(hero.pool) do
        local inst = run.spellByKey[key] or G.learnSpell(key, 1.3)
        inst.rank = SPELLS[key].maxRank or 15
    end
    G.recomputeStats()
    if run.spellByKey.mirror_image then
        G.mirrorImages(2, 200)
        local image = next(run.images)
        check(image ~= nil, 'mirror images appear')
        local life = GetWidgetLife(image)
        check(math.abs(BlzGetUnitMaxHP(image) - math.floor(BlzGetUnitMaxHP(run.hero) * 0.25)) <= 1,
            'a mirror image has a quarter of the hero health')
        UnitDamageTarget(next(run.enemies), image, 10, true, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
        check(math.abs(life - GetWidgetLife(image) - 30) < 0.01, 'mirror images take triple damage, lost '
            .. (life - GetWidgetLife(image)))
        note('mirror image takes 10 x 3')
    end
    if run.spellByKey.raven_form then
        -- Medivh turns into the raven (the Alternate sequences), flies over
        -- enemies, and comes back to his own attack when it ends.
        local CAST = upvalue(G.cast, 'CAST')
        local inst = run.spellByKey.raven_form
        MOCK.advance(0.1)
        if run.hand then MOCK.tap(OSKEY_1, CTRL) end
        for _ = 1, 5 do
            G.createEnemy(G.pickEnemyType(), run.hx + 60, run.hy, {})
        end
        G.refreshEnemyCache()
        check(run.buffs.raven_form or CAST.buff(inst, inst.v), 'raven form casts when surrounded')
        check(run.hero.props == 'alternate' and run.attackAnim == 'attack', 'medivh becomes the raven')
        local nx = G.collide(run.hx, run.hy, run.hx + 20, run.hy)
        check(math.abs(nx - (run.hx + 20)) < 0.01, 'the raven flies over enemies')
        for _ = 1, math.ceil(inst.v.dur / 0.25) + 4 do
            MOCK.advance(0.25)
            if run.hand then MOCK.tap(OSKEY_1, CTRL) end
        end
        check(run.buffs.raven_form == nil or run.buffs.raven_form.untilT > run.time, 'raven form ends')
        if run.buffs.raven_form == nil then
            check(run.hero.props == nil and run.attackAnim == 'spell', 'medivh takes his own form back, attack '
                .. tostring(run.attackAnim))
        end
        note('medivh raven form morphs and flies')
    end
    if run.spellByKey.storm_earth_fire then
        -- The Brewmaster splits into three spirits, hidden and invulnerable,
        -- and merges back when the split ends.
        local CAST = upvalue(G.cast, 'CAST')
        local inst = run.spellByKey.storm_earth_fire
        MOCK.advance(0.1)
        if run.hand then MOCK.tap(OSKEY_1, CTRL) end
        check(run.split or CAST.summon(inst, inst.v), 'storm, earth and fire casts')
        inst.cd = inst.v.cd
        -- The mock lists npn1 as an unknown rawcode: Storm and Earth come out.
        check(run.split and #run.split.units == 2, 'the spirits that exist come out, got '
            .. tostring(run.split and #run.split.units))
        check(run.hero.alpha == 0, 'the split hero is hidden')
        local spirits = run.split.units
        for _ = 1, math.ceil(inst.v.dur / 0.25) + 4 do
            MOCK.advance(0.25)
            if run.hand then MOCK.tap(OSKEY_1, CTRL) end
        end
        check(run.split == nil, 'the split ends, time ' .. run.time .. ' until ' .. tostring(run.split and run.split.untilT)
            .. ' paused=' .. tostring(run.paused) .. ' hand=' .. tostring(run.hand ~= nil) .. ' ended=' .. tostring(run.ended)
            .. ' same=' .. tostring(run.split == spirits))
        check(run.hero.alpha == 255, 'the hero comes back')
        for _, u in ipairs(spirits) do
            check(u.removed and run.summons[u] == nil, 'the spirits merge back')
        end
        note(string.format('brewmaster split %.1f s and merged', inst.v.dur))
    end
    play(45, {slayBosses = true})
    run = R()
    -- Extra lives and invulnerability buffs mean it can take a few blows.
    local blows = 0
    while run and not run.ended and blows < 20 do
        blows = blows + 1
        run.hero.invulnerable = false
        local attacker = next(run.enemies) or run.hero
        UnitDamageTarget(attacker, run.hero, 1e7, true, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
        MOCK.advance(3)
        if run.hand then MOCK.tap(OSKEY_1, CTRL) end
    end
    check(run.ended, hero.name .. ' run ends after ' .. blows .. ' blows')
    MOCK.click('Return to Camp')
end
note('all ' .. #HEROES .. ' heroes played with full pools')

-- Leftover effects/units check.
local alive = 0
for u in pairs(MOCK.units) do alive = alive + 1 end
-- The last hero is the Forsaken Paladin, which the mock treats as an unknown
-- rawcode, so no lobby preview unit is expected here.
note('units left in lobby: ' .. alive)

local missing = {}
for name in pairs(MOCK.missing) do missing[#missing + 1] = name end
table.sort(missing)
note('natives not in mock: ' .. table.concat(missing, ', '))
note('script errors printed: ' .. errors())
for i = 1, math.min(10, #MOCK.printed) do note('  ' .. MOCK.printed[i]) end
return table.concat(report, '\n')
