--!strict
--[=[
	AnimationVacuumHoldSystem: lifts a short holder's right hand to where the full-size vacuum rests on the floor
	(VacuumHoldFormulas: the vacuum's tilt is built into it, the remaining lift is this arm pose).

	While the vacuum is equipped by a holder that needs a lift, one native IKControl (server-created, so every
	client's Animator solves it, like the carry contacts) drives the RightUpperArm → RightHand chain so the hand's
	RightGripAttachment sits at a target fixed to the HumanoidRootPart: lifted from the hang, beside the torso so
	the vacuum's body misses it, oriented so the vacuum stands as it does in a stock avatar's hanging hand. Only
	the right arm is touched; no joint, attachment or Transform is written.

	@class AnimationVacuumHoldSystem
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local VacuumHoldFormulas = require(ServerScriptService.Features.Vacuum.Utils.VacuumHoldFormulas)

export type Controller = { destroy: () -> () }

local AnimationVacuumHoldSystem = {}

local TARGET_NAME = "VacuumHoldTarget"
local IK_NAME = "VacuumHoldIK"

local function part(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

local function attachment(bodyPart: BasePart?, name: string): Attachment?
	local found = if bodyPart ~= nil then bodyPart:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Attachment") then found else nil
end

local function between(a: Attachment?, b: Attachment?): number?
	return if a ~= nil and b ~= nil then (a.Position - b.Position).Magnitude else nil
end

--[=[
	Holds `character`'s right hand `lift` studs above its hang for a vacuum held by `grip` (the Tool's Grip) and
	`halfWidth` studs wide. Nil (nothing created) when there is nothing to lift or the rig lacks a native R15 right
	arm with its grip attachment.
]=]
function AnimationVacuumHoldSystem.hold(character: Model, grip: CFrame, lift: number, halfWidth: number): Controller?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = part(character, "HumanoidRootPart")
	local torso = part(character, "UpperTorso")
	local upper = part(character, "RightUpperArm")
	local lower = part(character, "RightLowerArm")
	local hand = part(character, "RightHand")
	local gripAttachment = attachment(hand, "RightGripAttachment")
	local shoulder = attachment(upper, "RightShoulderRigAttachment")
	local upperSpan = between(shoulder, attachment(upper, "RightElbowRigAttachment"))
	local lowerSpan =
		between(attachment(lower, "RightElbowRigAttachment"), attachment(lower, "RightWristRigAttachment"))
	local handSpan = between(attachment(hand, "RightWristRigAttachment"), gripAttachment)
	if
		not (lift > 0)
		or humanoid == nil
		or humanoid.Health <= 0
		or root == nil
		or torso == nil
		or upper == nil
		or hand == nil
		or gripAttachment == nil
		or shoulder == nil
		or upperSpan == nil
		or lowerSpan == nil
		or handSpan == nil
	then
		return nil
	end
	-- The torso's half-width in root space (its widest corner).
	local torsoFrame = root.CFrame:ToObjectSpace(torso.CFrame)
	local torsoHalf = 0
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = torsoFrame * (Vector3.new(x * torso.Size.X, y * torso.Size.Y, z * torso.Size.Z) / 2)
				torsoHalf = math.max(torsoHalf, corner.X)
			end
		end
	end
	local position = VacuumHoldFormulas.liftTarget(
		root.CFrame:PointToObjectSpace(shoulder.WorldPosition),
		upperSpan + lowerSpan + handSpan,
		lift,
		torsoHalf + halfWidth
	)
	local target = Instance.new("Attachment")
	target.Name = TARGET_NAME
	-- The hand's grip attachment meets the handle at `grip`: an upright handle means this frame.
	target.CFrame = CFrame.new(position) * grip
	target.Parent = root
	local control = Instance.new("IKControl")
	control.Name = IK_NAME
	control.Type = Enum.IKControlType.Transform
	control.ChainRoot = upper
	control.EndEffector = gripAttachment
	control.Target = target
	-- No smoothing: a lagging hand lets the walk bob dip the floor head through the floor (measured on Pippa:
	-- 0.1 s smoothing dipped it 0.15 studs below the floor at walk speed; none keeps it 0.08-0.11 above).
	control.SmoothTime = 0
	control.Weight = 1
	control.Priority = 10
	control.Parent = humanoid

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
			control:Destroy()
			target:Destroy()
		end,
	}
	table.insert(connections, humanoid.Died:Connect(controller.destroy))
	table.insert(connections, character.Destroying:Connect(controller.destroy))
	return controller
end

return AnimationVacuumHoldSystem
