AddCSLuaFile()

local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Life Support Core"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Editable = true

ENT.Model = "models/kingpommes/startrek/intrepid/eng_wallpanel.mdl"
ENT.InitialMaxHealth = 250
ENT.CriticalFraction = 0.25

local ALERT_SOUND = "star_trek.lcars_alert14"
local ALERT_POSITION = Vector(-6.93, -230.88, 13416.59)
local ALERT_REPEAT = 3
local ALERT_INTERVAL = 0.8

local REPAIR_PANEL_MODEL = "models/kingpommes/startrek/intrepid/eng_wallpanel.mdl"
local REPAIR_PANEL_OFFSET = Vector(-2.5, 0, 12)
local REPAIR_PANEL_ANGLE = Angle(0, 0, 0)
local BACKUP_OXYGEN_DURATION = 45

ENT.AlertModes = ENT.AlertModes or {"none", "blue", "yellow", "intruder", "red"}

function ENT:RefreshAlertModes()
    local baseOrder = {"none", "blue", "yellow", "intruder", "red"}
    local modes = {}
    local seen = {}

    for _, value in ipairs(baseOrder) do
        modes[#modes + 1] = value
        seen[value] = true
    end

    if Star_Trek and Star_Trek.Alert and Star_Trek.Alert.AlertTypes then
        for name in pairs(Star_Trek.Alert.AlertTypes) do
            local lower = string.lower(name)
            if not seen[lower] then
                modes[#modes + 1] = lower
                seen[lower] = true
            end
        end
    end

    self.AlertModes = modes
end

function ENT:FindAlertModeIndex(mode)
    if not istable(self.AlertModes) then
        self:RefreshAlertModes()
    end

    local modes = self.AlertModes or {"none"}
    local target = string.lower(tostring(mode or ""))
    for index, value in ipairs(modes) do
        if value == target then
            return index
        end
    end

    if #modes == 0 then
        modes[1] = "none"
        self.AlertModes = modes
        return 1
    end

    local fallback = (#modes >= 2) and 2 or 1
    return math.Clamp(fallback, 1, #modes)
end

function ENT:GetAlertModeByIndex(index)
    if not istable(self.AlertModes) then
        self:RefreshAlertModes()
    end

    local modes = self.AlertModes or {"none"}
    if #modes == 0 then
        return "none"
    end

    local clamped = math.Clamp(math.floor(index or 1), 1, #modes)
    return modes[clamped]
end

function ENT:GetOutageAlert()
    if not self.GetOutageAlertIndex then
        return "none"
    end

    return self:GetAlertModeByIndex(self:GetOutageAlertIndex())
end

function ENT:SetOutageAlert(mode)
    if not self.SetOutageAlertIndex then return end
    local index = self:FindAlertModeIndex(mode)
    if self:GetOutageAlertIndex() ~= index then
        self:SetOutageAlertIndex(index)
    else
        self:UpdateAlertIndicator()
    end
end

function ENT:GetAlertFriendlyName(mode)
    local key = string.lower(tostring(mode or ""))
    if key == "none" then
        return "No Alert"
    end

    return string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2) .. " Alert"
end

function ENT:UpdateAlertIndicator()
    if not self.SetNWString then return end
    self:SetNWString("life_support_alert_mode", self:GetAlertFriendlyName(self:GetOutageAlert()))
    self:SetNWBool("life_support_alert_enabled", self.GetOutageAlertsEnabled and self:GetOutageAlertsEnabled() ~= false)
end

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "PlayerRepairing")
    self:NetworkVar("Int", 0, "DamageAmount")
    self:NetworkVar("Int", 1, "DamageSeconds")
    self:NetworkVar("Bool", 1, "DisplayHealth")
    self:NetworkVar("Int", 2, "LifeSupportHealth", {
        KeyName = "LifeSupportHealth",
        Edit = {
            type = "Int",
            title = "Core Integrity",
            category = "Integrity",
            order = 0,
            min = 0,
            max = 2000,
        },
    })
    self:NetworkVar("Int", 3, "LifeSupportMaxHealth", {
        KeyName = "LifeSupportMaxHealth",
        Edit = {
            type = "Int",
            title = "Max Core Integrity",
            category = "Integrity",
            order = 1,
            min = 50,
            max = 2000,
        },
    })
    self:NetworkVar("Bool", 2, "OutageAlertsEnabled", {
        KeyName = "OutageAlertsEnabled",
        Edit = {
            type = "Boolean",
            title = "Trigger Outage Alert",
            category = "Alerts",
            order = 0,
        },
    })
    self:NetworkVar("Int", 4, "OutageAlertIndex", {
        KeyName = "OutageAlertIndex",
        Edit = {
            type = "Int",
            title = "Outage Alert Mode",
            category = "Alerts",
            order = 1,
            min = 1,
            max = 10,
        },
    })

    if SERVER then
        self.InitialMaxHealth = math.max(50, math.floor(self.InitialMaxHealth or 50))
        self:SetDamageAmount(2)
        self:SetDamageSeconds(1)
        self:SetDisplayHealth(true)
        self:SetCoreMaxHealthValue(self.InitialMaxHealth)
        self:SetCoreHealthValue(self.InitialMaxHealth)
        self:RefreshAlertModes()
        self:SetOutageAlertsEnabled(true)
        self:SetOutageAlert("blue")
        self:UpdateAlertIndicator()

        self:NetworkVarNotify("LifeSupportMaxHealth", function(ent, name, old, new)
            ent:OnLifeSupportMaxHealthEdited(old, new)
        end)

        self:NetworkVarNotify("LifeSupportHealth", function(ent, name, old, new)
            ent:OnLifeSupportHealthEdited(old, new)
        end)

        self:NetworkVarNotify("OutageAlertsEnabled", function(ent, name, old, new)
            ent:UpdateAlertIndicator()
            if StarTrekEntities and StarTrekEntities.LifeSupport then
                StarTrekEntities.LifeSupport:OnCoreAlertToggleChanged(ent, new)
            end
        end)

        self:NetworkVarNotify("OutageAlertIndex", function(ent, name, old, new)
            local mode = ent:GetOutageAlert()
            local expectedIndex = ent:FindAlertModeIndex(mode)
            if ent:GetOutageAlertIndex() ~= expectedIndex then
                ent:SetOutageAlertIndex(expectedIndex)
                return
            end

            ent:UpdateAlertIndicator()
            if StarTrekEntities and StarTrekEntities.LifeSupport then
                StarTrekEntities.LifeSupport:OnCoreAlertModeChanged(ent, mode)
            end
        end)
    end
end

if SERVER then

    local disabled_sections = {}
    local disabled_decks = {}
    local players_location = {}

    function ENT:SetCoreMaxHealthValue(value)
        local clamped = math.Clamp(math.floor(tonumber(value) or self.InitialMaxHealth or 0), 50, 2000)
        self._suppressMaxHealthNotify = true
        self:SetLifeSupportMaxHealth(clamped)
        self._suppressMaxHealthNotify = nil
    end

    function ENT:SetCoreHealthValue(value)
        local maxhp = math.max(50, math.floor(self:GetLifeSupportMaxHealth() or self.InitialMaxHealth or 50))
        local clamped = math.Clamp(math.floor(tonumber(value) or 0), 0, maxhp)
        self._suppressHealthNotify = true
        self:SetLifeSupportHealth(clamped)
        self._suppressHealthNotify = nil
    end

    function ENT:OnLifeSupportMaxHealthEdited(oldValue, newValue)
        if self._suppressMaxHealthNotify then return end
        local maxhp = math.Clamp(math.floor(tonumber(newValue) or self.InitialMaxHealth or 0), 50, 2000)
        if maxhp ~= newValue then
            self:SetCoreMaxHealthValue(maxhp)
            newValue = maxhp
        end

        self.InitialMaxHealth = maxhp
        self:SetMaxHealth(maxhp)

        local current = self:GetLifeSupportHealth()
        if current > maxhp then
            local old = current
            self:SetCoreHealthValue(maxhp)
            self:OnLifeSupportHealthEdited(old, maxhp)
        else
            self:SetHealth(current)
        end

        self:UpdateScannerData()
        self:NotifyStatusChanged()
    end

    function ENT:OnLifeSupportHealthEdited(oldValue, newValue)
        if self._suppressHealthNotify then return end

        local maxhp = math.max(50, math.floor(self:GetLifeSupportMaxHealth() or self.InitialMaxHealth or 50))
        local newhp = math.Clamp(math.floor(tonumber(newValue) or 0), 0, maxhp)
        if newhp ~= newValue then
            self:SetCoreHealthValue(newhp)
            newValue = newhp
        end

        local oldhp = math.Clamp(math.floor(tonumber(oldValue) or self:GetLifeSupportHealth() or 0), 0, maxhp)

        self:SetHealth(newhp)
        self.Working = (self.OverrideState ~= false) and newhp > 0

        if newhp <= 0 then
            self:TriggerCriticalAlert()
        elseif self.AlertTriggered then
            self:ClearCriticalAlert()
        end

        if newhp >= maxhp then
            self:SetPlayerRepairing(false)
        end

        if newhp <= 0 then
            if not self.DestroyedBroadcast or oldhp > 0 then
                local previousOverride = self.OverrideState
                if previousOverride ~= false then
                    self._autoForcedOffline = true
                    self._preFailureOverrideState = previousOverride
                    self:SetManualOverride(false)
                else
                    self._autoForcedOffline = nil
                    self._preFailureOverrideState = nil
                end

                self.DestroyedBroadcast = true
                self:ExtendBackup(BACKUP_OXYGEN_DURATION)
                hook.Run("OnLifeSupportDestroyed", self)
            end
        else
            if self.DestroyedBroadcast and oldhp <= 0 then
                self.DestroyedBroadcast = false

                if self._autoForcedOffline then
                    local restore = self._preFailureOverrideState
                    self._autoForcedOffline = nil
                    self._preFailureOverrideState = nil

                    local controller = StarTrekEntities and StarTrekEntities.LifeSupport
                    if restore == true then
                        if controller and controller.SetManualOverride then
                            controller:SetManualOverride(true, self)
                        else
                            self:SetManualOverride(true)
                        end
                    elseif restore == nil then
                        if controller and controller.ClearManualOverride then
                            controller:ClearManualOverride(self)
                        else
                            self:SetManualOverride(nil)
                        end
                    end
                end

                self:SetBackupDeadline(nil)
                self:Extinguish()
                if IsValid(self.ShockEnt) then
                    self.ShockEnt:Remove()
                    self.ShockEnt = nil
                end
                self._nextSpark = 0
                hook.Run("OnLifeSupportRepaired", self)
            end
        end

        self.Working = (self.OverrideState ~= false) and newhp > 0

        self:UpdateScannerData()
        self:NotifyStatusChanged()
    end

    hook.Add("Star_Trek.Sections.LocationChanged", "LifeSupport.Core.Location", function(ply, oldDeck, oldSectionId, newDeck, newSectionId)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        players_location[ply:SteamID64()] = {newDeck, newSectionId}
    end)

    hook.Add("PlayerDisconnected", "LifeSupport.Core.DropLocation", function(ply)
        if not IsValid(ply) then return end
        players_location[ply:SteamID64()] = nil
    end)

    hook.Add("OnDisableLifeSupportSectionCreated", "LifeSupport.Core.DisableSection", function(ent)
        if not ent or ent.Deck == nil or ent.Section == nil then return end
        disabled_sections[ent.Deck] = disabled_sections[ent.Deck] or {}
        table.insert(disabled_sections[ent.Deck], ent.Section)
    end)

    hook.Add("OnDisableLifeSupportSectionRemoved", "LifeSupport.Core.EnableSection", function(ent)
        if not ent or ent.Deck == nil or ent.Section == nil then return end
        if disabled_sections[ent.Deck] then
            table.RemoveByValue(disabled_sections[ent.Deck], ent.Section)
        end
    end)

    hook.Add("OnDisableLifeSupportDeckCreated", "LifeSupport.Core.DisableDeck", function(ent)
        if not ent or ent.Deck == nil then return end
        table.insert(disabled_decks, ent.Deck)
    end)

    hook.Add("OnDisableLifeSupportDeckRemoved", "LifeSupport.Core.EnableDeck", function(ent)
        if not ent or ent.Deck == nil then return end
        table.RemoveByValue(disabled_decks, ent.Deck)
    end)

    local function spawnSparks(ent)
        if not IsValid(ent) then return end
        local ed = EffectData()
        ed:SetOrigin(ent:WorldSpaceCenter())
        ed:SetMagnitude(1)
        ed:SetScale(1)
        util.Effect("Sparks", ed, true, true)
        ent:EmitSound("star_trek.lcars_error", 60, 120, 0.4, CHAN_ITEM)
    end

    function ENT:RemoveRepairPanel()
        if IsValid(self.RepairPanel) then
            self.RepairPanel:Remove()
            self.RepairPanel = nil
        end
    end

    function ENT:SpawnRepairPanel()
        if not (Star_Trek and Star_Trek.Button) then return end
        self:RemoveRepairPanel()

        local worldPos = self:LocalToWorld(REPAIR_PANEL_OFFSET)
        local worldAng = self:LocalToWorldAngles(REPAIR_PANEL_ANGLE)
        local success, button = Star_Trek.Button:CreateButton(worldPos, worldAng, REPAIR_PANEL_MODEL, function(panelEnt, ply)
            if not IsValid(self) then return end
            if not (Star_Trek and Star_Trek.LCARS) then return end

            local trigger = IsValid(self.RepairPanel) and self.RepairPanel or panelEnt
            if not IsValid(trigger) then
                trigger = self
            end
            local success2, err = Star_Trek.LCARS:OpenInterface(ply, trigger, "life_support_core", self)
            if not success2 and Star_Trek and Star_Trek.Life_Support_Panel and Star_Trek.Life_Support_Panel.Debug then
                print(string.format("[LifeSupportCore] Failed to open via repair panel: %s", tostring(err)))
            end
        end, true)
        if not success then
            if Star_Trek and Star_Trek.Life_Support_Panel and Star_Trek.Life_Support_Panel.Debug then
                print(string.format("[LifeSupportCore] Failed to create repair interface button: %s", tostring(button)))
            end
            return
        end

        if not IsValid(button) then return end
        button:SetParent(self)
        button:SetLocalPos(REPAIR_PANEL_OFFSET)
        button:SetLocalAngles(REPAIR_PANEL_ANGLE)
        button:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
        button:SetName(string.format("life_support_core_button_%d", self:EntIndex()))
        button.StarTrekRepairPanel = true
        button:SetSkin(0)
        self.RepairPanel = button
    end

    function ENT:SetBackupDeadline(deadline)
        if deadline == nil then
            if self.BackupEndTime then
                self.BackupEndTime = nil
                self.BackupExpired = nil
                hook.Run("OnLifeSupportBackupCleared", self)
            end
            return
        end

        if not isnumber(deadline) then return end

        if deadline < CurTime() then
            deadline = CurTime()
        end

        self.BackupEndTime = deadline
        self.BackupExpired = false
        hook.Run("OnLifeSupportBackupUpdated", self, deadline)
    end

    function ENT:ExtendBackup(duration)
        if not isnumber(duration) or duration <= 0 then return end
        self:SetBackupDeadline(CurTime() + duration)
    end

    function ENT:GetBackupTimeRemaining()
        if not self.BackupEndTime then return 0 end
        return math.max(0, self.BackupEndTime - CurTime())
    end

    function ENT:Initialize()
        local removalClasses = {"prop_physics", "prop_dynamic", "prop_dynamic_override", "prop_static"}
        for _, class in ipairs(removalClasses) do
            for _, prop in ipairs(ents.FindByClass(class)) do
                if not IsValid(prop) then continue end
                if prop:GetModel() ~= self.Model then continue end
                if prop:GetPos():DistToSqr(self:GetPos()) > 16 * 16 then continue end
                prop:Remove()
            end
        end

		self:RefreshAlertModes()
		self:UpdateAlertIndicator()

        self:SetModel(self.Model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_NONE)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:EnableMotion(false)
        end

        local maxhp = self:GetLifeSupportMaxHealth()
        self:SetCoreHealthValue(maxhp)
        self:SetHealth(maxhp)
        self:SetMaxHealth(maxhp)

        self.Working = true
        self.DestroyedBroadcast = false
        self.OverrideState = nil
        self._autoForcedOffline = nil
        self._preFailureOverrideState = nil
        self._nextSpark = 0
        self._nextShockSound = 0
        self.AlertTriggered = false
        self.BackupEndTime = nil
        self.BackupExpired = false

        self:SpawnRepairPanel()

        if StarTrekEntities and StarTrekEntities.LifeSupport then
            StarTrekEntities.LifeSupport:SetCore(self)
        end

        hook.Run("OnLifeSupportCreated", self)
        self:UpdateScannerData()
        self:NextThink(CurTime() + 0.1)
    end

    function ENT:GetHealthPercent()
        local maxhp = self:GetLifeSupportMaxHealth()
        if maxhp <= 0 then return 0 end
        return math.max(0, math.floor((self:GetLifeSupportHealth() / maxhp) * 100))
    end

    function ENT:Use(activator)
        -- Core no longer hosts an LCARS interface directly.
    end

    function ENT:IsOperational()
        if self.OverrideState == false then
            return false
        end
        return self:GetLifeSupportHealth() > 0
    end

    function ENT:SetManualOverride(state)
        if state == nil then
            self.OverrideState = nil
        else
            self.OverrideState = state and true or false
        end
        self:NotifyStatusChanged()
    end

    function ENT:NotifyStatusChanged()
        if StarTrekEntities and StarTrekEntities.LifeSupport then
            StarTrekEntities.LifeSupport:SetCore(self)
        end
    end

    function ENT:TriggerCriticalAlert()
        if self.AlertTriggered then return end
        self.AlertTriggered = true

        for i = 0, ALERT_REPEAT - 1 do
            timer.Simple(i * ALERT_INTERVAL, function()
                sound.Play(ALERT_SOUND, ALERT_POSITION, 80, 100, 1)
            end)
        end

        if Star_Trek and Star_Trek.Life_Support_Panel and Star_Trek.Life_Support_Panel.OnCriticalDamage then
            Star_Trek.Life_Support_Panel:OnCriticalDamage(self)
        end
    end

    function ENT:ClearCriticalAlert()
        self.AlertTriggered = false
    end

    function ENT:UpdateScannerData()
        local health = self:GetLifeSupportHealth()
        local maxHealth = self:GetLifeSupportMaxHealth()
        local status = (health > 0 and self.OverrideState ~= false) and "Active" or "Offline"

        local message
        if health <= 0 then
            message = "Core integrity failure. System offline."
        elseif health <= maxHealth * 0.25 then
            message = "Critical integrity. Immediate repairs required."
        elseif health <= maxHealth * 0.5 then
            message = "Warning: Core integrity below 50%."
        elseif health <= maxHealth * 0.75 then
            message = "Integrity reduced. Monitor closely."
        else
            message = "Environmental systems nominal."
        end

        self.ScannerData = string.format("Status: %s\n%s\n", status, message)
    end

    function ENT:OnTakeDamage(dmg)
        if not IsValid(self) then return end
        self:TakePhysicsDamage(dmg)

        local amount = dmg:GetDamage() or 0
        if amount <= 0 then return end

        local current = self:GetLifeSupportHealth()
        if current <= 0 then return end

        local newhp = math.max(0, current - amount)
        self:SetCoreHealthValue(newhp)
        self.last_hit_location = dmg:GetDamagePosition()

        self:OnLifeSupportHealthEdited(current, newhp)
        hook.Run("OnLifeSupportDamage", self, dmg)

        if newhp <= 0 and current > 0 then
            local boom = ents.Create("env_explosion")
            if IsValid(boom) then
                boom:SetKeyValue("spawnflags", 16)
                boom:SetKeyValue("iMagnitude", 15)
                boom:SetKeyValue("iRadiusOverride", 256)
                boom:SetPos(self:GetPos())
                boom:Spawn()
                boom:Fire("explode", "", 0)
            end

            self:Ignite(20, 250)
        end
    end

    function ENT:RepairAmount(amount)
        amount = tonumber(amount) or 0
        if amount <= 0 then return end

        local maxhp = self:GetLifeSupportMaxHealth()
        local current = self:GetLifeSupportHealth()
        local newhp = math.Clamp(current + amount, 0, maxhp)
        if newhp == current then return end

        self:SetPlayerRepairing(true)
        self:SetCoreHealthValue(newhp)
        self:OnLifeSupportHealthEdited(current, newhp)
    end

    function ENT:DoDamage(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        local movement = ply:GetMoveType()
        if movement == MOVETYPE_NOCLIP or movement == MOVETYPE_OBSERVER then return end

        local dmg = DamageInfo()
        dmg:SetDamage(self:GetDamageAmount())
        dmg:SetDamageType(DMG_RADIATION)
        dmg:SetAttacker(self)
        dmg:SetInflictor(self)
        ply:TakeDamageInfo(dmg)
    end

    function ENT:DoOxygenDamage(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end

        local ignoreDamage, overwrite = hook.Run("ShouldIgnoreLifeSupportDamage", ply, players_location[ply:SteamID64()] or {})
        if ignoreDamage then
            if overwrite == false then
                if self:IsOperational() then return end
            else
                return
            end
        end

        local dmg = DamageInfo()
        dmg:SetDamage(self:GetDamageAmount())
        dmg:SetDamageType(DMG_DROWN)
        dmg:SetAttacker(self)
        dmg:SetInflictor(self)
        ply:TakeDamageInfo(dmg)
    end

    function ENT:ThinkOxygen()
        local now = CurTime()
        self._nextDamageTick = self._nextDamageTick or 0

        if self.BackupEndTime then
            if now < self.BackupEndTime then
                self._nextDamageTick = now + 1
                return
            elseif not self.BackupExpired and now >= self.BackupEndTime then
                self.BackupExpired = true
                hook.Run("OnLifeSupportBackupExpired", self)
                self.BackupEndTime = nil
            end
        end

        if now < self._nextDamageTick then return end
        self._nextDamageTick = now + math.max(1, self:GetDamageSeconds())

        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:Alive() then continue end

            local sid = ply:SteamID64()
            local location = players_location[sid] or {}
            local deck, sectionId = location[1], location[2]

            local shouldDamage = false
            if deck == nil or sectionId == nil then
                shouldDamage = false
            elseif table.HasValue(disabled_decks, deck) then
                shouldDamage = true
            elseif table.HasValue(disabled_sections[deck] or {}, sectionId) then
                shouldDamage = true
            elseif not self:IsOperational() then
                shouldDamage = true
            end

            if shouldDamage then
                self:DoOxygenDamage(ply)
            end
        end
    end

    function ENT:Think()
        local maxhp = self:GetLifeSupportMaxHealth()
        local hp = self:GetLifeSupportHealth()

        if maxhp > 0 and hp < (0.5 * maxhp) then
            if CurTime() >= (self._nextSpark or 0) then
                spawnSparks(self)
                self._nextSpark = CurTime() + math.Rand(0.6, 1.5)
            end

            if CurTime() >= (self._nextShockSound or 0) then
                self._nextShockSound = CurTime() + math.Clamp(60 * (hp / maxhp), 5, 60)
                self:EmitSound("ambient/levels/labs/electric_explosion1.wav", 75, 100, 0.5)
            end

            if (not self.ShockEnt) or (not IsValid(self.ShockEnt)) then
                local shock = ents.Create("pfx4_05~")
                if IsValid(shock) then
                    shock:SetPos(self:GetPos())
                    shock:SetAngles(self:GetAngles())
                    shock:SetParent(self)
                    shock:Spawn()
                    self.ShockEnt = shock
                end
            end
        elseif IsValid(self.ShockEnt) then
            self.ShockEnt:Remove()
            self.ShockEnt = nil
        end

        if self:GetPlayerRepairing() and hp >= maxhp then
            self:SetPlayerRepairing(false)
        end

        self:ThinkOxygen()
        self:NextThink(CurTime() + 0.1)
        return true
    end

    function ENT:OnRemove()
        timer.Remove("LifeSupportCoreInterface_" .. self:EntIndex())
        self:RemoveRepairPanel()
        if IsValid(self.ShockEnt) then
            self.ShockEnt:Remove()
            self.ShockEnt = nil
        end
        if self.BackupEndTime then
            self:SetBackupDeadline(nil)
        end
        hook.Run("OnLifeSupportRemoved", self)
        if StarTrekEntities and StarTrekEntities.LifeSupport and StarTrekEntities.LifeSupport:GetCore() == self then
            StarTrekEntities.LifeSupport:SetCore(nil)
        end
    end

end -- SERVER

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end

scripted_ents.Register(ENT, "life_support_core")
