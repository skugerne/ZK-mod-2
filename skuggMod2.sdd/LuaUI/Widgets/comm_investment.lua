function widget:GetInfo()
    return {
        name      = "Comm Investment",
        desc      = "Shows the metal and time investment in your commander",
        author    = "skugerne",
        date      = "2023",
        license   = "GNU GPL, v2 or later",
        layer     = 10,   -- after unit_morph.lua ?
        enabled   = true,
    }
end

include("LuaRules/Configs/customcmds.h.lua")

local frame = 0
local totalFrame = 0
local trackedComms = {}
local trackedCommsLength = 0  -- for some reason the #-notation didn't work, meh

local Chili
local Window
local Label
local font -- dummy, need this to call GetTextWidth without looking up an instance
local fontSize = 14
local windowMain
local vsx,vsy = 0,0
local columnCenters = {}
local columnEdges = {}     -- should be one element shorter than columnCenters

local grey = {.5,.5,.5,1}
local white = {1,1,1,1}

function widget:GameFrame(n)
    frame = frame - 1
    totalFrame = totalFrame + 1
    if frame <= 0 then 
        frame = 11 -- just under 3 times per second (engine does 30 frames per second)
        for unitID, unitData in pairs(trackedComms) do
            Spring.Echo("GameFrame() color (r g b) " .. unitData.commProps.r .. "/" .. unitData.commProps.g .. "/" .. unitData.commProps.b)
            Spring.Echo("GameFrame() name " .. (unitData.commProps.name or "-"))       -- FIXME: nil for AIs
            Spring.Echo("GameFrame() rangeMult " .. unitData.commProps.rangeMult)
            Spring.Echo("GameFrame() damageMult " .. unitData.commProps.damageMult)
            Spring.Echo("GameFrame() speedMult " .. unitData.commProps.speedMult)
            Spring.Echo("GameFrame() commLevel " .. unitData.commProps.commLevel)
            Spring.Echo("GameFrame() commCost " .. unitData.commProps.commCost)
            Spring.Echo("GameFrame() teamID " .. unitData.commProps.teamID)
            Spring.Echo("GameFrame() allyTeamID " .. unitData.commProps.allyTeamID)

            unitData.labels.player:SetCaption((name or "-"))
            unitData.labels.level:SetCaption("L" .. (unitData.commProps.commLevel+1))
            unitData.labels.health:SetCaption(unitData.commProps.health)
            unitData.labels.rangeMult:SetCaption(string.format("%.2f",unitData.commProps.rangeMult))
            unitData.labels.damageMult:SetCaption(string.format("%.2f",unitData.commProps.damageMult))
            unitData.labels.speedMult:SetCaption(string.format("%.2f",unitData.commProps.speedMult))

            -- show color of commander (the wrong color)
            -- except for the problem with units being captured, could set label color during initialization
            local fontparams = {
                color = {r,g,b,1},
                size = fontSize,
                shadow = true
            }
            unitData.labels.unitID.font = Chili.Font:New(fontparams)
            unitData.labels.unitID:SetCaption(unitID)
            unitData.labels.totalCost:SetCaption(math.floor(trackedComms[unitID].investedMetal+trackedComms[unitID].uncommittedMetal+0.5) .. "m")
            unitData.labels.totalTime:SetCaption(math.floor((trackedComms[unitID].investedTime/30.0)+0.5) .. "s")
        end
    end
end

function rectangleVertices()
    gl.Vertex(0, -1, 0)  -- bottom left
    gl.Vertex(1, -1, 0)  -- bottom right
    gl.Vertex(1,  0, 0)  -- top right
    gl.Vertex(0,  0, 0)  -- top left
end

function lineVertices()
    gl.Vertex(0,  0, 0)  -- top
    gl.Vertex(0, -1, 0)  -- bottom
end

local rectangleDrawList = gl.CreateList(gl.BeginEnd, GL.LINE_LOOP, rectangleVertices)
local lineDrawList = gl.CreateList(gl.BeginEnd, GL.LINE_LOOP, lineVertices)

