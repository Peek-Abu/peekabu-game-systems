--!strict
-- Guide/gear are honest company briefing pages. Settings use the persisted, validated base service.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.React)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local SettingRegistry = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local ShiftHudViewModel = require(script.Parent.Parent.Shift.ShiftHudViewModel)
local SettingServiceClient = require(ReplicatedStorage.Client.Features.Setting.SettingServiceClient)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local PaperSheet = require(script.Parent.Parent.Paper.PaperSheet)
local PaperLabel = require(script.Parent.Parent.Paper.PaperLabel)
local PaperButton = require(script.Parent.Parent.Paper.PaperButton)
local PaperPropIcon = require(script.Parent.Parent.Paper.PaperPropIcon)
local COLOR = require(script.Parent.Parent.Paper.UIPaperConstants).COLOR
local usePaperViewport = require(script.Parent.Parent.Paper.usePaperViewport)
local usePaperLayout = require(script.Parent.Parent.Paper.usePaperLayout)
local VM = require(script.Parent.DepotHubViewModel)
local e = React.createElement
local function label(
	text: string,
	size: number,
	x: number,
	y: number,
	width: number,
	heading: boolean?
): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = if heading then "heading" else "body",
		size = size,
		position = UDim2.fromOffset(x, y),
		frame = UDim2.fromOffset(width, 0),
	})
end
local function SettingsRows(props: { width: number, phone: boolean, preview: boolean? }): React.ReactNode
	local initial: { [string]: number } = {}
	for _, setting in VM.SETTINGS do
		local value = SettingServiceClient:get(setting.id)
		if type(value) == "number" then
			initial[setting.id] = value
		end
	end
	local values, setValues = React.useState(initial)
	React.useEffect(function(): () -> ()
		local stoppers: { () -> () } = {}
		if props.preview then
			return function() end
		end
		for _, setting in VM.SETTINGS do
			table.insert(
				stoppers,
				SettingServiceClient:observe(setting.id, function(value)
					if type(value) == "number" then
						setValues(function(previous: { [string]: number }): { [string]: number }
							local nextValues = table.clone(previous)
							nextValues[setting.id] = value
							return nextValues
						end)
					end
				end)
			)
		end
		return function()
			for _, stop in stoppers do
				stop()
			end
		end
	end, {})
	local nodes: { [string]: React.ReactNode } = {}
	for index, setting in VM.SETTINGS do
		local y = (index - 1) * 68
		local value = values[setting.id]
		nodes[`label{index}`] = label(setting.label, if props.phone then 16 else 22, 0, y + 16, props.width - 190, true)
		nodes[`value{index}`] =
			label(if value ~= nil then `{math.round(value * 100)}%` else "…", 20, props.width - 128, y + 15, 70, true)
		for _, direction in { -1, 1 } do
			nodes[`{index}/{direction}`] = e(PaperButton, {
				text = if direction < 0 then "−" else "+",
				variant = "secondary",
				onPaper = true,
				position = UDim2.fromOffset(if direction < 0 then props.width - 185 else props.width - 54, y + 7),
				size = UDim2.fromOffset(48, 48),
				textSize = 28,
				disabled = value == nil or (if direction < 0 then value == 0 else value == 1),
				onActivated = function()
					local current = if props.preview then values[setting.id] else SettingServiceClient:get(setting.id)
					if type(current) == "number" then
						if props.preview then
							local nextValues = table.clone(values)
							nextValues[setting.id] = VM.adjust(current, direction)
							setValues(nextValues)
						else
							SettingServiceClient:set(setting.id, VM.adjust(current, direction))
						end
					end
				end,
			})
		end
		nodes[`line{index}`] = e("Frame", {
			Position = UDim2.fromOffset(0, y + 63),
			Size = UDim2.fromOffset(props.width, 1),
			BackgroundColor3 = COLOR.manilaDeep,
			BorderSizePixel = 0,
		})
	end
	nodes.reset = e(PaperButton, {
		text = "RESTORE DEFAULTS",
		variant = "secondary",
		onPaper = true,
		size = UDim2.fromOffset(210, 48),
		position = UDim2.fromOffset(0, 352),
		textSize = 18,
		onActivated = function()
			if props.preview then
				local defaults: { [string]: number } = {}
				for _, setting in VM.SETTINGS do
					local def = SettingRegistry.get(setting.id)
					if def ~= nil and type(def.default) == "number" then
						defaults[setting.id] = def.default
					end
				end
				setValues(defaults)
			else
				for _, setting in VM.SETTINGS do
					SettingServiceClient:reset(setting.id)
				end
			end
		end,
	})
	nodes.note = label(
		"Motion follows Roblox's Reduce Motion setting. Key bindings remain managed by your saved input settings.",
		if props.phone then 14 else 18,
		0,
		414,
		props.width
	)
	return e("Frame", { Size = UDim2.fromOffset(props.width, 480), BackgroundTransparency = 1 }, nodes)
