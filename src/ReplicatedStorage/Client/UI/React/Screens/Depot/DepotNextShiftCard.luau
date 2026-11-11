--!strict
--[=[
	DepotNextShiftCard: the hub's "Next shift" CTA (V1 hub render), bottom-centre between the phone's thumbstick and
	Jump: a cream bar with the company truck render breaking its top-left corner, NEXT SHIFT, a line ("Walk into a truck
	bed to join", or the truck's countdown in a coral pill), a seat per place with each crew member's own character
	(desktop) and the mint GO! with Gleam sparkles. What it says is DepotPadViewModel.cta; GO! is `onGo` (the hub opens
	the Jobs board, the queue pad departs now). On a hosted truck the host also gets two chips above the card (the
	friends-only lock, `onLock`, and Invite, `onInvite`) and may kick another crew member: tap their seat, then tap
	again while it asks "Kick?" (`onKick`; the ask clears after KICK_CONFIRM_SECONDS). On a phone the host's seats sit
	above the card too, so kicking works there. On a hosted truck the OFFICE / SCHOOL map cards (DepotMapCards, `maps`)
	stand at the card's right above the host's chips; only the host's tap reaches `onPickMap`. Presentational (exempt; story in DepotHubPanel.story).

	@class DepotNextShiftCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local HostConstants = require(ReplicatedStorage.Shared.Features.Host.Data.HostConstants)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local DepotMapCards = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotMapCards)
local DepotPadViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadViewModel)
local CharacterPortrait = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.CharacterPortrait)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonSparkle = require(Toon.ToonSparkle)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

export type DepotNextShiftCardProps = {
	cta: DepotPadViewModel.CtaView,
	phone: boolean,
	onGo: () -> (),
	onKick: ((userId: number) -> ())?,
	onLock: ((locked: boolean) -> ())?,
	onInvite: (() -> ())?,
	onUpgrade: (() -> ())?,
	-- A hosted truck's OFFICE / SCHOOL cards (DepotPadViewModel.maps) and the host's tap.
	maps: DepotPadViewModel.MapPickView?,
	onPickMap: ((map: ShiftTypes.MapId) -> ())?,
}

-- How long a seat's "Kick?" waits for the second tap.
local KICK_CONFIRM_SECONDS = 3
-- A phone host's seat size (the seat row sits above the card there).
local PHONE_HOST_SEAT = 40

type Geometry = {
	size: Vector2,
	bottom: number,
	truck: number,
	textLeft: number,
	title: number,
	line: number,
	go: Vector2,
	seat: number,
}

local DESKTOP: Geometry = {
	size = Vector2.new(940, 140),
	bottom = 26,
	truck = 300,
	textLeft = 252,
	title = 48,
	line = 22,
	go = Vector2.new(150, 86),
	seat = 52,
}
local PHONE: Geometry = {
	size = Vector2.new(430, 72),
	bottom = 10,
	truck = 156,
	textLeft = 128,
	title = 28,
	line = 15,
	go = Vector2.new(92, 54),
	seat = 0,
}

local function seat(
	view: DepotPadViewModel.SeatView,
	side: number,
	order: number,
	asking: boolean,
	onTap: (() -> ())?
): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		stroke = e("UIStroke", {
			Color = if asking
				then UIToonConstants.shade("coral").base
				elseif view.you then COLOR.selected
				else COLOR.ink,
			Thickness = if view.you or asking then 5 else 4,
		}),
	}
	if asking then
		children.ask = e(ToonPill, {
			text = "Kick?",
			hue = "coral",
			textSize = math.max(12, math.floor(side * 0.3)),
			size = UDim2.fromOffset(side * 1.3, side * 0.45),
			position = UDim2.new(0.5, -side * 0.65, 1, 2),
		})
	end
	if view.host then
		-- The host's crown sits on the seat's top edge, breaking it.
		children.crown = e(ToonIcon, {
			icon = "hostCrown",
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 0, side * 0.28),
			size = UDim2.fromOffset(side * 0.7, side * 0.7),
			drop = 3,
			zIndex = 3,
		})
	end
	if not view.open and view.userId ~= nil then
		children.face = e(CharacterPortrait, {
			userId = view.userId,
			context = "crew",
			framing = "head",
			size = UDim2.fromScale(1, 1),
			round = true,
		})
	end
	local look = {
		Size = UDim2.fromOffset(side, side),
		BackgroundColor3 = if view.open then UIToonConstants.shade("cream").base else UIToonConstants.shade("lilac").hi,
		BackgroundTransparency = if view.open then 1 else 0,
		LayoutOrder = order,
	}
	if onTap == nil then
		return e("Frame", look, children)
	end
	return e("TextButton", {
		Size = look.Size,
		BackgroundColor3 = look.BackgroundColor3,
		BackgroundTransparency = look.BackgroundTransparency,
		LayoutOrder = look.LayoutOrder,
		Text = "",
		AutoButtonColor = false,
		[React.Event.Activated] = onTap,
	}, children)
