--!strict
--[=[
	CustomizationDressQueueSystem: spreads dressing over frames, under a per-frame budget (R4 spec, Section 1).

	- One pending job per rig, the NEWEST: a newer version replaces the pending one in place (keeping
	  its turn), an older or equal one is ignored. So a burst of look changes dresses once, to the last.
	- A job carries the rig's owner and version. When its turn comes it is dropped if the rig changed
	  hands (the CustomizationRigOutfitTracker's owner is someone else now) or is already at that version or later — the
	  stale-job rule. The diff is computed THEN, against what the rig wears at that moment, never at
	  request time, so a job can never undo or double a dress that ran before it.
	- `step` runs jobs in request order until the budget is spent, always at least one, so a frame
	  over budget still makes progress. A job is one whole dress: a rig is never left half-dressed
	  across frames.

	Pure: the Instance work is the `dress` callback the caller passes (CustomizationDressSystem in
	production, a recorder in specs).

	@class CustomizationDressQueueSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationOutfitDiffUtils =
	require(ReplicatedStorage.Client.Features.Customization.Utils.CustomizationOutfitDiffUtils)
local CustomizationRigOutfitTracker =
	require(ReplicatedStorage.Client.Features.Customization.State.CustomizationRigOutfitTracker)

export type Job = {
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	ownerUserId: number,
	version: number,
	target: CustomizationOutfitDiffUtils.Outfit,
}

export type Queue = {
	budgetMs: number,
	order: { Job },
	pending: { [CustomizationRigOutfitTracker.CustomizationRigOutfitTracker]: Job },
	applied: number,
	dropped: number,
	lastStepMs: number,
}

local CustomizationDressQueueSystem = {}

CustomizationDressQueueSystem.DEFAULT_BUDGET_MS = 2

--[=[
	@param budgetMs number? -- per-frame budget (default 2 ms)
	@return Queue
]=]
function CustomizationDressQueueSystem.new(budgetMs: number?): Queue
	return {
		budgetMs = budgetMs or CustomizationDressQueueSystem.DEFAULT_BUDGET_MS,
		order = {},
		pending = {},
		applied = 0,
		dropped = 0,
		lastStepMs = 0,
	}
end

--[=[
	Asks for `outfit` to be dressed to `target` at `version`, for `ownerUserId`. Ignored when it would
	not move the rig forward (see the header).
	@param queue Queue
	@param outfit CustomizationRigOutfitTracker.CustomizationRigOutfitTracker
	@param ownerUserId number
	@param version number
	@param target CustomizationOutfitDiffUtils.Outfit
]=]
function CustomizationDressQueueSystem.request(
	queue: Queue,
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	ownerUserId: number,
	version: number,
	target: CustomizationOutfitDiffUtils.Outfit
)
	if outfit.ownerUserId == ownerUserId and version <= outfit.version then
		return
	end
	local existing = queue.pending[outfit]
	if existing ~= nil then
		if existing.ownerUserId == ownerUserId and version <= existing.version then
			return
		end
		existing.ownerUserId = ownerUserId
		existing.version = version
		existing.target = target
		return
	end
	local job: Job = { outfit = outfit, ownerUserId = ownerUserId, version = version, target = target }
	queue.pending[outfit] = job
	table.insert(queue.order, job)
end

--[=[
	The version pending for `outfit`, or nil.
	@param queue Queue
	@param outfit CustomizationRigOutfitTracker.CustomizationRigOutfitTracker
	@return number?
]=]
function CustomizationDressQueueSystem.pendingVersion(
	queue: Queue,
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker
): number?
	local job = queue.pending[outfit]
	return if job ~= nil then job.version else nil
end

--[=[
	Forgets `outfit`'s pending job (the rig is going back to the pool).
	@param queue Queue
	@param outfit CustomizationRigOutfitTracker.CustomizationRigOutfitTracker
]=]
function CustomizationDressQueueSystem.cancel(
	queue: Queue,
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker
)
	local job = queue.pending[outfit]
	if job == nil then
		return
	end
	queue.pending[outfit] = nil
	local index = table.find(queue.order, job)
	if index ~= nil then
		table.remove(queue.order, index)
	end
end

local function isStale(job: Job): boolean
	local outfit = job.outfit
	return outfit.ownerUserId ~= job.ownerUserId or job.version <= outfit.version
end

--[=[
	Runs jobs until the budget is spent (at least one). `dress` applies the ops; the queue then records
	the target as worn.
	@param queue Queue
	@param dress (outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker, ops: { CustomizationOutfitDiffUtils.DiffOp }) -> ()
	@param clock (() -> number)? -- seconds; os.clock by default
	@return number -- jobs applied this step
]=]
function CustomizationDressQueueSystem.step(
	queue: Queue,
	dress: (
		outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
		ops: { CustomizationOutfitDiffUtils.DiffOp }
	) -> (),
	clock: (() -> number)?
): number
	local now = clock or os.clock
	local started = now()
	local applied = 0
	while #queue.order > 0 do
		if applied > 0 and (now() - started) * 1000 >= queue.budgetMs then
			break
		end
		local job = table.remove(queue.order, 1)
		if job == nil then
			break
		end
		queue.pending[job.outfit] = nil
		if isStale(job) then
			queue.dropped += 1
			continue
		end
		dress(job.outfit, CustomizationOutfitDiffUtils.compute(job.outfit.worn, job.target))
		CustomizationRigOutfitTracker.setWorn(job.outfit, job.target, job.version)
		applied += 1
	end
	queue.applied += applied
	queue.lastStepMs = (now() - started) * 1000
	return applied
end

--[=[
	Jobs waiting.
	@param queue Queue
	@return number
]=]
function CustomizationDressQueueSystem.size(queue: Queue): number
	return #queue.order
end

return CustomizationDressQueueSystem
