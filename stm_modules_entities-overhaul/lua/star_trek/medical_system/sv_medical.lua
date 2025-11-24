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
--      Medical System | Server      --
---------------------------------------

local Medical = Star_Trek.Medical
if not istable(Medical) then return end

include("star_trek/medical_system/entities/stm_medbed_trigger.lua")

util.AddNetworkString("Star_Trek.Medical.DownedAlert")

local config = Medical.Config or {}

Medical.Beds = Medical.Beds or {}
Medical.BedEntityLookup = Medical.BedEntityLookup or {}
Medical.ActiveBedInterfaces = Medical.ActiveBedInterfaces or {}
Medical.ActiveCrewInterfaces = Medical.ActiveCrewInterfaces or {}
Medical.CombadgeIndexCache = Medical.CombadgeIndexCache or {}
Medical.LastDamageReports = Medical.LastDamageReports or {}
Medical.LastDeathReports = Medical.LastDeathReports or {}
Medical.ActiveAlerts = Medical.ActiveAlerts or {}
Medical.ActiveAlertMessages = Medical.ActiveAlertMessages or {}
Medical.MarkedIntruders = Medical.MarkedIntruders or {}
Medical.SecurityDetails = Medical.SecurityDetails or {}
Medical.ConsoleSettings = Medical.ConsoleSettings or {}
Medical.CrewProfiles = Medical.CrewProfiles or {}
Medical.ScramblerStates = Medical.ScramblerStates or {}

local BRIDGE_DECK = 1
local BRIDGE_SECTION = 1

local function isBridgeSection(deck, section)
	return deck == BRIDGE_DECK and section == BRIDGE_SECTION
end

local band = bit.band

local damageTypeLabels = {
	[DMG_BULLET] = "ballistic trauma",
	[DMG_SLASH] = "lacerations",
	[DMG_BURN] = "severe burns",
	[DMG_BLAST] = "explosive force trauma",
	[DMG_SHOCK] = "electrical shock",
	[DMG_RADIATION] = "radiation exposure",
	[DMG_CRUSH] = "crushing injuries",
	[DMG_FALL] = "fall impact",
	[DMG_CLUB] = "blunt-force trauma",
	[DMG_ENERGYBEAM] = "energy beam exposure",
	[DMG_POISON] = "toxic exposure",
	[DMG_DROWN] = "suffocating",
	[DMG_SONIC] = "sonic shock"
}

local function getDamageTypeText(bits)
	if not isnumber(bits) then
		return ""
	end

	local labels = {}
	for dmgFlag, label in pairs(damageTypeLabels) do
		if band(bits, dmgFlag) ~= 0 then
			table.insert(labels, label)
		end
	end

	if #labels == 0 then
		return ""
	end

	if #labels == 1 then
		return labels[1]
	end
end

local function summarizeEntity(ent)
	if not IsValid(ent) then
		return nil
	end

	if ent:IsPlayer() then
		return ent:Nick()
	end

	local name = ent.PrintName or ent:GetName()
	if isstring(name) and name ~= "" then
		return name
	end

	local class = ent:GetClass()
	if isstring(class) and class ~= "" then
		return class
	end

	return nil
end

local function summarizeAttacker(attacker, inflictor)
	local attackerName = summarizeEntity(attacker)
	if isstring(attackerName) and attackerName ~= "" then
		return attackerName
	end

	local inflictorName = summarizeEntity(inflictor)
	if isstring(inflictorName) and inflictorName ~= "" then
		return inflictorName
	end

	return "unknown source"
end

local speciesModelGroups = {
	Andorian = {
		"aenar_01.mdl",
		"andorian_01.mdl",
	},
	Bajoran = {
		"bajoran_01.mdl",
		"bajoran_female_01.mdl",
	},
	Bolian = {
		"bolian_01.mdl",
		"bolian_02.mdl",
		"bolian_03.mdl",
		"bolian_04.mdl",
	},
	Caitian = {
		"caitian.mdl",
	},
	Denobulan = {
		"denobulan.mdl",
	},
	Human = {
		"female_01.mdl",
		"female_02.mdl",
		"female_03.mdl",
		"female_04.mdl",
		"female_06.mdl",
		"female_07.mdl",
		"female_fang.mdl",
		"female_hawke.mdl",
		"female_rochelle.mdl",
		"female_wraith.mdl",
		"female_zoey.mdl",
		"male_01.mdl",
		"male_02.mdl",
		"male_03.mdl",
		"male_04.mdl",
		"male_05.mdl",
		"male_06.mdl",
		"male_07.mdl",
		"male_08.mdl",
		"male_09.mdl",
		"male_louis.mdl",
		"male_mp1.mdl",
		"male_mp2.mdl",
		"male_mp3.mdl",
		"male_plr.mdl",
		"male_plr2.mdl",
	},
	Klingon = {
		"klingon_01.mdl",
	},
	Orion = {
		"orion_01.mdl",
		"orion_female_01.mdl",
	},
	Trill = {
		"trill_01.mdl",
		"trill_02.mdl",
		"trill_03.mdl",
	},
	Vulcan = {
		"vulcan_01.mdl",
		"vulcan_02.mdl",
	},
}

local SPECIES_MODEL_LOOKUP = {}
for species, models in pairs(speciesModelGroups) do
	for _, modelName in ipairs(models) do
		local lowerName = string.lower(modelName)
		SPECIES_MODEL_LOOKUP[lowerName] = species
	end
end

local SPECIES_CLASS_LOOKUP = {
	["npc_crow"] = "Crow",
	["npc_pigeon"] = "Pigeon",
	["npc_seagull"] = "Seagull",
	["npc_dog"] = "Dog",
    ["npc_monk"] = "Human",
}

