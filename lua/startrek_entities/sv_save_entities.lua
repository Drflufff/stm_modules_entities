-- Placeholder for entity save/load system to satisfy include order.
-- Currently unused in the overhaul, but kept to avoid include errors.

if SERVER then
	print("[StarTrekEntities] sv_save_entities.lua loaded (placeholder)")

	function StarTrekEntities_SaveEntities()
		-- no-op
	end

	function StarTrekEntities_LoadEntities()
		-- no-op
	end
end
