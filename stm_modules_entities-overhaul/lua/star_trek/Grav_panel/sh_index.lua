Star_Trek:RequireModules("button", "lcars")

Star_Trek.Grav_Panel = Star_Trek.Grav_Panel or {}
if Star_Trek.Grav_Panel.Debug == nil then
	Star_Trek.Grav_Panel.Debug = false
end
if Star_Trek.Grav_Panel.ConsoleDisabled == nil then
	Star_Trek.Grav_Panel.ConsoleDisabled = false
end
if Star_Trek.Grav_Panel.ReenablePending == nil then
	Star_Trek.Grav_Panel.ReenablePending = false
end

AddCSLuaFile("star_trek/Grav_panel/interfaces/grav_panel/init.lua")

if CLIENT then
	return
end

if game.GetMap() ~= "rp_intrepid_v1" then return end

include("star_trek/Grav_panel/entities/grav_generator.lua")

local PANEL_POS = Vector(926.25, -150.75, 11768.13)
local PANEL_ANG = Angle(0.01, 90, -0.02)
local PANEL_MODEL = "models/hunter/blocks/cube025x025x025.mdl"

local GENERATOR_POS = Vector(1694.51, -381.71, 12077.13)
local GENERATOR_ANG = Angle(89.98, -90.01, 180)
local GENERATOR_MODEL = "models/hunter/blocks/cube05x075x025.mdl"

local REPAIR_PROP_MODEL = "models/kingpommes/startrek/intrepid/eng_wallpanel.mdl"
local REPAIR_PROP_POS = Vector(1694.94, -387.54, 12079.16)
local REPAIR_PROP_ANG = Angle(-89.99, -180, 180)
local REPAIR_PROP_RADIUS = 36

local CLEANUP_CLASSES = {"prop_physics", "prop_dynamic", "prop_dynamic_override", "prop_static"}

Star_Trek.Grav_Panel.LeakPosition = Vector(1642, -381, 12069)
Star_Trek.Grav_Panel.LeakAngle = Angle(0, 0, 0)

function Star_Trek.Grav_Panel:BroadcastLog(message, color)
	if not (Star_Trek and Star_Trek.Logs and Star_Trek.Logs.Sessions) then return end
	for ent, session in pairs(Star_Trek.Logs.Sessions) do
		if IsValid(ent) and istable(session) and session.Status == ST_LOGS_ACTIVE then
			Star_Trek.Logs:AddEntry(ent, nil, message, color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil))
		end
	end
end

function Star_Trek.Grav_Panel:Log(message, color, ply)
	if not (Star_Trek and Star_Trek.Logs) then return end
	if not IsValid(self.Button) then return end
	Star_Trek.Logs:AddEntry(self.Button, ply, message, color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorBlue or nil))
end

function Star_Trek.Grav_Panel:EnsureGenerator()
	if IsValid(self.Generator) then
		if self.Generator:GetModel() ~= GENERATOR_MODEL then
			self.Generator:SetModel(GENERATOR_MODEL)
		end
		self.Generator:SetPos(GENERATOR_POS)
		self.Generator:SetAngles(GENERATOR_ANG)
		self.Generator:SetNoDraw(false)
		self.Generator:DrawShadow(true)
		self.Generator:SetRenderMode(RENDERMODE_NORMAL)
		return self.Generator
	end

	for _, ent in ipairs(ents.FindByClass("gravgen")) do
		self.Generator = ent
		ent:SetPos(GENERATOR_POS)
		ent:SetAngles(GENERATOR_ANG)
		if ent:GetModel() ~= GENERATOR_MODEL then
			ent:SetModel(GENERATOR_MODEL)
		end
		ent:SetNoDraw(false)
		ent:DrawShadow(true)
		ent:SetRenderMode(RENDERMODE_NORMAL)
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
		end
		if StarTrekEntities and StarTrekEntities.Gravity then
			StarTrekEntities.Gravity:SetGenerator(ent)
		end
		if self.Debug then
			print(string.format("[GravPanel] Reusing existing gravity generator #%d", ent:EntIndex()))
		end
		return ent
	end

	local gen = ents.Create("gravgen")
	if not IsValid(gen) then
		print("[GravPanel] Failed to create gravity generator")
		return nil
	end

	gen:SetPos(GENERATOR_POS)
	gen:SetAngles(GENERATOR_ANG)
	if gen:GetModel() ~= GENERATOR_MODEL then
		gen:SetModel(GENERATOR_MODEL)
	end
	gen:Spawn()
	gen:Activate()
	gen:SetNoDraw(false)
	gen:DrawShadow(true)
	gen:SetRenderMode(RENDERMODE_NORMAL)

	local phys = gen:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	self.Generator = gen
	if StarTrekEntities and StarTrekEntities.Gravity then
		StarTrekEntities.Gravity:SetGenerator(gen)
	end

	if self.Debug then
		print(string.format("[GravPanel] Gravity generator spawned at %s", tostring(GENERATOR_POS)))
	end

	return gen
