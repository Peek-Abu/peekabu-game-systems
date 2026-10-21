--!strict
--[=[
	CargoScatterSystem: puts a player's pocketed inventory entries back in the world when they are caught, die or leave
	(docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md §1). They land in a ring of SCATTER_RADIUS
	round `origin`, else where the player stands, was last seen (sampled every ROOT_SAMPLE_INTERVAL by `start`) or the
	shift container's centre, each on the floor and never through a wall (CarryPlacementSystem), with its value,
	appraisal and art kit as they were, marked source "scatter". Nothing is spawned without a live shift container.

	Spec-exempt shell (Players, Heartbeat, Instances); the entries are the specced CargoInventoryTracker's.

	@class CargoScatterSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local CargoSpawnSystem = require(ServerScriptService.Features.Cargo.Systems.CargoSpawnSystem)
local CarryPlacementSystem = require(ServerScriptService.Features.Carry.Systems.CarryPlacementSystem)

export type Deps = {
	spawner: CargoSpawnSystem.CargoSpawnSystem,
	-- The shift's container (where items come back into the world); nil = no shift.
	container: () -> Instance?,
	-- What a floor probe looks through (every character).
	ignore: () -> { Instance },
}

export type CargoScatterSystem = {
	-- Samples every character's position now and then; returns the stopper.
	start: (self: CargoScatterSystem) -> () -> (),
	forget: (self: CargoScatterSystem, userId: number) -> (),
	-- Spawns `entries` round where `player` was; returns how many it put back.
	scatter: (self: CargoScatterSystem, player: Player, origin: Vector3?, entries: { CargoTypes.CargoEntry }) -> number,
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

local CargoScatterSystem = {}

function CargoScatterSystem.new(deps: Deps): CargoScatterSystem
	local known: { [number]: Vector3 } = {}

	local system: CargoScatterSystem = {
		start = function(_self)
			local elapsed = 0
			local sampling = RunService.Heartbeat:Connect(function(deltaTime)
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
				sampling:Disconnect()
			end
		end,

		forget = function(_self, userId)
			known[userId] = nil
		end,

		scatter = function(_self, player, origin, entries)
			local parent = deps.container()
			local root = rootOf(player)
			local at = origin
				or (if root ~= nil then root.Position else nil)
				or known[player.UserId]
				or centreOf(parent)
			if at == nil or parent == nil or parent.Parent == nil then
				return 0
			end
			for index, entry in entries do
				local angle = index / #entries * math.pi * 2
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * CargoConstants.SCATTER_RADIUS
				-- From where they stood, never through a wall or off the building's floor (CarryPlacementSystem).
				local def = CargoRegistry.get(entry.kind)
				local margin = (if def ~= nil then math.max(def.partSize.X, def.partSize.Z) / 2 else 0)
					+ CarryConstants.WALL_MARGIN
				local landing = CarryPlacementSystem.floorNear(at, at + offset, deps.ignore(), margin)
				deps.spawner:spawn(entry.kind, landing, parent, {
					value = entry.value,
					appraisal = entry.appraisal,
					artKit = if entry.visual ~= nil then entry.visual.kitId else nil,
					source = "scatter",
					overtime = entry.overtime,
				})
			end
			return #entries
		end,
	}
	return system
end

return CargoScatterSystem
