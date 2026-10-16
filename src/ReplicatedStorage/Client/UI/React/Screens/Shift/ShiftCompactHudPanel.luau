--!strict
-- Approved gameplay-backed compact HUD (Figma 75:2732). Physical pixels preserve readability in short windows.
-- The equipment is the paper hotbar (ShiftHotbar; docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md
-- §4): bottom centre on desktop with a "HOLDING ..." slip above it while the hands hold something, top centre on
-- phone between the crew button and the time card.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local PaperButton = require(script.Parent.Parent.Paper.PaperButton)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local Constants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local VM = require(script.Parent.ShiftHudViewModel)
local ShiftHotbar = require(script.Parent.ShiftHotbar)
local ShiftHotbarViewModel = require(script.Parent.ShiftHotbarViewModel)
local CrewVM = require(script.Parent.ShiftCrewViewModel)
local useProgressTween = require(ReplicatedStorage.Client.UI.React.Hooks.useProgressTween)
local SprintStaminaSlip = require(ReplicatedStorage.Client.UI.React.Screens.Sprint.SprintStaminaSlip)
local SprintViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Sprint.SprintViewModel)

local e = React.createElement
local C = Constants.COLOR

export type Props = {
	view: VM.HudView,
	roster: CrewVM.RosterView?,
	layout: Constants.Layout,
	viewport: Vector2,
	crewOpen: boolean?,
	onCrewToggle: (() -> ())?,
	-- A hotbar card was tapped or clicked: ask for that slot.
	onSelect: ((slot: number) -> ())?,
	bindings: VM.KeyBindings?,
	-- The sprint's stamina while it is not full (Sprint): a small slip tucked against the equipment cards.
	stamina: SprintViewModel.BarView?,
}

local function label(
	text: string,
	x: number,
	y: number,
	width: number,
	size: number,
	role: PaperLabel.Role?,
	color: Color3?
): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = role or "body",
		size = size,
		color = color,
		position = UDim2.fromOffset(x, y),
		frame = UDim2.fromOffset(width, size + 6),
		autoSize = false,
		wrapped = false,
		scaled = true,
		minSize = math.min(size, 14),
	})
end

local function sheet(
	size: Vector2,
	position: UDim2,
	anchor: Vector2,
	paper: Color3,
	children: { [string]: React.ReactNode }
): React.ReactNode
	return e(PaperSheet, {
		size = UDim2.fromOffset(size.X, size.Y),
		position = position,
		anchor = anchor,
		paper = paper,
		padding = 12,
		children = children,
	})
end

type ButtonProps = {
	position: UDim2,
	anchor: Vector2,
	size: Vector2,
	content: React.ReactNode,
	onPress: (() -> ())?,
}
local function CompactButton(props: ButtonProps): React.ReactNode
	return e(PaperButton, {
		text = "",
		variant = "surface",
		content = props.content,
		size = UDim2.fromOffset(props.size.X, props.size.Y),
		position = props.position,
		anchor = props.anchor,
		textSize = 14,
		onActivated = function()
			if props.onPress ~= nil then
				props.onPress()
			end
		end,
	})
end
local function button(
	position: UDim2,
	anchor: Vector2,
	size: Vector2,
	content: React.ReactNode,
	onPress: (() -> ())?
): React.ReactNode
	return e(CompactButton, { position = position, anchor = anchor, size = size, content = content, onPress = onPress })
end

-- Keep the layout panel pure; only the renderer-owned fill component runs animation hooks.
local function ClearanceFill(props: { target: number }): React.ReactNode
	local progress = useProgressTween(props.target, 0.22, nil, true)
	return e("Frame", {
		Size = progress:map(function(fill: number): UDim2
			return UDim2.fromScale(fill, 1)
		end),
		BackgroundColor3 = C.inkGreen,
		BorderSizePixel = 0,
	})
end

