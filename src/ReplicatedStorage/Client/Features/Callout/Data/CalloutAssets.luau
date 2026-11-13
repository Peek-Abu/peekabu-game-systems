--!strict
--[=[
	CalloutAssets: the art a callout shows, by name (the image ids themselves live in UIAssets).
	- `PING_ICON`: each ping's kit render (CalloutRegistry ids).
	- `stickerImage(id)`: a sticker's picture: its uploaded art (UIAssets.stickers); the shop gift for one with none.
	- `PING_SOUND`: the UI sound tier a ping plays (stickers are silent).

	@class CalloutAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantPortraitAssets = require(ReplicatedStorage.Client.Features.Occupant.Data.OccupantPortraitAssets)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UISoundFormulas = require(ReplicatedStorage.Client.Features.UI.Utils.UISoundFormulas)

local PING_ICON: { [string]: UIAssets.ToonIcon } = {
	gloom = "gloom",
	loot = "gleamPile",
	-- "Monster!" is about any map's monster: the neutral monster icon, no one kind's face.
	manager = OccupantPortraitAssets.NEUTRAL,
	help = "grab",
	truck = "truck",
	okay = "heart",
}

local PING_SOUND: UISoundFormulas.Tier = "confirm"

local CalloutAssets = {
	PING_ICON = table.freeze(PING_ICON),
	PING_SOUND = PING_SOUND,
}

-- The sticker's image: its uploaded art, else the sticker sheet.
function CalloutAssets.stickerImage(id: string): string
	local fallback: UIAssets.ToonIcon = "stickers"
	return UIAssets.stickers[id] or UIAssets.toonIcons[fallback]
end

-- The ping's image.
function CalloutAssets.pingImage(id: string): string
	local icon: UIAssets.ToonIcon = PING_ICON[id] or "gloom"
	return UIAssets.toonIcons[icon]
end

return table.freeze(CalloutAssets)
