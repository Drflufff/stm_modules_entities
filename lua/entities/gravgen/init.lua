
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

local disabled_gravity = {} -- Table to keep track of disabled gravity generators
-- Format:
    -- disabled_gravity[deck] = {entire_deck = true/false, sections = {[section1] = true, [section2] = true, ...}}
local pLocators = {}
hook.Add( "Star_Trek.Sections.LocationChanged", "GravGen.LocationChanged", function(ply, old_deck, old_sectionId, new_deck, new_sectionId)
    pLocators[ply:SteamID64()] = {deck = new_deck, section = new_sectionId}
end)

hook.Add( "OnDisableGravitySectionCreated", "GravGen.OnDisableGravitySectionCreated", function(ent)
    local deck = ent.Deck
    if not disabled_gravity[deck] then
        disabled_gravity[deck] = {entire_deck = false, sections = {}}
    end
    disabled_gravity[deck].sections[ent.Section] = true
end)
hook.Add( "OnDisableGravitySectionRemoved", "GravGen.OnDisableGravitySectionRemoved", function(ent)
    local deck = ent.Deck
    if not disabled_gravity[deck] then return end
    disabled_gravity[deck].sections[ent.Section] = nil
    if table.IsEmpty(disabled_gravity[deck].sections) then
        disabled_gravity[deck] = nil
    end
end)

hook.Add( "OnDisableGravityDeckCreated", "GravGen.OnDisableGravityDeckCreated", function(ent)
    local deck = ent.Deck
    if not disabled_gravity[deck] then
        disabled_gravity[deck] = {entire_deck = true, sections = {}}
    end
    disabled_gravity[deck].entire_deck = true
end)
hook.Add( "OnDisableGravityDeckRemoved", "GravGen.OnDisableGravityDeckRemoved", function(ent)
    local deck = ent.Deck
    if not disabled_gravity[deck] then return end
    disabled_gravity[deck].entire_deck = false
    if table.IsEmpty(disabled_gravity[deck].sections) then
        disabled_gravity[deck] = nil
    end
end)

