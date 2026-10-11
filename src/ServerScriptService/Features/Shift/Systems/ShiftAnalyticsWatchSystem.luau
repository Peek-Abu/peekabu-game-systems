--!strict
--[=[
	ShiftAnalyticsWatchSystem: turns what the features already announce into Cleanup Crew's analytics events (spec
	§6.6), so no feature carries analytics code and no service near the line cap grows. Every event goes out through
	ShiftAnalyticsSystem.emit; banking's events are ShiftBankingSystem's (ShiftAnalyticsSystem.banked).

	- Shift `changed`: contract_started when a run starts (target = how the variant was chosen), replay_started when
	  that run is not the server's first (an Another shift), quota_met when the quota is met;
	- Round `runEnded`: open optional-salvage attempts close as "unbanked", then shift_ended for each crew member (value
	  = their attempts this shift, target = their cleaning bucket, outcome = how the run ended, reason = whether the
	  quota was met). The crew is the trip's (`start`'s `trip`): the signal is deferred and Round has already cleared its
	  participants by then. The outcome is the signal's argument and the quota comes from the last `changed` copy (the
	  results copy on a normal end), so neither depends on Round's cleanup. After a Studio mid-run reset that last copy
	  is the lobby one (quotaMet = false), so the reason there always reads quota_missed;
	- Vacuum `vacuumStarted`: first_cleanup_started (once per player per shift); `pileCleared`: pile_cleared for each
	  player on the pile (and their cleaning count);
	- Carry `pickedUp`: cargo_picked_up, and an optional-salvage attempt opens when ShiftAnalyticsUtils.isSalvageAttempt
	  says so (after the quota, outside the loading bay); `dropped`: the item's attempt closes (dropped / thrown /
	  caught / left) and cargo_dropped is sent. Pocketing, banking and resets ("forced", "destroyed") are not drops;
	- Death `died` with Harlow's cause: the player's open attempts close as "caught", then player_caught;
	- Mr. Harlow's mode/target attributes (the `Occupant` tag; read, never required, since Occupant requires Shift):
	  noise_investigation for the crew, with the noise he most likely heard (Noise `made`, kept a few seconds), and
	  chase_started for the chased player, with what they hold. `investigated` tells the review who woke him
	  (ShiftReviewSystem).
	Gameplay events count only while the shift is running.

	Spec-exempt shell (signals, attributes, CollectionService); the decisions are the specced ShiftAnalyticsUtils,
	ShiftAnalyticsTracker and ShiftSalvageTracker.

	@class ShiftAnalyticsWatchSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftServer = ServerScriptService.Features.Shift
local Observers = require(ReplicatedStorage.Packages.Observers)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local DeathTypes = require(ReplicatedStorage.Shared.Features.Death.Data.DeathTypes)
local NoiseTypes = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseTypes)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local ShiftAnalyticsConstants = require(ShiftServer.Data.ShiftAnalyticsConstants)
local ShiftAnalyticsSystem = require(ShiftServer.Systems.ShiftAnalyticsSystem)
local ShiftAnalyticsUtils = require(ShiftServer.Utils.ShiftAnalyticsUtils)
local ShiftTripSystem = require(ShiftServer.Systems.ShiftTripSystem)

-- The makers of the noise Harlow went to investigate (ShiftReviewSystem credits each with waking him).
local investigated: SignalTyped.Signal<{ number }> = SignalTyped.new()

-- The last shift state seen (the `changed` copies arrive in order).
local before: ShiftTypes.ShiftState? = nil

local function running(): boolean
	local state = ShiftAnalyticsSystem.shift()
	return state ~= nil and state.phase == "running"
end

-- A cargo part's kind (nil for anything that is not cargo), where it came from, and its value now.
local function cargoOf(object: Instance): (string?, string, number)
	local kind = object:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	if type(kind) ~= "string" or not CargoRegistry.has(kind) then
		return nil, "open", 0
	end
	local source = object:GetAttribute(CargoConstants.SOURCE_ATTRIBUTE)
	local value = object:GetAttribute(CargoConstants.VALUE_ATTRIBUTE)
	return kind, if type(source) == "string" then source else "open", if type(value) == "number" then value else 0
end

local function itemIdOf(object: Instance): number?
	local id = object:GetAttribute(CargoConstants.ID_ATTRIBUTE)
	return if type(id) == "number" then id else nil
end

local function pileKindOf(pile: Instance): string
	local kind = pile:GetAttribute(VacuumConstants.PILE_KIND_ATTRIBUTE)
	return if type(kind) == "string" then kind else "unknown"
end

