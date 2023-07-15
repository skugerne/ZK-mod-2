function widget:GetInfo()
    return {
        name      = "Comm Investment",
        desc      = "Shows the metal and time investment in your commander",
        author    = "skugerne",
        date      = "2023",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true,
    }
end
  
local spGetSpectatingState	= Spring.GetSpectatingState

local frame = 0
local localTeamID = Spring.GetLocalTeamID()
local trackedComms = {}

-- new dyn comms are created after upgrades
function widget:UnitCreated(unitID, unitDefID, unitTeam)
    Spring.Echo("comm widget sees unitId " .. unitID .. " is created")
    if localTeamID == unitTeam and UnitDefs then
        local unitDef = UnitDefs[unitDefID]
        if unitDef and unitDef.customParams and unitDef.customParams.dynamic_comm then
            Spring.Echo("comm widget: new unit is a dyn comm")
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
            Spring.Echo("comm widget: a dead unit was a dyn comm")
            trackedComms[unitID] = nil
        end
    end
end

local function tableprint(t)
    local res = ""
    for k,v in pairs(t) do
        if type(v) == "boolean" then
            if v then v = "true" else v = "false" end
        end
        if v == nil then v = "nil" end
        res = res .. ";" .. k .. "=" .. v
    end
    return res
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams)
    if trackedComms[unitID] then
        Spring.Echo("comm widget: UnitCommand for a commander we are tracking")
        Spring.Echo("comm widget: cmdID=" .. (cmdID or "nil"))
        Spring.Echo("comm widget: cmdOpts=" .. (tableprint(cmdOpts) or "{}"))
        Spring.Echo("comm widget: cmdParams=" .. (tableprint(cmdParams) or "{}"))
    end
end

function widget:UnitCommandNotify(unitID, cmdID, cmdParams)
    if trackedComms[unitID] then
        Spring.Echo("comm widget: UnitCommandNotify for a commander we are tracking")
        Spring.Echo("comm widget: cmdID=" .. (cmdID or "nil"))
        Spring.Echo("comm widget: cmdParams=" .. (tableprint(cmdParams) or "{}"))
    end
end

function widget:GameFrame(n)
    frame = frame - 1
    if frame <= 0 then 
        frame = 60 -- once per 2 seconds (engine does 30 frames per second)
    end
end

function widget:Initialize()
    if spGetSpectatingState() then
        widgetHandler:RemoveWidget()
    end

    --WG.InitializeTranslation (languageChanged, GetInfo().name)
end

function widget:Shutdown()
    --WG.ShutdownTranslation(GetInfo().name)
end

-- changing teams, rejoin, becoming spec etc
function widget:PlayerChanged (playerID)
    if spGetSpectatingState() then
        widgetHandler:RemoveWidget()
    end
    localTeamID = Spring.GetLocalTeamID ()
end
