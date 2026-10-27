--!strict
--[=[
	EmployeeLanyardFormulas: pure geometry and spring math for the v4 fitted lanyard strap and v6 rank badge
	(gates: characters/employees_build/gates/7f_badges_v6_info_front_icon_back.md).

	- `fit(name)` / `fitForTorso(employeeName, torsoSize)`: decodes the quantized (`1e-4`) fitted ribbon and chest
	  depth map from `EmployeeLanyardConstants`.
	- `width(fit, rank)` and `geometry(fit, width, scale)`: builds the closed 5-station ribbon mesh (inner/outer faces,
	  two side edges, two end caps, and rank 7's dark edge bands) in UpperTorso-local studs.
	- `step(fit, rank, spring, accel, dt)`: integrates the badge's pitch/roll/yaw spring and clamps pitch against the
	  fitted chest depth map so the badge never pokes into the body.
	- `cardZ(parts)`: the plane the info card must sit on to stay in front of the badge's own geometry.

	@class EmployeeLanyardFormulas
]=]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeLanyardConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeLanyardConstants)

export type Vec = { number }

export type Ribbon = {
	centre: { Vec },
	binormal: { Vec },
	normal: { Vec },
	offset: { { Vec } },
}

export type DepthMap = {
	x_rbx: { number },
	y_rbx: { number },
	z_rbx: { { number } },
}

export type Clamp = {
	pitch_out_deg: number,
	roll_deg: number,
	yaw_max_deg: number,
	yaw_per_pitch: number,
}

export type Fit = {
	ut_size: Vec,
	torso_width: number,
	max_width: number,
	pivot_rbx: Vec,
	badge_rest: { [string]: { pitch_deg: number } },
	constants: { clamp_margin: number, clamp: Clamp },
	ribbon: Ribbon,
	depth_map: DepthMap,
	outlines_asm_rbx: { [string]: { Vec } },
}

export type Geometry = {
	pos: { Vec },
	tris: { { number } },
	triBand: { number },
	nSamples: number,
}

export type Spring = { p: number, r: number, y: number, vp: number, vr: number, vy: number }

-- One opaque part of a badge model, in the badge's own space (pivot at the origin).
export type BadgePart = { cframe: CFrame, size: Vector3 }

local EmployeeLanyardFormulas = {}

local decoded: { [string]: Fit } = {}

local function unquantize(tbl: { [unknown]: unknown })
	for key, value in tbl do
		if type(value) == "number" then
			tbl[key] = value * 1e-4
		elseif type(value) == "table" then
			unquantize(value :: { [unknown]: unknown }) -- recursive table unquantization of decoded JSON
		end
	end
end

function EmployeeLanyardFormulas.fit(name: string): Fit?
	local hit = decoded[name]
	if hit ~= nil then
		return hit
	end
	local raw = EmployeeLanyardConstants.FITS[name]
	if raw == nil then
		return nil
	end
	local parsed = HttpService:JSONDecode(raw) :: { [unknown]: unknown } -- JSONDecode returns unknown table
	unquantize(parsed)
	local typed = parsed :: Fit -- validated by EmployeeLanyardFormulas.spec against fit_v4.py schema
	decoded[name] = typed
	return typed
end

function EmployeeLanyardFormulas.fitForTorso(employeeName: string?, torsoSize: Vector3): (Fit, string)
	if employeeName ~= nil then
		local direct = EmployeeLanyardFormulas.fit(employeeName)
		if direct ~= nil then
			return direct, employeeName
		end
	end
	local bestFit: Fit? = nil
	local bestName = "Pippa"
	local bestErr = math.huge
	for name in EmployeeLanyardConstants.FITS do
		local f = EmployeeLanyardFormulas.fit(name)
		if f ~= nil then
			local s = torsoSize.X / f.ut_size[1]
			local err = math.abs(torsoSize.Y / f.ut_size[2] - s) + math.abs(torsoSize.Z / f.ut_size[3] - s)
			if err < bestErr then
				bestFit, bestName, bestErr = f, name, err
			end
		end
	end
	return bestFit or (EmployeeLanyardFormulas.fit("Pippa") :: Fit), bestName -- Pippa is always present in FITS
end

