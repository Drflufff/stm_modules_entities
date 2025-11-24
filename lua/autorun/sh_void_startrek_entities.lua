StarTrekEntities = StarTrekEntities or {}

local include_types = {
	["sv_"] = SERVER and include or function () end,
	["cl_"] = CLIENT and include or AddCSLuaFile,
	["sh_"] = function (file)
		if SERVER then
			AddCSLuaFile(file)
		end
		return include(file)
	end,
}

function StarTrekEntities:Include(file, inc_type)
	inc_type = inc_type or "sh_"
	local func = include_types[inc_type]
	if not func then
		error("Invalid include type '" .. tostring(inc_type) .. "' for file '" .. tostring(file) .. "'")
		return
	end
	return func(file)
end

function StarTrekEntities:Initialize()
	StarTrekEntities:Include("startrek_entities/init.lua", "sh_")
end

if GAMEMODE then
	StarTrekEntities:Initialize()
else
	hook.Add("Initialize", "StarTrekEntities.Initialize", function()
		StarTrekEntities:Initialize()
	end)
end

-- Register our Star Trek module so the main loader picks it up
Star_Trek = Star_Trek or {}
Star_Trek.Modules = Star_Trek.Modules or {}
Star_Trek.Modules["comms_panel"] = true
Star_Trek.Modules["life_support_panel"] = true
Star_Trek.Modules["Life_support_panel"] = true
Star_Trek.Modules["grav_panel"] = true
Star_Trek.Modules["Grav_panel"] = true
Star_Trek.Modules["medical_system"] = true

print("[StarTrekEntities] Autorun loaded, registered Star_Trek modules 'comms_panel', 'life_support_panel', 'Grav_panel', and 'medical_system'.")
