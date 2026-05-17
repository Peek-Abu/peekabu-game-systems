--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

--[=[
	Network events for battle system communication between client and server.
	@class BattleEvents
]=]
return ByteNet.defineNamespace("Battle", function()
	return {
		packets = {
			--[=[
				Server prompts a player to select an action (move, item, switch).
				Sent from server to client when it's the player's turn.
				@prop PromptAction ByteNetPacket
			]=]
			PromptAction = ByteNet.definePacket({
				name = "PromptAction",
				value = ByteNet.struct({
					battleId = ByteNet.string,
					battlerIndex = ByteNet.uint8,
					availableMoves = ByteNet.array(ByteNet.string),
					timeLimit = ByteNet.float32, -- seconds to respond
				}),
			}),
			
			--[=[
				Server prompts a player to perform a QTE/reaction (parry, dodge, timing).
				Sent from server to client when an interactive window opens.
				@prop PromptReaction ByteNetPacket
			]=]
			PromptReaction = ByteNet.definePacket({
				name = "PromptReaction",
				value = ByteNet.struct({
					reactionType = ByteNet.string, -- "Parry", "Dodge", "Timing", "Rhythm"
					duration = ByteNet.float32, -- window duration in seconds
					difficulty = ByteNet.uint8, -- 1-5 difficulty level
					metadata = ByteNet.string, -- JSON-encoded additional data
				}),
			}),

			--[=[
				Client submits their chosen action to the server.
				Sent from client to server in response to PromptAction.
				@prop SubmitAction ByteNetPacket
			]=]
			SubmitAction = ByteNet.definePacket({
				name = "SubmitAction",
				value = ByteNet.struct({
					actionType = ByteNet.string, -- "move", "item", "switch", "flee"
					moveName = ByteNet.string, -- move name if actionType is "move"
					targetIndex = ByteNet.uint8, -- target battler index
				}),
			}),

			--[=[
				Client submits a QTE/reaction result to the server.
				Sent from client to server during an interactive window.
				@prop SubmitReaction ByteNetPacket
			]=]
			SubmitReaction = ByteNet.definePacket({
				name = "SubmitReaction",
				value = ByteNet.struct({
					reactionType = ByteNet.string, -- must match the prompted type
					timingDelta = ByteNet.float32, -- time offset from perfect timing
					accuracy = ByteNet.float32, -- 0.0 to 1.0 for rhythm/osu games
					inputSequence = ByteNet.string, -- JSON-encoded input data
				}),
			}),
			
			--[=[
				Server broadcasts battle state updates to all participants.
				Sent from server to clients when battle state changes.
				@prop BattleStateUpdate ByteNetPacket
			]=]
			BattleStateUpdate = ByteNet.definePacket({
				name = "BattleStateUpdate",
				value = ByteNet.struct({
					battleId = ByteNet.string,
					turnCount = ByteNet.uint16,
					status = ByteNet.string, -- "IDLE", "PROMPTING_ACTION", "RESOLVING_ACTION", etc.
					battlerStates = ByteNet.string, -- JSON-encoded array of battler states
				}),
			}),
			
				--[=[
				Server announces a move is starting (BEFORE damage is calculated).
				Sent from server to clients so they can begin playing the attack animation.
				@prop BattleMoveStarted ByteNetPacket
			]=]
			BattleMoveStarted = ByteNet.definePacket({
				name = "BattleMoveStarted",
				value = ByteNet.struct({
					battleId = ByteNet.string,
					actorIndex = ByteNet.uint8,
					moveName = ByteNet.string,
					targetIndex = ByteNet.uint8,
					targetType = ByteNet.optional(ByteNet.string),
					animationDuration = ByteNet.float32,
				}),
			}),

			--[=[
				Server notifies clients of a battle action being executed.
				Sent from server to clients when an action is performed (AFTER damage calculated).
				@prop BattleActionExecuted ByteNetPacket
			]=]
			BattleActionExecuted = ByteNet.definePacket({
				name = "BattleActionExecuted",
				value = ByteNet.struct({
					battleId = ByteNet.string,
					actorIndex = ByteNet.uint8,
					actionType = ByteNet.string,
					moveName = ByteNet.string,
					targetIndex = ByteNet.uint8,
					targetType = ByteNet.optional(ByteNet.string), -- "enemy" | "self" | "allEnemies" etc.
					hit = ByteNet.optional(ByteNet.bool),
					damage = ByteNet.optional(ByteNet.uint16),
					healing = ByteNet.optional(ByteNet.uint16),
					statusApplied = ByteNet.optional(ByteNet.string),
					qteResult = ByteNet.optional(ByteNet.string), -- "PerfectDodge" | "GoodDodge" | "PerfectParry" | "GoodParry" | nil
					result = ByteNet.string, -- JSON-encoded result data
				}),
			}),
			
			--[=[
				Server broadcasts a battle log entry to all participants.
				Used for status effects, buffs, passive triggers, and other notable events.
				@prop BattleLog ByteNetPacket
			]=]
			BattleLog = ByteNet.definePacket({
				name = "BattleLog",
				value = ByteNet.struct({
					battleId = ByteNet.string,
					message = ByteNet.string,
					category = ByteNet.string, -- "status" | "buff" | "passive" | "info"
				}),
			}),

			--[=[
				Server notifies clients that the battle has ended.
				Sent from server to clients when battle concludes.
				@prop BattleEnd ByteNetPacket
			]=]
			BattleEnd = ByteNet.definePacket({
				name = "BattleEnd",
				value = ByteNet.struct({
					battleId = ByteNet.string,
					result = ByteNet.string, -- "VICTORY", "DEFEAT", "DRAW", "FLEE"
					rewards = ByteNet.string, -- JSON-encoded reward data
				}),
			}),
		},
		queries = {},
		structs = {},
	}
end)
