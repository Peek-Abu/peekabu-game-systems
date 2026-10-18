--!strict
--[=[
	CharacterPortrait.story: every portrait context (profile, crew, caught, award) in each framing (head, bust, upper, full),
	on a light and a dark plate, from the employee's template in the place (edit mode has no players). Controls: the
	Clearance Level and the results' grade (they change the profile and award poses), a dimmed (caught) portrait, and
	the fallback photo (no character). In Studio's edit mode (UI Labs).

	@class CharacterPortrait.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeePoseRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeePoseRegistry)
local CharacterPortrait = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.CharacterPortrait)
local PortraitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

local FRAMINGS: { PortraitViewModel.Framing } = { "head", "bust", "upper", "full" }
local TONES: { PortraitViewModel.Tone } = { "light", "dark" }
local CELL = 150

-- The default employee's template, stamped with its name (the server stamps live characters).
local function template(): Model?
	local def = EmployeeRegistry.get(EmployeeRegistry.DEFAULT)
	if def == nil then
		return nil
	end
	local node: Instance? = ReplicatedStorage
	for _, name in def.templatePath do
		node = if node ~= nil then node:FindFirstChild(name) else nil
	end
	if node == nil or not node:IsA("Model") then
		return nil
	end
	local copy = node:Clone()
	copy:SetAttribute(EmployeeConstants.NAME_ATTRIBUTE, def.name)
	return copy
end

local function Grid(props: { level: number, grade: string, dim: boolean, fallback: boolean }): React.ReactNode
	local model = React.useMemo(template, {})
	React.useEffect(function(): () -> ()
		return function()
			if model ~= nil then
				model:Destroy()
			end
		end
	end, { model })
	local nodes: { [string]: React.ReactNode } = {}
	for row, context: EmployeePoseRegistry.PortraitContext in EmployeePoseRegistry.CONTEXTS do
		for column, framing: PortraitViewModel.Framing in FRAMINGS do
			for plate, tone: PortraitViewModel.Tone in TONES do
				local x = 24 + ((plate - 1) * #FRAMINGS + column - 1) * (CELL + 16)
				local y = 24 + (row - 1) * (CELL + 34)
				local hue = UIToonConstants.shade(if tone == "light" then "cream" else "night").base
				nodes[`{context}_{framing}_{tone}`] = e("Frame", {
					Position = UDim2.fromOffset(x, y),
					Size = UDim2.fromOffset(CELL, CELL),
					BackgroundColor3 = hue,
				}, {
					corner = e("UICorner", { CornerRadius = UDim.new(0, 18) }),
					stroke = e("UIStroke", { Color = UIToonConstants.COLOR.ink, Thickness = 4 }),
					portrait = e(CharacterPortrait, {
						model = if props.fallback then nil else model,
						userId = 1,
						context = context,
						framing = framing,
						tone = tone,
						level = props.level,
						grade = props.grade,
						dim = props.dim,
						round = framing == "head" or framing == "bust",
						size = UDim2.new(1, -8, 1, -8),
						position = UDim2.fromScale(0.5, 0.5),
						anchor = Vector2.new(0.5, 0.5),
					}),
					label = e("TextLabel", {
						Position = UDim2.new(0, 0, 1, 4),
						Size = UDim2.new(1, 0, 0, 22),
						BackgroundTransparency = 1,
						Font = Enum.Font.FredokaOne,
						TextSize = 16,
						TextColor3 = Color3.new(1, 1, 1),
						Text = `{context} / {framing}`,
					}),
				})
			end
		end
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("2B1856"),
	}, nodes)
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Level = 2, Grade = "A", Dim = false, Fallback = false },
}, function(props)
	local controls = props.controls
	return e(Grid, {
		level = controls.Level,
		grade = controls.Grade,
		dim = controls.Dim,
		fallback = controls.Fallback,
	})
end)
