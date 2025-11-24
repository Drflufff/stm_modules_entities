--   Comms Panel | Index             --
---------------------------------------

Star_Trek:RequireModules("button", "lcars")

Star_Trek.Comms_Panel = Star_Trek.Comms_Panel or {}
if Star_Trek.Comms_Panel.AutoOpenTrigger == nil then
	Star_Trek.Comms_Panel.AutoOpenTrigger = true
end
if Star_Trek.Comms_Panel.Debug == nil then
	Star_Trek.Comms_Panel.Debug = true
end

if CLIENT then
	return
end

if game.GetMap() ~= "rp_intrepid_v1" then return end

include("star_trek/comms_panel/entities/comms_repair.lua")
include("star_trek/comms_panel/entities/stm_comms_trigger.lua")

local function isBridgeName(name)
	return name == "Section 100 Bridge" or name == "Section 1 Bridge"
end

function Star_Trek.Comms_Panel:IsOnBridge(ply, deck, section)
	if not (Star_Trek and Star_Trek.Sections and Star_Trek.Sections.DetermineSection) then
		return false
	end

	local useDeck = deck
	local useSection = section

	if useDeck == nil or useSection == nil then
		if not IsValid(ply) then return false end
		local inShip
		inShip, useDeck, useSection = Star_Trek.Sections:DetermineSection(ply:GetPos())
		if not inShip then
			return false
		end
	end

	local sectionName = Star_Trek.Sections:GetSectionName(useDeck, useSection)
	return isBridgeName(sectionName)
end

function Star_Trek.Comms_Panel:IsBridgeOccupied()
	for _, ply in ipairs(player.GetAll()) do
		if self:IsOnBridge(ply) then
			return true
		end
	end

	return false
end

function Star_Trek.Comms_Panel:SetHoldOpen(enabled)
	local ent = self.Button
	if not IsValid(ent) then
		self.HoldOpen = false
		return
	end

	if self.HoldOpen == enabled then
		return
	end

	self.HoldOpen = enabled
	ent.LCARSKeyData = ent.LCARSKeyData or {}

	if enabled then
		ent.LCARSKeyData["lcars_never_close"] = "1"
		ent:Fire("AddOutput", "lcars_never_close 1", 0)
	else
		ent.LCARSKeyData["lcars_never_close"] = nil
		ent:Fire("AddOutput", "lcars_never_close 0", 0)
	end
end

function Star_Trek.Comms_Panel:RefreshHoldOpen()
	self:SetHoldOpen(self:IsBridgeOccupied())
end

function Star_Trek.Comms_Panel:TryOpenInterface(ply, reason)
	if not IsValid(ply) or not ply:IsPlayer() then
		return false, "Invalid player"
	end

	if not (Star_Trek and Star_Trek.LCARS) then
		return false, "LCARS unavailable"
	end

	local panel = self.Button
	if not IsValid(panel) then
		return false, "Panel missing"
	end

	if Star_Trek and Star_Trek.LCARS and Star_Trek.LCARS.ActiveInterfaces and Star_Trek.LCARS.ActiveInterfaces[panel] then
		self:RefreshHoldOpen()
		return true
	end

	local success, err = Star_Trek.LCARS:OpenInterface(ply, panel, "comms_panel")
	if not success and self.Debug then
		print(string.format("[CommsTrigger] Failed to open via %s: %s", tostring(reason or "auto"), tostring(err)))
	end

	return success, err
end

