AddCSLuaFile()

local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Gravity Generator"
ENT.Category = "Star Trek"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Editable = true

ENT.Model = "models/hunter/blocks/cube05x075x025.mdl"
ENT.InitialMaxHealth = 250
ENT.CriticalFraction = 0.3
ENT.MinGravityScale = 0.2
ENT.MaxGravityScale = 2.5
ENT.DefaultGravityScale = 1
ENT.EmergencyGravityScale = 0.45
ENT.FailGravityScale = 0.12

local PLAYER_REFRESH_INTERVAL = 1

local disabled_gravity = {}
local players_location = {}

local function trackPlayerLocation(ply, deck, section)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	players_location[ply:SteamID64()] = {deck = deck, section = section}
end

hook.Add("Star_Trek.Sections.LocationChanged", "GravGenerator.TrackLocation", function(ply, oldDeck, oldSectionId, newDeck, newSectionId)
	trackPlayerLocation(ply, newDeck, newSectionId)
end)

hook.Add("PlayerDisconnected", "GravGenerator.DropLocation", function(ply)
	if not IsValid(ply) then return end
	players_location[ply:SteamID64()] = nil
end)

hook.Add("OnDisableGravitySectionCreated", "GravGenerator.DisableSection", function(ent)
	if not ent or ent.Deck == nil or ent.Section == nil then return end
	disabled_gravity[ent.Deck] = disabled_gravity[ent.Deck] or {entire_deck = false, sections = {}}
	disabled_gravity[ent.Deck].sections[ent.Section] = true
end)

hook.Add("OnDisableGravitySectionRemoved", "GravGenerator.EnableSection", function(ent)
	if not ent or ent.Deck == nil or ent.Section == nil then return end
	if not disabled_gravity[ent.Deck] then return end
	disabled_gravity[ent.Deck].sections[ent.Section] = nil
	if table.IsEmpty(disabled_gravity[ent.Deck].sections) and not disabled_gravity[ent.Deck].entire_deck then
		disabled_gravity[ent.Deck] = nil
	end
end)

hook.Add("OnDisableGravityDeckCreated", "GravGenerator.DisableDeck", function(ent)
	if not ent or ent.Deck == nil then return end
	disabled_gravity[ent.Deck] = disabled_gravity[ent.Deck] or {entire_deck = false, sections = {}}
	disabled_gravity[ent.Deck].entire_deck = true
end)

hook.Add("OnDisableGravityDeckRemoved", "GravGenerator.EnableDeck", function(ent)
	if not ent or ent.Deck == nil then return end
	if not disabled_gravity[ent.Deck] then return end
	disabled_gravity[ent.Deck].entire_deck = false
	if table.IsEmpty(disabled_gravity[ent.Deck].sections) then
		disabled_gravity[ent.Deck] = nil
	end
end)

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "PlayerRepairing")
	self:NetworkVar("Float", 0, "GravityOutputRaw")
	self:NetworkVar("Bool", 1, "DisplayHealth")
	self:NetworkVar("Int", 2, "ConfiguredHealth", {
		KeyName = "ConfiguredHealth",
		Edit = {
			type = "Int",
			title = "Generator Integrity",
			category = "Integrity",
			order = 0,
			min = 0,
			max = 2000,
		},
	})
	self:NetworkVar("Int", 3, "ConfiguredMaxHealth", {
		KeyName = "ConfiguredMaxHealth",
		Edit = {
			type = "Int",
			title = "Max Generator Integrity",
			category = "Integrity",
			order = 1,
			min = 50,
			max = 2000,
		},
	})

	if SERVER then
		self.InitialMaxHealth = math.max(50, math.floor(self.InitialMaxHealth or 50))
		self:SetPlayerRepairing(false)
		self:SetGravityOutputRaw(self.DefaultGravityScale)
		self:SetDisplayHealth(true)
		self._suppressConfiguredMaxHealth = true
		self:SetConfiguredMaxHealth(self.InitialMaxHealth)
		self._suppressConfiguredMaxHealth = false
		self._suppressConfiguredHealth = true
		self:SetConfiguredHealth(self.InitialMaxHealth)
		self._suppressConfiguredHealth = false

		self:NetworkVarNotify("ConfiguredMaxHealth", function(ent, name, old, new)
			ent:OnConfiguredMaxHealthEdited(old, new)
		end)

		self:NetworkVarNotify("ConfiguredHealth", function(ent, name, old, new)
			ent:OnConfiguredHealthEdited(old, new)
		end)
	end
