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
	- marks each holder's character with whether its vacuum is sucking (VacuumMotionConstants.ACTIVE_ATTRIBUTE) and
	  where its camera looks (VacuumAimSystem: AIM_ATTRIBUTE and AIM_YAW_ATTRIBUTE, checked and rate limited), for every client's
	  visual motion layers (VacuumMotionSystem); suction targeting never reads either;
	- fires `vacuumStarted(player, pile)` when a player starts vacuuming a pile (Shift's analytics: first_cleanup_started);
	- answers `canVacuum` for Cargo's grime channels (the loot loop, docs/superpowers/specs/
	  2026-10-15-cleanup-crew-loot-loop-design.md §3.2: a grimy valuable, tagged GRIME_TAG, is vacuumed exactly like a
	  pile; Cargo's CargoGrimeSystem owns the channel and the cleanliness), and pulses the same noise for it;
	- employee stats: the pile channel cleans at each holder's Suction (EmployeeStatFormulas.suctionRate, as Cargo's
	  grime channels do); Noise applies Quiet to the pulses' makers;
	- dresses every character in the canister backpack as it spawns (VacuumVisualSystem.wear), in the depot as on
	  a shift: it is part of the employee's look, its wand clipped on, in the skin the character's
	  VacuumConstants.SKIN_ATTRIBUTE names (EmployeeServiceServer writes it from the player's Cosmetic outfit), and
	  puts the pack on again when that attribute changes (the player picked another vacuum). A
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
local DeathKnockdownUtils = require(ReplicatedStorage.Shared.Features.Death.Utils.DeathKnockdownUtils)
local EmployeeStatFormulas = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeeStatFormulas)
local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local AnimationVacuumSystem = require(ServerScriptService.Features.Animation.Systems.AnimationVacuumSystem)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumMotionConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)
local VacuumMotionRigSystem = require(ReplicatedStorage.Shared.Features.Vacuum.Systems.VacuumMotionRigSystem)
local VacuumChannelTracker = require(ServerScriptService.Features.Vacuum.State.VacuumChannelTracker)
local VacuumToolSystem = require(ServerScriptService.Features.Vacuum.Systems.VacuumToolSystem)
local VacuumAimSystem = require(ServerScriptService.Features.Vacuum.Systems.VacuumAimSystem)
local VacuumVisualSystem = require(ServerScriptService.Features.Vacuum.Systems.VacuumVisualSystem)
local VacuumEquipmentRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumEquipmentRules)
local VacuumSkinRegistry = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)
local VacuumSkinRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumSkinRules)
local VacuumTargetRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumTargetRules)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)
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

-- Marks whether `character`'s vacuum is sucking now (every client's brace and shimmy read it), when that changed.
local function publishActive(character: Model?, active: boolean)
	if character ~= nil and character:GetAttribute(VacuumMotionConstants.ACTIVE_ATTRIBUTE) ~= active then
		character:SetAttribute(VacuumMotionConstants.ACTIVE_ATTRIBUTE, active)
	end
end

-- The skin `character` should wear (its SKIN_ATTRIBUTE; Standard Issue when unset or unknown).
local function wantedSkin(character: Model): VacuumSkinRegistry.SkinDef
	local wanted = character:GetAttribute(VacuumConstants.SKIN_ATTRIBUTE)
	return VacuumSkinRules.select(if type(wanted) == "string" then wanted else nil)
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
	local backpack = VacuumVisualSystem.wear(character, wantedSkin(character))
	if backpack ~= nil then
		worn[character] = backpack
	end
	return backpack
end

