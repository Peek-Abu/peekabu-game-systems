--!strict
--[=[
	AbilitySpotSystem: Spot It! on Cappy's client only. The server picks the treasure and names its CargoId
	(AbilityEvents.Spotted); this draws it in gold through walls (a Highlight, AlwaysOnTop) with a star over it for the
	effect's seconds. The look ends early, cleanly, when the item is picked up, banked or removed (it leaves the world
	or its parent changes); a new spot replaces the old one.

	Spec-exempt shell (Highlight, BillboardGui, CollectionService, live parts).

	@class AbilitySpotSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local AbilityVfxConstants = require(ReplicatedStorage.Client.Features.Ability.Data.AbilityVfxConstants)

local C = AbilityVfxConstants

local AbilitySpotSystem = {}

local current: { clear: () -> () }? = nil
local shown = 0

local function partFor(cargoId: number): BasePart?
	for _, tagged in CollectionService:GetTagged(CarryConstants.TAG) do
		if tagged:IsA("BasePart") and tagged:GetAttribute(CargoConstants.ID_ATTRIBUTE) == cargoId then
			return tagged
		end
	end
	return nil
end

--[=[
	Ends the spot on screen now (none: nothing).
]=]
function AbilitySpotSystem.clear()
	local spot = current
	current = nil
	if spot ~= nil then
		spot.clear()
	end
end

--[=[
	Shows the cargo item `cargoId` through walls for `seconds`. False when this client has no such item.
]=]
function AbilitySpotSystem.show(cargoId: number, seconds: number): boolean
	AbilitySpotSystem.clear()
	local part = partFor(cargoId)
	if part == nil then
		return false
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = C.SPOT_NAME
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.OutlineColor = C.SPOT_OUTLINE
	highlight.FillColor = C.SPOT_FILL
	highlight.FillTransparency = C.SPOT_FILL_TRANSPARENCY
	highlight.OutlineTransparency = 0
	highlight.Adornee = part
	highlight.Parent = Workspace

	local board = Instance.new("BillboardGui")
	board.Name = C.SPOT_NAME
	board.AlwaysOnTop = true
	board.Size = UDim2.fromScale(C.SPOT_STAR_SIZE, C.SPOT_STAR_SIZE)
	board.StudsOffsetWorldSpace = Vector3.new(0, C.SPOT_STAR_LIFT, 0)
	board.LightInfluence = 0
	board.Adornee = part
	local star = Instance.new("ImageLabel")
	star.BackgroundTransparency = 1
	star.Size = UDim2.fromScale(1, 1)
	star.Image = C.SPOT_STAR
	star.ImageColor3 = C.SPOT_STAR_COLOR
	star.Parent = board
	board.Parent = Workspace

	local connections: { RBXScriptConnection } = {}
	local cleared = false
	local function clear()
		if cleared then
			return
		end
		cleared = true
		for _, connection in connections do
			connection:Disconnect()
		end
		highlight:Destroy()
		board:Destroy()
	end
	local spot = { clear = clear }
	current = spot
	-- Picked up (re-parented to a hand), banked or removed: the treasure is no longer there to find.
	table.insert(
		connections,
		part.AncestryChanged:Connect(function()
			if current == spot then
				AbilitySpotSystem.clear()
			else
				clear()
			end
		end)
	)
	table.insert(
		connections,
		part:GetAttributeChangedSignal(CargoConstants.ID_ATTRIBUTE):Connect(function()
			if current == spot then
				AbilitySpotSystem.clear()
			end
		end)
	)
	task.delay(seconds, function()
		if current == spot then
			AbilitySpotSystem.clear()
		end
	end)
	shown += 1
	return true
end

function AbilitySpotSystem.shown(): number
	return shown
end

return AbilitySpotSystem
