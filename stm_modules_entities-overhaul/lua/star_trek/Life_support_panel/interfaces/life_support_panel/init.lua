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
--  LCARS Life Support Panel | SV   --
---------------------------------------

if not istable(INTERFACE) then Star_Trek:LoadAllModules() return end
local SELF = INTERFACE

SELF.BaseInterface = "base"
SELF.LogType = "Life Support Control"

local InterfaceAccess = include("star_trek/interface_panel_access.lua")

local function log(panelEnt, ply, message, color)
	if not (Star_Trek and Star_Trek.Logs) then return end
	Star_Trek.Logs:AddEntry(panelEnt, ply, message, color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorBlue or nil))
end

local function getLifeSupport()
	return StarTrekEntities and StarTrekEntities.LifeSupport or nil
end

local function isConsoleDisabled()
	return Star_Trek and Star_Trek.Life_Support_Panel and Star_Trek.Life_Support_Panel.ConsoleDisabled
end

local function getPanelStateStore()
	Star_Trek = Star_Trek or {}
	Star_Trek.Life_Support_Panel = Star_Trek.Life_Support_Panel or {}
	local panel = Star_Trek.Life_Support_Panel
	panel.SecurityState = panel.SecurityState or {}
	return panel.SecurityState
end

function SELF:SecurityEnabled()
	return InterfaceAccess and InterfaceAccess:IsEnabled(self.LogType)
end

function SELF:GetSecurityStore()
	return getPanelStateStore()
end

function SELF:IsPanelLocked()
	if not self:SecurityEnabled() then
		return false
	end
	return self.PanelLocked ~= false
end

function SELF:InitializeSecurityState()
	self.SecurityInput = ""

	if not self:SecurityEnabled() then
		self.PanelLocked = false
		self.PanelAccessRole = nil
		local store = self:GetSecurityStore()
		store.Locked = false
		store.Role = nil
		return
	end

	local store = self:GetSecurityStore()
	if store.Locked == nil then
		store.Locked = InterfaceAccess:DefaultLocked(self.LogType)
	end

	self.PanelLocked = store.Locked ~= false
	self.PanelAccessRole = store.Role
end

function SELF:SecurityLog(message, color)
	if not isstring(message) or message == "" then
		return
	end

	local ent = self.Ent
	if not IsValid(ent) then
		return
	end

	log(ent, nil, message, color or (Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil))
end

function SELF:SetPanelLocked(state, roleLabel, silent)
	if not self:SecurityEnabled() then
		return false
	end

	local locked = state and true or false
	if locked then
		roleLabel = nil
	end

	local changed = (self.PanelLocked ~= locked) or (not locked and self.PanelAccessRole ~= roleLabel)

	self.PanelLocked = locked
	self.PanelAccessRole = roleLabel
	self.SecurityInput = ""

	local store = self:GetSecurityStore()
	store.Locked = locked
	store.Role = roleLabel

	if changed and not silent then
		if locked then
			self:SecurityLog("Life support controls secured.", Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil)
		else
			local label = roleLabel or "Authorized"
			self:SecurityLog(string.format("Access granted: %s.", label), Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil)
		end
	end

	self:BuildControlWindow()

	if istable(self.MatrixWindow) then
		self.MatrixWindow:Update()
	end

	return changed
end

function SELF:LockPanel(silent)
	if not self:SecurityEnabled() then
		return false
	end
	return self:SetPanelLocked(true, nil, silent)
end

function SELF:UnlockPanel(roleLabel, silent)
	if not self:SecurityEnabled() then
		return false
	end
	return self:SetPanelLocked(false, roleLabel, silent)
end

function SELF:ResetSecurityInput()
	self.SecurityInput = ""
	self:UpdateSecurityDisplay()
end

function SELF:GetSecurityDisplayText()
	if not self.SecurityInput or self.SecurityInput == "" then
		return "ENTER AUTHORIZATION CODE"
	end
	return self.SecurityInput
end

