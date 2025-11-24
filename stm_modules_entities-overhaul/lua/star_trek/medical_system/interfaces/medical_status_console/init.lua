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
--  LCARS Medical Status | Server   --
---------------------------------------

if not istable(INTERFACE) then Star_Trek:LoadAllModules() return end
local SELF = INTERFACE

local Medical = Star_Trek.Medical or {}
local Logs = Star_Trek.Logs or {}

SELF.BaseInterface = "base"
SELF.LogType = "Medical Status"

local function noop()
	return false
end

local function isCommsOnline()
	if istable(Medical) and isfunction(Medical.IsCommunicationsOnline) then
		return Medical:IsCommunicationsOnline()
	end

	if StarTrekEntities and StarTrekEntities.Status and StarTrekEntities.Status.comms then
		return StarTrekEntities.Status.comms.active ~= false
	end

	return false
end

local function emitOfflineError(ent)
	if IsValid(ent) then
		ent:EmitSound("star_trek.lcars_error")
	end
end

local function applyOfflineState(widget, text, color)
	if not istable(widget) then
		return
	end

	widget.Name = text
	widget.Color = color
	if widget.AuxColor then
		widget.AuxColor = color
	end
end

local function disableWidgetForOffline(selfRef, widget)
	if not (istable(selfRef) and istable(widget)) then
		return
	end

	selfRef._offlineDisabledWidgets = selfRef._offlineDisabledWidgets or {}
	if selfRef._offlineDisabledWidgets[widget] == nil then
		selfRef._offlineDisabledWidgets[widget] = widget.Disabled
	end

	widget.Disabled = true
end

local function hasSensorTelemetry(entry)
	if not istable(entry) then
		return false
	end

	if entry.HasScrambler then
		return false
	end

	return entry.CombadgeActive == true or entry.LimitedTelemetryAvailable == true
end

local function isLimitedTelemetry(entry)
	if not istable(entry) then
		return false
	end

	return entry.CombadgeActive ~= true and entry.LimitedTelemetryAvailable == true and entry.HasScrambler ~= true
end

local function getLocationText(entry)
	if not istable(entry) then
		return "Unknown"
	end

	if entry.HasScrambler then
		return "Telemetry unavailable"
	end

	local hasTelemetryFlags = entry.CombadgeActive ~= nil or entry.LimitedTelemetryAvailable ~= nil or entry.IsUnknown ~= nil
	if hasTelemetryFlags and not hasSensorTelemetry(entry) then
		return "Telemetry unavailable"
	end

	local loc = entry.Location or {}
	if isstring(loc.SectionName) and loc.SectionName ~= "" then
		return loc.SectionName
	end

	if isnumber(loc.Deck) and isnumber(loc.Section) then
		return string.format("Deck %s Section %s", loc.Deck, loc.Section)
	end

	return "Unknown"
end

local function formatTimeAgo(timestamp)
	if not isnumber(timestamp) then
		return "Unknown"
	end

	local diff = math.max(CurTime() - timestamp, 0)
	if diff < 1 then
		return "moments ago"
	end

	if diff < 60 then
		return string.format("%.0f seconds ago", diff)
	end

	local minutes = math.floor(diff / 60)
	if minutes < 60 then
		return string.format("%d minute%s ago", minutes, minutes ~= 1 and "s" or "")
	end

	local hours = math.floor(minutes / 60)
	return string.format("%d hour%s ago", hours, hours ~= 1 and "s" or "")
end

local function getStatusText(entry)
	if not hasSensorTelemetry(entry) then
		return "Telemetry unavailable", Star_Trek.LCARS.ColorOrange
	end

	local scan = istable(entry) and entry.ScanData or nil
	if istable(scan) and scan.Alive then
		local health = scan.Health
		local label = "Stable"

		if isnumber(health) then
			if health < 25 then
				label = "CRITICAL"
			elseif health < 100 then
				label = "Injured"
			end
		else
			label = "Monitoring"
		end

		local color = isfunction(Medical.GetVitalColor) and Medical:GetVitalColor(health) or Star_Trek.LCARS.ColorLightBlue
		return label, color
	end

	if istable(entry) and istable(entry.InjuryReport) then
		local cause = entry.InjuryReport.Cause
		if isstring(cause) and cause ~= "" then
			return "DOWN: " .. cause, Star_Trek.LCARS.ColorRed
		end
	end

	return "No Life Signs", Star_Trek.LCARS.ColorRed
end

local function formatCrewLogEntry(entry)
	if not istable(entry) then
		return "Limited telemetry contact: Telemetry unavailable | Life Signs Telemetry unavailable | Combadge offline | Telemetry unavailable"
	end

	local name = entry.IsUnknown and "Limited telemetry contact" or entry.Name or "Unknown"
	local status = select(1, getStatusText(entry))
	local telemetryAvailable = hasSensorTelemetry(entry)
	local limitedTelemetry = isLimitedTelemetry(entry)
	local health = telemetryAvailable and istable(entry.ScanData) and entry.ScanData.Health or nil
	local healthText
	if telemetryAvailable and health ~= nil then
		healthText = isfunction(Medical.GetPercentText) and Medical:GetPercentText(health) or "Unknown"
	else
		healthText = "Telemetry unavailable"
	end
	if limitedTelemetry and healthText ~= "Telemetry unavailable" then
		healthText = healthText .. " (Sensor)"
	end
	if limitedTelemetry and status ~= "Telemetry unavailable" then
		status = status .. " (Sensor)"
	end
	local combadge = entry.CombadgeActive and "Combadge online" or "Combadge offline"
	local location = getLocationText(entry)
	if limitedTelemetry and location ~= "Telemetry unavailable" then
		location = location .. " (Sensor)"
	end

	local tags = {}
	if entry.IsUnknown then
		table.insert(tags, entry.HasScrambler and "Scrambled" or "Unregistered")
	end
	if entry.MarkedIntruder then
		table.insert(tags, "INTRUDER")
	end
	if entry.MarkedSecurityDetail then
		table.insert(tags, "DETAIL")
	end
	if #tags > 0 then
		name = string.format("%s [%s]", name, table.concat(tags, ", "))
	end

	return string.format("%s: %s | Life Signs %s | %s | %s", name, status, healthText, combadge, location)
end

