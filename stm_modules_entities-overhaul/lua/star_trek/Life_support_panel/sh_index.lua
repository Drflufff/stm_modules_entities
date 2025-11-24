Star_Trek:RequireModules("button", "lcars")

Star_Trek.Life_Support_Panel = Star_Trek.Life_Support_Panel or {}
if Star_Trek.Life_Support_Panel.Debug == nil then
	Star_Trek.Life_Support_Panel.Debug = false
end
if Star_Trek.Life_Support_Panel.ConsoleDisabled == nil then
	Star_Trek.Life_Support_Panel.ConsoleDisabled = false
end
Star_Trek.Life_Support_Panel.ReenablePending = Star_Trek.Life_Support_Panel.ReenablePending or false

if CLIENT then
	return
end

if game.GetMap() ~= "rp_intrepid_v1" then return end

include("star_trek/Life_support_panel/entities/life_support_core.lua")

local PANEL_POS = Vector(255.98, -246.70, 12390.24)
local PANEL_ANG = Angle(0, 0, 20)
local PANEL_MODEL = "models/kingpommes/startrek/intrepid/eng_console_wall3.mdl"
local CORE_POS = Vector(534.13, 176.07, 12396.09)
local CORE_ANG = Angle(-90, -89.97, 180)
local CRITICAL_MESSAGE = "LIFE SUPPORT DAMAGED ALERT ALERT LIFE SUPPORT DAMAGED"
local BACKUP_DURATION = 45
local EMERGENCY_DURATION = 300
local MANUAL_SHUTDOWN_DURATION = 90
local BACKUP_MARKER_CLASS = "pfx8_07"
local BACKUP_MARKER_MODEL = "models/hunter/blocks/cube025x025x025.mdl"
local BACKUP_MARKER_POS = Vector(520.86, 213.76, 12411.23)
local BACKUP_MARKER_ANG = Angle(20.97, -175.76, 3.03)

function Star_Trek.Life_Support_Panel:BroadcastLog(message, color)
	if not (Star_Trek and Star_Trek.Logs and Star_Trek.Logs.Sessions) then return end
	for ent, session in pairs(Star_Trek.Logs.Sessions) do
		if IsValid(ent) and istable(session) and session.Status == ST_LOGS_ACTIVE then
			Star_Trek.Logs:AddEntry(ent, nil, message, color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorRed or nil))
		end
	end
end

function Star_Trek.Life_Support_Panel:SpawnFailureMarker()
	local existing = self.FailureMarker
	local marker = ents.Create(BACKUP_MARKER_CLASS)
	if not IsValid(marker) then
		if not IsValid(existing) then
			print("[LifeSupportPanel] Failed to spawn backup oxygen indicator")
		end
		return
	end

	if IsValid(existing) then
		existing:Remove()
	end

	marker:SetPos(BACKUP_MARKER_POS)
	marker:SetAngles(BACKUP_MARKER_ANG)
	marker:SetModel(BACKUP_MARKER_MODEL)
	marker:Spawn()
	marker:Activate()
	self.FailureMarker = marker
end

function Star_Trek.Life_Support_Panel:RemoveFailureMarker()
	if IsValid(self.FailureMarker) then
		self.FailureMarker:Remove()
	end
	self.FailureMarker = nil
end

function Star_Trek.Life_Support_Panel:StartBackupWindow(core, duration, message, color, broadcast)
	if not IsValid(core) then return end
	if not isnumber(duration) or duration <= 0 then return end

	if isfunction(core.SpawnRepairPanel) and not IsValid(core.RepairPanel) then
		core:SpawnRepairPanel()
		if self.Core == core then
			self.CoreButton = core.RepairPanel
		end
	end

	local now = CurTime()
	local expires = now + duration

	if isfunction(core.SetBackupDeadline) then
		core:SetBackupDeadline(expires)
	elseif isfunction(core.ExtendBackup) then
		core:ExtendBackup(duration)
	end

	self.BackupExpires = math.max(self.BackupExpires or 0, expires)

	if message then
		local logColor = color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil)
		self:Log(message, logColor)
		self:AddOperationsLog(message, logColor)
		if broadcast then
			self:BroadcastLog(message, logColor)
		end
	end
end

function Star_Trek.Life_Support_Panel:ClearBackupWindow()
	self.BackupExpires = nil
	self:RemoveFailureMarker()
end

