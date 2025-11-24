StarTrekEntities = StarTrekEntities or {}
StarTrekEntities.Comms = StarTrekEntities.Comms or {}
print("StarTrekEntities: Loaded sv_communication_scramble.lua")
-- Define combining characters (Zalgo style)
local zalgo_up = {"̍","̎","̄","̅","̿","̑","̆","̐","͒","͗","͑","̇","̈","̊","͂","̓","̈́","͊","͋","͌","̃","̂","̌","͐"}
local zalgo_mid = {"̕","̛","̀","́","͘","̡","̢","̧","̨","̴","̵","̶","͜","͝","͞","͟","͠","͢","̸","̷","͡"}
local zalgo_down = {"̖","̗","̘","̙","̜","̝","̞","̟","̠","̤","̥","̦","̩","̪","̫","̬","̭","̮","̯","̰","̱","̲","̳","̹","̺","̻","̼","ͅ","͇","͈","͉","͍","͎","͓","͔","͕","͖","͙","͚"}

-- Scramble text with intensity level (1–6)
-- When providing a percent (0-100), convert to 0-6 intensity
local function PercentToIntensity(percent)
	percent = tonumber(percent) or 0
	percent = math.Clamp(percent, 0, 100)
	if percent <= 0 then return 0 end
	return math.Clamp(math.ceil((percent / 100) * 6), 1, 6)
end

