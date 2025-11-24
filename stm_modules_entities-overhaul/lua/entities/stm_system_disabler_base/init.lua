AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local COLLISION_MASK = COLLISION_GROUP_PASSABLE_DOOR
local DAMAGE_EFFECT_CLASS = "pfx4_05~"

function ENT:GetDisableThresholdValue()
	local maxHealth = math.max(1, self:GetMaxHealth())
	return math.max(1, math.floor(maxHealth * 0.2))
end

function ENT:SpawnDisableSparks()
	local ed = EffectData()
	ed:SetOrigin(self:WorldSpaceCenter())
	ed:SetMagnitude(1)
	ed:SetScale(1)
	util.Effect("Sparks", ed, true, true)
	self:EmitSound("star_trek.lcars_error", 60, 120, 0.4, CHAN_ITEM)
end

function ENT:StartDisableEffect()
	if IsValid(self.DisableFxEnt) then return end
	local fx = ents.Create(DAMAGE_EFFECT_CLASS)
	if not IsValid(fx) then return end
	fx:SetPos(self:GetPos())
	fx:SetAngles(self:GetAngles())
	fx:SetParent(self)
	fx:Spawn()
	self.DisableFxEnt = fx
	self:SpawnDisableSparks()
end

function ENT:StopDisableEffect()
	if IsValid(self.DisableFxEnt) then
		self.DisableFxEnt:Remove()
	end
	self.DisableFxEnt = nil
end

function ENT:Initialize()
	self:SetModel(self.DefaultModel or self:GetModel())
	self:SetColor(self:GetSystemColor())
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_MASK)
	self:SetUseType(SIMPLE_USE)
	self:DrawShadow(false)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:EnableMotion(false)
	end

	self.DisableValid = false
	self.DisableActive = false
	self.LastHealthValue = 0
	self._repairReset = 0
	self._configReady = false
	self.DisableFxEnt = nil

	local maxIntegrity = math.max(1, self:GetMaxIntegrity())
	self:SetMaxIntegrity(maxIntegrity)
	self:SetMaxHealth(maxIntegrity)
	self:SetHealth(maxIntegrity)
	self.LastHealthValue = maxIntegrity
	self:SetPlayerRepairing(false)

	self:SetNWString("stm_system_name", self.SystemName or "Subsystem")

	self:ResolveInitialTarget()
	self._configReady = true
	self:ApplyConfiguration(true)
	self:UpdateVisibility()
	self:UpdateDisableState(true)
end

function ENT:ResolveInitialTarget()
	if not (Star_Trek and Star_Trek.Sections and Star_Trek.Sections.DetermineSection) then return end

	if self:GetTargetDeck() > 0 and (self:GetAffectsDeck() or self:GetTargetSection() > 0) then
		return
	end

	local success, deck, section = Star_Trek.Sections:DetermineSection(self:GetPos())
	if not success then
		return
	end

	if self:GetTargetDeck() <= 0 then
		self:SetTargetDeck(deck)
	end

	if not self:GetAffectsDeck() and self:GetTargetSection() <= 0 then
		self:SetTargetSection(section or 0)
	end
end

function ENT:OnConfigChanged(name, old, new)
	if not self._configReady then
		return
	end

	if name == "InWorldVisible" then
		self:UpdateVisibility()
		return
	end

	if name == "MaxIntegrity" then
		local maxIntegrity = math.max(1, self:GetMaxIntegrity())
		self:SetMaxHealth(maxIntegrity)
		self:SetHealth(math.Clamp(self:Health(), 0, maxIntegrity))
		self.LastHealthValue = self:Health()
		self:UpdateDisableState(true)
		self._reactivateAfterConfig = nil
		return
	end

	if name == "Repairable" then
		if not self:GetRepairable() then
			self:SetHealth(0)
			self.LastHealthValue = 0
		end
		self:UpdateDisableState(true)
		self._reactivateAfterConfig = nil
		return
	end

	if name == "CustomLabel" then
		self:ApplyConfiguration(false)
		self._reactivateAfterConfig = nil
		return
	end

	if name == "AffectsDeck" then
		if self:GetAffectsDeck() and self:GetTargetSection() ~= 0 then
			self._configGuard = true
			self:SetTargetSection(0)
			self._configGuard = nil
		elseif not self:GetAffectsDeck() and self:GetTargetSection() <= 0 then
			if not self._configGuard then
				local success, deck, section = false, self.Deck, self.Section
				if Star_Trek and Star_Trek.Sections and Star_Trek.Sections.DetermineSection then
					success, deck, section = Star_Trek.Sections:DetermineSection(self:GetPos())
				end
				if success and (section or 0) > 0 then
					self._configGuard = true
					self:SetTargetSection(section)
					self._configGuard = nil
				end
			end
		end
	end

	if self._configGuard then
		return
	end

	if name == "TargetDeck" or name == "TargetSection" or name == "AffectsDeck" then
		self:ApplyConfiguration(false)
		local force = self._reactivateAfterConfig
		self._reactivateAfterConfig = nil
		self:UpdateDisableState(force)
	end
end

