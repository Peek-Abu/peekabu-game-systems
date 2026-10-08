--!strict
--[=[
	ReplicationOwnerRigSystem: builds and tears down this client's own body (spec §5.1 option A, owner client; plan R2
	Task 10).

	`build` clones the server-published rig template, makes it `LocalPlayer.Character` BEFORE parenting it
	(spike CP1: the order the engine expects), sets the camera subject explicitly, binds locomotion, mirrors
	the server-owned health from the public slice onto the Humanoid (display only — health is server state),
	and reports the local fall-plane destroy (`onFell`), which the server answers with a respawn.

	Spec-exempt shell (needs a live rig, camera and Humanoid).

	@class ReplicationOwnerRigSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local AnimationLocomotionHumanoidSystem =
	require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationLocomotionHumanoidSystem)

export type Rig = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	epoch: number,
	cleanup: () -> (),
}

export type RigParts = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
}

local ReplicationOwnerRigSystem = {}

--[=[
	Clone the rig template and find its Humanoid and root. The one place that knows what a usable rig is: the
	owner build below and the remote puppets (R2 Task 11) both go through it. The clone is unparented.
]=]
function ReplicationOwnerRigSystem.cloneTemplate(template: Model): (RigParts?, string?)
	local model = template:Clone()
	if not model:IsA("Model") then -- Instance:Clone() is typed Instance
		model:Destroy()
		return nil, "the rig template did not clone as a Model"
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or not humanoid:IsA("Humanoid") or root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return nil, "the rig template has no Humanoid / HumanoidRootPart"
	end
	return { model = model, humanoid = humanoid, root = root }, nil
end

function ReplicationOwnerRigSystem.build(
	template: Model,
	position: Vector3,
	epoch: number,
	onFell: () -> ()
): (Rig?, string?)
	local localPlayer = Players.LocalPlayer
	local parts, cloneError = ReplicationOwnerRigSystem.cloneTemplate(template)
	if parts == nil then
		return nil, cloneError
	end
	local model, humanoid, root = parts.model, parts.humanoid, parts.root
	model.Name = localPlayer.Name
	model:PivotTo(CFrame.new(position))
	-- Character first, then parent (spike CP1).
	localPlayer.Character = model
	model.Parent = Workspace
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraSubject = humanoid
	end

	local janitor = Janitor.new()
	local alive = true

	-- Health mirror (display only): the server's public entry for this player.
	local key = StateSyncConstants.publicEntryKey(localPlayer.UserId)
	local function mirror(map: PublicPlayerTypes.PublicPlayerMap)
		local entry = map[key]
		if entry ~= nil then
			humanoid.MaxHealth = entry.maxHealth
			humanoid.Health = math.min(entry.health, entry.maxHealth)
		end
	end
	mirror(StateSyncClientStore.publicPlayers())
	janitor:Add(Charm.subscribe(StateSyncClientStore.publicPlayers, mirror), true)

	-- The engine destroys the root locally below FallenPartsDestroyHeight.
	janitor:Add(
		root.AncestryChanged:Connect(function(_, parent)
			if parent == nil and alive then
				onFell()
			end
		end),
		"Disconnect"
	)

	-- Locomotion may yield (Animator lookup): bind in a thread, unbind at once if the rig died meanwhile.
	task.spawn(function()
		local unbind = AnimationLocomotionHumanoidSystem.bind(model)
		if unbind == nil then
			return
		end
		if alive then
			janitor:Add(unbind, true)
		else
			unbind()
		end
	end)

	local function cleanup()
		alive = false
		janitor:Destroy()
		if localPlayer.Character == model then
			localPlayer.Character = nil
		end
		model:Destroy()
	end

	return { model = model, humanoid = humanoid, root = root, epoch = epoch, cleanup = cleanup }, nil
end

function ReplicationOwnerRigSystem.destroy(rig: Rig)
	rig.cleanup()
end

return ReplicationOwnerRigSystem
