include("shared.lua")

local physgunClass = "weapon_physgun"
local drawColorActive = Color(255, 120, 120)
local drawColorInactive = Color(120, 200, 255)

local function shouldDrawHidden(ent)
	if ent:GetInWorldVisible() then
		return true
	end

	local ply = LocalPlayer()
	if not IsValid(ply) then
		return false
	end

	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) then
		return false
	end

	return wep:GetClass() == physgunClass
end

local function drawInfo(ent)
	local descriptor = ent:GetTargetDescription()
	local systemName = ent.SystemName or "Subsystem"
	local pos = ent:GetPos() + Vector(-50, 20, 108)
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local eyeAng = ply:EyeAngles()
	local ang = Angle(0, eyeAng.y - 90, 90)

	local scale = 0.08
	local active = ent:GetNWBool("stm_zone_disabled", false)
	local headerColor = active and drawColorActive or drawColorInactive

	cam.Start3D2D(pos, ang, scale)
		draw.SimpleTextOutlined(systemName, "DermaLarge", 0, -24, headerColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 160))
		draw.SimpleTextOutlined(descriptor, "DermaDefaultBold", 0, 6, Color(250, 250, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 160))
	cam.End3D2D()
end

function ENT:Draw()
	if not shouldDrawHidden(self) then
		return
	end

	self:DrawModel()
	drawInfo(self)
end
