--!strict
--[=[
	ShiftMobileButtons: touch controls while a shift runs (spec §4 "mobile: hold the Vacuum button"):
	a hold-to-vacuum button, then Pocket, Drop and Throw. Shown only on touch devices. The base Input feature
	has no touch bindings yet, so these call the Vacuum and Cargo client services directly (an open question
	for the base). Placeholder look (M3 replaces it).

	@class ShiftMobileButtons
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CargoServiceClient = require(ReplicatedStorage.Client.Features.Cargo.CargoServiceClient)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local VacuumServiceClient = require(ReplicatedStorage.Client.Features.Vacuum.VacuumServiceClient)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Button = require(ReplicatedStorage.Client.UI.React.Primitives.Button)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local BUTTON_WIDTH = 130
local VACUUM_HEIGHT = 60

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function ShiftMobileButtons(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	-- Unmounting destroys a held button before its InputEnded fires, so end the hold here.
	React.useEffect(function()
		return function()
			VacuumServiceClient:endVacuum()
		end
	end, {})
	if not UserInputService.TouchEnabled or snapshot == nil or snapshot.phase ~= "running" then
		return nil
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		-- Above the engine's jump button in the bottom-right corner.
		Position = UDim2.new(1, -Tokens.space.lg, 1, -Tokens.space.xxl * 5),
		Size = UDim2.fromOffset(BUTTON_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Tokens.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		vacuum = e("TextButton", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(BUTTON_WIDTH, VACUUM_HEIGHT),
			BackgroundColor3 = Tokens.color.accent,
			BorderSizePixel = 0,
			Font = Tokens.font.bold,
			TextSize = Tokens.textSize.lg,
			TextColor3 = Tokens.color.onAccent,
			Text = "Hold: Vacuum",
			[React.Event.InputBegan] = function(_button: TextButton, input: InputObject)
				if isPress(input) then
					VacuumServiceClient:beginVacuum()
				end
			end,
			[React.Event.InputEnded] = function(_button: TextButton, input: InputObject)
				if isPress(input) then
					VacuumServiceClient:endVacuum()
				end
			end,
			[React.Event.MouseLeave] = function()
				VacuumServiceClient:endVacuum()
			end,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, Tokens.radius.md) }),
		}),
		pocket = e(Button, {
			text = "Pocket",
			width = BUTTON_WIDTH,
			layoutOrder = 2,
			onActivated = function()
				CargoServiceClient:pocket()
			end,
		}),
		drop = e(Button, {
			text = "Drop",
			width = BUTTON_WIDTH,
			layoutOrder = 3,
			onActivated = function()
				CargoServiceClient:drop()
			end,
		}),
		throw = e(Button, {
			text = "Throw",
			width = BUTTON_WIDTH,
			layoutOrder = 4,
			onActivated = function()
				CargoServiceClient:throw()
			end,
		}),
	})
end

return ShiftMobileButtons