end

if SERVER then

function ENT:SetConfiguredMaxHealthValue(value)
	local clamped = math.Clamp(math.floor(tonumber(value) or self.InitialMaxHealth or 0), 50, 2000)
	self._suppressConfiguredMaxHealth = true
	self:SetConfiguredMaxHealth(clamped)
	self._suppressConfiguredMaxHealth = nil
end

function ENT:SetConfiguredHealthValue(value)
	local maxhp = math.max(50, math.floor(self:GetConfiguredMaxHealth() or self:GetMaxHealth() or self.InitialMaxHealth or 50))
	local clamped = math.Clamp(math.floor(tonumber(value) or 0), 0, maxhp)
	self._suppressConfiguredHealth = true
	self:SetConfiguredHealth(clamped)
	self._suppressConfiguredHealth = nil
end

function ENT:OnConfiguredMaxHealthEdited(oldValue, newValue)
	if self._suppressConfiguredMaxHealth then return end
	local maxhp = math.Clamp(math.floor(tonumber(newValue) or self.InitialMaxHealth or 0), 50, 2000)
	if maxhp ~= newValue then
		self:SetConfiguredMaxHealthValue(maxhp)
		newValue = maxhp
	end

	self.InitialMaxHealth = maxhp
	self:SetMaxHealth(maxhp)

	local previousHealth = self:Health()
	local clamped = math.Clamp(previousHealth, 0, maxhp)
	if previousHealth ~= clamped then
		self:SetHealth(clamped)
		self.LastHealthValue = clamped
		self._suppressConfiguredHealth = true
		self:SetConfiguredHealth(clamped)
		self._suppressConfiguredHealth = nil
		self:OnConfiguredHealthEdited(previousHealth, clamped, true)
	else
		self._suppressConfiguredHealth = true
		self:SetConfiguredHealth(clamped)
		self._suppressConfiguredHealth = nil
	end

	self:RefreshGravity()
	self:NotifyStatusChanged()
end

function ENT:OnConfiguredHealthEdited(oldValue, newValue, ignoreGuard)
	if self._suppressConfiguredHealth and not ignoreGuard then return end
	local maxhp = math.max(50, math.floor(self:GetMaxHealth() or self.InitialMaxHealth or 50))
	local newhp = math.Clamp(math.floor(tonumber(newValue) or 0), 0, maxhp)
	if newhp ~= newValue then
		self:SetConfiguredHealthValue(newhp)
		newValue = newhp
	end

	local oldhp = math.Clamp(math.floor(tonumber(oldValue) or self:Health()), 0, maxhp)
	self:SetHealth(newhp)
	self.LastHealthValue = newhp
	self.Working = (self.OverrideState ~= false) and newhp > 0

	local wasDestroyed = oldhp <= 0
	local nowDestroyed = newhp <= 0

	if nowDestroyed then
		if not wasDestroyed then
			self.Working = false
			local previousOverride = self.OverrideState
			if previousOverride ~= false then
				self._autoForcedOffline = true
				self._preFailureOverrideState = previousOverride
				self:SetManualOverride(false)
			else
				self._autoForcedOffline = nil
				self._preFailureOverrideState = nil
			end
			self:SpawnLeakEffect()
			self:Ignite(10, 250)
			hook.Run("OnGravGenDestroyed", self)
		end
	else
		if wasDestroyed then
			if self._autoForcedOffline then
				local restore = self._preFailureOverrideState
				self._autoForcedOffline = nil
				self._preFailureOverrideState = nil

				if restore == true then
					self:SetManualOverride(true)
				elseif restore == nil then
					self:SetManualOverride(nil)
				end
			end
			local restoredScale = math.Clamp(self.LastGravityScale or self.DefaultGravityScale, self.MinGravityScale, self.MaxGravityScale)
			local ok, result = self:SetGravityScale(restoredScale)
			if ok then
				self.LastGravityScale = tonumber(result) or restoredScale
			else
				self:SetGravityOutputRaw(restoredScale)
				self.LastGravityScale = restoredScale
				self:RefreshGravity()
				self:NotifyStatusChanged()
			end
			self:RemoveLeakEffect()
			self:Extinguish()
			if IsValid(self.ShockEnt) then
				self.ShockEnt:Remove()
				self.ShockEnt = nil
			end
			self._nextSpark = 0
			hook.Run("OnGravGenRepaired", self)
		end
	end

	if newhp >= maxhp then
		self:SetPlayerRepairing(false)
	end

	self.Working = (self.OverrideState ~= false) and self:Health() > 0

	self:RefreshGravity()
	self:NotifyStatusChanged()
