--!strict
--[=[
	EmployeeTailSystem: swinging coat tails on every employee character near this client's camera (cosmetic,
	client-only).

	An outfit can carry tail chains: Bones the outfit fit put under LowerTorso (they carry
	EmployeeConstants.OUTFIT_BONE_ATTRIBUTE), named Tail<side><n>Bone; the highest n of a side only marks where its
	last link ends. Every TAIL_STEP each link end is stepped by EmployeeTailFormulas (pulled toward where the coat
	hangs at rest, kept off the leg parts and above the feet) and each link Bone's Transform is written to match. No
	clip animates these Bones (their names are no body part's), so the Animator never writes them; the owner calls
	`step` after the frame's animation pass, as for the ears. Characters beyond TAIL_RADIUS rest at identity.

	An outfit that asks for SmartBone 2 (EmployeeConstants.TAIL_PHYSICS_ATTRIBUTE on its fitted Outfit folder) is
	handed over instead (EmployeeTailSmartBoneUtils.prepare); SmartBone's own runtime (started by
	EmployeeServiceClient) then drives those bones, and this system only releases them when the character goes.

	@class EmployeeTailSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local EmployeeTailFormulas = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeeTailFormulas)
local EmployeeTailSmartBoneUtils = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeeTailSmartBoneUtils)

type Chain = {
	-- The link Bones in order, then the end marker.
	links: { Bone },
	tip: Bone,
	points: { Vector3 }?,
	previous: { Vector3 },
}

type Tracked = {
	model: Model,
	chains: { Chain },
	dirty: boolean,
	time: number,
	active: boolean,
	-- Whether SmartBone drives this character's tails (its outfit asked for it; EmployeeTailSmartBoneUtils).
	smart: boolean,
}

export type EmployeeTailState = {
	tracked: number,
	active: number,
}

export type EmployeeTailSystem = {
	-- Starts driving a character's tails; returns the release (which puts them back at rest).
	track: (character: Model) -> () -> (),
	step: (dt: number, focus: Vector3) -> (),
	getState: () -> EmployeeTailState,
}

local LEGS = {
	{ name = "LeftUpperLeg", radius = EmployeeConstants.TAIL_UPPER_LEG_RADIUS },
	{ name = "RightUpperLeg", radius = EmployeeConstants.TAIL_UPPER_LEG_RADIUS },
	{ name = "LeftLowerLeg", radius = EmployeeConstants.TAIL_LOWER_LEG_RADIUS },
	{ name = "RightLowerLeg", radius = EmployeeConstants.TAIL_LOWER_LEG_RADIUS },
}
local FEET = { "LeftFoot", "RightFoot" }

local EmployeeTailSystem = {}

