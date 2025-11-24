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
--  Lifesign Scrambler Tool | Shared --
---------------------------------------

if not istable(TOOL) then Star_Trek:LoadAllModules() return end

TOOL.Category = "ST:RP"
TOOL.Name = "Lifesign Scrambler"
TOOL.ConfigName = ""

local function isValidTarget(ent)
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

if CLIENT then
	TOOL.Information = {
		{ name = "left" },
		{ name = "right" },
	}

	language.Add("tool.lifesign_scrambler.name", "Lifesign Scrambler")
	language.Add("tool.lifesign_scrambler.desc", "Applies or removes lifesign scrambling on crew and NPCs.")
	language.Add("tool.lifesign_scrambler.left", "Toggle scrambling on targeted player or NPC")
	language.Add("tool.lifesign_scrambler.right", "Toggle scrambling on yourself")

	function TOOL:BuildCPanel(panel)
		if not IsValid(panel) then
			return
		end

		panel:AddControl("Header", {
			Text = "#tool.lifesign_scrambler.name",
			Description = "Left-click a player or NPC to toggle a lifesign scrambler. Right-click to scramble/unscramble yourself.",
		})
	end
	return
end

local function toggleScrambler(ent)
	if not (Star_Trek and Star_Trek.Medical) then
		return nil
	end

	local medical = Star_Trek.Medical
	if not (istable(medical) and isfunction(medical.SetLifeSignScrambler) and isfunction(medical.HasLifeSignScrambler)) then
		return nil
	end

	local newState = not medical:HasLifeSignScrambler(ent)
	medical:SetLifeSignScrambler(ent, newState)

	if ent:IsPlayer() then
		ent:ChatPrint(newState and "Your lifesigns are now scrambled." or "Your lifesigns are now visible to sensors.")
	end

	return newState
end

function TOOL:LeftClick(trace)
	if CLIENT then
		return true
	end

	local ent = trace.Entity
	if not isValidTarget(ent) then
		return false
	end

	local state = toggleScrambler(ent)
	if state == nil then
		return false
	end

	local name
	if ent:IsPlayer() then
		name = ent:Nick()
	elseif ent:IsNPC() then
		name = ent:GetClass()
	else
		name = tostring(ent)
	end

	if state then
		notifyOwner(self, string.format("Applied lifesign scrambler to %s.", name))
	else
		notifyOwner(self, string.format("Removed lifesign scrambler from %s.", name))
	end

	return true
end

function TOOL:RightClick(trace)
	if CLIENT then
		return true
	end

	local owner = self:GetOwner()
	if not IsValid(owner) then
		return false
	end

	local state = toggleScrambler(owner)
	if state == nil then
		return false
	end

	notifyOwner(self, state and "Personal lifesign scrambler engaged." or "Personal lifesign scrambler disengaged.")

	return true
end

function TOOL:Reload(trace)
	if CLIENT then
		return true
	end

	local ent = trace.Entity
	if not isValidTarget(ent) then
		return false
	end

	if not (Star_Trek and Star_Trek.Medical and Star_Trek.Medical.SetLifeSignScrambler) then
		return false
	end

	Star_Trek.Medical:SetLifeSignScrambler(ent, false)

	local name
	if ent:IsPlayer() then
		name = ent:Nick()
	elseif ent:IsNPC() then
		name = ent:GetClass()
	else
		name = tostring(ent)
	end

	notifyOwner(self, string.format("Forced lifesign scrambler offline for %s.", name))

	return true
end