local function getSpeciesFromModel(model)
	if not isstring(model) then
		return nil
	end

	model = string.lower(model)
	if SPECIES_MODEL_LOOKUP[model] then
		return SPECIES_MODEL_LOOKUP[model]
	end

	local fileName = model:match("([^/\\]+)$")
	if fileName and SPECIES_MODEL_LOOKUP[fileName] then
		return SPECIES_MODEL_LOOKUP[fileName]
	end

	return nil
end

local function determineSpecies(ent, isPlayer)
	if not IsValid(ent) then
		return "Alien"
	end

	local model = ent:GetModel()
	local species = getSpeciesFromModel(model)
	local class = string.lower(ent:GetClass() or "")
	if not species then
		species = SPECIES_CLASS_LOOKUP[class]
	end

	return species or "Alien"
end

function Medical:IsCommunicationsOnline()
	if not StarTrekEntities then
		return true
	end

	local commsHealth
	if StarTrekEntities.Comms and isfunction(StarTrekEntities.Comms.GetHealthPercent) then
		commsHealth = StarTrekEntities.Comms:GetHealthPercent()
		if commsHealth <= 0 then
			return false
		end
	else
		local repairEnt = Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.RepairEnt
		if IsValid(repairEnt) then
			local maxhp = (repairEnt.GetCommsMaxHealth and repairEnt:GetCommsMaxHealth()) or (repairEnt.GetMaxHealth and repairEnt:GetMaxHealth()) or 0
			local hp = (repairEnt.GetCommsHealth and repairEnt:GetCommsHealth()) or (repairEnt.Health and repairEnt:Health()) or 0
			if maxhp > 0 and hp <= 0 then
				return false
			end
		end
	end

	local status = StarTrekEntities.Status and StarTrekEntities.Status.comms
	if istable(status) then
		if status.active == false then
			return false
		end
		if status.active == true then
			return commsHealth == nil or commsHealth > 0
		end
	end

	if commsHealth ~= nil then
		return commsHealth > 0
	end

	return false
end

function Medical:IsBridgeOccupied()
	if not (Star_Trek and Star_Trek.Sections and Star_Trek.Sections.DetermineSection) then
		return false
	end

	for _, ply in ipairs(player.GetAll()) do
		if not (IsValid(ply) and ply:IsPlayer()) then
			continue
		end

		local success, deck, section = Star_Trek.Sections:DetermineSection(ply:GetPos())
		if success and isBridgeSection(deck, section) then
			return true
		end
	end

	return false
end

function Medical:GetBridgeHoldState()
	if Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.HoldOpen ~= nil then
		return Star_Trek.Comms_Panel.HoldOpen == true
	end

	return self:IsBridgeOccupied()
end

function Medical:SetCrewConsoleHold(enabled)
	local ent = self.CrewConsoleEnt
	if not IsValid(ent) then
		self.CrewConsoleHold = false
		return
	end

	if self.CrewConsoleHold == enabled then
		return
	end

	self.CrewConsoleHold = enabled
	ent.LCARSKeyData = ent.LCARSKeyData or {}

	if enabled then
		ent.LCARSKeyData["lcars_never_close"] = "1"
		ent:Fire("AddOutput", "lcars_never_close 1", 0)
	else
		ent.LCARSKeyData["lcars_never_close"] = nil
		ent:Fire("AddOutput", "lcars_never_close 0", 0)
	end
end

function Medical:SetConsoleIncludeUnbadged(ent, enabled)
	if not IsValid(ent) then
		return
	end

	self.ConsoleSettings[ent] = self.ConsoleSettings[ent] or {}
	self.ConsoleSettings[ent].IncludeUnbadged = enabled and true or false
end

function Medical:GetConsoleIncludeUnbadged(ent)
	local settings = self.ConsoleSettings and self.ConsoleSettings[ent]
	if not settings then
		return false
	end

	return settings.IncludeUnbadged == true
end

function Medical:SetConsoleTrackScrambled(ent, enabled)
	if not IsValid(ent) then
		return
	end

	self.ConsoleSettings[ent] = self.ConsoleSettings[ent] or {}
	self.ConsoleSettings[ent].TrackScrambled = false
end

function Medical:GetConsoleTrackScrambled(ent)
	return false
end

function Medical:GetCrewRoster(includeUnbadged, includeScrambled)
	if not self:IsCommunicationsOnline() then
		return {}
	end

	local allowUnknown = includeUnbadged == true
	local roster = {}
	local seenIds = {}

	for _, ply in ipairs(player.GetAll()) do
		local entry = self:BuildCrewEntry(ply)
		if entry then
			local include = false
			if not entry.HasScrambler then
				include = entry.CombadgeActive or entry.MarkedIntruder or entry.MarkedSecurityDetail or entry.RegisteredCrew
				if not include and allowUnknown and entry.IsUnknown then
					include = true
				end
			end

			if include then
				table.insert(roster, entry)
				if entry.Id then
					seenIds[entry.Id] = true
				end
			elseif entry.Id then
				self.ActiveAlerts[entry.Id] = nil
				self.ActiveAlertMessages[entry.Id] = nil
			end
		end
	end

	if allowUnknown then
		for _, ent in ipairs(ents.GetAll()) do
			if not IsValid(ent) or ent:IsPlayer() then
				continue
			end
			if not (ent:IsNPC() or (isfunction(ent.IsNextBot) and ent:IsNextBot())) then
				continue
			end

			local entry = self:BuildCrewEntry(ent)
			if entry and entry.Id and not seenIds[entry.Id] then
				if entry.HasScrambler then
					continue
				end

				table.insert(roster, entry)
				seenIds[entry.Id] = true
			end
		end
	end

	table.sort(roster, function(a, b)
		return string.lower(a.Name or "") < string.lower(b.Name or "")
	end)

	return roster
end