local function categorizeRoster(roster)
	local counts = {
		total = 0,
		stable = 0,
		injured = 0,
		critical = 0,
		down = 0,
		combadgeOnline = 0,
		unknown = 0,
		intruders = 0,
		detailed = 0,
		scrambled = 0,
	}

	for _, entry in ipairs(roster or {}) do
		counts.total = counts.total + 1
		if entry.CombadgeActive then
			counts.combadgeOnline = counts.combadgeOnline + 1
		end
		if entry.IsUnknown then
			counts.unknown = counts.unknown + 1
		end
		if entry.MarkedIntruder then
			counts.intruders = counts.intruders + 1
		end
		if entry.MarkedSecurityDetail then
			counts.detailed = counts.detailed + 1
		end
		if entry.HasScrambler then
			counts.scrambled = counts.scrambled + 1
		end

		local scan = entry.ScanData
		if not istable(scan) or not scan.Alive then
			counts.down = counts.down + 1
		elseif not isnumber(scan.Health) then
			counts.injured = counts.injured + 1
		elseif scan.Health < 25 then
			counts.critical = counts.critical + 1
		elseif scan.Health < 100 then
			counts.injured = counts.injured + 1
		else
			counts.stable = counts.stable + 1
		end
	end

	return counts
end

function SELF:GetFocusedEntry(roster)
	local list = roster or self.Roster
	if not istable(list) or #list == 0 then
		return nil
	end

	if isstring(self.ActiveCrewId) then
		for _, entry in ipairs(list) do
			if entry.Id == self.ActiveCrewId then
				return entry
			end
		end
	end

	return list[1]
end

function SELF:GetIncludeUnknown()
	if self.IncludeUnknown == nil then
		if istable(Medical) and isfunction(Medical.GetConsoleIncludeUnbadged) and IsValid(self.Ent) then
			self.IncludeUnknown = Medical:GetConsoleIncludeUnbadged(self.Ent)
		else
			self.IncludeUnknown = false
		end
	end

	return self.IncludeUnknown
end

function SELF:SetIncludeUnknown(enabled)
	local newValue = enabled and true or false
	if self.IncludeUnknown == newValue then
		return
	end

	self.IncludeUnknown = newValue
	if istable(Medical) and isfunction(Medical.SetConsoleIncludeUnbadged) and IsValid(self.Ent) then
		Medical:SetConsoleIncludeUnbadged(self.Ent, newValue)
	end

	self:RefreshRoster()
end

function SELF:ToggleIncludeUnknown()
	if not self:IsSystemOnline() then
		emitOfflineError(self.Ent)
		return false
	end

	self:SetIncludeUnknown(not self:GetIncludeUnknown())
	return true
end

function SELF:GetIncludeScrambled()
	if self.IncludeScrambled == nil then
		if istable(Medical) and isfunction(Medical.GetConsoleTrackScrambled) and IsValid(self.Ent) then
			self.IncludeScrambled = Medical:GetConsoleTrackScrambled(self.Ent)
		else
			self.IncludeScrambled = false
		end
	end

	return self.IncludeScrambled
end

function SELF:SetIncludeScrambled(enabled)
	local newValue = false
	if self.IncludeScrambled == newValue then
		return
	end

	self.IncludeScrambled = newValue
	if istable(Medical) and isfunction(Medical.SetConsoleTrackScrambled) and IsValid(self.Ent) then
		Medical:SetConsoleTrackScrambled(self.Ent, false)
	end

	self:RefreshRoster()
end

function SELF:ToggleIncludeScrambled()
	if not self:IsSystemOnline() then
		emitOfflineError(self.Ent)
		return false
	end

	if IsValid(self.Ent) then
		self.Ent:EmitSound("star_trek.lcars_error")
	end

	self:SetIncludeScrambled(false)
	return false
end

function SELF:IsSystemOnline()
	return isCommsOnline()
end

function SELF:GetOfflinePulseColor()
	if self._offlinePulse then
		return Star_Trek.LCARS.ColorOrange
	end

	return Star_Trek.LCARS.ColorRed
end

function SELF:StartOfflinePulseTimer()
	if self._offlineTimerName then
		return
	end

	local ent = self.Ent
	if not IsValid(ent) then
		return
	end

	local id = string.format("Star_Trek.MedicalConsole.Offline.%d", ent:EntIndex())
	self._offlineTimerName = id
	self._offlinePulse = false

	timer.Create(id, 0.5, 0, function()
		if not IsValid(ent) then
			timer.Remove(id)
			self._offlineTimerName = nil
			self._offlinePulse = nil
			return
		end

		if not (Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ActiveInterfaces and Star_Trek.LCARS.ActiveInterfaces[ent]) then
			timer.Remove(id)
			self._offlineTimerName = nil
			self._offlinePulse = nil
			self._offlineDisabledWidgets = nil
			return
		end

		if self:IsSystemOnline() then
			timer.Remove(id)
			self._offlineTimerName = nil
			self._offlinePulse = nil
			self:UpdateUI()
			self:UpdateLifeSignsList()
			return
		end

		self._offlinePulse = not self._offlinePulse
		self:UpdateUI()
		self:UpdateLifeSignsList()
	end)
end

function SELF:StopOfflinePulseTimer()
	local id = self._offlineTimerName
	if id then
		timer.Remove(id)
		self._offlineTimerName = nil
	end

	self._offlinePulse = nil

	if istable(self._offlineDisabledWidgets) then
		for widget, prevState in pairs(self._offlineDisabledWidgets) do
			if istable(widget) then
				widget.Disabled = prevState
			end
		end
		self._offlineDisabledWidgets = nil
	end
end