function Star_Trek.Life_Support_Panel:TriggerEmergencyOverride(ply)
	local core = self.Core
	if not IsValid(core) then
		return false, "Life support core unavailable."
	end

	if core:IsOperational() then
		return false, "Life support is online. Emergency override not required."
	end

	local desired = CurTime() + EMERGENCY_DURATION
	if core.BackupEndTime and core.BackupEndTime >= desired - 1 then
		return false, "Emergency override reserves already active."
	end

	if isfunction(core.SetBackupDeadline) then
		core:SetBackupDeadline(desired)
	else
		core:ExtendBackup(EMERGENCY_DURATION)
	end

	local color = Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil
	self:StartBackupWindow(core, EMERGENCY_DURATION, "Emergency override engaged. Reserve oxygen available for 5 minutes.", color, true)
	self:BroadcastLog("EMERGENCY OVERRIDE: Reserve oxygen deployed for five minutes.", color)
	if not IsValid(self.FailureMarker) then
		self:SpawnFailureMarker()
	end

	return true
end

function Star_Trek.Life_Support_Panel:Log(message, color, ply)
	if not (Star_Trek and Star_Trek.Logs) then return end
	local panel = self.Button
	if not IsValid(panel) then return end
	Star_Trek.Logs:AddEntry(panel, ply, message, color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorBlue or nil))
end

function Star_Trek.Life_Support_Panel:AddOperationsLog(message, color)
	self.PendingOperationsLogs = self.PendingOperationsLogs or {}

	if not (Star_Trek and Star_Trek.Logs) then
		table.insert(self.PendingOperationsLogs, {Message = message, Color = color})
		return
	end

	if IsValid(self.OperationsPanelEnt) then
		Star_Trek.Logs:AddEntry(self.OperationsPanelEnt, nil, message, color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorRed or nil))
	else
		table.insert(self.PendingOperationsLogs, {Message = message, Color = color})
	end
end

function Star_Trek.Life_Support_Panel:FlushOperationsLogs()
	if not (Star_Trek and Star_Trek.Logs) then return end
	if not IsValid(self.OperationsPanelEnt) then return end
	if not istable(self.PendingOperationsLogs) then return end

	for _, entry in ipairs(self.PendingOperationsLogs) do
		Star_Trek.Logs:AddEntry(self.OperationsPanelEnt, nil, entry.Message, entry.Color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorRed or nil))
	end
	self.PendingOperationsLogs = {}
end

function Star_Trek.Life_Support_Panel:OnCriticalDamage(core)
	self:Log(CRITICAL_MESSAGE, Star_Trek.LCARS and Star_Trek.LCARS.ColorRed)
	self:AddOperationsLog(CRITICAL_MESSAGE, Star_Trek.LCARS and Star_Trek.LCARS.ColorRed)

	if self.Debug then
		print("[LifeSupportPanel] Critical damage alert dispatched")
	end
end

function Star_Trek.Life_Support_Panel:TryOpenInterface(ply)
	if not IsValid(ply) or not ply:IsPlayer() then
		return false, "Invalid player"
	end

	if not (Star_Trek and Star_Trek.LCARS) then
		return false, "LCARS unavailable"
	end

	local panel = self.Button
	if not IsValid(panel) then
		return false, "Life support panel not present"
	end

	if self.ConsoleDisabled then
		return false, "Life support console offline for maintenance"
	end

	if Star_Trek.LCARS.ActiveInterfaces and Star_Trek.LCARS.ActiveInterfaces[panel] then
		return true
	end

	local success, err = Star_Trek.LCARS:OpenInterface(ply, panel, "life_support_panel")
	if not success then
		if self.Debug then
			print(string.format("[LifeSupportPanel] Open failed: %s", tostring(err)))
		end
	end
	return success, err
end

local function ensureCore()
	if Star_Trek.Life_Support_Panel.Core and IsValid(Star_Trek.Life_Support_Panel.Core) then
		if Star_Trek.Life_Support_Panel.Debug then
			print("[LifeSupportPanel] Reusing existing life support core entity")
		end
		return Star_Trek.Life_Support_Panel.Core
	end

	for _, ent in ipairs(ents.FindByClass("life_support_core")) do
		Star_Trek.Life_Support_Panel.Core = ent
		if Star_Trek.Life_Support_Panel.Debug then
			print("[LifeSupportPanel] Located life support core entity already on map")
		end
		if isfunction(ent.SpawnRepairPanel) then
			timer.Simple(0, function()
				if not IsValid(ent) then return end
				ent:SpawnRepairPanel()
				Star_Trek.Life_Support_Panel.CoreButton = ent.RepairPanel
			end)
		end
		return ent
	end

	local core = ents.Create("life_support_core")
	if not IsValid(core) then
		print("[LifeSupportPanel] Failed to create life support core")
		return nil
	end

	core:SetPos(CORE_POS)
	core:SetAngles(CORE_ANG)
	core:Spawn()
	core:Activate()
	timer.Simple(0, function()
		if not IsValid(core) then return end
		if isfunction(core.SpawnRepairPanel) then
			core:SpawnRepairPanel()
			Star_Trek.Life_Support_Panel.CoreButton = core.RepairPanel
		end
	end)

	if Star_Trek.Life_Support_Panel.Debug then
		print(string.format("[LifeSupportPanel] Life support core ready at %s", tostring(CORE_POS)))
	end

	Star_Trek.Life_Support_Panel.Core = core
	return core