function widget:DrawScreenPost()
    if columnEdges ~= nil then
        local screenWidth, screenHeight = Spring.GetViewGeometry()
        gl.LineWidth(1)
        gl.DepthTest(false)

        gl.Color(1,1,0,1)
        gl.PushMatrix()
        gl.Translate(windowMain.x, screenHeight - windowMain.y, 1)
        gl.Scale(windowMain.width,windowMain.height,1)
        gl.CallList(rectangleDrawList)
        gl.PopMatrix()

        gl.Color(1,0,0,1)
        for idx = 1, #columnEdges do
            gl.PushMatrix()
            gl.Translate(windowMain.x + columnEdges[idx], screenHeight - windowMain.y, 1)
            gl.Scale(1,windowMain.height,1)
            gl.CallList(lineDrawList)
            gl.PopMatrix()
        end
    end
end

function generateLabelObject(row, col, txt, color)
    local extra = 5
    if row == 1 then extra = -5 end
    return Label:New {
        parent = windowMain,
        x = columnCenters[col],
        y = 10 + (15 * (row - 1)) + extra,    -- vertical axis
        font = {
            color = color,
            size = fontSize,
            shadow = true
        },
        caption = txt,
        align = 'center',
        autosize = false                   -- if this is true, text can wander over time
    }
end

