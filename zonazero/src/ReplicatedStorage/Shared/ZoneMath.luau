-- ZoneMath: calcula onde a zona está agora (o servidor e as telas usam a mesma conta).
-- Atributos do Workspace: ZoneCX, ZoneCZ, ZoneR (círculo antigo), ZoneNCX, ZoneNCZ, ZoneNR (próximo),
-- ZoneShrinkStart, ZoneShrinkEnd (hora do servidor), ZoneStage (fase atual, 0 = sem zona).
local ZoneMath = {}

function ZoneMath.Current(now: number?): (number, number, number)
	local w = workspace
	local t = now or w:GetServerTimeNow()
	local cx, cz, r = w:GetAttribute("ZoneCX") or 0, w:GetAttribute("ZoneCZ") or 0, w:GetAttribute("ZoneR") or 0
	local ncx, ncz, nr = w:GetAttribute("ZoneNCX") or cx, w:GetAttribute("ZoneNCZ") or cz, w:GetAttribute("ZoneNR") or r
	local s, e = w:GetAttribute("ZoneShrinkStart") or 0, w:GetAttribute("ZoneShrinkEnd") or 0
	if t <= s or e <= s then
		return cx, cz, r
	end
	local a = math.clamp((t - s) / (e - s), 0, 1)
	return cx + (ncx - cx) * a, cz + (ncz - cz) * a, r + (nr - r) * a
end

function ZoneMath.Next(): (number, number, number)
	local w = workspace
	return w:GetAttribute("ZoneNCX") or 0, w:GetAttribute("ZoneNCZ") or 0, w:GetAttribute("ZoneNR") or 0
end

function ZoneMath.IsInside(position: Vector3, now: number?): boolean
	if (workspace:GetAttribute("ZoneStage") or 0) <= 0 then
		return true
	end
	local cx, cz, r = ZoneMath.Current(now)
	local dx, dz = position.X - cx, position.Z - cz
	return dx * dx + dz * dz <= r * r
end

return ZoneMath
