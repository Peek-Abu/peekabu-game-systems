--!strict
--[=[
	VacuumServiceServer: piles and the vacuum (Cleanup Crew spec §4 "Vacuum", §6.4). A pile is a tagged
	part carrying the `pile` Interaction channel kind, so holding the vacuum on it is Interaction's channel:
	progress accumulates on the server, is kept on release, and several players' rates add. This service:

	- registers the channel (8 studs, 2.5 s) and refuses it to a player whose hands hold an item, or whose
	  vacuum is not on that pile (VacuumTargetRules, the client's own pick with slack; re-checked every tick);
	- shrinks a pile as its ChannelProgress rises;
	- on completion destroys the pile and fires `pileCleared` (Office reveals what was hidden under it; Shift credits
	  its Gloom to the contract, VacuumConstants.PILE_GLOOM, and counts piles; docs/superpowers/specs/
	  2026-10-16-cleanup-crew-gloom-gleam-economy-design.md: no canister capacity, no dust bags) and, every second a
	  pile is being vacuumed, `noiseMade` (the M2 Noise seam; nothing listens in M1).
	- fires `vacuumStarted(player, pile)` when a player starts vacuuming a pile (Shift's analytics: first_cleanup_started);
	- answers `canVacuum` for Cargo's grime channels (the loot loop, docs/superpowers/specs/
	  2026-10-15-cleanup-crew-loot-loop-design.md §3.2: a grimy valuable, tagged GRIME_TAG, is vacuumed exactly like a
	  pile; Cargo's CargoGrimeSystem owns the channel and the cleanliness), and pulses the same noise for it;
	- dresses every character in the canister backpack as it spawns (VacuumVisualSystem.wear), in the depot as on
	  a shift: it is part of the employee's look, its wand clipped on, in its player's skin (VacuumSkinRules). A
	  shift's crew are given the vacuum Tool (VacuumToolSystem), which takes the wand off that same pack while held
	  (never a second pack).

	Spec-exempt shell (Instances, Players, RunService, signals); the aim is the specced VacuumTargetRules.

	@class VacuumServiceServer
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local AnimationVacuumSystem = require(ServerScriptService.Features.Animation.Systems.AnimationVacuumSystem)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumChannelTracker = require(ServerScriptService.Features.Vacuum.State.VacuumChannelTracker)
local VacuumToolSystem = require(ServerScriptService.Features.Vacuum.Systems.VacuumToolSystem)
local VacuumVisualSystem = require(ServerScriptService.Features.Vacuum.Systems.VacuumVisualSystem)
local VacuumEquipmentRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumEquipmentRules)
local VacuumSkinRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumSkinRules)
local VacuumTargetRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumTargetRules)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

-- Registered at load: the channel is a server rule (the client only names the pile it aims at).
if not InteractionRegistry.hasChannel(VacuumConstants.CHANNEL_KIND) then
	InteractionRegistry.registerChannel(VacuumConstants.CHANNEL_KIND, {
		duration = VacuumConstants.DURATION,
		maxDistance = VacuumConstants.RANGE,
	})
end

local pileCleared: SignalTyped.Signal<BasePart, { Player }> = SignalTyped.new()
local noiseMade: SignalTyped.Signal<Vector3, number, string, { number }> = SignalTyped.new()
local vacuumStarted: SignalTyped.Signal<Player, BasePart> = SignalTyped.new()

local tools: { [Player]: VacuumToolSystem.Controller } = {}
local equipped: { [Player]: boolean } = {}
local animations: { [Player]: AnimationVacuumSystem.Controller } = {}
-- Who is vacuuming which pile (vacuumStarted fires when a player's pile changes; the makers of each noise pulse).
local channels = VacuumChannelTracker.new(VacuumConstants.MAKER_WINDOW)
local counters = { spawned = 0, cleared = 0 }
local stoppers: { () -> () } = {}
-- The canister backpack each character wears.
local worn: { [Model]: VacuumVisualSystem.WornBackpack } = {}

-- Publishes whether `player`'s vacuum is out, when that changed.
local function publishEquipped(player: Player, selected: boolean)
	if equipped[player] ~= selected then
		equipped[player] = selected
		StateSyncPublicPlayerStore.set(player.UserId, { [VacuumConstants.PUBLIC_EQUIPPED_FIELD] = selected })
	end
end

-- `character`'s backpack, put on now if it has none (nil when it cannot wear one: no UpperTorso yet).
local function wornFor(character: Model): VacuumVisualSystem.WornBackpack?
	local current = worn[character]
	if current ~= nil and current.model.Parent == character then
		return current
	end
	if current ~= nil then
		current.destroy()
		worn[character] = nil
	end
	-- In its player's skin (VacuumSkinRules: the owner's MVP allowlist, else Standard Issue).
	local player = Players:GetPlayerFromCharacter(character)
	local backpack =
		VacuumVisualSystem.wear(character, if player ~= nil then VacuumSkinRules.forPlayer(player.UserId) else nil)
	if backpack ~= nil then
		worn[character] = backpack
	end
	return backpack
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- The client's pick re-checked (VacuumTargetRules, with TARGET_SLACK): `pile` is near the held wand's floor
-- head, underfoot, or in front of the body.
local SERVER_REACH = VacuumTargetRules.widened(VacuumConstants.TARGET, VacuumConstants.TARGET_SLACK)
local function inReach(player: Player, pile: Instance): boolean
	local root = rootOf(player)
	if root == nil or not pile:IsA("BasePart") then
		return false
	end
	local character = player.Character
	local tool = if character ~= nil then character:FindFirstChild(VacuumConstants.TOOL_NAME) else nil
	local head = if tool ~= nil then tool:FindFirstChild(VacuumConstants.FLOOR_HEAD_NAME) else nil
	return VacuumTargetRules.reaches(
		root.Position,
		root.CFrame.LookVector,
		if head ~= nil and head:IsA("BasePart") then VacuumTargetRules.head(head.CFrame, head.Size) else nil,
		{
			position = pile.Position,
			radius = VacuumTargetRules.radius(pile.Size, pile:GetAttribute(VacuumConstants.BASE_SIZE_ATTRIBUTE)),
		},
		SERVER_REACH
	)
end

-- Scales a pile down with its progress, keeping it on the floor.
local function shrink(pile: BasePart)
	local base = pile:GetAttribute(VacuumConstants.BASE_SIZE_ATTRIBUTE)
	if typeof(base) ~= "Vector3" then
		return
	end
	local progress = pile:GetAttribute(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE)
	local fraction = if type(progress) == "number" then progress else 0
	local scale = 1 - (1 - VacuumConstants.MIN_SCALE) * fraction
	local bottom = pile.Position.Y - pile.Size.Y / 2
	pile.Size = base * scale
	pile.Position = Vector3.new(pile.Position.X, bottom + pile.Size.Y / 2, pile.Position.Z)
end

-- The channel's completion: the pile is cleared once, for everyone on it.
local function clear(players: { Player }, target: Instance)
	if not target:IsA("BasePart") then
		return
	end
	-- Destroyed (not just forgotten) so a still-held channel cannot restart on this pile.
	target:Destroy()
	counters.cleared += 1
	pileCleared:Fire(target, players)
end

-- One noise pulse per pile (or grimy item) someone is vacuuming right now.
local function pulse()
	for _, tag in { VacuumConstants.PILE_TAG, VacuumConstants.GRIME_TAG } do
		for _, target in CollectionService:GetTagged(tag) do
			local count = target:GetAttribute(InteractionConstants.CHANNEL_COUNT_ATTRIBUTE)
			if target:IsA("BasePart") and type(count) == "number" and count > 0 then
				noiseMade:Fire(
					target.Position,
					VacuumConstants.NOISE_RADIUS,
					"vacuum",
					channels:makersOn(target, os.clock())
				)
			end
		end
	end
end

-- Whether `player` may vacuum `target` now (asked at the start and every tick): spec §4, you can't vacuum while your
-- hands hold an item; the vacuum must be on the target. A start on a new target fires `vacuumStarted`. Never yields.
local function canVacuum(player: Player, target: Instance): boolean
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if
		not VacuumEquipmentRules.canVacuum(
			tools[player] ~= nil,
			VacuumToolSystem.isEquipped(character),
			CarryServiceServer:getCarried(player) ~= nil,
			humanoid ~= nil and humanoid.Health > 0
		) or not inReach(player, target)
	then
		return false
	end
	if channels:note(player.UserId, target, os.clock()) and target:IsA("BasePart") then
		vacuumStarted:Fire(player, target)
	end
	return true
end

export type VacuumServiceServer = {
	dependencies: { string },
	pileCleared: SignalTyped.Signal<BasePart, { Player }>,
	noiseMade: SignalTyped.Signal<Vector3, number, string, { number }>,
	vacuumStarted: SignalTyped.Signal<Player, BasePart>,
	start: (self: VacuumServiceServer) -> (),
	canVacuum: (self: VacuumServiceServer, player: Player, target: Instance) -> boolean,
	stop: (self: VacuumServiceServer) -> (),
	getState: (self: VacuumServiceServer) -> { [string]: any },
	spawnPile: (self: VacuumServiceServer, kind: string, floor: CFrame, parent: Instance) -> BasePart,
	isVacuuming: (self: VacuumServiceServer, player: Player) -> boolean,
	reset: (self: VacuumServiceServer) -> (),
	setCrew: (self: VacuumServiceServer, crew: { Player }) -> (),
	setEquipped: (self: VacuumServiceServer, player: Player, on: boolean, resume: boolean?) -> boolean,
}

local VacuumServiceServer: VacuumServiceServer = {
	dependencies = {
		"InteractionServiceServer",
		"CarryServiceServer",
		"StateSyncServiceServer",
		"AnimationServiceServer",
	},
	pileCleared = pileCleared,
	noiseMade = noiseMade,
	vacuumStarted = vacuumStarted,

	--[=[
		Handles the pile channel, shrinks piles as they progress, pulses vacuum noise, forgets leavers.
	]=]
	start = function(_self)
		InteractionServiceServer:channel(VacuumConstants.CHANNEL_KIND, {
			canChannel = canVacuum,
			onComplete = clear,
		})

		-- Every employee wears the pack, in the depot too (the wand clipped on until a shift's Tool takes it).
		table.insert(
			stoppers,
			Observers.observeCharacter(function(_player: Player, character: Model)
				wornFor(character)
				return function()
					local backpack = worn[character]
					worn[character] = nil
					if backpack ~= nil then
						backpack.destroy()
					end
				end
			end)
		)

		table.insert(
			stoppers,
			Observers.observeTag(VacuumConstants.PILE_TAG, function(pile: Instance)
				if not pile:IsA("BasePart") then
					return nil
				end
				local changed = pile:GetAttributeChangedSignal(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE)
					:Connect(function()
						shrink(pile)
					end)
				return function()
					changed:Disconnect()
				end
			end)
		)

		local elapsed = 0
		local equipmentElapsed = 0
		local ticking = RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			equipmentElapsed += deltaTime
			if equipmentElapsed >= VacuumConstants.TOOL_REFRESH_INTERVAL then
				equipmentElapsed = 0
				for player, controller in tools do
					local carrying = CarryServiceServer:getCarried(player) ~= nil
					local selected = controller.refresh(carrying)
					local character = player.Character
					local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
					local animation = animations[player]
					if animation ~= nil then
						animation.update({
							character = character,
							equipped = selected,
							carrying = carrying,
							active = channels:isActive(player.UserId, os.clock()),
							alive = humanoid ~= nil and humanoid.Health > 0,
							authorized = true,
						}, os.clock())
					end
					publishEquipped(player, selected)
				end
			end
			if elapsed >= VacuumConstants.NOISE_INTERVAL then
				elapsed = 0
				pulse()
			end
		end)
		local leaving = Players.PlayerRemoving:Connect(function(player)
			local controller = tools[player]
			if controller ~= nil then
				controller.destroy()
				local animation = animations[player]
				if animation ~= nil then
					animation.stop()
					animations[player] = nil
				end
				tools[player] = nil
			end
			equipped[player] = nil
			channels:forget(player.UserId)
		end)
		table.insert(stoppers, function()
			ticking:Disconnect()
			leaving:Disconnect()
		end)
	end,

	stop = function(self)
		self:setCrew({})
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		Places a pile of `kind` (VacuumConstants.PILE_KINDS) standing on `floor`, under `parent`.
	]=]
	spawnPile = function(_self, kind, floor, parent)
		local style = VacuumConstants.PILE_KINDS[kind]
		assert(style ~= nil, `spawnPile: unknown pile kind "{kind}"`)
		local pile = Instance.new("Part")
		pile.Name = `Pile ({kind})`
		pile.Size = style.size
		pile.Color = style.color
		pile.Material = style.material
		pile.Anchored = true
		pile.CanCollide = false
		pile.CanTouch = false
		-- Floor raycasts (item placement) must pass through piles; the client aim uses distance + dot, not rays.
		pile.CanQuery = false
		pile.CFrame = floor * CFrame.new(0, style.size.Y / 2, 0)
		pile:SetAttribute(VacuumConstants.PILE_KIND_ATTRIBUTE, kind)
		pile:SetAttribute(VacuumConstants.BASE_SIZE_ATTRIBUTE, style.size)
		pile:SetAttribute(InteractionConstants.CHANNEL_KIND_ATTRIBUTE, VacuumConstants.CHANNEL_KIND)
		pile.Parent = parent
		CollectionService:AddTag(pile, VacuumConstants.PILE_TAG)
		counters.spawned += 1
		return pile
	end,

	--[=[
		Whether `player` may vacuum `target` now: equipped, empty hands, alive, the wand on it (Cargo's grime channels
		ask this every tick). Never yields.
	]=]
	canVacuum = function(_self, player, target)
		return canVacuum(player, target)
	end,

	--[=[
		Whether `player` is vacuuming a pile right now (their channel asked within MAKER_WINDOW).
	]=]
	isVacuuming = function(_self, player)
		return channels:isActive(player.UserId, os.clock())
	end,

	--[=[
		Takes the crew's vacuums and forgets who vacuumed what (a new shift). Piles go with the shift's container (Office).
	]=]
	reset = function(self)
		self:setCrew({})
		channels:clear()
	end,

	--[=[
		Takes `player`'s vacuum out (true) or puts it away (false) now: the hotbar's slot 1 (Cargo's inventory). Put away
		with `resume`, it comes back by itself when the carry about to start ends. False when they have no vacuum (not on a
		shift's crew, no living character) or it could not be taken out. Never yields.
	]=]
	setEquipped = function(_self, player, on, resume)
		local controller = tools[player]
		local ok = controller ~= nil and controller.setEquipped(on, resume)
		publishEquipped(player, on and ok)
		return ok
	end,

	setCrew = function(_self, crew)
		local wanted: { [Player]: boolean } = {}
		for _, player in crew do
			wanted[player] = true
		end
		for player, controller in tools do
			if not wanted[player] then
				controller.destroy()
				local animation = animations[player]
				if animation ~= nil then
					animation.stop()
					animations[player] = nil
				end
				tools[player] = nil
				equipped[player] = nil
				StateSyncPublicPlayerStore.set(player.UserId, { [VacuumConstants.PUBLIC_EQUIPPED_FIELD] = false })
			end
		end
		for player in wanted do
			if tools[player] == nil then
				tools[player] = VacuumToolSystem.new(player, wornFor)
				animations[player] = AnimationVacuumSystem.new({
					available = function(id)
						return AnimationRegistry.get(id) ~= nil
					end,
					play = function(id)
						local ok = AnimationServiceServer:play(player, id)
						return ok
					end,
					stop = function(id)
						AnimationServiceServer:stop(player, id)
					end,
				})
			end
		end
	end,

	getState = function(_self)
		local wearing = 0
		for character in worn do
			if character.Parent ~= nil then
				wearing += 1
			end
		end
		return {
			piles = #CollectionService:GetTagged(VacuumConstants.PILE_TAG),
			wearing = wearing,
			counters = table.clone(counters),
		}
	end,
}

return VacuumServiceServer