end

end

function ENT:GetGravityScale()
	return math.Clamp(self:GetGravityOutputRaw() or self.DefaultGravityScale, self.MinGravityScale, self.MaxGravityScale)
end

function ENT:GetEffectiveGravityScale()
	local raw = self:GetGravityOutputRaw()
	if raw == nil then
		raw = self.DefaultGravityScale
	end

	local clamped = math.Clamp(raw, self.MinGravityScale, self.MaxGravityScale)

	if self:IsOperational() then
		return clamped
	end

	if self:Health() <= 0 then
		return math.max(self.FailGravityScale or 0, 0)
	end

	if self.OverrideState == false then
		return 0
	end

	if self.Working == false then
		return math.max(self.FailGravityScale or 0, 0)
	end

	return clamped
end

function ENT:SetGravityScale(scale)
	scale = tonumber(scale) or self:GetGravityScale()
	if not self:IsOperational() then
		return false, "Gravity generator offline. Repairs or restart required."
	end

	scale = math.Clamp(scale, self.MinGravityScale, self.MaxGravityScale)
	local current = self:GetGravityScale()
	if math.abs(current - scale) < 0.01 then
		return false, string.format("Gravity already at %.2fg", scale)
	end

	self:SetGravityOutputRaw(scale)
	self.LastGravityScale = scale
	self:RefreshGravity()
	hook.Run("OnGravGenScaleChanged", self, scale)
	self:NotifyStatusChanged()
	return true, scale
end

function ENT:AdjustGravityScale(delta)
	delta = tonumber(delta) or 0
	if delta == 0 then
		return false, "No adjustment specified."
	end
	return self:SetGravityScale(self:GetGravityScale() + delta)
end

function ENT:IsOperational()
	if self.OverrideState == false then
		return false
	end
	if self:Health() <= 0 then
		return false
	end
	return self.Working ~= false
end

function ENT:NotifyStatusChanged()
	if StarTrekEntities and StarTrekEntities.Gravity then
		StarTrekEntities.Gravity:SetGenerator(self)
	end
end

function ENT:SetManualOverride(state)
	if state == nil then
		self.OverrideState = nil
	elseif state then
		self.OverrideState = true
	else
		self.OverrideState = false
	end
	self:RefreshGravity()
	self:NotifyStatusChanged()
end

function ENT:ShutdownGenerator()
	if not self:IsOperational() and self.OverrideState == false then
		return false, "Gravity generators already offline."
	end

	self.Working = false
	self:SetManualOverride(false)
	self:RefreshGravity()
	return true, "Gravity generators offline. Field output suspended."
end

function ENT:RestartGenerator()
	if self:Health() <= 0 then
		return false, "Gravity generator damaged. Repairs required."
	end

	self.Working = true
	self:SetManualOverride(nil)
	self:SetGravityOutputRaw(math.Clamp(self:GetGravityScale(), self.MinGravityScale, self.MaxGravityScale))
	self:RefreshGravity()
	return true, "Gravity generators restarted. Output nominal."
end

function ENT:EmergencyGenerator(scale)
	local destroyed = self:Health() <= 0

	if self.OverrideState == true then
		self:SetManualOverride(nil)
		if destroyed then
			self.Working = false
			self:RefreshGravity()
			return true, "Emergency override cleared. Generator remains offline."
		end

		self.Working = true
		local ok, result = self:SetGravityScale(self.DefaultGravityScale)
		if ok then
			return true, "Emergency override cleared. Output stabilized."
		end
		return true, result or "Emergency override cleared."
	end

	if destroyed then
		return false, "Gravity generator damaged. Repairs required."
	end

	scale = tonumber(scale) or self.EmergencyGravityScale
	scale = math.Clamp(scale, self.MinGravityScale, self.MaxGravityScale)

	self.Working = true
	self:SetManualOverride(true)
	local ok, result = self:SetGravityScale(scale)
	if ok then
		return true, string.format("Emergency gravity routing engaged. Output %.2fg", result)
	end
	return ok, result
