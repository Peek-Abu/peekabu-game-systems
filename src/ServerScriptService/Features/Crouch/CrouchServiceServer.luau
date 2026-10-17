--!strict
--[=[
	CrouchServiceServer: crouching, server-authoritative (the SprintServiceServer pattern). The client only says
	whether it wants to crouch (CrouchEvents.Crouch, rate limited: the key held or a toggle on); every TICK the server
	decides (CrouchRules: alive, not frozen in a catch, not hiding, not sprinting or asking to, hands empty or holding
	a small item) and, while crouched, owns the speed: CROUCH_SPEED slowed by the load exactly as the walk is
	(CrouchSpeedFormulas, through Carry's formula and Carry's whole load), the player's own (carried) walk otherwise.
	The character's Crouching attribute (CrouchConstants.CROUCHING_ATTRIBUTE) is the decision every client reads: the
	crouch poses (Animation), the quiet crouch gait (Footstep), the slower glance (Occupant) and the lowered camera.

	Sprinting ends a crouch: asking to sprint (SprintServiceServer:wantsToSprint) stands the player up, and Sprint
	waits for the attribute to clear, so a sprint always starts from the walk. A crouch makes no sprint noise (walking
	and crouching are silent to the Manager; only a sprint is heard).

	Carry is told the walk under the crouch, composed with Sprint's (CarryServiceServer:setSpeedBase: the crouch's
	when crouched, else Sprint's), so an item pocketed or picked up while crouched leaves Carry's walk right.

	Spec-exempt shell (Humanoids, Players, ByteNet, RunService); the decisions are the specced CrouchRules and
	CrouchSpeedFormulas.

	@class CrouchServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CrouchShared = ReplicatedStorage.Shared.Features.Crouch
local Observers = require(ReplicatedStorage.Packages.Observers)
local CrouchConstants = require(CrouchShared.Data.CrouchConstants)
local CrouchEvents = require(CrouchShared.Net.CrouchEvents)
local CrouchRules = require(CrouchShared.Rules.CrouchRules)
local CrouchSpeedFormulas = require(CrouchShared.Utils.CrouchSpeedFormulas)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CarryFormulas = require(ReplicatedStorage.Shared.Features.Carry.Utils.CarryFormulas)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local CarrySpeedSystem = require(ServerScriptService.Features.Carry.Systems.CarrySpeedSystem)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)
local SprintServiceServer = require(ServerScriptService.Features.Sprint.SprintServiceServer)

type Croucher = {
	requested: boolean,
	-- The humanoid crouched now, and its own walk to give back (nil while standing).
	lowered: Humanoid?,
	base: number?,
}

local crouchers: { [number]: Croucher } = {}
local stoppers: { () -> () } = {}
local elapsed = 0
local counters = { crouches = 0, refused = 0, stoodForSprint = 0 }

local function croucherOf(player: Player): Croucher
	local croucher = crouchers[player.UserId]
	if croucher == nil then
		croucher = { requested = false, lowered = nil, base = nil }
		crouchers[player.UserId] = croucher
	end
	return croucher
end

-- The size of what the player holds (nil when empty-handed; "unknown" for a held thing that is not cargo): Hide's
-- reading of the hands.
local function heldSize(player: Player): string?
	local carried = CarryServiceServer:getCarried(player)
	if carried == nil then
		return nil
	end
	local kind = carried:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
	return if def ~= nil then def.size else "unknown"
end

-- Stands a crouched player up: the humanoid walks again at its own walk slowed by what it carries, and the
-- attribute clears on the body that crouched.
local function stand(player: Player, croucher: Croucher)
	local humanoid = croucher.lowered
	local base = croucher.base
	croucher.lowered = nil
	croucher.base = nil
	if humanoid ~= nil and base ~= nil and humanoid.Parent ~= nil then
		humanoid.WalkSpeed = CarryFormulas.carrierSpeed(base, CarrySpeedSystem.weightFor(player))
	end
	local body = if humanoid ~= nil then humanoid.Parent else nil
	if body ~= nil then
		body:SetAttribute(CrouchConstants.CROUCHING_ATTRIBUTE, nil)
	end
	local character = player.Character
	if character ~= nil and character ~= body then
		character:SetAttribute(CrouchConstants.CROUCHING_ATTRIBUTE, nil)
	end
end

local onCrouch = RequestHandler.wrap({
	name = "Crouch",
	rateLimitKey = "Crouch",
	rateLimit = CrouchConstants.REQUEST_RATE,
	handler = function(data: unknown, player: Player)
		if type(data) == "boolean" then
			croucherOf(player).requested = data
		end
	end,
})

local function stepOne(player: Player, croucher: Croucher)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local alive = humanoid ~= nil and humanoid.Health > 0 and not DeathServiceServer:isDead(player)
	local sprinting = SprintServiceServer:wantsToSprint(player)
	local ok, reason = CrouchRules.canCrouch({
		requested = croucher.requested,
		alive = alive,
		frozen = root ~= nil and root:IsA("BasePart") and root.Anchored,
		hidden = HideServiceServer:isHidden(player),
		sprinting = sprinting,
		heldSize = heldSize(player),
	})
	if croucher.lowered ~= nil and (not ok or croucher.lowered ~= humanoid) then
		if reason == "sprinting" then
			counters.stoodForSprint += 1
		end
		stand(player, croucher)
	end
	local weight = CarrySpeedSystem.weightFor(player)
	if ok and humanoid ~= nil and character ~= nil and croucher.lowered == nil then
		croucher.lowered = humanoid
		-- The unloaded walk: the walk now, un-slowed by the load (Carry's slow is a plain factor). Sprint is not
		-- boosting (a crouch never starts while it does).
		croucher.base = humanoid.WalkSpeed / CarryFormulas.carrierSpeed(1, weight)
		character:SetAttribute(CrouchConstants.CROUCHING_ATTRIBUTE, true)
		counters.crouches += 1
	elseif not ok and croucher.requested then
		counters.refused += 1
	end
	-- While crouched, the speed follows the load every tick (a pocketing or a small pick-up included).
	local speed = CrouchSpeedFormulas.speed(weight)
	if croucher.lowered ~= nil and humanoid ~= nil and humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
end

local function onHeartbeat(deltaTime: number)
	elapsed += deltaTime
	if elapsed < CrouchConstants.TICK then
		return
	end
	elapsed = 0
	for _, player in Players:GetPlayers() do
		stepOne(player, croucherOf(player))
	end
end

export type CrouchServiceServer = {
	dependencies: { string },
	start: (self: CrouchServiceServer) -> (),
	stop: (self: CrouchServiceServer) -> (),
	getState: (self: CrouchServiceServer) -> { [string]: any },
	isCrouching: (self: CrouchServiceServer, player: Player) -> boolean,
	unloweredSpeed: (self: CrouchServiceServer, player: Player) -> number?,
}

local CrouchServiceServer: CrouchServiceServer = {
	dependencies = {
		"CarryServiceServer",
		"DeathServiceServer",
		"HideServiceServer",
		"SprintServiceServer",
	},

	--[=[
		Listens for crouch requests, composes Carry's speed base with Sprint's, and steps everyone's crouch every TICK.
	]=]
	start = function(self)
		CarryServiceServer:setSpeedBase(function(player: Player): number?
			local crouched = self:unloweredSpeed(player)
			return if crouched ~= nil then crouched else SprintServiceServer:unboostedSpeed(player)
		end)
		table.insert(
			stoppers,
			CrouchEvents.packets.Crouch.listen(function(data: boolean, player: Player?)
				if player then
					onCrouch(data, player)
				end
			end)
		)
		local heartbeat = RunService.Heartbeat:Connect(onHeartbeat)
		local leaving = Players.PlayerRemoving:Connect(function(player: Player)
			crouchers[player.UserId] = nil
		end)
		table.insert(
			stoppers,
			Observers.observeCharacter(function(player: Player, _character: Model)
				-- A fresh body stands (the old one's crouch went with it); the request stays (a held key still holds).
				local croucher = croucherOf(player)
				croucher.lowered = nil
				croucher.base = nil
				return nil
			end)
		)
		table.insert(stoppers, function()
			heartbeat:Disconnect()
			leaving:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		-- Carry's speed base goes back to Sprint's alone.
		CarryServiceServer:setSpeedBase(function(player: Player): number?
			return SprintServiceServer:unboostedSpeed(player)
		end)
		for userId, croucher in crouchers do
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				stand(player, croucher)
			end
		end
		table.clear(crouchers)
	end,

	isCrouching = function(_self, player)
		local croucher = crouchers[player.UserId]
		return croucher ~= nil and croucher.lowered ~= nil
	end,

	--[=[
		The walk under a crouch (Carry's speed base); nil while standing.
	]=]
	unloweredSpeed = function(_self, player)
		local croucher = crouchers[player.UserId]
		return if croucher ~= nil and croucher.lowered ~= nil then croucher.base else nil
	end,

	getState = function(_self)
		local crouching = 0
		local requested = 0
		for _, croucher in crouchers do
			if croucher.lowered ~= nil then
				crouching += 1
			end
			if croucher.requested then
				requested += 1
			end
		end
		return { crouching = crouching, requested = requested, counters = table.clone(counters) }
	end,
}

return CrouchServiceServer
