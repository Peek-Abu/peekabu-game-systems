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

	local mockEnemies = {
		{
			itemType = "Slime",
			currentHp = 45,
			maxHp = 60,
			statusEffects = {},
			userId = nil,
		},
	}

	local element = Roact.createElement(BattleUI, {
		storyMode = true,
		isInBattle = true,
		allies = mockAllies,
		enemies = mockEnemies,
		isPromptingAction = true,
		availableMoves = { "Strike", "Thunderbolt", "Protect" },
		battleLog = { "Battle started!", "Choose your move!" },
	})

	local handle = Roact.mount(element, target)
	
	return function()
		Roact.unmount(handle)
	end
end
