--!strict
--[=[
	UIWorldSuppression: the pure core that turns "which scenes are open" into "what the world
	suppresses", refcounted so co-open and nested scenes compose.

	The old game opened a panel with six side effects fired imperatively and NOT refcounted, so nested
	panels could not compose — last write won, and its own refcounted `pushInputLock`/`popInputLock`
	went unused by the UI path. This is that lock, done right: the union of every stacked scene's
	SuppressionRecord, with a per-capability count. A capability engages when its count goes 0→1 and
	releases when it returns to 0, so a suppression requested by two scenes survives closing one.

	Injectable (`resolveScene`, `warn`) so it is fully testable with no Instances; the real handler —
	just the mouse, touching UserInputService — lives in the exempt UISuppression shell. Every other
	capability (blur/movement/cameraState) is handled by the system that owns it (Input registers
	`movement`, Camera `cameraState`); one with no handler yet is logged ONCE, never silently dropped, until its owning system
	registers one via `registerHandler`. That is the seam that keeps those systems slottable.

	@class UIWorldSuppression
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)

type SuppressionRecord = SceneRegistry.SuppressionRecord

--[=[
	Applies and releases one capability's world side effects. Both are called at most once per
	transition (the refcount guarantees engage fires only 0→1, disengage only →0).
]=]
export type Handler = {
	engage: () -> (),
	disengage: () -> (),
}

export type SuppressionCore = {
	registerHandler: (capability: string, handler: Handler) -> (),
	reconcile: (activeScenes: { string }) -> (),
	counts: () -> { [string]: number },
}

-- The requested capabilities of a record, read field-by-field (not dynamic indexing) so this stays
-- --!strict with no casts. A string field (cameraState) counts as requested when
-- present; a boolean field when true.
local function requestedCaps(record: SuppressionRecord): { string }
	local caps: { string } = {}
	if record.mouse then
		table.insert(caps, "mouse")
	end
	if record.blur then
		table.insert(caps, "blur")
	end
	if record.movement then
		table.insert(caps, "movement")
	end
	if record.cameraState ~= nil then
		table.insert(caps, "cameraState")
	end
	return caps
end

local UIWorldSuppression = {}

--[=[
	Builds a suppression core.
	@param resolveScene (name: string) -> SuppressionRecord? -- a scene name to its declared suppression
	@param warn (message: string) -> () -- called once per capability that is requested with no handler
	@return SuppressionCore
]=]
function UIWorldSuppression.new(
	resolveScene: (name: string) -> SuppressionRecord?,
	warn: (message: string) -> ()
): SuppressionCore
	local handlers: { [string]: Handler } = {}
	local applied: { [string]: boolean } = {} -- capabilities currently engaged (count > 0)
	local counts: { [string]: number } = {}
	local warnedUnhandled: { [string]: boolean } = {}

	local function engage(capability: string)
		local handler = handlers[capability]
		if handler ~= nil then
			handler.engage()
		elseif not warnedUnhandled[capability] then
			warnedUnhandled[capability] = true
			warn(
				`suppression capability "{capability}" was requested but has no handler yet — `
					.. `declared for a future phase (Input/Camera register it later)`
			)
		end
	end

	local function disengage(capability: string)
		local handler = handlers[capability]
		if handler ~= nil then
			handler.disengage()
		end
	end

	local function registerHandler(capability: string, handler: Handler)
		handlers[capability] = handler
		-- Late registration adopts already-active state: if the capability is engaged right now
		-- (e.g. a scene requested it before Input/Camera booted), apply it immediately.
		if applied[capability] then
			handler.engage()
		end
	end

	local function reconcile(activeScenes: { string })
		local newCounts: { [string]: number } = {}
		for _, name in activeScenes do
			local record = resolveScene(name)
			if record ~= nil then
				for _, capability in requestedCaps(record) do
					newCounts[capability] = (newCounts[capability] or 0) + 1
				end
			end
		end

		-- Engage capabilities newly desired this pass.
		for capability in newCounts do
			if not applied[capability] then
				applied[capability] = true
				engage(capability)
			end
		end

		-- Disengage capabilities no longer desired. Collect first, then mutate — modifying `applied`
		-- while iterating it is fragile.
		local toDisengage: { string } = {}
		for capability in applied do
			if newCounts[capability] == nil then
				table.insert(toDisengage, capability)
			end
		end
		for _, capability in toDisengage do
			applied[capability] = nil
			disengage(capability)
		end

		counts = newCounts
	end

	local function getCounts(): { [string]: number }
		return table.clone(counts)
	end

	return {
		registerHandler = registerHandler,
		reconcile = reconcile,
		counts = getCounts,
	}
end

return UIWorldSuppression