end

local function spawnPanel()
	if IsValid(Star_Trek.Life_Support_Panel.Button) then
		Star_Trek.Life_Support_Panel.Button:Remove()
	end

	local success, panel = Star_Trek.Button:CreateInterfaceButton(PANEL_POS, PANEL_ANG, PANEL_MODEL, "life_support_panel", true)
	if not success then
		print("[LifeSupportPanel] Failed to spawn panel:", panel)
		return
	end

	Star_Trek.Life_Support_Panel.Button = panel
	if Star_Trek.Life_Support_Panel.Debug then
		print(string.format("[LifeSupportPanel] Panel spawned at %s", tostring(PANEL_POS)))
	end
	local phys = panel:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	if not ensureCore() then
		print("[LifeSupportPanel] Warning: life support core unavailable after panel spawn")
	end

	Star_Trek.Life_Support_Panel.ConsoleDisabled = false
	Star_Trek.Life_Support_Panel.ReenablePending = false
end

hook.Add("InitPostEntity", "Star_Trek.LifeSupportPanel.Spawn", function()
	spawnPanel()
	if Star_Trek.Life_Support_Panel.Debug then
		print("[LifeSupportPanel] InitPostEntity spawn sequence complete")
	end
end)

hook.Add("PostCleanupMap", "Star_Trek.LifeSupportPanel.Cleanup", function()
	timer.Simple(0.5, spawnPanel)
	if Star_Trek.Life_Support_Panel.Debug then
		print("[LifeSupportPanel] Map cleanup detected, respawning panel shortly")
	end
	Star_Trek.Life_Support_Panel.ConsoleDisabled = false
	Star_Trek.Life_Support_Panel.ReenablePending = false
	Star_Trek.Life_Support_Panel:ClearBackupWindow()
end)

hook.Add("OnLifeSupportDestroyed", "Star_Trek.LifeSupportPanel.Destruction", function(ent)
	if not IsValid(ent) then return end
	if Star_Trek.Life_Support_Panel.Core ~= ent then return end

	local color = Star_Trek.LCARS and Star_Trek.LCARS.ColorRed or nil
	Star_Trek.Life_Support_Panel:Log("Life support core destroyed. Atmospheric integrity compromised.", color)
	Star_Trek.Life_Support_Panel:AddOperationsLog("Life support core destroyed. Atmospheric integrity compromised.", color)
	Star_Trek.Life_Support_Panel:BroadcastLog("ALERT: Life support core destroyed. Repairs required immediately.", color)
	Star_Trek.Life_Support_Panel:SpawnFailureMarker()
	Star_Trek.Life_Support_Panel:StartBackupWindow(ent, BACKUP_DURATION, "Backup oxygen engaged. Atmospheric collapse in 45 seconds.", color, true)

	if Star_Trek and Star_Trek.Alert and isfunction(Star_Trek.Alert.Enable) then
		Star_Trek.Alert:Enable("red")
	end
end)

hook.Add("OnLifeSupportRepaired", "Star_Trek.LifeSupportPanel.Log", function(ent)
	if not IsValid(ent) then return end
	if Star_Trek.Life_Support_Panel.Core ~= ent then return end
	local color = Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil
	Star_Trek.Life_Support_Panel:Log("Life support core restored. Atmospheric systems stabilizing.", color)
	Star_Trek.Life_Support_Panel:AddOperationsLog("Life support core restored. Atmospheric systems stabilizing.", color)
	Star_Trek.Life_Support_Panel:BroadcastLog("Life support restored. Atmospheric systems stabilizing.", color)
	Star_Trek.Life_Support_Panel:ClearBackupWindow()
end)

hook.Add("OnLifeSupportRemoved", "Star_Trek.LifeSupportPanel.ClearCoreButton", function(ent)
	if not IsValid(ent) then return end
	if Star_Trek.Life_Support_Panel.Core ~= ent then return end
	Star_Trek.Life_Support_Panel.CoreButton = nil
	Star_Trek.Life_Support_Panel:ClearBackupWindow()
end)

