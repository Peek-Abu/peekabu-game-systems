--!strict
--[=[
	ShiftPromptSystem: draws the Interaction prompts on paper (Cleanup Crew M3 UI, Figma 1a). Every Interaction prompt
	(the ProximityPrompt named InteractionConstants.PROMPT_NAME that the base Interaction feature creates under an
	object tagged InteractionConstants.TAG) is switched to the Custom style on this client: a local property write, so
	the engine stops drawing its own card while its key (and the server's trigger) still work. Prompts created later
	(a newly tagged object, a respawned one, a prompt rebuilt under a tagged object) are switched as they appear, and a
	prompt shown before it was switched is switched when it shows; no other prompt is touched. The engine's Shown /
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
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

-- Adopted prompts, each with the watch that forgets it when it leaves the game.
local watches: { [ProximityPrompt]: RBXScriptConnection? } = {}
-- The store id of each adopted prompt that has been shown.
local ids: { [ProximityPrompt]: number } = {}
local nextId = 0
-- The prompt shown now, and the prompt `press(true)` is holding.
local current: ProximityPrompt? = nil
local held: ProximityPrompt? = nil

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
	if prompt.Name ~= InteractionConstants.PROMPT_NAME or not underTagged(prompt) then
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

local ShiftPromptSystem = {}

function ShiftPromptSystem.start(): () -> ()
	local connections: { RBXScriptConnection } = {}
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
