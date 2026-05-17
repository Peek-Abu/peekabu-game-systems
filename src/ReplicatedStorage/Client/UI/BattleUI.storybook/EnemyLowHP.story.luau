local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)
local BattleUI = require(script.Parent.Parent.BattleUI)

return function(target)
	local mockAllies = {
		{
			itemType = "Hero",
			currentHp = 80,
			maxHp = 100,
			statusEffects = {},
			userId = 12345,
		},
	}

	local mockEnemiesLowHp = {
		{
			itemType = "Slime",
			currentHp = 5,
			maxHp = 60,
			statusEffects = {},
			userId = nil,
		},
	}

	local element = Roact.createElement(BattleUI, {
		storyMode = true,
		isInBattle = true,
		allies = mockAllies,
		enemies = mockEnemiesLowHp,
		isPromptingAction = true,
		availableMoves = { "Strike", "Thunderbolt" },
		battleLog = { 
			"Battle started!", 
			"Hero used Strike!",
			"Slime used Tackle!",
			"Hero used Thunderbolt!",
			"Choose your move!"
		},
	})

	local handle = Roact.mount(element, target)
	
	return function()
		Roact.unmount(handle)
	end
end
