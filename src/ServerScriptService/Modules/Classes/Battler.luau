--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BattleTypes = require(ReplicatedStorage.Shared.Types.BattleTypes)

local Battler = {}
Battler.__index = Battler

function Battler.new(config: BattleTypes.BattlerState)
	local self = setmetatable({}, Battler)
	self.userId = config.userId
	self.itemType = config.itemType
	self.characterId = config.characterId
	self.element = config.element
	self.currentHp = config.currentHp
	self.maxHp = config.maxHp
	self.attack = config.attack
	self.defense = config.defense
	self.speed = config.speed
	self.level = config.level or 50
	self.statusEffects = {}
	self.moves = config.moves
	self.passive = config.passive
	self.modelName = config.modelName -- exact workspace model name for client resolution
	self.model = nil -- server-only: live Model reference (not serialized)
	return self
end

function Battler:takeDamage(amount: number)
	self.currentHp = math.max(0, self.currentHp - amount)
end

function Battler:heal(amount: number)
	self.currentHp = math.min(self.maxHp, self.currentHp + amount)
end

function Battler:isAlive(): boolean
	return self.currentHp > 0
end

function Battler:getState(): BattleTypes.BattlerState
	return {
		userId = self.userId,
		itemType = self.itemType,
		characterId = self.characterId,
		element = self.element,
		currentHp = self.currentHp,
		maxHp = self.maxHp,
		attack = self.attack,
		defense = self.defense,
		speed = self.speed,
		level = self.level,
		statusEffects = self.statusEffects,
		moves = self.moves,
		passive = self.passive,
		modelName = self.modelName,
	}
end

export type Battler = typeof(setmetatable({} :: BattleTypes.BattlerState, Battler))

return Battler
