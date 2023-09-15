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

local spGetSpectatingState	= Spring.GetSpectatingState

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
local columnCenters = {}

local red = {1,0,0,1}
local green = {0,1,0,1}
local blue = {.2,.2,1,1}
local grey = {.5,.5,.5,1}
local white = {1,1,1,1}

-- new dyn comms are created after upgrades
-- mostly we don't care, but we will perform the original initialization of our list from this event
-- (NOTE: this does not capture comms on other teams, at least if we don't see the event)
function widget:UnitCreated(unitID, unitDefID, unitTeam)
    local unitdef = UnitDefs[unitDefID]
    if unitdef and unitdef.customParams and unitdef.customParams.dynamic_comm then
        Spring.Echo("A dyncomm is created, unitID " .. unitID)
    end
end

-- old dyn comms are destroyed after upgrade
-- mostly we don't care, but we will mark comms as dead in case if wasn't just an upgrade
-- (NOTE: this does not capture comms on other teams, at least if we don't see the event)
function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    if trackedComms[unitID] then
        Spring.Echo("A dyncomm is dead, unitID " .. unitID)
        trackedComms[unitID]['unit_destroyed'] = true
    end
end

function widget:GameFrame(n)
    frame = frame - 1
    totalFrame = totalFrame + 1
    if frame <= 0 then 
        frame = 7 -- just over 4 times per second (engine does 30 frames per second)
        for unitID, unitData in pairs(trackedComms) do
            local unitDefID = Spring.GetUnitDefID(unitID)
            local unitdef = unitDefID and UnitDefs[unitDefID]
            if unitdef ~= nil then
                local teamID = Spring.GetUnitTeam(unitID)
                local r, g, b = Spring.GetTeamColor(teamID)
                local _, playerID, _, isAI, side_, allyTeamID = Spring.GetTeamInfo(teamID, false)
                --local teamNum, leader, dead, isAI, side, allyTeam = Spring.GetTeamInfo(teamID)
                if isAI then
                    Spring.Echo("Is an AI  ..... ")
                    local name = select(2, Spring.GetAIInfo(teamID))
                else
                    Spring.Echo("Is a player ......")
                    --local teamName = Spring.GetPlayerInfo(playerID, false)
                    local name, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country = Spring.GetPlayerInfo(playerID)
                end

                local rangeMult = Spring.GetUnitRulesParam(unitID, "comm_range_mult") or 1
                local damageMult = Spring.GetUnitRulesParam(unitID, "comm_damage_mult") or 1
                local speedMult = Spring.GetUnitRulesParam(unitID, "upgradesSpeedMult") or 1
                local commLevel = Spring.GetUnitRulesParam(unitID, "comm_level") or 0
                local commCost = Spring.GetUnitRulesParam(unitID, "comm_cost") or 0

                Spring.Echo("side " .. (side or "-"))
                Spring.Echo("country " .. (country or "-"))
                Spring.Echo("color (r g b) " .. r .. "/" .. g .. "/" .. b)
                Spring.Echo("name " .. (name or "-"))
                Spring.Echo("rangeMult " .. rangeMult)
                Spring.Echo("damageMult " .. damageMult)
                Spring.Echo("speedMult " .. speedMult)
                Spring.Echo("commLevel " .. commLevel)
                Spring.Echo("commCost " .. commCost)
                Spring.Echo("unitID " .. unitID)
                Spring.Echo("unitDefID " .. unitDefID)
                Spring.Echo("teamID " .. teamID)
                Spring.Echo("allyTeamID " .. allyTeamID)

                --unitData.color = {r,g,b,1}
                --unitData.labels.unitID.textColor = {r,g,b,1}
                unitData.labels.unitID:SetCaption(unitID)
                --unitData.labels.level:SetCaption(commLevel)
                unitData.labels.totalCost:SetCaption(math.floor(trackedComms[unitID].investedMetal+trackedComms[unitID].uncommittedMetal+0.5) .. "m")
                unitData.labels.totalTime:SetCaption(math.floor((trackedComms[unitID].investedTime/30.0)+0.5) .. "s")
                --unitData.labels.rangeMult:SetCaption(rangeMult)
                --unitData.labels.damageMult:SetCaption(damageMult)
                --unitData.labels.speedMult:SetCaption(speedMult)
            end
        end
    end
end

function generateLabelObject(row, col, txt, color)
    return Label:New {
        parent = windowMain,
        x = columnCenters[col] - (font:GetTextWidth(txt, fontSize) / 2),
        y = 10 + (15 * (row - 1)),
        fontSize = fontSize,
        textColor = color,
        caption = txt,
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

    if spGetSpectatingState() then
        widgetHandler:RemoveWidget()
    end

    -- register our functions so that unit_morph.lua can send us updates
	widgetHandler:RegisterGlobal('CommInvestMorphUpdate', CommInvestMorphUpdate)
	widgetHandler:RegisterGlobal('CommInvestMorphFinished', CommInvestMorphFinished)
	widgetHandler:RegisterGlobal('CommInvestMorphStart', CommInvestMorphStart)
	widgetHandler:RegisterGlobal('CommInvestMorphStop', CommInvestMorphStop)

    windowMain = Window:New{
		color = {1,1,1,0.8},
		parent = Chili.Screen0,
		dockable = true,
		dockableSavePositionOnly = true,
		name = "CommInvestment",
		classname = "main_window_small_very_flat",
		padding = {0,0,0,0},
		margin = {0,0,0,0},
		right = 0,
		y = "30%",
		height = 60,
		clientWidth  = 400,
		clientHeight = 60,
		minHeight = 60,
		maxHeight = 200,
		minWidth = 250,
		draggable = true,
		resizable = true,
		tweakDraggable = true,
		tweakResizable = true,
		parentWidgetName = widget:GetInfo().name, --for gui_chili_docking.lua (minimize function)
	}

    local numColumns = 4
    for idx = 1,numColumns do
        Spring.Echo("Initialize column " .. idx)
        columnCenters[idx] = idx * windowMain.width / (numColumns+1)
    end

    -- header row, static
    generateLabelObject(1, 1, 'unitID', white)
    generateLabelObject(1, 2, 'cost', white)
    generateLabelObject(1, 3, 'time', white)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('CommInvestMorphUpdate', CommInvestMorphUpdate)
	widgetHandler:DeregisterGlobal('CommInvestMorphFinished', CommInvestMorphFinished)
	widgetHandler:DeregisterGlobal('CommInvestMorphStart', CommInvestMorphStart)
	widgetHandler:DeregisterGlobal('CommInvestMorphStop', CommInvestMorphStop)
	if windowMain then windowMain:Dispose() end
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
            --Spring.Echo("The morphDef:")
            --for k, v in pairs(morphData.morphDef) do
            --    if type(v) == 'table' then
            --        Spring.Echo("  -- " .. k)
            --        for k2, v2 in pairs(v) do
            --            if type(v2) == 'table' then
            --                Spring.Echo("    -- " .. k2)
            --                for k3, v3 in pairs(v2) do
            --                    Spring.Echo("      -- " .. k3 .. " = " .. tostring(v3))
            --                end
            --            else
            --                Spring.Echo("    -- " .. k2 .. " = " .. tostring(v2))
            --            end
            --        end
            --    else
            --        Spring.Echo("  -- " .. k .. " = " .. tostring(v))
            --    end
            --end
        end
    end
end

function CommInvestMorphStart(unitID)
    Spring.Echo("Got a call to CommInvestMorphStart, unitID=" .. unitID .. ".")
    if trackedComms[unitID] == nil then
        trackedCommsLength = trackedCommsLength + 1
        Spring.Echo("Initialize a dyncomm, unitID " .. unitID)
        trackedComms[unitID] = {investedMetal = 0, uncommittedMetal = 0, investedTime = 0, index = trackedCommsLength}
        --local y = 10 + (15 * (trackedCommsLength - 1))
        trackedComms[unitID].labels = {
            unitID = generateLabelObject(trackedCommsLength+1, 1, unitID, white),
            totalCost = generateLabelObject(trackedCommsLength+1, 2, '---', grey),
            totalTime = generateLabelObject(trackedCommsLength+1, 3, '---', grey)
        }
        --trackedComms[unitID].labels = {
        --    unitID = Label:New {
        --        parent = windowMain,
        --        x = (windowMain.width / 4) - (font:GetTextWidth('---', 20) / 2),
        --        y = y,
        --        fontSize = 14,
        --        textColor = white,
        --        caption = '---',
        --    },
        --    totalCost = Label:New {
        --        parent = windowMain,
        --        x = (windowMain.width / 2) - (font:GetTextWidth('---', 20) / 2),
        --        y = y,
        --        fontSize = 14,
        --        textColor = grey,
        --        caption = '---',
        --    },
        --    totalTime = Label:New {
        --        parent = windowMain,
        --        x = (3 * windowMain.width / 4) - (font:GetTextWidth('---', 20) / 2),
        --        y = y,
        --        fontSize = 14,
        --        textColor = grey,
        --        caption = '---',
        --    }
        --}

        windowMain:Resize(nil, (15 * trackedCommsLength) + 35)
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

function CommInvestMorphFinished(oldUnitID, newUnitID)
    Spring.Echo("Got a call to CommInvestMorphFinished, oldUnitID=" .. oldUnitID .. ", newUnitID=" .. newUnitID .. ".")
    CommInvestMorphStop(oldUnitID, 0)
    if trackedComms[newUnitID] == nil then
        trackedComms[newUnitID] = trackedComms[oldUnitID]
        trackedComms[oldUnitID] = nil
    else
        Spring.Echo("FROWN: A known unitID been given as a new unitID.")
    end
end