end

local function removeNearbyProps(model, pos, radius)
	local radiusSqr = radius * radius
	for _, class in ipairs(CLEANUP_CLASSES) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if not IsValid(ent) then continue end
			if ent:GetModel() ~= model then continue end
			if ent:GetPos():DistToSqr(pos) > radiusSqr then continue end
			ent:Remove()
		end
	end
end

function Star_Trek.Grav_Panel:EnsureRepairProp()
	removeNearbyProps(REPAIR_PROP_MODEL, REPAIR_PROP_POS, REPAIR_PROP_RADIUS)

	if IsValid(self.RepairProp) then
		self.RepairProp:SetModel(REPAIR_PROP_MODEL)
		self.RepairProp:SetPos(REPAIR_PROP_POS)
		self.RepairProp:SetAngles(REPAIR_PROP_ANG)
		self.RepairProp:SetNoDraw(false)
		self.RepairProp:DrawShadow(true)
		return self.RepairProp
	end

	local prop = ents.Create("prop_dynamic")
	if not IsValid(prop) then
		print("[GravPanel] Failed to create repair wall prop")
		return nil
	end

	prop:SetModel(REPAIR_PROP_MODEL)
	prop:SetPos(REPAIR_PROP_POS)
	prop:SetAngles(REPAIR_PROP_ANG)
	prop:Spawn()
	prop:Activate()
	prop:SetMoveType(MOVETYPE_NONE)
	prop:SetSolid(SOLID_NONE)
	prop:DrawShadow(true)

	self.RepairProp = prop

	if Star_Trek.Grav_Panel.Debug then
		print(string.format("[GravPanel] Repair prop positioned at %s", tostring(REPAIR_PROP_POS)))
	end

	return prop
end

local function spawnPanel()
	if IsValid(Star_Trek.Grav_Panel.Button) then
		Star_Trek.Grav_Panel.Button:Remove()
	end

	local success, panel = Star_Trek.Button:CreateInterfaceButton(PANEL_POS, PANEL_ANG, PANEL_MODEL, "grav_panel", true)
	if not success then
		print("[GravPanel] Failed to spawn control panel:", panel)
		return
	end

	Star_Trek.Grav_Panel.Button = panel
	local phys = panel:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	Star_Trek.Grav_Panel.ConsoleDisabled = false
	Star_Trek.Grav_Panel.ReenablePending = false

	panel:SetNoDraw(true)
	panel:DrawShadow(false)

	if Star_Trek.Grav_Panel.Debug then
		print(string.format("[GravPanel] Control panel ready at %s", tostring(PANEL_POS)))
	end

	Star_Trek.Grav_Panel:EnsureGenerator()
	Star_Trek.Grav_Panel:EnsureRepairProp()
end