function SELF:RenderOfflineState()
	local color = self:GetOfflinePulseColor()
	local offlineText = "SYSTEM OFFLINE"

	if self.StatusPage == "detail" then
		local widgets = istable(self.Widgets) and self.Widgets.Detail or nil
		if istable(widgets) then
			if istable(widgets.BackButton) then
				widgets.BackButton.Name = "Back to Overview"
				widgets.BackButton.Color = color
				widgets.BackButton.Disabled = false
			end
			applyOfflineState(widgets.RescanButton, offlineText, color)
			disableWidgetForOffline(self, widgets.RescanButton)
			applyOfflineState(widgets.ScanAll, offlineText, color)
			disableWidgetForOffline(self, widgets.ScanAll)
			if istable(widgets.Disable) then
				widgets.Disable.Name = "Disable Console"
				widgets.Disable.Color = color
				widgets.Disable.Disabled = false
			end
			applyOfflineState(widgets.MarkIntruder, offlineText, color)
			disableWidgetForOffline(self, widgets.MarkIntruder)
			applyOfflineState(widgets.MarkSecurityDetail, offlineText, color)
			disableWidgetForOffline(self, widgets.MarkSecurityDetail)
			applyOfflineState(widgets.Name, "Crew member: " .. offlineText, color)
			applyOfflineState(widgets.Location, "Location: " .. offlineText, color)
			applyOfflineState(widgets.Species, "Species: " .. offlineText, color)
			applyOfflineState(widgets.Status, "Status: " .. offlineText, color)
			applyOfflineState(widgets.Vitals, "Vitals: " .. offlineText, color)
			applyOfflineState(widgets.Combadge, "Combadge: OFFLINE", color)
			applyOfflineState(widgets.Intruder, "Security Status: " .. offlineText, color)
			applyOfflineState(widgets.SecurityDetail, "Security Detail: " .. offlineText, color)
			applyOfflineState(widgets.Injury, "Recent damage: " .. offlineText, color)
			applyOfflineState(widgets.LastScan, string.format("Last scan: -- (%s)", offlineText), color)
		end
	else
		local widgets = istable(self.Widgets) and self.Widgets.Overview or nil
		if istable(widgets) then
			applyOfflineState(widgets.CrewCount, offlineText, color)
			applyOfflineState(widgets.Alert, offlineText, color)
			applyOfflineState(widgets.Triage, offlineText, color)
			applyOfflineState(widgets.LastScan, string.format("Last scan: -- (%s)", offlineText), color)
			applyOfflineState(widgets.Instructions, offlineText .. " - COMMUNICATIONS UNAVAILABLE", color)
			applyOfflineState(widgets.LimitedTelemetry, offlineText, color)
			disableWidgetForOffline(self, widgets.LimitedTelemetry)
			applyOfflineState(widgets.ScrambledToggle, offlineText, color)
			disableWidgetForOffline(self, widgets.ScrambledToggle)
			applyOfflineState(widgets.DetailButton, offlineText, color)
			disableWidgetForOffline(self, widgets.DetailButton)
			applyOfflineState(widgets.ScanFocused, offlineText, color)
			disableWidgetForOffline(self, widgets.ScanFocused)
			applyOfflineState(widgets.ScanAll, offlineText, color)
			disableWidgetForOffline(self, widgets.ScanAll)
			if istable(widgets.Disable) then
				-- Keep disable button interactive but update color/text.
				widgets.Disable.Name = "Disable Console"
				widgets.Disable.Color = color
				widgets.Disable.Disabled = false
			end
		end
	end
end

function SELF:RefreshRoster()
	if not (istable(Medical) and isfunction(Medical.GetCrewRoster)) then
		return
	end

	if not self:IsSystemOnline() then
		self:SetRoster({})
		return
	end

	local roster = Medical:GetCrewRoster(self:GetIncludeUnknown(), self:GetIncludeScrambled()) or {}
	local activeId = self.ActiveCrewId
	self:SetRoster(table.Copy(roster))
	if activeId then
		self.ActiveCrewId = activeId
		self:EnsureActiveCrew()
		self:UpdateUI()
		self:UpdateLifeSignsList()
	end
end

function SELF:ToggleMarkedIntruder(ply)
	if not self:IsSystemOnline() then
		emitOfflineError(self.Ent)
		return false
	end

	local focus = self:GetFocusedEntry()
	if not istable(focus) or not focus.Id then
		if IsValid(self.Ent) then
			self.Ent:EmitSound("star_trek.lcars_error")
		end
		return false
	end

	if not focus.CanMarkIntruder then
		if IsValid(self.Ent) then
			self.Ent:EmitSound("star_trek.lcars_error")
		end
		return false
	end

	local desiredState = not focus.MarkedIntruder
	if istable(Medical) and isfunction(Medical.SetIntruder) then
		Medical:SetIntruder(focus.Id, desiredState)
	end

	if istable(Logs) and isfunction(Logs.AddEntry) then
		local displayName = focus.IsUnknown and "Limited telemetry contact" or focus.Name or focus.Id
		local message
		local color
		if desiredState then
			message = string.format("Marked %s as intruder.", displayName)
			color = Star_Trek.LCARS.ColorRed
		else
			message = string.format("Cleared intruder flag for %s.", displayName)
			color = Star_Trek.LCARS.ColorLightBlue
		end
		Logs:AddEntry(self.Ent, ply, message, color)
	end

	if IsValid(self.Ent) then
		self.Ent:EmitSound(desiredState and "star_trek.lcars_alert14" or "star_trek.lcars_close")
	end

	self:RefreshRoster()
	return true
end

function SELF:ToggleSecurityDetail(ply)
	if not self:IsSystemOnline() then
		emitOfflineError(self.Ent)
		return false
	end

	local focus = self:GetFocusedEntry()
	if not istable(focus) or not focus.Id then
		if IsValid(self.Ent) then
			self.Ent:EmitSound("star_trek.lcars_error")
		end
		return false
	end

	if focus.CanMarkSecurityDetail == false then
		if IsValid(self.Ent) then
			self.Ent:EmitSound("star_trek.lcars_error")
		end
		return false
	end

	local desiredState = not focus.MarkedSecurityDetail
	if istable(Medical) and isfunction(Medical.SetSecurityDetail) then
		Medical:SetSecurityDetail(focus.Id, desiredState)
	end

	if istable(Logs) and isfunction(Logs.AddEntry) then
		local displayName = focus.IsUnknown and "Limited telemetry contact" or focus.Name or focus.Id
		local message
		local color
		if desiredState then
			message = string.format("Flagged %s for security detail.", displayName)
			color = Star_Trek.LCARS.ColorOrange
		else
			message = string.format("Cleared security detail for %s.", displayName)
			color = Star_Trek.LCARS.ColorLightBlue
		end
		Logs:AddEntry(self.Ent, ply, message, color)
	end

	if IsValid(self.Ent) then
		self.Ent:EmitSound(desiredState and "star_trek.lcars_alert14" or "star_trek.lcars_close")
	end

	self:RefreshRoster()
	return true
end