local function ShiftCompactHudPanel(props: Props): React.ReactNode
	local view = props.view
	local phone = props.layout == "phone"
	local compact = VM.compact(view, props.bindings or {})
	local inset = if phone then 12 else 24
	-- Roblox's top-left controls occupy the first ~58 px. Right-hand time card has no such overlap.
	local quotaTop = 64
	local quotaWidth = if phone then 210 else 294
	local quotaHeight = if phone then 66 else 82
	local valueSize = if phone then 18 else 22
	local barTop = if phone then 42 else 54
	local quotaChildren: { [string]: React.ReactNode } = {
		heading = label("CLEARANCE CONTRACT", 0, -4, quotaWidth - 24, if phone then 11 else 13, "heading"),
		value = label(`{view.clearedShort} cleared`, 0, if phone then 17 else 23, quotaWidth - 24, valueSize, "timer"),
		bar = e("Frame", {
			Position = UDim2.fromOffset(0, barTop),
			Size = UDim2.new(1, 0, 0, 5),
			BackgroundColor3 = C.manilaDeep,
			BorderSizePixel = 0,
		}, {
			fill = e(ClearanceFill, { target = view.fill }),
		}),
	}
	local clockWidth = if phone then 116 else 148
	local clockHeight = if phone then 66 else 72
	local clock = sheet(Vector2.new(clockWidth, clockHeight), UDim2.new(1, -inset, 0, 24), Vector2.new(1, 0), C.cream, {
		band = e("Frame", {
			Position = UDim2.fromOffset(-12, -12),
			Size = UDim2.new(1, 24, 0, 19),
			BackgroundColor3 = C.stamp,
			BorderSizePixel = 0,
		}, { title = label(ShiftConstants.EMPLOYER_BAND, 8, 0, clockWidth - 16, 11, "heading", C.cream) }),
		time = label(view.time, 0, 12, clockWidth - 24, if phone then 24 else 27, "timer"),
		stage = label(if view.overtime then "OVERTIME" else "SHIFT", 0, 42, clockWidth - 24, 10, "heading"),
	})
	local crewCount = if props.roster ~= nil then #props.roster.members else 0
	local crewPosition = if phone then UDim2.fromOffset(inset + quotaWidth + 12, 64) else UDim2.new(0, inset, 1, -inset)
	local crewAnchor = if phone then Vector2.zero else Vector2.new(0, 1)
	local crewSize = Vector2.new(if phone then 108 else 128, if phone then 48 else 44)
	local crewButton = button(
		crewPosition,
		crewAnchor,
		crewSize,
		sheet(crewSize, UDim2.fromScale(0, 0), Vector2.zero, C.cream, {
			title = label(
				`CREW {crewCount}/4 {if props.crewOpen then "<" else ">"}`,
				0,
				0,
				crewSize.X - 24,
				14,
				"heading"
			),
		}),
		props.onCrewToggle
	)
	local roster: React.ReactNode = nil
	if props.crewOpen and props.roster ~= nil then
		local rosterHeight = 42 + #props.roster.members * 34
		local rows: { [string]: React.ReactNode } = { title = label(props.roster.title, 0, 0, 256, 14, "heading") }
		for index, member in props.roster.members do
			rows[`member{index}`] = label(
				`{member.name}: {member.status}`,
				0,
				24 + (index - 1) * 34,
				256,
				14,
				"body",
				Constants.inkColor(member.tone)
			)
		end
		roster = sheet(
			Vector2.new(280, rosterHeight),
			if phone then UDim2.fromOffset(inset, 142) else UDim2.new(0, inset, 1, -80),
			if phone then Vector2.zero else Vector2.new(0, 1),
			C.cream,
			rows
		)
	end
	-- The hotbar: bottom centre on desktop; on phone at the top, centred between the crew button and the time card.
	local hotbarPosition = UDim2.new(0.5, 0, 1, -inset)
	local hotbarAnchor = Vector2.new(0.5, 1)
	if phone then
		local left = inset + quotaWidth + 12 + crewSize.X + 12
		local right = props.viewport.X - inset - clockWidth - 12
		hotbarPosition = UDim2.fromOffset((left + right) / 2, 24)
		hotbarAnchor = Vector2.new(0.5, 0)
	end
	local hotbar = e(ShiftHotbar, {
		view = view.hotbar,
		phone = phone,
		position = hotbarPosition,
		anchor = hotbarAnchor,
		onSelect = props.onSelect,
	})
	-- What the hands hold, its worth and its keys: a slip above the desktop hotbar (phone has its DROP / THROW buttons).
	local holding: React.ReactNode = nil
	local hands = view.hands
	if hands ~= nil and not phone then
		local actions: { string } = {}
		for _, hint in compact.actions do
			table.insert(actions, `{hint.key} {hint.label}`)
		end
		local slipWidth = 420
		local line = `HOLDING {string.upper(hands.name)}   {compact.cargoValue or hands.value}{if hands.fragile
			then " / fragile"
			else ""}`
		holding = sheet(
			Vector2.new(slipWidth, if #actions > 0 then 58 else 40),
			UDim2.new(0.5, 0, 1, -inset - ShiftHotbarViewModel.barSize(false, #view.hotbar.slots).Y - 8),
			Vector2.new(0.5, 1),
			C.cream,
			{
				title = label(line, 0, -4, slipWidth - 24, 15, "heading", if view.hotbar.locked then C.inkRed else nil),
				actions = if #actions > 0 then label(table.concat(actions, "   "), 0, 20, slipWidth - 24, 12) else nil,
			}
		)
	end
	-- The stamina slip: bottom right on desktop; on phone under the time card.
	local stamina: React.ReactNode = nil
	local staminaView = props.stamina
	if staminaView ~= nil then
		stamina = e(SprintStaminaSlip, {
			view = staminaView,
			size = if phone then Vector2.new(150, 28) else Vector2.new(176, 30),
			position = if phone then UDim2.new(1, -inset, 0, 24 + clockHeight + 8) else UDim2.new(1, -inset, 1, -inset),
			anchor = if phone then Vector2.new(1, 0) else Vector2.new(1, 1),
		})
	end
	local countdown = view.clockOut
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		stamina = stamina,
		clearance = sheet(
			Vector2.new(quotaWidth, quotaHeight),
			UDim2.fromOffset(inset, quotaTop),
			Vector2.zero,
			C.manila,
			quotaChildren
		),
		time = clock,
		crew = crewButton,
		roster = roster,
		hotbar = hotbar,
		holding = holding,
		clockOut = if countdown ~= nil
			then sheet(
				Vector2.new(if phone then 260 else 300, 46),
				UDim2.new(0.5, 0, 0, if phone then 120 else 108),
				Vector2.new(0.5, 0),
				C.cream,
				{
					text = label(
						`CLOCKING OUT IN {countdown}`,
						0,
						0,
						if phone then 236 else 276,
						18,
						"heading",
						C.inkRed
					),
				}
			)
			else nil,
	})
end
return ShiftCompactHudPanel
