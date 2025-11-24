AddCSLuaFile()

DEFINE_BASECLASS("stm_system_disabler_base")

ENT.Type = "anim"
ENT.Base = "stm_system_disabler_base"
ENT.PrintName = "Life Support Disruption Node"
ENT.Category = "Star Trek - Systems"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

ENT.SystemName = "Life Support"
ENT.DefaultModel = "models/kingpommes/startrek/intrepid/eng_wallpanel.mdl"
ENT.SystemColor = Color(255, 255, 255)
ENT.DefaultMaxIntegrity = 160
ENT.DisableHooks = {
	deckCreate = "OnDisableLifeSupportDeckCreated",
	deckRemove = "OnDisableLifeSupportDeckRemoved",
	sectionCreate = "OnDisableLifeSupportSectionCreated",
	sectionRemove = "OnDisableLifeSupportSectionRemoved",
}
