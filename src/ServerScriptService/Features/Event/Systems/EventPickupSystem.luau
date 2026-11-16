--!strict
--[=[
	EventPickupSystem: the rare acorn in a shift (owner R3/R9 answer, 11-16: about one per shift, +5). When a shift starts
	running while an event is live (never in training), it rolls which cleared pile (the event's pickup.firstPile to
	pickup.lastPile) hides the acorn; clearing that pile drops the acorn where the pile was. The first crew member to touch
	it gets pickup.amount of the event's money (`grant`); a refused grant leaves it for the next toucher. An untaken acorn
	goes when the shift returns to the lobby or the next shift starts.

	@class EventPickupSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local EventTypes = require(ReplicatedStorage.Shared.Features.Event.Data.EventTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type Event = EventTypes.Event

-- Spawns the acorn at `at`; `onTouch` gets the touching player's userId. Returns the function that removes it.
export type Spawn = (at: Vector3, onTouch: (userId: number) -> ()) -> () -> ()

export type Source = {
	changed: SignalTyped.Signal<ShiftTypes.ShiftState>,
	cleared: SignalTyped.Signal<BasePart, { Player }>,
	live: () -> Event?,
	training: () -> boolean,
	-- A whole number from min to max (both included).
	roll: ((min: number, max: number) -> number)?,
	spawn: Spawn?,
	-- Gives `amount` of the event's money; true once written.
	grant: (userId: number, event: Event, amount: number) -> boolean,
}

local NUT = Color3.fromRGB(196, 118, 52)
local CAP = Color3.fromRGB(110, 62, 32)

-- The acorn as two parts (nut and cap) until its model is made: anchored, no collision, a touch takes it.
local function spawnAcorn(at: Vector3, onTouch: (userId: number) -> ()): () -> ()
	local model = Instance.new("Model")
	model.Name = "EventAcorn"
	local nut = Instance.new("Part")
	nut.Name = "Nut"
	nut.Shape = Enum.PartType.Ball
	nut.Size = Vector3.new(1.4, 1.4, 1.4)
	nut.Color = NUT
	nut.Material = Enum.Material.SmoothPlastic
	nut.Anchored = true
	nut.CanCollide = false
	nut.CFrame = CFrame.new(at + Vector3.new(0, 1, 0))
	nut.Parent = model
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Shape = Enum.PartType.Cylinder
	cap.Size = Vector3.new(0.5, 1.5, 1.5)
	cap.Color = CAP
	cap.Material = Enum.Material.SmoothPlastic
	cap.Anchored = true
	cap.CanCollide = false
	cap.CFrame = CFrame.new(at + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	cap.Parent = model
	model.PrimaryPart = nut
	model.Parent = workspace
	local function touched(hit: BasePart)
		local character = hit.Parent
		local player = if character ~= nil then Players:GetPlayerFromCharacter(character) else nil
		if player ~= nil then
			onTouch(player.UserId)
		end
	end
	local a = nut.Touched:Connect(touched)
	local b = cap.Touched:Connect(touched)
	return function()
		a:Disconnect()
		b:Disconnect()
		model:Destroy()
	end
end

local EventPickupSystem = {}

function EventPickupSystem.start(source: Source): () -> ()
	local rng = Random.new()
	local roll = source.roll or function(min: number, max: number): number
		return rng:NextInteger(min, max)
	end
	local spawn: Spawn = source.spawn or spawnAcorn

	local shift = 0
	local event: Event? = nil
	local target: number? = nil
	local count = 0
	local remove: (() -> ())? = nil

	local function clear()
		local current = remove
		remove = nil
		if current ~= nil then
			current()
		end
	end

	local onChanged = source.changed:Connect(function(state: ShiftTypes.ShiftState)
		if state.phase == "lobby" then
			clear()
			target = nil
			return
		end
		if state.phase ~= "running" or state.shift == shift then
			return
		end
		shift = state.shift
		clear()
		count = 0
		local live = source.live()
		event = live
		target = if live ~= nil and not source.training()
			then roll(live.pickup.firstPile, live.pickup.lastPile)
			else nil
	end)

	local onCleared = source.cleared:Connect(function(pile: BasePart)
		local want, current = target, event
		if want == nil or current == nil then
			return
		end
		count += 1
		if count < want then
			return
		end
		target = nil
		local taken = false
		local amount = current.pickup.amount
		local removeThis: () -> ()
		removeThis = spawn(pile.Position, function(userId: number)
			if taken then
				return
			end
			taken = true
			if source.grant(userId, current, amount) then
				if remove == removeThis then
					remove = nil
				end
				removeThis()
			else
				taken = false
			end
		end)
		remove = removeThis
	end)

	return function()
		onChanged:Disconnect()
		onCleared:Disconnect()
		clear()
	end
end

return EventPickupSystem
