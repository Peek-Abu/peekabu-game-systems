--!strict
-- Released cargo rests anchored and noncolliding; deliberate throws retain physics until they settle.
-- Never touches authored surface placements or objects that have been picked up again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local CargoSpawnSystem = require(ServerScriptService.Features.Cargo.Systems.CargoSpawnSystem)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CarryTypes = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryTypes)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)

type Flight = { age: number, still: number, player: Player? }
export type Controller = {
	release: (self: Controller, part: BasePart, reason: CarryTypes.DropReason, player: Player?) -> (),
	step: (self: Controller, dt: number) -> (),
	stop: (self: Controller) -> (),
}
local CargoGroundSystem = {}
function CargoGroundSystem.new(
	spawner: CargoSpawnSystem.CargoSpawnSystem,
	ignore: (Instance?) -> { Instance },
	settled: ((Player, BasePart, CarryTypes.DropReason, boolean) -> ())?
): Controller
	local flights: { [BasePart]: Flight } = {}
	local connection: RBXScriptConnection? = nil
	local function rest(part: BasePart, player: Player?, reason: CarryTypes.DropReason, landed: boolean)
		local floor = spawner:floorUnder(part.Position, ignore(part))
		local look = part.CFrame.LookVector
		local horizontal = Vector3.new(look.X, 0, look.Z)
		local position = floor.Position + Vector3.new(0, part.Size.Y / 2, 0)
		-- Upright cargo preserves its authored facing, even after tumbling in a throw.
		part.CFrame = if horizontal.Magnitude > 0.001
			-- Build rotation at the origin so large map coordinates do not quantize the facing vector.
			then CFrame.new(position) * CFrame.lookAt(Vector3.zero, horizontal)
			else CFrame.new(position)
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
		part.CanCollide = false
		part.Anchored = true
		if settled ~= nil and player ~= nil then
			settled(player, part, reason, landed)
		end
	end
	local system: Controller
	system = {
		release = function(_self, part, reason, player)
			flights[part] = nil
			if
				reason == "destroyed"
				or part.Parent == nil
				or part:GetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE) ~= nil
			then
				return
			end
			if reason == "throw" then
				part.CanCollide = true
				-- The server owns flight physics; no client position is accepted as a landing.
				if not part.Anchored then
					part:SetNetworkOwner(nil)
				end
				flights[part] = { age = 0, still = 0, player = player }
				if connection == nil then
					connection = RunService.Heartbeat:Connect(function(dt)
						system:step(dt)
					end)
				end
			else
				rest(part, player, reason, true)
			end
		end,
		step = function(_self, dt)
			for part, flight in flights do
				if part.Parent == nil or part:GetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE) ~= nil then
					flights[part] = nil
					continue
				end
				flight.age += dt
				local quiet = part.AssemblyLinearVelocity.Magnitude <= CargoConstants.REST_SPEED
					and part.AssemblyAngularVelocity.Magnitude <= CargoConstants.REST_SPEED
				flight.still = if quiet then flight.still + dt else 0
				if
					(flight.age >= CargoConstants.THROW_MIN_FLIGHT and flight.still >= CargoConstants.REST_SECONDS)
					or flight.age >= CargoConstants.THROW_MAX_FLIGHT
				then
					flights[part] = nil
					local floor = spawner:floorUnder(part.Position, ignore(part))
					local frame = part.CFrame
					local halfHeight = (
						math.abs(frame.RightVector.Y) * part.Size.X
						+ math.abs(frame.UpVector.Y) * part.Size.Y
						+ math.abs(frame.LookVector.Y) * part.Size.Z
					) / 2
					local landed = quiet
						and math.abs(part.Position.Y - halfHeight - floor.Position.Y)
							<= CargoConstants.LANDING_TOLERANCE
					rest(part, flight.player, "throw", landed)
				end
			end
			if next(flights) == nil and connection ~= nil then
				connection:Disconnect()
				connection = nil
			end
		end,
		stop = function(_self)
			if connection ~= nil then
				connection:Disconnect()
				connection = nil
			end
			table.clear(flights)
		end,
	}
	return system
end
return CargoGroundSystem