function Medical:SetLifeSignScrambler(ent, state)
	if not IsValid(ent) then
		return false
	end

	local flags = config.LifeSignScramblerFlags or {}
	local value = state and true or false
	for _, flag in ipairs(flags) do
		if isstring(flag) and flag ~= "" then
			ent:SetNWBool(flag, value)
		end
	end

	local scramblerId = self:GetEntityId(ent)
	if scramblerId then
		if value then
			self.ScramblerStates[scramblerId] = true
		else
			self.ScramblerStates[scramblerId] = nil
		end
		self.ActiveAlerts[scramblerId] = nil
		self.ActiveAlertMessages[scramblerId] = nil
	end

	self:UpdateCrewConsoles()
	return true
end

function Medical:HasLifeSignScrambler(ent)
	if not IsValid(ent) then
		return false
	end

	local flags = config.LifeSignScramblerFlags or {}
	for _, flag in ipairs(flags) do
		if isstring(flag) and flag ~= "" and ent:GetNWBool(flag) then
			return true
		end
	end

	if isfunction(ent.HasLifeSignScrambler) then
		local ok, result = pcall(ent.HasLifeSignScrambler, ent)
		if ok and result then
			return true
		end
	end

	local scramblerId = self:GetEntityId(ent)
	if scramblerId and self.ScramblerStates[scramblerId] then
		return true
	end

	return false
end

function Medical:IsIntruder(id)
	return id ~= nil and self.MarkedIntruders[id] == true
end

function Medical:SetIntruder(id, state)
	if not id then
		return
	end

	if state then
		self.MarkedIntruders[id] = true
	else
		self.MarkedIntruders[id] = nil
	end

	timer.Simple(0, function()
		if Medical then
			Medical:UpdateCrewConsoles()
		end
	end)

end


function Medical:IsSecurityDetail(id)
	return id ~= nil and self.SecurityDetails[id] == true
end

function Medical:SetSecurityDetail(id, state)
	if not id then
		return
	end

	if state then
		self.SecurityDetails[id] = true
	else
		self.SecurityDetails[id] = nil
	end

	timer.Simple(0, function()
		if Medical then
			Medical:UpdateCrewConsoles()
		end
	end)
end

function Medical:DescribeDamage(report)
	if not istable(report) then
		return nil
	end

	local typeText = getDamageTypeText(report.DamageType)
	local attackerText = report.Attacker or ""

	if typeText ~= "" and attackerText ~= "" then
		return string.format("%s from %s", typeText, attackerText)
	end

	if typeText ~= "" then
		return typeText
	end

	if attackerText ~= "" then
		return string.format("Fatal injuries caused by %s", attackerText)
	end

	return nil
end

function Medical:GetLocationString(entry)
	if not istable(entry) then
		return "Unknown location"
	end

	local loc = entry.Location or {}
	if isstring(loc.SectionName) and loc.SectionName ~= "" then
		return loc.SectionName
	end

	if isnumber(loc.Deck) and isnumber(loc.Section) then
		return string.format("Deck %s Section %s", loc.Deck, loc.Section)
	end

	return "Unknown location"
end

function Medical:BroadcastDownedAlert(entry)
	if not istable(entry) or not entry.Id then
		return
	end

	local now = CurTime()
	local cooldownLength = config.DownedAlertCooldown or 180
	if cooldownLength < 180 then
		cooldownLength = 180
	end

	local cooldownUntil = self.ActiveAlerts[entry.Id] or 0
	if now < cooldownUntil then
		return
	end

	local location = self:GetLocationString(entry)
	local messageKey = tostring(entry.Id)
	local lastMessage = self.ActiveAlertMessages[entry.Id]
	if lastMessage and lastMessage.Message == messageKey and now < (lastMessage.Expire or 0) then
		return
	end

	net.Start("Star_Trek.Medical.DownedAlert")
		net.WriteString(entry.Name or "Unknown crew member")
		net.WriteString(location)
	net.Broadcast()

	local expireTime = now + cooldownLength
	self.ActiveAlerts[entry.Id] = expireTime
	self.ActiveAlertMessages[entry.Id] = {
		Message = messageKey,
		Expire = expireTime,
		Location = location,
	}
end

function Medical:TriggerDownedAlerts(entries)
	if not self:IsCommunicationsOnline() then
		return
	end

	if not istable(entries) then
		return
	end

	for _, entry in ipairs(entries) do
		if not istable(entry) or not entry.Id then
			continue
		end

		if entry.CombadgeActive ~= true then
			self.ActiveAlerts[entry.Id] = nil
			self.ActiveAlertMessages[entry.Id] = nil
			continue
		end

		local scan = entry.ScanData
		local alive = istable(scan) and scan.Alive ~= false
		local health = istable(scan) and scan.Health or 0

		if not alive or health <= 0 then
			self:BroadcastDownedAlert(entry)
		else
			self.ActiveAlerts[entry.Id] = nil
			self.ActiveAlertMessages[entry.Id] = nil
		end
	end
end

function Medical:SanitizeName(name)
	if not isstring(name) or name == "" then
		return "Unknown"
	end
	name = string.Trim(name)
	if name == "" then
		return "Unknown"
	end
	name = string.gsub(name, "[%c]+", " ")
	name = string.gsub(name, "%s+", " ")
	return string.sub(name, 1, 48)
end

function Medical:NormalizeCrewNameInput(name)
	if not isstring(name) then
		return nil
	end

	local trimmed = string.Trim(name)
	if trimmed == "" then
		return nil
	end

	trimmed = string.gsub(trimmed, "[%c]+", " ")
	trimmed = string.gsub(trimmed, "%s+", " ")
	return string.sub(trimmed, 1, 48)
end

function Medical:NormalizeSpeciesInput(species)
	if not isstring(species) then
		return nil
	end

	local trimmed = string.Trim(species)
	if trimmed == "" then
		return nil
	end

	trimmed = string.gsub(trimmed, "[%c]+", " ")
	trimmed = string.gsub(trimmed, "%s+", " ")
	return string.sub(trimmed, 1, 32)
end

