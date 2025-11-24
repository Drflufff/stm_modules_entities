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
--      Medical System | Index       --
---------------------------------------

Star_Trek:RequireModules("button", "lcars", "logs", "sensors", "sections")

AddCSLuaFile("star_trek/medical_system/entities/stm_medbed_trigger.lua")
if CLIENT then
	include("star_trek/medical_system/entities/stm_medbed_trigger.lua")
	local recentAlerts = {}
	net.Receive("Star_Trek.Medical.DownedAlert", function()
		local name = net.ReadString()
		local location = net.ReadString()

		local key = name
		local now = CurTime()
		if recentAlerts[key] and recentAlerts[key] > now then
			return
		end

		recentAlerts[key] = now + 8
		local message = string.format("%s is down at %s", name, location)
		chat.AddText(Color(255, 0, 0), "*** MEDICAL ALERT *** ", Color(255, 255, 255), message)
	end)

	return
end

Star_Trek.Medical = Star_Trek.Medical or {}
Star_Trek.Medical.Config = Star_Trek.Medical.Config or {}

local config = Star_Trek.Medical.Config
config.CombadgeBodygroupNames = config.CombadgeBodygroupNames or {"combadge", "badge"}
config.CombadgeOnValue = config.CombadgeOnValue or 1
config.DownedAlertCooldown = math.max(config.DownedAlertCooldown or 0, 180)
config.LifeSignScramblerClasses = config.LifeSignScramblerClasses or {}
config.LifeSignScramblerFlags = config.LifeSignScramblerFlags or {"st_lifesign_scrambler_active"}
config.CrewConsole = {
	-- Crew status console anchor; tweak as needed per map layout.
	pos = Vector(149.95, -91.68, 13415.21),
	ang = Angle(0.05, 171.8, 0.21),
	model = "models/hunter/blocks/cube025x2x025.mdl",
}

if game.GetMap() ~= "rp_intrepid_v1" then return end

include("star_trek/medical_system/sv_medical.lua")
