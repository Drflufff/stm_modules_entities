-- Communications Array Repairable Entity
-- This entity has health; below 50% health it sparks; its health drives comms scramble when power is ON.
-- It can be repaired by the sonic driver via ent:RepairAmount(amount).
AddCSLuaFile()

if CLIENT then return end

local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Communications Array"
ENT.Spawnable = false
ENT.AdminSpawnable = false

-- Config
ENT.Model = "models/props_lab/reciever01a.mdl"
ENT.InitialMaxHealth = 100

function ENT:Initialize()
    self:SetModel(self.Model)

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:DrawShadow(true)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    self.CommsMaxHealth = self.InitialMaxHealth or 100
    self.CommsHealth = self.CommsMaxHealth
    self:SetHealth(self.CommsHealth)

    self._nextSpark = 0
end

function ENT:GetCommsMaxHealth()
    return self.CommsMaxHealth or 100
end

function ENT:GetCommsHealth()
    return self.CommsHealth or 0
end

-- Expose MaxHealth for systems that expect the default API
function ENT:GetMaxHealth()
    return self:GetCommsMaxHealth()
end

local function sync_scramble()
    if StarTrekEntities and StarTrekEntities.Comms and StarTrekEntities.Comms.SyncScrambleFromHealth then
        StarTrekEntities.Comms:SyncScrambleFromHealth()
    end
end

local function do_spark(ent)
    if not IsValid(ent) then return end
    local ed = EffectData()
    ed:SetOrigin(ent:WorldSpaceCenter())
    ed:SetMagnitude(1)
    ed:SetScale(1)
    util.Effect("Sparks", ed, true, true)
    ent:EmitSound("DoSpark", 65, 100, 0.4, CHAN_ITEM)
end

function ENT:Think()
    -- Continuous sparking while below 50% health
    local maxhp = self:GetCommsMaxHealth()
    local hp = self:GetCommsHealth()
    if maxhp > 0 and hp < (0.5 * maxhp) then
        if CurTime() >= (self._nextSpark or 0) then
            do_spark(self)
            self._nextSpark = CurTime() + math.Rand(0.6, 1.5)
        end
    else
        -- No sparks at or above 50%
        self._nextSpark = CurTime() + 1.0
    end

    self:NextThink(CurTime() + 0.1)
    return true
end

function ENT:OnTakeDamage(dmg)
    if not IsValid(self) then return end
    local amount = dmg:GetDamage() or 0
    if amount <= 0 then return end

    local newhp = math.max(0, (self.CommsHealth or 0) - amount)
    self.CommsHealth = newhp
    self:SetHealth(newhp)

    local maxhp = self:GetCommsMaxHealth()

    -- Trigger yellow alert once when dropping below 50%
    if not self._yellowTriggered and maxhp > 0 and newhp < (0.50 * maxhp) then
        self._yellowTriggered = true
        if Star_Trek and Star_Trek.Alert and Star_Trek.Alert.Enable then
            Star_Trek.Alert:Enable("yellow")
        end
    end

    -- Beep when health detected below 35% (cooldown)
    if maxhp > 0 and newhp < (0.35 * maxhp) then
        self._nextHealthBeep = self._nextHealthBeep or 0
        if CurTime() >= self._nextHealthBeep then
            self._nextHealthBeep = CurTime() + 3
            self:EmitSound("star_trek.lcars_alert14")
        end
    end

    -- Update scramble mapping when damaged
    sync_scramble()
end

-- Optional: also handle trace-based damage paths
function ENT:OnTraceAttack(dmg, dir, trace)
    self:OnTakeDamage(dmg)
end

-- Repair API used by sonic driver and automated repair
function ENT:RepairAmount(amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local maxhp = self:GetCommsMaxHealth()
    local newhp = math.min(maxhp, (self.CommsHealth or 0) + amount)
    self.CommsHealth = newhp
    self:SetHealth(newhp)


    -- Reset yellow flag when sufficiently repaired (>55%) to allow future triggers
    if maxhp > 0 and newhp > (0.55 * maxhp) then
        self._yellowTriggered = nil
    end

    -- Update scramble mapping when repaired
    sync_scramble()
end

-- Register entity
scripted_ents.Register(ENT, "comms_repair")
