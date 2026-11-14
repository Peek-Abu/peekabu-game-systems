--!strict
--[=[
	DepotHubScreen: the hub's GUIDE, VACUUMS (the company equipment page, the Inventory's Vacuums tab) and SETTINGS in the V1 kit: a cream modal
	popping in with its header in the page's colour (DepotHubViewModel.pageHue) (the page's render breaking the corner, Gloom drips from the header's foot, the
	coral close). The Guide is DepotGuidePanel (HOW TO PLAY photo steps and MONSTERS cards, p075 scene menus) on a
	wider sheet (DepotGuideViewModel.layout); Settings, over a scrolling body, are the persisted, validated base settings (a ToonSlider per percentage setting, its value on a
	pill; an ON/OFF button per switch such as Tips; RESTORE DEFAULTS). Sizes follow the specced DepotHubViewModel.panelLayout in HUD design px, laid out against the virtual
	viewport and drawn at the game's one UI scale (PaperHudScaleViewModel, inside PaperHudFrame), so the sheet keeps
	the same share of the screen as the hub on a small laptop and on a 4K monitor.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.React)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingHubSystem = require(ReplicatedStorage.Client.Features.Training.Systems.TrainingHubSystem)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local SettingRegistry = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local ShiftHudViewModel = require(script.Parent.Parent.Shift.ShiftHudViewModel)
local SettingServiceClient = require(ReplicatedStorage.Client.Features.Setting.SettingServiceClient)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonPanel = require(Toon.ToonPanel)
local ToonSlider = require(Toon.ToonSlider)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH
-- Room inside the scroll frame for a card's ink outline (it is drawn outside the card) on its open sides.
local EDGE = DEPTH.outline + 3
local usePaperViewport = require(script.Parent.Parent.Paper.usePaperViewport)
local PaperHudFrame = require(script.Parent.Parent.Paper.PaperHudFrame)
local PaperHudScaleViewModel = require(script.Parent.Parent.Paper.PaperHudScaleViewModel)
local usePaperLayout = require(script.Parent.Parent.Paper.usePaperLayout)
local VM = require(script.Parent.DepotHubViewModel)
local DepotGuidePanel = require(script.Parent.DepotGuidePanel)
local GuideVM = require(script.Parent.DepotGuideViewModel)
local e = React.createElement
-- A settings row's value: a percentage (a slider) or a switch (a toggle button).
type RowValue = number | boolean
type RowValues = { [string]: RowValue }
local function label(
	text: string,
	size: number,
	x: number,
	y: number,
	width: number,
	heading: boolean?
): React.ReactNode
	return e(ToonText, {
		text = text,
		font = if heading then "display" else "body",
		textSize = size,
		position = UDim2.fromOffset(x, y),
		size = UDim2.fromOffset(width, if heading then size + 8 else size * 3),
		fit = heading,
		wrapped = not heading,
		alignY = "top",
	})
