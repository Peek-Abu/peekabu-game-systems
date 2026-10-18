--!strict
--[=[
	ShiftPromptSystem: draws the Interaction prompts on paper (Cleanup Crew M3 UI, Figma 1a). Every Interaction prompt
	(the ProximityPrompt named InteractionConstants.PROMPT_NAME that the base Interaction feature creates under an
	object tagged InteractionConstants.TAG) is switched to the Custom style on this client: a local property write, so
	the engine stops drawing its own card while its key (and the server's trigger) still work. Prompts created later
	(a newly tagged object, a respawned one, a prompt rebuilt under a tagged object) are switched as they appear, and a
	prompt shown before it was switched is switched when it shows; no other prompt is touched. Nearby selection controls native activation range; the engine's Shown /
	Hidden / hold events keep ShiftPromptStore current; `press` holds or releases the shown prompt for touch (the chip
	and the phone LOAD button get it as a prop). A held prompt is let go when it hides or is removed. The engine accepts
	InputHoldBegin only on a prompt shown on this client, and the server still validates every trigger
	(InteractionServiceServer).

	The bookkeeping tables are keyed by Instance with STRONG keys, and entries are removed explicitly when a prompt
	leaves the game or its object is untagged: never weak Instance keys, because the engine can collect and recreate
	an Instance's Lua wrapper while the Instance lives, which silently drops a weak key.

	Spec-exempt shell (ProximityPromptService, Instances); the chip's words are the specced ShiftHudViewModel.prompt and
	the bookkeeping the specced ShiftPromptStore.

	@class ShiftPromptSystem
]=]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

-- Adopted prompts, each with the watch that forgets it when it leaves the game.
local watches: { [ProximityPrompt]: RBXScriptConnection? } = {}
-- The store id of each adopted prompt that has been shown.
local ids: { [ProximityPrompt]: number } = {}
local CarryServiceClient = require(ReplicatedStorage.Client.Features.Carry.CarryServiceClient)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CargoBankRules = require(ReplicatedStorage.Shared.Features.Cargo.Rules.CargoBankRules)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoInventoryRules = require(ReplicatedStorage.Shared.Features.Cargo.Rules.CargoInventoryRules)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local Rules = require(ReplicatedStorage.Client.Features.Shift.Rules.ShiftPromptRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTimeClockRules = require(ReplicatedStorage.Shared.Features.Shift.Rules.ShiftTimeClockRules)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local ranges: { [ProximityPrompt]: number } = {}
local chosen: ProximityPrompt? = nil
local nextId = 0
-- The prompt shown now, and the prompt `press(true)` is holding.
local current: ProximityPrompt? = nil
local held: ProximityPrompt? = nil

-- The kind the local player holds (their public `carrying` field; nil with empty hands).
local function heldKind(): string?
	local entry = StateSyncClientStore.publicPlayers()[StateSyncConstants.publicEntryKey(Players.LocalPlayer.UserId)]
	local kind = if entry ~= nil then entry[CarryConstants.PUBLIC_FIELD] else nil
	return if type(kind) == "string" then kind else nil
end

-- Whether an instance sits under an object tagged InteractionConstants.TAG.
local function underTagged(instance: Instance): boolean
	local node: Instance? = instance.Parent
	while node ~= nil do
		if node:HasTag(InteractionConstants.TAG) then
			return true
		end
		node = node.Parent
	end
	return false
end

-- The Interaction kind of the object a prompt belongs to (the tagged ancestor's attribute).
local function targetOf(prompt: ProximityPrompt): Instance?
	local node: Instance? = prompt.Parent
	while node ~= nil do
		if node:HasTag(InteractionConstants.TAG) then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function kindOf(prompt: ProximityPrompt): string?
	local node: Instance? = prompt.Parent
	while node ~= nil do
		local kind = node:GetAttribute(InteractionConstants.KIND_ATTRIBUTE)
		if type(kind) == "string" then
			return kind
		end
		node = node.Parent
	end
	return nil
end

-- The truck's paperwork (Clock out, Start overtime) is a candidate only with empty hands, in front of it in the box:
-- the rule the server refuses by, so it never takes the key from Bank cargo, and never once the local player has
-- clocked out (they wait in the truck; the server refuses them too). Every other prompt passes.
local function paperworkUsable(prompt: ProximityPrompt, target: Instance, root: BasePart): boolean
	local kind = kindOf(prompt)
	if kind ~= ShiftConstants.CLOCK_OUT_KIND and kind ~= ShiftConstants.OVERTIME_KIND then
		return true
	end
	local snapshot = ShiftStore.snapshot()
	if not target:IsA("BasePart") or (snapshot ~= nil and table.find(snapshot.punched, Players.LocalPlayer.UserId)) then
		return false
	end
	local ok =
		ShiftTimeClockRules.canUse(target.CFrame:PointToObjectSpace(root.Position), CarryServiceClient:isCarrying())
	return ok
end

local function release()
	local prompt = held
	held = nil
	if prompt ~= nil and prompt.Parent ~= nil then
		prompt:InputHoldEnd()
	end
end

-- Drops a prompt from the bookkeeping: lets go of it, takes it off the chip, forgets its id and its watch.
local function forget(prompt: ProximityPrompt)
	if held == prompt then
		release()
	end
	if current == prompt then
		current = nil
	end
	if chosen == prompt then
		chosen = nil
	end
	local range = ranges[prompt]
	if range ~= nil and prompt.Parent ~= nil then
		prompt.MaxActivationDistance = range
	end
	ranges[prompt] = nil
	local id = ids[prompt]
	if id ~= nil then
		ShiftPromptStore.hide(id)
		ids[prompt] = nil
	end
	local watch: RBXScriptConnection? = watches[prompt]
	if watch ~= nil then
		watch:Disconnect()
		watches[prompt] = nil
	end
end

-- Switches an Interaction prompt to the Custom style and (once) watches for it leaving the game.
local function adopt(prompt: ProximityPrompt)
	prompt.Style = Enum.ProximityPromptStyle.Custom
	if watches[prompt] ~= nil then
		return
	end
	ranges[prompt] = prompt.MaxActivationDistance
	nextId += 1
	ids[prompt] = nextId
	prompt.MaxActivationDistance = 0
	watches[prompt] = prompt.AncestryChanged:Connect(function()
		if not prompt:IsDescendantOf(game) then
			forget(prompt)
		end
	end)
end

local function adoptIfOurs(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance.Name == InteractionConstants.PROMPT_NAME then
		adopt(instance)
	end
end

local function onShown(prompt: ProximityPrompt)
	if prompt ~= chosen or prompt.Name ~= InteractionConstants.PROMPT_NAME or not underTagged(prompt) then
		return
	end
	-- Shown before the tag observer reached it: adopt it now.
	adopt(prompt)
	local id = ids[prompt]
	if id == nil then
		nextId += 1
		id = nextId
		ids[prompt] = id
	end
	current = prompt
	ShiftPromptStore.show({
		id = id,
		target = targetOf(prompt),
		action = prompt.ActionText,
		object = prompt.ObjectText,
		key = ShiftHudViewModel.keyName(prompt.KeyboardKeyCode),
		hold = prompt.HoldDuration,
		kind = kindOf(prompt),
	})
end

local function onHidden(prompt: ProximityPrompt)
	if held == prompt then
		release()
	end
	if current == prompt then
		current = nil
	end
	local id = ids[prompt]
	if id ~= nil then
		ShiftPromptStore.hide(id)
	end
end

-- One sight ray setup for every pick. The ray looks past what ShiftPromptRules.sight says does not hide a prompt
-- (invisible non-colliding volumes, see-through art, what the player carries), adding each to the filter; it is
-- reset to the player's own character before every prompt's ray.
local sight = RaycastParams.new()
sight.FilterType = Enum.RaycastFilterType.Exclude
-- Parts looked past before a ray gives up and counts the prompt as hidden.
local SIGHT_MAX_PIERCE = 8

-- Whether the camera sees `target` at `position`: the first part on the way that hides it decides.
local function inSight(origin: Vector3, position: Vector3, target: Instance, character: Model, root: BasePart): boolean
	sight.FilterDescendantsInstances = { character }
	local direction = position - origin
	for _ = 1, SIGHT_MAX_PIERCE do
		local result = Workspace:Raycast(origin, direction, sight)
		if result == nil then
			return true
		end
		local hit = result.Instance
		local verdict = if hit:IsA("BasePart") then Rules.sight(hit, target, root) else "past"
		if verdict ~= "past" then
			return verdict == "target"
		end
		sight:AddToFilter(hit)
	end
	return false
end

-- The engine's native input only sees the chosen prompt in range. Others get a local zero range;
-- authoritative reach/enabled checks still run on the server. Never mutate the object's attributes.
local function selectNearby()
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local camera = Workspace.CurrentCamera
	local candidates: { Rules.Candidate } = {}
	local byId: { [number]: ProximityPrompt } = {}
	if
		character ~= nil
		and root ~= nil
		and root:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and camera ~= nil
	then
		for prompt, id in ids do
			local target = targetOf(prompt)
			local parent = prompt.Parent
			local position: Vector3? = nil
			if parent ~= nil and parent:IsA("BasePart") then
				position = parent.Position
			elseif parent ~= nil and parent:IsA("Attachment") then
				position = parent.WorldPosition
			end
			local offset = if position ~= nil then position - root.Position else Vector3.zero
			local distance = offset.Magnitude
			local kind = kindOf(prompt)
			local isLoad = kind == CargoConstants.LOAD_KIND and target ~= nil and target:IsA("BasePart")
			local range = if isLoad
				then ranges[prompt] or 0
				else math.min(ranges[prompt] or 0, if kind == "carry" then 6 else 8)
			-- Out of reach can never be chosen (ShiftPromptRules.choose), so the sight ray and the screen
			-- projection are spent only on the few prompts within reach, not on every prompt in the office.
			if target ~= nil and position ~= nil and distance <= range and paperworkUsable(prompt, target, root) then
				local screen, onScreen = camera:WorldToViewportPoint(position)
				local visible = onScreen
					and screen.Z > 0
					and inSight(camera.CFrame.Position, position, target, character, root)
				local loadReach = true
				if isLoad and target:IsA("BasePart") then
					loadReach = CargoBankRules.canLoad(target.CFrame:PointToObjectSpace(root.Position), target.Size)
				end
				table.insert(candidates, {
					id = id,
					distance = distance,
					dot = if distance > 0 then camera.CFrame.LookVector:Dot(offset.Unit) else 1,
					range = range,
					visible = visible,
					enabled = loadReach
						and target:GetAttribute(InteractionConstants.ENABLED_ATTRIBUTE) ~= false
						and (
							kind ~= "carry"
							or (
																-- The hotbar: a small item in one hand still lets E pocket another.
CargoInventoryRules.handsFree(heldKind())
								and target:GetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE) == nil
							)
						),
				})
				byId[id] = prompt
			end
		end
	end
	local selected = Rules.choose(candidates, if chosen ~= nil then ids[chosen] else nil)
	local nextPrompt = if selected ~= nil then byId[selected] else nil
	if nextPrompt ~= chosen then
		release()
		if current ~= nil then
			onHidden(current)
		end
		chosen = nextPrompt
	end
	for prompt in ranges do
		local want = if prompt == chosen
			then (if kindOf(prompt) == CargoConstants.LOAD_KIND
				then ranges[prompt] or 0
				else math.min(ranges[prompt] or 0, if kindOf(prompt) == "carry" then 6 else 8))
			else 0
		if prompt.MaxActivationDistance ~= want then
			prompt.MaxActivationDistance = want
		end
	end
end

local ShiftPromptSystem = {}

function ShiftPromptSystem.start(): () -> ()
	local connections: { RBXScriptConnection } = {}
	local elapsed = 0
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			elapsed += dt
			if elapsed >= 0.1 then
				elapsed = 0
				selectNearby()
			end
		end)
	)
	local stopObserver = Observers.observeTag(InteractionConstants.TAG, function(target: Instance)
		-- The server parents the prompt under the object's root part; it may replicate after the tag does.
		for _, descendant in target:GetDescendants() do
			adoptIfOurs(descendant)
		end
		local added = target.DescendantAdded:Connect(adoptIfOurs)
		return function()
			added:Disconnect()
			-- Untagged: its prompts are no longer Interaction prompts.
			local gone: { ProximityPrompt } = {}
			for prompt in watches do
				if prompt:IsDescendantOf(target) then
					table.insert(gone, prompt)
				end
			end
			for _, prompt in gone do
				forget(prompt)
			end
		end
	end)
	table.insert(connections, ProximityPromptService.PromptShown:Connect(onShown))
	table.insert(connections, ProximityPromptService.PromptHidden:Connect(onHidden))
	table.insert(
		connections,
		ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt, player: Player)
			local id = ids[prompt]
			if id ~= nil and player == Players.LocalPlayer then
				-- The server clock, as useServerClock reads it, so the chip's fill compares like with like.
				ShiftPromptStore.holdBegan(id, Workspace:GetServerTimeNow())
			end
		end)
	)
	table.insert(
		connections,
		ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt, player: Player)
			local id = ids[prompt]
			if id ~= nil and player == Players.LocalPlayer then
				ShiftPromptStore.holdEnded(id)
			end
		end)
	)
	return function()
		stopObserver()
		for _, connection in connections do
			connection:Disconnect()
		end
		release()
		current = nil
		for _, watch in watches do
			if watch ~= nil then
				watch:Disconnect()
			end
		end
		for prompt, range in ranges do
			if prompt.Parent ~= nil then
				prompt.MaxActivationDistance = range
			end
		end
		table.clear(ranges)
		chosen = nil
		table.clear(watches)
		table.clear(ids)
		ShiftPromptStore.clear()
	end
end

--[=[
	Holds (`down`) or releases the shown prompt: the touch path for the chip and the phone LOAD button. A release goes
	to the prompt this held, even if it has been hidden since; a release without a hold does nothing.
]=]
function ShiftPromptSystem.press(down: boolean)
	if not down then
		release()
		return
	end
	local prompt = current
	if prompt == nil or prompt.Parent == nil or held ~= nil then
		return
	end
	held = prompt
	prompt:InputHoldBegin()
end

return ShiftPromptSystem
