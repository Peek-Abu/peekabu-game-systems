--!strict
--[=[
	ShiftCompactHudPanel: the live shift HUD in the V1 kit (shift-desktop / shift-mobile renders), kept restrained the
	way horror games hold back in a run: few elements, each on the full depth stack.
	- top centre: the Gloom meter and the shift clock joined in one plate (ShiftGloomMeter); while the crew clocks out,
	  ShiftHud draws the clock-out board under it (ShiftClockOutBoard);
	- under the meter, the local player's Gloom-life pips (ShiftLivesPips.Local); the clock-out board opens under them;
	- the crew (ShiftCrewList): top-left on desktop under Roblox's buttons, top-right on phone; tapping it shows each
	  member's status (`crewOpen`) beside it, or under it on a narrow window, and on the left under the meter on phone
	  (never on the meter, its clock or the clock-out board: ShiftCrewViewModel.rosterFrame);
	- bottom centre: the hotbar (ShiftHotbar: the vacuum with its Gloom gauge, the items with their worth), the stamina
	  bar over it while it is not full, and on desktop what the hands hold with its keys over that.
	On phone everything stays clear of the thumbstick (bottom left) and the action arc and Jump (bottom right; those
	buttons are ShiftMobileButtons). Laid out in HUD design px: ShiftHud draws it inside PaperHudFrame at the game's
	one UI scale. Presentational: it draws the
	views it is given (specced in ShiftHudViewModel, ShiftHotbarViewModel, ShiftCrewViewModel, SprintViewModel).

	@class ShiftCompactHudPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local React = require(ReplicatedStorage.Packages.React)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftCountdown = require(script.Parent.ShiftCountdown)
local ShiftCrewList = require(script.Parent.ShiftCrewList)
local ShiftGloomMeter = require(script.Parent.ShiftGloomMeter)
local ShiftHotbar = require(script.Parent.ShiftHotbar)
local ShiftHotbarViewModel = require(script.Parent.ShiftHotbarViewModel)
local ShiftLivesPips = require(script.Parent.ShiftLivesPips)
local CrewVM = require(script.Parent.ShiftCrewViewModel)
local VM = require(script.Parent.ShiftHudViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
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
	-- The sprint's stamina bar while it is not full (Sprint): ShiftHud's live bar element, which reads the stamina
	-- itself so a draining bar re-renders only the bar, not this panel.
	stamina: React.ReactElement?,
	-- Whether the clocks run live (ShiftHud): the shift clock and a caught member's "back in" line each tick as a
	-- ShiftCountdown to the view's deadlines, so only they re-render each second. A story draws the view's texts as
	-- they are.
	live: boolean?,
}

-- A one-line label's width in design px at `textSize` (Fredoka for `body`, else Luckiest Guy), measured once per label.
local measured: { [string]: number } = {}
local function measure(text: string, textSize: number, body: boolean): number
	local key = `{if body then "b" else "d"}{textSize}:{text}`
	local width = measured[key]
	if width == nil then
		local font = if body then Enum.Font.FredokaOne else Enum.Font.LuckiestGuy
		width = TextService:GetTextSize(text, textSize, font, Vector2.new(10000, 1000)).X
		measured[key] = width
	end
	return width
end

-- The crew detail: each member's status in words, on a dark plate where CrewVM.rosterFrame puts it (never on the
-- Gloom meter, its clock or what shares the phone's band under it), drawn over the meter's layer. Every line is
-- measured: a long name is cut short (CrewVM.detailLine) and the line drawn at the size that fits
-- (ToonStyleViewModel.fitSize), never under the text floor; a title too wide even at the floor drops its truck.
local function rosterDetail(
	roster: CrewVM.RosterView,
	phone: boolean,
	frame: CrewVM.DetailFrame,
	live: boolean
): React.ReactNode
	local lineHeight = frame.line
	local pad = frame.padding
	local room = frame.size.X - 2 * pad
	local floor = if phone then UIPaperConstants.TEXT_MIN.phone else UIPaperConstants.TEXT_MIN.desktop
	local titleSize = if phone then 15 else 19
	local titleRoom = room - 2 * ToonStyleViewModel.stroke(titleSize)
	local title = if measure(roster.title, floor, false) <= titleRoom
		then roster.title
		else string.match(roster.title, "^(.-) · ") or roster.title
	local rows: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = title,
			textSize = ToonStyleViewModel.fitSize(measure(title, titleSize, false), titleSize, titleRoom, floor),
			position = UDim2.fromOffset(pad, 8),
			size = UDim2.fromOffset(room, lineHeight),
			fit = true,
		}),
	}
	local lineSize = if phone then 14 else 17
	local function atFloor(text: string): number
		return measure(text, floor, true)
	end
	for index, member in roster.members do
		local function line(status: string): React.ReactNode
			local text = CrewVM.detailLine(member.name, status, room, atFloor)
			return e(ToonText, {
				text = text,
				font = "body",
				color = if member.tone == "danger"
					then UIToonConstants.shade("coral").hi
					elseif member.tone == "ok" then UIToonConstants.shade("mint").hi
					else UIToonConstants.COLOR.white,
				textSize = ToonStyleViewModel.fitSize(measure(text, lineSize, true), lineSize, room, floor),
				position = UDim2.fromOffset(pad, 8 + index * lineHeight),
				size = UDim2.fromOffset(room, lineHeight),
				fit = true,
			})
		end
		local caughtUntil = member.caughtUntil
		rows[`member{index}`] = if live and caughtUntil ~= nil
			then e(ShiftCountdown, {
				deadline = caughtUntil,
				render = function(clock: string): React.ReactNode
					return line(`CAUGHT · back {clock}`)
				end,
			})
			else line(member.status)
	end
	return e(ToonPanel, {
		hue = "night",
		size = frame.size,
		position = UDim2.fromOffset(frame.position.X, frame.position.Y),
		radius = 18,
		zIndex = 2,
		pop = true,
		children = rows,
	})