function ENT:Initialize()
	self:SetModel( "models/props/console_control_round.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetMaxHealth( 500 )
	self:SetHealth( 500 )
	self:SetUseType( SIMPLE_USE )

	local GenPhys = self:GetPhysicsObject()
	if IsValid( GenPhys ) then
		GenPhys:Wake()
	end

    local ent_count = #ents.FindByClass( self:GetClass() )
    if ent_count > 1 then
        self:Remove()
        print( "Too many Gravity Generators! Please remove some before spawning more." )
        for _, ply in pairs(player.GetAll()) do
            if ply:IsAdmin() then
                ply:ChatPrint("Too many Gravity Generators! Please remove some before spawning more.")
            end
        end
        return
    end
    hook.Run( "OnGravGenInitialized", self )
    self.Working = true
    self:SetPlayerRepairing(false)

    for _, ply in player.Iterator() do
        local success, deck, section = Star_Trek.Sections:DetermineSection( self:GetPos() )
		if success then
			pLocators[ply:SteamID64()] = {deck = deck, section = section}
		end
        self:ApplyGravity(ply, success)
    end

    for k, v in ipairs(ents.FindByClass("disablegravity_*")) do
        if v.Deck == self.Deck then
            disabled_gravity[v.Deck] = disabled_gravity[v.Deck] or {entire_deck = false, sections = {}}
            if v.Section then
                disabled_gravity[v.Deck].sections[v.Section] = true
            else
                disabled_gravity[v.Deck].entire_deck = true
            end
        end
    end
end

function ENT:CanProperty(ply, property)
	if !ply:IsAdmin() && property == "editentity" then
		return false
	end
end
function ENT:CanTool(ply, tool)
	if tool == "permaprops" then
		return false
	end
end

function ENT:Use( ply )
	if !IsValid( ply ) then return end
	if !ply:IsPlayer() then return end
	if !ply:IsAdmin() then return end
	local CheckString = string.EndsWith( self:GetGravModel(), ".mdl" )
	self:SetHealth( self:GetGravHealth() )
	self:SetMaxHealth( self:GetGravHealth() )
	if CheckString then
		self:SetModel( self:GetGravModel() )
	end
	self:PhysicsInit( SOLID_VPHYSICS ) -- Redo physics since the model was changed...I guess.
end

function ENT:OnTakeDamage( dmg )
	self:TakePhysicsDamage( dmg )
    if ( self:Health() <= 0 ) then return end

    self:SetHealth( math.Clamp( self:Health() - dmg:GetDamage(), 0, self:GetMaxHealth() ) )
    hook.Run( "OnGravGenDamaged", self, dmg )

    if ( self:Health() <= 0 ) then
		local BoomBoom = ents.Create( "env_explosion" )
		BoomBoom:SetKeyValue( "spawnflags", 144 )
		BoomBoom:SetKeyValue( "iMagnitude", 15 )
		BoomBoom:SetKeyValue( "iRadiusOverride", 256 )
		BoomBoom:SetPos( self:GetPos() )
		BoomBoom:Spawn()
		BoomBoom:Fire( "explode", "", 0 )
		PrintMessage( HUD_PRINTCENTER, "Gravity Generator has been destroyed!" )
		self:Ignite( 10, 250 )
        self.Working = false
	end
end

local last_shock_time = 0
function ENT:Think()
    local health = self:Health()
	local maxHealth = self:GetMaxHealth()
	if health >= maxHealth then
		if self.ShockEnt and IsValid( self.ShockEnt ) then
			self.ShockEnt:Remove()
			self.ShockEnt = nil
		end
	else
		local hp_percent = health / maxHealth
		local time_interval = 60 * ( hp_percent ) -- Calculate time interval based on health percentage

		time_interval = math.Clamp( time_interval, 5, 60 ) -- Ensure the interval is between 5 and 60 seconds

		if last_shock_time + time_interval < CurTime() then
			last_shock_time = CurTime()
			self:EmitSound( "ambient/levels/labs/electric_explosion1.wav", 75, 100, 0.5 )
		end
		if not self.ShockEnt or not IsValid( self.ShockEnt ) then
			local shockEnt = ents.Create( "pfx4_05~" )
			shockEnt:SetPos( self:GetPos() )
			shockEnt:SetAngles( self:GetAngles() )
			shockEnt:SetParent( self )
			shockEnt:Spawn()
			self.ShockEnt = shockEnt
		end
	end

    self:ThinkGravity()

	if self:GetPlayerRepairing() then
        if not self.Working then
            hook.Run( "OnGravGenRepaired", self )
            self.Working = true
        end
		self:SetPlayerRepairing( false )
	end
end

function ENT:OnRemove()
    for k, v in player.Iterator() do
        self:ApplyGravity(v, false) -- Reset gravity for all players
    end
end

function ENT:ApplyGravity(ply, remove_grav)
    if not IsValid(ply) or ply == self then return end

    local pLocator = pLocators[ply:SteamID64()] or {}
    local ShouldIgnore, OverWrite = hook.Run("ShouldIgnoreGravity", ply, {pLocator.deck, pLocator.section})
    if ShouldIgnore then
        if OverWrite ~= false then
            remove_grav = self:Health() > 0
        else
            remove_grav = false
        end
    end

    if not remove_grav then
        ply:SetGravity(1)
        ply:SetFriction(1)
        return
    end
    -- Apply gravity to players (?)
    ply:SetGravity(1 / 6) -- 600 -> 100 -- 1/6th of the normal gravity?
    ply:SetFriction(1 / 8) -- 8 -> 1 -- 1/8th of the normal friction?
end

function ENT:ThinkGravity()
    for k, v in player.Iterator() do
        local pLocator = pLocators[v:SteamID64()] or {}
        local deck = pLocator.deck or nil
        local section = pLocator.section or nil

        local should_remove_grav = false
        -- Not in the ship, remove grav!!!!!!!!!!
        if deck == nil or section == nil then
            should_remove_grav = true
        else
            local grav_data = disabled_gravity[deck] or {}
            if grav_data.entire_deck then
                -- Deck's gravity is disabled
                should_remove_grav = true
            elseif grav_data.sections and grav_data.sections[section] then
                -- Section's gravity is disabled
                should_remove_grav = true
            end
        end

        if self:Health() <= 0 or not self.Working then
            should_remove_grav = true
        end

        self:ApplyGravity(v, should_remove_grav)
    end
end
