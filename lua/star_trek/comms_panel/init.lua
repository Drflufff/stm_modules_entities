---------------------------------------
---------------------------------------
--         Star Trek Modules         --
--                                   --
--            Created by             --
--       Onioni                      --
--                                   --
-- This software can be used freely, --
--    but only distributed by me.    --
--                                   --
--    Copyright © 2022 Jan Ziegler   --
---------------------------------------
---------------------------------------

---------------------------------------
--   LCARS Comms Panel | Server      --
---------------------------------------

if not istable(INTERFACE) then Star_Trek:LoadAllModules() return end
local SELF = INTERFACE

SELF.BaseInterface = "base"
SELF.LogType = "Communications Console"

function SELF:AutoSpawn()
    if SERVER then
        local pos = Vector(190, 90, 13427)
        local ang = Angle(0, 0, 0)
        local model = "models/hunter/blocks/cube025x025x025.mdl"
        local success, ent = Star_Trek.Button:CreateInterfaceButton(pos, ang, model, "comms_panel")
        if success then
            ent.LogType = SELF.LogType
            print("[StarTrekEntities] Auto-spawned Comms Panel at:", pos, ang)
        else
            print("[StarTrekEntities] Failed to auto-spawn Comms Panel!", ent)
        end
    end
end

function SELF:Open(ent)
    if game.GetMap() ~= "rp_intrepid_v1" then return false, "Wrong map" end
    if SERVER then
        print("[StarTrekEntities] Comms Panel interface opened for entity:", ent)
    end


    local success1, categorySelection = self.CreateCategorySelectionWindow and self:CreateCategorySelectionWindow() or true, nil
    if not success1 then
        return false, categorySelection
    end

    local success2, controlWindow = self.CreateControlMenu and self:CreateControlMenu() or true, nil
    if not success2 then
        return false, controlWindow
    end

    local success3, listWindow = self.CreateListWindow and self:CreateListWindow(1) or true, nil
    if not success3 then
        return false, listWindow
    end

    local success4, commsWindow = Star_Trek.LCARS:CreateWindow(
        "log_entry",
        Vector(0, -2, -14.25),
        Angle(0, 0, 0),
        16,
        770,
        380,
        function(windowData, interfaceData, ply, buttonId)
            -- Add comms button stuff here
        end,
        true
    )
    if not success4 then
        return false, commsWindow
    end

    return true, {categorySelection, controlWindow, listWindow, commsWindow}
end

hook.Add("InitPostEntity", "AutoSpawnCommsPanel", function()
    if INTERFACE and INTERFACE.AutoSpawn then
        INTERFACE:AutoSpawn()
    end
end)
