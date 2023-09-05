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
local windowMain

local red = {1,0,0,1}
local green = {0,1,0,1}
local blue = {.2,.2,1,1}
local grey = {.5,.5,.5,1}
local white = {1,1,1,1}

function CreateWindow()

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
		clientHeight = 65,
		minHeight = 65,
		maxHeight = 65,
		minWidth = 250,
		draggable = true,
		resizable = true,
		tweakDraggable = true,
		tweakResizable = true,
		parentWidgetName = widget:GetInfo().name, --for gui_chili_docking.lua (minimize function)
	}
end

-- new dyn comms are created after upgrades
function widget:UnitCreated(unitID, unitDefID, unitTeam)
    Spring.Echo("comm widget sees unitId " .. unitID .. " is created")
--    if localTeamID == unitTeam and UnitDefs then
--        local unitDef = UnitDefs[unitDefID]
--        if unitDef and unitDef.customParams and unitDef.customParams.dynamic_comm then
--            Spring.Echo("comm widget: new unit is a dyn comm with the right team")
--            trackedComms[unitID] = true
--        end
--    end
end

-- old dyn comms are destroyed after upgrade
function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    Spring.Echo("comm widget sees unitId " .. unitID .. " was destroyed")
    if trackedComms[unitID] then
        trackedComms[unitID]['unit_destroyed'] = true
    end
--   if localTeamID == unitTeam and UnitDefs then
--       local unitDef = UnitDefs[unitDefID]
--       if unitDef and unitDef.customParams and unitDef.customParams.dynamic_comm then
--           Spring.Echo("comm widget: dead unit was a dyn comm with the right team")
--           trackedComms[unitID] = nil
--       end
--   end
end

function widget:GameFrame(n)
    frame = frame - 1
    totalFrame = totalFrame + 1
    if frame <= 0 then 
        frame = 7 -- just over 4 times per second (engine does 30 frames per second)
        for unitID, unitData in pairs(trackedComms) do
            unitData.labels.labelUnitID:SetCaption(unitID)
            unitData.labels.labelTotalCost:SetCaption(trackedComms[unitID].invested_metal)
            unitData.labels.labelTotalTime:SetCaption(trackedComms[unitID].invested_time)
        end
    end
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

    Spring.Echo("Set up our window...")
    CreateWindow()
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('CommInvestMorphUpdate', CommInvestMorphUpdate)
	widgetHandler:DeregisterGlobal('CommInvestMorphFinished', CommInvestMorphFinished)
	widgetHandler:DeregisterGlobal('CommInvestMorphStart', CommInvestMorphStart)
	widgetHandler:DeregisterGlobal('CommInvestMorphStop', CommInvestMorphStop)
	if windowMain then windowMain:Dispose() end
end

-- changing teams, rejoin, becoming spec etc
--function widget:PlayerChanged (playerID)
--    if spGetSpectatingState() then
--        widgetHandler:RemoveWidget()
--    end
--    localTeamID = Spring.GetLocalTeamID ()
--end

function CommInvestMorphUpdate(morphTable)
	Spring.Echo("Got a call to CommInvestMorphUpdate.")
    for unitID, morphData in pairs(morphTable) do
        Spring.Echo("Have progress " .. morphData.progress .. " for unitID " .. unitID .. ".")
        if trackedComms[unitID] == nil then
            Spring.Echo("FROWN: An unknown upgrade is in progress.")
        else
            trackedComms[unitID].progess = morphData.progress
            trackedComms[unitID].invested_time = trackedComms[unitID].invested_time +  totalFrame - trackedComms[unitID].upgrade_started
            trackedComms[unitID].upgrade_started = totalFrame
            trackedComms[unitID].invested_metal = trackedComms[unitID].invested_metal + 0
        end
    end
end

function CommInvestMorphStart(unitID)
	Spring.Echo("Got a call to CommInvestMorphStart, unitID=" .. unitID .. ".")
    if trackedComms[unitID] == nil then
        Spring.Echo("There are currently " .. trackedCommsLength .. " elements in our comm tracking list.")
        trackedCommsLength = trackedCommsLength + 1
        local y = 15 + (10 * (trackedCommsLength - 1))
        trackedComms[unitID] = {upgrade_started = totalFrame, invested_metal = 0, invested_time = 0}
        trackedComms[unitID].labels = {
            labelUnitID = Label:New {
                parent = windowMain,
                x = (windowMain.width / 4) - (font:GetTextWidth('---', 20) / 2),
                y = y,
                fontSize = 20,
                textColor = white,
                caption = '---',
            },
            labelTotalCost = Label:New {
                parent = windowMain,
                x = (windowMain.width / 2) - (font:GetTextWidth('---', 20) / 2),
                y = y,
                fontSize = 20,
                textColor = grey,
                caption = '---',
            },
            labelTotalTime = Label:New {
                parent = windowMain,
                x = (3 * windowMain.width / 4) - (font:GetTextWidth('---', 20) / 2),
                y = y,
                fontSize = 20,
                textColor = grey,
                caption = '---',
            }
        }
    else
        if trackedComms[unitID].upgrade_started then
            Spring.Echo("FROWN: An upgrade is started on top of another upgrade.")
        else
            trackedComms[unitID].upgrade_started = totalFrame
        end
    end
end

function CommInvestMorphStop(unitID, refundMetal)
	Spring.Echo("Got a call to CommInvestMorphStop, unitID=" .. unitID .. ", refundMetal=" .. refundMetal .. ".")
    if trackedComms[unitID] == nil then
        Spring.Echo("FROWN: An unknown upgrade has been stopped.")
    else
        trackedComms[unitID].invested_time = trackedComms[unitID].invested_time + totalFrame - trackedComms[unitID].upgrade_started
        trackedComms[unitID].upgrade_started = nil
        trackedComms[unitID].progess = nil
        trackedComms[unitID].invested_metal = trackedComms[unitID].invested_metal - refundMetal
    end
end

function CommInvestMorphFinished(oldUnitID, newUnitID)
	Spring.Echo("Got a call to CommInvestMorphStop, oldUnitID=" .. oldUnitID .. ", newUnitID=" .. newUnitID .. ".")
    CommInvestMorphStop(oldUnitID, 0)
    if trackedComms[newUnitID] == nil then
        trackedComms[newUnitID] = trackedComms[oldUnitID]
        trackedComms[oldUnitID] = nil
    else
        Spring.Echo("FROWN: A known unitID been given as a new unitID.")
    end
end