function Star_Trek.Grav_Panel:TryOpenInterface(ply)
	if not IsValid(ply) or not ply:IsPlayer() then
		return false, "Invalid user"
	end

	if not (Star_Trek and Star_Trek.LCARS) then
		return false, "LCARS unavailable"
	end

	if not IsValid(self.Button) then
		return false, "Gravity control panel missing"
	end

	if self.ConsoleDisabled then
		return false, "Gravity console offline. Tap the panel to reactivate."
	end

	local success, err = Star_Trek.LCARS:OpenInterface(ply, self.Button, "grav_panel")
	if not success and self.Debug then
		print(string.format("[GravPanel] Failed to open interface: %s", tostring(err)))
	end
	return success, err
end

local function reopenPanelWithDelay(panel)
	if not IsValid(panel) then
		return
	end

	if panel._gravReopenPending then
		return
	end

	panel._gravReopenPending = true
	panel:Fire("CloseLcars")

	timer.Simple(1, function()
		if not IsValid(panel) then
			return
		end

		panel._gravReopenPending = nil

		if Star_Trek.Grav_Panel and Star_Trek.Grav_Panel.ConsoleDisabled then
			return
		end

		panel:Fire("Press")
	end)
end

hook.Add("Star_Trek.Grav.OverrideStateChanged", "Star_Trek.GravPanel.RefreshOnOverride", function(_, newState)
	if not (Star_Trek and Star_Trek.Grav_Panel and Star_Trek.LCARS) then
		return
	end

	local panel = Star_Trek.Grav_Panel.Button
	if not IsValid(panel) then
		return
	end

	if Star_Trek.Grav_Panel.ConsoleDisabled then
		return
	end

	local active = Star_Trek.LCARS.ActiveInterfaces
	if not (istable(active) and active[panel]) then
		return
	end

	reopenPanelWithDelay(panel)
end)

hook.Add("Star_Trek.LCARS.PreOpenInterface", "Star_Trek.GravPanel.ResumeFromDisable", function(ent, interfaceName)
	if interfaceName ~= "grav_panel" then return end
	if ent ~= Star_Trek.Grav_Panel.Button then return end
	if not Star_Trek.Grav_Panel.ConsoleDisabled then return end

	Star_Trek.Grav_Panel.ConsoleDisabled = false

	if Star_Trek.Grav_Panel.ReenablePending then
		Star_Trek.Grav_Panel.ReenablePending = false
		Star_Trek.Grav_Panel:Log("Gravity console manually reactivated.", Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue)
	end

	if Star_Trek.Grav_Panel.Debug then
		print("[GravPanel] Console reactivated via panel use")
	end
end)

hook.Add("InitPostEntity", "Star_Trek.GravPanel.Spawn", function()
	spawnPanel()
end)

hook.Add("PostCleanupMap", "Star_Trek.GravPanel.Respawn", function()
	timer.Simple(0.5, spawnPanel)
end)

hook.Add("OnGravGenDestroyed", "Star_Trek.GravPanel.Destruction", function(ent)
	if Star_Trek.Grav_Panel.Generator ~= ent then return end
	local color = Star_Trek.LCARS and Star_Trek.LCARS.ColorRed or nil
	Star_Trek.Grav_Panel:Log("Gravity generator offline. Field failure imminent.", color)
	Star_Trek.Grav_Panel:BroadcastLog("ALERT: Gravity generator offline. Initiate emergency protocols.", color)
end)

hook.Add("OnGravGenRepaired", "Star_Trek.GravPanel.Repaired", function(ent)
	if Star_Trek.Grav_Panel.Generator ~= ent then return end
	local color = Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil
	Star_Trek.Grav_Panel:Log("Gravity generator integrity restored. Field output stable.", color)
	Star_Trek.Grav_Panel:BroadcastLog("Gravity systems restored. Output nominal.", color)
end)

hook.Add("OnGravGenRemoved", "Star_Trek.GravPanel.Clear", function(ent)
	if Star_Trek.Grav_Panel.Generator == ent then
		Star_Trek.Grav_Panel.Generator = nil
		timer.Simple(1, function()
			if not Star_Trek or not Star_Trek.Grav_Panel then return end
			if IsValid(Star_Trek.Grav_Panel.Generator) then return end
			Star_Trek.Grav_Panel:EnsureGenerator()
		end)
	end
end)
