--!strict
--[=[
	ReplicationPuppetPool: rigs that draw other players (spec §5.1 "Other clients"; Verdict: pooled, hidden by moving;
	plan R2 Task 11, R4 Task 6).

	Building a puppet costs 25–50 ms and unparenting/reparenting one 10–30 ms (the rig has ~109 parts, spike
	measurement), so puppets are POOLED and HIDDEN BY MOVING them far away, never by unparenting. At most one
	is built per frame (`beginFrame` resets the budget); a body waiting for one simply appears a frame later.

	A puppet: scripts stripped, every part non-colliding / non-query / non-touch, an anchored root moved by
	the client service's single BulkMoveTo, `EvaluateStateMachine = false`, the display name set per player.
	Every puppet has an Animator (created if the template lacks one) so ReplicationRigAnimationSystem can play on it at once.

	Owner affinity (R4): every puppet owns a CustomizationRigOutfitTracker for its whole life, so a pooled puppet KEEPS its
	outfit and its owner label. `acquire` prefers the rig that last drew that player — its record is
	still current, so it needs no redress — and otherwise takes the least-recently-used spare, which
	`CustomizationRigOutfitTracker.assign` marks undressed for the new owner (the next diff takes the old look off).

	Spec-exempt shell (Instances).

	@class ReplicationPuppetPool
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationRigOutfitTracker =
	require(ReplicatedStorage.Client.Features.Customization.State.CustomizationRigOutfitTracker)
local ReplicationOwnerRigSystem =
	require(ReplicatedStorage.Client.Features.Replication.Systems.ReplicationOwnerRigSystem)

local ReplicationPuppetPool = {}

ReplicationPuppetPool.HIDDEN_CFRAME = CFrame.new(0, 50000, 0)
ReplicationPuppetPool.DEFAULT_MAX_IDLE = 16

export type Puppet = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	animator: Animator,
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
}

export type Pool = {
	template: Model,
	container: Folder,
	maxIdle: number,
	idle: { Puppet }, -- index 1 = least recently used
	byOwner: { [number]: Puppet }, -- an idle puppet that last drew this userId
	buildsThisFrame: number,
	built: number,
	affinityHits: number,
	spareReuses: number,
}

--[=[
	@param template Model -- the character rig template
	@param container Folder -- where puppets live
	@param maxIdle number? -- idle puppets kept (default 16)
	@return Pool
]=]
function ReplicationPuppetPool.new(template: Model, container: Folder, maxIdle: number?): Pool
	local cap = maxIdle or ReplicationPuppetPool.DEFAULT_MAX_IDLE
	assert(cap >= 1, "PuppetPool maxIdle must be >= 1")
	return {
		template = template,
		container = container,
		maxIdle = cap,
		idle = {},
		byOwner = {},
		buildsThisFrame = 0,
		built = 0,
		affinityHits = 0,
		spareReuses = 0,
	}
end

local function build(pool: Pool): Puppet?
	local parts = ReplicationOwnerRigSystem.cloneTemplate(pool.template)
	if parts == nil then
		return nil
	end
	local model, humanoid, root = parts.model, parts.humanoid, parts.root
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	humanoid.EvaluateStateMachine = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	local found = humanoid:FindFirstChildOfClass("Animator")
	local animator: Animator = if found ~= nil then found else Instance.new("Animator")
	animator.Parent = humanoid
	root.Anchored = true
	model.Name = "Puppet"
	model:PivotTo(ReplicationPuppetPool.HIDDEN_CFRAME)
	model.Parent = pool.container
	pool.built += 1
	return {
		model = model,
		root = root,
		humanoid = humanoid,
		animator = animator,
		outfit = CustomizationRigOutfitTracker.new(model),
	}
end

--[=[
	Resets the per-frame build budget. Call once per frame before any acquire calls.
	@param pool Pool
]=]
function ReplicationPuppetPool.beginFrame(pool: Pool)
	pool.buildsThisFrame = 0
end

local function forgetOwner(pool: Pool, puppet: Puppet)
	local owner = puppet.outfit.ownerUserId
	if pool.byOwner[owner] == puppet then
		pool.byOwner[owner] = nil
	end
end

--[=[
	A puppet for `player`: the idle rig that last drew them, else the least-recently-used spare, else a
	new one (at most one build per frame; nil means try again next frame). The puppet's CustomizationRigOutfitTracker is
	assigned to the player either way, and it takes their name and display name.
	@param pool Pool
	@param player Player
	@return Puppet?
]=]
function ReplicationPuppetPool.acquire(pool: Pool, player: Player): Puppet?
	local userId = player.UserId
	local puppet: Puppet? = nil
	local owned = pool.byOwner[userId]
	local spare = if owned == nil then pool.idle[1] else nil
	if owned ~= nil then
		pool.byOwner[userId] = nil
		local index = table.find(pool.idle, owned)
		if index ~= nil then
			table.remove(pool.idle, index)
		end
		pool.affinityHits += 1
		puppet = owned
	elseif spare ~= nil then
		table.remove(pool.idle, 1)
		forgetOwner(pool, spare)
		pool.spareReuses += 1
		puppet = spare
	elseif pool.buildsThisFrame < 1 then
		pool.buildsThisFrame += 1
		puppet = build(pool)
	end
	if puppet == nil then
		return nil
	end
	CustomizationRigOutfitTracker.assign(puppet.outfit, userId)
	puppet.model.Name = player.Name
	puppet.humanoid.DisplayName = player.DisplayName
	return puppet
end

--[=[
	Parks a puppet, keeping its outfit and owner label. Over the cap the least-recently-used idle
	puppet is destroyed.
	@param pool Pool
	@param puppet Puppet
]=]
function ReplicationPuppetPool.release(pool: Pool, puppet: Puppet)
	puppet.model:PivotTo(ReplicationPuppetPool.HIDDEN_CFRAME)
	puppet.model.Name = "Puppet"
	puppet.humanoid.DisplayName = ""
	table.insert(pool.idle, puppet)
	pool.byOwner[puppet.outfit.ownerUserId] = puppet
	while #pool.idle > pool.maxIdle do
		local oldest = table.remove(pool.idle, 1)
		if oldest ~= nil then
			forgetOwner(pool, oldest)
			oldest.model:Destroy()
		end
	end
end

--[=[
	Destroys every idle puppet and the container.
	@param pool Pool
]=]
function ReplicationPuppetPool.destroy(pool: Pool)
	for _, puppet in pool.idle do
		puppet.model:Destroy()
	end
	table.clear(pool.idle)
	table.clear(pool.byOwner)
	pool.container:Destroy()
end

return ReplicationPuppetPool