-- The client's pick re-checked (VacuumTargetRules, with TARGET_SLACK): `pile` is near the held wand's floor
-- head, underfoot, or in front of the body.
local SERVER_REACH = VacuumTargetRules.widened(VacuumConstants.TARGET, VacuumConstants.TARGET_SLACK)
local function inReach(player: Player, pile: Instance): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") or not pile:IsA("BasePart") then
		return false
	end
	local tool = if character ~= nil then character:FindFirstChild(VacuumConstants.TOOL_NAME) else nil
	local head = if tool ~= nil then tool:FindFirstChild(VacuumConstants.FLOOR_HEAD_NAME) else nil
	local measured = if head ~= nil and head:IsA("BasePart")
		then VacuumTargetRules.head(head.CFrame, head.Size)
		else nil
	-- The nozzle where the client's aim lays it, computed here from the look it sent (never a client position).
	if VacuumConstants.SUCTION_FOLLOWS_NOZZLE and character ~= nil then
		local yaw = character:GetAttribute(VacuumMotionConstants.AIM_YAW_ATTRIBUTE)
		local pitch = character:GetAttribute(VacuumMotionConstants.AIM_ATTRIBUTE)
		measured = VacuumMotionRigSystem.nozzleHead(
			character,
			math.rad(if type(yaw) == "number" then yaw else 0),
			if type(pitch) == "number" then math.rad(pitch) else VacuumMotionConstants.aim.neutral
		) or measured
	end
	return VacuumTargetRules.reaches(
		root.Position,
		root.CFrame.LookVector,
		measured,
		{
			position = pile.Position,
			radius = VacuumTargetRules.radius(pile.Size, pile:GetAttribute(VacuumConstants.BASE_SIZE_ATTRIBUTE)),
		},
		VacuumTargetRules.withCone(
			SERVER_REACH,
			VacuumTargetRules.coneOn(
				RunService:IsStudio(),
				workspace:GetAttribute(VacuumConstants.DEV_CONE_ATTRIBUTE),
				VacuumConstants.TARGET.cone ~= false
			)
		)
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
-- hands hold an item or while knocked down; the vacuum must be on the target. A start on a new target fires
-- `vacuumStarted`. Never yields.
local function canVacuum(player: Player, target: Instance): boolean
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if
		not VacuumEquipmentRules.canVacuum(
			tools[player] ~= nil,
			VacuumToolSystem.isEquipped(character),
			CarryServiceServer:getCarried(player) ~= nil,
			-- Knocked down (Death's knockdown) counts as not able to work, like dead.
			humanoid ~= nil and humanoid.Health > 0 and not DeathKnockdownUtils.isDown(character)
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
		"HideServiceServer",
	},
	pileCleared = pileCleared,
	noiseMade = noiseMade,
	vacuumStarted = vacuumStarted,

	--[=[
		Handles the pile channel, shrinks piles as they progress, pulses vacuum noise, forgets leavers.
	]=]
	start = function(self)
		InteractionServiceServer:channel(VacuumConstants.CHANNEL_KIND, {
			canChannel = canVacuum,
			rate = EmployeeStatFormulas.suctionRate,
			onComplete = clear,
		})

		-- Every employee wears the pack, in the depot too (the wand clipped on until a shift's Tool takes it).
		table.insert(
			stoppers,
			Observers.observeCharacter(function(_player: Player, character: Model)
				wornFor(character)
				-- Another vacuum picked in the depot (Cosmetic refuses changes in a shift): the new pack goes on.
				local skinChanged = character
					:GetAttributeChangedSignal(VacuumConstants.SKIN_ATTRIBUTE)
					:Connect(function()
						local current = worn[character]
						if current ~= nil and current.skin.name ~= wantedSkin(character).name then
							current.destroy()
							worn[character] = nil
							wornFor(character)
						end
					end)
				return function()
					skinChanged:Disconnect()
					local backpack = worn[character]
					worn[character] = nil
					if backpack ~= nil then
						backpack.destroy()
					end
				end
			end)
		)

		-- Going into a hiding spot puts the wand back on the backpack first (so Hide measures the body with it on); it
		-- stays there (no resume).
		HideServiceServer:setBeforeEnter(function(player: Player)
			self:setEquipped(player, false)
		end)
		table.insert(stoppers, function()
			HideServiceServer:setBeforeEnter(nil)
		end)

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
					local active = channels:isActive(player.UserId, os.clock())
					publishActive(character, selected and active)
					if animation ~= nil then
						animation.update({
							character = character,
							equipped = selected,
							carrying = carrying,
							active = active,
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
		table.insert(stoppers, VacuumAimSystem.start())
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
				publishActive(player.Character, false)
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