function ENT:ApplyConfiguration(initial)
	local reactivate = false
	if self.DisableValid and self.DisableActive then
		self:SetEffectActive(false)
		reactivate = true
	end

	local affectsDeck = self:GetAffectsDeck()
	local deck = tonumber(self:GetTargetDeck()) or 0
	local section = affectsDeck and 0 or (tonumber(self:GetTargetSection()) or 0)

	local success, autoDeck, autoSection
	if Star_Trek and Star_Trek.Sections and Star_Trek.Sections.DetermineSection then
		success, autoDeck, autoSection = Star_Trek.Sections:DetermineSection(self:GetPos())
	end

	if deck <= 0 and autoDeck then
		deck = autoDeck
		if initial then
			self:SetTargetDeck(deck)
		end
	end

	if not affectsDeck then
		if section <= 0 and autoSection then
			section = autoSection
			if initial then
				self:SetTargetSection(section)
			end
		end
	else
		section = 0
	end

	if deck <= 0 then
		self.DisableValid = false
		self.Deck = nil
		self.Section = nil
		self.TargetDescription = "Unassigned"
	else
		self.Deck = deck
		if affectsDeck or section <= 0 then
			self.Section = nil
		else
			self.Section = section
		end

		self.DisableValid = true

		local descriptor
		if self.Section then
			local name
			if Star_Trek and Star_Trek.Sections and Star_Trek.Sections.GetSectionName then
				name = Star_Trek.Sections:GetSectionName(self.Deck, self.Section)
			end
			descriptor = name and string.format("Deck %d - %s", self.Deck, name) or string.format("Deck %d - Section %s", self.Deck, tostring(self.Section))
		else
			descriptor = string.format("Deck %d", self.Deck)
		end

		self.TargetDescription = descriptor
	end

	self:SetNWBool("stm_target_valid", self.DisableValid)
	self:SetNWBool("stm_target_deckwide", self.Section == nil)
	self:SetNWString("stm_target_description", self:GetTargetDescription())
	self:SetNWInt("stm_target_deck", self.Deck or 0)
	self:SetNWInt("stm_target_section", self.Section or 0)

	if reactivate then
		self.DisableActive = nil
	end
	self._reactivateAfterConfig = reactivate
end

function ENT:UpdateVisibility()
	self:SetRenderMode(RENDERMODE_TRANSALPHA)
	local baseColor = self:GetSystemColor()
	local alpha = self:GetInWorldVisible() and 255 or 25
	self:SetColor(Color(baseColor.r, baseColor.g, baseColor.b, alpha))
end

function ENT:ShouldDisableSubsystem()
	if not self.DisableValid then
		return false
	end

	if not self:GetRepairable() then
		return true
	end

	local maxHealth = math.max(1, self:GetMaxHealth())
	local hp = math.max(0, self:Health())
	local threshold = self:GetDisableThresholdValue()
	return hp <= threshold
end

function ENT:SetEffectActive(active)
	if self.DisableActive == active then
		return
	end

	self.DisableActive = active
	self:SetNWBool("stm_zone_disabled", active)

	if not self.DisableValid then
		if not active then
			self:StopDisableEffect()
		end
		return
	end

	if active then
		if self:GetRepairable() and self:Health() > 0 then
			self:SetHealth(0)
			self.LastHealthValue = 0
		end
		self:StartDisableEffect()
	else
		self:StopDisableEffect()
	end

	local hooks = self.DisableHooks or {}
	local createHook
	local removeHook
	if self.Section then
		createHook = hooks.sectionCreate
		removeHook = hooks.sectionRemove
	else
		createHook = hooks.deckCreate
		removeHook = hooks.deckRemove
	end

	local hookName = active and createHook or removeHook
	if hookName and hookName ~= "" then
		hook.Run(hookName, self)
	end
end

function ENT:UpdateDisableState(force)
	if force then
		self.DisableActive = nil
	end

	if not self.DisableValid then
		self:SetEffectActive(false)
		return
	end

	local shouldDisable = self:ShouldDisableSubsystem()
	self:SetEffectActive(shouldDisable)
end

function ENT:RepairAmount(amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then
		return false
	end

	if not self:GetRepairable() then
		return false
	end

	local maxHealth = math.max(1, self:GetMaxHealth())
	local newHealth = math.Clamp(self:Health() + amount, 0, maxHealth)
	if newHealth == self:Health() then
		return false
	end

	self:SetHealth(newHealth)
	self.LastHealthValue = newHealth
	self:SetPlayerRepairing(true)
	self._repairReset = CurTime() + 0.75
	self:UpdateDisableState(false)
	return true
end

function ENT:OnTakeDamage(dmg)
	self:TakePhysicsDamage(dmg)
	local amount = dmg:GetDamage() or 0
	if amount <= 0 then return end

	local maxHealth = math.max(1, self:GetMaxHealth())
	local newHealth = math.Clamp(self:Health() - amount, 0, maxHealth)
	if newHealth == self:Health() then return end

	self:SetHealth(newHealth)
	self.LastHealthValue = newHealth
	if self:GetPlayerRepairing() then
		self:SetPlayerRepairing(false)
		self._repairReset = 0
	end
	self:UpdateDisableState(false)
end

function ENT:Think()
	local maxHealth = math.max(1, self:GetMaxHealth())
	local rawHealth = self:Health()
	local hp = math.Clamp(rawHealth, 0, maxHealth)
	if hp ~= rawHealth then
		self:SetHealth(hp)
	end
	if hp ~= self.LastHealthValue then
		local wasActive = self.DisableActive == true
		self.LastHealthValue = hp
		if self:GetPlayerRepairing() and hp >= maxHealth then
			self:SetPlayerRepairing(false)
			self._repairReset = 0
		end
		self:UpdateDisableState(false)
		if wasActive and self.DisableActive == false then
			self:SpawnDisableSparks()
		end
	end

	if self:GetPlayerRepairing() and self._repairReset > 0 and CurTime() >= self._repairReset then
		self:SetPlayerRepairing(false)
		self._repairReset = 0
	end

	self:NextThink(CurTime() + 0.3)
	return true
end

function ENT:OnRemove()
	self:SetEffectActive(false)
	self:StopDisableEffect()
end
