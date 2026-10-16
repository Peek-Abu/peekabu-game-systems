--!strict
--[=[
	ShiftTransitSystem: the server half of the load screen between the depot and the office and between shifts. Nobody
	walks in the old or a half-built map: a held player's root is anchored from the moment the hold begins until they
	are released, and their client covers the screen (the route slip, ShiftTransitScreen) while they are held.

	- `begin(players)` is the crew's transit (the first departure, Another shift, the next shift): every player is held
	  and anchored under a new id and the holds are published (ShiftConstants.TRANSIT_ENTRY), so each client fades its
	  screen in. TRANSIT_COVER_SECONDS later, with every screen covered, `prepare` runs (Shift resets the last shift
	  and rebuilds and spawns the office: OfficeServiceServer:beginShift), then each player is placed in the truck
	  (OfficeServiceServer:spawnCFrame) and their hold marked built (with the spot and the office's seed), and the server starts streaming
	  the area in around them. Each client reports ready (ShiftEvents.TransitReady) once it sees the new office, its
	  character on its spot, the area streamed in and the lighting applied; its screen then clears, but the player
	  stays anchored until the whole crew is in. Once everyone reported, or TRANSIT_TIMEOUT after the hold began (the
	  late ones are logged), the crew is released and Round's run starts (startNow), so the shift clock starts with the
	  crew in. If every held player leaves, `abandoned`.
	- `admit(player)` holds one player who arrives on their own (a late member, a second party): during the crew's
	  transit they join it (placed with the crew); otherwise they get their own short hold, are placed in the truck
	  after the cover and released when their client is ready (the clock is not held for them).
	- A held player's new character is anchored and put back on their spot; a player who leaves is forgotten.

	Spec-exempt shell (Players, characters, streaming, ByteNet, task timers); the holds, ids, readiness and deadlines
	are the specced ShiftTransitTracker, the published entry the specced ShiftTransitUtils.

	@class ShiftTransitSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftEvents = require(ReplicatedStorage.Shared.Features.Shift.Net.ShiftEvents)
local ShiftTransitUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftTransitUtils)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ShiftTransitTracker = require(ServerScriptService.Features.Shift.State.ShiftTransitTracker)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

export type Options = {
	-- Under the cover, before anyone is placed: reset the last shift, rebuild and spawn the office.
	prepare: () -> (),
	-- Everyone held by the crew's transit left.
	abandoned: () -> (),
	-- The route slip's lines: the contract's client and the truck (ShiftTripSystem).
	slip: () -> (string?, number?),
}

export type ShiftTransitSystem = {
	start: (self: ShiftTransitSystem) -> () -> (),
	begin: (self: ShiftTransitSystem, players: { Player }) -> boolean,
	admit: (self: ShiftTransitSystem, player: Player) -> (),
	cancel: (self: ShiftTransitSystem) -> (),
	active: (self: ShiftTransitSystem) -> boolean,
	isHeld: (self: ShiftTransitSystem, player: Player) -> boolean,
	getState: (self: ShiftTransitSystem) -> { [string]: number | boolean },
}

local log = Logger.new("ShiftTransitSystem")

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function anchor(player: Player, on: boolean)
	local root = rootOf(player)
	if root ~= nil then
		root.Anchored = on
	end
end

local ShiftTransitSystem = {}

function ShiftTransitSystem.new(options: Options): ShiftTransitSystem
	local tracker = ShiftTransitTracker.new()
	-- The crew's transit in progress (its hold id), nil when none.
	local crewId: number? = nil
	-- Whether that transit has placed the crew yet (a player admitted after it is placed on their own).
	local crewPlaced = false
	local publishScheduled = false
	local counters = { transits = 0, admitted = 0, timeouts = 0, ready = 0 }

	local function publish()
		if publishScheduled then
			return
		end
		publishScheduled = true
		task.defer(function()
			publishScheduled = false
			local client, truck = options.slip()
			StateSyncWorldStore.set(
				ShiftConstants.TRANSIT_ENTRY,
				ShiftTransitUtils.build(tracker:list(), client, truck)
			)
		end)
	end

	local function playersOf(userIds: { number }): { Player }
		local list: { Player } = {}
		for _, userId in userIds do
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				table.insert(list, player)
			end
		end
		return list
	end

	-- Puts a held player on their spot (anchored) and starts streaming it in for them.
	local function place(player: Player, spot: CFrame)
		local character = player.Character
		if character ~= nil then
			anchor(player, true)
			character:PivotTo(spot)
		end
		tracker:place(player.UserId, spot.Position, OfficeServiceServer:seed())
		task.spawn(function()
			local ok, err = pcall(function()
				player:RequestStreamAroundAsync(spot.Position, ShiftConstants.TRANSIT_STREAM_TIMEOUT)
			end)
			if not ok then
				log:warn(`streaming in the truck for {player.Name} failed: {err}`)
			end
		end)
	end

	local function release(player: Player)
		if tracker:release(player.UserId) then
			anchor(player, false)
		end
	end

	-- Runs `step`, logging (not rethrowing) an error, so the transit always goes on to reveal.
	local function guarded(label: string, body: () -> ())
		xpcall(body, function(err: unknown)
			log:error(`{label} failed: {err}`)
		end)
	end

	local function finishCrew(id: number, status: string)
		if crewId ~= id then
			return
		end
		crewId = nil
		if status == "timeout" then
			counters.timeouts += 1
			local late = tracker:unready(id)
			log:warn(
				`the transit timed out waiting for {#late} player(s) ({table.concat(late, ", ")}); revealing anyway`
			)
		end
		for _, player in playersOf(tracker:members(id)) do
			release(player)
		end
		publish()
		if status == "empty" then
			options.abandoned()
		elseif not RoundServiceServer:startNow() then
			log:error("the transit settled but Round would not start the run")
		end
	end

	-- Every held player whose own hold is over: released; the crew's transit finishes once it settles.
	local function check()
		local current = crewId
		if current ~= nil then
			local status = tracker:status(current, now())
			if status ~= "waiting" then
				finishCrew(current, status)
			end
		end
		for _, player in Players:GetPlayers() do
			local id = tracker:idOf(player.UserId)
			if id ~= nil and id ~= crewId then
				local status = tracker:status(id, now())
				if status == "timeout" then
					counters.timeouts += 1
					log:warn(`{player.Name}'s arrival timed out; revealing anyway`)
				end
				if status ~= "waiting" then
					release(player)
					publish()
				end
			end
		end
	end

	local onReady = RequestHandler.wrap({
		name = "ShiftTransitReady",
		rateLimit = { maxRequests = 10, windowSeconds = 5 },
		handler = function(data: unknown, player: Player)
			if type(data) ~= "number" then
				return
			end
			if not tracker:markReady(player.UserId, data) then
				return
			end
			counters.ready += 1
			publish()
			local current = crewId
			if current ~= nil and data == current and #tracker:unready(current) > 0 then
				ToastServiceServer:send(player, { text = ShiftConstants.TRANSIT_WAIT_TEXT, duration = 4 })
			end
			check()
		end,
	})

	local system: ShiftTransitSystem = {
		start = function(_self)
			local listening = ShiftEvents.packets.TransitReady.listen(function(data: number, player: Player?)
				if player then
					onReady(data, player)
				end
			end)
			local characters: { [Player]: RBXScriptConnection } = {}
			local function watch(player: Player)
				characters[player] = player.CharacterAdded:Connect(function(character: Model)
					if not tracker:isHeld(player.UserId) then
						return
					end
					local root = character:WaitForChild("HumanoidRootPart", 5)
					local spot = tracker:spotOf(player.UserId)
					if root ~= nil and root:IsA("BasePart") and tracker:isHeld(player.UserId) then
						root.Anchored = true
						if spot ~= nil then
							character:PivotTo(CFrame.new(spot) * root.CFrame.Rotation)
						end
					end
				end)
			end
			for _, player in Players:GetPlayers() do
				watch(player)
			end
			local joining = Players.PlayerAdded:Connect(watch)
			local leaving = Players.PlayerRemoving:Connect(function(player: Player)
				local connection: RBXScriptConnection? = characters[player]
				characters[player] = nil
				if connection ~= nil then
					connection:Disconnect()
				end
				if tracker:release(player.UserId) then
					publish()
					-- Their leaving may settle the crew's transit (or empty it).
					task.defer(check)
				end
			end)
			local elapsed = 0
			local ticking = RunService.Heartbeat:Connect(function(deltaTime: number)
				elapsed += deltaTime
				if elapsed >= ShiftConstants.TICK_INTERVAL then
					elapsed = 0
					check()
				end
			end)
			publish()
			return function()
				listening()
				joining:Disconnect()
				leaving:Disconnect()
				ticking:Disconnect()
				for _, connection in characters do
					connection:Disconnect()
				end
				table.clear(characters)
				for _, player in Players:GetPlayers() do
					release(player)
				end
				tracker:clear()
				crewId = nil
				StateSyncWorldStore.clear(ShiftConstants.TRANSIT_ENTRY)
			end
		end,

		begin = function(_self, players)
			if crewId ~= nil or #players == 0 then
				return false
			end
			local ids: { number } = {}
			for _, player in players do
				table.insert(ids, player.UserId)
				anchor(player, true)
			end
			local id = tracker:hold(ids, now(), ShiftConstants.TRANSIT_TIMEOUT)
			crewId = id
			crewPlaced = false
			counters.transits += 1
			publish()
			log:info(`transit {id}: {#players} crew member(s) held`)
			task.delay(ShiftConstants.TRANSIT_COVER_SECONDS, function()
				if crewId ~= id then
					return
				end
				guarded("preparing the shift", options.prepare)
				for index, player in playersOf(tracker:members(id)) do
					place(player, OfficeServiceServer:spawnCFrame(index))
				end
				crewPlaced = true
				publish()
			end)
			return true
		end,

		admit = function(_self, player)
			counters.admitted += 1
			local current = crewId
			if current ~= nil then
				-- Placed with the crew; if the crew is already placed, on their own after the cover.
				tracker:join(player.UserId, current)
				anchor(player, true)
				publish()
				if crewPlaced then
					task.delay(ShiftConstants.TRANSIT_COVER_SECONDS, function()
						if tracker:idOf(player.UserId) == current then
							local index = table.find(tracker:members(current), player.UserId) or 1
							place(player, OfficeServiceServer:spawnCFrame(index))
							publish()
						end
					end)
				end
				return
			end
			anchor(player, true)
			local id = tracker:hold({ player.UserId }, now(), ShiftConstants.TRANSIT_TIMEOUT)
			publish()
			task.delay(ShiftConstants.TRANSIT_COVER_SECONDS, function()
				if tracker:idOf(player.UserId) ~= id then
					return
				end
				local index = 1
				for position, other in Players:GetPlayers() do
					if other == player then
						index = position
					end
				end
				place(player, OfficeServiceServer:spawnCFrame(index))
				publish()
			end)
		end,

		cancel = function(_self)
			local current = crewId
			crewId = nil
			if current ~= nil then
				for _, player in playersOf(tracker:members(current)) do
					release(player)
				end
				publish()
			end
		end,

		active = function(_self)
			return crewId ~= nil
		end,

		isHeld = function(_self, player)
			return tracker:isHeld(player.UserId)
		end,

		getState = function(_self)
			return {
				active = crewId ~= nil,
				held = #tracker:list(),
				transits = counters.transits,
				admitted = counters.admitted,
				timeouts = counters.timeouts,
				ready = counters.ready,
			}
		end,
	}
	return system
end

return ShiftTransitSystem
