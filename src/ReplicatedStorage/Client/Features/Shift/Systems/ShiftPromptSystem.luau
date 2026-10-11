--!strict
--[=[
	ShiftPromptSystem: draws the Interaction prompts on paper (Cleanup Crew M3 UI, Figma 1a). Every Interaction prompt
	(the ProximityPrompt named InteractionConstants.PROMPT_NAME that the base Interaction feature creates under an
	object tagged InteractionConstants.TAG) is switched to the Custom style on this client: a local property write, so
	the engine stops drawing its own card while its key (and the server's trigger) still work. Prompts created later
	(a newly tagged object, a respawned one, a prompt rebuilt under a tagged object) are switched as they appear; no
	other prompt is touched. The engine's Shown / Hidden / hold events keep ShiftPromptStore current; `press` holds or
	releases the shown prompt for touch (the chip and the phone LOAD button get it as a prop). The engine accepts
	InputHoldBegin only on a prompt shown on this client, and the server still validates every trigger
	(InteractionServiceServer).

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

-- Weak keys: a destroyed prompt drops out of both tables on its own (objects are rebuilt every shift).
local ids: { [ProximityPrompt]: number } = {}
local ours: { [ProximityPrompt]: boolean } = {}
setmetatable(ids, { __mode = "k" })
setmetatable(ours, { __mode = "k" })
local nextId = 0
-- The prompt shown now, and the prompt `press(true)` is holding (released even if it was hidden meanwhile).
local current: ProximityPrompt? = nil
local held: ProximityPrompt? = nil
local currentGone: RBXScriptConnection? = nil

local function idOf(prompt: ProximityPrompt): number
	local id = ids[prompt]
	if id == nil then
		nextId += 1
		id = nextId
		ids[prompt] = id
	end
	return id
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

-- Switches an Interaction prompt to the Custom style; any other instance is left alone.
local function adopt(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance.Name == InteractionConstants.PROMPT_NAME then
		ours[instance] = true
		instance.Style = Enum.ProximityPromptStyle.Custom
	end
end

local function forgetCurrent()
	current = nil
	local gone = currentGone
	if gone ~= nil then
		gone:Disconnect()
		currentGone = nil
	end
end

local function onShown(prompt: ProximityPrompt)
	if not ours[prompt] then
		return
	end
	forgetCurrent()
	current = prompt
	local id = idOf(prompt)
	-- A prompt destroyed while shown may never fire Hidden; drop it from the chip either way.
	currentGone = prompt.Destroying:Connect(function()
		if current == prompt then
			forgetCurrent()
		end
		ShiftPromptStore.hide(id)
	end)
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
	if not ours[prompt] then
		return
	end
	if current == prompt then
		forgetCurrent()
	end
	ShiftPromptStore.hide(idOf(prompt))
end

local ShiftPromptSystem = {}

function ShiftPromptSystem.start(): () -> ()
	local connections: { RBXScriptConnection } = {}
	local stopObserver = Observers.observeTag(InteractionConstants.TAG, function(target: Instance)
		-- The server parents the prompt under the object's root part; it may replicate after the tag does.
		for _, descendant in target:GetDescendants() do
			adopt(descendant)
		end
		local added = target.DescendantAdded:Connect(adopt)
		return function()
			added:Disconnect()
		end
	end)
	table.insert(connections, ProximityPromptService.PromptShown:Connect(onShown))
	table.insert(connections, ProximityPromptService.PromptHidden:Connect(onHidden))
	table.insert(
		connections,
		ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt, player: Player)
			if ours[prompt] and player == Players.LocalPlayer then
				-- The server clock, as useServerClock reads it, so the chip's fill compares like with like.
				ShiftPromptStore.holdBegan(idOf(prompt), Workspace:GetServerTimeNow())
			end
		end)
	)
	table.insert(
		connections,
		ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt, player: Player)
			if ours[prompt] and player == Players.LocalPlayer then
				ShiftPromptStore.holdEnded(idOf(prompt))
			end
		end)
	)
	return function()
		stopObserver()
		for _, connection in connections do
			connection:Disconnect()
		end
		ShiftPromptSystem.press(false)
		forgetCurrent()
		ShiftPromptStore.clear()
	end
end

--[=[
	Holds (`down`) or releases the shown prompt: the touch path for the chip and the phone LOAD button. A release goes
	to the prompt this held, even if it has been hidden since; a release without a hold does nothing.
]=]
function ShiftPromptSystem.press(down: boolean)
	if down then
		local prompt = current
		if prompt == nil or prompt.Parent == nil or held ~= nil then
			return
		end
		held = prompt
		prompt:InputHoldBegin()
	else
		local prompt = held
		held = nil
		if prompt ~= nil and prompt.Parent ~= nil then
			prompt:InputHoldEnd()
		end
	end
end

return ShiftPromptSystem
