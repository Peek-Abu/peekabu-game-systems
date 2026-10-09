--!strict
--[=[
	VoiceWiringTracker: which remote players' voices are wired on this client, and how; returns the actions
	to take. Pure: VoiceServiceClient performs them on real instances.

	A speaker is wired when their input exists, their route is not `none`, and — for a `spatial` route —
	their Head exists. Any change to the input, the route, or (for a spatial route) the head rewires.

	@class VoiceWiringTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VoiceTypes = require(ReplicatedStorage.Shared.Features.Voice.Data.VoiceTypes)

type Route = VoiceTypes.Route

export type Action =
	{ kind: "wire", userId: number, route: Route, input: Instance, head: BasePart? }
	| {
		kind: "unwire",
		userId: number,
	}

type Entry = {
	input: Instance?,
	head: BasePart?,
	route: Route,
	-- The (route, input, head) currently wired; nil when unwired.
	wired: { route: Route, input: Instance, head: BasePart? }?,
}

export type VoiceWiringTracker = {
	setInput: (self: VoiceWiringTracker, userId: number, input: Instance?) -> { Action },
	setHead: (self: VoiceWiringTracker, userId: number, head: BasePart?) -> { Action },
	setRoute: (self: VoiceWiringTracker, userId: number, route: Route) -> { Action },
	remove: (self: VoiceWiringTracker, userId: number) -> { Action },
	wiredCount: (self: VoiceWiringTracker) -> number,
}

local VoiceWiringTracker = {}

function VoiceWiringTracker.new(): VoiceWiringTracker
	local entries: { [number]: Entry } = {}

	local function entryFor(userId: number): Entry
		local entry = entries[userId]
		if entry == nil then
			entry = { input = nil, head = nil, route = "none", wired = nil }
			entries[userId] = entry
		end
		return entry
	end

	local function reconcile(userId: number, entry: Entry): { Action }
		local actions: { Action } = {}
		local input = entry.input
		local wantHead = if entry.route == "spatial" then entry.head else nil
		local wanted = input ~= nil and entry.route ~= "none" and (entry.route ~= "spatial" or wantHead ~= nil)
		local current = entry.wired
		if
			current ~= nil
			and wanted
			and current.route == entry.route
			and current.input == input
			and current.head == wantHead
		then
			return actions
		end
		if current ~= nil then
			table.insert(actions, { kind = "unwire", userId = userId })
			entry.wired = nil
		end
		if wanted and input ~= nil then
			table.insert(
				actions,
				{ kind = "wire", userId = userId, route = entry.route, input = input, head = wantHead }
			)
			entry.wired = { route = entry.route, input = input, head = wantHead }
		end
		return actions
	end

	local tracker: VoiceWiringTracker = {
		setInput = function(_self, userId, input)
			local entry = entryFor(userId)
			entry.input = input
			return reconcile(userId, entry)
		end,

		setHead = function(_self, userId, head)
			local entry = entryFor(userId)
			entry.head = head
			return reconcile(userId, entry)
		end,

		setRoute = function(_self, userId, route)
			local entry = entryFor(userId)
			entry.route = route
			return reconcile(userId, entry)
		end,

		remove = function(_self, userId)
			local entry = entries[userId]
			entries[userId] = nil
			if entry == nil or entry.wired == nil then
				return {}
			end
			return { { kind = "unwire", userId = userId } }
		end,

		wiredCount = function(_self)
			local count = 0
			for _, entry in entries do
				if entry.wired ~= nil then
					count += 1
				end
			end
			return count
		end,
	}
	return tracker
end

return VoiceWiringTracker