hook.Add("OnLifeSupportBackupUpdated", "Star_Trek.LifeSupportPanel.BackupUpdated", function(core, deadline)
	if not IsValid(core) then return end
	if Star_Trek.Life_Support_Panel.Core ~= core then return end
	Star_Trek.Life_Support_Panel.BackupExpires = deadline
end)

hook.Add("OnLifeSupportBackupCleared", "Star_Trek.LifeSupportPanel.BackupCleared", function(core)
	if not IsValid(core) then return end
	if Star_Trek.Life_Support_Panel.Core ~= core then return end
	Star_Trek.Life_Support_Panel:ClearBackupWindow()
end)

hook.Add("OnLifeSupportBackupExpired", "Star_Trek.LifeSupportPanel.BackupExpired", function(core)
	if not IsValid(core) then return end
	if Star_Trek.Life_Support_Panel.Core ~= core then return end
	if core:IsOperational() then
		Star_Trek.Life_Support_Panel:ClearBackupWindow()
		return
	end
	Star_Trek.Life_Support_Panel.BackupExpires = nil
	local color = Star_Trek.LCARS and Star_Trek.LCARS.ColorRed or nil
	Star_Trek.Life_Support_Panel:Log("Backup oxygen depleted. Atmospheric collapse imminent.", color)
	Star_Trek.Life_Support_Panel:AddOperationsLog("Backup oxygen depleted. Atmospheric collapse imminent.", color)
	Star_Trek.Life_Support_Panel:BroadcastLog("CRITICAL: Backup oxygen depleted. Atmospheric collapse imminent!", color)
end)

hook.Add("StarTrekEntities.LifeSupportPowerChanged", "Star_Trek.LifeSupportPanel.PowerToggle", function(_, online)
	local core = Star_Trek.Life_Support_Panel.Core
	if not IsValid(core) then return end

	if online then
		if isfunction(core.SetBackupDeadline) then
			core:SetBackupDeadline(nil)
		end
		Star_Trek.Life_Support_Panel:ClearBackupWindow()
		return
	end

	if core:GetLifeSupportHealth() <= 0 then
		-- Core already destroyed; destruction handler manages backup window.
		return
	end

	Star_Trek.Life_Support_Panel:SpawnFailureMarker()
	local color = Star_Trek.LCARS and Star_Trek.LCARS.ColorOrange or nil
	Star_Trek.Life_Support_Panel:StartBackupWindow(core, MANUAL_SHUTDOWN_DURATION, "Life support manually offline. Reserve oxygen available for 90 seconds.", color, true)
end)

hook.Add("Star_Trek.LCARS.PostOpenInterface", "Star_Trek.LifeSupportPanel.TrackOperations", function(ent)
	if not IsValid(ent) then return end

	local interfaceData
	if Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ActiveInterfaces then
		interfaceData = Star_Trek.LCARS.ActiveInterfaces[ent]
	end

	if not istable(interfaceData) or interfaceData.Class ~= "bridge_targeting_base" then return end

	Star_Trek.Life_Support_Panel.OperationsPanelEnt = ent
	if Star_Trek.Life_Support_Panel.Debug then
		print(string.format("[LifeSupportPanel] Tracking operations interface on entity %s", tostring(ent)))
	end
	Star_Trek.Life_Support_Panel:FlushOperationsLogs()
end)

hook.Add("Star_Trek.LCARS.PostCloseInterface", "Star_Trek.LifeSupportPanel.ClearOperations", function(ent)
	if not IsValid(ent) then return end
	if Star_Trek.Life_Support_Panel.OperationsPanelEnt ~= ent then return end

	Star_Trek.Life_Support_Panel.OperationsPanelEnt = nil
	if Star_Trek.Life_Support_Panel.Debug then
		print("[LifeSupportPanel] Operations interface closed; awaiting reopen for queued alerts")
	end
end)

hook.Add("Star_Trek.LCARS.PreOpenInterface", "Star_Trek.LifeSupportPanel.ResumeFromDisable", function(ent, interfaceName)
	if interfaceName ~= "life_support_panel" then return end
	if ent ~= Star_Trek.Life_Support_Panel.Button then return end
	if not Star_Trek.Life_Support_Panel.ConsoleDisabled then return end

	Star_Trek.Life_Support_Panel.ConsoleDisabled = false

	if Star_Trek.Life_Support_Panel.ReenablePending then
		Star_Trek.Life_Support_Panel.ReenablePending = false
		Star_Trek.Life_Support_Panel:Log("Life support console manually reactivated.", Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue)
		Star_Trek.Life_Support_Panel:AddOperationsLog("Life support console manually reactivated.", Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue)
	end

	if Star_Trek.Life_Support_Panel.Debug then
		print("[LifeSupportPanel] Console reactivated via panel use")
	end
end)
