print("StarTrekEntities: Loaded sv_lifesupport_grav_think.lua")
local safe_zones = {
	{ -- Turbo Lift [Halfway] + TP Buffer
		min = Vector(8258.139648, 572.089539, 13468.325195),
		max = Vector(7241.450195, -552.128723, 11847.990234)
	},
	{ -- Holodeck - The Void
		min = Vector( -2035.248779, -11788.853516, 13971.599609 ),
		max = Vector( -8471.815430, -5346.975098, 12336.586914 ),
	},
	{ -- Holodeck - Waste Land
		min = Vector( 15300.295898, 14036.236328, 17559.767578 ),
		max = Vector( 2739.603027, 2675.925537, 11989.919922 ),
	},
	{ -- Holodeck - Holo lab
		min = Vector( -2365.034668, 2035.330322, 13131.249023 ),
		max = Vector( -5893.335449, 5428.146484, 12473.782227 ),
	},

	-- AUX AREAS!
	{
		min = Vector( -5950.541992, 5265.229492, 13124.010742 ),
		max = Vector( -13579.957031, 1857.106934, 12494.546875 ),
	},
	{
		min = Vector( -13567.231445, 6074.521484, 11368.706055 ),
		max = Vector( -2346.298584, 11287.033203, 15019.102539 ),
	},

	--- Testing with the entire ship:
	{
		min = Vector( -2188.804199, -1236.667847, 14246.653320 ),
		max = Vector( 2390.314209, 1144.067993, 11371.262695 ),
	}
}
hook.Add( "ShouldIgnoreLifeSupportDamage", "DisableLifeSupportDamage", function( ply, location_data )
	if not IsValid( ply ) or not ply:IsPlayer() then return end
	local pMovement = ply:GetMoveType()
	if pMovement == MOVETYPE_NOCLIP or pMovement == MOVETYPE_OBSERVER then return true end
	if ply:GetModel() == "models/player/startrek_female_spacesuit.mdl" then return true end
	local pos = ply:GetPos()
	if #location_data == 0 then
		for _, zone in ipairs( safe_zones ) do
			if pos:WithinAABox( zone.min, zone.max ) then
				return true, false -- Ignore damage, but don't overwrite life support.
			end
		end
	end
end )