local setupButton = function()
	if IsValid(Star_Trek.Comms_Panel.Button) then
		Star_Trek.Comms_Panel:SetHoldOpen(false)
		Star_Trek.Comms_Panel.Button:Remove()
	end
	timer.Remove("Star_Trek.Comms_Panel.BridgeHold")

	local pos = Vector(159.02, 89.44, 13427.09)
	local ang = Angle(0, 170, 0)

	local success, ent = Star_Trek.Button:CreateInterfaceButton(pos, ang, "models/hunter/blocks/cube025x025x025.mdl", "comms_panel")
	if not success then
		print(ent)
	else
		print("[StarTrekEntities] Comms panel button spawned:", pos, ang)
	end
	Star_Trek.Comms_Panel.Button = ent

	if IsValid(ent) then
		Star_Trek.Comms_Panel:RefreshHoldOpen()
		timer.Create("Star_Trek.Comms_Panel.BridgeHold", 2, 0, function()
			if not IsValid(Star_Trek.Comms_Panel.Button) then
				Star_Trek.Comms_Panel:SetHoldOpen(false)
				return
			end

			Star_Trek.Comms_Panel:RefreshHoldOpen()
		end)
	end

	if IsValid(Star_Trek.Comms_Panel.Trigger) then
		Star_Trek.Comms_Panel.Trigger:Remove()
		Star_Trek.Comms_Panel.Trigger = nil
	end

	if Star_Trek.Comms_Panel.AutoOpenTrigger ~= false then
		local trigger = ents.Create("stm_comms_trigger")
		if IsValid(trigger) then
			trigger:SetPos(pos)
			trigger:SetAngles(ang)
			trigger:SetRange(110)
			trigger:Spawn()
			trigger:Activate()
			trigger.Panel = ent
			Star_Trek.Comms_Panel.Trigger = trigger
			print("[StarTrekEntities] Comms trigger spawned around panel")
		else
			print("[StarTrekEntities] Failed to create comms trigger")
		end
	end


	local repairPos = Vector(-200.00, -265.00, 13355.00)
	local repairAng = Angle(-0.01, -117.19, 89.99)
	if IsValid(Star_Trek.Comms_Panel.RepairEnt) then
		Star_Trek.Comms_Panel.RepairEnt:Remove()
	end

	local repair = ents.Create("comms_repair")
	if IsValid(repair) then
		repair:SetPos(repairPos)
		repair:SetAngles(repairAng)
		repair:Spawn()
		repair:Activate()
		Star_Trek.Comms_Panel.RepairEnt = repair
		print("[StarTrekEntities] Comms repair entity spawned:", repairPos, repairAng)
	else
		print("[StarTrekEntities] Failed to create Comms repair entity!")
	end

	-- Power ON by default and sync scramble to health
	if StarTrekEntities and StarTrekEntities.Comms then
		if StarTrekEntities.Comms.SetPower then StarTrekEntities.Comms:SetPower(true) end
		if StarTrekEntities.Comms.SyncScrambleFromHealth then
			local scram = select(1, StarTrekEntities.Comms:SyncScrambleFromHealth())
			local hp = StarTrekEntities.Comms:GetHealthPercent()
			print(string.format("[StarTrekEntities] Comms sync: HP %.0f%% -> Scramble %.0f%%", hp or -1, scram or -1))
		end
	end
end

hook.Add("InitPostEntity", "Star_Trek.Comms_Panel.SpawnButton", setupButton)
hook.Add("PostCleanupMap", "Star_Trek.Comms_Panel.SpawnButton", setupButton)

hook.Add("Star_Trek.Sections.LocationChanged", "Star_Trek.Comms_Panel.AutoOpenOnBridge", function(ply, oldDeck, oldSectionId, newDeck, newSectionId)
	if not IsValid(ply) then return end
	if Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.AutoOpenTrigger == false then return end
	if not (Star_Trek and Star_Trek.Sections and Star_Trek.Sections.GetSectionName) then return end
	if Star_Trek and Star_Trek.Comms_Panel then
		Star_Trek.Comms_Panel:RefreshHoldOpen()
	end

	if not newDeck or not newSectionId then return end
	if not (Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.IsOnBridge) then return end
	if not Star_Trek.Comms_Panel:IsOnBridge(ply, newDeck, newSectionId) then return end

	Star_Trek.Comms_Panel._sectionOpenTimes = Star_Trek.Comms_Panel._sectionOpenTimes or {}
	local lastOpen = Star_Trek.Comms_Panel._sectionOpenTimes[ply] or 0
	if CurTime() < lastOpen + 2 then return end

	local panel = Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.Button
	if not (Star_Trek and Star_Trek.LCARS and IsValid(panel)) then
		if Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.Debug then
			print("[CommsTrigger] Section hook activation failed: panel unavailable")
		end
		return
	end

	local success, err = Star_Trek.Comms_Panel:TryOpenInterface(ply, "section_hook")
	if success then
		Star_Trek.Comms_Panel._sectionOpenTimes[ply] = CurTime()
	elseif Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.Debug then
		print(string.format("[CommsTrigger] Section hook failed: %s", tostring(err)))
	end
end)

hook.Add("PlayerSay", "Star_Trek.Comms_Panel.SectionDebug", function(ply, text)
	if not IsValid(ply) or not isstring(text) then return end
	local cleaned = string.Trim(string.lower(text))
	if cleaned ~= "balls2" then return end

	if not (Star_Trek and Star_Trek.Sections and Star_Trek.Sections.DetermineSection) then
		ply:ChatPrint("[CommsTrigger] Section system unavailable.")
		return true
	end

	local success, deck, sectionId = Star_Trek.Sections:DetermineSection(ply:GetPos())
	if not success then
		ply:ChatPrint("[CommsTrigger] Unable to resolve section from current position.")
		return true
	end

	local sectionName = Star_Trek.Sections:GetSectionName(deck, sectionId) or "Unknown"
	ply:ChatPrint(string.format("Deck %s, Section %s (%s)", tostring(deck), tostring(sectionId), sectionName))
	return true
end)
