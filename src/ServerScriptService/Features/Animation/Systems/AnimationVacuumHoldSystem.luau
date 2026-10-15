--!strict
--[=[
	AnimationVacuumHoldSystem: holds the backpack vacuum's wand with the arms (VacuumHoldFormulas.hold).

	While the wand is equipped, native IKControls (server-created, so every client's Animator solves them, like
	the carry contacts) drive the arms to targets fixed to the HumanoidRootPart: the right arm's
	RightGripAttachment to the hold's grip frame on the wand's GripUpper (Transform: position and the hand turned
	along the forearm, so the elbow bends and the wrist does not), the LeftGripAttachment onto the wand's
	GripLower, lower down the wand, when it reaches (Transform too: a Position-only solve left Pippa's left hand
	~0.75 studs off its target in Studio). The targets are where the wand skin's grip Attachments are (the grip
	contract, VacuumVisualSystem), planned once per holder; they are not the attachments themselves, since the
	wand is welded to the right hand it would be steering.
	Poles bend the elbows outward and down. Fixed to the root (which does not bob), the floor head glides at a
	constant height while the legs walk. No smoothing: a lagging hand lets the floor head dip into the floor.
	No joint, attachment or Transform of the rig is written.

	@class AnimationVacuumHoldSystem
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local VacuumHoldFormulas = require(ServerScriptService.Features.Vacuum.Utils.VacuumHoldFormulas)

export type Controller = { destroy: () -> () }

local AnimationVacuumHoldSystem = {}

local PRIORITY = 10

local function part(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

local function attachment(bodyPart: BasePart?, name: string): Attachment?
	local found = if bodyPart ~= nil then bodyPart:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Attachment") then found else nil
end

--[=[
	Holds `character`'s arms to `hold`. Nil (nothing created) when it is dead or lacks a native R15 right arm
	with its grip attachment.
]=]
function AnimationVacuumHoldSystem.hold(character: Model, hold: VacuumHoldFormulas.Hold): Controller?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = part(character, "HumanoidRootPart")
	local rightUpper = part(character, "RightUpperArm")
	local rightGrip = attachment(part(character, "RightHand"), "RightGripAttachment")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or rightUpper == nil or rightGrip == nil then
		return nil
	end
	local created: { Instance } = {}
	local function marker(name: string, frame: CFrame): Attachment
		local target = Instance.new("Attachment")
		target.Name = name
		target.CFrame = frame
		target.Parent = root
		table.insert(created, target)
		return target
	end
	local function control(
		name: string,
		kind: Enum.IKControlType,
		chainRoot: BasePart,
		effector: Attachment,
		target: Attachment,
		pole: Attachment
	)
		local ik = Instance.new("IKControl")
		ik.Name = name
		ik.Type = kind
		ik.ChainRoot = chainRoot
		ik.EndEffector = effector
		ik.Target = target
		ik.Pole = pole
		ik.SmoothTime = 0
		ik.Weight = 1
		ik.Priority = PRIORITY
		ik.Parent = humanoid
		table.insert(created, ik)
	end
	control(
		"VacuumHoldIK",
		Enum.IKControlType.Transform,
		rightUpper,
		rightGrip,
		marker("VacuumHoldTarget", hold.grip),
		marker("VacuumHoldPole", CFrame.new(hold.rightPole))
	)
	local leftUpper = part(character, "LeftUpperArm")
	local leftGrip = attachment(part(character, "LeftHand"), "LeftGripAttachment")
	local left = hold.left
	if left ~= nil and leftUpper ~= nil and leftGrip ~= nil then
		control(
			"VacuumSupportIK",
			Enum.IKControlType.Transform,
			leftUpper,
			leftGrip,
			marker("VacuumSupportTarget", left),
			marker("VacuumSupportPole", CFrame.new(hold.leftPole))
		)
	end

	local connections: { RBXScriptConnection } = {}
	local destroyed = false
	local controller: Controller
	controller = {
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			for _, instance in created do
				instance:Destroy()
			end
			table.clear(created)
		end,
	}
	table.insert(connections, humanoid.Died:Connect(controller.destroy))
	table.insert(connections, character.Destroying:Connect(controller.destroy))
	return controller
end

return AnimationVacuumHoldSystem
