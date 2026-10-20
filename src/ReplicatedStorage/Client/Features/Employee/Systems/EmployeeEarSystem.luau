--!strict
--[=[
	EmployeeEarSystem: springy ears on every employee character near this client's camera (cosmetic, client-only).

	Each tracked employee's LeftEarBase / RightEarBase Motor6D gets its Transform written every step from two
	damped springs per ear (EmployeeEarFormulas), reacting to how the root moved since the last step. The ear
	joints are in no animation, so the Animator never writes them; the owner still calls `step` after the
	frame's animation pass (RunService.PreSimulation, the slot the engine documents for overriding
	Motor6D.Transform) so nothing it does can be overwritten. Employees beyond EAR_RADIUS rest at identity and
	cost one distance check.

	@class EmployeeEarSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local EmployeeEarFormulas = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeeEarFormulas)

type Ear = {
	motor: Motor6D,
	side: number,
	pitch: number,
	pitchVelocity: number,
	outward: number,
	outwardVelocity: number,
}

type Employee = {
	model: Model,
	ears: { Ear },
	phase: number,
	previous: CFrame?,
	vertical: number,
	active: boolean,
	hiding: boolean,
}

export type EmployeeEarState = {
	tracked: number,
	active: number,
}

export type EmployeeEarSystem = {
	-- Starts driving a character's ears; returns the release (which puts them back at rest).
	track: (character: Model) -> () -> (),
	step: (dt: number, focus: Vector3, now: number) -> (),
	getState: () -> EmployeeEarState,
}

local EmployeeEarSystem = {}

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
	for _, joint in EmployeeConstants.EAR_JOINTS do
		if joint.name == instance.Name then
			return joint.side
		end
	end
	return nil
end

-- Adds an ear joint the employee does not drive yet.
local function addEar(employee: Employee, instance: Instance)
	local side = earSide(instance)
	if side == nil or not instance:IsA("Motor6D") then
		return
	end
	for _, ear in employee.ears do
		if ear.motor == instance or ear.side == side then
			return
		end
	end
	table.insert(employee.ears, {
		motor = instance,
		side = side,
		pitch = 0,
		pitchVelocity = 0,
		outward = 0,
		outwardVelocity = 0,
	})
end

local function rest(employee: Employee)
	for _, ear in employee.ears do
		ear.pitch, ear.pitchVelocity, ear.outward, ear.outwardVelocity = 0, 0, 0, 0
		ear.motor.Transform = CFrame.identity
	end
	employee.previous = nil
	employee.vertical = 0
	employee.active = false
	employee.hiding = false
end

-- Whether the character's Player is in a hiding spot.
local function playerIsHiding(model: Model): boolean
	local player = Players:GetPlayerFromCharacter(model)
	return player ~= nil and player:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE) ~= nil
end

-- Picks the springs up where the joints are (the inverse of EmployeeEarFormulas.transform), so nothing snaps.
local function seedFromJoints(employee: Employee)
	for _, ear in employee.ears do
		local x, _, z = ear.motor.Transform:ToEulerAnglesXYZ()
		ear.pitch, ear.pitchVelocity = x, 0
		ear.outward, ear.outwardVelocity = -ear.side * z, 0
	end
	employee.previous = nil
	employee.vertical = 0
end

-- `isHiding` (default: the character's Player has HideConstants.PLAYER_SPOT_ATTRIBUTE set) is injectable for specs.
function EmployeeEarSystem.new(isHiding: ((Model) -> boolean)?): EmployeeEarSystem
	local hidingCheck = isHiding or playerIsHiding
	local employees: { [Model]: Employee } = {}
	local random = Random.new()

	local function stepEmployee(employee: Employee, root: BasePart, dt: number, now: number)
		local current = root.CFrame
		local previous = employee.previous
		employee.previous = current
		if previous == nil then
			return
		end
		local motion = EmployeeEarFormulas.motion(previous, current, dt)
		local kick = EmployeeEarFormulas.landingKick(employee.vertical, motion.vertical)
		employee.vertical = motion.vertical
		for _, ear in employee.ears do
			local pitchTarget, outwardTarget = EmployeeEarFormulas.targets(motion, ear.side, now, employee.phase)
			ear.outwardVelocity += kick
			ear.pitch, ear.pitchVelocity = EmployeeEarFormulas.step(ear.pitch, ear.pitchVelocity, pitchTarget, dt)
			ear.outward, ear.outwardVelocity =
				EmployeeEarFormulas.step(ear.outward, ear.outwardVelocity, outwardTarget, dt)
			ear.motor.Transform = EmployeeEarFormulas.transform(ear.pitch, ear.outward, ear.side)
		end
	end

	return {
		track = function(character)
			local employee: Employee = {
				model = character,
				ears = {},
				phase = random:NextNumber(0, math.pi * 2),
				previous = nil,
				vertical = 0,
				active = false,
				hiding = false,
			}
			for _, descendant in character:GetDescendants() do
				addEar(employee, descendant)
			end
			-- A replicated character can arrive before its ear joints do.
			local connection = character.DescendantAdded:Connect(function(descendant: Instance)
				addEar(employee, descendant)
			end)
			employees[character] = employee
			return function()
				connection:Disconnect()
				if employees[character] == employee then
					employees[character] = nil
				end
				rest(employee)
			end
		end,

		step = function(dt, focus, now)
			for model, employee in employees do
				local root = rootOf(model)
				if hidingCheck(model) then
					-- The hide pose writes these joints: leave them be, and start afresh when it lets go.
					employee.hiding = true
					employee.previous = nil
					employee.active = false
				elseif
					#employee.ears > 0
					and root ~= nil
					and (root.Position - focus).Magnitude <= EmployeeConstants.EAR_RADIUS
				then
					if employee.hiding then
						employee.hiding = false
						seedFromJoints(employee)
					end
					employee.active = true
					stepEmployee(employee, root, dt, now)
				elseif employee.active then
					rest(employee)
				end
			end
		end,

		getState = function()
			local tracked, active = 0, 0
			for _, employee in employees do
				tracked += 1
				if employee.active then
					active += 1
				end
			end
			return { tracked = tracked, active = active }
		end,
	}
end

return EmployeeEarSystem
