--!strict
--[=[
	HideSpotSystem: turns the office's furniture into hiding spots (docs/superpowers/specs/
	2026-10-15-cleanup-crew-chase-kit-design.md §4). Every BasePart tagged HideConstants.FURNITURE_TAG (Office tags its
	desks, tables, lockers and filing cabinets, naming the kind) gets one spot: an Attachment on its front face, tagged
	SPOT_TAG, carrying the spot's id, kind, noun and peek camera, and holding a hold-to-enter ProximityPrompt on its own
	key (C / L1, so it never takes E from the furniture's Search). A trigger goes to `onTrigger`; the server re-checks
	everything there (HideServiceServer, HideRules). When the furniture goes (the office is rebuilt each shift) the
	spot goes with it and `onRemoved` hears of it first.

	Instance shell; where things go is the specced HideSpotUtils.

	@class HideSpotSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Observers = require(ReplicatedStorage.Packages.Observers)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local HideTypes = require(ReplicatedStorage.Shared.Features.Hide.Data.HideTypes)
local HideSpotUtils = require(ReplicatedStorage.Shared.Features.Hide.Utils.HideSpotUtils)

export type Hooks = {
	onTrigger: (player: Player, spot: HideTypes.Spot) -> (),
	onRemoved: (spot: HideTypes.Spot) -> (),
}

export type HideSpotSystem = {
	start: (self: HideSpotSystem) -> () -> (),
	get: (self: HideSpotSystem, spotId: string) -> HideTypes.Spot?,
	list: (self: HideSpotSystem) -> { HideTypes.Spot },
	setOpen: (self: HideSpotSystem, spotId: string, open: boolean) -> (),
}

-- A typical character's root height over its feet, for the peek (the hiding frame uses the real one).
local PEEK_STAND = 3

local HideSpotSystem = {}

function HideSpotSystem.new(hooks: Hooks): HideSpotSystem
	local spots: { [string]: HideTypes.Spot } = {}
	local prompts: { [string]: ProximityPrompt } = {}
	local nextId = 0

	local function build(furniture: Instance): (() -> ())?
		local kindName = furniture:GetAttribute(HideConstants.FURNITURE_KIND_ATTRIBUTE)
		local def = if type(kindName) == "string" then HideConstants.FURNITURE[kindName] else nil
		local spotKind: HideTypes.SpotKind? = if type(kindName) == "string" then HideSpotUtils.spotOf(kindName) else nil
		if def == nil or spotKind == nil or not furniture:IsA("BasePart") then
			return nil
		end
		nextId += 1
		local marker = furniture:GetAttribute("OfficeMarkerId") or furniture:GetAttribute("OfficeDeskMarker")
		local id = `{def.noun}.{if type(marker) == "string" then marker else tostring(nextId)}`
		if spots[id] ~= nil then
			id = `{id}.{nextId}`
		end
		local frames = HideSpotUtils.frames(spotKind, furniture.CFrame, furniture.Size, PEEK_STAND)
		local anchor = Instance.new("Attachment")
		anchor.Name = HideConstants.SPOT_NAME
		anchor.Position = frames.prompt
		anchor:SetAttribute(HideConstants.SPOT_ID_ATTRIBUTE, id)
		anchor:SetAttribute(HideConstants.SPOT_KIND_ATTRIBUTE, spotKind)
		anchor:SetAttribute(HideConstants.SPOT_NOUN_ATTRIBUTE, def.noun)
		anchor:SetAttribute(HideConstants.PEEK_ATTRIBUTE, frames.peek)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = HideConstants.PROMPT_NAME
		prompt.ActionText = def.action
		prompt.ObjectText = def.noun
		prompt.HoldDuration = HideConstants.ENTER_HOLD
		prompt.MaxActivationDistance = HideConstants.ENTER_RANGE
		prompt.KeyboardKeyCode = HideConstants.KEYBOARD_KEY
		prompt.GamepadKeyCode = HideConstants.GAMEPAD_KEY
		prompt.RequiresLineOfSight = false
		-- Only the nearest spot per key shows; the client draws it on paper (HideServiceClient).
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Parent = anchor
		anchor.Parent = furniture
		CollectionService:AddTag(anchor, HideConstants.SPOT_TAG)
		local spot: HideTypes.Spot =
			{ id = id, kind = spotKind, noun = def.noun, furniture = furniture, anchor = anchor }
		spots[id] = spot
		prompts[id] = prompt
		local triggered = prompt.Triggered:Connect(function(player: Player)
			hooks.onTrigger(player, spot)
		end)
		return function()
			triggered:Disconnect()
			hooks.onRemoved(spot)
			spots[id] = nil
			prompts[id] = nil
			if anchor.Parent ~= nil then
				anchor:Destroy()
			end
		end
	end

	local system: HideSpotSystem = {
		start = function(_self)
			return Observers.observeTag(HideConstants.FURNITURE_TAG, build)
		end,

		get = function(_self, spotId)
			return spots[spotId]
		end,

		list = function(_self)
			local list: { HideTypes.Spot } = {}
			for _, spot in spots do
				table.insert(list, spot)
			end
			table.sort(list, function(a, b)
				return a.id < b.id
			end)
			return list
		end,

		--[=[
			Shows or hides a spot's prompt for everyone (taken while someone is in it).
		]=]
		setOpen = function(_self, spotId, open)
			local prompt: ProximityPrompt? = prompts[spotId]
			if prompt ~= nil then
				prompt.Enabled = open
			end
		end,
	}
	return system
end

return HideSpotSystem