function widget:Initialize()
    Chili = WG.Chili;
    if (not Chili) then
        Spring.Echo("No Chili!")
        widgetHandler:RemoveWidget()
        return
    end

    Window = Chili.Window
    Label = Chili.Label
    Image = Chili.Image
    font = Chili.Font:New{} -- need this to call GetTextWidth without looking up an instance

    if Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget()
    end

    -- register our functions so that unit_morph.lua can send us updates
    widgetHandler:RegisterGlobal('CommInvestMorphUpdate', CommInvestMorphUpdate)
    widgetHandler:RegisterGlobal('CommInvestMorphFinished', CommInvestMorphFinished)
    widgetHandler:RegisterGlobal('CommInvestMorphStart', CommInvestMorphStart)
    widgetHandler:RegisterGlobal('CommInvestMorphStop', CommInvestMorphStop)

    local screenWidth, screenHeight = Spring.GetViewGeometry()
    local w = screenWidth * 0.4
    local h = 60

    windowMain = Window:New{
		color = {1,1,1,0.8},
		parent = Chili.Screen0,
		dockable = true,
		dockableSavePositionOnly = true,
		name = "CommInvestment",
		classname = "main_window_small_very_flat",
		padding = {0,0,0,0},
		margin = {0,0,0,0},
		x = vsx-w, -- these are retained between games, suitable initial values mysterious
		y = 100,   -- these are retained between games, suitable initial values mysterious
		width = w,
		height = h,
		draggable = true,
		resizable = false,
		tweakDraggable = true,
		tweakResizable = false,
		parentWidgetName = Chili.Screen0
	}

    Spring.Echo("CommInvestment windowMain.width:        " .. windowMain.width)
    Spring.Echo("CommInvestment windowMain.height:       " .. windowMain.height)
    Spring.Echo("CommInvestment windowMain.x:            " .. windowMain.x)
    Spring.Echo("CommInvestment windowMain.y:            " .. windowMain.y)
    Spring.Echo("CommInvestment windowMain.clientWidth:  " .. windowMain.clientWidth)
    Spring.Echo("CommInvestment windowMain.clientHeight: " .. windowMain.clientHeight)

    local headerNames = {
        'unitID',
        'player',
        'level',
        'cost',
        'time',
        'health',
        'rng mul',
        'dmg mul',
        'spd mul'
    }

    local textWidths = {}
    local totalTxtLen = 0
    for idx = 1, #headerNames do
        local colTxtLen = font:GetTextWidth(headerNames[idx], fontSize)
        textWidths[idx] = colTxtLen
        Spring.Echo("CommInvestment txt W:                   " .. colTxtLen)
        totalTxtLen = totalTxtLen + colTxtLen
    end
    local whitespace = (w - totalTxtLen) / #headerNames

    Spring.Echo("CommInvestment total text len:          " .. totalTxtLen)
    Spring.Echo("CommInvestment whitespace:              " .. whitespace)
    Spring.Echo("CommInvestment num header names:        " .. #headerNames)

    local accumulator = 0
    for idx = 1, #headerNames do
        local colWid = whitespace + textWidths[idx]
        columnCenters[idx] = accumulator
        Spring.Echo("CommInvestment col C:                   " .. columnCenters[idx])
        accumulator = accumulator + colWid
        columnEdges[idx] = accumulator
        generateLabelObject(1, idx, headerNames[idx], white)
    end

    columnEdges[#columnEdges] = nil
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('CommInvestMorphUpdate', CommInvestMorphUpdate)
	widgetHandler:DeregisterGlobal('CommInvestMorphFinished', CommInvestMorphFinished)
	widgetHandler:DeregisterGlobal('CommInvestMorphStart', CommInvestMorphStart)
	widgetHandler:DeregisterGlobal('CommInvestMorphStop', CommInvestMorphStop)
	if windowMain then windowMain:Dispose() end
end

function widget:ViewResize(vsx_, vsy_)
    Spring.Echo("Got a call to ViewResize.")
	vsx = vsx_
	vsy = vsy_
end

function CommInvestMorphUpdate(morphTable)
    Spring.Echo("Got a call to CommInvestMorphUpdate.")
    for unitID, morphData in pairs(morphTable) do
        Spring.Echo("Have progress " .. morphData.progress .. " for unitID " .. unitID .. ".")
        if trackedComms[unitID] == nil then
            Spring.Echo("FROWN: An unknown upgrade is in progress.")
        else
            trackedComms[unitID].progess = morphData.progress
            trackedComms[unitID].investedTime = trackedComms[unitID].investedTime +  totalFrame - trackedComms[unitID].upgradeStatusAt
            trackedComms[unitID].upgradeStatusAt = totalFrame
            trackedComms[unitID].uncommittedMetal = morphData.morphDef.metal * morphData.progress
        end
    end
end

function CommInvestMorphStart(unitID, commProps)
    -- it appears that sometimes this is called for an replaced (no longer valid) comm unitID
    Spring.Echo("Got a call to CommInvestMorphStart, unitID=" .. unitID .. ".")
    if trackedComms[unitID] == nil then
        trackedCommsLength = trackedCommsLength + 1
        Spring.Echo("Initialize a dyncomm tracking record, unitID=" .. unitID)
        local col = trackedCommsLength+1
        trackedComms[unitID] = {
            investedMetal = 0,
            uncommittedMetal = 0,
            investedTime = 0,
            index = trackedCommsLength,
            commProps = commProps,
            labels = {
                unitID =     generateLabelObject(col, 1, unitID, white),
                player =     generateLabelObject(col, 2, '-', grey),
                level =      generateLabelObject(col, 3, '-', grey),
                totalCost =  generateLabelObject(col, 4, '-', grey),
                totalTime =  generateLabelObject(col, 5, '-', grey),
                health =     generateLabelObject(col, 6, '-', grey),
                rangeMult =  generateLabelObject(col, 7, '-', grey),
                damageMult = generateLabelObject(col, 8, '-', grey),
                speedMult =  generateLabelObject(col, 9, '-', grey)
            }
        }
        windowMain:Resize(nil, (15 * trackedCommsLength) + 45)
    end

    if trackedComms[unitID].upgradeStatusAt then
        Spring.Echo("FROWN: An upgrade is started on top of another upgrade.")
    else
        trackedComms[unitID].upgradeStatusAt = totalFrame
        trackedComms[unitID].uncommittedMetal = 0
    end
end

function CommInvestMorphStop(unitID, refundMetal)
    Spring.Echo("Got a call to CommInvestMorphStop, unitID=" .. unitID .. ", refundMetal=" .. refundMetal .. ".")
    if trackedComms[unitID] == nil then
        Spring.Echo("FROWN: An unknown upgrade has been stopped.")
    else
        trackedComms[unitID].investedTime = trackedComms[unitID].investedTime + totalFrame - trackedComms[unitID].upgradeStatusAt
        trackedComms[unitID].upgradeStatusAt = nil
        trackedComms[unitID].progess = nil
        trackedComms[unitID].investedMetal = math.floor(trackedComms[unitID].investedMetal + trackedComms[unitID].uncommittedMetal - refundMetal + 0.5)
        trackedComms[unitID].uncommittedMetal = 0
    end
end

function CommInvestMorphFinished(oldUnitID, newUnitID, commProps)
    Spring.Echo("Got a call to CommInvestMorphFinished, oldUnitID=" .. oldUnitID .. ", newUnitID=" .. newUnitID .. ".")
    CommInvestMorphStop(oldUnitID, 0)
    if trackedComms[newUnitID] == nil then
        trackedComms[newUnitID] = trackedComms[oldUnitID]
        trackedComms[oldUnitID] = nil
        Spring.Echo("Deleted unitID=" .. oldUnitID .. "from list of tracked comms.")
        trackedComms[newUnitID].commProps = commProps
    else
        Spring.Echo("FROWN: A known unitID been given as a new unitID.")
    end
end