-- Standing in the loading bay (Mr. Harlow's safe zone)?
local function inBay(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local low, high = OfficeServiceServer:safeZone()
	return ShiftAnalyticsUtils.inBox(root.Position, low, high)
end

-- The kind in a player's hands, or "empty".
local function held(player: Player): string
	local carried = CarryServiceServer:getCarried(player)
	local kind = if carried ~= nil then cargoOf(carried) else nil
	return kind or "empty"
end

local function onChanged(state: ShiftTypes.ShiftState)
	local previous = before
	before = state
	ShiftAnalyticsSystem.setShift(state)
	if state.phase ~= "running" then
		return
	end
	if previous == nil or previous.phase ~= "running" then
		ShiftAnalyticsSystem.beginShift()
		local replay = state.shift > 1
		ShiftAnalyticsSystem.emit("contract_started", "crew", {
			target = ShiftAnalyticsSystem.variantSource(),
			outcome = if replay then "replay" else "first",
			value = state.shift,
		})
		if replay then
			ShiftAnalyticsSystem.emit("replay_started", "crew", {
				target = "another_shift",
				outcome = "same_server",
				value = state.shift,
			})
		end
	elseif previous ~= nil and state.quotaMet and not previous.quotaMet then
		local at = ShiftAnalyticsSystem.elapsed()
		ShiftAnalyticsSystem.tracker:markQuota(at)
		ShiftAnalyticsSystem.emit("quota_met", "crew", { target = "clearance", outcome = "met", value = at })
	end
end

local function onRunEnded(outcome: string)
	ShiftAnalyticsSystem.closeAttempts(ShiftAnalyticsSystem.salvage:resolveAll("unbanked"))
	local state = ShiftAnalyticsSystem.shift()
	local reason = if state ~= nil and state.quotaMet then "quota_met" else "quota_missed"
	for _, player in ShiftAnalyticsSystem.crew() do
		ShiftAnalyticsSystem.emit("shift_ended", player, {
			target = ShiftAnalyticsUtils.pileBucket(ShiftAnalyticsSystem.tracker:pilesOf(player.UserId)),
			outcome = outcome,
			reason = reason,
			value = ShiftAnalyticsSystem.salvage:attemptsBy(player.UserId),
		})
	end
end

local function onVacuumStarted(player: Player, pile: BasePart)
	if not running() or not ShiftAnalyticsSystem.tracker:firstCleanup(player.UserId) then
		return
	end
	ShiftAnalyticsSystem.emit("first_cleanup_started", player, {
		target = pileKindOf(pile),
		outcome = ShiftAnalyticsSystem.quotaTag(),
		value = ShiftAnalyticsSystem.elapsed(),
	})
end

local function onPileCleared(pile: BasePart, players: { Player })
	if not running() then
		return
	end
	local kind = pileKindOf(pile)
	local outcome = if #players > 1 then "shared" else "solo"
	for _, player in players do
		ShiftAnalyticsSystem.tracker:addPile(player.UserId)
		ShiftAnalyticsSystem.emit("pile_cleared", player, {
			target = kind,
			outcome = outcome,
			value = ShiftAnalyticsSystem.elapsed(),
		})
	end
end

local function onPickedUp(player: Player, object: Instance)
	if not running() then
		return
	end
	local kind, source, value = cargoOf(object)
	if kind == nil then
		return
	end
	ShiftAnalyticsSystem.emit("cargo_picked_up", player, {
		target = `{kind}:{source}`,
		outcome = ShiftAnalyticsSystem.quotaTag(),
		value = value,
	})
	local def = CargoRegistry.get(kind)
	local state = ShiftAnalyticsSystem.shift()
	local id = itemIdOf(object)
	if def == nil or state == nil or id == nil then
		return
	end
	local attempt = ShiftAnalyticsUtils.isSalvageAttempt({
		category = def.category,
		phase = state.phase,
		sub = state.sub,
		quotaMet = state.quotaMet,
		inBay = inBay(player),
	})
	if attempt then
		ShiftAnalyticsSystem.salvage:open(id, player.UserId, kind, source, ShiftAnalyticsSystem.sinceQuota())
	end
end

local function onDropped(player: Player, object: Instance, reason: string)
	-- Annotated: Luau widens an unannotated singleton-union local to `string` once `== nil` refines it.
	local outcome: ShiftAnalyticsUtils.AttemptOutcome? = ShiftAnalyticsUtils.dropOutcome(reason)
	if outcome == nil then
		return
	end
	local id = itemIdOf(object)
	if id ~= nil then
		local closed = ShiftAnalyticsSystem.salvage:resolveItem(id, outcome)
		if closed ~= nil then
			ShiftAnalyticsSystem.closeAttempts({ closed })
		end
	end
	if not running() then
		return
	end
	local kind, source, value = cargoOf(object)
	if kind == nil then
		return
	end
	ShiftAnalyticsSystem.emit("cargo_dropped", player, { target = `{kind}:{source}`, outcome = outcome, value = value })
end

local function onDied(player: Player, info: DeathTypes.DeathInfo)
	if info.cause ~= ShiftAnalyticsConstants.CATCH_CAUSE then
		return
	end
	ShiftAnalyticsSystem.closeAttempts(ShiftAnalyticsSystem.salvage:resolvePlayer(player.UserId, "caught"))
	if running() then
		ShiftAnalyticsSystem.emit("player_caught", player, {
			target = "harlow",
			outcome = ShiftAnalyticsSystem.quotaTag(),
			value = ShiftAnalyticsSystem.elapsed(),
		})
	end
end

local function onNoise(event: NoiseTypes.NoiseEvent)
	ShiftAnalyticsSystem.tracker:noteNoise({
		source = event.source,
		position = event.position,
		radius = event.radius,
		at = os.clock(),
		makers = table.clone(event.makers),
	})
end

-- Reads Harlow's mode and target (OccupantRigSystem.setMode writes both), sends what changed since `last` (this
-- model's previous read, nil at first) and returns the new reading.
local function readHarlow(model: Instance, last: ShiftAnalyticsUtils.Harlow?): ShiftAnalyticsUtils.Harlow
	local mode = model:GetAttribute(OccupantConstants.MODE_ATTRIBUTE)
	local target = model:GetAttribute(OccupantConstants.TARGET_ATTRIBUTE)
	local now: ShiftAnalyticsUtils.Harlow = {
		mode = if type(mode) == "string" then mode else "patrol",
		target = if type(target) == "number" then target else 0,
	}
	local event = ShiftAnalyticsUtils.harlowChange(last, now)
	if event == nil or not running() then
		return now
	end
	if event == "noise_investigation" then
		local position = if model:IsA("PVInstance") then model:GetPivot().Position else Vector3.zero
		local scale = NoiseServiceServer:getHearingScale()
		local noise = ShiftAnalyticsUtils.heardNoise(ShiftAnalyticsSystem.tracker:noises(), position, scale, os.clock())
		ShiftAnalyticsSystem.emit("noise_investigation", "crew", {
			target = if noise ~= nil then noise.source else "unknown",
			outcome = ShiftAnalyticsSystem.quotaTag(),
			value = ShiftAnalyticsSystem.elapsed(),
		})
		if noise ~= nil and #noise.makers > 0 then
			investigated:Fire(table.clone(noise.makers))
		end
		return now
	end
	local victim = Players:GetPlayerByUserId(now.target)
	if victim ~= nil then
		ShiftAnalyticsSystem.emit("chase_started", victim, {
			target = held(victim),
			outcome = ShiftAnalyticsSystem.quotaTag(),
			value = ShiftAnalyticsSystem.elapsed(),
		})
	end
	return now
end

-- Follows one Harlow model; both attributes change together, so one deferred read covers both. The last reading is
-- this model's own, so an old model's late cleanup cannot reset a new model's state.
local function watchHarlow(model: Instance): () -> ()
	local last: ShiftAnalyticsUtils.Harlow? = nil
	local pending = false
	local function schedule()
		if pending then
			return
		end
		pending = true
		task.defer(function()
			pending = false
			if model.Parent ~= nil then
				last = readHarlow(model, last)
			end
		end)
	end
	local modeChanged = model:GetAttributeChangedSignal(OccupantConstants.MODE_ATTRIBUTE):Connect(schedule)
	local targetChanged = model:GetAttributeChangedSignal(OccupantConstants.TARGET_ATTRIBUTE):Connect(schedule)
	-- Attributes set before the model was seen raise no change: read his current mode once at start.
	schedule()
	return function()
		modeChanged:Disconnect()
		targetChanged:Disconnect()
	end
end

local ShiftAnalyticsWatchSystem = {}
ShiftAnalyticsWatchSystem.investigated = investigated

--[=[
	Starts ShiftAnalyticsSystem (its crew = `trip`'s) and subscribes to the features. Returns the function that undoes
	both.
]=]
function ShiftAnalyticsWatchSystem.start(
	changed: SignalTyped.Signal<ShiftTypes.ShiftState>,
	trip: ShiftTripSystem.ShiftTripSystem
): () -> ()
	ShiftAnalyticsSystem.start(function()
		return trip:crew()
	end)
	local stops: { () -> () } = {}
	local function keep(stop: () -> ())
		table.insert(stops, stop)
	end
	local shiftChanged = changed:Connect(onChanged)
	keep(function()
		shiftChanged:Disconnect()
	end)
	local ended = RoundServiceServer.runEnded:Connect(onRunEnded)
	keep(function()
		ended:Disconnect()
	end)
	local started = VacuumServiceServer.vacuumStarted:Connect(onVacuumStarted)
	keep(function()
		started:Disconnect()
	end)
	local cleared = VacuumServiceServer.pileCleared:Connect(onPileCleared)
	keep(function()
		cleared:Disconnect()
	end)
	local picked = CarryServiceServer.pickedUp:Connect(onPickedUp)
	keep(function()
		picked:Disconnect()
	end)
	local dropped = CarryServiceServer.dropped:Connect(onDropped)
	keep(function()
		dropped:Disconnect()
	end)
	local died = DeathServiceServer.died:Connect(onDied)
	keep(function()
		died:Disconnect()
	end)
	local noise = NoiseServiceServer.made:Connect(onNoise)
	keep(function()
		noise:Disconnect()
	end)
	keep(Observers.observeTag(OccupantConstants.TAG, watchHarlow))
	return function()
		for _, stop in stops do
			stop()
		end
		before = nil
		ShiftAnalyticsSystem.stop()
	end
end

return ShiftAnalyticsWatchSystem
