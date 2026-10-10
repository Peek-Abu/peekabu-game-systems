--!strict
--[=[
	CargoPocketSystem: the two pockets (Cleanup Crew spec §4 "Pockets: 2 slots, tiny items only"; §6.3 the
	`pocket` and `swap` requests). `pocket` moves a tiny hands item into a pocket (claim, record, release from
	Carry, destroy); `swap` takes the newest pocketed item into empty hands, or trades a tiny hands item for the
	oldest pocketed one (CargoHandlingRules.swapPlan); `take` empties them for a Load; `scatter` puts a player's
	pockets back in the world around `origin`, else where they stand, were last seen (sampled every
	ROOT_SAMPLE_INTERVAL), or the shift container's centre, and takes nothing it cannot put back. Pockets are
	published as the public `pocket1` / `pocket2` fields.

	M1 final review: the scatter fallback. M2: the pocket list and requests moved here from CargoServiceServer
	(the service was at the 400-line cap). Spec-exempt shell (Carry, Instances, Players, Heartbeat); the
	decisions are the specced CargoHandlingRules and CargoPocketTracker.

	@class CargoPocketSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CargoServer = ServerScriptService.Features.Cargo
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoHandlingRules = require(CargoShared.Rules.CargoHandlingRules)
local CargoClaimTracker = require(CargoServer.State.CargoClaimTracker)
local CargoPocketTracker = require(CargoServer.State.CargoPocketTracker)
local CargoSpawnSystem = require(CargoServer.Systems.CargoSpawnSystem)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

type CargoEntry = CargoTypes.CargoEntry

export type Deps = {
	claims: CargoClaimTracker.CargoClaimTracker,
	spawner: CargoSpawnSystem.CargoSpawnSystem,
	-- The shift's container (where items come back into the world); nil = no shift.
	container: () -> Instance?,
	-- What a floor probe looks through (every character).
	ignore: () -> { Instance },
	entryOf: (object: Instance) -> CargoEntry?,
	idOf: (object: Instance) -> number?,
}

export type Counts = { pocketed: number, swapped: number, scattered: number }

export type CargoPocketSystem = {
	-- Samples every character's position now and then; returns the disconnect.
	start: (self: CargoPocketSystem) -> () -> (),
	forget: (self: CargoPocketSystem, userId: number) -> (),
	pocket: (self: CargoPocketSystem, player: Player) -> (boolean, string?),
	swap: (self: CargoPocketSystem, player: Player) -> (boolean, string?),
	list: (self: CargoPocketSystem, userId: number) -> { CargoEntry },
	take: (self: CargoPocketSystem, userId: number) -> { CargoEntry },
	scatter: (self: CargoPocketSystem, player: Player, origin: Vector3?) -> (),
	clear: (self: CargoPocketSystem) -> (),
	counts: (self: CargoPocketSystem) -> Counts,
}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function centreOf(container: Instance?): Vector3?
	if container == nil then
		return nil
	end
	if container:IsA("Model") then
		return container:GetPivot().Position
	elseif container:IsA("BasePart") then
		return container.Position
	end
	return nil
end

local CargoPocketSystem = {}

function CargoPocketSystem.new(deps: Deps): CargoPocketSystem
	local pockets = CargoPocketTracker.new()
	local known: { [number]: Vector3 } = {}
	local counts: Counts = { pocketed = 0, swapped = 0, scattered = 0 }

	local function publish(userId: number)
		local list = pockets:list(userId)
		for index, field in CargoConstants.PUBLIC_POCKET_FIELDS do
			local entry = list[index]
			if entry ~= nil then
				StateSyncPublicPlayerStore.set(userId, { [field] = entry.kind })
			else
				StateSyncPublicPlayerStore.clearField(userId, field)
			end
		end
	end

	-- Brings a pocketed entry back at the player's feet and into their hands a frame later (Carry adopts a new
	-- item when its tag lands). If the hands filled meanwhile, it stays on the floor.
	local function intoHands(player: Player, entry: CargoEntry, root: BasePart, parent: Instance)
		local floor = deps.spawner:floorUnder(root.Position, deps.ignore())
		local part = deps.spawner:spawn(entry.kind, floor, parent, { value = entry.value })
		task.defer(function()
			if part.Parent ~= nil and player.Parent ~= nil and CarryServiceServer:getCarried(player) == nil then
				CarryServiceServer:pickUp(player, part)
			end
		end)
	end

	local system: CargoPocketSystem
	system = {
		start = function(_self)
			local elapsed = 0
			local connection = RunService.Heartbeat:Connect(function(deltaTime)
				elapsed += deltaTime
				if elapsed < CargoConstants.ROOT_SAMPLE_INTERVAL then
					return
				end
				elapsed = 0
				for _, player in Players:GetPlayers() do
					local root = rootOf(player)
					if root ~= nil then
						known[player.UserId] = root.Position
					end
				end
			end)
			return function()
				connection:Disconnect()
			end
		end,

		forget = function(_self, userId)
			known[userId] = nil
		end,

		pocket = function(_self, player)
			local item = CarryServiceServer:getCarried(player)
			local entry = if item ~= nil then deps.entryOf(item) else nil
			local id = if item ~= nil then deps.idOf(item) else nil
			local def = if entry ~= nil then CargoRegistry.get(entry.kind) else nil
			local ok, reason = CargoHandlingRules.canPocket(def, pockets:count(player.UserId))
			if not ok then
				return false, reason
			end
			if item == nil or entry == nil or id == nil or not deps.claims:claim(id) then
				return false, "nothing to pocket"
			end
			pockets:add(player.UserId, entry)
			CarryServiceServer:forceDrop(player, "forced")
			item:Destroy()
			publish(player.UserId)
			counts.pocketed += 1
			return true, nil
		end,

		swap = function(self, player)
			local item = CarryServiceServer:getCarried(player)
			local entry = if item ~= nil then deps.entryOf(item) else nil
			local def = if entry ~= nil then CargoRegistry.get(entry.kind) else nil
			local action: CargoTypes.SwapAction?, reason =
				CargoHandlingRules.swapPlan(item ~= nil, def, pockets:count(player.UserId))
			if not action then
				return false, reason
			end
			local root = rootOf(player)
			local parent = deps.container()
			if root == nil or parent == nil or parent.Parent == nil then
				return false, "not now"
			end
			local out: CargoEntry? = nil
			if action == "unpocket" then
				out = pockets:remove(player.UserId, pockets:count(player.UserId))
			else
				out = pockets:remove(player.UserId, 1)
				local pocketed, why = self:pocket(player)
				if not pocketed then
					if out ~= nil then
						pockets:add(player.UserId, out)
					end
					publish(player.UserId)
					return false, why
				end
			end
			publish(player.UserId)
			if out == nil then
				return false, "pockets empty"
			end
			intoHands(player, out, root, parent)
			counts.swapped += 1
			return true, nil
		end,

		list = function(_self, userId)
			return pockets:list(userId)
		end,

		take = function(_self, userId)
			local list = pockets:take(userId)
			publish(userId)
			return list
		end,

		scatter = function(_self, player, origin)
			local parent = deps.container()
			local root = rootOf(player)
			local at = origin
				or (if root ~= nil then root.Position else nil)
				or known[player.UserId]
				or centreOf(parent)
			if at == nil or parent == nil or parent.Parent == nil then
				return
			end
			local list = pockets:take(player.UserId)
			publish(player.UserId)
			for index, entry in list do
				local angle = index / #list * math.pi * 2
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * CargoConstants.SCATTER_RADIUS
				deps.spawner:spawn(entry.kind, deps.spawner:floorUnder(at + offset, deps.ignore()), parent, {
					value = entry.value,
				})
				counts.scattered += 1
			end
		end,

		clear = function(_self)
			pockets:clear()
			for _, player in Players:GetPlayers() do
				publish(player.UserId)
			end
		end,

		counts = function(_self)
			return table.clone(counts)
		end,
	}
	return system
end

return CargoPocketSystem