end
local function SettingsRows(props: { width: number, phone: boolean, preview: boolean? }): React.ReactNode
	local initial: RowValues = {}
	for _, setting in VM.SETTINGS do
		local value = SettingServiceClient:get(setting.id)
		if type(value) == "number" or type(value) == "boolean" then
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
					if type(value) == "number" or type(value) == "boolean" then
						setValues(function(previous: RowValues): RowValues
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
		local compact = props.width < 440
		local rowHeight = if compact then VM.SETTINGS_ROW_COMPACT else VM.SETTINGS_ROW
		local y = (index - 1) * rowHeight
		local value = values[setting.id]
		local def = SettingRegistry.get(setting.id)
		nodes[`label{index}`] = label(
			setting.label,
			if props.phone then 16 else 22,
			0,
			y + (if compact then 0 else 20),
			if compact then props.width else VM.SLIDER_LABEL_WIDTH,
			true
		)
		if def ~= nil and def.kind == "number" then
			-- A slider per percentage setting (ToonSlider): drag, click to jump, or step with the keys / d-pad.
			nodes[`slider{index}`] = e(ToonSlider, {
				value = if type(value) == "number" then value else def.default,
				min = def.min,
				max = def.max,
				step = def.step,
				disabled = value == nil,
				position = UDim2.fromOffset(
					if compact then 0 else VM.SLIDER_LABEL_WIDTH + 16,
					y + (if compact then 32 else 10)
				),
				size = UDim2.fromOffset(if compact then props.width else props.width - VM.SLIDER_LABEL_WIDTH - 16, 48),
				onChange = function(next: number)
					if props.preview then
						setValues(function(previous: RowValues): RowValues
							local nextValues = table.clone(previous)
							nextValues[setting.id] = next
							return nextValues
						end)
					else
						SettingServiceClient:set(setting.id, next)
					end
				end,
			})
		elseif def ~= nil and def.kind == "boolean" then
			-- A switch: one button that reads ON (mint) or OFF (lilac) and flips it.
			local on = if type(value) == "boolean" then value else def.default
			nodes[`switch{index}`] = e(ToonButton, {
				text = VM.switchText(on),
				variant = if on then "gleam" else "lilac",
				disabled = value == nil,
				size = UDim2.fromOffset(140, 48),
				position = UDim2.fromOffset(
					if compact then 0 else VM.SLIDER_LABEL_WIDTH + 16,
					y + (if compact then 32 else 10)
				),
				textSize = 20,
				onActivated = function()
					if props.preview then
						setValues(function(previous: RowValues): RowValues
							local nextValues = table.clone(previous)
							nextValues[setting.id] = not on
							return nextValues
						end)
					else
						SettingServiceClient:set(setting.id, not on)
					end
				end,
			})
		end
		nodes[`line{index}`] = e("Frame", {
			Position = UDim2.fromOffset(0, y + rowHeight - 5),
			Size = UDim2.fromOffset(props.width, 2),
			BackgroundColor3 = UIToonConstants.shade("cream").lo,
			BorderSizePixel = 0,
		})
	end
	local footerY = VM.settingsFooterY(props.width < 440)
	nodes.reset = e(ToonButton, {
		text = "RESTORE DEFAULTS",
		variant = "lilac",
		size = UDim2.fromOffset(250, 52),
		position = UDim2.fromOffset(0, footerY),
		textSize = 18,
		onActivated = function()
			if props.preview then
				local defaults: RowValues = {}
				for _, setting in VM.SETTINGS do
					local def = SettingRegistry.get(setting.id)
					if def ~= nil and (type(def.default) == "number" or type(def.default) == "boolean") then
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
	-- One line under the button, fitted; the box has room for a second line so a very narrow sheet (where the fit
	-- reaches the text floor) wraps instead of clipping.
	local noteSize = if props.phone then 14 else 18
	nodes.note = e(ToonText, {
		text = "Motion follows Roblox's Reduce Motion setting.",
		font = "body",
		textSize = noteSize,
		position = UDim2.fromOffset(0, footerY + 62),
		size = UDim2.fromOffset(props.width, 2 * noteSize + 8),
		fit = true,
		wrapped = true,
		alignY = "top",
	})
	return e(
		"Frame",
		{ Size = UDim2.fromOffset(props.width, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 },
		nodes
	)
end
local function DepotHubScreen(
	props: { page: VM.Page, preview: boolean?, viewport: Vector2?, phone: boolean? }
): React.ReactNode
	local liveViewport = usePaperViewport()
	local livePhone = usePaperLayout() == "phone"
	local viewport = props.viewport or liveViewport
	local phone = if props.phone ~= nil then props.phone else livePhone
	-- The one UI scale, and the screen in design px (less the scaled frame's top shift) the sheet is laid out in.
	local scale = PaperHudScaleViewModel.scale(viewport, if phone then "phone" else "desktop")
	local virtual =
		PaperHudScaleViewModel.virtual(viewport - Vector2.new(0, PaperHudScaleViewModel.topShift(scale)), scale)
	local layout = VM.panelLayout(virtual, phone)
	local width, height = layout.width, layout.height
	local tab, setTab = React.useState(GuideVM.DEFAULT_TAB)
	if props.page == "guide" then
		-- The Guide's photo cards need a wider sheet than the settings rows.
		local guide = GuideVM.layout(virtual, phone)
		width, height = guide.width, guide.height
	end
	local bindings = InputServiceClient:bindingsFor(VacuumConstants.ACTION)
	local input = UserInputService:GetLastInputType()
	local control = "Hold the vacuum button near dust."
	if input == Enum.UserInputType.Touch then
		control = "Hold VACUUM on the shift's touch controls near dust."
	elseif bindings ~= nil then
		local keys = if string.sub(input.Name, 1, 7) == "Gamepad" then bindings.gamepad else bindings.keyboard
		local key = if keys ~= nil then keys[1] else nil
		if key ~= nil then
			-- The HUD's key cap says "LMB"; a sentence in the guide spells it out for younger players.
			local name = if key == Enum.UserInputType.MouseButton1
				then "the left mouse button"
				else ShiftHudViewModel.keyName(key)
			control = `Hold {name} near dust to clean.`
		end
	end
	local body: { [string]: React.ReactNode } = {}
	if props.page == "settings" then
		-- Inset like the cards: the sliders' and RESTORE DEFAULTS' outlines and drops stay inside the scroll frame.
		body.pad = e("UIPadding", {
			PaddingLeft = UDim.new(0, EDGE),
			PaddingRight = UDim.new(0, EDGE),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 20),
		})
		body.settings = e(SettingsRows, { width = layout.bodyWidth - 2 * EDGE, phone = phone, preview = props.preview })
	end
	local headerHeight = if layout.compact then 84 else 104
	local subtitle: string? = if props.page == "settings"
		then (if props.preview then "Local preview · does not save" else "Saved to your account")
		else nil
	local icon: "guide" | "settings" = if props.page == "guide" then "guide" else "settings"
	local children: { [string]: React.ReactNode } = {}
	if props.page == "guide" then
		-- The Guide's tabs and photo cards (DepotGuidePanel) fill the sheet under its header; the way back into
		-- training (only where the hub has a Training pad) sits under the HOW TO PLAY cards.
		local inset = if phone then 16 else 32
		children.guide = e("Frame", {
			Position = UDim2.fromOffset(inset, headerHeight + (if phone then 14 else 28)),
			Size = UDim2.new(1, -2 * inset, 1, -headerHeight - (if phone then 26 else 56)),
			BackgroundTransparency = 1,
		}, {
			panel = e(DepotGuidePanel, {
				tab = tab,
				phone = phone,
				width = width - 2 * inset,
				height = height - headerHeight - (if phone then 26 else 56),
				onTab = setTab,
				control = control,
				training = if TrainingHubSystem.offered()
					then {
						text = TrainingConstants.TEXT.againButton,
						onActivated = function()
							SceneStack.remove(VM.scene(props.page))
							TrainingHubSystem.again()
						end,
					}
					else nil,
			}),
		})
	else
		children.scroll = e("ScrollingFrame", {
			Position = UDim2.fromOffset(layout.padding * 0.5, headerHeight + 44),
			Size = UDim2.new(1, -layout.padding, 1, -headerHeight - 64),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = UIToonConstants.shade("grape").base,
		}, {
			content = e("Frame", {
				Size = UDim2.new(1, -12, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			}, body),
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLOR.ink,
		BackgroundTransparency = 0.35,
		Active = true,
		BorderSizePixel = 0,
	}, {
		scaled = e(PaperHudFrame, {
			scale = scale,
			children = {
				sheet = e(ToonPanel, {
					anchor = Vector2.new(0.5, 0.5),
					position = UDim2.fromScale(0.5, 0.5),
					size = Vector2.new(width, height),
					header = {
						title = VM.pageTitle(props.page),
						hue = VM.pageHue(props.page),
						subtitle = subtitle,
						icon = icon,
						height = headerHeight,
						titleSize = if layout.compact then 40 else 54,
						goo = true,
					},
					onClose = function()
						SceneStack.remove(VM.scene(props.page))
					end,
					pop = true,
					wipe = true,
					children = children,
				}),
			},
		}),
	})
end
return DepotHubScreen
