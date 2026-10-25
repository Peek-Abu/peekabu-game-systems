--!strict
--[=[
	CalloutAssets: the art a callout shows, by name (the image ids themselves live in UIAssets).
	- `PING_ICON`: each ping's kit render (CalloutRegistry ids).
	- `stickerImage(id)`: a sticker's picture. PLACEHOLDERS until the sticker sheets are approved and uploaded: each
	  sticker borrows a kit render that hints at it; the real art replaces this table (UIAssets).
	- `PING_SOUND`: the UI sound tier a ping plays (stickers are silent).

	@class CalloutAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UISoundFormulas = require(ReplicatedStorage.Client.Features.UI.Utils.UISoundFormulas)

local PING_ICON: { [string]: UIAssets.ToonIcon } = {
	gloom = "gloom",
	loot = "gleamPile",
	manager = "managerHunt",
	help = "grab",
	truck = "truck",
	okay = "heart",
}

-- Placeholder stand-ins (see above).
local STICKER_STAND_IN: { [string]: UIAssets.ToonIcon } = {
	["CozyPack.Cocoa"] = "heart",
	["CozyPack.Sleepy"] = "clock",
	["CozyPack.Pillow"] = "gift",
	["BubblePack.Ducky"] = "fishtank",
	["BubblePack.Bubbles"] = "gleam",
	["BubblePack.Splash"] = "spray",
	["SheriffPack.Badge"] = "key",
	["SheriffPack.Howdy"] = "pippaHappy",
	["SheriffPack.Grump"] = "managerCalm",
}

local PING_SOUND: UISoundFormulas.Tier = "confirm"

local CalloutAssets = {
	PING_ICON = table.freeze(PING_ICON),
	PING_SOUND = PING_SOUND,
}

-- The sticker's image (its stand-in for now); the shop gift for a sticker with none.
function CalloutAssets.stickerImage(id: string): string
	local icon: UIAssets.ToonIcon = STICKER_STAND_IN[id] or "shopGift"
	return UIAssets.toonIcons[icon]
end

-- The ping's image.
function CalloutAssets.pingImage(id: string): string
	local icon: UIAssets.ToonIcon = PING_ICON[id] or "gloom"
	return UIAssets.toonIcons[icon]
end

return table.freeze(CalloutAssets)
