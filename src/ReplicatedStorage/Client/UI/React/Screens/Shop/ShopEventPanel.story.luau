--!strict
--[=[
	ShopEventPanel.story: the Thanksgiving event's Shop tab with its real offers, Locker and keys, at desktop or phone
	size, rich or broke in acorns. The offer cards are simple stand-ins here (the real tab draws the Shop's own card).
	In Studio's edit mode (UI Labs); buttons only print.

	@class ShopEventPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local EventRegistry = require(ReplicatedStorage.Shared.Features.Event.Data.EventRegistry)
local ToonSurface = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSurface)
local ToonText = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonText)
local ShopEventPanel = require(script.Parent.ShopEventPanel)
local EventVM = require(script.Parent.ShopEventViewModel)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Phone = false, Acorns = 120, DaysLeft = 9 },
}, function(props)
	local phone = props.controls.Phone == true
	local acorns = tonumber(props.controls.Acorns) or 0
	local event = EventRegistry.get("harvest")
	assert(event ~= nil, "ShopEventPanel.story: no harvest event")
	local now = event.ends - (tonumber(props.controls.DaysLeft) or 9) * 86400 + 60
	local owns = function(_id: string): boolean
		return false
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(46, 26, 64),
	}, {
		panel = e(ShopEventPanel, {
			header = EventVM.header(event, now, false, acorns),
			cards = EventVM.offers(event, owns, { gleam = 0, credits = 0, acorns = acorns }),
			locker = EventVM.locker(event),
			keys = EventVM.keys(event, acorns),
			note = nil,
			width = if phone then 760 else 1600,
			height = if phone then 320 else 800,
			headingSize = if phone then 24 else 48,
			textSize = if phone then 13 else 22,
			gap = if phone then 10 else 18,
			phone = phone,
			renderCard = function(card, size, order)
				local face: { [string]: React.ReactNode } = {
					name = e(ToonText, {
						text = `{card.name} · {card.price}`,
						textSize = if phone then 13 else 22,
						position = UDim2.fromOffset(10, 10),
						size = UDim2.new(1, -20, 0, 30),
						fit = true,
					}),
				}
				return e("Frame", {
					Size = UDim2.fromOffset(size.X, size.Y),
					BackgroundTransparency = 1,
					LayoutOrder = order,
				}, {
					surface = e(ToonSurface, {
						hue = "grape",
						radius = 14,
						size = UDim2.fromScale(1, 1),
						children = face,
					}),
				})
			end,
			onLocker = function(id)
				print(`ShopEventPanel.story: open locker {id}`)
			end,
			onKey = function(id)
				print(`ShopEventPanel.story: buy key {id}`)
			end,
		}),
	})
end)
