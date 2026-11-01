-- Minimal Warcraft III native mock for smoke-testing the map script.
MOCK = {now = 0, timers = {}, triggers = {}, frames = {}, units = {}, files = {}, tooltips = {}, missing = {},
    log = {}, printed = {}, invalidUnits = {Npal = true, npn1 = true, ncg1 = true, ncg2 = true, ncg3 = true}}

local function handle(kind, t)
    t = t or {}
    t.__kind = kind
    return t
end

-- Anything not defined below is logged and stubbed, so typos show up.
setmetatable(_G, {__index = function(_, name)
    if type(name) == 'string' and name:match('^[A-Z]') then
        MOCK.missing[name] = true
        if name:match('^[A-Z0-9_]+$') then
            local c = handle('const', {name = name})
            rawset(_G, name, c)
            return c
        end
        return function() return nil end
    end
    return nil
end})

local function const(name) rawset(_G, name, handle('const', {name = name})) end
for _, n in ipairs({'FRAMEEVENT_CONTROL_CLICK', 'FRAMEEVENT_MOUSE_ENTER', 'FRAMEEVENT_MOUSE_LEAVE', 'FRAMEPOINT_TOPLEFT',
    'FRAMEPOINT_BOTTOMRIGHT', 'TEXT_JUSTIFY_CENTER', 'TEXT_JUSTIFY_LEFT', 'TEXT_JUSTIFY_RIGHT', 'TEXT_JUSTIFY_MIDDLE',
    'TEXT_JUSTIFY_TOP', 'ORIGIN_FRAME_GAME_UI', 'ORIGIN_FRAME_MINIMAP', 'ORIGIN_FRAME_PORTRAIT', 'ORIGIN_FRAME_WORLD_FRAME',
    'ATTACK_TYPE_CHAOS', 'DAMAGE_TYPE_NORMAL', 'WEAPON_TYPE_WHOKNOWS', 'CAMERA_FIELD_ANGLE_OF_ATTACK', 'CAMERA_FIELD_FARZ',
    'CAMERA_FIELD_FIELD_OF_VIEW', 'CAMERA_FIELD_ROTATION', 'CAMERA_FIELD_TARGET_DISTANCE', 'CAMERA_FIELD_ZOFFSET',
    'EVENT_PLAYER_UNIT_DAMAGED', 'EVENT_PLAYER_UNIT_DEATH', 'PATHING_TYPE_WALKABILITY', 'GAME_STATE_TIME_OF_DAY',
    'UNIT_RF_SCALING_VALUE', 'UNIT_WEAPON_RF_ATTACK_PROJECTILE_SPEED', 'UNIT_WEAPON_RF_ATTACK_RANGE',
    'UNIT_WEAPON_SF_ATTACK_PROJECTILE_ART', 'OSKEY_1', 'OSKEY_2', 'OSKEY_3', 'OSKEY_4', 'OSKEY_A', 'OSKEY_D', 'OSKEY_DOWN',
    'OSKEY_LEFT', 'OSKEY_R', 'OSKEY_RIGHT', 'OSKEY_S', 'OSKEY_SPACE', 'OSKEY_UP', 'OSKEY_W', 'OSKEY_ESCAPE',
    'OSKEY_F1', 'OSKEY_F2', 'OSKEY_F3', 'OSKEY_F4', 'UNIT_WEAPON_IF_ATTACK_WEAPON_SOUND', 'WEAPON_TYPE_METAL_HEAVY_SLICE',
    'SOUND_VOLUMEGROUP_SPELLS', 'SOUND_VOLUMEGROUP_AMBIENTSOUNDS', 'SOUND_VOLUMEGROUP_UNITSOUNDS',
    'SOUND_VOLUMEGROUP_COMBAT', 'SOUND_VOLUMEGROUP_UNITMOVEMENT', 'UNIT_STATE_MANA', 'UNIT_STATE_MAX_MANA'}) do
    const(n)
end
for _, n in ipairs({'EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER', 'EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER'}) do
    const(n)
end
for c in ('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'):gmatch('.') do
    if rawget(_G, 'OSKEY_' .. c) == nil then const('OSKEY_' .. c) end
