--!strict
--[=[
	BankScene: registers the `Bank` scene — the first scene showing TWO co-visible container panels,
	which is the case `SceneRegistry` was designed around.

	Same suppression as the inventory: the mouse is freed and blur is asked for, and the HUD hides while
	it is open.

	**This is also where the panel is joined to the network**, exactly as `InventoryScene` is: the panel
	takes its transfer requests as a prop and requires no service, so the ByteNet-backed
	`BankServiceClient` is required HERE, at boot-time registration, and never in the render tree. That
	keeps the panel renderable in UI Labs, which has no server for ByteNet to wait on.

	The world trigger — a banker NPC or a proximity prompt — is world content and lands with that pass.
	Until then the scene opens on a keybind (see `UIServiceClient`); nothing about the scene changes when
	the real trigger arrives, since it pushes this same scene.

	@class BankScene
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local BankPanel = require(ReplicatedStorage.Client.UI.React.Screens.Bank.BankPanel)
local BankServiceClient = require(ReplicatedStorage.Client.Features.Bank.BankServiceClient)

local e = React.createElement

local BankScene = {
	SCENE = "Bank",
}

-- Plain functions over the service's colon methods: the panel declares what it needs to DO, not which
-- service does it.
local BANK_ACTIONS: BankPanel.BankActions = {
	depositUnique = function(uid: string)
		BankServiceClient:depositUnique(uid)
	end,
	withdrawUnique = function(uid: string)
		BankServiceClient:withdrawUnique(uid)
	end,
	depositStack = function(itemType: string)
		BankServiceClient:depositStack(itemType)
	end,
	withdrawStack = function(itemType: string)
		BankServiceClient:withdrawStack(itemType)
	end,
	depositCurrency = function(currencyType: CurrencyConstants.CurrencyType, amount: number)
		BankServiceClient:depositCurrency(currencyType, amount)
	end,
	withdrawCurrency = function(currencyType: CurrencyConstants.CurrencyType, amount: number)
		BankServiceClient:withdrawCurrency(currencyType, amount)
	end,
}

SceneRegistry.register({
	name = BankScene.SCENE,
	screens = {
		{
			layer = "Panel",
			key = "main",
			-- Wrapped rather than passed directly: a scene screen renders with no arguments.
			component = function()
				return e(BankPanel, {
					actions = BANK_ACTIONS,
					-- Remove THIS scene, not `pop`: the X belongs to the Bank, so it closes the Bank
					-- wherever it sits. `pop` closes the stack head, which is only the same thing while
					-- the Bank happens to be on top.
					onClose = function()
						SceneStack.remove(BankScene.SCENE)
					end,
				})
			end,
		},
	},
	suppress = { mouse = true, blur = true },
	hud = "hidden",
})

return BankScene
