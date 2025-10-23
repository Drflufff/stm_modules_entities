AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

function ENT:Initialize()
	self:SetModel( "models/props/computerconsole_grey.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetHealth( 500 )
	self:SetMaxHealth( 500 )
	self:SetUseType( SIMPLE_USE )

	local CommPhys = self:GetPhysicsObject()
	if IsValid( CommPhys ) then
		CommPhys:Wake()
	end
	self.AuxCommunications = false

	local ent_count = #ents.FindByClass( self:GetClass() )
	if ent_count > 1 then
		self:Remove()
		print( "Too many Communications Arrays! Please remove some before spawning more." )
        for _, ply in pairs(player.GetAll()) do
            if ply:IsAdmin() then
                ply:ChatPrint("Too many Communications Arrays! Please remove some before spawning more.")
            end
        end
		return
	end

	hook.Run( "CommunicationsArrayInitialized", self )
end

function ENT:CanProperty(ply, property)
	if !ply:IsAdmin() && property == "editentity" then
		return false
	end
end

function ENT:Use( ply )
	if !IsValid( ply ) then return end
	if !ply:IsPlayer() then return end
	if !ply:IsAdmin() then return end
	local CheckString = string.EndsWith( self:GetCommsModel(), ".mdl" )
	self:SetHealth( self:GetCommsHealth() )
	self:SetMaxHealth( self:GetCommsHealth() )
	if CheckString then
		self:SetModel( self:GetCommsModel() )
	end
	self:PhysicsInit( SOLID_VPHYSICS ) -- Redo physics since the model was changed...I guess.
end

local function map(cur_val, cur_min, cur_max, new_min, new_max)
	return (cur_val - cur_min) / (cur_max - cur_min) * (new_max - new_min) + new_min
end

function ENT:OnTakeDamage( dmg )
	self:TakePhysicsDamage( dmg )
	if ( self:Health() <= 0 ) then return end
	self:SetHealth( math.Clamp( self:Health() - dmg:GetDamage(), 0, self:GetMaxHealth() ) )

	local hp = self:Health()
	local max_hp = self:GetMaxHealth()
	local damage_percent = (max_hp - hp) / max_hp * 100

	hook.Run( "CommunicationsArrayDamaged", self, dmg, math.floor(map(damage_percent, 0, 100, 0, 7)) )

	if self:Health() <= 0 then
		local BigExplosion = ents.Create( "env_explosion" )
		BigExplosion:SetKeyValue( "spawnflags", 144 )
		BigExplosion:SetKeyValue( "iMagnitude", 15 )
		BigExplosion:SetKeyValue( "iRadiusOverride", 256 )
		BigExplosion:SetPos( self:GetPos() )
		BigExplosion:Spawn()
		BigExplosion:Fire( "explode", "", 0 )

		PrintMessage( HUD_PRINTCENTER, "Communications Array has been destroyed!" )

		self:Ignite( 20, 250 )
		hook.Run( "CommunicationsArrayDestroyed", self )
		self:SetPlayerRepairing( false )
	end
end

function ENT:OnRemove()
	hook.Run( "CommunicationsArrayRemoved", self )
end

function ENT:Think()
	if self:GetPlayerRepairing() then
		-- Handle player repairing logic
		self:SetPlayerRepairing( false )
		local hp = self:Health()
		local max_hp = self:GetMaxHealth()
		local damage_percent = (max_hp - hp) / max_hp * 100

		local intensity = math.floor(map(damage_percent, 0, 100, 0, 7))

		hook.Run( "CommunicationsArrayRepairing", self, intensity )
	end
	self:NextThink( CurTime() + 0.1 )
	return true
end