end
PLAYER_NEUTRAL_PASSIVE = 15
bj_RADTODEG = 180 / math.pi
bj_ALLIANCE_UNALLIED = 0
bj_mapInitialPlayableArea = handle('rect', {minX = -4000, minY = -4000, maxX = 4000, maxY = 4000})
bj_mapInitialCameraBounds = handle('rect', {minX = -3800, minY = -3800, maxX = 3800, maxY = 3800})

-- Core
function FourCC(s)
    assert(type(s) == 'string' and #s == 4, 'FourCC needs 4 chars: ' .. tostring(s))
    local n = 0
    for i = 1, 4 do n = n * 256 + s:byte(i) end
    return n
end
local function code(n)
    local c = {}
    for i = 4, 1, -1 do c[i] = string.char(n % 256); n = n // 256 end
    return table.concat(c)
end
local function int(name, x)
    assert(type(x) == 'number', name .. ' expects a number, got ' .. tostring(x))
    assert(math.type(x) == 'integer' or x == math.floor(x), name .. ' got non-integer ' .. tostring(x))
end
local players = {}
function Player(i) players[i] = players[i] or handle('player', {id = i}); return players[i] end
function GetLocalPlayer() return Player(0) end
function GetRandomReal(a, b) return a + math.random() * (b - a) end
function GetRandomInt(a, b) int('GetRandomInt', a); int('GetRandomInt', b); assert(a <= b, 'GetRandomInt range'); return math.random(a, b) end
function Atan2(y, x) return math.atan(y, x) end
function print(...) local t = {...}; for i = 1, #t do t[i] = tostring(t[i]) end; MOCK.printed[#MOCK.printed + 1] = table.concat(t, ' ') end
function GetRectCenterX(r) return (r.minX + r.maxX) / 2 end
function GetRectCenterY(r) return (r.minY + r.maxY) / 2 end
function GetRectMinX(r) return r.minX end
function GetRectMinY(r) return r.minY end
function GetRectMaxX(r) return r.maxX end
function GetRectMaxY(r) return r.maxY end
function Location(x, y) return handle('location', {x = x, y = y}) end
function MoveLocation(l, x, y) l.x, l.y = x, y end
function GetLocationZ(l) return 0 end
function IsTerrainPathable() return false end
function FogEnable() end
function FogMaskEnable() end
function SuspendTimeOfDay() end
function SetMusicVolume(v) int('SetMusicVolume', v) end
function ClearMapMusic() end
function StopMusic(fade) assert(type(fade) == 'boolean') end
function PlayMusic(s) assert(type(s) == 'string' and not s:find('\\\\', 1, true)); MOCK.music = s end
function GetUnitState(u, state) return (state == UNIT_STATE_MANA or state == UNIT_STATE_MAX_MANA) and 300 or 0 end
function VolumeGroupSetVolume(group, v) assert(type(v) == 'number', 'VolumeGroupSetVolume expects a number') end
function SetFloatGameState() end
function SetTerrainFogEx(style, a, b, c, r, g, bl) assert(type(bl) == 'number') end
function ResetTerrainFog() end
function SetPlayerAllianceStateBJ() end
function EnableSelect() end
function ClearTextMessages() end
function DisplayTimedTextToPlayer(p, x, y, d, s) assert(type(s) == 'string') end
function SelectUnitForPlayerSingle() end
function ResetToGameCamera() end
function SetCameraTargetController() end
function SetCameraField(f, v, d) assert(type(v) == 'number') end
function SetCameraPosition() end
function SetCameraBounds(...) for i = 1, 8 do assert(type(select(i, ...)) == 'number') end end
function SetCameraBoundsToRect(r) assert(r ~= nil) end

-- Items
function CreateItem(id, x, y) return handle('item', {x = x, y = y}) end
function SetItemVisible() end
function SetItemPosition(i, x, y) i.x, i.y = x, y end
function GetItemX(i) return i.x end
function GetItemY(i) return i.y end

-- Units
local unitCount = 0
function CreateUnit(p, id, x, y, face)
    assert(type(face) == 'number', 'CreateUnit facing')
    local c = code(id)
    if MOCK.invalidUnits[c] then return nil end
    unitCount = unitCount + 1
    local hero = c:sub(1, 1):match('[HOEUN]') ~= nil
    local u = handle('unit', {id = c, owner = p, x = x, y = y, life = 100, maxHp = 100, alive = true, n = unitCount,
        name = c, hero = hero, order = 0})
    MOCK.units[u] = true
    return u
end
function RemoveUnit(u) MOCK.units[u] = nil; u.removed = true end
function GetUnitX(u) return u.x end
function GetUnitY(u) return u.y end
function SetUnitX(u, x) u.x = x end
function SetUnitY(u, y) u.y = y end
function SetUnitPosition(u, x, y) u.x, u.y = x, y end
function BlzGetUnitZ() return 0 end
function GetWidgetLife(u) return u.alive and u.life or 0 end
function SetWidgetLife(u, v) assert(type(v) == 'number'); if u.alive then u.life = math.min(v, u.maxHp) end end
function BlzGetUnitMaxHP(u) return u.maxHp end
function BlzSetUnitMaxHP(u, v) int('BlzSetUnitMaxHP', v); u.maxHp = v end
function BlzSetUnitBaseDamage(u, v, i) int('BlzSetUnitBaseDamage', v); u.damage = v end
function BlzSetUnitArmor(u, v) assert(type(v) == 'number') end
function GetUnitDefaultMoveSpeed() return 270 end
function SetUnitMoveSpeed(u, v) assert(type(v) == 'number') end
function IssueTargetOrder(u, o, t) u.order = 1; return true end
function IssuePointOrder(u, o, x, y) u.order = 1; return true end
function GetUnitCurrentOrder(u) return u.order end
function IssueImmediateOrder(u, o) assert(type(o) == 'string'); u.order = 0; return true end
function GetUnitTypeId(u) return FourCC(u.id) end
function PauseUnit(u, p) u.paused = p end
function BlzPauseUnitEx(u, p) u.stuns = (u.stuns or 0) + (p and 1 or -1) end
function SetUnitScale() end
function SetUnitVertexColor(u, r, g, b, a) int('SetUnitVertexColor', r); u.alpha = a end
function BlzSetUnitName(u, s) u.name = s end
function GetUnitName(u) return u.name end
function SetUnitAnimation(u, a) u.anim = a end
function AddUnitAnimationProperties(u, tag, add) assert(type(tag) == 'string'); u.props = add and tag or nil end
function BlzGetUnitCollisionSize(u) return u.hero and 32 or 16 end
function QueueUnitAnimation() end
function SetUnitTimeScale() end
function BlzSetUnitFacingEx() end
function SetUnitInvulnerable(u, v) u.invulnerable = v end
function UnitAddAbility() return true end
function UnitRemoveAbility() return true end
function SuspendHeroXP() end
function GetHeroSkillPoints() return 1 end
function UnitModifySkillPoints() return true end
function UnitApplyTimedLife() end
function BlzGetUnitWeaponRealField(u, f, i)
    if f == UNIT_WEAPON_RF_ATTACK_RANGE then return (u.id == 'Hmkg' or u.id == 'Obla') and 100 or 600 end
    return 900
end
function BlzGetUnitWeaponStringField(u) return (u.id == 'Hmkg' or u.id == 'Obla') and '' or 'Missile.mdl' end
-- Weapon sound: melee heroes slice (MetalHeavySlice), the rest have none.
function BlzGetUnitWeaponIntegerField(u) return (u.id == 'Hmkg' or u.id == 'Obla') and 6 or 0 end
function BlzGetUnitAttackCooldown() return 1.8 end
function BlzGetUnitRealField() return 1.0 end

-- Damage and death events fire synchronously, like the game.
local eventStack = {}
local function fire(kind, ctx, filter)
    for _, t in ipairs(MOCK.triggers) do
        for _, ev in ipairs(t.events) do
            if ev.kind == kind and (filter == nil or filter(ev)) then
                eventStack[#eventStack + 1] = ctx
                for _, action in ipairs(t.actions) do action() end
                eventStack[#eventStack] = nil
                break
            end
        end
    end
end
local function ctx() return eventStack[#eventStack] or {} end
function UnitDamageTarget(src, target, amount, a, r, at, dt, wt)
    assert(type(amount) == 'number' and amount == amount, 'damage NaN')
    if not target.alive or target.invulnerable then return false end
    local c = {source = src, target = target, damage = amount}
    fire('damaged', c)
    target.life = target.life - c.damage
    if target.life <= 0.405 then
        target.alive = false
        target.life = 0
        fire('death', {unit = target, killer = src}, function(ev) return ev.player == target.owner end)
    end
    return true
end
function BlzGetEventDamageTarget() return ctx().target end
function GetEventDamageSource() return ctx().source end
function GetEventDamage() return ctx().damage end
function BlzSetEventDamage(v) ctx().damage = v end
function GetTriggerUnit() return ctx().unit end
function GetTriggerPlayer() return ctx().player or Player(0) end
function GetOrderPointX() return ctx().x end
function GetOrderPointY() return ctx().y end
function GetOrderTargetUnit() return ctx().target end
function GetOrderTarget() return ctx().target end

-- Triggers
function CreateTrigger() local t = handle('trigger', {events = {}, actions = {}}); MOCK.triggers[#MOCK.triggers + 1] = t; return t end
function TriggerAddAction(t, f) t.actions[#t.actions + 1] = f end
function TriggerRegisterAnyUnitEventBJ(t, e) t.events[#t.events + 1] = {kind = 'damaged'} end
function TriggerRegisterPlayerUnitEvent(t, p, e)
    t.events[#t.events + 1] = {kind = e == EVENT_PLAYER_UNIT_DEATH and 'death' or 'order', player = p}
end
function BlzTriggerRegisterFrameEvent(t, f, e) t.events[#t.events + 1] = {kind = 'frame', frame = f, event = e} end
function BlzTriggerRegisterPlayerKeyEvent(t, p, k, m, down) t.events[#t.events + 1] = {kind = 'key', key = k, down = down} end
function BlzGetTriggerFrame() return ctx().frame end
function BlzGetTriggerFrameEvent() return ctx().event end
function BlzGetTriggerPlayerKey() return ctx().key end
function BlzGetTriggerPlayerIsKeyDown() return ctx().down end

-- Timers
function CreateTimer() return handle('timer', {}) end
function TimerStart(t, d, periodic, fn)
    t.due = MOCK.now + d; t.period = periodic and d or nil; t.fn = fn; t.active = true
    MOCK.timers[t] = true
end
function DestroyTimer(t) t.active = false; MOCK.timers[t] = nil end
function GetExpiredTimer() return MOCK.expired end

-- Effects, lightning, text tags
function AddSpecialEffect(m, x, y) assert(type(m) == 'string', 'effect model'); return handle('effect', {}) end
function AddSpecialEffectTarget(m, u, a) assert(type(m) == 'string'); return handle('effect', {}) end
function DestroyEffect(e) assert(e and e.__kind == 'effect', 'DestroyEffect on non-effect'); assert(not e.dead, 'effect destroyed twice'); e.dead = true end
function BlzSetSpecialEffectScale() end
function BlzSetSpecialEffectPosition(e, x, y, z) assert(type(z) == 'number' and x == x) end
function BlzSetSpecialEffectYaw() end
function BlzSetSpecialEffectZ() end
function BlzSetSpecialEffectColor(e, r, g, b) int('BlzSetSpecialEffectColor', r) end
function AddLightningEx() return handle('lightning', {}) end
function DestroyLightning() end
local textTags = {}
function CreateTextTag() local t = handle('texttag', {}); textTags[#textTags + 1] = t; return t end
-- Permanent text tags (price labels) never expire: each must be destroyed.
function MOCK.liveTags()
    local live = {}
    for _, t in ipairs(textTags) do
        if t.permanent and not t.dead then live[#live + 1] = t end
    end
    return live
end
function SetTextTagText(t, s) assert(type(s) == 'string') end
function SetTextTagPos() end
function SetTextTagColor(t, r, g, b, a) int('SetTextTagColor', r) end
function SetTextTagVelocity() end
function SetTextTagPermanent(t, on) t.permanent = on end
function SetTextTagLifespan() end
function SetTextTagFadepoint() end
function SetTextTagVisibility() end
function DestroyTextTag(t) assert(t and t.__kind == 'texttag', 'DestroyTextTag on non-tag'); assert(not t.dead, 'text tag destroyed twice'); t.dead = true end

-- Abilities: icons and tooltips
function BlzGetAbilityIcon(id) return 'ReplaceableTextures\\CommandButtons\\BTN' .. code(id) .. '.blp' end
function BlzGetAbilityTooltip(id) return MOCK.tooltips[id] or 'Tooltip' end
function BlzSetAbilityTooltip(id, s) MOCK.tooltips[id] = s end

-- Preload file IO, emulated the way the game writes and reads these files.
local preload = {}
function PreloadGenClear() preload = {} end
function Preload(s) preload[#preload + 1] = s end
function PreloadGenEnd(path)
    local lines = {'function PreloadFiles takes nothing returns nothing', '', '\tcall PreloadStart()'}
    for _, s in ipairs(preload) do lines[#lines + 1] = '\tcall Preload( "' .. s .. '" )' end
    lines[#lines + 1] = '\tcall PreloadEnd( 0.0 )'
    lines[#lines + 1] = 'endfunction'
    MOCK.files[path] = table.concat(lines, '\n')
end
function Preloader(path)
    local text = MOCK.files[path]
    if not text then return end
    local code = text:match('//!beginusercode\n(.-)\n//!endusercode')
    assert(code, 'no usercode section in save file')
    local fn, err = load(code, 'preload')
    assert(fn, err)
    fn()
end

-- Frames
local frameCount = 0
local function frame(kind, name, parent)
    frameCount = frameCount + 1
    local f = handle('frame', {kind = kind, name = name, parent = parent, visible = true, text = '', n = frameCount,
        x = 0, top = 0, w = 0, h = 0, alpha = 255})
    MOCK.frames[#MOCK.frames + 1] = f
    return f
end
local origins = {}
function BlzGetOriginFrame(o) origins[o] = origins[o] or frame('ORIGIN', o.name); return origins[o] end
local named = {}
function BlzGetFrameByName(n) named[n] = named[n] or frame('NAMED', n); return named[n] end
function BlzCreateFrameByType(kind, name, parent, template, ctx) assert(parent, 'frame without parent'); return frame(kind, name, parent) end
function BlzHideOriginFrames() end
function BlzFrameSetAllPoints() end
function BlzFrameClearAllPoints() end
function BlzFrameSetAbsPoint(f, p, x, y) assert(type(x) == 'number' and type(y) == 'number'); f.x, f.top = x, y end
function BlzFrameSetSize(f, w, h) assert(w >= 0 and h >= 0, 'negative frame size'); f.w, f.h = w, h end
function BlzFrameSetText(f, s) assert(type(s) == 'string', 'frame text must be a string, got ' .. type(s)); f.text = s end
function BlzFrameSetTexture(f, t) assert(type(t) == 'string', 'texture'); f.texture = t end
function BlzFrameSetVertexColor() end
function BlzConvertColor(a, r, g, b) int('BlzConvertColor', a); int('BlzConvertColor', r); int('BlzConvertColor', g); int('BlzConvertColor', b); return 0 end
function BlzFrameSetVisible(f, v) assert(f, 'BlzFrameSetVisible nil'); f.visible = v end
function BlzFrameSetAlpha(f, a) int('BlzFrameSetAlpha', a); f.alpha = a end
function BlzFrameSetFont(f, file, size) assert(type(size) == 'number') end
function BlzFrameSetTextAlignment() end
function BlzFrameSetLevel(f, level) f.level = level end
function BlzFrameSetEnable() end

-- Simulation helpers
function MOCK.advance(seconds)
    local stop = MOCK.now + seconds
    while true do
        local nextT, nextTimer = nil, nil
        for t in pairs(MOCK.timers) do
            if t.active and (nextT == nil or t.due < nextT) then nextT, nextTimer = t.due, t end
        end
        if nextT == nil or nextT > stop then break end
        MOCK.now = nextT
        if nextTimer.period then nextTimer.due = nextTimer.due + math.max(nextTimer.period, 0.001)
        else nextTimer.active = false; MOCK.timers[nextTimer] = nil end
        MOCK.expired = nextTimer
        nextTimer.fn()
    end
    MOCK.now = stop
end

local function shown(f)
    while f do
        if not f.visible then return false end
        f = f.parent
    end
    return true
end
MOCK.shown = shown

-- Stacking as in the engine (SF_BuildTree): siblings by (level, creation
-- order), and a child above its parent. Returns true when a is above b.
local function chain(f)
    local list = {}
    while f do
        table.insert(list, 1, f)
        f = f.parent
    end
    return list
end
local function above(a, b)
    local ca, cb = chain(a), chain(b)
    for i = 1, math.min(#ca, #cb) do
        local x, y = ca[i], cb[i]
        if x ~= y then
            local lx, ly = x.level or 0, y.level or 0
            if lx ~= ly then return lx > ly end
            return x.n > y.n
        end
    end
    return #ca > #cb
end

local function strip(s) return (s:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')) end
MOCK.strip = strip

function MOCK.findText(pattern)
    for _, f in ipairs(MOCK.frames) do
        if f.kind == 'TEXT' and shown(f) and strip(f.text):find(pattern, 1, true) then return f end
    end
end

function MOCK.fireFrame(f, event)
    fire('frame', {frame = f, event = event, player = Player(0)}, function(ev) return ev.frame == f and ev.event == event end)
end

-- Click the topmost visible button covering the centre of a visible label.
function MOCK.click(pattern)
    local hit = nil
    local labels = {}
    for _, label in ipairs(MOCK.frames) do
        if label.kind == 'TEXT' and shown(label) and strip(label.text) == pattern then
            labels[#labels + 1] = label
        end
    end
    for _, label in ipairs(MOCK.frames) do
        if label.kind == 'TEXT' and shown(label) and strip(label.text):find(pattern, 1, true) then
            labels[#labels + 1] = label
        end
    end
    for _, label in ipairs(labels) do
        do
            local cx, cy = label.x + label.w / 2, label.top - label.h / 2
            for _, f in ipairs(MOCK.frames) do
                if f.kind == 'GLUETEXTBUTTON' and shown(f) and cx >= f.x and cx <= f.x + f.w and cy <= f.top and cy >= f.top - f.h
                    and (hit == nil or above(f, hit)) then
                    hit = f
                end
            end
            if hit then
                break
            end
        end
    end
    assert(hit, 'no button under: ' .. pattern)
    MOCK.fireFrame(hit, FRAMEEVENT_MOUSE_ENTER)
    MOCK.fireFrame(hit, FRAMEEVENT_CONTROL_CLICK)
    MOCK.fireFrame(hit, FRAMEEVENT_MOUSE_LEAVE)
end

-- Hover and click every visible button (exercises every handler).
function MOCK.pokeAll(skip)
    local list = {}
    for _, f in ipairs(MOCK.frames) do
        if f.kind == 'GLUETEXTBUTTON' and shown(f) then list[#list + 1] = f end
    end
    for _, f in ipairs(list) do
        if not (skip and skip(f)) then
            MOCK.fireFrame(f, FRAMEEVENT_MOUSE_ENTER)
            MOCK.fireFrame(f, FRAMEEVENT_MOUSE_LEAVE)
        end
    end
    return list
end

function MOCK.key(k, down)
    fire('key', {key = k, down = down, player = Player(0)}, function(ev) return ev.key == k and ev.down == down end)
end
function MOCK.tap(k) MOCK.key(k, true); MOCK.key(k, false) end
-- A right-click on the ground, as the hero's point order.
function MOCK.order(u, x, y)
    fire('order', {unit = u, x = x, y = y, player = Player(0)}, function(ev) return ev.player == u.owner end)
end

-- Sounds by label (spells whose art is silent).
function CreateSoundFromLabel(label, looping, is3D) assert(type(label) == 'string'); return handle('sound', {label = label}) end
function SetSoundPosition(snd, x, y, z) assert(type(x) == 'number' and type(y) == 'number') end
function StartSound(snd) MOCK.sounds = (MOCK.sounds or 0) + 1 end
function KillSoundWhenDone() end
