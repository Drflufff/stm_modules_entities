AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

local disabled_sections = {}
local disabled_decks = {}

local players_location = {}
hook.Add( "Star_Trek.Sections.LocationChanged", "LifeSupport.LocationChanged", function(ply, old_deck, old_sectionId, new_deck, new_sectionId)
	players_location[ply:SteamID64()] = {new_deck, new_sectionId}
end)

hook.Add( "OnDisableLifeSupportSectionCreated", "DisabledSections.Created", function(ent)
	disabled_sections[ent.Deck] = disabled_sections[ent.Deck] or {}
	table.insert(disabled_sections[ent.Deck], ent.Section)
end)

hook.Add( "OnDisableLifeSupportSectionRemoved", "DisabledSections.Removed", function(ent)
	table.RemoveByValue(disabled_sections[ent.Deck], ent.Section)
end)

hook.Add( "OnDisableLifeSupportDeckCreated", "DisabledDecks.Created", function(ent)
	print( "OnDisableLifeSupportDeckCreated: " .. ent.Deck )
	table.insert(disabled_decks, ent.Deck)
end)

hook.Add( "OnDisableLifeSupportDeckRemoved", "DisabledDecks.Removed", function(ent)
	print( "OnDisableLifeSupportDeckRemoved: " .. ent.Deck )
	table.RemoveByValue(disabled_decks, ent.Deck)
end)

