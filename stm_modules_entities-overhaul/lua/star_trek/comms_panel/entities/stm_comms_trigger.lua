AddCSLuaFile()

local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Comms Panel Trigger"
ENT.RenderGroup = RENDERGROUP_NONE

function ENT:Initialize()
    print("[CommsTrigger] Initialize called", self)
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self:SetTrigger(true)

    self.Mins = self.Mins or Vector(-120, -120, -40)
    self.Maxs = self.Maxs or Vector(120, 120, 80)
    self:SetCollisionBounds(self.Mins, self.Maxs)

    self.Initialized = true
    self.Range = 110
    self.OpenCooldowns = {}
    self:NextThink(CurTime() + 0.1)
end

function ENT:SetRange(radius)
    print(string.format("[CommsTrigger] Range set to %s", tostring(radius)))
    self.Range = radius
end

function ENT:Think()
    if not self.Initialized then return end

    if not (Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.Button and Star_Trek.LCARS) then
        print("[CommsTrigger] Panel or LCARS missing, deferring")
        self:NextThink(CurTime() + 1)
        return true
    end

    if Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.AutoOpenTrigger == false then
        print("[CommsTrigger] Auto-open disabled via config")
        self:NextThink(CurTime() + 1)
        return true
    end

    local rangeSqr = (self.Range or 110) ^ 2
    self.OpenCooldowns = self.OpenCooldowns or {}
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then
            continue
        end

        local pos = ply:GetPos()
        local distSqr = self:GetPos():DistToSqr(pos)
        if distSqr <= rangeSqr then
            local onBridge
            if Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.IsOnBridge then
                onBridge = Star_Trek.Comms_Panel:IsOnBridge(ply)
            else
                onBridge = false
            end
            if not onBridge then
                continue
            end

            local nextAllowed = self.OpenCooldowns[ply] or 0
            if CurTime() < nextAllowed then
                continue
            end

            local success = false
            local err
            if Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.TryOpenInterface then
                success, err = Star_Trek.Comms_Panel:TryOpenInterface(ply, "trigger")
            end

            if success then
                self.OpenCooldowns[ply] = CurTime() + 2
            elseif Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.Debug then
                print(string.format("[CommsTrigger] Trigger failed to open for %s: %s", ply:Nick(), tostring(err or "unknown error")))
            end
        end
    end

    self:NextThink(CurTime() + 0.2)
    return true
end

scripted_ents.Register(ENT, "stm_comms_trigger")

