--!strict
--[=[
	EmployeeSpawnSystem: makes every player spawn as an employee, while keeping the character a native Humanoid
	character (death, ragdoll, spectate, the Animate script, tools, carry IK and interaction all keep
	working unchanged).

	`install` copies the employee's art template (ReplicatedStorage, art-owned, never in the source tree) into
	StarterPlayer as `StarterCharacter` at server boot, and turns off LoadCharacterAppearance so the engine
	does not dress it in the player's avatar. This is runtime-only: Rojo never owns StarterCharacter or that
	property (StarterPlayer's node only mounts the two script folders and DevCameraOcclusionMode), so a sync
	cannot fight it and a published place does not need it saved in.

	`prepare` fills in what an exported employee rig lacks and a stock R15 avatar has (EmployeeRigUtils): the
	`<Joint>RigAttachment` pairs at every joint pivot (BuildRigFromAttachments, the carry IK's arm reach),
	both grip attachments (where a Tool's handle is welded), and an Animator. It only adds: anything the
	art authored wins.

	@class EmployeeSpawnSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeeRigUtils = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeeRigUtils)

local GRIP_SIDES: { EmployeeRigUtils.Side } = { "Left", "Right" }

local EmployeeSpawnSystem = {}

local function basePart(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

local function place(model: Model, placement: EmployeeRigUtils.Placement): boolean
	local part = basePart(model, placement.part)
	if part == nil or part:FindFirstChild(placement.name) ~= nil then
		return false
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = placement.name
	attachment.CFrame = placement.cframe
	attachment.Parent = part
	return true
end

--[=[
	Adds the missing rig attachments, grip attachments and Animator to an employee model.
	@return number -- how many instances were added (0 when already prepared)
]=]
function EmployeeSpawnSystem.prepare(model: Model): number
	local joints: { EmployeeRigUtils.Joint } = {}
	local wrists: { [string]: Motor6D } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local part0, part1 = descendant.Part0, descendant.Part1
			if part0 ~= nil and part1 ~= nil and part0:IsDescendantOf(model) and part1:IsDescendantOf(model) then
				table.insert(joints, {
					name = descendant.Name,
					part0 = part0.Name,
					part1 = part1.Name,
					c0 = descendant.C0,
					c1 = descendant.C1,
				})
				if descendant.Name == "LeftWrist" or descendant.Name == "RightWrist" then
					wrists[descendant.Name] = descendant
				end
			end
		end
	end
	local added = 0
	for _, placement in EmployeeRigUtils.rigAttachments(joints) do
		if place(model, placement) then
			added += 1
		end
	end
	for _, side: EmployeeRigUtils.Side in GRIP_SIDES do
		local hand = basePart(model, side .. "Hand")
		local wrist: Motor6D? = wrists[side .. "Wrist"]
		if hand ~= nil and wrist ~= nil and place(model, EmployeeRigUtils.gripAttachment(side, hand.Size, wrist.C1)) then
			added += 1
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and humanoid:FindFirstChildOfClass("Animator") == nil then
		Instance.new("Animator").Parent = humanoid
		added += 1
	end
	return added
end

local function resolve(root: Instance, path: { string }): Instance?
	local current: Instance? = root
	for _, name in path do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

--[=[
	Installs a prepared copy of the employee's template as `target`'s StarterCharacter (target is StarterPlayer
	in the game). Replaces a StarterCharacter an earlier install left, never an authored one.
	@param source Where the template path starts (ReplicatedStorage in the game).
	@return (ok, reason?)
]=]
function EmployeeSpawnSystem.install(def: EmployeeRegistry.EmployeeDef, source: Instance, target: Instance): (boolean, string?)
	local template = resolve(source, def.templatePath)
	if template == nil or not template:IsA("Model") then
		return false, `employee template {table.concat(def.templatePath, ".")} is missing or not a Model`
	end
	local existing = target:FindFirstChild(EmployeeConstants.STARTER_CHARACTER_NAME)
	if existing ~= nil and existing:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) == nil then
		return false, "an authored StarterCharacter is already in place; not replacing it"
	end
	local starter = template:Clone()
	starter.Name = EmployeeConstants.STARTER_CHARACTER_NAME
	starter:SetAttribute(EmployeeConstants.NAME_ATTRIBUTE, def.name)
	EmployeeSpawnSystem.prepare(starter)
	if existing ~= nil then
		existing:Destroy()
	end
	starter.Parent = target
	if target:IsA("StarterPlayer") then
		target.LoadCharacterAppearance = false
	end
	return true, nil
end

return EmployeeSpawnSystem
