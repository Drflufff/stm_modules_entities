AddCSLuaFile()

DEFINE_BASECLASS("stm_system_disabler_base")

ENT.Type = "anim"
ENT.Base = "stm_system_disabler_base"
ENT.PrintName = "Gravity Field Disruption Node"
ENT.Category = "Star Trek - Systems"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

ENT.SystemName = "Gravity"
ENT.DefaultModel = "models/kingpommes/startrek/intrepid/eng_wallpanel.mdl"
ENT.SystemColor = Color(255, 255, 255)
ENT.DefaultMaxIntegrity = 140
ENT.DisableHooks = {
	deckCreate = "OnDisableGravityDeckCreated",
	deckRemove = "OnDisableGravityDeckRemoved",
	sectionCreate = "OnDisableGravitySectionCreated",
	sectionRemove = "OnDisableGravitySectionRemoved",
}
