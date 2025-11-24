print("StarTrekEntities: Loaded sv_fix_think.lua")
local valid_ents = {
	["lifesupport"] = true,
	["commsarray"] = true,
	["gravgen"] = true,
	["life_support_core"] = true,
	["stm_disable_lifesupport"] = true,
	["stm_disable_gravity"] = true,
}

-- Smooth out SWEP repairing animation and per-target throttling
local last_active_by_owner = {}
local last_tick_by_ent = {}
local last_full_hp_log = {}
local ANIM_SMOOTH_WINDOW = 0.2

local function HandleSonicTrace(owner, wep, hit_ent, hit_pos)
	if not IsValid(owner) or not owner:IsPlayer() then return end

	-- If the trace didn't give us an entity, try to resolve one near the hit_pos to reduce flicker
	if (not IsValid(hit_ent)) and isvector(hit_pos) then
		local nearest, nd, nclass
		for _, ent in ipairs(ents.FindInSphere(hit_pos, 16)) do
			if IsValid(ent) then
				local class = ent:GetClass()
				if class == "comms_repair" or class == "stm_quickshake_remover" or valid_ents[class] then
					local d = ent:GetPos():DistToSqr(hit_pos)
					if not nearest or d < nd then
						nearest, nd, nclass = ent, d, class
					end
				end
			end
		end
		if IsValid(nearest) then
			hit_ent = nearest
		end
	end

	-- If we still have no entity, keep animation alive briefly if we had a recent positive hit
	local lastActive = last_active_by_owner[owner]
	if not IsValid(hit_ent) then
		if lastActive and CurTime() < lastActive + ANIM_SMOOTH_WINDOW then
			return true
		end
		return
	end

	local ent_class = hit_ent:GetClass()
	-- Support QuickShake Remover entity: repair via its own API and reduce comms scramble gradually
	if ent_class == "stm_quickshake_remover" then
		if isfunction(hit_ent.Repair) then
			hit_ent:Repair(owner, wep)
		end
		-- Reduce comms scramble a bit per sonic tick
		if StarTrekEntities and StarTrekEntities.Comms then
			local st = StarTrekEntities.Status and StarTrekEntities.Status.comms
			if st then
				local before = st.scrambled_percent or 0
				if before > 0 then
					local reduce = 5
					local after = math.max(0, before - reduce)
					st.scrambled_percent = after
					st.scrambled_level = math.max(0, math.ceil((after / 100) * 6))
					if Star_Trek and Star_Trek.Logs and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.Button then
						Star_Trek.Logs:AddEntry(Star_Trek.Comms_Panel.Button, owner, string.format("Comms scramble reduced to %d%% via sonic repair", after))
					end
				end
				-- If the entity reports fully repaired, clear scramble completely
				if hit_ent.Repaired then
					st.scrambled_percent = 0
					st.scrambled_level = 0
				end
			end
		end
		last_active_by_owner[owner] = CurTime()
		return true
	end


	-- Handle our dedicated comms repair entity specially
	if ent_class == "comms_repair" then
		local now = CurTime()
		local key = hit_ent:EntIndex()
		-- Prefer entity-provided comms health APIs if available (retrieve early to decide animation)
		local hp = (hit_ent.GetCommsHealth and hit_ent:GetCommsHealth()) or hit_ent:Health()
		local max_hp = (hit_ent.GetCommsMaxHealth and hit_ent:GetCommsMaxHealth()) or hit_ent:GetMaxHealth()
		if hp >= max_hp then
			-- Immediately stop repair effects; do NOT keep animation alive
			if IsValid(wep) then wep:SetSkin(1) end
			if Star_Trek and Star_Trek.Logs and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.Button then
				local lastLog = last_full_hp_log[key] or 0
				if now > lastLog + 2 then
					Star_Trek.Logs:AddEntry(Star_Trek.Comms_Panel.Button, owner, "Comms array at 100% integrity. Sonic repair not required.", Star_Trek.LCARS and Star_Trek.LCARS.ColorBlue or nil)
					last_full_hp_log[key] = now
				end
			end
			return false
		end

		local last = last_tick_by_ent[key] or 0
		local interval = 0.1
		if now < last + interval then
			-- Throttled: keep animation active smoothly
			last_active_by_owner[owner] = now
			return true
		end
		last_tick_by_ent[key] = now

		local amount = math.max(1, math.floor(max_hp * 0.005))
		if hit_ent.RepairAmount then
			hit_ent:RepairAmount(amount)
		else
			hit_ent:SetHealth(math.Clamp(hp + amount, 0, max_hp))
		end

		if StarTrekEntities and StarTrekEntities.Comms and StarTrekEntities.Comms.SyncScrambleFromHealth then
			StarTrekEntities.Comms:SyncScrambleFromHealth()
		end

		local chp = (hit_ent.GetCommsHealth and hit_ent:GetCommsHealth()) or hit_ent:Health()
		local cmx = (hit_ent.GetCommsMaxHealth and hit_ent:GetCommsMaxHealth()) or hit_ent:GetMaxHealth()
		if chp >= cmx then
			if IsValid(wep) then wep:SetSkin(1) end
			return false
		end
		last_active_by_owner[owner] = now
		return true
	end

	if ent_class == "life_support_core" then
		local now = CurTime()
		local key = hit_ent:EntIndex()
		local hp = hit_ent.GetLifeSupportHealth and hit_ent:GetLifeSupportHealth() or hit_ent:Health()
		local max_hp = hit_ent.GetLifeSupportMaxHealth and hit_ent:GetLifeSupportMaxHealth() or hit_ent:GetMaxHealth()
		if max_hp <= 0 then return true end
		if hp >= max_hp then
			if IsValid(wep) then wep:SetSkin(1) end
			last_active_by_owner[owner] = now
			return false
		end

		local last = last_tick_by_ent[key] or 0
		local interval = 0.15
		if now < last + interval then
			last_active_by_owner[owner] = now
			return true
		end
		last_tick_by_ent[key] = now

		local add = math.max(1, math.floor(max_hp * 0.01))
		if hit_ent.RepairAmount then
			hit_ent:RepairAmount(add)
		else
			hit_ent:SetHealth(math.Clamp(hp + add, 0, max_hp))
		end

		if StarTrekEntities and StarTrekEntities.LifeSupport and StarTrekEntities.LifeSupport:GetCore() == hit_ent then
			StarTrekEntities.LifeSupport:ClearManualOverride(hit_ent)
		end

		hp = hit_ent.GetLifeSupportHealth and hit_ent:GetLifeSupportHealth() or hit_ent:Health()
		if hp >= max_hp then
			if IsValid(wep) then wep:SetSkin(1) end
			return false
		end

		last_active_by_owner[owner] = now
		return true
	end

	if not valid_ents[ent_class] then
		return
	end -- If the entity is not in the valid list, just return

	local now = CurTime()
	local key = hit_ent:EntIndex()
	local last = last_tick_by_ent[key] or 0
	if now < last + 1 then return true end
	last_tick_by_ent[key] = now
	local hp = hit_ent:Health()
	local max_hp = hit_ent:GetMaxHealth()
	if hp >= max_hp then return end
	math.randomseed(os.time() + hit_ent:EntIndex())
	local repair_amount = math.random(15, 30)
	hit_ent:SetHealth(math.Clamp(hp + repair_amount, 0, max_hp))
	hit_ent:SetPlayerRepairing(true)
	
	if hit_ent:Health() >= hit_ent:GetMaxHealth() then
		wep:SetSkin(1)
		return false
	end

	last_active_by_owner[owner] = now
	return true
end

-- Register for multiple possible sonic driver hook ids (different addons may use different case/paths)
local hookIds = {
	"Star_Trek.tools.sonic_driver.trace_hit",
	"Star_Trek.Tools.SonicDriver.TraceHit",
	"Star_Trek.SonicDriver.TraceHit",
	"Star_Trek.tools.sonicdriver.trace_hit",
}

for _, id in ipairs(hookIds) do
	hook.Add(id, "Valid_Ents_Fix_Trace", HandleSonicTrace)
end
