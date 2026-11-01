-- Test aid: every hero's lobby preview model in one grid, framed like the
-- lobby's portrait (same frame size). Run alone as wc3_lua_script with
-- +screenshot; it replaces the map's main.
local IDS = {'Hamg', 'Hmkg', 'Hpal', 'Hblm', 'Obla', 'Ofar', 'Otch', 'Oshd',
    'Udea', 'Udre', 'Ulic', 'Ucrl', 'Edem', 'Ekee', 'Emoo', 'Ewar',
    'Nngs', 'Nbrn', 'Nbst', 'Npbm', 'Nfir', 'Ntin', 'Nalc', 'Nplh', 'nmed'}

function main()
    InitBlizzard()
    BlzHideOriginFrames(true)
    local game = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
    local back = BlzCreateFrameByType('BACKDROP', 'TMback', game, '', 0)
    BlzFrameSetAbsPoint(back, FRAMEPOINT_TOPLEFT, -0.2, 0.6)
    BlzFrameSetSize(back, 1.2, 0.6)
    BlzFrameSetTexture(back, 'UI\\Glues\\MainMenu\\MainMenu3D\\white32.blp', 0, true)
    BlzFrameSetVertexColor(back, BlzConvertColor(255, 40, 30, 24))
    for i, id in ipairs(IDS) do
        local col = math.fmod(i - 1, 9)
        local row = (i - 1) // 9
        local x, top = -0.125 + col * 0.116, 0.59 - row * 0.195
        local cell = BlzCreateFrameByType('BACKDROP', 'TMcell' .. i, game, '', 0)
        BlzFrameSetAbsPoint(cell, FRAMEPOINT_TOPLEFT, x, top)
        BlzFrameSetSize(cell, 0.112, 0.142)
        BlzFrameSetTexture(cell, 'UI\\Glues\\MainMenu\\MainMenu3D\\white32.blp', 0, true)
        BlzFrameSetVertexColor(cell, BlzConvertColor(255, 8, 8, 8))
        local model = BlzCreateFrameByType('SPRITE', 'TMmodel' .. i, game, '', 0)
        BlzFrameSetAbsPoint(model, FRAMEPOINT_TOPLEFT, x, top)
        BlzFrameSetSize(model, 0.112, 0.142)
        BlzFrameSetModel(model, EngineUnitModel(FourCC(id)), 0)
        local label = BlzCreateFrameByType('TEXT', 'TMlabel' .. i, game, '', 0)
        BlzFrameSetAbsPoint(label, FRAMEPOINT_TOPLEFT, x, top - 0.145)
        BlzFrameSetSize(label, 0.112, 0.014)
        BlzFrameSetText(label, id)
    end
end