end

function ENT:GetHealthPercent()
	local maxhp = self:GetMaxHealth()
	if maxhp <= 0 then
		return 0
	end
	return math.max(0, math.floor((self:Health() / maxhp) * 100))
end

function ENT:Initialize()
	local removalClasses = {"prop_physics", "prop_dynamic", "prop_dynamic_override", "prop_static"}
	for _, class in ipairs(removalClasses) do
		for _, prop in ipairs(ents.FindByClass(class)) do
			if not IsValid(prop) then continue end
			if prop:GetModel() ~= self.Model then continue end
			if prop:GetPos():DistToSqr(self:GetPos()) > (18 * 18) then continue end
			prop:Remove()
		end
	end

	self:SetModel(self.Model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:SetNoDraw(false)
	self:DrawShadow(true)
	self:SetRenderMode(RENDERMODE_NORMAL)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:EnableMotion(false)
	end

	self:SetMaxHealth(self.InitialMaxHealth)
	self:SetHealth(self.InitialMaxHealth)
	self.LastHealthValue = self:Health()
	self.Working = true
	self.OverrideState = nil
	self._autoForcedOffline = nil
	self._preFailureOverrideState = nil
	self.LastGravityScale = self.DefaultGravityScale
	self._nextShockSound = 0
	self._nextSpark = 0
	self._nextPlayerRefresh = 0

	StarTrekEntities.Gravity:SetGenerator(self)
	hook.Run("OnGravGenInitialized", self)
end

function ENT:SpawnLeakEffect()
	if IsValid(self.LeakEffect) then return end
	if not (Star_Trek and Star_Trek.Grav_Panel and Star_Trek.Grav_Panel.LeakPosition) then return end

	local leak = ents.Create("pfx5_01")
	if not IsValid(leak) then return end

	leak:SetPos(Star_Trek.Grav_Panel.LeakPosition)
	local leakAng = Star_Trek.Grav_Panel.LeakAngle
	leak:SetAngles(isangle(leakAng) and leakAng or Angle(0, 0, 0))
	leak:SetModel("models/hunter/blocks/cube025x025x025.mdl")
	leak:Spawn()
	leak:Activate()
	leak:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	self.LeakEffect = leak
end

function ENT:RemoveLeakEffect()
	if IsValid(self.LeakEffect) then
		self.LeakEffect:Remove()
	end
	self.LeakEffect = nil
end

function ENT:OnTakeDamage(dmg)
	self:TakePhysicsDamage(dmg)
	if self:Health() <= 0 then return end

	local amount = dmg:GetDamage() or 0
	if amount <= 0 then return end

	local current = self:Health()
	local newhp = math.Clamp(current - amount, 0, self:GetMaxHealth())
	if newhp == current then return end

	self._suppressConfiguredHealth = true
	self:SetConfiguredHealth(newhp)
	self._suppressConfiguredHealth = nil
	self:OnConfiguredHealthEdited(current, newhp, true)

	hook.Run("OnGravGenDamaged", self, dmg)

	if newhp <= 0 then
		local explosion = ents.Create("env_explosion")
		if IsValid(explosion) then
			explosion:SetKeyValue("spawnflags", 16)
			explosion:SetKeyValue("iMagnitude", 15)
			explosion:SetKeyValue("iRadiusOverride", 256)
			explosion:SetPos(self:GetPos())
			explosion:Spawn()
			explosion:Fire("explode", "", 0)
		end
	end
end

function ENT:RepairAmount(amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return end

	local maxhp = self:GetMaxHealth()
	local current = self:Health()
	local newhp = math.Clamp(current + amount, 0, maxhp)
	if newhp == current then return end

	self:SetPlayerRepairing(true)
	self._suppressConfiguredHealth = true
	self:SetConfiguredHealth(newhp)
	self._suppressConfiguredHealth = nil
	self:OnConfiguredHealthEdited(current, newhp, true)

	if newhp >= maxhp then
		self:SetPlayerRepairing(false)
	end
end

function ENT:ApplyGravity(ply, remove_grav)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	if remove_grav then
		local failScale = math.max(0.01, self.FailGravityScale)
		ply:SetGravity(failScale)
		ply:SetFriction(math.Clamp(failScale * 0.5, 0.1, 1))
	else
		local scale = self:GetGravityScale()
		ply:SetGravity(scale)
		ply:SetFriction(math.Clamp(scale, 0.2, 1.2))
	end
end

function ENT:RefreshGravity()
	self._nextPlayerRefresh = 0
end

local function shouldRemoveGravity(ent, ply)
	if not IsValid(ply) then return true end

	local location = players_location[ply:SteamID64()] or {}
	local deck = location.deck
	local section = location.section

	if deck == nil or section == nil then
		return false
	end

	local grav_data = disabled_gravity[deck]
	if grav_data then
		if grav_data.entire_deck then
			return true
		end
		if grav_data.sections and grav_data.sections[section] then
			return true
		end
	end

	if ent:Health() <= 0 or not ent:IsOperational() then
		return true
	end

	return false
end

function ENT:ThinkGravity()
	local now = CurTime()
	if self._nextPlayerRefresh > now then return end
	self._nextPlayerRefresh = now + PLAYER_REFRESH_INTERVAL

	for _, ply in ipairs(player.GetAll()) do
		local remove_grav = shouldRemoveGravity(self, ply)
		self:ApplyGravity(ply, remove_grav)
	end
end

local function spawnSparks(ent)
	if not IsValid(ent) then return end
	local ed = EffectData()
	ed:SetOrigin(ent:WorldSpaceCenter())
	ed:SetMagnitude(1)
	ed:SetScale(1)
	util.Effect("Sparks", ed, true, true)
	ent:EmitSound("star_trek.lcars_error", 10, 120, 0.4, CHAN_ITEM)
end

function ENT:Think()
	local now = CurTime()
	if SERVER then
		self:ThinkGravity()
	end

	local maxhp = self:GetMaxHealth()
	local hp = self:Health()
	local criticalThreshold = maxhp > 0 and (self.CriticalFraction * maxhp) or 0
	local shockThreshold = maxhp > 0 and (0.2 * maxhp) or 0

	if maxhp > 0 and hp < criticalThreshold then
		if now >= (self._nextSpark or 0) then
			spawnSparks(self)
			self._nextSpark = now + math.Rand(0.6, 1.5)
		end

		if now >= (self._nextShockSound or 0) then
			self._nextShockSound = now + math.Clamp(60 * (hp / maxhp), 5, 60)
			self:EmitSound("ambient/levels/labs/electric_explosion1.wav", 10, 100, 0.5)
		end
	end

	if maxhp > 0 and hp <= shockThreshold then
		if not IsValid(self.ShockEnt) then
			local shock = ents.Create("pfx4_05~")
			if IsValid(shock) then
				shock:SetPos(self:GetPos())
				shock:SetAngles(self:GetAngles())
				shock:SetParent(self)
				shock:Spawn()
				shock:Activate()
				self.ShockEnt = shock
			end
		end
	else
		if IsValid(self.ShockEnt) then
			self.ShockEnt:Remove()
			self.ShockEnt = nil
		end
	end

	if hp > 0 then
		self:RemoveLeakEffect()
	end

	if self:GetPlayerRepairing() and hp >= maxhp then
		self:SetPlayerRepairing(false)
	end

	if maxhp > 0 and hp > (0.2 * maxhp) then
		if IsValid(self.ShockEnt) then
			self.ShockEnt:Remove()
			self.ShockEnt = nil
		end
	end

	if SERVER then
		self:NextThink(now + 0.25)
	end
	return true
end

function ENT:Use(activator)
	-- Gravity generator is managed via LCARS consoles.
end

function ENT:OnRemove()
	self:RemoveLeakEffect()
	if IsValid(self.ShockEnt) then
		self.ShockEnt:Remove()
		self.ShockEnt = nil
	end
	hook.Run("OnGravGenRemoved", self)
	if StarTrekEntities and StarTrekEntities.Gravity and StarTrekEntities.Gravity:GetGenerator() == self then
		StarTrekEntities.Gravity:SetGenerator(nil)
	end
end

scripted_ents.Register(ENT, "gravgen")