end

-- A row of seats; a kickable one asks "Kick?" on the first tap and kicks on the second.
local function seatRow(
	cta: DepotPadViewModel.CtaView,
	side: number,
	asking: number?,
	setAsking: (number?) -> (),
	onKick: ((userId: number) -> ())?
): { [string]: React.ReactNode }
	local seats: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, view in cta.seats do
		local userId = view.userId
		local onTap: (() -> ())? = nil
		if view.kickable and userId ~= nil and onKick ~= nil then
			onTap = function()
				if asking == userId then
					setAsking(nil)
					onKick(userId)
				else
					setAsking(userId)
				end
			end
		end
		seats[`seat{index}`] = seat(view, side, index, asking ~= nil and asking == userId, onTap)
	end
	return seats
end

-- How tall the host's chips are, per layout (a phone host's seats sit above them).
local function chipHeight(phone: boolean): number
	return if phone then 34 else 44
end

-- The host's chips: the friends-only lock, Invite and, for a host without it, the Big Crew pass ("Get 6 seats").
local function hostChips(props: DepotNextShiftCardProps, controls: DepotPadViewModel.HostControls): React.ReactNode
	local height = chipHeight(props.phone)
	-- Sized for their words at this text size (the button's default 28 leaves the label too little room: "INVIT").
	local textSize = if props.phone then 14 else 20
	local onLock = props.onLock
	local onInvite = props.onInvite
	local onUpgrade = props.onUpgrade
	local upgrade: React.ReactNode = nil
	if controls.upgrade then
		upgrade = e(ToonButton, {
			variant = "grape",
			text = HostConstants.TEXT.upgrade,
			small = true,
			textSize = textSize,
			size = UDim2.fromOffset(if props.phone then 138 else 180, height),
			onActivated = function()
				if onUpgrade ~= nil then
					onUpgrade()
				end
			end,
			layoutOrder = 3,
		})
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 0, -8),
		Size = UDim2.fromOffset(if props.phone then 440 else 640, height),
		BackgroundTransparency = 1,
	}, {
		upgrade = upgrade,
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		lock = e(ToonButton, {
			variant = if controls.locked then "night" else "secondary",
			text = if controls.locked then "Friends only" else "Anyone can join",
			icon = if controls.locked then "friendsLock" else "friendsLockOpen",
			small = true,
			textSize = textSize,
			size = UDim2.fromOffset(if props.phone then 176 else 260, height),
			selected = controls.locked,
			onActivated = function()
				if onLock ~= nil then
					onLock(not controls.locked)
				end
			end,
			layoutOrder = 1,
		}),
		invite = e(ToonButton, {
			variant = "gleam",
			text = "Invite",
			icon = "invite",
			small = true,
			textSize = textSize,
			size = UDim2.fromOffset(if props.phone then 104 else 160, height),
			onActivated = function()
				if onInvite ~= nil then
					onInvite()
				end
			end,
			layoutOrder = 2,
		}),
	})
end

