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
--   LCARS Gravity Control | SV     --
---------------------------------------

if not istable(INTERFACE) then Star_Trek:LoadAllModules() return end
local SELF = INTERFACE

SELF.BaseInterface = "base"
SELF.LogType = "Gravity Control"

local function getController()
	return StarTrekEntities and StarTrekEntities.Gravity or nil
end

local function formatOverride(gen)
	if not IsValid(gen) then
		return "UNKNOWN"
	end

	if gen.OverrideState == true then
		return "FORCED ON"
	elseif gen.OverrideState == false then
		return "FORCED OFF"
	end

	return "AUTO"
end

local function pushLog(message, color)
	if not Star_Trek or not Star_Trek.Grav_Panel then return end
	Star_Trek.Grav_Panel:Log(message, color)
end

local InterfaceAccess = include("star_trek/interface_panel_access.lua")

local function getSecurityStore()
	Star_Trek = Star_Trek or {}
	Star_Trek.Grav_Panel = Star_Trek.Grav_Panel or {}
	Star_Trek.Grav_Panel.Security = Star_Trek.Grav_Panel.Security or {}
	return Star_Trek.Grav_Panel.Security
end

function SELF:SecurityEnabled()
	return InterfaceAccess and InterfaceAccess:IsEnabled(self.LogType)
end

function SELF:GetSecurityStore()
	return getSecurityStore()
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

	pushLog(message, color or (Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil))
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
			self:SecurityLog("Gravity controls secured.", Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil)
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
	self.IncreaseButton = nil
	self.DecreaseButton = nil
	self.ResetButton = nil
	self.EmergencyButton = nil
	self.ShutdownButton = nil
	self.ActivateButton = nil
	self.DisableConsoleButton = nil
	self.AccessControlButton = nil

	local colorLight = Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil
	local colorAction = Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil

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

	if isfunction(self._GravBuildControls) then
		self._GravBuildControls()
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
local function isConsoleDisabled()
	return Star_Trek and Star_Trek.Grav_Panel and Star_Trek.Grav_Panel.ConsoleDisabled
end

local STATUS_MAX_LINES = 20
local STATUS_PREFIXES = {
	"LCARS",
	"EPS",
	"SIF",
	"GAV",
	"STB",
	"OHD",
}

local STATUS_KEYS = {
	"SEG",
	"NODE",
	"BUS",
	"GAMMA",
	"SIG",
	"PWR",
	"CORE",
}

local STATUS_COLORS = {
	function() return Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or Color(120, 180, 255) end,
	function() return Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or Color(255, 170, 60) end,
	function() return Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorBlue or Color(100, 140, 255) end,
	function() return Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorRed or Color(255, 80, 80) end,
}