function SELF:EnsureActiveCrew()
	if istable(self.RosterMap) and isstring(self.ActiveCrewId) and self.RosterMap[self.ActiveCrewId] then
		return
	end

	local focus = istable(self.Roster) and self.Roster[1] or nil
	self.ActiveCrewId = focus and focus.Id or nil
end

function SELF:SetStatusPage(page)
	if page ~= "detail" then
		page = "overview"
	end

	self.StatusPage = page

	if not istable(self.StatusWindow) then
		return
	end

	self:RebuildStatusWindow()
	self:UpdateLifeSignsList()
	self:UpdateUI()
end

function SELF:RebuildStatusWindow()
	if not istable(self.StatusWindow) then
		return
	end

	self.StatusWindow:ClearMainButtons()
	self.Widgets = self.Widgets or {}
	self.Widgets.Overview = self.Widgets.Overview or {}
	self.Widgets.Detail = self.Widgets.Detail or {}

	if self.StatusPage == "detail" then
		self:BuildDetailPage()
	else
		self:BuildOverviewPage()
	end

	self.StatusWindow:Update()
end

function SELF:BuildOverviewPage()
	local window = self.StatusWindow
	local widgets = {}
	self.Widgets.Overview = widgets

	local countRow = window:CreateMainButtonRow(38)
	widgets.CrewCount = window:AddButtonToRow(countRow, "Crew online: --", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local alertRow = window:CreateMainButtonRow(38)
	widgets.Alert = window:AddButtonToRow(alertRow, "Awaiting data", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local triageRow = window:CreateMainButtonRow(38)
	widgets.Triage = window:AddButtonToRow(triageRow, "Stable 0 | Injured 0 | Critical 0 | Down 0", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local scanInfoRow = window:CreateMainButtonRow(38)
	widgets.LastScan = window:AddButtonToRow(scanInfoRow, "Last scan: --", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local instructionsRow = window:CreateMainButtonRow(38)
	widgets.Instructions = window:AddButtonToRow(instructionsRow, "Select a crew member from LIFE SIGNS to view details", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local telemetryRow = window:CreateMainButtonRow(38)
	widgets.LimitedTelemetry = window:AddButtonToRow(telemetryRow, "Limited Telemetry: Hidden", nil, Star_Trek.LCARS.ColorOrange, nil, false, false, function(ply)
		return self:ToggleIncludeUnknown(ply)
	end)

	local actionRow = window:CreateMainButtonRow(46)
	widgets.DetailButton = window:AddButtonToRow(actionRow, "Open Crew Detail", nil, Star_Trek.LCARS.ColorOrange, nil, false, false, function(ply)
		local focus = self:GetFocusedEntry()
		if not focus then
			if IsValid(self.Ent) then
				self.Ent:EmitSound("star_trek.lcars_error")
			end
			return false
		end

		self:SetStatusPage("detail")
		return true
	end)

	widgets.ScanFocused = window:AddButtonToRow(actionRow, "Scan Focused", nil, Star_Trek.LCARS.ColorOrange, nil, false, false, function(ply)
		return self:PerformCrewScan(ply, true)
	end)

	widgets.ScanAll = window:AddButtonToRow(actionRow, "Scan All Crew", nil, Star_Trek.LCARS.ColorLightBlue, nil, false, false, function(ply)
		return self:PerformCrewScan(ply, false)
	end)

	local powerRow = window:CreateMainButtonRow(38)
	widgets.Disable = window:AddButtonToRow(powerRow, "Disable Console", nil, Star_Trek.LCARS.ColorRed, nil, false, false, function()
		if Star_Trek and Star_Trek.LCARS and IsValid(self.Ent) then
			Star_Trek.LCARS:CloseInterface(self.Ent)
		end
		return true
	end)

	self:ApplyTelemetryButtonState()
end

function SELF:BuildDetailPage()
	local window = self.StatusWindow
	local widgets = {}
	self.Widgets.Detail = widgets

	local navRow = window:CreateMainButtonRow(46)
	widgets.BackButton = window:AddButtonToRow(navRow, "Back to Overview", nil, Star_Trek.LCARS.ColorOrange, nil, false, false, function()
		self:SetStatusPage("overview")
		return true
	end)

	widgets.RescanButton = window:AddButtonToRow(navRow, "Rescan Crew Member", nil, Star_Trek.LCARS.ColorOrange, nil, false, false, function(ply)
		return self:PerformCrewScan(ply, true)
	end)

	widgets.ScanAll = window:AddButtonToRow(navRow, "Scan All Crew", nil, Star_Trek.LCARS.ColorLightBlue, nil, false, false, function(ply)
		return self:PerformCrewScan(ply, false)
	end)

	widgets.Disable = window:AddButtonToRow(navRow, "Disable Console", nil, Star_Trek.LCARS.ColorRed, nil, false, false, function()
		if Star_Trek and Star_Trek.LCARS and IsValid(self.Ent) then
			Star_Trek.LCARS:CloseInterface(self.Ent)
		end
		return true
	end)

	local securityActionRow = window:CreateMainButtonRow(38)
	widgets.MarkIntruder = window:AddButtonToRow(securityActionRow, "Mark Intruder", nil, Star_Trek.LCARS.ColorRed, nil, false, false, function(ply)
		return self:ToggleMarkedIntruder(ply)
	end)

	widgets.MarkSecurityDetail = window:AddButtonToRow(securityActionRow, "Flag Security Detail", nil, Star_Trek.LCARS.ColorOrange, nil, false, false, function(ply)
		return self:ToggleSecurityDetail(ply)
	end)

	local nameRow = window:CreateMainButtonRow(38)
	widgets.Name = window:AddButtonToRow(nameRow, "Crew member: --", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local locationRow = window:CreateMainButtonRow(38)
	widgets.Location = window:AddButtonToRow(locationRow, "Location: --", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local speciesRow = window:CreateMainButtonRow(38)
	widgets.Species = window:AddButtonToRow(speciesRow, "Species: --", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local statusRow = window:CreateMainButtonRow(38)
	widgets.Status = window:AddButtonToRow(statusRow, "Status: --", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local vitalsRow = window:CreateMainButtonRow(38)
	widgets.Vitals = window:AddButtonToRow(vitalsRow, "Vitals: --", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local combadgeRow = window:CreateMainButtonRow(38)
	widgets.Combadge = window:AddButtonToRow(combadgeRow, "Combadge: --", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local intruderRow = window:CreateMainButtonRow(38)
	widgets.Intruder = window:AddButtonToRow(intruderRow, "Security Status: --", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local securityDetailRow = window:CreateMainButtonRow(38)
	widgets.SecurityDetail = window:AddButtonToRow(securityDetailRow, "Security Detail: --", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)

	local injuryRow = window:CreateMainButtonRow(38)
	widgets.Injury = window:AddButtonToRow(injuryRow, "Recent damage: --", nil, Star_Trek.LCARS.ColorLightBlue, Star_Trek.LCARS.ColorLightBlue, true)

	local scanRow = window:CreateMainButtonRow(38)
	widgets.LastScan = window:AddButtonToRow(scanRow, "Last scan: --", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, true)
end

function SELF:ApplyTelemetryButtonState()
	local widgets = istable(self.Widgets) and self.Widgets.Overview or nil
	if not istable(widgets) then
		return
	end

	if istable(widgets.LimitedTelemetry) then
		if self:GetIncludeUnknown() then
			widgets.LimitedTelemetry.Name = "Limited Telemetry: Showing"
			widgets.LimitedTelemetry.Color = Star_Trek.LCARS.ColorLightBlue
		else
			widgets.LimitedTelemetry.Name = "Limited Telemetry: Hidden"
			widgets.LimitedTelemetry.Color = Star_Trek.LCARS.ColorOrange
		end
	end

	if istable(widgets.ScrambledToggle) then
		widgets.ScrambledToggle.Disabled = true
		widgets.ScrambledToggle.Name = "Scrambled Biosigns: Blocked"
		widgets.ScrambledToggle.Color = Star_Trek.LCARS.ColorOrange
	end
end

function SELF:UpdateOverviewWidgets(roster, focus)
	local widgets = istable(self.Widgets) and self.Widgets.Overview or nil
	if not istable(widgets) then
		return
	end

	self:ApplyTelemetryButtonState()

	local includeUnknown = self:GetIncludeUnknown()
	local counts = categorizeRoster(roster)

	if istable(widgets.CrewCount) then
		if counts.total > 0 then
			if includeUnknown and counts.unknown > 0 then
				local crewCount = counts.total - counts.unknown
				widgets.CrewCount.Name = string.format("Contacts: %d (Crew %d | Limited %d)", counts.total, crewCount, counts.unknown)
			else
				widgets.CrewCount.Name = string.format("Crew online: %d (%d combadges)", counts.total, counts.combadgeOnline)
			end
			widgets.CrewCount.Color = Star_Trek.LCARS.ColorLightBlue
		else
			widgets.CrewCount.Name = "Crew online: 0"
			widgets.CrewCount.Color = Star_Trek.LCARS.ColorOrange
		end
	end

	if istable(widgets.Alert) then
		if counts.total == 0 then
			widgets.Alert.Name = "Awaiting sensor contact"
			widgets.Alert.Color = Star_Trek.LCARS.ColorOrange
		elseif counts.down > 0 or counts.critical > 0 then
			local alertText = {}
			if counts.down > 0 then
				table.insert(alertText, string.format("%d down", counts.down))
			end
			if counts.critical > 0 then
				table.insert(alertText, string.format("%d critical", counts.critical))
			end
			widgets.Alert.Name = table.concat(alertText, " | ")
			widgets.Alert.Color = Star_Trek.LCARS.ColorRed
		elseif counts.injured > 0 then
			widgets.Alert.Name = string.format("%d injured crew", counts.injured)
			widgets.Alert.Color = Star_Trek.LCARS.ColorOrange
		elseif counts.detailed > 0 then
			widgets.Alert.Name = string.format("%d crew flagged for security detail", counts.detailed)
			widgets.Alert.Color = Star_Trek.LCARS.ColorOrange
		elseif includeUnknown and counts.unknown > 0 then
			local suffix = counts.unknown ~= 1 and "s" or ""
			widgets.Alert.Name = string.format("%d limited telemetry contact%s", counts.unknown, suffix)
			widgets.Alert.Color = Star_Trek.LCARS.ColorOrange
		else
			widgets.Alert.Name = "All crew stable"
			widgets.Alert.Color = Star_Trek.LCARS.ColorLightBlue
		end
	end

	if istable(widgets.Triage) then
		widgets.Triage.Name = string.format("Stable %d | Injured %d | Critical %d | Down %d", counts.stable, counts.injured, counts.critical, counts.down)
		widgets.Triage.Color = counts.down > 0 and Star_Trek.LCARS.ColorRed or Star_Trek.LCARS.ColorLightBlue
	end

	if istable(widgets.DetailButton) then
		widgets.DetailButton.Disabled = focus == nil
		if focus ~= nil then
			widgets.DetailButton.Color = Star_Trek.LCARS.ColorLightBlue
		else
			widgets.DetailButton.Color = Star_Trek.LCARS.ColorOrange
		end
	end

	if istable(widgets.Instructions) then
		if focus then
			local focusTags = {}
			if focus.IsUnknown then
				table.insert(focusTags, focus.HasScrambler and "Scrambled" or "Unregistered")
			end
			if focus.MarkedIntruder then
				table.insert(focusTags, "INTRUDER")
			end
			if focus.MarkedSecurityDetail then
				table.insert(focusTags, "DETAIL")
			end
			local label = focus.IsUnknown and "Limited telemetry contact" or focus.Name or "Unknown"
			if #focusTags > 0 then
				label = string.format("%s [%s]", label, table.concat(focusTags, ", "))
			end
			widgets.Instructions.Name = string.format("Focused: %s", label)
			widgets.Instructions.Color = Star_Trek.LCARS.ColorLightBlue
		else
			widgets.Instructions.Name = "Select a crew member from LIFE SIGNS to view details"
			widgets.Instructions.Color = Star_Trek.LCARS.ColorOrange
		end
	end
end

function SELF:UpdateDetailWidgets(entry)
	local widgets = istable(self.Widgets) and self.Widgets.Detail or nil
	if not istable(widgets) then
		return
	end

	if not istable(entry) then
		if istable(widgets.Name) then widgets.Name.Name = "Crew member: --" end
		if istable(widgets.Location) then widgets.Location.Name = "Location: --" end
		if istable(widgets.Species) then
			widgets.Species.Name = "Species: --"
			widgets.Species.Color = Star_Trek.LCARS.ColorOrange
		end
		if istable(widgets.Status) then widgets.Status.Name = "Status: --" end
		if istable(widgets.Vitals) then widgets.Vitals.Name = "Vitals: --" end
		if istable(widgets.Combadge) then widgets.Combadge.Name = "Combadge: --" end
		if istable(widgets.Injury) then widgets.Injury.Name = "Recent damage: --" end
		if istable(widgets.Intruder) then
			widgets.Intruder.Name = "Security Status: --"
			widgets.Intruder.Color = Star_Trek.LCARS.ColorOrange
		end
		if istable(widgets.MarkIntruder) then
			widgets.MarkIntruder.Name = "Mark Intruder"
			widgets.MarkIntruder.Color = Star_Trek.LCARS.ColorOrange
			widgets.MarkIntruder.Disabled = true
		end
		if istable(widgets.SecurityDetail) then
			widgets.SecurityDetail.Name = "Security Detail: --"
			widgets.SecurityDetail.Color = Star_Trek.LCARS.ColorOrange
		end
		if istable(widgets.MarkSecurityDetail) then
			widgets.MarkSecurityDetail.Name = "Flag Security Detail"
			widgets.MarkSecurityDetail.Color = Star_Trek.LCARS.ColorOrange
			widgets.MarkSecurityDetail.Disabled = true
		end
		return
	end

	local telemetryAvailable = hasSensorTelemetry(entry)
	local limitedTelemetry = isLimitedTelemetry(entry)

	if istable(widgets.Name) then
		local displayName = entry.IsUnknown and "Limited telemetry contact" or entry.Name or "Unknown"
		widgets.Name.Name = string.format("Crew member: %s", displayName)
		widgets.Name.Color = entry.IsUnknown and Star_Trek.LCARS.ColorOrange or Star_Trek.LCARS.ColorLightBlue
	end

	if istable(widgets.Location) then
		local locationText = getLocationText(entry)
		if limitedTelemetry and locationText ~= "Telemetry unavailable" then
			locationText = locationText .. " (Sensor)"
		end
		widgets.Location.Name = "Location: " .. locationText
		if locationText == "Telemetry unavailable" then
			widgets.Location.Color = Star_Trek.LCARS.ColorOrange
		else
			widgets.Location.Color = limitedTelemetry and Star_Trek.LCARS.ColorOrange or Star_Trek.LCARS.ColorLightBlue
		end
	end

	if istable(widgets.Species) then
		local speciesLabel = entry.Species or "Alien"
		widgets.Species.Name = "Species: " .. speciesLabel
		if speciesLabel == "Alien" then
			widgets.Species.Color = Star_Trek.LCARS.ColorOrange
		else
			widgets.Species.Color = Star_Trek.LCARS.ColorLightBlue
		end
	end

	if istable(widgets.Status) then
		local status, color = getStatusText(entry)
		if limitedTelemetry and status ~= "Telemetry unavailable" then
			status = status .. " (Sensor)"
		end
		widgets.Status.Name = "Status: " .. status
		widgets.Status.Color = color or Star_Trek.LCARS.ColorLightBlue
	end

	local scan = entry.ScanData or {}
	if istable(widgets.Vitals) then
		if telemetryAvailable then
			local healthText = isfunction(Medical.GetPercentText) and Medical:GetPercentText(scan.Health) or "Unknown"
			local armorText = isfunction(Medical.GetPercentText) and Medical:GetPercentText(scan.Armor) or "Unknown"
			local vitalsLabel = string.format("Vitals: Health %s | Armor %s", healthText, armorText)
			if limitedTelemetry then
				vitalsLabel = vitalsLabel .. " (Sensor)"
			end
			widgets.Vitals.Name = vitalsLabel
			widgets.Vitals.Color = isfunction(Medical.GetVitalColor) and Medical:GetVitalColor(scan.Health) or Star_Trek.LCARS.ColorLightBlue
		else
			widgets.Vitals.Name = "Vitals: Telemetry unavailable"
			widgets.Vitals.Color = Star_Trek.LCARS.ColorOrange
		end
	end

	if istable(widgets.Combadge) then
		if entry.CombadgeActive then
			widgets.Combadge.Name = "Combadge: Online"
			widgets.Combadge.Color = Star_Trek.LCARS.ColorLightBlue
		else
			widgets.Combadge.Name = "Combadge: Offline"
			widgets.Combadge.Color = Star_Trek.LCARS.ColorOrange
		end
	end

	if istable(widgets.Intruder) then
		local statusText = "Security Status: Cleared"
		local statusColor = Star_Trek.LCARS.ColorLightBlue
		if entry.MarkedIntruder then
			statusText = "Security Status: INTRUDER"
			statusColor = Star_Trek.LCARS.ColorRed
		elseif entry.IsUnknown then
			if entry.HasScrambler then
				statusText = "Security Status: Scrambled biosigns"
				statusColor = Star_Trek.LCARS.ColorOrange
			else
				statusText = "Security Status: Unregistered lifesign"
				statusColor = Star_Trek.LCARS.ColorOrange
			end
		end
		widgets.Intruder.Name = statusText
		widgets.Intruder.Color = statusColor
	end

	if istable(widgets.MarkIntruder) then
		if entry.CanMarkIntruder then
			widgets.MarkIntruder.Disabled = false
			if entry.MarkedIntruder then
				widgets.MarkIntruder.Name = "Clear Intruder Flag"
				widgets.MarkIntruder.Color = Star_Trek.LCARS.ColorLightBlue
			else
				widgets.MarkIntruder.Name = "Mark Intruder"
				widgets.MarkIntruder.Color = Star_Trek.LCARS.ColorRed
			end
		else
			widgets.MarkIntruder.Disabled = true
			if entry.HasScrambler then
				widgets.MarkIntruder.Name = "Scrambler Detected"
			else
				widgets.MarkIntruder.Name = "Mark Intruder"
			end
			widgets.MarkIntruder.Color = Star_Trek.LCARS.ColorOrange
		end
	end

	if istable(widgets.SecurityDetail) then
		if entry.MarkedSecurityDetail then
			widgets.SecurityDetail.Name = "Security Detail: Escort required"
			widgets.SecurityDetail.Color = Star_Trek.LCARS.ColorOrange
		else
			widgets.SecurityDetail.Name = "Security Detail: Cleared"
			widgets.SecurityDetail.Color = Star_Trek.LCARS.ColorLightBlue
		end
	end

	if istable(widgets.MarkSecurityDetail) then
		if entry.CanMarkSecurityDetail == false then
			widgets.MarkSecurityDetail.Disabled = true
			widgets.MarkSecurityDetail.Name = "Security Detail Unavailable"
			widgets.MarkSecurityDetail.Color = Star_Trek.LCARS.ColorOrange
		else
			widgets.MarkSecurityDetail.Disabled = false
			if entry.MarkedSecurityDetail then
				widgets.MarkSecurityDetail.Name = "Clear Security Detail"
				widgets.MarkSecurityDetail.Color = Star_Trek.LCARS.ColorLightBlue
			else
				widgets.MarkSecurityDetail.Name = "Flag Security Detail"
				widgets.MarkSecurityDetail.Color = Star_Trek.LCARS.ColorOrange
			end
		end
	end

	if istable(widgets.Injury) then
		local detail
		local color = Star_Trek.LCARS.ColorLightBlue
		if istable(entry.InjuryReport) and isstring(entry.InjuryReport.Cause) and entry.InjuryReport.Cause ~= "" then
			local whenText = formatTimeAgo(entry.InjuryReport.Time)
			local whereText = getLocationText({Location = entry.InjuryReport.Location})
			detail = string.format("%s (%s) at %s", entry.InjuryReport.Cause, whenText, whereText)
			color = Star_Trek.LCARS.ColorRed
		elseif istable(entry.LastDamage) and isfunction(Medical.DescribeDamage) then
			detail = string.format("%s (%s)", Medical:DescribeDamage(entry.LastDamage) or "Injury recorded", formatTimeAgo(entry.LastDamage.Time))
			color = Star_Trek.LCARS.ColorOrange
		else
			detail = "None reported"
		end
		widgets.Injury.Name = "Recent damage: " .. detail
		widgets.Injury.Color = color
	end
end

function SELF:UpdateUI()
	if not istable(self.StatusWindow) then
		return
	end

	if not self:IsSystemOnline() then
		self:StartOfflinePulseTimer()
		self:RenderOfflineState()
		self.StatusWindow:Update()
		return
	end

	self:StopOfflinePulseTimer()

	local roster = self.Roster or {}
	local focus = self:GetFocusedEntry()

	self:UpdateOverviewWidgets(roster, focus)
	self:UpdateDetailWidgets(focus)
	self.StatusWindow:Update()
end

function SELF:UpdateLifeSignsList()
	if not istable(self.LifeSignsWindow) then
		return
	end

	if not self:IsSystemOnline() then
		self:StartOfflinePulseTimer()
		local color = self:GetOfflinePulseColor()
		local buttons = {
			{
				Name = "SYSTEM OFFLINE - COMMUNICATIONS",
				Color = color,
				AuxColor = color,
				Disabled = true,
			},
		}
		self.LifeSignsWindow:SetButtons(buttons, 32)
		self.LifeSignsWindow:Update()
		return
	end

	self:StopOfflinePulseTimer()

	local buttons = {}
	for idx, entry in ipairs(self.Roster or {}) do
		local scan = entry.ScanData
		local statusLabel, statusColor = getStatusText(entry)
		local telemetryAvailable = hasSensorTelemetry(entry)
		local limitedTelemetry = isLimitedTelemetry(entry)
		local healthValue = istable(scan) and scan.Health or nil
		local healthText
		if telemetryAvailable then
			healthText = isfunction(Medical.GetPercentText) and Medical:GetPercentText(healthValue) or "Unknown"
		else
			healthText = "Telemetry unavailable"
		end
		local locationText = getLocationText(entry)
		if limitedTelemetry then
			if healthText ~= "Telemetry unavailable" then
				healthText = healthText .. " (Sensor)"
			end
			if statusLabel ~= "Telemetry unavailable" then
				statusLabel = statusLabel .. " (Sensor)"
			end
			if locationText ~= "Telemetry unavailable" then
				locationText = locationText .. " (Sensor)"
			end
		end
		local selected = isstring(self.ActiveCrewId) and entry.Id == self.ActiveCrewId
		local nameLabel = entry.Name or "Unknown"
		local speciesLabel = entry.Species or "Alien"
		local tags = {}
		if entry.IsUnknown then
			table.insert(tags, entry.HasScrambler and "Scrambled" or "Unregistered")
		end
		if entry.MarkedIntruder then
			table.insert(tags, "INTRUDER")
		end
		if entry.MarkedSecurityDetail then
			table.insert(tags, "DETAIL")
		end
		if entry.IsUnknown then
			nameLabel = "Limited telemetry contact"
			if not telemetryAvailable then
				healthText = "Telemetry unavailable"
				statusLabel = "Telemetry unavailable"
				locationText = "Telemetry unavailable"
			end
		end
		if #tags > 0 then
			nameLabel = string.format("%s [%s]", nameLabel, table.concat(tags, ", "))
		end

		local color = statusColor
		if entry.MarkedIntruder then
			color = Star_Trek.LCARS.ColorRed
		elseif entry.MarkedSecurityDetail then
			color = Star_Trek.LCARS.ColorOrange
		end

		local auxColor
		if entry.CombadgeActive then
			auxColor = Star_Trek.LCARS.ColorLightBlue
		elseif entry.HasScrambler then
			auxColor = Star_Trek.LCARS.ColorBlue
		elseif entry.LimitedTelemetryAvailable then
			auxColor = Star_Trek.LCARS.ColorLightBlue
		else
			auxColor = Star_Trek.LCARS.ColorOrange
		end

		buttons[idx] = {
			Name = string.format("%s | %s | %s | %s | %s", nameLabel, speciesLabel, healthText, statusLabel, locationText),
			Color = color,
			AuxColor = auxColor,
			Data = entry.Id,
			Selected = selected,
		}
	end

	if #buttons == 0 then
		buttons[1] = {
			Name = "No lifesigns detected",
			Color = Star_Trek.LCARS.ColorOrange,
			Disabled = true,
		}
	end

	self.LifeSignsWindow:SetButtons(buttons, 32)
	self.LifeSignsWindow:Update()
end

function SELF:SetLastScan(timestamp)
	self.LastScanTime = timestamp

	local overview = istable(self.Widgets) and self.Widgets.Overview or nil
	if istable(overview) and istable(overview.LastScan) then
		if not isnumber(timestamp) then
			overview.LastScan.Name = "Last scan: --"
			overview.LastScan.Color = Star_Trek.LCARS.ColorOrange
		else
			local display
			if Star_Trek and Star_Trek.Util and isfunction(Star_Trek.Util.GetTime) then
				display = Star_Trek.Util:GetTime(timestamp)
			else
				display = os.date("%c", timestamp)
			end
			overview.LastScan.Name = "Last scan: " .. display
			overview.LastScan.Color = Star_Trek.LCARS.ColorLightBlue
		end
	end

	local detail = istable(self.Widgets) and self.Widgets.Detail or nil
	if istable(detail) and istable(detail.LastScan) then
		if not isnumber(timestamp) then
			detail.LastScan.Name = "Last scan: --"
			detail.LastScan.Color = Star_Trek.LCARS.ColorOrange
		else
			detail.LastScan.Name = string.format("Last scan: %s", os.date("%c", timestamp))
			detail.LastScan.Color = Star_Trek.LCARS.ColorLightBlue
		end
	end

	if istable(self.StatusWindow) then
		self.StatusWindow:Update()
	end
end

function SELF:SetRoster(roster)
	self.Roster = roster or {}
	self.RosterMap = {}

	for _, entry in ipairs(self.Roster) do
		if entry.Id then
			self.RosterMap[entry.Id] = entry
		end
	end

	self:EnsureActiveCrew()

	if not istable(self.StatusWindow) then
		self.PendingRoster = table.Copy(self.Roster)
		return
	end

	self.PendingRoster = nil

	self:UpdateUI()
	self:UpdateLifeSignsList()
end

function SELF:PerformCrewScan(ply, focusOnly)
	local ent = self.Ent
	if not IsValid(ent) then
		return false
	end

	if not self:IsSystemOnline() then
		emitOfflineError(ent)
		return false
	end

	local rosterFull = {}
	if istable(Medical) and isfunction(Medical.GetCrewRoster) then
		rosterFull = Medical:GetCrewRoster(true, false) or {}
	end

	local displayRoster
	if self:GetIncludeUnknown() then
		displayRoster = rosterFull
	else
		displayRoster = {}
		for _, entry in ipairs(rosterFull) do
			if not entry.IsUnknown then
				table.insert(displayRoster, entry)
			end
		end
	end

	local targets = {}
	if focusOnly then
		local focusId = self.ActiveCrewId
		local focusEntry
		if isstring(focusId) then
			for _, entry in ipairs(rosterFull) do
				if entry.Id == focusId then
					focusEntry = entry
					break
				end
			end
		end
		if not focusEntry then
			focusEntry = self:GetFocusedEntry(displayRoster)
		end
		if focusEntry then
			table.insert(targets, focusEntry)
		end
	else
		targets = rosterFull
	end

	if #targets == 0 then
		if IsValid(ent) then
			ent:EmitSound("star_trek.lcars_error")
		end
		return false
	end

	self:SetRoster(table.Copy(displayRoster))

	if istable(Medical) and isfunction(Medical.TriggerDownedAlerts) then
		Medical:TriggerDownedAlerts(rosterFull)
	end

	self:SetLastScan(os.time())

	if IsValid(ent) then
		ent:EmitSound("star_trek.lcars_close")
	end

	if istable(Logs) and isfunction(Logs.AddEntry) then
		local prefix = focusOnly and "Focused scan" or "Crew scan"
		Logs:AddEntry(ent, ply, string.format("%s: %d lifesigns analysed.", prefix, #targets), Star_Trek.LCARS.ColorLightBlue)
		for _, entry in ipairs(targets) do
			local text = formatCrewLogEntry(entry)
			local _, statusColor = getStatusText(entry)
			local color = statusColor or (entry.CombadgeActive and Star_Trek.LCARS.ColorLightBlue or Star_Trek.LCARS.ColorOrange)
			if entry.MarkedIntruder then
				color = Star_Trek.LCARS.ColorRed
			end
			Logs:AddEntry(ent, ply, text, color)
		end
	end

	self:UpdateUI()

	return true
end

function SELF:CreateStatusWindow()
	local success, window = Star_Trek.LCARS:CreateWindow(
		"button_matrix",
		Vector(11, -2, -18.7),
		Angle(0, 87.5, 32),
		16,
		720,
		400,
		noop,
		"Crew Status",
		"STAT",
		false
	)
	if not success then
		return false, window
	end

	self.StatusWindow = window
	self.StatusPage = self.StatusPage or "overview"
	self:RebuildStatusWindow()

	return true, window
end

function SELF:CreateLifeSignsWindow()
	local success, window = Star_Trek.LCARS:CreateWindow(
		"button_list",
		Vector(-6.5, -1, 12),
		Angle(0, 87, 90),
		16,
		750,
		800,
		function(windowData, interfaceData, ply, buttonId, buttonData)
			if not istable(buttonData) or not buttonData.Data then
				return false
			end

			interfaceData.ActiveCrewId = buttonData.Data
			interfaceData:SetStatusPage("detail")
			interfaceData:UpdateLifeSignsList()

			local successScan = interfaceData:PerformCrewScan(ply, true)
			if not successScan then
				interfaceData:UpdateUI()
			end

			return successScan
		end,
		{},
		"Life Signs",
		"LIFE",
		false,
		false,
		32
	)
	if not success then
		return false, window
	end

	self.LifeSignsWindow = window
	return true, window
end

function SELF:Open(ent)
	self.Ent = ent
	self.IncludeScrambled = nil
	self:GetIncludeScrambled()
	self.IncludeUnknown = nil
	self:GetIncludeUnknown()

	local windows = {}

	local successStatus, statusWindow = self:CreateStatusWindow()
	if not successStatus then
		return false, statusWindow
	end
	table.insert(windows, statusWindow)

	local successLife, lifeWindow = self:CreateLifeSignsWindow()
	if not successLife then
		return false, lifeWindow
	end
	table.insert(windows, lifeWindow)

	if istable(self.PendingRoster) then
		self:SetRoster(self.PendingRoster)
		self.PendingRoster = nil
	else
		self:SetRoster(self.Roster or {})
	end

	self:SetStatusPage(self.StatusPage or "overview")
	self:SetLastScan(self.LastScanTime)

	return true, windows
end
