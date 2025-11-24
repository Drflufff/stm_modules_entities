StarTrekEntities = StarTrekEntities or {}
StarTrekEntities.Gravity = StarTrekEntities.Gravity or {}

local Gravity = StarTrekEntities.Gravity
Gravity.MinScale = Gravity.MinScale or 0.2
Gravity.MaxScale = Gravity.MaxScale or 2
Gravity.DefaultScale = Gravity.DefaultScale or 1
Gravity.EmergencyScale = Gravity.EmergencyScale or 0.4

Gravity.DisabledDecks = Gravity.DisabledDecks or {}
Gravity.DisabledSections = Gravity.DisabledSections or {}
Gravity.DisruptorIndex = Gravity.DisruptorIndex or {}

local function isTableEmpty(t)
	return not (istable(t) and next(t) ~= nil)
end

local function resolveSectionName(deck, section)
	if Star_Trek and Star_Trek.Sections and Star_Trek.Sections.GetSectionName then
		local name = Star_Trek.Sections:GetSectionName(deck, section)
		if isstring(name) and name ~= "" then
			return string.format("Deck %d - %s", deck, name)
		end
	end

	return string.format("Deck %d - Section %s", deck, tostring(section))
end

function Gravity:GetSectionDescriptor(deck, section)
	if section == nil then
		return string.format("Deck %d", deck)
	end

	return resolveSectionName(deck, section)
end

function Gravity:GetZoneLabel(map, fallback)
	if not istable(map) then
		return fallback
	end

	for ent in pairs(map) do
		if IsValid(ent) and ent.GetTargetDescription then
			local desc = ent:GetTargetDescription()
			if isstring(desc) and desc ~= "" then
				return desc
			end
		end
	end

	return fallback
end

function Gravity:HasActiveDisruptions()
	for _, map in pairs(self.DisabledDecks) do
		if not isTableEmpty(map) then
			return true
		end
	end

	for _, deckSections in pairs(self.DisabledSections) do
		for _, map in pairs(deckSections) do
			if not isTableEmpty(map) then
				return true
			end
		end
	end

	return false
end

function Gravity:GetDisruptionSummary()
	local summary = {}

	for deck, map in pairs(self.DisabledDecks) do
		if not isTableEmpty(map) then
			local label = self:GetZoneLabel(map, self:GetSectionDescriptor(deck))
			table.insert(summary, {
				deck = deck,
				deckWide = true,
				label = label,
				message = string.format("%s gravity field offline.", label),
			})
		end
	end

	for deck, sections in pairs(self.DisabledSections) do
		for sectionId, map in pairs(sections) do
			if not isTableEmpty(map) then
				local fallback = self:GetSectionDescriptor(deck, sectionId)
				local label = self:GetZoneLabel(map, fallback)
				table.insert(summary, {
					deck = deck,
					section = sectionId,
					deckWide = false,
					label = label,
					message = string.format("%s gravity field offline.", label),
				})
			end
		end
	end

	table.sort(summary, function(a, b)
		if a.deck == b.deck then
			local ap = a.deckWide and 0 or 1
			local bp = b.deckWide and 0 or 1
			if ap == bp then
				return (a.section or 0) < (b.section or 0)
			end
			return ap < bp
		end
		return a.deck < b.deck
	end)

	return summary
end

function Gravity:ClearDisruptions()
	self.DisabledDecks = {}
	self.DisabledSections = {}
	self.DisruptorIndex = {}
end

local function registerDisruption(ent, deck, section)
	if not IsValid(ent) then return end
	deck = tonumber(deck)
	if not deck then return end

	Gravity.DisruptorIndex[ent] = {deck = deck, section = section}

	if section == nil then
		Gravity.DisabledDecks[deck] = Gravity.DisabledDecks[deck] or {}
		Gravity.DisabledDecks[deck][ent] = true
	else
		section = tonumber(section)
		if not section then return end
		Gravity.DisabledSections[deck] = Gravity.DisabledSections[deck] or {}
		Gravity.DisabledSections[deck][section] = Gravity.DisabledSections[deck][section] or {}
		Gravity.DisabledSections[deck][section][ent] = true
	end
end

local function unregisterDisruption(ent)
	local info = Gravity.DisruptorIndex[ent]
	if not info then return end

	local deck = info.deck
	local section = info.section

	if section == nil then
		local deckMap = Gravity.DisabledDecks[deck]
		if deckMap then
			deckMap[ent] = nil
			if isTableEmpty(deckMap) then
				Gravity.DisabledDecks[deck] = nil
			end
		end
	else
		local deckSections = Gravity.DisabledSections[deck]
		if deckSections then
			local sectionMap = deckSections[section]
			if sectionMap then
				sectionMap[ent] = nil
				if isTableEmpty(sectionMap) then
					deckSections[section] = nil
					if isTableEmpty(deckSections) then
						Gravity.DisabledSections[deck] = nil
					end
				end
			end
		end
	end

	Gravity.DisruptorIndex[ent] = nil
end

hook.Add("OnDisableGravitySectionCreated", "StarTrekEntities.Gravity.TrackSections", function(ent)
	if not ent or ent.Deck == nil or ent.Section == nil then return end
	registerDisruption(ent, ent.Deck, ent.Section)
end)

hook.Add("OnDisableGravitySectionRemoved", "StarTrekEntities.Gravity.TrackSections", function(ent)
	unregisterDisruption(ent)
end)