local function randomStatusEntry()
	local prefix = STATUS_PREFIXES[math.random(#STATUS_PREFIXES)] or "LCARS"
	local key = STATUS_KEYS[math.random(#STATUS_KEYS)] or "SEG"
	local value = string.format("%02X%02X.%02X", math.random(0, 255), math.random(0, 255), math.random(0, 255))
	local text = string.format("%s %s:%s", prefix, key, value)
	local colorFunc = STATUS_COLORS[math.random(#STATUS_COLORS)]
	local color = colorFunc and colorFunc() or (Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue) or Color(200, 220, 255)
	return {Text = text, Color = color}
end

local function ensureStatusBuffer(buffer)
	if not istable(buffer) then
		buffer = {}
	end
	while #buffer < STATUS_MAX_LINES do
		buffer[#buffer + 1] = randomStatusEntry()
	end
	while #buffer > STATUS_MAX_LINES do
		table.remove(buffer, 1)
	end
	return buffer
end

function SELF:Open(ent)
	if game.GetMap() ~= "rp_intrepid_v1" then
		return false, "Wrong map"
	end

	self.Ent = ent
	self:InitializeSecurityState()

	local controller = getController()
	local generator = controller and controller:GetGenerator() or (Star_Trek and Star_Trek.Grav_Panel and Star_Trek.Grav_Panel:EnsureGenerator())
	local panelState = Star_Trek and Star_Trek.Grav_Panel or nil

	local successMatrix, matrixWindow = Star_Trek.LCARS:CreateWindow(
		"button_matrix",
		Vector(11.4, 3.5, -10.8),
		Angle(0, 90, 13.5),
		12,
		1100,
		360,
		function() end,
		"Gravity Field Control",
		nil,
		true
	)
	if not successMatrix then
		return false, matrixWindow
	end

	self.MatrixWindow = matrixWindow

	local savedStatus = panelState and panelState.LastStatus
	local savedHealthOk = true
	if savedStatus then
		local savedHealthValue = tonumber(savedStatus.HealthValue)
		local savedHealthPercent = tonumber(savedStatus.Health)
		savedHealthOk = (savedHealthValue and savedHealthValue > 0) or (savedHealthPercent and savedHealthPercent > 0) or false
	end

	local statusBuffer = panelState and panelState.StatusBuffer
	statusBuffer = ensureStatusBuffer(statusBuffer)
	if panelState then
		panelState.StatusBuffer = statusBuffer
	end

	local statusLines = {}
	for _, entry in ipairs(statusBuffer) do
		statusLines[#statusLines + 1] = {
			Text = entry.Text or "",
			Color = entry.Color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil),
		}
	end

	local statusSuccess, statusWindow = Star_Trek.LCARS:CreateWindow(
		"text_entry",
		Vector(-7.7, -29.5, 13.8),
		Angle(0, 90, 90),
		12,
		380,
		290,
		function() end,
		Star_Trek.LCARS.ColorLightBlue,
		"Field Status Feed",
		nil,
		true,
		statusLines
	)
	if not statusSuccess then
		return false, statusWindow
	end

	local telemetryBuffer = panelState and panelState.TelemetryBuffer
	if not istable(telemetryBuffer) then
		telemetryBuffer = {
			{Text = "Telemetry feed online.", Color = Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil},
		}
		if panelState then
			panelState.TelemetryBuffer = telemetryBuffer
		end
	end

	local TELEMETRY_MAX = 7
	while #telemetryBuffer > TELEMETRY_MAX do
		table.remove(telemetryBuffer, 1)
	end

	local initialTelemetry = {}
	for _, entry in ipairs(telemetryBuffer) do
		initialTelemetry[#initialTelemetry + 1] = {
			Text = entry.Text or "",
			Color = entry.Color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil),
		}
	end
	if #initialTelemetry == 0 then
		initialTelemetry[1] = {Text = "Telemetry feed online.", Color = Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil}
	end

	local telemetrySuccess, telemetryWindow = Star_Trek.LCARS:CreateWindow(
		"log_entry",
		Vector(-7.5, 30, 14),
		Angle(0, 90, 90),
		12,
		380,
		290,
		function() end,
		Star_Trek.LCARS.ColorLightBlue,
		"Gravity Telemetry",
		nil,
		true,
		initialTelemetry
	)
	if not telemetrySuccess then
		return false, telemetryWindow
	end

	local lastTelemetrySnapshot

	local function buildSnapshot(lines)
		local out = {}
		for i, line in ipairs(lines) do
			local text = line.text or line.Text or ""
			local color = line.color or line.Color
			if IsColor(color) then
				out[i] = string.format("%s|%03d%03d%03d%03d", text, color.r or 0, color.g or 0, color.b or 0, color.a or 255)
			else
				out[i] = string.format("%s|%s", text, tostring(color or ""))
			end
		end
		return table.concat(out, "\n")
	end

	local function refreshTelemetry(lines)
		local snapshot = buildSnapshot(lines)
		if snapshot == lastTelemetrySnapshot then
			return
		end

		lastTelemetrySnapshot = snapshot
		if panelState then
			panelState.LastTelemetrySnapshot = snapshot
		end
		telemetryWindow:ClearLines()
		for _, line in ipairs(lines) do
			telemetryWindow:AddLine(line.text or line.Text or "", line.color or line.Color or Star_Trek.LCARS.ColorLightBlue)
		end
		Star_Trek.LCARS:UpdateWindow(ent, telemetryWindow.Id, telemetryWindow)
	end

	local function pushTelemetryLine(text, color)
		if not telemetryBuffer then return end
		telemetryBuffer[#telemetryBuffer + 1] = {Text = text, Color = color}
		while #telemetryBuffer > TELEMETRY_MAX do
			table.remove(telemetryBuffer, 1)
		end
	end

	local function pushStatusEntry(entry)
		if not statusBuffer or not entry then return end
		statusBuffer[#statusBuffer + 1] = {Text = entry.Text or "", Color = entry.Color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil)}
		while #statusBuffer > STATUS_MAX_LINES do
			table.remove(statusBuffer, 1)
		end
		if panelState then
			panelState.StatusBuffer = statusBuffer
		end
	end

	local function refreshStatusDisplay()
		if not statusWindow then return end
		statusWindow:ClearLines()
		for _, entry in ipairs(statusBuffer or {}) do
			statusWindow:AddLine(entry.Text or "", entry.Color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil))
		end
		Star_Trek.LCARS:UpdateWindow(ent, statusWindow.Id, statusWindow)
	end

	local function rollStatusLine(entry)
		entry = entry or randomStatusEntry()
		pushStatusEntry(entry)
		refreshStatusDisplay()
	end

	refreshStatusDisplay()
	rollStatusLine(randomStatusEntry())

	local function resolveCurrentScale(grav, generatorEnt)
		if grav and grav.GetScale then
			return grav:GetScale()
		end

		if not IsValid(generatorEnt) then
			return nil
		end

		if generatorEnt.GetEffectiveGravityScale then
			return generatorEnt:GetEffectiveGravityScale()
		end

		if generatorEnt.GetGravityScale then
			local scale = generatorEnt:GetGravityScale()
			if generatorEnt.IsOperational and not generatorEnt:IsOperational() then
				if generatorEnt:Health() <= 0 then
					return generatorEnt.FailGravityScale or 0
				end
				if generatorEnt.OverrideState == false or generatorEnt.Working == false then
					return 0
				end
			end
			return scale
		end

		return nil
	end

	local function gatherTelemetryState()
		local grav = getController()
		generator = grav and grav:GetGenerator() or generator
		local scale = resolveCurrentScale(grav, generator)
		scale = scale or 1
		local online = grav and grav:IsOnline() or (IsValid(generator) and generator:IsOperational() or false)
		local health = grav and grav:GetHealthPercent() or (IsValid(generator) and generator.GetHealthPercent and generator:GetHealthPercent() or 0)
		local healthValue = IsValid(generator) and (generator.LastHealthValue or generator:Health() or 0) or 0
		scale = math.Round(scale, 2)
		local overrideState = formatOverride(generator)
		local overrideActive = IsValid(generator) and generator.OverrideState == true or false
		if panelState then
			panelState.LastStatus = panelState.LastStatus or {}
			local lastStatus = panelState.LastStatus
			lastStatus.Scale = scale
			lastStatus.Health = health
			lastStatus.HealthValue = healthValue
			lastStatus.Online = online
			lastStatus.Override = overrideState
			lastStatus.OverrideActive = overrideActive
		end
		return scale, health, online, overrideState
	end

	local function assembleTelemetryLines(scale, health, online, overrideState)
		local lines = {
			{text = string.format("GRAV: %.2fg", scale), color = Star_Trek.LCARS.ColorLightBlue},
			{text = string.format("FIELD INTEGRITY %03d%%", health), color = (health <= 30) and Star_Trek.LCARS.ColorRed or ((health <= 60) and Star_Trek.LCARS.ColorOrange or Star_Trek.LCARS.ColorLightBlue)},
			{text = online and "OUTPUT STABLE" or "OUTPUT OFFLINE", color = online and Star_Trek.LCARS.ColorLightBlue or Star_Trek.LCARS.ColorRed},
			{text = string.format("OVERRIDE %s", overrideState), color = Star_Trek.LCARS.ColorOrange},
		}
		for _, entry in ipairs(telemetryBuffer) do
			lines[#lines + 1] = {text = entry.Text or "", color = entry.Color or Star_Trek.LCARS.ColorLightBlue}
		end
		return lines
	end

	local function logResult(ply, ok, result, color)
		if ok then
			local successMessage = tostring(result or "Command acknowledged.")
			local entryColor = color or Star_Trek.LCARS.ColorLightBlue
			pushLog(successMessage, entryColor)
			pushTelemetryLine(successMessage, entryColor)
			rollStatusLine({Text = string.format("CMD ACK :: %s", successMessage), Color = entryColor})
		else
			local failure = result or "Command failed."
			pushLog(failure, Star_Trek.LCARS.ColorRed)
			pushTelemetryLine(failure, Star_Trek.LCARS.ColorRed)
			rollStatusLine({Text = string.format("CMD FAIL :: %s", failure), Color = Star_Trek.LCARS.ColorRed})
		end

		local scale, health, online, overrideState = gatherTelemetryState()
		refreshTelemetry(assembleTelemetryLines(scale, health, online, overrideState))
		return true
	end

	local function adjustGravity(ply, delta)
		local grav = getController()
		if not grav then
			pushLog("Gravity control backend offline.", Star_Trek.LCARS.ColorRed)
			return true
		end

		local gen = grav:GetGenerator() or generator
		if not IsValid(gen) then
			return logResult(ply, false, "Gravity generator offline or missing.")
		end

		generator = gen
		if gen.OverrideState ~= true then
			return logResult(ply, false, "Emergency override required before manual adjustments.")
		end

		if not grav:IsOnline() then
			return logResult(ply, false, "Gravity generators offline. Activate systems first.")
		end
		local ok, result = grav:AdjustScale(delta, ent)
		if ok and result then
			return logResult(ply, true, string.format("Gravity output adjusted to %.2fg", result))
		end
		return logResult(ply, false, result)
	end

	local function buildControls()
		if not istable(matrixWindow) then
			return
		end

		matrixWindow:ClearMainButtons()
		matrixWindow:ClearSecondaryButtons()

		self.SecurityDisplayButton = nil
		self.IncreaseButton = nil
		self.DecreaseButton = nil
		self.ResetButton = nil
		self.EmergencyButton = nil
		self.ShutdownButton = nil
		self.ActivateButton = nil
		self.DisableConsoleButton = nil
		self.AccessControlButton = nil

		savedStatus = panelState and panelState.LastStatus
		savedHealthOk = true
		if savedStatus then
			local savedHealthValue = tonumber(savedStatus.HealthValue)
			local savedHealthPercent = tonumber(savedStatus.Health)
			savedHealthOk = (savedHealthValue and savedHealthValue > 0) or (savedHealthPercent and savedHealthPercent > 0) or false
		end

		local savedOverrideActive = savedStatus and savedStatus.OverrideActive == true

		local row1 = matrixWindow:CreateSecondaryButtonRow(36)
		self.IncreaseButton = matrixWindow:AddButtonToRow(row1, "Increase Gravity", nil, Star_Trek.LCARS.ColorOrange, nil, false, false, function(ply)
			return adjustGravity(ply, 0.1)
		end)
		self.DecreaseButton = matrixWindow:AddButtonToRow(row1, "Decrease Gravity", nil, Star_Trek.LCARS.ColorOrange, nil, false, false, function(ply)
			return adjustGravity(ply, -0.1)
		end)

		local adjustmentsInitiallyEnabled = savedOverrideActive and savedHealthOk
		if self.IncreaseButton then
			self.IncreaseButton.Disabled = not adjustmentsInitiallyEnabled
		end
		if self.DecreaseButton then
			self.DecreaseButton.Disabled = not adjustmentsInitiallyEnabled
		end

		local row2 = matrixWindow:CreateSecondaryButtonRow(36)
		self.ResetButton = matrixWindow:AddButtonToRow(row2, "Reset Gravity", nil, Star_Trek.LCARS.ColorLightBlue, nil, false, false, function(ply)
			local grav = getController()
			if not grav then
				return logResult(ply, false, "Gravity control backend offline.")
			end

			if not grav:IsOnline() then
				return logResult(ply, false, "Gravity generators offline. Activate systems first.")
			end

			local ok, result = grav:Reset(ent)
			if ok and result then
				return logResult(ply, true, string.format("Gravity output reset to %.2fg", result))
			end
			return logResult(ply, ok, result)
		end)
		local emergencyLabel = savedOverrideActive and "Emergency Override (Active)" or "Emergency Override"
		local emergencyColor = savedOverrideActive and Star_Trek.LCARS.ColorLightBlue or Star_Trek.LCARS.ColorOrange
		self.EmergencyButton = matrixWindow:AddButtonToRow(row2, emergencyLabel, nil, emergencyColor, nil, false, false, function(ply)
			local grav = getController()
			if not grav then
				return logResult(ply, false, "Gravity control backend offline.")
			end

			local gen = grav:GetGenerator() or generator
			if not IsValid(gen) then
				return logResult(ply, false, "Gravity generator offline or missing.")
			end

			generator = gen
			local genHealth = gen:Health() or 0
			local overrideActive = gen.OverrideState == true
			if genHealth <= 0 then
				if overrideActive then
					gen:SetManualOverride(nil)
					gen.Working = false
					return logResult(ply, true, "Emergency override cleared. Generator remains offline.")
				end
				return logResult(ply, false, "Gravity generator damaged. Repairs required.")
			end

			local ok, result = grav:Emergency(ent)
			local handled = logResult(ply, ok, result)
			if ok and Star_Trek and Star_Trek.LCARS and Star_Trek.Grav_Panel then
				Star_Trek.LCARS:CloseInterface(ent)
				timer.Simple(0, function()
					if not IsValid(ply) then return end
					Star_Trek.Grav_Panel:TryOpenInterface(ply)
				end)
			end
			return handled
		end)

		local onlineOnOpen = savedStatus and savedStatus.Online == true
		if self.ResetButton then
			self.ResetButton.Disabled = not (savedHealthOk and (onlineOnOpen or savedOverrideActive))
		end
		if self.EmergencyButton then
			self.EmergencyButton.Disabled = not (savedHealthOk or savedOverrideActive)
		end

		local row3 = matrixWindow:CreateSecondaryButtonRow(36)
		self.ShutdownButton = matrixWindow:AddButtonToRow(row3, "Shutdown Generators", nil, Star_Trek.LCARS.ColorRed, nil, false, false, function(ply)
			local grav = getController()
			if not grav then
				return logResult(ply, false, "Gravity control backend offline.")
			end

			if not grav:IsOnline() then
				return logResult(ply, false, "Gravity generators already offline.")
			end

			local ok, result = grav:Shutdown(ent)
			return logResult(ply, ok, result)
		end)
		self.ActivateButton = matrixWindow:AddButtonToRow(row3, "Activate Generators", nil, Star_Trek.LCARS.ColorLightBlue, nil, false, false, function(ply)
			local grav = getController()
			if not grav then
				return logResult(ply, false, "Gravity control backend offline.")
			end

			local gen = grav:GetGenerator() or generator
			if not IsValid(gen) then
				return logResult(ply, false, "Gravity generator offline or missing.")
			end

			if gen:Health() <= 0 then
				return logResult(ply, false, "Gravity generator damaged. Repairs required.")
			end

			local ok, result = grav:Restart(ent)
			return logResult(ply, ok, result)
		end)

		if self.ShutdownButton then
			self.ShutdownButton.Disabled = not (savedHealthOk and onlineOnOpen)
		end
		if self.ActivateButton then
			self.ActivateButton.Disabled = not savedHealthOk
		end

		local row4 = matrixWindow:CreateSecondaryButtonRow(36)
		matrixWindow:AddButtonToRow(row4, "Run Diagnostics", nil, Star_Trek.LCARS.ColorLightBlue, nil, false, false, function(ply)
			local scale, health, online, overrideState = gatherTelemetryState()
			local status = online and "ONLINE" or "OFFLINE"
			local diagColor = online and ((health <= 45) and Star_Trek.LCARS.ColorOrange or Star_Trek.LCARS.ColorLightBlue) or Star_Trek.LCARS.ColorRed
			pushLog("Initiating LCARS diagnostic sequence...", diagColor)
			pushTelemetryLine("Diag> LCARS handshake acknowledged.", diagColor)
			refreshTelemetry(assembleTelemetryLines(scale, health, online, overrideState))

			local diagPrefix = string.format("StarTrek.GravityPanel.Diagnostics.%d", ent:EntIndex())
			for i = 1, 6 do
				timer.Remove(diagPrefix .. "." .. i)
			end

			local steps = {
				{
					delay = 0.6,
					text = function()
						return string.format("Diag> EPS lattice sync %03d%%", math.random(72, 98))
					end,
					color = Star_Trek.LCARS.ColorLightBlue,
				},
				{
					delay = 1.2,
					text = function()
						return string.format("Diag> Gravimetric sweep %.1f microdynes", math.Rand(0.8, 4.9))
					end,
					color = Star_Trek.LCARS.ColorOrange,
				},
				{
					delay = 1.8,
					text = function()
						return string.format("Diag> Inertial dampers phase %d.%02d", math.random(2, 5), math.random(0, 99))
					end,
					color = Star_Trek.LCARS.ColorLightBlue,
				},
				{
					delay = 2.4,
					func = function()
						local curScale, curHealth, curOnline, curOverride = gatherTelemetryState()
						local curStatus = curOnline and "ONLINE" or "OFFLINE"
						local summary = string.format("Diagnostics: %.2fg | %d%% | %s | Override %s", curScale, curHealth, curStatus, curOverride)
						pushTelemetryLine(string.format("Diag> Output %.2fg", curScale), diagColor)
						pushTelemetryLine(string.format("Diag> Integrity %d%% | %s", curHealth, curStatus), diagColor)
						pushTelemetryLine(string.format("Diag> Override %s", curOverride), Star_Trek.LCARS.ColorOrange)
						pushLog(summary, diagColor)
						refreshTelemetry(assembleTelemetryLines(curScale, curHealth, curOnline, curOverride))
					end,
				},
				{
					delay = 3.1,
					func = function()
						local controller = getController()
						local summary = controller and controller.GetDisruptionSummary and controller:GetDisruptionSummary() or nil
						if not istable(summary) or #summary == 0 then
							pushTelemetryLine("Diag> All deck segments maintaining standard gravity.", Star_Trek.LCARS.ColorLightBlue)
						else
							pushTelemetryLine(string.format("Diag> %d gravity outage%s detected.", #summary, #summary == 1 and "" or "s"), Star_Trek.LCARS.ColorOrange)
							for _, entry in ipairs(summary) do
								local message = entry and entry.message or "Gravity field offline in an unidentified zone."
								pushTelemetryLine("Diag> " .. message, Star_Trek.LCARS.ColorRed)
								pushLog(message, Star_Trek.LCARS.ColorRed)
							end
						end

						local curScale, curHealth, curOnline, curOverride = gatherTelemetryState()
						refreshTelemetry(assembleTelemetryLines(curScale, curHealth, curOnline, curOverride))
					end,
				},
			}

			for index, step in ipairs(steps) do
				timer.Create(diagPrefix .. "." .. index, step.delay, 1, function()
					if not IsValid(ent) then return end
					if step.text then
						local line = step.text()
						local color = step.color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil)
						pushTelemetryLine(line, color)
						local curScale, curHealth, curOnline, curOverride = gatherTelemetryState()
						refreshTelemetry(assembleTelemetryLines(curScale, curHealth, curOnline, curOverride))
					end
					if step.func then
						step.func()
					end
				end)
			end

			return true
		end)
		self.DisableConsoleButton = matrixWindow:AddButtonToRow(row4, "Disable Console", nil, Star_Trek.LCARS.ColorOrange, nil, false, false, function(ply)
			if not (Star_Trek and Star_Trek.Grav_Panel) then
				return logResult(ply, false, "Console control backend unavailable.")
			end

			if isConsoleDisabled() then
				pushTelemetryLine("Console already offline.", Star_Trek.LCARS.ColorOrange)
				pushLog("Gravity console already offline.", Star_Trek.LCARS.ColorOrange)
				return true
			end

			Star_Trek.Grav_Panel.ConsoleDisabled = true
			Star_Trek.Grav_Panel.ReenablePending = true
			pushLog("Gravity console secured. Tap the panel to restore.", Star_Trek.LCARS.ColorOrange)
			pushTelemetryLine("Console secured for maintenance.", Star_Trek.LCARS.ColorOrange)
			local scale, health, online, overrideState = gatherTelemetryState()
			refreshTelemetry(assembleTelemetryLines(scale, health, online, overrideState))
			Star_Trek.LCARS:CloseInterface(ent)
			return true
		end)

		local consoleDisabled = isConsoleDisabled()
		if consoleDisabled then
			self.DisableConsoleButton.Name = "Console Offline"
			self.DisableConsoleButton.Color = Star_Trek.LCARS.ColorRed
			self.DisableConsoleButton.Disabled = true
		else
			self.DisableConsoleButton.Name = "Disable Console"
			self.DisableConsoleButton.Color = Star_Trek.LCARS.ColorOrange
			self.DisableConsoleButton.Disabled = false
		end

		if self:SecurityEnabled() then
			local lockRow = matrixWindow:CreateSecondaryButtonRow(36)
			self.AccessControlButton = matrixWindow:AddButtonToRow(lockRow, "Lock Console", nil, Star_Trek.LCARS.ColorOrange, nil, false, false, function()
				return self:LockPanel()
			end)
		else
			self.AccessControlButton = nil
		end

		matrixWindow:Update()
		self:UpdateSecurityStatus()
	end

	self._GravBuildControls = buildControls
	self:BuildControlWindow()

	local function syncButtonState(button, properties)
		if not button or not istable(properties) then return false end
		local changed = false
		if properties.Disabled ~= nil and button.Disabled ~= properties.Disabled then
			button.Disabled = properties.Disabled
			changed = true
		end
		if properties.Color and button.Color ~= properties.Color then
			button.Color = properties.Color
			changed = true
		end
		if properties.Name and button.Name ~= properties.Name then
			button.Name = properties.Name
			changed = true
		end
		return changed
	end

	local entIndex = ent:EntIndex()
	local timerId = "StarTrek.GravityPanel.Update." .. entIndex
	local nextTicker = 0
	local nextHeartbeat = 0
	local nextStatusPulse = 0
	local prevScale
	local prevOnline
	local prevHealth
	local prevOverride
	local lastDisableState

	local function update()
		if not IsValid(ent) then
			timer.Remove(timerId)
			return
		end

		local active = Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ActiveInterfaces and Star_Trek.LCARS.ActiveInterfaces[ent]
		if not active then
			timer.Remove(timerId)
			return
		end

		local grav = getController()
		generator = grav and grav:GetGenerator() or generator

		local scale = resolveCurrentScale(grav, generator) or 1
		local online = grav and grav:IsOnline() or (IsValid(generator) and generator:IsOperational() or false)
		local health = grav and grav:GetHealthPercent() or (IsValid(generator) and generator.GetHealthPercent and generator:GetHealthPercent() or 0)
		local healthValue = IsValid(generator) and (generator.LastHealthValue or generator:Health() or 0) or 0
		local overrideState = formatOverride(generator)
		scale = math.Round(scale, 2)

		local generatorValid = IsValid(generator)
		local overrideActive = generatorValid and generator.OverrideState == true or false
		local healthOk = (healthValue and healthValue > 0) or ((health or 0) > 0)
		if panelState then
			panelState.LastStatus = panelState.LastStatus or {}
			local lastStatus = panelState.LastStatus
			lastStatus.Scale = scale
			lastStatus.Health = health
			lastStatus.HealthValue = healthValue
			lastStatus.Online = online
			lastStatus.Override = overrideState
			lastStatus.OverrideActive = overrideActive
		end
		local matrixDirty = false

		local adjustmentsEnabled = generatorValid and overrideActive and healthOk
		local adjustmentsColor = adjustmentsEnabled and Star_Trek.LCARS.ColorOrange or Star_Trek.LCARS.ColorBlue
		if syncButtonState(self.IncreaseButton, {Disabled = not adjustmentsEnabled, Color = adjustmentsColor}) then
			matrixDirty = true
		end
		if syncButtonState(self.DecreaseButton, {Disabled = not adjustmentsEnabled, Color = adjustmentsColor}) then
			matrixDirty = true
		end

		local resetEnabled = healthOk and (online or overrideActive)
		local resetColor = resetEnabled and Star_Trek.LCARS.ColorLightBlue or Star_Trek.LCARS.ColorBlue
		if syncButtonState(self.ResetButton, {Disabled = not resetEnabled, Color = resetColor}) then
			matrixDirty = true
		end

		local emergencyEnabled = generatorValid and (healthOk or overrideActive)
		local emergencyColor = overrideActive and Star_Trek.LCARS.ColorLightBlue or Star_Trek.LCARS.ColorOrange
		local emergencyName = overrideActive and "Emergency Override (Active)" or "Emergency Override"
		if syncButtonState(self.EmergencyButton, {Disabled = not emergencyEnabled, Color = emergencyColor, Name = emergencyName}) then
			matrixDirty = true
		end

		local shutdownEnabled = healthOk and (online or overrideActive)
		local shutdownColor = shutdownEnabled and Star_Trek.LCARS.ColorRed or Star_Trek.LCARS.ColorBlue
		if syncButtonState(self.ShutdownButton, {Disabled = not shutdownEnabled, Color = shutdownColor}) then
			matrixDirty = true
		end

		local activateEnabled = generatorValid and healthOk
		local activateColor = activateEnabled and Star_Trek.LCARS.ColorLightBlue or Star_Trek.LCARS.ColorBlue
		if syncButtonState(self.ActivateButton, {Disabled = not activateEnabled, Color = activateColor}) then
			matrixDirty = true
		end

		local consoleDisabled = isConsoleDisabled()
		if self.DisableConsoleButton then
			if lastDisableState ~= consoleDisabled then
				lastDisableState = consoleDisabled
				self.DisableConsoleButton.Name = consoleDisabled and "Console Offline" or "Disable Console"
				self.DisableConsoleButton.Color = consoleDisabled and Star_Trek.LCARS.ColorRed or Star_Trek.LCARS.ColorOrange
				self.DisableConsoleButton.Disabled = consoleDisabled
				matrixDirty = true
			end
		end

		if matrixDirty then
			Star_Trek.LCARS:UpdateWindow(ent, matrixWindow.Id, matrixWindow)
		end

		refreshTelemetry(assembleTelemetryLines(scale, health, online, overrideState))

		local now = CurTime()
		if now >= nextStatusPulse then
			nextStatusPulse = now + math.Rand(0.6, 1.1)
			local entry
			if math.random() < 0.35 then
				entry = {
					Text = string.format("LCARS FIELD %.2fg/%03d%% :: %s", scale, health, overrideState),
					Color = online and (Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil) or (Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil),
				}
			else
				entry = randomStatusEntry()
			end
			rollStatusLine(entry)
		end
		if now >= nextHeartbeat then
			nextHeartbeat = now + (online and 3 or 1.5)
			local heartbeatText
			local heartbeatColor
			if online then
				heartbeatText = string.format("Diagnostic: %.2fg | %d%% integrity", scale, health)
				heartbeatColor = (health <= 45) and Star_Trek.LCARS.ColorOrange or Star_Trek.LCARS.ColorLightBlue
			else
				heartbeatText = "Diagnostic: Output offline; emergency mode required."
				heartbeatColor = Star_Trek.LCARS.ColorRed
			end
			pushTelemetryLine(heartbeatText, heartbeatColor)
			refreshTelemetry(assembleTelemetryLines(scale, health, online, overrideState))
		end

		if now >= nextTicker then
			nextTicker = now + 6
			local color = online and ((health <= 40) and Star_Trek.LCARS.ColorOrange or Star_Trek.LCARS.ColorLightBlue) or Star_Trek.LCARS.ColorRed
			pushLog(string.format("Field report: %.2fg | Integrity %d%% | %s", scale, health, online and "ONLINE" or "OFFLINE"), color)
			pushTelemetryLine(string.format("Field report queued: %.2fg, %d%%", scale, health), color)
			refreshTelemetry(assembleTelemetryLines(scale, health, online, overrideState))
		end

		if prevOnline == nil then
			prevOnline = online
		else
			if prevOnline ~= online then
				prevOnline = online
				local color = online and Star_Trek.LCARS.ColorLightBlue or Star_Trek.LCARS.ColorRed
				pushLog(online and "Gravity generators online. Output stabilized." or "Gravity generators offline. Emergency mode required.", color)
				pushTelemetryLine(online and "Generators online; field stable." or "Generators offline; emergency routing required.", color)
				refreshTelemetry(assembleTelemetryLines(scale, health, online, overrideState))
			end
		end

		if prevScale == nil then
			prevScale = scale
		elseif math.abs(prevScale - scale) >= 0.09 then
			prevScale = scale
			pushLog(string.format("Gravity output recalibrated to %.2fg", scale), Star_Trek.LCARS.ColorOrange)
			pushTelemetryLine(string.format("Gravity output now %.2fg", scale), Star_Trek.LCARS.ColorOrange)
			refreshTelemetry(assembleTelemetryLines(scale, health, online, overrideState))
		end

		if prevHealth == nil then
			prevHealth = health
		elseif math.abs(prevHealth - health) >= 5 then
			prevHealth = health
			if health <= 30 then
				pushLog("Warning: Gravity generator integrity critical.", Star_Trek.LCARS.ColorRed)
				pushTelemetryLine("Integrity critical; dispatch repair teams.", Star_Trek.LCARS.ColorRed)
			elseif health <= 60 then
				pushLog("Gravity generator integrity reduced. Monitor repairs.", Star_Trek.LCARS.ColorOrange)
				pushTelemetryLine("Integrity dropping; monitor repairs.", Star_Trek.LCARS.ColorOrange)
			end
			refreshTelemetry(assembleTelemetryLines(scale, health, online, overrideState))
		end

		if prevOverride == nil or prevOverride ~= overrideState then
			prevOverride = overrideState
			pushTelemetryLine(string.format("Override state: %s", overrideState), Star_Trek.LCARS.ColorOrange)
			refreshTelemetry(assembleTelemetryLines(scale, health, online, overrideState))
		end
	end

	timer.Create(timerId, 0.5, 0, update)
	update()

	return true, {matrixWindow, statusWindow, telemetryWindow}
end
