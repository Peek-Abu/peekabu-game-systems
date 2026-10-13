--!strict
--[=[
	ToonEarSystem: springy ears on every toon character near this client's camera (cosmetic, client-only).

	Each tracked toon's LeftEarBase / RightEarBase Motor6D gets its Transform written every step from two
	damped springs per ear (ToonEarFormulas), reacting to how the root moved since the last step. The ear
	joints are in no animation, so the Animator never writes them; the owner still calls `step` after the
	frame's animation pass (RunService.PreSimulation, the slot the engine documents for overriding
	Motor6D.Transform) so nothing it does can be overwritten. Toons beyond EAR_RADIUS rest at identity and
	cost one distance check.

	@class ToonEarSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToonConstants = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonConstants)
local ToonEarFormulas = require(ReplicatedStorage.Client.Features.Toon.Utils.ToonEarFormulas)

type Ear = {
	motor: Motor6D,
	side: number,
	pitch: number,
	pitchVelocity: number,
	outward: number,
	outwardVelocity: number,
}

type Toon = {
	model: Model,
	ears: { Ear },
	phase: number,
	previous: CFrame?,
	vertical: number,
	active: boolean,
}

export type ToonEarState = {
	tracked: number,
	active: number,
}

export type ToonEarSystem = {
	-- Starts driving a character's ears; returns the release (which puts them back at rest).
	track: (character: Model) -> () -> (),
	step: (dt: number, focus: Vector3, now: number) -> (),
	getState: () -> ToonEarState,
}

local ToonEarSystem = {}

local function rootOf(model: Model): BasePart?
	local root = model.PrimaryPart
	if root ~= nil then
		return root
	end
	local found = model:FindFirstChild("HumanoidRootPart")
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

-- The ear joint's side, or nil when `instance` is not an ear joint.
local function earSide(instance: Instance): number?
	if not instance:IsA("Motor6D") then
		return nil
	end
	for _, joint in ToonConstants.EAR_JOINTS do
		if joint.name == instance.Name then
			return joint.side
		end
	end
	return nil
end

-- Adds an ear joint the toon does not drive yet.
local function addEar(toon: Toon, instance: Instance)
	local side = earSide(instance)
	if side == nil or not instance:IsA("Motor6D") then
		return
	end
	for _, ear in toon.ears do
		if ear.motor == instance or ear.side == side then
			return
		end
	end
	table.insert(toon.ears, {
		motor = instance,
		side = side,
		pitch = 0,
		pitchVelocity = 0,
		outward = 0,
		outwardVelocity = 0,
	})
end

local function rest(toon: Toon)
	for _, ear in toon.ears do
		ear.pitch, ear.pitchVelocity, ear.outward, ear.outwardVelocity = 0, 0, 0, 0
		ear.motor.Transform = CFrame.identity
	end
	toon.previous = nil
	toon.vertical = 0
	toon.active = false
end

function ToonEarSystem.new(): ToonEarSystem
	local toons: { [Model]: Toon } = {}
	local random = Random.new()

	local function stepToon(toon: Toon, root: BasePart, dt: number, now: number)
		local current = root.CFrame
		local previous = toon.previous
		toon.previous = current
		if previous == nil then
			return
		end
		local motion = ToonEarFormulas.motion(previous, current, dt)
		local kick = ToonEarFormulas.landingKick(toon.vertical, motion.vertical)
		toon.vertical = motion.vertical
		for _, ear in toon.ears do
			local pitchTarget, outwardTarget = ToonEarFormulas.targets(motion, ear.side, now, toon.phase)
			ear.outwardVelocity += kick
			ear.pitch, ear.pitchVelocity = ToonEarFormulas.step(ear.pitch, ear.pitchVelocity, pitchTarget, dt)
			ear.outward, ear.outwardVelocity = ToonEarFormulas.step(ear.outward, ear.outwardVelocity, outwardTarget, dt)
			ear.motor.Transform = ToonEarFormulas.transform(ear.pitch, ear.outward, ear.side)
		end
	end

	return {
		track = function(character)
			local toon: Toon = {
				model = character,
				ears = {},
				phase = random:NextNumber(0, math.pi * 2),
				previous = nil,
				vertical = 0,
				active = false,
			}
			for _, descendant in character:GetDescendants() do
				addEar(toon, descendant)
			end
			-- A replicated character can arrive before its ear joints do.
			local connection = character.DescendantAdded:Connect(function(descendant: Instance)
				addEar(toon, descendant)
			end)
			toons[character] = toon
			return function()
				connection:Disconnect()
				if toons[character] == toon then
					toons[character] = nil
				end
				rest(toon)
			end
		end,

		step = function(dt, focus, now)
			for model, toon in toons do
				local root = rootOf(model)
				if #toon.ears > 0 and root ~= nil and (root.Position - focus).Magnitude <= ToonConstants.EAR_RADIUS then
					toon.active = true
					stepToon(toon, root, dt, now)
				elseif toon.active then
					rest(toon)
				end
			end
		end,

		getState = function()
			local tracked, active = 0, 0
			for _, toon in toons do
				tracked += 1
				if toon.active then
					active += 1
				end
			end
			return { tracked = tracked, active = active }
		end,
	}
end

return ToonEarSystem