local function partOf(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

-- The character's tail chains (sides with at least one link and an end marker), from its outfit Bones.
local function collect(model: Model): { Chain }
	local lower = partOf(model, "LowerTorso")
	if lower == nil then
		return {}
	end
	local sides: { [string]: { { n: number, bone: Bone } } } = {}
	for _, child in lower:GetChildren() do
		if child:IsA("Bone") and child:GetAttribute(EmployeeConstants.OUTFIT_BONE_ATTRIBUTE) == true then
			local side, n = string.match(child.Name, EmployeeConstants.TAIL_BONE_PATTERN)
			local index = if n ~= nil then tonumber(n) else nil
			if side ~= nil and index ~= nil then
				local list = sides[side] or {}
				table.insert(list, { n = index, bone = child })
				sides[side] = list
			end
		end
	end
	local chains: { Chain } = {}
	for _, list in sides do
		table.sort(list, function(a, b)
			return a.n < b.n
		end)
		if #list >= 2 then
			local links: { Bone } = {}
			for i = 1, #list - 1 do
				links[i] = list[i].bone
			end
			table.insert(chains, { links = links, tip = list[#list].bone, points = nil, previous = {} })
		end
	end
	return chains
end

local function restChain(chain: Chain)
	for _, bone in chain.links do
		bone.Transform = CFrame.identity
	end
	chain.points = nil
	chain.previous = {}
end

local function rest(tracked: Tracked)
	for _, chain in tracked.chains do
		restChain(chain)
	end
	tracked.time = 0
	tracked.active = false
end

local function playerIsHiding(model: Model): boolean
	local player = Players:GetPlayerFromCharacter(model)
	return player ~= nil and player:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE) ~= nil
end

-- The step's world for a chain: rest positions on LowerTorso as it is now, the leg capsules and the floor.
local function worldOf(model: Model, lower: BasePart, chain: Chain): (EmployeeTailFormulas.World, { CFrame })
	local scale = model:GetScale()
	local rests: { CFrame } = {}
	for i, bone in chain.links do
		rests[i] = lower.CFrame * bone.CFrame
	end
	local targets: { Vector3 } = {}
	local lengths: { number } = {}
	for i = 1, #chain.links do
		local nextBone = chain.links[i + 1] or chain.tip
		targets[i] = (lower.CFrame * nextBone.CFrame).Position
		lengths[i] = (targets[i] - rests[i].Position).Magnitude
	end
	local capsules: { EmployeeTailFormulas.Capsule } = {}
	for _, leg in LEGS do
		local p = partOf(model, leg.name)
		if p ~= nil then
			local half = p.Size.Y / 2
			table.insert(capsules, {
				a = p.CFrame:PointToWorldSpace(Vector3.new(0, half, 0)),
				b = p.CFrame:PointToWorldSpace(Vector3.new(0, -half, 0)),
				radius = leg.radius * scale,
			})
		end
	end
	local floor = -math.huge
	local sole = math.huge
	for _, name in FEET do
		local foot = partOf(model, name)
		if foot ~= nil then
			sole = math.min(sole, foot.Position.Y - foot.Size.Y / 2)
		end
	end
	if sole < math.huge then
		floor = sole + EmployeeConstants.TAIL_FLOOR_CLEARANCE * scale
	end
	return {
		anchor = rests[1].Position,
		targets = targets,
		lengths = lengths,
		capsules = capsules,
		floor = floor,
		scale = scale,
	},
		rests
end

-- `isHiding` (default: the character's Player has HideConstants.PLAYER_SPOT_ATTRIBUTE set) is injectable for specs.
function EmployeeTailSystem.new(isHiding: ((Model) -> boolean)?): EmployeeTailSystem
	local hidingCheck: (Model) -> boolean = isHiding or playerIsHiding
	local trackedByModel: { [Model]: Tracked } = {}

	local function stepChain(model: Model, lower: BasePart, chain: Chain, steps: number)
		local world, rests = worldOf(model, lower, chain)
		local seeded = chain.points
		local current: { Vector3 } = if seeded ~= nil then seeded else table.clone(world.targets)
		local previous: { Vector3 } = if seeded ~= nil then chain.previous else table.clone(world.targets)
		for _ = 1, steps do
			current, previous = EmployeeTailFormulas.step(current, previous, world)
		end
		chain.points, chain.previous = current, previous
		local head = world.anchor
		for i, bone in chain.links do
			bone.Transform = EmployeeTailFormulas.transform(rests[i], world.targets[i], head, current[i])
			head = current[i]
		end
	end

	return {
		track = function(character)
			local tracked: Tracked =
				{ model = character, chains = {}, dirty = true, time = 0, active = false, smart = false }
			local function markDirty(instance: Instance)
				if instance:IsA("Bone") or instance.Name == EmployeeConstants.OUTFIT_FOLDER then
					tracked.dirty = true
				end
			end
			local added = character.DescendantAdded:Connect(markDirty)
			local removing = character.DescendantRemoving:Connect(markDirty)
			trackedByModel[character] = tracked
			return function()
				added:Disconnect()
				removing:Disconnect()
				if trackedByModel[character] == tracked then
					trackedByModel[character] = nil
				end
				rest(tracked)
				if tracked.smart then
					EmployeeTailSmartBoneUtils.release(character)
				end
			end
		end,

		step = function(dt, focus)
			for model, tracked in trackedByModel do
				if tracked.dirty then
					tracked.dirty = false
					rest(tracked)
					if EmployeeTailSmartBoneUtils.wantsSmartBone(model) then
						-- A fresh fit (flat chains again) is handed over; our own nesting changes nothing.
						if EmployeeTailSmartBoneUtils.prepare(model) then
							tracked.smart = true
						end
						tracked.chains = {}
					else
						if tracked.smart then
							EmployeeTailSmartBoneUtils.release(model)
							tracked.smart = false
						end
						tracked.chains = collect(model)
					end
				end
				local lower = partOf(model, "LowerTorso")
				if #tracked.chains == 0 or lower == nil then
					continue
				end
				if hidingCheck(model) or (lower.Position - focus).Magnitude > EmployeeConstants.TAIL_RADIUS then
					if tracked.active then
						rest(tracked)
					end
					continue
				end
				tracked.active = true
				tracked.time =
					math.min(tracked.time + dt, EmployeeConstants.TAIL_STEP * EmployeeConstants.TAIL_MAX_STEPS)
				local steps = math.floor(tracked.time / EmployeeConstants.TAIL_STEP + 1e-6)
				if steps <= 0 then
					continue
				end
				tracked.time -= steps * EmployeeConstants.TAIL_STEP
				for _, chain in tracked.chains do
					stepChain(model, lower, chain, steps)
				end
			end
		end,

		getState = function()
			local count, active = 0, 0
			for _, tracked in trackedByModel do
				count += 1
				if tracked.active then
					active += 1
				end
			end
			return { tracked = count, active = active }
		end,
	}
end

return EmployeeTailSystem
