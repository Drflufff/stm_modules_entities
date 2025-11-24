---------------------------------------
---------------------------------------
--         Star Trek Modules         --
--                                   --
--            Created by             --
--       Jan 'Oninoni' Ziegler       --
--                                   --
-- This software can be used freely, --
--    but only distributed by me.    --
--                                   --
--    Copyright © 2022 Jan Ziegler   --
---------------------------------------
---------------------------------------

---------------------------------------
-- LCARS Life Support Core | Server --
---------------------------------------

if not istable(INTERFACE) then Star_Trek:LoadAllModules() return end
local SELF = INTERFACE

SELF.BaseInterface = "base"
SELF.LogType = "Life Support Core"

local function getController()
	return StarTrekEntities and StarTrekEntities.LifeSupport or nil
end

local function buildStatusLines(core)
	local ls = getController()
	local percent = 0
	if IsValid(core) and core.GetLifeSupportMaxHealth then
		local maxhp = core:GetLifeSupportMaxHealth()
		if maxhp > 0 then
			percent = math.floor((core:GetLifeSupportHealth() / maxhp) * 100)
		end
	end

	local online = IsValid(core) and core:IsOperational()
	local status = online and "ONLINE" or "OFFLINE"

	local override = "AUTO"
	if IsValid(core) and core.OverrideState ~= nil then
		override = core.OverrideState and "FORCED ON" or "FORCED OFF"
	elseif ls and ls.ManualOverride ~= nil then
		override = ls.ManualOverride and "FORCED ON" or "FORCED OFF"
	end

	local repairState = "IDLE"
	if ls and ls:IsAutoRepairRunning() then
		repairState = "ACTIVE"
	elseif IsValid(core) and core.AutoRepairActive then
		repairState = "ACTIVE"
	end

	return percent, status, override, repairState
end

local function formatReserve(seconds)
	if not isnumber(seconds) or seconds <= 0 then
		return "RESERVE O2: STANDBY"
	end

	local total = math.max(0, math.ceil(seconds))
	local mins = math.floor(total / 60)
	local secs = total % 60

	return string.format("RESERVE O2: %02d:%02d", mins, secs)
end

function SELF:Open(ent, core)
	if game.GetMap() ~= "rp_intrepid_v1" then
		return false, "Wrong map"
	end

	local coreEnt = core
	if not IsValid(coreEnt) then
		coreEnt = ent
	end

	if not IsValid(coreEnt) then
		return false, "Invalid core"
	end

	local interfaceEnt = ent

	self.CoreEnt = coreEnt
	self.InterfaceEnt = interfaceEnt
	self.Ent = interfaceEnt

	local successPanel, panelWindow = Star_Trek.LCARS:CreateWindow(
		"button_matrix",
		Vector(0, 0, 0),
		Angle(0, 0, 0),
		8,
		220,
		120,
		function() end,
		"Repair Node",
		nil,
		true
	)

	if not successPanel then
		return false, panelWindow
	end

	local displayRow = panelWindow:CreateSecondaryButtonRow(32)
	panelWindow:AddButtonToRow(displayRow, "REPAIR MODE", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, false, false, function()
		return true
	end)

	local success, window = Star_Trek.LCARS:CreateWindow(
		"button_list",
		Vector(0, 0, 0),
		Angle(0, 0, 0),
		14,
		420,
		200,
		function() end,
		"Core Integrity",
		nil,
		true
	)

	if not success then
		return false, window
	end

	local percent, status, override, repair = buildStatusLines(coreEnt)
	window:SetButtons({
		[1] = {
			Name = string.format("Core Integrity: %d%%", percent),
			Color = Star_Trek.LCARS.ColorLightBlue,
			Disabled = true,
		},
		[2] = {
			Name = string.format("Status: %s", status),
			Color = Star_Trek.LCARS.ColorBlue,
			Disabled = true,
		},
		[3] = {
			Name = string.format("Override: %s", override),
			Color = Star_Trek.LCARS.ColorOrange,
			Disabled = true,
		},
		[4] = {
			Name = string.format("Auto-Repair: %s", repair),
			Color = Star_Trek.LCARS.ColorOrange,
			Disabled = true,
		},
	}, 38)

	local entIndex = coreEnt:EntIndex()
	local timerId = "LifeSupportCoreInterface_" .. entIndex

	local function update()
		if not IsValid(coreEnt) or not IsValid(interfaceEnt) then
			timer.Remove(timerId)
			return
		end

		if not (Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ActiveInterfaces and Star_Trek.LCARS.ActiveInterfaces[interfaceEnt]) then
			timer.Remove(timerId)
			return
		end

		local pct, st, ov, rp = buildStatusLines(coreEnt)
		local buttons = window.Buttons or {}
		if buttons[1] then buttons[1].Name = string.format("Core Integrity: %d%%", pct) end
		if buttons[2] then buttons[2].Name = string.format("Status: %s", st) end
		if buttons[3] then buttons[3].Name = string.format("Override: %s", ov) end
		if buttons[4] then buttons[4].Name = string.format("Auto-Repair: %s", rp) end

		if panelWindow and panelWindow.Buttons and panelWindow.Buttons[1] then
			local reserve = coreEnt.GetBackupTimeRemaining and coreEnt:GetBackupTimeRemaining() or 0
			panelWindow.Buttons[1].Name = reserve > 0 and string.format("REPAIR MODE | %s", formatReserve(reserve)) or "REPAIR MODE"
		end

		Star_Trek.LCARS:UpdateWindow(interfaceEnt, window.Id, window)
		if panelWindow then
			Star_Trek.LCARS:UpdateWindow(interfaceEnt, panelWindow.Id, panelWindow)
		end
	end

	timer.Create(timerId, 1, 0, update)
	update()

	return true, {panelWindow, window}
end
