--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TypeConstants = require(ReplicatedStorage.Shared.Classes.Constants.TypeConstants)

export type BattleStatus = "IDLE" | "WAITING_FOR_INPUT" | "RESOLVING_TURNS" | "VICTORY" | "DEFEAT"

export type BattlerState = {
	userId: number?, -- nil if NPC
	itemType: string,
	characterId: string?,
	element: TypeConstants.ElementType,
	currentHp: number,
	maxHp: number,
	attack: number,
	defense: number,
	speed: number,
	level: number,
	statusEffects: { string },
	moves: { string },
	passive: any?,
	modelName: string?,
}

export type BattleState = {
	status: BattleStatus,
	turnCount: number,
	allies: { BattlerState },
	enemies: { BattlerState },
}

return {}
