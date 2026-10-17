--!strict
--[=[
	RankSlip: the company rank on the results screen (Cleanup Crew "Clearance Level") in the V1 kit: a cream card with
	the XP star render breaking its left edge (the level's number on it), "LV n · Rank" in Fredoka, this shift's XP in a
	mint gradient on the right, the XP bar with its total, the breakdown under it, a gold PROMOTED sticker once a
	level-up has landed and "Incident Report filed" in coral for a caught player. Desktop draws it 820x120 design px;
	the phone draws a 370x56 strip (level, rank, gain and a thin bar). Presentational: the words are RankViewModel.slip.

	@class RankSlip
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBar = require(Toon.ToonBar)
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type RankSlipProps = {
	view: RankViewModel.SlipView,
	layout: UIPaperConstants.Layout,
	position: UDim2,
}

-- "CLEARANCE LEVEL 2" -> "2" (the star carries the number).
local function levelOf(heading: string): string
	return string.match(heading, "(%d+)%s*$") or ""
end

-- "PROBATIONARY ASSOCIATE" -> "Probationary Associate".
local function titleCase(text: string): string
	local words: { string } = {}
	for word in string.gmatch(string.lower(text), "%S+") do
		table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end
	return table.concat(words, " ")
end

local function RankSlip(props: RankSlipProps): React.ReactNode
	local view = props.view
	local phone = props.layout == "phone"
	local size = if phone then Vector2.new(370, 58) else Vector2.new(820, 124)
	local star = if phone then 64 else 132
	local left = if phone then 46 else 104
	local level = levelOf(view.heading)
	local face: { [string]: React.ReactNode } = {
		star = e("Frame", {
			Position = UDim2.fromOffset(-star * 0.36, (size.Y - star) / 2 - 4),
			Size = UDim2.fromOffset(star, star),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, {
			icon = e(ToonIcon, { icon = "xp", size = UDim2.fromScale(1, 1), drop = 5 }),
			number = e(ToonText, {
				text = level,
				textSize = if phone then 22 else 42,
				size = UDim2.fromScale(1, 1),
				align = "center",
				zIndex = 3,
			}),
		}),
		title = e(ToonText, {
			text = `LV {level} · {titleCase(view.rank)}`,
			font = "body",
			textSize = if phone then 15 else 26,
			position = UDim2.fromOffset(left, if phone then 4 else 14),
			size = UDim2.fromOffset(size.X - left - (if phone then 90 else 200), if phone then 20 else 32),
			fit = true,
		}),
		bar = e(ToonBar, {
			kind = "xp",
			fill = view.fill,
			label = if phone then nil else view.xpText,
			labelSize = 20,
			position = UDim2.fromOffset(left, if phone then 32 else 54),
			size = UDim2.fromOffset(size.X - left - 20, if phone then 14 else 32),
		}),
	}
	local gain = view.gain
	if gain ~= nil then
		face.gain = e(ToonText, {
			text = string.gsub(gain, " this shift", ""),
			meaning = "mint",
			textSize = if phone then 20 else 40,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -16, 0, if phone then 0 else 4),
			size = UDim2.fromOffset(if phone then 90 else 200, if phone then 26 else 48),
			align = "right",
			fit = true,
		})
	end
	if not phone then
		local breakdown = view.breakdown
		local incident = view.incident
		if breakdown ~= nil or incident ~= nil then
			face.breakdown = e(ToonText, {
				text = if incident ~= nil then incident else breakdown or "",
				font = "body",
				color = if incident ~= nil then UIToonConstants.shade("coral").lo else UIToonConstants.COLOR.ink,
				textSize = 16,
				position = UDim2.fromOffset(left, 92),
				size = UDim2.fromOffset(size.X - left - 20, 22),
				fit = true,
			})
		end
	end
	if view.promoted then
		face.promoted = e(ToonPill, {
			text = "PROMOTED!",
			hue = "gold",
			textSize = if phone then 13 else 22,
			tilt = -6,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(1, if phone then -60 else -120, 0, if phone then -6 else -10),
			size = UDim2.fromOffset(if phone then 100 else 170, if phone then 24 else 40),
			zIndex = 6,
		})
	end
	return e(ToonPanel, {
		size = size,
		position = props.position,
		radius = if phone then 18 else 26,
		children = face,
	})
end

return RankSlip