end
local function DepotHubScreen(
	props: { page: VM.Page, preview: boolean?, viewport: Vector2?, phone: boolean? }
): React.ReactNode
	local liveViewport = usePaperViewport()
	local livePhone = usePaperLayout() == "phone"
	local viewport = props.viewport or liveViewport
	local phone = if props.phone ~= nil then props.phone else livePhone
	local width = math.max(260, math.min(if phone then 690 else 860, viewport.X - 96))
	local height = math.max(230, math.min(660, viewport.Y - 92))
	local bindings = InputServiceClient:bindingsFor(VacuumConstants.ACTION)
	local input = UserInputService:GetLastInputType()
	local control = "Hold the cleaning action near dust."
	if input == Enum.UserInputType.Touch then
		control = "Hold VACUUM on the shift's touch controls near dust."
	elseif bindings ~= nil then
		local keys = if string.sub(input.Name, 1, 7) == "Gamepad" then bindings.gamepad else bindings.keyboard
		if keys ~= nil and keys[1] ~= nil then
			control = `Hold {ShiftHudViewModel.keyName(keys[1])} near dust to clean.`
		end
	end
	local copy = VM.copy(props.page, control)
	local title = if props.page == "settings" then "PERSONAL SETTINGS" else copy.title
	local body: { [string]: React.ReactNode } = {}
	if props.page == "settings" then
		body.settings = e(SettingsRows, { width = width - 64, phone = phone, preview = props.preview })
	else
		local y = 0
		for index, section in copy.sections do
			body[`title{index}`] = label(section.title, if phone then 18 else 24, 0, y, width - 76, true)
			body[`body{index}`] = label(section.body, if phone then 16 else 21, 0, y + 32, width - 76)
			y += if phone then 106 else 118
		end
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLOR.night,
		BackgroundTransparency = 0.2,
		Active = true,
		BorderSizePixel = 0,
	}, {
		sheet = e(PaperSheet, {
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			size = UDim2.fromOffset(width, height),
			padding = 0,
		}, {
			strip = e(
				"Frame",
				{ Size = UDim2.new(1, 0, 0, 7), BackgroundColor3 = COLOR.companyTeal, BorderSizePixel = 0 }
			),
			icon = e(
				"Frame",
				{ Position = UDim2.fromOffset(24, 22), Size = UDim2.fromOffset(58, 58), BackgroundTransparency = 1 },
				{ art = e(PaperPropIcon, { kind = props.page }) }
			),
			title = label(title, if phone then 24 else 34, 96, 20, width - 280, true),
			subtitle = label(
				if props.page == "settings"
					then (if props.preview then "LOCAL PREVIEW / DOES NOT SAVE" else "SAVED TO YOUR ACCOUNT")
					else copy.subtitle,
				if phone then 14 else 17,
				96,
				62,
				width - 280
			),
			close = e(PaperButton, {
				text = "CLOSE",
				variant = "secondary",
				onPaper = true,
				size = UDim2.fromOffset(106, 48),
				position = UDim2.fromOffset(width - 130, 28),
				textSize = 20,
				onActivated = function()
					SceneStack.remove(VM.scene(props.page))
				end,
			}),
			scroll = e("ScrollingFrame", {
				Position = UDim2.fromOffset(32, 110),
				Size = UDim2.new(1, -64, 1, -130),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 5,
				ScrollBarImageColor3 = COLOR.companyTeal,
			}, {
				content = e("Frame", {
					Size = UDim2.new(1, -12, 0, if props.page == "settings" then 490 elseif phone then 444 else 490),
					BackgroundTransparency = 1,
				}, body),
			}),
		}),
	})
end
return DepotHubScreen
