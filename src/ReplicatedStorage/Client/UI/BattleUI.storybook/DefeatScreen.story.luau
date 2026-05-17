local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)
local BattleUI = require(script.Parent.Parent.BattleUI)

return function(target)
	local defeatedAlly = {
		itemType = "Hero",
		currentHp = 0,
		maxHp = 100,
		statusEffects = {},
		userId = 12345,
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
		allies = { defeatedAlly },
		enemies = mockEnemies,
		battleResult = "DEFEAT",
		battleLog = { 
			"Battle started!",
			"Hero used Strike!",
			"Slime used Tackle!",
			"Hero fainted!",
			"Defeat..."
		},
	})

	local handle = Roact.mount(element, target)
	
	return function()
		Roact.unmount(handle)
	end
end