function EmployeeLanyardFormulas.width(fit: Fit, rank: number): number
	local r = math.clamp(math.floor(rank), 1, #EmployeeLanyardConstants.RANK_RATIO)
	return EmployeeLanyardConstants.CORD_FRAC * fit.torso_width * EmployeeLanyardConstants.RANK_RATIO[r]
end

local function add(a: Vec, b: Vec): Vec
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

local function sub(a: Vec, b: Vec): Vec
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function mulv(a: Vec, s: number): Vec
	return { a[1] * s, a[2] * s, a[3] * s }
end

local function dot(a: Vec, b: Vec): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function offsetAt(row: { Vec }, u: number): Vec
	local f = (math.clamp(u, -1, 1) + 1) / 0.5
	local k = math.min(math.floor(f), 3)
	local t = f - k
	local a, b = row[k + 1], row[k + 2]
	return { a[1] * (1 - t) + b[1] * t, a[2] * (1 - t) + b[2] * t, a[3] * (1 - t) + b[3] * t }
end

function EmployeeLanyardFormulas.geometry(fit: Fit, width: number, scale: number): Geometry
	local rb = fit.ribbon
	local n = #rb.centre
	local u = width / fit.max_width
	local pos: { Vec } = {}
	local tris: { { number } } = {}
	local band: { number } = {}
	local inner: { { number } } = {}
	local outer: { { number } } = {}
	local thickness = EmployeeLanyardConstants.STRAP_T
	local across = EmployeeLanyardConstants.ACROSS

	for i = 1, n do
		local c, b, nn = rb.centre[i], rb.binormal[i], rb.normal[i]
		inner[i], outer[i] = {}, {}
		for k = 1, 5 do
			local s = across[k] * u
			local p = add(add(c, mulv(b, s * fit.max_width / 2)), offsetAt(rb.offset[i], s))
			table.insert(pos, mulv(p, scale))
			inner[i][k] = #pos
			table.insert(pos, mulv(add(p, mulv(nn, thickness)), scale))
			outer[i][k] = #pos
		end
	end

	local function tri(a: number, b: number, c: number, want: Vec, bnd: number)
		local nrm = cross(sub(pos[b], pos[a]), sub(pos[c], pos[a]))
		if dot(nrm, want) < 0 then
			b, c = c, b
		end
		table.insert(tris, { a, b, c })
		table.insert(band, bnd)
	end

	local function quad(a: number, b: number, c: number, d: number, want: Vec, bnd: number)
		tri(a, b, c, want, bnd)
		tri(a, c, d, want, bnd)
	end

	for i = 1, n - 1 do
		local nn = rb.normal[i]
		local bb = rb.binormal[i]
		for k = 1, 4 do
			local bnd = if k == 1 or k == 4 then 1 else 0
			quad(outer[i][k], outer[i + 1][k], outer[i + 1][k + 1], outer[i][k + 1], nn, bnd)
			quad(inner[i][k], inner[i + 1][k], inner[i + 1][k + 1], inner[i][k + 1], mulv(nn, -1), bnd)
		end
		quad(inner[i][1], inner[i + 1][1], outer[i + 1][1], outer[i][1], mulv(bb, -1), 1)
		quad(inner[i][5], inner[i + 1][5], outer[i + 1][5], outer[i][5], bb, 1)
	end

	for _, pair in { { 1, 2 }, { n, n - 1 } } do
		local i, j = pair[1], pair[2]
		local t = mulv(sub(rb.centre[j], rb.centre[i]), -1)
		for k = 1, 4 do
			quad(inner[i][k], inner[i][k + 1], outer[i][k + 1], outer[i][k], t, 1)
		end
	end

	return { pos = pos, tris = tris, triBand = band, nSamples = n }
end

local function rad(d: number): number
	return d * math.pi / 180
end

local function rotX(a: number): { { number } }
	local c, s = math.cos(a), math.sin(a)
	return { { 1, 0, 0 }, { 0, c, -s }, { 0, s, c } }
end

local function rotY(a: number): { { number } }
	local c, s = math.cos(a), math.sin(a)
	return { { c, 0, s }, { 0, 1, 0 }, { -s, 0, c } }
end

local function rotZ(a: number): { { number } }
	local c, s = math.cos(a), math.sin(a)
	return { { c, -s, 0 }, { s, c, 0 }, { 0, 0, 1 } }
end

local function mulMat(a: { { number } }, b: { { number } }): { { number } }
	local r: { { number } } = {}
	for i = 1, 3 do
		r[i] = {}
		for j = 1, 3 do
			r[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
	end
	return r
end

local function applyMat(m: { { number } }, v: Vec): Vec
	return {
		m[1][1] * v[1] + m[1][2] * v[2] + m[1][3] * v[3],
		m[2][1] * v[1] + m[2][2] * v[2] + m[2][3] * v[3],
		m[3][1] * v[1] + m[3][2] * v[2] + m[3][3] * v[3],
	}
end

function EmployeeLanyardFormulas.rotation(pitchDeg: number, rollDeg: number, yawDeg: number): { { number } }
	return mulMat(mulMat(rotX(rad(pitchDeg)), rotZ(rad(rollDeg))), rotY(rad(yawDeg)))
end

function EmployeeLanyardFormulas.chestZ(fit: Fit, x: number, y: number): number
	local dm = fit.depth_map
	local xs, ys, zs = dm.x_rbx, dm.y_rbx, dm.z_rbx
	local nx, ny = #xs, #ys
	local x0, x1 = xs[nx], xs[1]
	if x < x0 or x > x1 or y > ys[1] or y < ys[ny] then
		return 3
	end
	local gs = math.abs(xs[2] - xs[1])
	local fx = (x1 - x) / gs
	local i0 = math.min(math.floor(fx), nx - 2)
	local tx = fx - i0
	local fy = (ys[1] - y) / gs
	local j0 = math.min(math.floor(fy), ny - 2)
	local ty = fy - j0
	local a = zs[j0 + 1][i0 + 1] * (1 - tx) + zs[j0 + 1][i0 + 2] * tx
	local b = zs[j0 + 2][i0 + 1] * (1 - tx) + zs[j0 + 2][i0 + 2] * tx
	return a * (1 - ty) + b * ty
end

-- The plane the badge's front face sits on, `CARD_CLEARANCE` further front than the deepest part: the local z the
-- info card must use so the card (and the portrait inside it) is never buried in the badge. Nil for no parts.
function EmployeeLanyardFormulas.cardZ(parts: { BadgePart }): number?
	local front: number? = nil
	for _, part in parts do
		local _, _, z, _, _, _, _, _, _, r20, r21, r22 = part.cframe:GetComponents()
		local half = part.size * 0.5
		-- A box's reach along z once its rotation is applied (support function of its half extents).
		local reach = math.abs(r20) * half.X + math.abs(r21) * half.Y + math.abs(r22) * half.Z
		local face = z - reach
		if front == nil or face < front then
			front = face
		end
	end
	if front == nil then
		return nil
	end
	return front - EmployeeLanyardConstants.CARD_CLEARANCE
end

function EmployeeLanyardFormulas.clampPitch(
	fit: Fit,
	rank: number,
	pitchDeg: number,
	rollDeg: number,
	yawDeg: number,
	lift: number?
): number
	local ol = fit.outlines_asm_rbx[tostring(rank)]
	if ol == nil then
		return pitchDeg
	end
	local pv = fit.pivot_rbx
	local liftZ = -(lift or 0)
	local margin = fit.constants.clamp_margin
	local p = pitchDeg
	for _ = 1, 240 do
		local m = EmployeeLanyardFormulas.rotation(p, rollDeg, yawDeg)
		local ok = true
		for _, v in ol do
			local w = applyMat(m, v)
			local x, y, z = pv[1] + w[1], pv[2] + w[2], pv[3] + liftZ + w[3]
			if z > EmployeeLanyardFormulas.chestZ(fit, x, y) - margin then
				ok = false
				break
			end
		end
		if ok then
			return p
		end
		p += 0.25
	end
	return p
end

function EmployeeLanyardFormulas.newSpring(): Spring
	return { p = 0, r = 0, y = 0, vp = 0, vr = 0, vy = 0 }
end

function EmployeeLanyardFormulas.step(
	fit: Fit,
	rank: number,
	s: Spring,
	accel: Vec,
	dt: number
): (number, number, number, boolean)
	local cl = fit.constants.clamp
	local k, c = 140, 9
	s.vp += (accel[3] * 40 - k * s.p - c * s.vp) * dt
	s.vr += (-accel[1] * 40 - k * s.r - c * s.vr) * dt
	s.vy += (accel[1] * 20 - k * s.y - c * s.vy) * dt
	s.p += s.vp * dt
	s.r += s.vr * dt
	s.y += s.vy * dt
	local po = math.clamp(s.p, 0, cl.pitch_out_deg)
	local r = math.clamp(s.r, -cl.roll_deg, cl.roll_deg)
	local ym = math.min(cl.yaw_max_deg, cl.yaw_per_pitch * po)
	local y = math.clamp(s.y, -ym, ym)
	if po ~= s.p then
		s.p, s.vp = po, 0
	end
	if r ~= s.r then
		s.r, s.vr = r, 0
	end
	if y ~= s.y then
		s.y, s.vy = y, 0
	end
	local moving = math.abs(s.p) + math.abs(s.r) + math.abs(s.y) > 0.05
		or math.abs(s.vp) + math.abs(s.vr) + math.abs(s.vy) > 0.5
		or math.abs(accel[1]) + math.abs(accel[3]) > 0.5
	local restEntry = fit.badge_rest[tostring(rank)] or fit.badge_rest["1"]
	local rest = if restEntry ~= nil then restEntry.pitch_deg else 0
	return EmployeeLanyardFormulas.clampPitch(fit, rank, rest + po, r, y, 0), r, y, moving
end

return EmployeeLanyardFormulas
