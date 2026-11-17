--!strict
--[=[
	DepotProfileCard: the depot hub's profile card in the V1 kit (hub-desktop / hub-mobile renders), top-left right of
	Roblox's menu and chat buttons: the player's own character in a ring breaking the card, the player's name, the
	Clearance Level star, the rank name on desktop and the XP bar. Presentational (the words come from
	DepotHubViewModel.profile). Exempt. Split out of DepotHubPanel, which lays it out with the rest of the hub.

	@class DepotProfileCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotHubViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubViewModel)
local CharacterPortrait = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.CharacterPortrait)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBar = require(Toon.ToonBar)
local ToonIcon = require(Toon.ToonIcon)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

export type DepotProfileCardProps = {
	phone: boolean,
	-- Whose character the profile ring shows (nil: the fallback photo, as in the story).
	userId: number?,
	profile: DepotHubViewModel.ProfileView,
}

local function DepotProfileCard(props: DepotProfileCardProps): React.ReactNode
	local phone = props.phone
	local profile = props.profile
	local portrait = if phone then 78 else 168
	local cardX = if phone then 168 else 150
	local cardY = if phone then 6 else 80
	local card = if phone then Vector2.new(232, 52) else Vector2.new(356, 134)
	local textLeft = if phone then 36 else 46
	local face: { [string]: React.ReactNode } = {
		name = e(ToonText, {
			text = profile.name,
			-- On phone the name sits right above the XP bar: a size whose caps (optically centred) and drop clear it.
			textSize = if phone then 23 else 44,
			position = UDim2.fromOffset(textLeft, if phone then 0 else 10),
			size = UDim2.fromOffset(card.X - textLeft - (if phone then 52 else 80), if phone then 28 else 48),
			fit = true,
			automaticWidth = false,
		}),
		level = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, if phone then -8 else -18, 0, if phone then -6 else 4),
			Size = UDim2.fromOffset(if phone then 40 else 62, if phone then 40 else 62),
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, {
			star = e(ToonIcon, { icon = "xp", size = UDim2.fromScale(1, 1), drop = 3 }),
			-- Centred on the star's body (its optical centre sits 3% below its box's centre), not on its box.
			number = e(ToonText, {
				text = profile.level,
				textSize = if phone then 18 else 28,
				position = UDim2.fromScale(0, 0.03),
				size = UDim2.fromScale(1, 1),
				align = "center",
				zIndex = 3,
			}),
		}),
		bar = e(ToonBar, {
			kind = "xp",
			fill = profile.fill,
			label = if phone then nil else profile.xpText,
			labelSize = 20,
			position = UDim2.fromOffset(textLeft - 4, if phone then 32 else 86),
			size = UDim2.fromOffset(card.X - textLeft - 14, if phone then 12 else 32),
		}),
	}
	if not phone then
		face.rank = e(ToonText, {
			text = profile.rank,
			font = "body",
			textSize = 22,
			position = UDim2.fromOffset(textLeft, 56),
			size = UDim2.fromOffset(card.X - textLeft - 14, 26),
			fit = true,
		})
	end
	return e("Frame", {
		Position = UDim2.fromOffset(if phone then 128 else 22, if phone then 0 else 56),
		Size = UDim2.fromOffset(cardX - (if phone then 128 else 22) + card.X, portrait),
		BackgroundTransparency = 1,
	}, {
		card = e(ToonSurface, {
			hue = "cream",
			radius = if phone then 18 else 26,
			pattern = "rings",
			small = phone,
			position = UDim2.fromOffset(cardX - (if phone then 128 else 22), cardY - (if phone then 0 else 56)),
			size = UDim2.fromOffset(card.X, card.Y),
			children = face,
		}),
		-- The player's own character (CharacterPortrait, posed for their rank) in a ring, breaking the card's left
		-- edge.
		portrait = e("Frame", {
			Size = UDim2.fromOffset(portrait, portrait),
			BackgroundColor3 = UIToonConstants.shade("lilac").hi,
			ZIndex = 3,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = if phone then 4 else 6 }),
			ring = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -10, 1, -10),
				BackgroundTransparency = 1,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				stroke = e("UIStroke", { Color = COLOR.white, Thickness = if phone then 2 else 4 }),
			}),
			photo = e(CharacterPortrait, {
				userId = props.userId,
				context = "profile",
				framing = "bust",
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.5),
				size = UDim2.new(1, -12, 1, -12),
				round = true,
				zIndex = 3,
			}),
		}),
	})
end

return DepotProfileCard