local function DepotNextShiftCard(props: DepotNextShiftCardProps): React.ReactNode
	local cta = props.cta
	local g = if props.phone then PHONE else DESKTOP
	-- The seat waiting for its second tap ("Kick?"), by UserId.
	local nobody: number? = nil
	local asking, setAskingState = React.useState(nobody)
	local function setAsking(userId: number?)
		setAskingState(userId)
	end
	React.useEffect(function(): (() -> ())?
		if asking == nil then
			return nil
		end
		local thread = task.delay(KICK_CONFIRM_SECONDS, function()
			setAskingState(nil)
		end)
		return function()
			task.cancel(thread)
		end
	end, { asking })
	local height = g.size.Y
	local lineChildren: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		text = e(ToonText, {
			text = cta.line,
			font = "body",
			textSize = g.line,
			size = UDim2.fromScale(0, 1),
			automaticWidth = true,
			layoutOrder = 1,
		}),
	}
	if cta.time ~= nil then
		lineChildren.time = e(ToonPill, {
			text = cta.time,
			hue = "coral",
			textSize = math.floor(g.line * 1.25),
			size = UDim2.fromOffset(g.line * 3.6, g.line * 1.7),
			layoutOrder = 2,
		})
	end
	-- The seats sit between the line and GO!; the line and title stop short of them.
	local seatsWidth = if g.seat > 0 and #cta.seats > 0 then #cta.seats * (g.seat + 8) + 6 else 0
	local textWidth = g.size.X - g.textLeft - g.go.X - 32 - seatsWidth
	local face: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = cta.title,
			textSize = g.title,
			position = UDim2.fromOffset(g.textLeft, if props.phone then 4 else 14),
			size = UDim2.fromOffset(textWidth, g.title + 8),
			fit = true,
		}),
		line = e("Frame", {
			Position = UDim2.fromOffset(g.textLeft, if props.phone then 38 else 74),
			Size = UDim2.fromOffset(textWidth, if props.phone then 26 else 44),
			BackgroundTransparency = 1,
		}, lineChildren),
		go = e(ToonButton, {
			variant = cta.variant,
			text = cta.go,
			textSize = if props.phone then 34 else 50,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -16, 0.5, -2),
			size = UDim2.fromOffset(g.go.X, g.go.Y),
			disabled = not cta.canGo,
			sound = "cta",
			onActivated = props.onGo,
			zIndex = 4,
		}),
	}
	if g.seat > 0 and #cta.seats > 0 then
		local seats = seatRow(cta, g.seat, asking, setAsking, props.onKick)
		face.seats = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -g.go.X - 30, 0.5, 4),
			Size = UDim2.fromOffset(seatsWidth, g.seat + 8),
			BackgroundTransparency = 1,
		}, seats)
	end
	local controls = cta.hostControls
	if controls ~= nil then
		face.hostChips = hostChips(props, controls)
		if props.phone and #cta.seats > 0 then
			-- The phone card has no seat row: the host's seats sit above it, a row over the chips, so kicking works
			-- there and the two never overlap.
			face.hostSeats = e("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromOffset(g.textLeft, -(chipHeight(true) + 22)),
				Size = UDim2.fromOffset(#cta.seats * (PHONE_HOST_SEAT + 8), PHONE_HOST_SEAT),
				BackgroundTransparency = 1,
			}, seatRow(cta, PHONE_HOST_SEAT, asking, setAsking, props.onKick))
		end
	end
	local maps = props.maps
	local onPickMap = props.onPickMap
	if maps ~= nil and onPickMap ~= nil then
		-- The map cards stand at the card's right, over the host's chips (and a phone host's seats) when there are any.
		local lift = 8
		if controls ~= nil then
			lift += chipHeight(props.phone) + 10
			if props.phone and #cta.seats > 0 then
				lift += PHONE_HOST_SEAT + 14
			end
		end
		face.maps = e(DepotMapCards.render, {
			view = maps,
			phone = props.phone,
			position = UDim2.new(1, -8, 0, -lift),
			onPick = onPickMap,
		})
	end
	local truckSize = g.truck
	face.truck = e(ToonIcon, {
		image = UIAssets.toonPhotos.truckCut,
		position = UDim2.fromOffset(-truckSize * 0.2, height - truckSize * 0.92),
		size = UDim2.fromOffset(truckSize, truckSize * 0.82),
		drop = 6,
		zIndex = 3,
	})
	face.sparkles = e(ToonSparkle, {
		spots = {
			{ position = UDim2.fromOffset(truckSize * 0.92, 0), size = if props.phone then 22 else 36 },
			{ position = UDim2.new(1, -g.go.X - 6, 0, -6), size = if props.phone then 18 else 30 },
			{ position = UDim2.new(1, -g.go.X * 0.4, 0, 4), size = if props.phone then 14 else 24 },
		},
		zIndex = 6,
	})
	return e(ToonPanel, {
		size = g.size,
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -g.bottom),
		radius = if props.phone then 20 else 26,
		children = face,
	})
end

return DepotNextShiftCard