function SELF:UpdateSecurityDisplay()
	if istable(self.SecurityDisplayButton) then
		self.SecurityDisplayButton.Name = self:GetSecurityDisplayText()
	end

	if istable(self.MatrixWindow) then
		self.MatrixWindow:Update()
	end
end

function SELF:HandleSecurityKey(key)
	if not self:SecurityEnabled() then
		return true
	end

	key = tostring(key or "")
	local upper = string.upper(key)

	if upper == "ENTER" then
		self:SubmitSecurityCode()
		return true
	elseif upper == "CLEAR" then
		self:ResetSecurityInput()
		return true
	elseif upper == "BACK" then
		if self.SecurityInput and #self.SecurityInput > 0 then
			self.SecurityInput = string.sub(self.SecurityInput, 1, -2)
			self:UpdateSecurityDisplay()
		end
		return true
	end

	local maxLen = InterfaceAccess and InterfaceAccess:GetMaxCodeLength() or 12
	if self.SecurityInput and #self.SecurityInput >= maxLen then
		return true
	end

	if upper:match("^[A-Z0-9]$") then
		self.SecurityInput = (self.SecurityInput or "") .. upper
		self:UpdateSecurityDisplay()
	end

	return true
end

function SELF:SubmitSecurityCode()
	if not self:SecurityEnabled() then
		return false
	end

	local code = string.upper(string.Trim(self.SecurityInput or ""))
	if code == "" then
		if IsValid(self.Ent) then
			self.Ent:EmitSound("star_trek.lcars_error")
		end
		self:SecurityLog("Authorization required: enter a valid code.", Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil)
		return false
	end

	local roleId, entry = InterfaceAccess:Validate(code)
	if not roleId then
		if IsValid(self.Ent) then
			self.Ent:EmitSound("star_trek.lcars_error")
		end
		self:SecurityLog("Access denied. Code not recognized.", Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorRed or nil)
		self.SecurityInput = ""
		self:UpdateSecurityDisplay()
		return false
	end

	local label = InterfaceAccess:GetRoleLabel(roleId, entry)
	if IsValid(self.Ent) then
		self.Ent:EmitSound("star_trek.lcars_success")
	end

	self.SecurityInput = ""
	self:UnlockPanel(label, true)
	self:SecurityLog(string.format("Access granted: %s.", label), Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil)
	self:UpdateSecurityStatus()
	return true
end

