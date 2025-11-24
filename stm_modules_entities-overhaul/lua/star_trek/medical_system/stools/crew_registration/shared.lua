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
--  Crew Registration Tool | Shared --
---------------------------------------

if not istable(TOOL) then Star_Trek:LoadAllModules() return end

TOOL.Category = "ST:RP"
TOOL.Name = "Crew Registration"
TOOL.ConfigName = ""

TOOL.ClientConVar = {
	crew_name = "",
	crew_species = "",
}

local function isRegisterable(ent)
	if not IsValid(ent) then
		return false
	end

	if ent:IsPlayer() then
		return true
	end

	if ent:IsNPC() then
		return true
	end

	if isfunction(ent.IsNextBot) and ent:IsNextBot() then
		return true
	end

	return false
end

local function notifyOwner(tool, message)
	local owner = IsValid(tool) and tool:GetOwner()
	if not IsValid(owner) then
		return
	end

	owner:ChatPrint("[LCARS] " .. message)
end

local function getTargetEntity(tool, trace)
	local ent = trace.Entity
	if IsValid(ent) and ent ~= tool:GetOwner() then
		return ent
	end

	local owner = tool:GetOwner()
	if IsValid(owner) and isRegisterable(owner) then
		return owner
	end

	return ent
end

if CLIENT then
	TOOL.Information = {
		{ name = "left" },
		{ name = "right" },
		{ name = "reload" },
	}

	language.Add("tool.crew_registration.name", "Crew Registration")
	language.Add("tool.crew_registration.desc", "Register crew members in the medical database.")
	language.Add("tool.crew_registration.left", "Register or update the targeted contact")
	language.Add("tool.crew_registration.right", "Clear the targeted contact's registration")
	language.Add("tool.crew_registration.reload", "Register yourself with the current details")

	function TOOL:BuildCPanel(panel)
		if not IsValid(panel) then
			return
		end

		panel:AddControl("Header", {
			Text = "#tool.crew_registration.name",
			Description = "Provide a name and species, then use the tool to sync contacts with the medical roster.",
		})

		panel:TextEntry("Crew Name", "crew_registration_crew_name")
		panel:TextEntry("Species", "crew_registration_crew_species")

		panel:Help("Left-click a player or NPC to assign the entered name/species. Right-click clears any stored entry. Reload applies the details to yourself.")
	end

	return
end

local function applyRegistration(target, tool, name, species)
	if not (Star_Trek and Star_Trek.Medical and isfunction(Star_Trek.Medical.SetCrewProfile)) then
		return false, "Medical database unavailable"
	end

	if not isRegisterable(target) then
		return false, "Target must be a player or NPC"
	end

	local ok, err = Star_Trek.Medical:SetCrewProfile(target, name, species)
	return ok, err or ""
end

function TOOL:LeftClick(trace)
	if CLIENT then
		return true
	end

	local target = getTargetEntity(self, trace)
	if not isRegisterable(target) then
		return false
	end

	local name = self:GetClientInfo("crew_name")
	local species = self:GetClientInfo("crew_species")

	local ok, err = applyRegistration(target, self, name, species)
	if not ok then
		notifyOwner(self, err or "Unable to register contact.")
		return false
	end

	local displayName
	if target:IsPlayer() then
		displayName = target:Nick()
	else
		displayName = target.PrintName or target:GetClass()
	end

	notifyOwner(self, string.format("Registered %s in the medical roster.", displayName or "contact"))
	return true
end

function TOOL:RightClick(trace)
	if CLIENT then
		return true
	end

	local target = getTargetEntity(self, trace)
	if not isRegisterable(target) then
		return false
	end

	local ok, err = applyRegistration(target, self, "", "")
	if not ok then
		notifyOwner(self, err or "Unable to clear registration.")
		return false
	end

	notifyOwner(self, "Cleared crew registration for targeted contact.")
	return true
end

function TOOL:Reload(trace)
	if CLIENT then
		return true
	end

	local owner = self:GetOwner()
	if not isRegisterable(owner) then
		return false
	end

	local name = self:GetClientInfo("crew_name")
	local species = self:GetClientInfo("crew_species")

	local ok, err = applyRegistration(owner, self, name, species)
	if not ok then
		notifyOwner(self, err or "Unable to register yourself.")
		return false
	end

	notifyOwner(self, "Updated your crew registration.")
	return true
end