function ENT:Initialize()
	self:SetModel( "models/props/atmospherecontrol.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetPos( self:GetPos() ) -- This spawns underground in some maps so set to 100 then DropToFloor().
	self:SetHealth( 500 )
	self:SetMaxHealth( 500 )
	self:SetUseType( SIMPLE_USE )

	-- We can improve this later. Let's first make sure the system works!
	-- TODO: Do something else. Perhaps a hook so gamemode can notify in it's own way?
	if table.Count( ents.FindByClass( "lifesupport" ) ) ~= 1 then
		for k, v in player.Iterator() do
			if not IsValid( v ) then continue end
			if v:IsAdmin() then
				v:ChatPrint( "Another life support system already exists. Please remove it before placing a new one." )
			end
		end
		self:Remove()
		return
	end

	local SuppPhys = self:GetPhysicsObject()
	if IsValid( SuppPhys ) then
		SuppPhys:Wake()
	end

	hook.Run( "OnLifeSupportCreated", self )

	self.Working = true

	self:UpdateScannerData()

	for k, v in player.Iterator() do
		local success, deck, section = Star_Trek.Sections:DetermineSection( self:GetPos() )
		if success then
			players_location[v:SteamID64()] = {deck, section}
		end
	end

	for k, v in ipairs(ents.FindByClass("disablelifesupport_deck")) do
		table.insert(disabled_decks, v.Deck)
	end
	for k, v in ipairs(ents.FindByClass("disablelifesupport_section")) do
		disabled_sections[v.Deck] = disabled_sections[v.Deck] or {}
		table.insert(disabled_sections[v.Deck], v.Section)
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
	local CheckString = string.EndsWith( self:GetLifeModel(), ".mdl" )
	if CheckString then
		self:SetModel( self:GetLifeModel() )
	end
	self:PhysicsInit( SOLID_VPHYSICS ) -- Redo physics since the model was changed...I guess.

	self:Freeze( false )
end

function ENT:OnTakeDamage( dmg )
	self:TakePhysicsDamage( dmg )
	if ( self:Health() <= 0 ) then return end
	self:SetHealth( math.Clamp( self:Health() - dmg:GetDamage(), 0, self:GetMaxHealth() ) )
	self.last_hit_location = dmg:GetDamagePosition()
	self:UpdateScannerData()

	hook.Run( "OnLifeSupportDamage", self, dmg )

	if ( self:Health() <= 0 ) then

		local BoomBoom2 = ents.Create( "env_explosion" )
		BoomBoom2:SetKeyValue( "spawnflags", 144 )
		BoomBoom2:SetKeyValue( "iMagnitude", 15 )
		BoomBoom2:SetKeyValue( "iRadiusOverride", 256 )
		BoomBoom2:SetPos( self:GetPos() )
		BoomBoom2:Spawn()
		BoomBoom2:Fire( "explode", "", 0 )

		PrintMessage( HUD_PRINTCENTER, "Life Support System has been destroyed!" )

		self:Ignite( 20, 250 )

		self.Working = false

		hook.Run( "OnLifeSupportDestroyed", self )
	end
end

function ENT:UpdateScannerData()
	local health = self:Health()
	local maxHealth = self:GetMaxHealth()

	local status = health > 0 and "Active" or "Destroyed"

	local fun_message = ""
	if health <= 0 then
		fun_message = "System is offline. Please repair."
	elseif health <= maxHealth * 0.25 then
		fun_message = "Warning: System health is critically low! Failure imminent!"
	elseif health <= maxHealth * 0.5 then
		fun_message = "Caution: System health is below 50%. Consider repairs."
	elseif health <= maxHealth * 0.75 then
		fun_message = "System health is below 75%. Monitor closely."
	else
		fun_message = "System is operational."
	end

	self.ScannerData = "Status: " .. status .. "\n" .. fun_message .. "\n"

end

local last_shock_time = 0
function ENT:DoDamage(ply)
	if not IsValid( ply ) then return end
	if not ply:IsPlayer() then return end

	-- ENT, ply, section, deck
	local should_damage = hook.Run( "ShouldIgnoreLifeSupportDamagePlayer", self, ply, nil, nil )
	if should_damage == true then return end

	local pMovement = ply:GetMoveType()
	if pMovement == MOVETYPE_NOCLIP or pMovement == MOVETYPE_OBSERVER then return end

	local dmg = DamageInfo()
	dmg:SetDamage( self:GetDamageAmount() )
	dmg:SetDamageType( DMG_RADIATION )
	dmg:SetAttacker( self )
	dmg:SetInflictor( self )

	ply:TakeDamageInfo( dmg )
end

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

	self:ThinkOxygen()

	if self:GetPlayerRepairing() then
		if not self.Working then
			hook.Run( "OnLifeSupportRepaired", self )
			self.Working = true
		end
		self:SetPlayerRepairing( false )
	end

end

function ENT:OnRemove()
	hook.Run( "OnLifeSupportRemoved", self )
end


function ENT:DoOxygenDamage(ply)
	local ignoreDamage, overwriteLifeSupport = hook.Run("ShouldIgnoreLifeSupportDamage", ply, players_location[ply:SteamID64()] or {})
	
	-- If the hook wants to handle damage itself, respect that decision
	if ignoreDamage then
		-- If overwriteLifeSupport is explicitly false, check if life support is working
		-- and allow damage if it's not working
		if overwriteLifeSupport == false then
			ignoreDamage = self:Health() > 0 -- If life support is working, ignore damage
		end
	end
	
	-- If we should ignore damage, return early
	if ignoreDamage == true then 
		return 
	end

	-- Deal oxygen deprivation damage
	local dmg = DamageInfo()
	dmg:SetDamage( self:GetDamageAmount() )
	dmg:SetDamageType( DMG_DROWN )
	dmg:SetAttacker( self )
	dmg:SetInflictor( self )

	ply:TakeDamageInfo( dmg )
end

local last_damage_time = 0
function ENT:ThinkOxygen()
	-- Rate limiting: don't damage too frequently
	if last_damage_time + self:GetDamageSeconds() > CurTime() then
		return
	end
	last_damage_time = CurTime()

	-- Check each player for oxygen deprivation conditions
	for i, ply in player.Iterator() do
		if not IsValid(ply) or not ply:Alive() then
			continue
		end

		local steamId = ply:SteamID64()
		local playerLocation = players_location[steamId] or {}
		local deck, sectionId = unpack(playerLocation)

		-- Check various conditions that would cause oxygen damage
		local shouldTakeDamage = false

		-- Is the player outside the ship (no location data)?
		if deck == nil or sectionId == nil then
			shouldTakeDamage = true
		-- Is the player in a disabled deck?
		elseif table.HasValue(disabled_decks, deck) then
			shouldTakeDamage = true
		-- Is the player in a disabled section?
		elseif table.HasValue(disabled_sections[deck] or {}, sectionId) then
			shouldTakeDamage = true
		-- Is the life support system destroyed?
		elseif self:Health() <= 0 then
			shouldTakeDamage = true
		end
		
		-- Apply oxygen damage if any condition is met
		if shouldTakeDamage then
			self:DoOxygenDamage(ply)
		end
	end
end
