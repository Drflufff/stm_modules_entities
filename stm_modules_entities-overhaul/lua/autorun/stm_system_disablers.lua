AddCSLuaFile()

local CATEGORY_NAME = "Star Trek - Systems"

local DISABLERS = {
	{class = "stm_disable_lifesupport", name = "Life Support Disruption Node"},
	{class = "stm_disable_gravity", name = "Gravity Field Disruption Node"},
}

local function registerDisabler(className, printName)
	list.Set("SpawnableEntities", className, {
		PrintName = printName,
		ClassName = className,
		Category = CATEGORY_NAME,
	})
end

for _, data in ipairs(DISABLERS) do
	registerDisabler(data.class, data.name)
end

if CLIENT then
	local categoryRegistered = false

	local function ensureCategory()
		if categoryRegistered then
			return
		end
		categoryRegistered = true

		local entries = {}
		for _, data in ipairs(DISABLERS) do
			entries[#entries + 1] = {
				PrintName = data.name,
				ClassName = data.class,
				Category = CATEGORY_NAME,
			}
		end

		if spawnmenu.AddEntityCategory then
			spawnmenu.AddEntityCategory(CATEGORY_NAME, entries)
		end
	end

	hook.Add("PopulateEntities", "StarTrek.SystemDisablers.Populate", ensureCategory)
end
