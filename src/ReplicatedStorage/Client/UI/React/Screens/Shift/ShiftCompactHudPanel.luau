--!strict
--[=[
	ShiftCompactHudPanel: the live shift HUD in the V1 kit (shift-desktop / shift-mobile renders), kept restrained the
	way horror games hold back in a run: few elements, each on the full depth stack.
	- top centre: the Gloom meter and the shift clock joined in one plate (ShiftGloomMeter), and while the crew clocks
	  out a coral countdown pill under it;
	- the crew (ShiftCrewList): top-left on desktop under Roblox's buttons, top-right on phone; tapping it shows each
	  member's status beside it (`crewOpen`);
	- bottom centre: the hotbar (ShiftHotbar: the vacuum with its Gloom gauge, the items with their worth), the stamina
	  bar over it while it is not full, and on desktop what the hands hold with its keys over that.
	On phone everything stays clear of the thumbstick (bottom left) and the action arc and Jump (bottom right; those
	buttons are ShiftMobileButtons). Physical px, so text stays readable in a short window. Presentational: it draws the
	views it is given (specced in ShiftHudViewModel, ShiftHotbarViewModel, ShiftCrewViewModel, SprintViewModel).

	@class ShiftCompactHudPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local SprintViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Sprint.SprintViewModel)
local ShiftCrewList = require(script.Parent.ShiftCrewList)
local ShiftGloomMeter = require(script.Parent.ShiftGloomMeter)
local ShiftHotbar = require(script.Parent.ShiftHotbar)
local ShiftHotbarViewModel = require(script.Parent.ShiftHotbarViewModel)
local CrewVM = require(script.Parent.ShiftCrewViewModel)
local VM = require(script.Parent.ShiftHudViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBar = require(Toon.ToonBar)
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type Props = {
	view: VM.HudView,
	roster: CrewVM.RosterView?,
	layout: UIPaperConstants.Layout,
	viewport: Vector2,
	-- The local player (the crew list marks YOU).
	myId: number?,
	crewOpen: boolean?,
	onCrewToggle: (() -> ())?,
	-- A hotbar slot was tapped or clicked: ask for that slot.
	onSelect: ((slot: number) -> ())?,
	bindings: VM.KeyBindings?,
	-- The sprint's stamina while it is not full (Sprint).
	stamina: SprintViewModel.BarView?,
}

-- The crew detail: each member's status in words, on a dark plate beside the list.
local function rosterDetail(
	roster: CrewVM.RosterView,
	phone: boolean,
	position: UDim2,
	anchor: Vector2
): React.ReactNode
	local lineHeight = if phone then 22 else 28
	local width = if phone then 240 else 300
	local rows: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = roster.title,
			textSize = if phone then 15 else 19,
			position = UDim2.fromOffset(14, 8),
			size = UDim2.fromOffset(width - 28, lineHeight),
			fit = true,
		}),
	}
	for index, member in roster.members do
		rows[`member{index}`] = e(ToonText, {
			text = `{member.name}: {member.status}`,
			font = "body",
			color = if member.tone == "danger"
				then UIToonConstants.shade("coral").hi
				elseif member.tone == "ok" then UIToonConstants.shade("mint").hi
				else UIToonConstants.COLOR.white,
			textSize = if phone then 14 else 17,
			position = UDim2.fromOffset(14, 8 + index * lineHeight),
			size = UDim2.fromOffset(width - 28, lineHeight),
			fit = true,
		})
	end
	return e(ToonPanel, {
		hue = "night",
		size = Vector2.new(width, 20 + (#roster.members + 1) * lineHeight),
		position = position,
		anchor = anchor,
		radius = 18,
		pop = true,
		children = rows,
	})
end

local function ShiftCompactHudPanel(props: Props): React.ReactNode
	local view = props.view
	local phone = props.layout == "phone"
	local compact = VM.compact(view, props.bindings or {})
	local inset = if phone then 10 else 24
	local meterTop = if phone then 6 else 12
	local meterHeight = if phone then 70 else 96
	local nodes: { [string]: React.ReactNode } = {
		clearance = e(ShiftGloomMeter, { view = view, phone = phone, top = meterTop }),
	}
	-- The crew: top-left on desktop (under Roblox's buttons), top-right on phone.
	local roster = props.roster
	if roster ~= nil and #roster.members > 0 then
		local crewPosition = if phone then UDim2.new(1, -inset, 0, 6) else UDim2.fromOffset(inset, 66)
		local crewAnchor = if phone then Vector2.new(1, 0) else Vector2.zero
		nodes.crew = e(ShiftCrewList, {
			roster = roster,
			myId = props.myId or 0,
			phone = phone,
			position = crewPosition,
			anchor = crewAnchor,
			onToggle = props.onCrewToggle,
		})
		if props.crewOpen then
			nodes.roster = rosterDetail(
				roster,
				phone,
				if phone then UDim2.new(1, -inset - 186, 0, 6) else UDim2.fromOffset(inset + 248, 66),
				if phone then Vector2.new(1, 0) else Vector2.zero
			)
		end
	end
	-- The hotbar, bottom centre on both (between the thumbstick and the action arc on phone).
	local bar = ShiftHotbarViewModel.barSize(phone, #view.hotbar.slots)
	nodes.hotbar = e(ShiftHotbar, {
		view = view.hotbar,
		phone = phone,
		position = UDim2.new(0.5, 0, 1, -inset - 8),
		anchor = Vector2.new(0.5, 1),
		onSelect = props.onSelect,
	})
	local stackTop = inset + 8 + bar.Y + 14
	-- The stamina bar over the hotbar while it is not full: the sneaker render and a gold (coral when low) bar.
	local staminaView = props.stamina
	if staminaView ~= nil then
		local width = math.max(bar.X, if phone then 200 else 260)
		nodes.stamina = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -stackTop),
			Size = UDim2.fromOffset(width, if phone then 16 else 20),
			BackgroundTransparency = 1,
		}, {
			icon = e(ToonIcon, {
				icon = "stamina",
				anchor = Vector2.new(1, 0.5),
				position = UDim2.new(0, 14, 0.5, -2),
				size = UDim2.fromOffset(if phone then 34 else 44, if phone then 34 else 44),
				drop = 3,
				zIndex = 3,
			}),
			bar = e(ToonBar, {
				kind = if staminaView.low then "load" else "stamina",
				fill = staminaView.fill,
				size = UDim2.fromScale(1, 1),
			}),
		})
		stackTop += (if phone then 16 else 20) + 14
	end
	-- What the hands hold, its worth and its keys (desktop; phone has its DROP / THROW buttons).
	local hands = view.hands
	if hands ~= nil and not phone then
		local actions: { string } = {}
		for _, hint in compact.actions do
			table.insert(actions, `[{hint.key}] {string.upper(hint.label)}`)
		end
		local worth = compact.cargoValue or hands.value
		local slip: { [string]: React.ReactNode } = {
			name = e(ToonText, {
				text = `{string.upper(hands.name)}{if hands.fragile then "  · FRAGILE" else ""}`,
				textSize = 20,
				position = UDim2.fromOffset(16, 0),
				size = UDim2.new(1, -150, 1, 0),
				fit = true,
			}),
			worth = e(ToonPill, {
				text = worth,
				meaning = "gold",
				hue = if hands.fragile then "coral" else "cream",
				textSize = 16,
				anchor = Vector2.new(1, 0.5),
				position = UDim2.new(1, -10, 0.5, 0),
				size = UDim2.fromOffset(124, 30),
			}),
		}
		if #actions > 0 then
			slip.keys = e(ToonText, {
				text = table.concat(actions, "   "),
				font = "body",
				color = UIToonConstants.COLOR.white,
				textSize = 15,
				anchor = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 1, 6),
				size = UDim2.fromOffset(380, 20),
				align = "center",
			})
		end
		nodes.holding = e(ToonPanel, {
			hue = if view.hotbar.locked then "coral" else "grape",
			size = Vector2.new(420, 46),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -stackTop - (if #actions > 0 then 24 else 0)),
			radius = 18,
			children = slip,
		})
	end
	local countdown = view.clockOut
	if countdown ~= nil then
		nodes.clockOut = e(ToonPill, {
			text = `CLOCKING OUT IN {countdown}`,
			hue = "coral",
			textSize = if phone then 16 else 22,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, meterTop + meterHeight + 18),
			size = UDim2.fromOffset(if phone then 250 else 340, if phone then 30 else 40),
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, nodes)
end

return ShiftCompactHudPanel