end

local function ShiftCompactHudPanel(props: Props): React.ReactNode
	local view = props.view
	local phone = props.layout == "phone"
	local compact = VM.compact(view, props.bindings or {})
	local inset = if phone then 10 else 24
	-- The stopwatch render breaks the meter's top-right corner (24 / 34 px above it): the meter sits low enough that
	-- the render stays on the screen (the HUD layer spans the whole viewport, top bar included).
	local meterTop = if phone then VM.METER.phone.top else VM.METER.desktop.top
	local live = props.live == true
	-- Phone: the meter and the crew list share the top band; on a narrow screen both give up width so they never overlap.
	local fit = CrewVM.phoneFit(props.viewport.X)
	local nodes: { [string]: React.ReactNode } = {
		clearance = e(ShiftGloomMeter, {
			view = view,
			phone = phone,
			top = meterTop,
			width = if phone then fit.meter else nil,
			deadline = if live then view.endsAt else nil,
		}),
	}
	-- The local player's Gloom-life pips just under the meter (ShiftHudViewModel.livesFrame), from their roster entry.
	local roster = props.roster
	if roster ~= nil then
		for _, member in roster.members do
			local lives, livesMax = member.lives, member.livesMax
			if member.userId == props.myId and lives ~= nil and livesMax ~= nil then
				nodes.lives = e(ShiftLivesPips.Local, {
					lives = lives,
					livesMax = livesMax,
					layout = props.layout,
					viewport = props.viewport,
				})
			end
		end
	end
	-- The crew: top-left on desktop (under Roblox's buttons), top-right on phone.
	if roster ~= nil and #roster.members > 0 then
		-- The list's top-left corner (the phone's is pinned to the right edge; the open card lays out against it).
		local listWidth = if phone then fit.list else nil
		local listAt = if phone
			then Vector2.new(props.viewport.X - inset - CrewVM.listSize(phone, #roster.members, listWidth).X, 6)
			else Vector2.new(inset, 66)
		nodes.crew = e(ShiftCrewList, {
			roster = roster,
			myId = props.myId or 0,
			phone = phone,
			position = if phone then UDim2.new(1, -inset, 0, listAt.Y) else UDim2.fromOffset(listAt.X, listAt.Y),
			anchor = if phone then Vector2.new(1, 0) else Vector2.zero,
			width = listWidth,
			onToggle = props.onCrewToggle,
		})
		if props.crewOpen then
			local frame = CrewVM.rosterFrame(phone, props.viewport, #roster.members, listAt)
			nodes.roster = rosterDetail(roster, phone, frame, live)
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
	local staminaBar = props.stamina
	if staminaBar ~= nil then
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
			bar = staminaBar,
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
				textSize = 16,
				anchor = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 1, 6),
				size = UDim2.fromOffset(380, 22),
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
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, nodes)
end

return ShiftCompactHudPanel