function SELF:BuildSecurityPad()
	local matrixWindow = self.MatrixWindow
	if not istable(matrixWindow) then
		return
	end

	matrixWindow:ClearMainButtons()
	matrixWindow:ClearSecondaryButtons()

	self.SecurityDisplayButton = nil
	self.PowerButton = nil
	self.DisableButton = nil
	self.AccessControlButton = nil

	local colorLight = Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil
	local colorAction = Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil

	local displayRow = matrixWindow:CreateSecondaryButtonRow(30)
	self.SecurityDisplayButton = matrixWindow:AddButtonToRow(displayRow, self:GetSecurityDisplayText(), nil, colorLight, nil, true, false)

	local controlRow = matrixWindow:CreateSecondaryButtonRow(30)
	matrixWindow:AddButtonToRow(controlRow, "BACK", nil, colorAction, nil, false, false, function()
		return self:HandleSecurityKey("BACK")
	end)
	matrixWindow:AddButtonToRow(controlRow, "CLEAR", nil, colorAction, nil, false, false, function()
		return self:HandleSecurityKey("CLEAR")
	end)
	matrixWindow:AddButtonToRow(controlRow, "ENTER", nil, colorAction, nil, false, false, function()
		return self:HandleSecurityKey("ENTER")
	end)

	local layout = InterfaceAccess and InterfaceAccess:GetKeyLayout() or {}
	local flattened = {}
	for _, chars in ipairs(layout) do
		for _, ch in ipairs(chars) do
			flattened[#flattened + 1] = ch
		end
	end

	local KEY_ROWS = 4
	local keysPerRow = math.max(math.ceil(#flattened / KEY_ROWS), 1)
	local keyIndex = 1
	for rowIndex = 1, KEY_ROWS do
		if keyIndex > #flattened then
			break
		end

		local row = matrixWindow:CreateSecondaryButtonRow(30)
		for _ = 1, keysPerRow do
			local ch = flattened[keyIndex]
			if not ch then
				break
			end

			matrixWindow:AddButtonToRow(row, ch, nil, colorLight, nil, false, false, function()
				return self:HandleSecurityKey(ch)
			end)
			keyIndex = keyIndex + 1
		end
	end

	matrixWindow:Update()
	self:UpdateSecurityDisplay()
end

function SELF:BuildControlWindow()
	local matrixWindow = self.MatrixWindow
	if not istable(matrixWindow) then
		return
	end

	if self:SecurityEnabled() and self:IsPanelLocked() then
		self:BuildSecurityPad()
		return
	end

	if isfunction(self._LifeSupportBuildControls) then
		self._LifeSupportBuildControls()
	end
end

function SELF:UpdateSecurityStatus()
	if not self:SecurityEnabled() then
		return
	end

	if istable(self.AccessControlButton) then
		local label = self.PanelAccessRole or "Authorized"
		if self:IsPanelLocked() then
			self.AccessControlButton.Name = string.format("Panel Locked (%s)", label)
			self.AccessControlButton.Color = Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil
			self.AccessControlButton.Disabled = true
		else
			self.AccessControlButton.Name = string.format("Lock Console (%s)", label)
			self.AccessControlButton.Color = Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil
			self.AccessControlButton.Disabled = false
		end
	end

	if istable(self.MatrixWindow) then
		self.MatrixWindow:Update()
	end
end

function SELF:UpdatePowerButton()
	local button = self.PowerButton
	if not istable(button) then
		return
	end

	local matrixWindow = self.MatrixWindow
	if isConsoleDisabled() then
		button.Name = "Power Unavailable"
		button.Color = Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorRed or nil
		button.Disabled = true
	else
		button.Disabled = false
		local ls = getLifeSupport()
		local online = ls and ls:IsOnline()
		if online then
			button.Name = "Power Online"
			button.Color = Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil
		else
			button.Name = "Power Offline"
			button.Color = Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorRed or nil
		end
	end

	if istable(matrixWindow) then
		matrixWindow:Update()
	end

	self:UpdateDisableButton()
end

function SELF:UpdateDisableButton()
	local button = self.DisableButton
	if not istable(button) then
		return
	end

	local matrixWindow = self.MatrixWindow
	if isConsoleDisabled() then
		button.Name = "Console Disabled"
		button.Color = Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorRed or nil
		button.Disabled = true
	else
		button.Name = "Disable Console"
		button.Color = Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil
		button.Disabled = false
	end

	if istable(matrixWindow) then
		matrixWindow:Update()
	end
end

function SELF:Open(ent)
	if game.GetMap() ~= "rp_intrepid_v1" then
		return false, "Wrong map"
	end

	self.Ent = ent
	self:InitializeSecurityState()

	local panelEnt = ent
	local ls = getLifeSupport()

	local successMatrix, matrixWindow = Star_Trek.LCARS:CreateWindow(
		"button_matrix",
		Vector(0, 1.5, -13),
		Angle(0, 180, 30),
		16,
		730,
		200,
		function() end,
		"Life Support",
		nil,
		true
	)
	if not successMatrix then
		return false, matrixWindow
	end

	self.MatrixWindow = matrixWindow

	local lastDiag = 0
	local DIAG_COOLDOWN = 8

	local function queueDiagnostics(ply)
		local steps = {
			"Routing atmospheric telemetry...",
			"Sampling deck environmental controls...",
			"Checking CO2 scrubbing matrix...",
			"Sweeping structural integrity fields...",
			"Verifying emergency bulkheads...",
			"Collating lifeform biometrics...",
			"Life support diagnostics complete."
		}

		for i, msg in ipairs(steps) do
			timer.Simple(0.45 * i, function()
				if not IsValid(panelEnt) then return end
				log(panelEnt, ply, msg, Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorBlue or nil)
			end)
		end

		timer.Simple(0.45 * #steps, function()
			if not (ls and ls.GetHealthPercent) then return end
			local hp = ls:GetHealthPercent() or 0
			local status = (ls:IsOnline() and "ONLINE") or "OFFLINE"
			log(panelEnt, ply, string.format("Status: %s | Core integrity at %d%%", status, hp), Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil)
		end)

		timer.Simple(0.45 * #steps + 0.35, function()
			if not (ls and ls.GetDisruptionSummary) then return end
			local summary = ls:GetDisruptionSummary()
			if not istable(summary) or #summary == 0 then
				log(panelEnt, ply, "All decks reporting nominal atmospheric conditions.", Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil)
				return
			end

			local count = #summary
			local header = string.format("Detected %d environmental outage%s.", count, count == 1 and "" or "s")
			log(panelEnt, ply, header, Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil)

			for _, entry in ipairs(summary) do
				local message = entry and entry.message or "Environmental controls offline in an unidentified zone."
				log(panelEnt, ply, message, Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorRed or nil)
			end
		end)

		timer.Simple(0.45 * #steps + 0.5, function()
			if not (ls and ls.GetAlertSelectionLabel and ls.IsAlertEnabled) then return end
			local label = ls:GetAlertSelectionLabel()
			local enabled = ls:IsAlertEnabled()
			local color = enabled and (Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil) or (Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil)
			local message
			if enabled then
				message = string.format("Outage alert routing armed: %s.", label)
			else
				message = string.format("Outage alert routing disabled (last setting: %s).", label)
			end
			log(panelEnt, ply, message, color)
		end)
	end

	local function buildControls()
		local matrix = self.MatrixWindow
		if not istable(matrix) then
			return
		end

		matrix:ClearMainButtons()
		matrix:ClearSecondaryButtons()

		self.SecurityDisplayButton = nil
		self.PowerButton = nil
		self.DisableButton = nil
		self.AccessControlButton = nil

		ls = getLifeSupport()

		local row1 = matrix:CreateSecondaryButtonRow(32)
		matrix:AddButtonToRow(row1, "Diagnostics", nil, Star_Trek.LCARS.ColorLightBlue, Star_Trek.LCARS.ColorLightBlue, false, false, function(ply)
			if CurTime() < (lastDiag + DIAG_COOLDOWN) then
				log(panelEnt, ply, "Diagnostics in progress. Please stand by...", Star_Trek.LCARS.ColorOrange)
				return true
			end
			lastDiag = CurTime()
			log(panelEnt, ply, "Initiating environmental diagnostics...", Star_Trek.LCARS.ColorBlue)
			queueDiagnostics(ply)
			return true
		end)

		local row2 = matrix:CreateSecondaryButtonRow(32)
		self.PowerButton = matrix:AddButtonToRow(row2, "Power Online", nil, Star_Trek.LCARS.ColorLightBlue, nil, false, false, function(ply)
			if isConsoleDisabled() then
				log(panelEnt, ply, "Console offline. Tap panel to reactivate before adjusting power.", Star_Trek.LCARS.ColorOrange)
				return true
			end
			if not ls then
				log(panelEnt, ply, "Life support controller unavailable.", Star_Trek.LCARS.ColorRed)
				return true
			end

			local online = ls:IsOnline()
			if online then
				ls:Shutdown(ent)
				log(panelEnt, ply, "Manual override engaged. Life support offline.", Star_Trek.LCARS.ColorRed)
			else
				ls:Enable(ent)
				if ls:IsOnline() then
					log(panelEnt, ply, "Manual override released. Life support enabled.", Star_Trek.LCARS.ColorLightBlue)
				else
					local msg = "Failed to reactivate life support. Main life support core has been breached."
					log(panelEnt, ply, msg, Star_Trek.LCARS.ColorRed)
					if Star_Trek and Star_Trek.Life_Support_Panel then
						Star_Trek.Life_Support_Panel:AddOperationsLog(msg, Star_Trek.LCARS and Star_Trek.LCARS.ColorRed)
					end
				end
			end

			self:UpdatePowerButton()
			return true
		end)

		local row3 = matrix:CreateSecondaryButtonRow(32)
		matrix:AddButtonToRow(row3, "Deploy Repair Drones", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, false, false, function(ply)
			if not ls or not ls.RunRepair then
				log(panelEnt, ply, "Automated repair unavailable.", Star_Trek.LCARS.ColorRed)
				return true
			end

			local success, err = ls:RunRepair(panelEnt, ply)
			if not success and err then
				log(panelEnt, ply, err, Star_Trek.LCARS.ColorRed)
			end
			self:UpdatePowerButton()
			return true
		end)

		matrix:AddButtonToRow(row3, "Emergency Override", nil, Star_Trek.LCARS.ColorBlue, nil, false, false, function(ply)
			if not ls then
				log(panelEnt, ply, "Override controls unavailable.", Star_Trek.LCARS.ColorRed)
				return true
			end

			if not (Star_Trek and Star_Trek.Life_Support_Panel and Star_Trek.Life_Support_Panel.TriggerEmergencyOverride) then
				log(panelEnt, ply, "Emergency override unavailable.", Star_Trek.LCARS.ColorRed)
				return true
			end

			local success, err = Star_Trek.Life_Support_Panel:TriggerEmergencyOverride(ply)
			if not success then
				log(panelEnt, ply, err or "Unable to engage emergency override.", Star_Trek.LCARS.ColorRed)
			else
				log(panelEnt, ply, "Emergency override engaged. Reserve oxygen routed to shipwide manifolds.", Star_Trek.LCARS.ColorOrange)
			end
			self:UpdatePowerButton()
			return true
		end)

		local row4 = matrix:CreateSecondaryButtonRow(32)
		self.DisableButton = matrix:AddButtonToRow(row4, "Disable Console", nil, Star_Trek.LCARS.ColorOrange, nil, false, false, function(ply)
			if not (Star_Trek and Star_Trek.Life_Support_Panel) then
				log(panelEnt, ply, "Console control backend unavailable.", Star_Trek.LCARS.ColorRed)
				return true
			end

			if isConsoleDisabled() then
				log(panelEnt, ply, "Console already offline. Tap the panel to restart.", Star_Trek.LCARS.ColorOrange)
				return true
			end

			Star_Trek.Life_Support_Panel.ConsoleDisabled = true
			Star_Trek.Life_Support_Panel.ReenablePending = true
			Star_Trek.Life_Support_Panel:Log("Life support console secured. Tap panel to restore.", Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange)
			Star_Trek.Life_Support_Panel:AddOperationsLog("Life support console secured for maintenance.", Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange)

			log(panelEnt, ply, "Console disabled. Use the wall panel to bring it back online.", Star_Trek.LCARS.ColorOrange)
			Star_Trek.LCARS:CloseInterface(panelEnt)
			self:UpdatePowerButton()
			return true
		end)

		if self:SecurityEnabled() then
			local lockRow = matrix:CreateSecondaryButtonRow(32)
			self.AccessControlButton = matrix:AddButtonToRow(lockRow, "Lock Console", nil, Star_Trek.LCARS.ColorOrange, nil, false, false, function()
				return self:LockPanel()
			end)
		else
			self.AccessControlButton = nil
		end

		matrix:Update()
		self:UpdatePowerButton()
		self:UpdateDisableButton()
		self:UpdateSecurityStatus()
	end

	self._LifeSupportBuildControls = buildControls

	local successLog, logWindow = Star_Trek.LCARS:CreateWindow(
		"log_entry",
		Vector(-0, 2, 12),
		Angle(0, 180, 110),
		16,
		600,
		530,
		function() end,
		nil
	)
	if not successLog then
		return false, logWindow
	end

	self.LogWindow = logWindow

	self:BuildControlWindow()

	return true, {matrixWindow, logWindow}
end
