--!strict
--[=[
	DepotTopperConstants: each hub station's topper in the V1 kit (owner 11-12, kit mock round 2 #1: one rendered icon,
	one colour, one word). The keys are the stations DepotTopperRules.station names; a topper anchor's `Topper`
	attribute picks one. The colour also tints the station's floor lane and its look outline. Words for young players.
	Static data (spec-exempt).

	@class DepotTopperConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

export type Station = {
	word: string,
	hue: UIToonConstants.Hue,
	icon: UIAssets.ToonIcon,
}

local function station(word: string, hue: UIToonConstants.Hue, icon: UIAssets.ToonIcon): Station
	return table.freeze({ word = word, hue = hue, icon = icon })
end

local STATIONS: { [string]: Station } = {
	shop = station("SHOP", "mint", "shopGift"),
	clock = station("CLOCK IN", "grape", "clock"),
	bell = station("RING", "coral", "bell"),
	radio = station("MUSIC", "sky", "radio"),
	rank = station("RANKS", "lilac", "trophy"),
	locker = station("LOCKERS", "grape", "locker"),
	coffee = station("COFFEE", "cream", "coffee"),
	daily = station("BONUS", "gold", "credits"),
	crew = station("CREWS", "sky", "hostCrown"),
}

return table.freeze({
	STATIONS = table.freeze(STATIONS),
})
