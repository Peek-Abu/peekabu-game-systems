--!strict
--[=[
	ShopPassesPanel.story: the Passes tab with the Big Crew card in each state (on sale, loading, owned, off sale), at
	desktop or phone size. In Studio's edit mode (UI Labs); Buy only prints.

	@class ShopPassesPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local ShopPassesPanel = require(script.Parent.ShopPassesPanel)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { State = "buy", Phone = false },
}, function(props)
	local phone = props.controls.Phone == true
	local state = props.controls.State
	local infos: { [string]: ShopStore.PassInfo } = {}
	if state ~= "loading" then
		infos.bigCrew = {
			price = if state == "unavailable" then nil else 149,
			icon = nil,
			name = "Big Crew",
			forSale = state ~= "unavailable",
		}
	end
	local cards = VM.passes({ "bigCrew" }, infos, function(_key: string): boolean
		return state == "owned"
	end)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(46, 26, 64),
	}, {
		panel = e(ShopPassesPanel, {
			cards = cards,
			width = if phone then 760 else 1600,
			height = if phone then 320 else 800,
			headingSize = if phone then 24 else 48,
			textSize = if phone then 13 else 22,
			phone = phone,
			onBuy = function(key: string)
				print(`ShopPassesPanel.story: buy {key}`)
			end,
		}),
	})
end)
