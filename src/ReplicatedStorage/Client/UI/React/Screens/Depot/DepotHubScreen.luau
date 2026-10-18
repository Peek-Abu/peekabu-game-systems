--!strict
--[=[
	DepotHubScreen: the hub's GUIDE, LOCKER (the company equipment page) and SETTINGS in the V1 kit: a cream modal
	popping in with its grape header (the page's render breaking the corner, Gloom drips from the header's foot, the
	coral close) over a scrolling body. Guide and Locker are honest briefing pages, a card per section with its
	render; Settings are the persisted, validated base settings (a ToonSlider per percentage setting, its value on a
	pill, RESTORE DEFAULTS). Sizes follow the specced DepotHubViewModel.panelLayout in HUD design px, laid out against the virtual
	viewport and drawn at the game's one UI scale (PaperHudScaleViewModel, inside PaperHudFrame), so the sheet keeps
	the same share of the screen as the hub on a small laptop and on a 4K monitor.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.React)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local SettingRegistry = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local ShiftHudViewModel = require(script.Parent.Parent.Shift.ShiftHudViewModel)
local SettingServiceClient = require(ReplicatedStorage.Client.Features.Setting.SettingServiceClient)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonSlider = require(Toon.ToonSlider)
local ToonSurface = require(Toon.ToonSurface)
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
local e = React.createElement
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
				value = value or def.default,
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
						setValues(function(previous: { [string]: number }): { [string]: number }
							local nextValues = table.clone(previous)
							nextValues[setting.id] = next
							return nextValues
						end)
					else
						SettingServiceClient:set(setting.id, next)
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
	local bindings = InputServiceClient:bindingsFor(VacuumConstants.ACTION)
	local input = UserInputService:GetLastInputType()
	local control = "Hold the cleaning action near dust."
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
	local copy = VM.copy(props.page, control)
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
	else
		local icons = VM.sectionIcons(props.page)
		if props.page == "gear" then
			-- The Locker: a card per piece of issued equipment, its render on a gold stage (the V1 locker cards).
			body.grid = e("UIGridLayout", {
				-- Each cell holds its card AND the card's hard drop (the card is drawn DEPTH.drop short of it).
				CellSize = UDim2.new(if phone then 1 else 0.5, -10, 0, if phone then 262 else 312),
				CellPadding = UDim2.fromOffset(16, 16),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			-- Room on every side for the cards' ink outline and their drop, so the scroll frame never cuts them.
			body.pad = e("UIPadding", {
				PaddingLeft = UDim.new(0, EDGE),
				PaddingRight = UDim.new(0, EDGE),
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 20),
			})
			for index, section in copy.sections do
				local stage: { [string]: React.ReactNode } = {
					art = e(ToonIcon, {
						icon = icons[index],
						anchor = Vector2.new(0.5, 0.5),
						position = UDim2.fromScale(0.5, 0.5),
						size = UDim2.fromOffset(if phone then 88 else 124, if phone then 88 else 124),
						drop = 5,
					}),
				}
				local face: { [string]: React.ReactNode } = {
					stage = e(ToonSurface, {
						hue = "gold",
						small = true,
						radius = 14,
						position = UDim2.fromOffset(10, 10),
						size = UDim2.new(1, -20, 0, if phone then 96 else 130),
						children = stage,
					}),
					title = e(ToonText, {
						text = section.title,
						textSize = if phone then 20 else 24,
						position = UDim2.fromOffset(16, if phone then 114 else 150),
						size = UDim2.new(1, -32, 0, 30),
						fit = true,
					}),
					text = e(ToonText, {
						text = section.body,
						font = "body",
						textSize = if phone then 15 else 18,
						position = UDim2.fromOffset(16, if phone then 146 else 184),
						size = UDim2.new(1, -32, 0, if phone then 92 else 104),
						wrapped = true,
						fit = true,
						alignY = "top",
					}),
				}
				body[`section{index}`] = e("Frame", {
					LayoutOrder = index,
					BackgroundTransparency = 1,
				}, {
					card = e(ToonSurface, {
						hue = "cream",
						radius = 20,
						pattern = "sparkle",
						size = UDim2.new(1, 0, 1, -DEPTH.drop),
						children = face,
					}),
				})
			end
		else
			body.list = e("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 16),
			})
			body.pad = e("UIPadding", {
				PaddingLeft = UDim.new(0, if phone then 34 else 52),
				PaddingRight = UDim.new(0, EDGE),
				PaddingTop = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 20),
			})
			local iconSize = if phone then 64 else 92
			for index, section in copy.sections do
				-- A card per section on the depth stack, its render breaking the card's left edge. The card is as tall as
				-- its measured copy (TextService) plus the surface's lip and drop: an automatic size would also count the
				-- surface's selected glow and ring, which reach past the card, and leave every card padded to the tallest.
				-- The scroll content is the body width plus the panel padding (see DepotHubViewModel.panelLayout).
				local textWidth = layout.bodyWidth
					+ layout.padding
					- (if phone then 34 else 52)
					- 2 * EDGE
					- iconSize * 0.66
					- 14
				local titleHeight = TextService:GetTextSize(
					section.title,
					if phone then 18 else 24,
					Enum.Font.LuckiestGuy,
					Vector2.new(textWidth, math.huge)
				).Y
				local bodyHeight = TextService:GetTextSize(
					section.body,
					if phone then 15 else 20,
					Enum.Font.FredokaOne,
					Vector2.new(textWidth, math.huge)
				).Y
				local cardHeight =
					math.max(iconSize * 0.8, 12 + titleHeight + 4 + bodyHeight + 14 + DEPTH.lip + DEPTH.drop)
				body[`section{index}`] = e("Frame", {
					LayoutOrder = index,
					Size = UDim2.new(1, -EDGE, 0, math.ceil(cardHeight)),
					BackgroundTransparency = 1,
				}, {
					surface = e(ToonSurface, {
						hue = "cream",
						radius = 18,
						pattern = "sparkle",
						size = UDim2.new(1, 0, 1, -DEPTH.drop),
						zIndex = 1,
					}),
					icon = e(ToonIcon, {
						icon = icons[index],
						position = UDim2.fromOffset(-iconSize * 0.42, -8),
						size = UDim2.fromOffset(iconSize, iconSize),
						drop = 4,
						zIndex = 3,
					}),
					text = e("Frame", {
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						ZIndex = 2,
					}, {
						pad = e("UIPadding", {
							PaddingLeft = UDim.new(0, iconSize * 0.66),
							PaddingRight = UDim.new(0, 14),
							PaddingTop = UDim.new(0, 12),
							-- The surface's lip and the card's drop sit under the copy.
							PaddingBottom = UDim.new(0, 14 + DEPTH.lip + DEPTH.drop),
						}),
						list = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
						title = e("TextLabel", {
							LayoutOrder = 1,
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							Text = section.title,
							TextWrapped = true,
							FontFace = UIToonConstants.FONT.display,
							TextSize = if phone then 18 else 24,
							TextColor3 = UIToonConstants.shade("grape").lo,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 2,
						}),
						body = e("TextLabel", {
							LayoutOrder = 2,
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							Text = section.body,
							TextWrapped = true,
							FontFace = UIToonConstants.FONT.body,
							TextSize = if phone then 15 else 20,
							TextColor3 = COLOR.ink,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 2,
						}),
					}),
				})
			end
		end
	end
	local headerHeight = if layout.compact then 84 else 104
	local subtitle = if props.page == "settings"
		then (if props.preview then "Local preview · does not save" else "Saved to your account")
		else copy.subtitle
	local icon: "guide" | "locker" | "settings" = if props.page == "guide"
		then "guide"
		elseif props.page == "gear" then "locker"
		else "settings"
	local children: { [string]: React.ReactNode } = {
		scroll = e("ScrollingFrame", {
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
		}),
	}
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