function Medical:SetCrewProfile(target, name, species)
	if not IsValid(target) then
		return false, "Invalid target"
	end

	local isPlayer = target:IsPlayer()
	local isNpc = target:IsNPC() or (isfunction(target.IsNextBot) and target:IsNextBot())
	if not (isPlayer or isNpc) then
		return false, "Unsupported entity"
	end

	local id = self:GetEntityId(target)
	if not id then
		return false, "Missing identifier"
	end

	local sanitizedName = self:NormalizeCrewNameInput(name)
	local sanitizedSpecies = self:NormalizeSpeciesInput(species)

	if not sanitizedName and not sanitizedSpecies then
		self.CrewProfiles[id] = nil
	else
		self.CrewProfiles[id] = {
			Name = sanitizedName,
			Species = sanitizedSpecies,
			RegisteredAt = CurTime(),
			IsPlayer = isPlayer,
		}
	end

	self:UpdateCrewConsoles()

	return true
end

function Medical:GetCrewProfile(id)
	if not id then
		return nil
	end

	return self.CrewProfiles and self.CrewProfiles[id] or nil
end

function Medical:GetSectionData(ply)
	if not IsValid(ply) then
		return nil
	end

	if not (Star_Trek and Star_Trek.Sections and Star_Trek.Sections.DetermineSection) then
		return nil
	end

	local success, deck, section = Star_Trek.Sections:DetermineSection(ply:GetPos())
	if not success then
		return nil
	end

	local name = Star_Trek.Sections:GetSectionName(deck, section)
	return {
		Deck = deck,
		Section = section,
		SectionName = name,
	}
end

function Medical:GetPlayerId(ply)
	if not IsValid(ply) then return nil end
	local steamId64 = ply:SteamID64()
	if isstring(steamId64) and steamId64 ~= "" then
		return steamId64
	end
	return tostring(ply:UserID())
end

function Medical:GetEntityId(ent)
	if not IsValid(ent) then
		return nil
	end

	if ent:IsPlayer() then
		return self:GetPlayerId(ent)
	end

	return string.format("npc:%s:%d", ent:GetClass() or "", ent:EntIndex())
end

hook.Add("EntityTakeDamage", "Star_Trek.Medical.TrackDamage", function(ent, dmginfo)
	if not IsValid(ent) or not ent:IsPlayer() then
		return
	end

	local id = Medical:GetPlayerId(ent)
	if not id then
		return
	end

	Medical.LastDamageReports[id] = {
		Time = CurTime(),
		DamageType = dmginfo:GetDamageType(),
		Damage = dmginfo:GetDamage(),
		Attacker = summarizeAttacker(dmginfo:GetAttacker(), dmginfo:GetInflictor()),
	}
end)

hook.Add("PlayerDeath", "Star_Trek.Medical.TrackDeath", function(ply, inflictor, attacker)
	local id = Medical:GetPlayerId(ply)
	if not id then
		return
	end

	local damageReport = Medical.LastDamageReports[id]
	local cause = Medical:DescribeDamage(damageReport)
	if not isstring(cause) or cause == "" then
		local attackerText = summarizeAttacker(attacker, inflictor)
		cause = string.format("Fatal injuries caused by %s", attackerText)
	end

	local location = Medical:GetSectionData(ply)
	Medical.LastDeathReports[id] = {
		Time = CurTime(),
		Cause = cause,
		Location = location,
	}

	Medical.ActiveAlerts[id] = nil
end)

hook.Add("PlayerSpawn", "Star_Trek.Medical.ClearDeathReport", function(ply)
	local id = Medical:GetPlayerId(ply)
	if not id then
		return
	end

	Medical.LastDeathReports[id] = nil
	Medical.LastDamageReports[id] = nil
	Medical.ActiveAlerts[id] = nil
	Medical.ActiveAlertMessages[id] = nil
end)

hook.Add("PlayerDisconnected", "Star_Trek.Medical.ClearCrewProfile", function(ply)
	local id = Medical:GetPlayerId(ply)
	if not id then
		return
	end

	Medical.CrewProfiles[id] = nil
end)

