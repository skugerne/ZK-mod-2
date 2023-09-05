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
end

-- new dyn comms are created after upgrades
-- mostly we don't care, but we will perform the original initialization of our list from this event
-- (NOTE: this does not capture comms on other teams)
function widget:UnitCreated(unitID, unitDefID, unitTeam)

    -- only pay attention to unit creation at the startup or we can capture comm upgrades
    if totalFrame > 0 then
        return
    end

    local unitdef = UnitDefs[unitDefID]
    if unitdef and unitdef.customParams and unitdef.customParams.dynamic_comm then
        if trackedComms[unitID] == nil then
            trackedCommsLength = trackedCommsLength + 1
            Spring.Echo("Initialize a dyncomm, unitID " .. unitID)
            trackedComms[unitID] = {invested_metal = 0, invested_time = 0, index = trackedCommsLength}
            local y = 10 + (15 * (trackedCommsLength - 1))
            trackedComms[unitID].labels = {
                labelUnitID = Label:New {
                    parent = windowMain,
                    x = (windowMain.width / 4) - (font:GetTextWidth('---', 20) / 2),
                    y = y,
                    fontSize = 14,
                    textColor = white,
                    caption = '---',
                },
                labelTotalCost = Label:New {
                    parent = windowMain,
                    x = (windowMain.width / 2) - (font:GetTextWidth('---', 20) / 2),
                    y = y,
                    fontSize = 14,
                    textColor = grey,
                    caption = '---',
                },
                labelTotalTime = Label:New {
                    parent = windowMain,
                    x = (3 * windowMain.width / 4) - (font:GetTextWidth('---', 20) / 2),
                    y = y,
                    fontSize = 14,
                    textColor = grey,
                    caption = '---',
                }
            }
        end
    end
end

-- old dyn comms are destroyed after upgrade
-- mostly we don't care, but we will mark comms as dead in case if wasn't just an upgrade
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

function CommInvestMorphUpdate(morphTable)
    Spring.Echo("Got a call to CommInvestMorphUpdate.")
    for unitID, morphData in pairs(morphTable) do
        Spring.Echo("Have progress " .. morphData.progress .. " for unitID " .. unitID .. ".")
        if trackedComms[unitID] == nil then
            Spring.Echo("FROWN: An unknown upgrade is in progress.")
        else
            trackedComms[unitID].progess = morphData.progress
            trackedComms[unitID].invested_time = trackedComms[unitID].invested_time +  totalFrame - trackedComms[unitID].upgradeStarted
            trackedComms[unitID].upgradeStarted = totalFrame
            trackedComms[unitID].invested_metal = trackedComms[unitID].invested_metal + 0
            Spring.Echo("The morphDef:")
            for k, v in pairs(morphData.morphDef) do
                if type(v) == 'table' then
                    Spring.Echo("  -- " .. k)
                    for k2, v2 in pairs(v) do
                        if type(v2) == 'table' then
                            Spring.Echo("    -- " .. k2)
                            for k3, v3 in pairs(v2) do
                                Spring.Echo("      -- " .. k3 .. " = " .. tostring(v3))
                            end
                        else
                            Spring.Echo("    -- " .. k2 .. " = " .. tostring(v2))
                        end
                    end
                else
                    Spring.Echo("  -- " .. k .. " = " .. tostring(v))
                end
            end
        end
    end
end

function CommInvestMorphStart(unitID)
    Spring.Echo("Got a call to CommInvestMorphStart, unitID=" .. unitID .. ".")
    if trackedComms[unitID] == nil then
        Spring.Echo("FROWN: Got a start for an un-initialized comm.")
    else
        if trackedComms[unitID].upgradeStarted then
            Spring.Echo("FROWN: An upgrade is started on top of another upgrade.")
        else
            trackedComms[unitID].upgradeStarted = totalFrame
        end
    end
end

function CommInvestMorphStop(unitID, refundMetal)
    Spring.Echo("Got a call to CommInvestMorphStop, unitID=" .. unitID .. ", refundMetal=" .. refundMetal .. ".")
    if trackedComms[unitID] == nil then
        Spring.Echo("FROWN: An unknown upgrade has been stopped.")
    else
        trackedComms[unitID].invested_time = trackedComms[unitID].invested_time + totalFrame - trackedComms[unitID].upgradeStarted
        trackedComms[unitID].upgradeStarted = nil
        trackedComms[unitID].progess = nil
        trackedComms[unitID].invested_metal = trackedComms[unitID].invested_metal - refundMetal
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