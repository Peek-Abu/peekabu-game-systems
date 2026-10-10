--!strict
--[=[
	CargoPocketSystem: puts a player's pocketed items back in the world. Scattering must never lose them, so
	it remembers where each player last stood (sampled on a cheap interval) and falls back to that, then to
	the shift container's position, when the character or its root is already gone.

	Spec-exempt shell (Instances, Players, Heartbeat); the pocket list itself is the specced CargoPocketTracker.

	@class CargoPocketSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoSpawnSystem = require(script.Parent.CargoSpawnSystem)

export type CargoPocketSystem = {
	-- Samples every character's position now and then; returns the disconnect.
	start: (self: CargoPocketSystem) -> () -> (),
	-- Where to scatter for `player`: the live root, else the last known position, else the container's centre.
	originOf: (self: CargoPocketSystem, player: Player, container: Instance?) -> Vector3?,
	forget: (self: CargoPocketSystem, userId: number) -> (),
	-- Spawns `entries` in a ring around `origin`; returns how many.
	scatter: (
		self: CargoPocketSystem,
		entries: { CargoTypes.CargoEntry },
		origin: Vector3,
		parent: Instance,
		ignore: { Instance }
	) -> number,
}

local CargoPocketSystem = {}

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
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

function CargoPocketSystem.new(spawner: CargoSpawnSystem.CargoSpawnSystem): CargoPocketSystem
	local known: { [number]: Vector3 } = {}

	local system: CargoPocketSystem = {
		start = function(_self)
			local elapsed = 0
			local connection = RunService.Heartbeat:Connect(function(deltaTime)
				elapsed += deltaTime
				if elapsed < CargoConstants.ROOT_SAMPLE_INTERVAL then
					return
				end
				elapsed = 0
				for _, player in Players:GetPlayers() do
					local position = rootPosition(player)
					if position ~= nil then
						known[player.UserId] = position
					end
				end
			end)
			return function()
				connection:Disconnect()
			end
		end,

		originOf = function(_self, player, container)
			return rootPosition(player) or known[player.UserId] or centreOf(container)
		end,

		forget = function(_self, userId)
			known[userId] = nil
		end,

		scatter = function(_self, entries, origin, parent, ignore)
			for index, entry in entries do
				local angle = index / #entries * math.pi * 2
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * CargoConstants.SCATTER_RADIUS
				spawner:spawn(entry.kind, spawner:floorUnder(origin + offset, ignore), parent, { value = entry.value })
			end
			return #entries
		end,
	}
	return system
end

return CargoPocketSystem