function StarTrekEntities.Comms:ScrambleText(text, intensity)
	if not text or text == "" then return "" end
	if intensity == 0 then return text end
	math.randomseed(os.time()) -- Seed random number generator
	intensity = math.Clamp(intensity, 1, 6) -- Ensure intensity is between 1 and 6
	local function getRandom(tbl, count)
		local out = ""
		for i = 1, count do
			out = out .. tbl[math.random(#tbl)]
		end
		return out
	end

	local result = ""
	for i = 1, #text do
		local char = text:sub(i, i)
		if char:match("%s") then
			result = result .. char -- don't glitch spaces
		else
			local up = getRandom(zalgo_up, intensity)
			local mid = getRandom(zalgo_mid, math.max(0, intensity - 2))
			local down = getRandom(zalgo_down, intensity)
			result = result .. char .. up .. mid .. down
		end
	end

	return result
end

local comms_status = {
	active = false,
	-- scrambled_level: 0-6 (for text intensity)
	scrambled_level = 0,
	-- scrambled_percent: 0-100 (for precise mapping/display)
	scrambled_percent = 0,
}

-- Helper: fetch current status table safely
local function GetStatus()
	local st = StarTrekEntities.Status and StarTrekEntities.Status.comms
	if not st then
		StarTrekEntities.Status = StarTrekEntities.Status or {}
		StarTrekEntities.Status.comms = table.Copy(comms_status)
		st = StarTrekEntities.Status.comms
	end
	return st
end

-- Helper: write a value to the status store (no external dependency)
local function SetCommsStatus(key, value)
	local st = GetStatus()
	st[key] = value
	return st
end

-- Helper: get current repair entity if available
function StarTrekEntities.Comms:GetRepairEntity()
	if Star_Trek and Star_Trek.Comms_Panel and IsValid(Star_Trek.Comms_Panel.RepairEnt) then
		return Star_Trek.Comms_Panel.RepairEnt
	end
	return nil
end

-- (removed) QuickShake fallback helper was deprecated; health is sourced only from the comms repair entity

-- Compute scrambled percent (0-100) from health percent using 50% threshold
-- If health >= 50% -> 0% scrambled; if 0..50% -> map linearly to 100% scrambled
function StarTrekEntities.Comms:ComputeScramblePercentFromHealth(hpPercent)
	hpPercent = tonumber(hpPercent) or 0
	hpPercent = math.Clamp(hpPercent, 0, 100)
	if hpPercent >= 50 then return 0 end
	return (50 - hpPercent) * 2
end

-- Inverse mapping used for UI fallback: derive a plausible health from scramble percent
function StarTrekEntities.Comms:ComputeHealthFromScramblePercent(scramPercent)
	scramPercent = tonumber(scramPercent) or 0
	scramPercent = math.Clamp(scramPercent, 0, 100)
	if scramPercent <= 0 then return 100 end
	return math.max(0, math.floor(50 - (scramPercent / 2)))
end

-- Health percent of the repair entity (0-100). If missing, assume 0.
function StarTrekEntities.Comms:GetHealthPercent()
	local ent = self:GetRepairEntity()
	if IsValid(ent) then
		local maxhp = (ent.GetCommsMaxHealth and ent:GetCommsMaxHealth()) or (ent.GetMaxHealth and ent:GetMaxHealth()) or 0
		local hp = (ent.GetCommsHealth and ent:GetCommsHealth()) or (ent.Health and ent:Health())
		if (maxhp or 0) > 0 and (hp ~= nil) then
			return math.Clamp(((hp or 0) / maxhp) * 100, 0, 100)
		end
	end

	-- Finally, fall back to scramble-derived health for UI consistency
	local st = GetStatus()
	return self:ComputeHealthFromScramblePercent(st.scrambled_percent or 0)
end

-- Sync scrambled values from current health if power is ON; if OFF, keep at 100%
function StarTrekEntities.Comms:SyncScrambleFromHealth()
	local st = GetStatus()
	if not st.active then
		st.scrambled_percent = 100
		st.scrambled_level = 6
		SetCommsStatus("scrambled_percent", st.scrambled_percent)
		SetCommsStatus("scrambled_level", st.scrambled_level)
		return st.scrambled_percent, st.scrambled_level
	end
	local hpPercent = self:GetHealthPercent()
	local scramPercent = self:ComputeScramblePercentFromHealth(hpPercent)
	local level = PercentToIntensity(scramPercent)
	st.scrambled_percent = scramPercent
	st.scrambled_level = level
	SetCommsStatus("scrambled_percent", scramPercent)
	SetCommsStatus("scrambled_level", level)
	return scramPercent, level
end

-- Power control
function StarTrekEntities.Comms:SetPower(on)
	local st = GetStatus()
	st.active = not not on
	SetCommsStatus("active", st.active)
	if st.active then
		self:SyncScrambleFromHealth()
	else
		st.scrambled_percent = 100
		st.scrambled_level = 6
		SetCommsStatus("scrambled_percent", 100)
		SetCommsStatus("scrambled_level", 6)
	end
end

function StarTrekEntities.Comms:Shutdown(ent)
	self:SetPower(false)
	if Star_Trek and Star_Trek.Logs and ent then
		Star_Trek.Logs:AddEntry(ent, nil, "Communications: Power OFF (scramble 100%)")
	end
end

function StarTrekEntities.Comms:Enable(ent)
	self:SetPower(true)
	local percent = select(1, self:SyncScrambleFromHealth()) or 0
	if Star_Trek and Star_Trek.Logs and ent then
		Star_Trek.Logs:AddEntry(ent, nil, string.format("Communications: Power ON (scramble %d%%)", percent))
	end
end

-- Start a slow automated repair: +15% max health every 30 seconds until full.
function StarTrekEntities.Comms:RunRepair(ent)
	local repairEnt = self:GetRepairEntity()
	if not IsValid(repairEnt) then
		if Star_Trek and Star_Trek.Logs and ent then
			Star_Trek.Logs:AddEntry(ent, nil, "Automated repair failed: repair entity not found")
		end
		return false
	end

	local maxhp = (repairEnt.GetCommsMaxHealth and repairEnt:GetCommsMaxHealth()) or 100
	if maxhp <= 0 then return false end

	local timerId = "StarTrekEntities.Comms.AutoRepair"
	local startTime = CurTime()
	if timer.Exists(timerId) then
		if Star_Trek and Star_Trek.Logs and ent then
			Star_Trek.Logs:AddEntry(ent, nil, "Automated repair already running")
		end
		return true
	end

	timer.Create(timerId, 30, 0, function()
		if not IsValid(repairEnt) then
			timer.Remove(timerId)
			return
		end
		if CurTime() - startTime > 60 then
			if Star_Trek and Star_Trek.Logs and ent then
				Star_Trek.Logs:AddEntry(ent, nil, "Automated repair ended auto shutdown")
			end
			timer.Remove(timerId)
			return
		end
		local cur = (repairEnt.GetCommsHealth and repairEnt:GetCommsHealth()) or (repairEnt.Health and repairEnt:Health()) or 0
		if cur >= maxhp then
			timer.Remove(timerId)
			if Star_Trek and Star_Trek.Logs and ent then
				Star_Trek.Logs:AddEntry(ent, nil, "Automated repair complete")
			end
			return
		end
		local add = math.floor(maxhp * 0.15)
		if repairEnt.RepairAmount then
			repairEnt:RepairAmount(add)
		else
			repairEnt:SetHealth(math.min(cur + add, maxhp))
			if StarTrekEntities and StarTrekEntities.Comms and StarTrekEntities.Comms.SyncScrambleFromHealth then
				StarTrekEntities.Comms:SyncScrambleFromHealth()
			end
		end
		if Star_Trek and Star_Trek.Logs and ent then
			local newhp = (repairEnt.GetCommsHealth and repairEnt:GetCommsHealth()) or (repairEnt.Health and repairEnt:Health()) or 0
			Star_Trek.Logs:AddEntry(ent, nil, string.format("Automated repair progress report: System stablitly %d%%", math.floor((newhp / maxhp) * 100)))
		end
	end)

	if Star_Trek and Star_Trek.Logs and ent then
		Star_Trek.Logs:AddEntry(ent, nil, "Automated repair sequence online automatic shutdown in 60 seconds")
	end

	return true
end

hook.Add("CommunicationsArrayInitialized", "ActivateCommsSystem", function(ent)
	if not IsValid(ent) then return end
	StarTrekEntities.Comms:SetPower(true)
end)

hook.Add("CommunicationsArrayDamaged", "HandleCommsDamage", function(ent, dmg, damage_level)
	-- ...existing code...
end)

-- Chat command: /comms "target" "message" or /comms <message>
hook.Add("PlayerSay", "StarTrekEntities.CommsChat", function(ply, text)
	if not isstring(text) then return end
	if text[1] ~= "/" then return end

	local raw = string.sub(text, 2)
	local args = string.Explode(" ", raw)
	if args[1] ~= "comms" then return end

	-- Supports /comms "target" "message" or /comms <message>
	local quotedTarget = raw:match('^comms%s+"([^"]+)"')
	local message = raw:match('^comms%s+"[^"]+"%s+"([^"]+)"')
	if quotedTarget and not message then
		-- Allow unquoted message after quoted target
		local after = raw:gsub('^comms%s+"[^"]+"%s*', "", 1)
		message = string.Trim(after)
	end
	if not quotedTarget then
		message = string.Trim(raw:sub(7) or "")
	end

	local sender = ply:Nick() or "Unknown"
	local receiver = quotedTarget or "All Channels"
	local msg = message or ""

	if Star_Trek and Star_Trek.Logs then
		local ent = Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.Button
		Star_Trek.Logs:RegisterType("Communications Console")
		local col = Star_Trek.LCARS and Star_Trek.LCARS.ColorLightBlue or nil
		Star_Trek.Logs:AddEntry(ent, ply, "", col)
		Star_Trek.Logs:AddEntry(ent, ply, "Sender: " .. sender, col)
		Star_Trek.Logs:AddEntry(ent, ply, "", col)
		Star_Trek.Logs:AddEntry(ent, ply, "Broadcasted to: " .. receiver, col)
		Star_Trek.Logs:AddEntry(ent, ply, "", col)
		Star_Trek.Logs:AddEntry(ent, ply, "Message: " .. msg, col)
	end
	return
end)
