AddCSLuaFile()

DEFINE_BASECLASS("base_gmodentity")

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "System Disabler Base"
ENT.Category = "Star Trek - Systems"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.Editable = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

ENT.SystemName = "Subsystem"
ENT.DefaultModel = "models/kingpommes/startrek/intrepid/eng_wallpanel.mdl"
ENT.DefaultColor = Color(180, 180, 180)
ENT.DefaultMaxIntegrity = 100
ENT.DisableHooks = ENT.DisableHooks or {
	deckCreate = "",
	deckRemove = "",
	sectionCreate = "",
	sectionRemove = "",
}

local function notifyConfigChanged(ent, name, old, new)
	if ent.OnConfigChanged then
		ent:OnConfigChanged(name, old, new)
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Repairable", {
		KeyName = "Repairable",
		Edit = {
			type = "Boolean",
			title = "Repairable",
			category = "Damage",
			order = 0,
		},
	})

	self:NetworkVar("Bool", 1, "InWorldVisible", {
		KeyName = "InWorldVisible",
		Edit = {
			type = "Boolean",
			title = "Visible In-World",
			category = "Appearance",
			order = 0,
		},
	})

	self:NetworkVar("Bool", 2, "AffectsDeck", {
		KeyName = "AffectsDeck",
		Edit = {
			type = "Boolean",
			title = "Affect Entire Deck",
			category = "Target",
			order = 0,
		},
	})

	self:NetworkVar("Int", 0, "TargetDeck", {
		KeyName = "TargetDeck",
		Edit = {
			type = "Int",
			title = "Deck Index (0 = auto)",
			category = "Target",
			order = 1,
			min = 0,
			max = 20,
		},
	})

	self:NetworkVar("Int", 1, "TargetSection", {
		KeyName = "TargetSection",
		Edit = {
			type = "Int",
			title = "Section Id (0 = auto)",
			category = "Target",
			order = 2,
			min = 0,
			max = 128,
		},
	})

	self:NetworkVar("Int", 2, "MaxIntegrity", {
		KeyName = "MaxIntegrity",
		Edit = {
			type = "Int",
			title = "Max Integrity",
			category = "Damage",
			order = 1,
			min = 10,
			max = 1000,
		},
	})

	self:NetworkVar("Bool", 3, "PlayerRepairing")
	self:NetworkVar("String", 0, "CustomLabel", {
		KeyName = "CustomLabel",
		Edit = {
			type = "String",
			title = "Custom Label",
			category = "Target",
			order = 3,
			waitforenter = true,
		},
	})

	if SERVER then
		self:SetRepairable(true)
		self:SetInWorldVisible(true)
		self:SetAffectsDeck(false)
		self:SetTargetDeck(0)
		self:SetTargetSection(0)
		self:SetMaxIntegrity(self.DefaultMaxIntegrity or 100)
		self:SetPlayerRepairing(false)

		self:NetworkVarNotify("Repairable", notifyConfigChanged)
		self:NetworkVarNotify("InWorldVisible", notifyConfigChanged)
		self:NetworkVarNotify("AffectsDeck", notifyConfigChanged)
		self:NetworkVarNotify("TargetDeck", notifyConfigChanged)
		self:NetworkVarNotify("TargetSection", notifyConfigChanged)
		self:NetworkVarNotify("MaxIntegrity", notifyConfigChanged)
		self:NetworkVarNotify("CustomLabel", notifyConfigChanged)
	end
end

function ENT:GetSystemColor()
	return self.SystemColor or self.DefaultColor or color_white
end

function ENT:GetTargetDescription()
	local custom = self:GetCustomLabel()
	if isstring(custom) and custom ~= "" then
		return custom
	end
	return self.TargetDescription or self:GetNWString("stm_target_description", "Unassigned")
end

function ENT:IsDeckWide()
	if self.Section ~= nil then
		return false
	end
	return self:GetAffectsDeck() or self:GetNWBool("stm_target_deckwide", true)
end
