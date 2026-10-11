--!strict
--[=[
	DepotWorld.story: the depot's world signs (Figma World UI 2a) at their design size over the dark depot, in Studio's
	edit mode (UI Labs). Each sign is drawn through WorldBillboard in a frame of its design size times `Scale` (a sign
	seen from further away). Truck 1 is empty, truck 2 has `Aboard` crew and `SecondsLeft` on its clock (or `Departing`),
	truck 3 is full with 8 s left. Below them the contract board and the result board with (`Review`) or without your
	card; `QuotaMet` stamps it, `LongClient` tries a 60-character client.

	@class DepotWorld.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local DepotResultBoard = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotResultBoard)
local DepotWorkOrderBoard = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorkOrderBoard)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local DepotTruckTag = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotTruckTag)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

local e = React.createElement

local NOW = 1000
local PX = DepotConstants.BILLBOARD_PX

-- A sign through the real wrapper, in a frame of its design size times `scale` (fit = scale).
local function sign(order: number, design: Vector2, scale: number, child: React.ReactNode): React.ReactNode
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(design.X * scale, design.Y * scale),
		BackgroundTransparency = 1,
	}, {
		billboard = e(WorldBillboard, { design = design, sizing = "studs" }, { sign = child }),
	})
end

local function row(order: number, children: { [string]: React.ReactNode }): React.ReactNode
	local content: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 40),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for key, node in children do
		content[key] = node
	end
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, content)
end

local function truckSign(order: number, truck: number, pad: QueueTypes.PadSnapshot?, scale: number): React.ReactNode
	local view = DepotWorldViewModel.truckTag(truck, 4, pad, NOW)
	return sign(order, PX.truck, scale, e(DepotTruckTag, { view = view }))
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Aboard = 2,
		SecondsLeft = 12,
		Departing = false,
		Review = true,
		QuotaMet = true,
		LongClient = false,
		Scale = 1,
	},
}, function(props)
	local aboard: number = math.clamp(math.floor(props.controls.Aboard), 0, 4)
	local secondsLeft: number = props.controls.SecondsLeft
	local departing: boolean = props.controls.Departing
	local scale: number = math.max(props.controls.Scale, 0.1)
	local members: { number } = {}
	for userId = 1, aboard do
		table.insert(members, userId)
	end
	local second: QueueTypes.PadSnapshot? = if aboard > 0
		then {
			members = members,
			capacity = 4,
			destination = DepotConstants.ROLE_SHIFT,
			endsAt = if departing then nil else NOW + secondsLeft,
			departing = departing,
		}
		else nil
	local full: QueueTypes.PadSnapshot = {
		members = { 1, 2, 3, 4 },
		capacity = 4,
		destination = DepotConstants.ROLE_SHIFT,
		endsAt = NOW + 8,
		departing = false,
	}
	local contract = DepotConstants.CONTRACTS[1]
	local client = if props.controls.LongClient then string.rep("Pemberton ", 6) else "Pemberton Dental"
	local contractKeys = DepotConstants.CONTRACT_KEYS
	local workOrder = DepotWorldViewModel.workOrder({
		[contractKeys.id] = contract.id,
		[contractKeys.client] = client,
		[contractKeys.job] = contract.job,
	})
	local keys = DepotConstants.REVIEW_KEYS
	local met: boolean = props.controls.QuotaMet
	local review = if props.controls.Review
		then DepotWorldViewModel.review({
			[keys.client] = client,
			[keys.cleared] = if met then 362 else 214,
			[keys.quota] = ShiftConstants.QUOTA,
			[keys.bonus] = 215,
			[keys.catches] = 3,
			[keys.salvage] = 5,
			[keys.offered] = 9,
			[keys.met] = met,
			[keys.rating] = "exceeds",
			[keys.truck] = 2,
			[`{keys.crew}1`] = "Sam",
			[`{keys.crew}2`] = "Alex",
			[`{keys.crew}3`] = "Jo",
			[`{keys.awardTitle}1`] = "EMPLOYEE OF THE NIGHT",
			[`{keys.awardName}1`] = "Sam",
			[`{keys.awardTitle}2`] = "BUTTERFINGERS",
			[`{keys.awardName}2`] = "Jo",
		})
		else nil
	local boards: { [string]: React.ReactNode } = {
		result = sign(
			1,
			PX.result,
			scale,
			e(DepotResultBoard, { title = DepotConstants.RESULT_BOARD_TITLE, review = review })
		),
	}
	if workOrder ~= nil then
		boards.contract = sign(2, PX.contract, scale, e(DepotWorkOrderBoard, { view = workOrder }))
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.night,
		BorderSizePixel = 0,
	}, {
		padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 60),
			PaddingTop = UDim.new(0, 60),
		}),
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 60),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		trucks = row(1, {
			truck1 = truckSign(1, 1, nil, scale),
			truck2 = truckSign(2, 2, second, scale),
			truck3 = truckSign(3, 3, full, scale),
		}),
		boards = row(2, boards),
	})
end)