function Medical:GetCombadgeBodygroupIndex(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return nil end

	local override = config.CombadgeBodygroupIndex
	if isnumber(override) then
		return override
	end

	local model = string.lower(ply:GetModel() or "")
	local cached = self.CombadgeIndexCache[model]
	if cached ~= nil then
		if cached == false then
			return nil
		end
		return cached
	end

	local targetNames = config.CombadgeBodygroupNames or {}
	local lookup = {}
	for _, name in ipairs(targetNames) do
		lookup[string.lower(name)] = true
	end

	local numGroups = ply:GetNumBodyGroups()
	for i = 0, numGroups - 1 do
		local groupName = string.lower(ply:GetBodygroupName(i) or "")
		if lookup[groupName] then
			self.CombadgeIndexCache[model] = i
			return i
		end
	end

	self.CombadgeIndexCache[model] = false
	return nil
end

function Medical:HasActiveCombadge(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return false end

	local index = self:GetCombadgeBodygroupIndex(ply)
	if not isnumber(index) then
		return false
	end

	local value = ply:GetBodygroup(index) or 0
	return value >= (config.CombadgeOnValue or 1)
end

function Medical:GetVitalColor(percent)
	if not isnumber(percent) then
		return Star_Trek.LCARS.ColorOrange
	end

	if percent < 25 then
		return Star_Trek.LCARS.ColorRed
	end

	if percent < 50 then
		return Star_Trek.LCARS.ColorOrange
	end

	return Star_Trek.LCARS.ColorLightBlue
end

function Medical:GetPercentText(value)
	if not isnumber(value) then
		return "Unknown"
	end

	return string.format("%d%%", math.Clamp(math.floor(value + 0.5), 0, 100))
end

function Medical:BuildCrewEntry(ent)
	if not IsValid(ent) then
		return nil
	end

	local isPlayer = ent:IsPlayer()
	local isNpc = ent:IsNPC() or (isfunction(ent.IsNextBot) and ent:IsNextBot())
	if not (isPlayer or isNpc) then
		return nil
	end

	local success, scanData = Star_Trek.Sensors:ScanEntity(ent)
	if not success then
		return nil
	end

	if isPlayer then
		scanData.Alive = ent:Alive()
	else
		local alive = true
		if isfunction(ent.Health) then
			alive = ent:Health() > 0
		end
		scanData.Alive = alive
	end

	local rawName
	if isstring(scanData.Name) and scanData.Name ~= "" then
		rawName = scanData.Name
	elseif isPlayer then
		rawName = ent:Nick()
	else
		rawName = ent.PrintName or ent:GetName() or ent:GetClass()
	end

	local location = self:GetSectionData(ent) or {}

	local hasScrambler = false
	if isfunction(self.HasLifeSignScrambler) then
		hasScrambler = self:HasLifeSignScrambler(ent)
	end
	local entry = {
		Id = self:GetEntityId(ent),
		Entity = ent,
		Player = isPlayer and ent or nil,
		Name = self:SanitizeName(rawName),
		ScanData = scanData,
		CombadgeActive = isPlayer and self:HasActiveCombadge(ent) or false,
		HasScrambler = hasScrambler,
		Location = location,
		LastUpdated = CurTime(),
		IsPlayer = isPlayer,
		EntityClass = ent:GetClass(),
	}
	entry.Species = determineSpecies(ent, isPlayer)

	local crewId = entry.Id
	if crewId then
		local profile = self:GetCrewProfile(crewId)
		if istable(profile) then
			entry.RegisteredCrew = true
			if isstring(profile.Name) and profile.Name ~= "" then
				entry.Name = self:SanitizeName(profile.Name)
			end
			if isstring(profile.Species) and profile.Species ~= "" then
				entry.Species = profile.Species
			end
			entry.ProfileRegisteredAt = profile.RegisteredAt
		end
	end

	if not isnumber(scanData.Health) then
		local maxHealth
		if isPlayer then
			maxHealth = math.max(ent:GetMaxHealth() or 0, 1)
		else
			local rawMax = isfunction(ent.GetMaxHealth) and ent:GetMaxHealth() or (isfunction(ent.Health) and ent:Health() or 0)
			maxHealth = math.max(rawMax or 0, 1)
		end

		local currentHealth = isfunction(ent.Health) and ent:Health() or 0
		scanData.Health = math.Clamp(math.floor((currentHealth / maxHealth) * 100 + 0.5), 0, 100)
	end

	if isPlayer and not isnumber(scanData.Armor) then
		local maxArmor = ent:GetMaxArmor()
		if maxArmor > 0 then
			scanData.Armor = math.Clamp(math.floor((ent:Armor() / maxArmor) * 100 + 0.5), 0, 100)
		elseif ent:Armor() > 0 then
			scanData.Armor = math.Clamp(math.floor(ent:Armor()), 0, 100)
		end
	end

	local id = entry.Id
	if id and isPlayer then
		entry.LastDamage = self.LastDamageReports[id]
		entry.MarkedIntruder = self:IsIntruder(id)
		entry.MarkedSecurityDetail = self:IsSecurityDetail(id)
		if not ent:Alive() then
			local report = self.LastDeathReports[id]
			if istable(report) then
				entry.InjuryReport = table.Copy(report)
				entry.InjuryReport.Location = entry.InjuryReport.Location or location
			else
				local cause = self:DescribeDamage(entry.LastDamage)
				if isstring(cause) and cause ~= "" then
					entry.InjuryReport = {
						Time = CurTime(),
						Cause = cause,
						Location = location,
					}
				end
			end
		end
	else
		entry.LastDamage = nil
		entry.MarkedIntruder = id and self:IsIntruder(id) or false
		entry.MarkedSecurityDetail = id and self:IsSecurityDetail(id) or false
	end

	if entry.HasScrambler then
		entry.CombadgeActive = false
	end

	local combadgeActive = entry.CombadgeActive == true
	entry.LimitedTelemetryAvailable = (not combadgeActive) and not entry.HasScrambler
	entry.IsUnknown = (not combadgeActive) and not entry.RegisteredCrew
	entry.CanMarkIntruder = not entry.HasScrambler
	entry.CanMarkSecurityDetail = true

	if entry.HasScrambler then
		entry.Location = nil
		if istable(entry.ScanData) then
			entry.ScanData.Health = nil
			entry.ScanData.Armor = nil
			entry.ScanData.Name = nil
		end
	elseif entry.IsUnknown and istable(entry.ScanData) then
		entry.ScanData.Name = nil
	end

	return entry
end

function Medical:GetCrewEntryById(id)
	if not id then return nil end
	for _, ply in ipairs(player.GetAll()) do
		if self:GetEntityId(ply) == id then
			return self:BuildCrewEntry(ply)
		end
	end

	for _, ent in ipairs(ents.GetAll()) do
		if not IsValid(ent) or ent:IsPlayer() then
			continue
		end
		if not (ent:IsNPC() or (isfunction(ent.IsNextBot) and ent:IsNextBot())) then
			continue
		end
		if self:GetEntityId(ent) == id then
			return self:BuildCrewEntry(ent)
		end
	end
	return nil
end

function Medical:RegisterBed(bedData)
	if not istable(bedData) then return false end

	local id = bedData.id or bedData.Id
	if not isstring(id) then return false end

	local entry = table.Copy(bedData)
	entry.id = id
	entry.Label = entry.label or id
	entry.ActiveContacts = {}
	entry.CurrentOccupant = nil
	entry.LastEntry = nil
	entry.PanelEnt = nil
	entry.TriggerEnt = nil
	entry.PodEnt = nil

	self.Beds[id] = entry
	return true
end

function Medical:LoadBeds()
	self.Beds = {}

	local files = file.Find("star_trek/medical_system/beds/*.lua", "LUA")
	for _, fileName in SortedPairs(files) do
		local bedData = include("star_trek/medical_system/beds/" .. fileName)
		self:RegisterBed(bedData)
	end
end

function Medical:SpawnBeds()
	self.BedEntityLookup = {}

	for id, bed in pairs(self.Beds) do
		if IsValid(bed.PanelEnt) then
			bed.PanelEnt:Remove()
			bed.PanelEnt = nil
		end
		if IsValid(bed.TriggerEnt) then
			bed.TriggerEnt:Remove()
			bed.TriggerEnt = nil
		end
		if IsValid(bed.PodEnt) then
			bed.PodEnt:Remove()
			bed.PodEnt = nil
		end

		if istable(bed.panel) then
			local model = bed.panel.model or "models/hunter/blocks/cube025x2x025.mdl"
			local success, ent = Star_Trek.Button:CreateInterfaceButton(bed.panel.pos, bed.panel.ang or Angle(), model, "medical_bed")
			if success and IsValid(ent) then
				ent.MedicalBedId = id
				ent:SetNWString("st_med_bed_id", id)
				bed.PanelEnt = ent
				self.BedEntityLookup[ent] = id
			else
				print(string.format("[Star_Trek.Medical] Failed to create panel for bed '%s': %s", id, tostring(ent)))
			end
		end

		local podSpawned = false
		if istable(bed.pod) then
			podSpawned = self:SpawnBedPod(bed, id)
		end

		if not podSpawned and istable(bed.trigger) then
			local trigger = ents.Create("stm_medbed_trigger")
			if IsValid(trigger) then
				trigger:SetPos(bed.trigger.pos)
				trigger:SetAngles(bed.trigger.ang or Angle())
				trigger:Spawn()
				trigger:Activate()
				trigger:Setup(id, bed.trigger.radius, bed.trigger.height)
				trigger.MedicalBedId = id
				bed.TriggerEnt = trigger
				self.BedEntityLookup[trigger] = id
			else
				print(string.format("[Star_Trek.Medical] Failed to create trigger for bed '%s'", id))
			end
		end
	end
end


function Medical:SetupCrewConsole()
	if IsValid(self.CrewConsoleEnt) then
		self:SetCrewConsoleHold(false)
		self.CrewConsoleEnt:Remove()
		self.CrewConsoleEnt = nil
	end

	local cfg = config.CrewConsole
	if not istable(cfg) then
		return
	end

	local pos = cfg.pos
	local ang = cfg.ang or Angle()
	if not (isvector(pos) and isangle(ang)) then
		return
	end

	local model = cfg.model or "models/hunter/blocks/cube025x025x025.mdl"
	local success, ent = Star_Trek.Button:CreateInterfaceButton(pos, ang, model, "medical_status_console")
	if not (success and IsValid(ent)) then
		print("[Star_Trek.Medical] Failed to spawn crew console interface")
		return
	end

	ent:SetNWString("st_med_console", "crew_status")
	self.CrewConsoleEnt = ent
	self:SetCrewConsoleHold(self:GetBridgeHoldState())
end


local function buildRosterKey(includeUnknown, includeScrambled)
	local part1 = includeUnknown and "1" or "0"
	local part2 = includeScrambled and "1" or "0"
	return part1 .. part2
end

function Medical:UpdateCrewConsoles()
	local commsOnline = self:IsCommunicationsOnline()
	local rosterCache = {}

	self:SetCrewConsoleHold(self:GetBridgeHoldState())

	if commsOnline then
		local baseKey = buildRosterKey(false, false)
		rosterCache[baseKey] = self:GetCrewRoster(false, false) or {}
		self:TriggerDownedAlerts(rosterCache[baseKey])
	end

	for ent, _ in pairs(self.ActiveCrewInterfaces) do
		if not IsValid(ent) then
			self.ActiveCrewInterfaces[ent] = nil
			self.ConsoleSettings[ent] = nil
			continue
		end

		local interfaceData = Star_Trek.LCARS.ActiveInterfaces[ent]
		if not interfaceData or interfaceData.Class ~= "medical_status_console" then
			self.ActiveCrewInterfaces[ent] = nil
			self.ConsoleSettings[ent] = nil
			continue
		end

		if isfunction(interfaceData.SetRoster) then
			if not commsOnline then
				interfaceData:SetRoster({})
			else
				local includeUnknown = self:GetConsoleIncludeUnbadged(ent)
				local includeScrambled = self:GetConsoleTrackScrambled(ent)
				local rosterKey = buildRosterKey(includeUnknown, includeScrambled)
				if not rosterCache[rosterKey] then
					rosterCache[rosterKey] = self:GetCrewRoster(includeUnknown, includeScrambled) or {}
				end

				local rosterCopy = table.Copy(rosterCache[rosterKey] or {})
				interfaceData:SetRoster(rosterCopy)
			end
		end
	end

end

function Medical:HandleBedContact(bedId, ply)
	local bed = self.Beds and self.Beds[bedId]
	if not bed then return end

	bed.ActiveContacts = bed.ActiveContacts or {}
	bed.ActiveContacts[ply] = CurTime() + 1.5
end

local DEFAULT_TRIGGER_RADIUS = 80
local DEFAULT_TRIGGER_HEIGHT = 72
local CONTACT_FLOOR_TOLERANCE = 24
local DEFAULT_POD_MODEL = "models/vehicles/prisoner_pod_inner.mdl"
local DEFAULT_POD_SCRIPT = "scripts/vehicles/prisoner_pod.txt"

local function getPodOccupant(pod)
	if not IsValid(pod) then
		return nil
	end

	if isfunction(pod.GetDriver) then
		local driver = pod:GetDriver()
		if IsValid(driver) then
			return driver
		end
	end

	if isfunction(pod.GetPassenger) then
		local passenger = pod:GetPassenger(1)
		if IsValid(passenger) then
			return passenger
		end
	end

	return nil
end

local function getTriggerParameters(triggerData)
	if not istable(triggerData) then
		return nil
	end

	local origin = triggerData.pos
	if not isvector(origin) then
		return nil
	end

	local radius = triggerData.radius
	if not isnumber(radius) or radius <= 0 then
		radius = DEFAULT_TRIGGER_RADIUS
	end

	local height = triggerData.height
	if not isnumber(height) or height <= 0 then
		height = DEFAULT_TRIGGER_HEIGHT
	end

	return origin, radius * radius, height
end

local function isValidBedCandidate(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:Alive()
end

function Medical:SpawnBedPod(bed, id)
	if not istable(bed) then
		return false
	end

	local podData = bed.pod
	if not istable(podData) then
		return false
	end

	local pos = podData.pos
	if not isvector(pos) then
		return false
	end

	local ang = podData.ang or Angle()
	local model = podData.model or DEFAULT_POD_MODEL
	local vehicleScript = podData.vehiclescript or DEFAULT_POD_SCRIPT
	local offset = podData.offset
	if not isvector(offset) then
		offset = Vector(0, 0, podData.offsetHeight or 8)
	end

	local finalOffset = podData.finalOffset
	if not isvector(finalOffset) then
		finalOffset = Vector()
	end
	local pod = ents.Create("prop_vehicle_prisoner_pod")

	if not IsValid(pod) then
		print(string.format("[Star_Trek.Medical] Failed to create pod for bed '%s'", tostring(id)))
		return false
	end

	pod:SetModel(model)
	pod:SetKeyValue("vehiclescript", vehicleScript)
	if podData.limitview ~= nil then
		pod:SetKeyValue("limitview", tostring(podData.limitview))
	end
	pod:SetKeyValue("solid", "0")

	local spawnPos = pos + offset
	pod:SetPos(spawnPos)
	pod:SetAngles(ang)
	pod:Spawn()
	pod:Activate()
	pod:SetNotSolid(true)
	pod:SetPos(pos + finalOffset)

	if podData.noDraw ~= false then
		pod:SetNoDraw(true)
	else
		pod:SetNoDraw(false)
	end
	pod:DrawShadow(false)
	pod:SetUseType(SIMPLE_USE)
	pod:SetMoveType(MOVETYPE_NONE)

	if podData.collisionGroup then
		pod:SetCollisionGroup(podData.collisionGroup)
	else
		pod:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
	end

	local phys = pod:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	if podData.color and IsColor(podData.color) then
		pod:SetRenderMode(RENDERMODE_TRANSALPHA)
		pod:SetColor(podData.color)
	end

	pod.MedicalBedId = id
	pod:SetNWString("st_med_bed_id", id)

	bed.PodEnt = pod
	self.BedEntityLookup[pod] = id

	return true
end

-- Refresh contact data by sampling players near the configured trigger origin.
function Medical:UpdateBedProximity(bed)
	if not istable(bed) or not isstring(bed.id) then
		return
	end

	local pod = bed.PodEnt
	if IsValid(pod) then
		local occupant = getPodOccupant(pod)
		if isValidBedCandidate(occupant) then
			self:HandleBedContact(bed.id, occupant)
		end
	end

	local origin, radiusSqr, height = getTriggerParameters(bed.trigger)
	if not origin then
		return
	end

	for _, ply in ipairs(player.GetAll()) do
		if isValidBedCandidate(ply) then
			local delta = ply:GetPos() - origin
			if delta.z >= -CONTACT_FLOOR_TOLERANCE and delta.z <= height then
				local dist2D = delta.x * delta.x + delta.y * delta.y
				if dist2D <= radiusSqr then
					self:HandleBedContact(bed.id, ply)
				end
			end
		end
	end
end

local function openBedInterface(bed, ply)
	if not IsValid(ply) then return end
	if not IsValid(bed.PanelEnt) then return end

	local success = Star_Trek.LCARS:OpenInterface(ply, bed.PanelEnt, "medical_bed", bed.id, ply)
	if not success then
		return
	end

	local interfaceData = Star_Trek.LCARS.ActiveInterfaces[bed.PanelEnt]
	if istable(interfaceData) then
		interfaceData.BedId = bed.id
	end
end

function Medical:UpdateBedData(bed, ply)
	if not bed then return end

	local entry = self:BuildCrewEntry(ply)
	if not entry then
		return
	end

	entry.BedId = bed.id
	bed.LastEntry = entry

	local panel = bed.PanelEnt
	if not IsValid(panel) then
		return
	end

	local interfaceData = Star_Trek.LCARS.ActiveInterfaces[panel]
	if istable(interfaceData) and interfaceData.Class == "medical_bed" and isfunction(interfaceData.SetPatientEntry) then
		interfaceData:SetPatientEntry(entry)
	end
end

function Medical:OnBedOccupied(bed, ply)
	if not bed or not IsValid(ply) then return end

	openBedInterface(bed, ply)
	self:UpdateBedData(bed, ply)
end

function Medical:OnBedVacated(bed)
	if not bed then return end

	if IsValid(bed.PanelEnt) then
		Star_Trek.LCARS:CloseInterface(bed.PanelEnt)
	end

	bed.CurrentOccupant = nil
	bed.LastEntry = nil
	bed.ActiveContacts = {}
end

function Medical:UpdateBeds()
	local now = CurTime()

	for id, bed in pairs(self.Beds) do
		self:UpdateBedProximity(bed)

		bed.ActiveContacts = bed.ActiveContacts or {}

		local bestPly
		local bestExpire = 0
		for ply, expire in pairs(bed.ActiveContacts) do
			if not IsValid(ply) or now > expire then
				bed.ActiveContacts[ply] = nil
			else
				if expire > bestExpire then
					bestExpire = expire
					bestPly = ply
				end
			end
		end

		if bed.CurrentOccupant ~= bestPly then
			if IsValid(bestPly) then
				bed.CurrentOccupant = bestPly
				self:OnBedOccupied(bed, bestPly)
			else
				self:OnBedVacated(bed)
			end
		end

		if IsValid(bed.CurrentOccupant) then
			self:UpdateBedData(bed, bed.CurrentOccupant)
		end
	end
end

function Medical:Initialize()
	timer.Remove("Star_Trek.Medical.BedUpdate")
	timer.Remove("Star_Trek.Medical.CrewUpdate")

	self:LoadBeds()
	self:SpawnBeds()
	self:SetupCrewConsole()
	self:SetCrewConsoleHold(self:GetBridgeHoldState())

	timer.Create("Star_Trek.Medical.BedUpdate", 1, 0, function()
		Medical:UpdateBeds()
	end)

	timer.Create("Star_Trek.Medical.CrewUpdate", 2, 0, function()
		Medical:UpdateCrewConsoles()
	end)

	self._LastCommsState = self:IsCommunicationsOnline()

	hook.Add("Think", "Star_Trek.Medical.SyncCommsState", function()
		if not Star_Trek or not Star_Trek.Medical then
			return
		end

		local medical = Star_Trek.Medical
		local online = medical:IsCommunicationsOnline()
		if medical._LastCommsState == online then
			return
		end

		medical._LastCommsState = online
		medical:UpdateCrewConsoles()
	end)
end

hook.Add("InitPostEntity", "Star_Trek.Medical.Initialize", function()
	Medical:Initialize()
end)

hook.Add("PostCleanupMap", "Star_Trek.Medical.Reinitialize", function()
	Medical:Initialize()
end)

hook.Add("Star_Trek.Sections.LocationChanged", "Star_Trek.Medical.RefreshHold", function()
	if not Medical then return end
	Medical:SetCrewConsoleHold(Medical:GetBridgeHoldState())
end)

hook.Add("Star_Trek.LCARS.PostOpenInterface", "Star_Trek.Medical.TrackInterfaces", function(ent)
	local id = Medical.BedEntityLookup[ent]
	local interfaceData = Star_Trek.LCARS.ActiveInterfaces[ent]
	if not interfaceData then return end

	if interfaceData.Class == "medical_bed" and id then
		Medical.ActiveBedInterfaces[ent] = id
	elseif interfaceData.Class == "medical_status_console" then
		Medical.ActiveCrewInterfaces[ent] = true
		if isfunction(interfaceData.SetRoster) then
			local roster = Medical:GetCrewRoster(false, false) or {}
			Medical:TriggerDownedAlerts(roster)
			local rosterCopy = table.Copy(roster or {})
			interfaceData:SetRoster(rosterCopy)
		end
	end
end)

hook.Add("Star_Trek.LCARS.OpenInterface", "Star_Trek.Medical.AutoOpenWithComms", function(interfaceData, ply)
	if not (Star_Trek and Star_Trek.Medical and Star_Trek.LCARS) then
		return
	end

	if not istable(interfaceData) or interfaceData.Class ~= "comms_panel" then
		return
	end

	if not IsValid(ply) then
		return
	end

	local medical = Star_Trek.Medical
	local consoleEnt = medical and medical.CrewConsoleEnt or nil
	if not IsValid(consoleEnt) then
		return
	end

	local active = Star_Trek.LCARS.ActiveInterfaces
	if istable(active) and active[consoleEnt] then
		medical:SetCrewConsoleHold(medical:GetBridgeHoldState())
		return
	end

	local success, err = Star_Trek.LCARS:OpenInterface(ply, consoleEnt, "medical_status_console")
	if not success and medical.Debug then
		print(string.format("[Star_Trek.Medical] Failed to auto-open crew console with comms: %s", tostring(err or "unknown error")))
	end
end)

hook.Add("Star_Trek.LCARS.OpenInterface", "Star_Trek.Medical.ScanPanelActivator", function(interfaceData, ply)
	if not istable(interfaceData) or interfaceData.Class ~= "medical_bed" then
		return
	end

	if not IsValid(ply) or not ply:IsPlayer() then
		return
	end

	if not istable(Medical) or not isfunction(Medical.BuildCrewEntry) then
		return
	end

	local entry = Medical:BuildCrewEntry(ply)
	if not entry then
		return
	end

	if isfunction(interfaceData.SetPatientEntry) then
		interfaceData:SetPatientEntry(entry)
	end

	if not interfaceData.BedId then
		local bedId = Medical.BedEntityLookup and Medical.BedEntityLookup[interfaceData.Ent]
		interfaceData.BedId = bedId
	end
end)
hook.Add("Star_Trek.LCARS.PostCloseInterface", "Star_Trek.Medical.CleanupInterfaces", function(ent)
	Medical.ActiveBedInterfaces[ent] = nil
	Medical.ActiveCrewInterfaces[ent] = nil
	Medical.ConsoleSettings[ent] = nil
end)

hook.Add("PlayerEnteredVehicle", "Star_Trek.Medical.MedbedPodEntry", function(ply, vehicle)
	if not (Star_Trek and Star_Trek.Medical) then return end
	if not IsValid(vehicle) then return end

	local bedId = vehicle.MedicalBedId or vehicle:GetNWString("st_med_bed_id", "")
	if not isstring(bedId) or bedId == "" then return end

	Star_Trek.Medical:HandleBedContact(bedId, ply)
end)

hook.Add("PlayerLeaveVehicle", "Star_Trek.Medical.MedbedPodExit", function(ply, vehicle)
	if not (Star_Trek and Star_Trek.Medical) then return end
	if not IsValid(vehicle) then return end

	local bedId = vehicle.MedicalBedId or vehicle:GetNWString("st_med_bed_id", "")
	if not isstring(bedId) or bedId == "" then return end

	local medical = Star_Trek.Medical
	local bed = medical.Beds and medical.Beds[bedId]
	if not bed then return end

	if istable(bed.ActiveContacts) then
		bed.ActiveContacts[ply] = nil
	end
end)
