-- Minimal init file for StarTrekEntities overhaul
StarTrekEntities = StarTrekEntities or {}

if SERVER then
	-- Load server-side logic for comms, sonic driver integration, etc.
	include("startrek_entities/sv_save_entities.lua")
	include("startrek_entities/sv_communication_scramble.lua")
	include("startrek_entities/sv_gravity.lua")
	include("startrek_entities/sv_life_support.lua")
	include("startrek_entities/sv_fix_think.lua")
	if file.Exists("addons/stm_modules_entities-overhaul/lua/startrek_entities/sv_lifesupport_grav_think.lua", "GAME") then
		include("startrek_entities/sv_lifesupport_grav_think.lua")
	end
	print("[StarTrekEntities] startrek_entities/init.lua loaded server components.")
	
	-- Ensure warp panel config is loaded
	if file.Exists("addons/stm_modules_entities-overhaul/lua/star_trek/warp_panel/sv_config.lua", "GAME") then
		include("star_trek/warp_panel/sv_config.lua")
		print("[StarTrekEntities] Warp panel config loaded.")
	end
end

-- You can add shared setup logic here if needed
