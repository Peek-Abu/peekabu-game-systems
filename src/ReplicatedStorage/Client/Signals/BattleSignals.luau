--!strict
--[=[
	Client-side signals for battle events.
	UI components can subscribe to these signals to react to battle state changes.
	@class BattleSignals
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

local BattleSignals = {}

--[=[
	Fired when a battle starts.
	@param allies {any} -- Allied battlers
	@param enemies {any} -- Enemy battlers
]=]
BattleSignals.BattleStarted = Signal() :: Signal.Signal<{ allies: { any }, enemies: { any } }>

--[=[
	Fired when the player is prompted to select an action.
	@param battleId string -- Battle identifier
	@param availableMoves {string} -- List of available move names
	@param timeLimit number -- Time limit in seconds
]=]
BattleSignals.ActionPrompted = Signal() :: Signal.Signal<{ battleId: string, availableMoves: { string }, timeLimit: number }>

--[=[
	Fired when the player is prompted for a QTE/reaction.
	@param reactionType string -- Type of reaction (Parry, Dodge, etc.)
	@param duration number -- Duration of QTE window
	@param windowStart number -- Start of success window (0-1)
	@param windowEnd number -- End of success window (0-1)
]=]
BattleSignals.ReactionPrompted = Signal() :: Signal.Signal<{ reactionType: string, availableTypes: { string }?, duration: number, windowStart: number?, windowEnd: number? }>

--[=[
	Fired when the reaction window ends (timeout or resolved).
]=]
BattleSignals.ReactionWindowEnded = Signal() :: Signal.Signal<{}>

--[=[
	Fired when a move is announced (BEFORE damage is calculated).
	Used to start attack animations immediately.
	@param actorIndex number -- Index of the acting battler
	@param moveName string -- Name of the move used
	@param targetIndex number -- Index of the target
	@param animationDuration number -- Expected animation duration
]=]
BattleSignals.MoveStarted = Signal() :: Signal.Signal<{ actorIndex: number, moveName: string, targetIndex: number, targetType: string?, animationDuration: number }>

--[=[
	Fired when a battle action is resolved (AFTER damage calculated, QTE resolved).
	@param actorIndex number -- Index of the acting battler
	@param moveName string -- Name of the move used
	@param targetIndex number -- Index of the target
	@param user string? -- Display name of the user
]=]
BattleSignals.ActionExecuted = Signal() :: Signal.Signal<{ actorIndex: number, actionType: string?, moveName: string, targetIndex: number, user: string?, hit: boolean?, damage: number?, healing: number?, statusApplied: string? }>

--[=[
	Fired when the battle state changes.
	@param status string -- Battle status
	@param turnCount number -- Current turn number
	@param allies {any}? -- Allied battlers state
	@param enemies {any}? -- Enemy battlers state
]=]
BattleSignals.StateChanged = Signal() :: Signal.Signal<{ status: string, turnCount: number, allies: { any }?, enemies: { any }? }>

--[=[
	Fired when the server sends a battle log entry (status applied, buff, passive trigger, etc.).
	@param message string -- The log message text
	@param category string -- "status" | "buff" | "passive" | "info"
]=]
BattleSignals.BattleLog = Signal() :: Signal.Signal<{ message: string, category: string }>

--[=[
	Fired when the battle ends.
	@param result string -- "VICTORY" or "DEFEAT"
	@param rewards any? -- Battle rewards
]=]
BattleSignals.BattleEnded = Signal() :: Signal.Signal<{ result: string, rewards: any? }>

return BattleSignals
