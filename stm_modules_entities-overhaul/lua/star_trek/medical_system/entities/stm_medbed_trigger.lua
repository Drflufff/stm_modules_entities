AddCSLuaFile()

local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Medical Bed Trigger"
ENT.RenderGroup = RENDERGROUP_NONE
ENT.Spawnable = false
ENT.AdminSpawnable = false

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/hunter/blocks/cube025x2x025.mdl")
        self:SetNoDraw(true)
        self:DrawShadow(false)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:SetTrigger(true)

        local radius = self.Radius or 80
        local height = self.Height or 72
        self:SetCollisionBounds(Vector(-radius, -radius, 0), Vector(radius, radius, height))

        self.NextThinkTime = CurTime() + 0.25
        self.Cooldowns = {}
    end

    function ENT:Setup(bedId, radius, height)
        self.BedId = bedId
        self.Radius = radius or 80
        self.Height = height or 72
        self:SetCollisionBounds(Vector(-self.Radius, -self.Radius, 0), Vector(self.Radius, self.Radius, self.Height))
    end

    local function isValidPatient(ent)
        return IsValid(ent) and ent:IsPlayer() and ent:Alive()
    end

    local function handleContact(self, ply)
        if not isValidPatient(ply) then
            return
        end

        if not (Star_Trek and Star_Trek.Medical and self.BedId) then
            return
        end

        Star_Trek.Medical:HandleBedContact(self.BedId, ply)
    end

    function ENT:StartTouch(ent)
        handleContact(self, ent)
    end

    function ENT:Think()
        if CurTime() < (self.NextThinkTime or 0) then
            return
        end

        self.NextThinkTime = CurTime() + 0.2

        if not (Star_Trek and Star_Trek.Medical and self.BedId) then
            return true
        end

        local bed = Star_Trek.Medical.Beds and Star_Trek.Medical.Beds[self.BedId]
        if not istable(bed) then
            return true
        end

        local radius = self.Radius or 80
        local radiusSqr = radius * radius
        local origin = self:GetPos()
        local height = self.Height or 72

        for _, ply in ipairs(player.GetAll()) do
            if isValidPatient(ply) then
                local pos = ply:GetPos()
                local delta = pos - origin
                if delta.z >= -24 and delta.z <= height then
                    if delta.x * delta.x + delta.y * delta.y <= radiusSqr then
                        local nextAllowed = self.Cooldowns[ply] or 0
                        if CurTime() >= nextAllowed then
                            self.Cooldowns[ply] = CurTime() + 1
                            handleContact(self, ply)
                        end
                    end
                else
                    local vehicle = ply:GetVehicle()
                    if IsValid(vehicle) and vehicle:GetClass() == "prop_vehicle_prisoner_pod" then
                        local podPos = vehicle:GetPos()
                        local podDelta = podPos - origin
                        if podDelta.z >= -24 and podDelta.z <= height then
                            if podDelta.x * podDelta.x + podDelta.y * podDelta.y <= radiusSqr then
                                local nextAllowed = self.Cooldowns[ply] or 0
                                if CurTime() >= nextAllowed then
                                    self.Cooldowns[ply] = CurTime() + 1
                                    handleContact(self, ply)
                                end
                            end
                        end
                    end
                end
            end
        end

        return true
    end
else
    function ENT:Initialize()
        self:SetNoDraw(true)
    end
end

function ENT:Draw()
    -- keep invisible client-side
end

scripted_ents.Register(ENT, "stm_medbed_trigger")
