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
local upgradeFrameCounter = 0
local upgradeStarted = nil
local localTeamID = Spring.GetLocalTeamID()
local trackedComms = {}

local Chili
local Window
local Label
local font -- dummy, need this to call GetTextWidth without looking up an instance
local windowMain
local labelTotalCost

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
		resizable = false,
		tweakDraggable = true,
		tweakResizable = true,
		parentWidgetName = widget:GetInfo().name, --for gui_chili_docking.lua (minimize function)
	}

    labelTotalCost = Label:New {
		parent = windowMain,
		x = (windowMain.width / 2) - (font:GetTextWidth('---', 30) / 2),
		y = 15,
		fontSize = 30,
		textColor = grey,
		caption = '---',
	}
	
	--if WG.GlobalCommandBar then
	--	local function ToggleWindow()
	--		if windowMain then
	--			windowMain:SetVisibility(not windowMain.visible)
	--		end
	--	end
	--	global_command_button = WG.GlobalCommandBar.AddCommand("LuaUI/Images/AttritionCounter/Skull.png", "", ToggleWindow)
	--end
end

-- new dyn comms are created after upgrades
function widget:UnitCreated(unitID, unitDefID, unitTeam)
    Spring.Echo("comm widget sees unitId " .. unitID .. " is created")
    if localTeamID == unitTeam and UnitDefs then
        local unitDef = UnitDefs[unitDefID]
        if unitDef and unitDef.customParams and unitDef.customParams.dynamic_comm then
            Spring.Echo("comm widget: new unit is a dyn comm with the right team")
            trackedComms[unitID] = true
        end
    end
end

-- old dyn comms are destroyed after upgrade
function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    Spring.Echo("comm widget sees unitId " .. unitID .. " was destroyed")
    if localTeamID == unitTeam and UnitDefs then
        local unitDef = UnitDefs[unitDefID]
        if unitDef and unitDef.customParams and unitDef.customParams.dynamic_comm then
            Spring.Echo("comm widget: dead unit was a dyn comm with the right team")
            trackedComms[unitID] = nil
        end
    end
end

--local function tableprint(t)
--    local res = ""
--    for k,v in pairs(t) do
--        if type(v) == "boolean" then
--            if v then v = "true" else v = "false" end
--        end
--        if v == nil then v = "nil" end
--        res = res .. ";" .. k .. "=" .. v
--    end
--    return res
--end

-- SendToUnsynced("unit_morph_start", unitID, unitDefID, morphDef.cmd)
-- SendToUnsynced("unit_morph_stop", unitID)
-- SendToUnsynced("unit_morph_finished", unitID, newUnit)

--function talkaboutcommand(unitDefId, cmdID)
--    -- turns out that GG is only available for gadgets (there is a WG for widgets)
--    if GG and GG.MorphInfo then
--        if GG.MorphInfo[unitDefId] then
--            Spring.Echo("This unit can morph (unitDefId " .. unitDefId .. ").")
--        else
--            Spring.Echo("This unit can NOT morph (unitDefId " .. unitDefId .. ").")
--        end
--
--        if GG.MorphInfo[cmdID] then
--            Spring.Echo("This command is associated with morphing (cmdID " .. cmdID .. ").")
--        else
--            Spring.Echo("This command is NOT associated with morphing (cmdID " .. cmdID .. ").")
--        end
--    else
--        Spring.Echo("GG or GG.MorphInfo is not available.")
--    end
--end

--function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams)
--    if trackedComms[unitID] then
--        Spring.Echo("comm widget: UnitCommand for a commander we are tracking")
--        Spring.Echo("comm widget: cmdID=" .. (cmdID or "nil"))
--        Spring.Echo("comm widget: cmdOpts=" .. (tableprint(cmdOpts) or "{}"))
--        Spring.Echo("comm widget: cmdParams=" .. (tableprint(cmdParams) or "{}"))
--        --talkaboutcommand(unitDefId, cmdID)
--    end
--end

--function widget:UnitCommandNotify(unitID, cmdID, cmdParams)
--    if trackedComms[unitID] then
--        Spring.Echo("comm widget: UnitCommandNotify for a commander we are tracking")
--        Spring.Echo("comm widget: cmdID=" .. (cmdID or "nil"))
--        Spring.Echo("comm widget: cmdParams=" .. (tableprint(cmdParams) or "{}"))
--    end
--end

function widget:GameFrame(n)
    frame = frame - 1
    totalFrame = totalFrame + 1
    if frame <= 0 then 
        frame = 15 -- twice per second (engine does 30 frames per second)
        labelTotalCost:SetCaption(totalFrame)
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

	WG['CommInvestMorphStart'] = CommInvestMorphStart
    WG['CommInvestMorphStop'] = CommInvestMorphStop

    Spring.Echo("Set up our window...")
    CreateWindow()
end

function widget:Shutdown()
    WG['CommInvestMorphStart'] = nil
    WG['CommInvestMorphStop'] = nil
	if windowMain then windowMain:Dispose() end
end

-- changing teams, rejoin, becoming spec etc
function widget:PlayerChanged (playerID)
    if spGetSpectatingState() then
        widgetHandler:RemoveWidget()
    end
    localTeamID = Spring.GetLocalTeamID ()
end

function CommInvestMorphStart(unitID, morphDef)
	Spring.Echo("Got a call to CommInvestMorphStart, unitID=" .. unitID .. ".")
    if trackedComms[unitID] then
        Spring.Echo("We are tracking comm unitID=" .. unitID .. ".")
        if upgradeStarted ~= nil then
            Spring.Echo("Upgrade started on top of another upgrade.")
        else
            upgradeStarted = totalFrame
        end
    end
end

function CommInvestMorphStop(oldUnitID, newUnitID)
	Spring.Echo("Got a call to CommInvestMorphStop, oldUnitID=" .. oldUnitID .. ", newUnitID=" .. newUnitID .. ".")
    if trackedComms[oldUnitID] then
        Spring.Echo("We are tracking comm oldUnitID=" .. oldUnitID .. ".")
    end
    if trackedComms[newUnitID] then
        Spring.Echo("We are tracking comm newUnitID=" .. newUnitID .. ".")
    end
    if trackedComms[oldUnitID] or trackedComms[newUnitID] then
        if upgradeStarted == nil then
            Spring.Echo("Upgrade stopped without a start.")
        else
            upgradeFrameCounter = upgradeFrameCounter + totalFrame - upgradeStarted
            upgradeStarted = nil
        end
    end
end