hook.Add("OnDisableGravityDeckCreated", "StarTrekEntities.Gravity.TrackDecks", function(ent)
	if not ent or ent.Deck == nil then return end
	registerDisruption(ent, ent.Deck, nil)
end)

hook.Add("OnDisableGravityDeckRemoved", "StarTrekEntities.Gravity.TrackDecks", function(ent)
	unregisterDisruption(ent)
end)

hook.Add("PostCleanupMap", "StarTrekEntities.Gravity.ResetDisruptions", function()
	Gravity:ClearDisruptions()
end)

local function updateStatus(source)
	if not StarTrekEntities or not StarTrekEntities.SetStatus then return end
	local online = Gravity:IsOnline()
	StarTrekEntities:SetStatus("gravity", "active", online)
	hook.Run("StarTrekEntities.GravityPowerChanged", source, online)
end

function Gravity:SetGenerator(ent)
	if IsValid(ent) then
		self.Generator = ent
	elseif self.Generator == ent then
		self.Generator = nil
	end
	updateStatus(ent)
end

function Gravity:GetGenerator()
	if IsValid(self.Generator) then
		return self.Generator
	end
	return nil
end

function Gravity:IsOnline()
	local gen = self:GetGenerator()
	if not IsValid(gen) then
		return false
	end

	if gen.IsOperational then
		return gen:IsOperational()
	end

	return gen:Health() > 0
end

function Gravity:GetHealthPercent()
	local gen = self:GetGenerator()
	if not IsValid(gen) or not gen.GetHealthPercent then
		return 0
	end

	return gen:GetHealthPercent()
end

function Gravity:GetScale()
	local gen = self:GetGenerator()
	if not IsValid(gen) or not gen.GetGravityScale then
		return self.DefaultScale
	end

	if gen.GetEffectiveGravityScale then
		return gen:GetEffectiveGravityScale()
	end

	local scale = gen:GetGravityScale()

	if gen.IsOperational and gen:IsOperational() then
		return scale
	end

	if gen:Health() <= 0 then
		return gen.FailGravityScale or 0
	end

	if gen.OverrideState == false or gen.Working == false then
		return 0
	end

	return scale
end

function Gravity:SetScale(scale, source)
	local gen = self:GetGenerator()
	if not IsValid(gen) then
		return false, "Gravity generator offline."
	end

	if not gen.SetGravityScale then
		return false, "Gravity output controls unavailable."
	end

	local ok, result = gen:SetGravityScale(scale)
	if ok then
		updateStatus(source or gen)
	end

	return ok, result
end

function Gravity:AdjustScale(delta, source)
	local gen = self:GetGenerator()
	if not IsValid(gen) then
		return false, "Gravity generator offline."
	end

	if not gen.AdjustGravityScale then
		return false, "Adjustment controls unavailable."
	end

	if gen.OverrideState ~= true then
		return false, "Emergency override required before manual adjustments."
	end

	if not self:IsOnline() then
		return false, "Gravity generators offline. Activate systems first."
	end

	local ok, result = gen:AdjustGravityScale(delta)
	if ok then
		updateStatus(source or gen)
	end

	return ok, result
end

function Gravity:Shutdown(source)
	local gen = self:GetGenerator()
	if not IsValid(gen) then
		return false, "Gravity generator offline."
	end

	if not gen.ShutdownGenerator then
		return false, "Shutdown controls unavailable."
	end

	local ok, msg = gen:ShutdownGenerator(source)
	if ok then
		updateStatus(source or gen)
	end

	return ok, msg
end

function Gravity:Restart(source)
	local gen = self:GetGenerator()
	if not IsValid(gen) then
		return false, "Gravity generator offline."
	end

	if not gen.RestartGenerator then
		return false, "Restart controls unavailable."
	end

	local ok, msg = gen:RestartGenerator(source)
	if ok then
		updateStatus(source or gen)
	end

	return ok, msg
end

function Gravity:Reset(source)
	if not self:IsOnline() then
		return false, "Gravity generators offline. Activate systems first."
	end
	return self:SetScale(self.DefaultScale, source)
end

function Gravity:Emergency(source)
	local gen = self:GetGenerator()
	if not IsValid(gen) then
		return false, "Gravity generator offline."
	end

	if not gen.EmergencyGenerator then
		return false, "Emergency override unavailable."
	end

	local ok, msg = gen:EmergencyGenerator(self.EmergencyScale, source)
	if ok then
		updateStatus(source or gen)
	end

	return ok, msg
end

hook.Add("OnGravGenInitialized", "StarTrekEntities.Gravity.Track", function(ent)
	if not IsValid(ent) then return end
	Gravity:SetGenerator(ent)
end)

hook.Add("OnGravGenRemoved", "StarTrekEntities.Gravity.Track", function(ent)
	if Gravity:GetGenerator() == ent then
		Gravity:SetGenerator(nil)
	end
end)

hook.Add("OnGravGenDestroyed", "StarTrekEntities.Gravity.Status", function(ent)
	if Gravity:GetGenerator() == ent then
		updateStatus(ent)
	end
end)

hook.Add("OnGravGenRepaired", "StarTrekEntities.Gravity.Status", function(ent)
	if Gravity:GetGenerator() == ent then
		updateStatus(ent)
	end
end)
