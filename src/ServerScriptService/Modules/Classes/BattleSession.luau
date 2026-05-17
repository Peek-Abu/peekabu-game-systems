--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BattleTypes = require(ReplicatedStorage.Shared.Types.BattleTypes)

local EventBus = require(ServerScriptService.Modules.Classes.EventBus)
local ActionAgenda = require(ServerScriptService.Modules.Classes.ActionAgenda)
local StatusEffectRegistry = require(ServerScriptService.Modules.Battle.StatusEffectRegistry)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

local log = Logger.new("BattleSession")

--[=[
	Manages a battle session using a continuous Active Time Battle (ATB) system.
	
	## ATB System Overview
	
	The ActionAgenda is built ONCE at battle start and never reset. Each battler
	is rescheduled after acting (nextActionTime += interval), so the queue runs
	indefinitely until the battle ends.
	
	**Speed determines action frequency:**
	- Battler with speed 200 acts twice as often as speed 100
	- Action ratio for speeds 200:150:100 → 4:3:2 over time
	- Example 9-action cycle: A, B, A, C, B, A, A, B, C (then repeats)
	
	## Per-Battler Events
	
	- **BattlerTurnStart**: Fired before a battler acts (start-of-turn effects)
	- **BattlerTurnEnd**: Fired after a battler acts (status ticks, buff expiry)
	- Both carry `{ battler, battle }` so listeners can filter by battler
	- Both fire even when a battler is paralyzed and skips their action
	
	## Interactive Combat
	
	Supports QTE/rhythm game mechanics via `openInteractiveWindow()`:
	- Parry/Dodge reactions with timing windows
	- Can be extended for rhythm-based attacks, OSU-style minigames, etc.
	
	@class BattleSession
]=]

local BattleSession = {}
BattleSession.__index = BattleSession

-- ── Constants ─────────────────────────────────────────────────────────────────

-- Seconds the client has to react (parry / dodge) when a hit is incoming
local INTERACTIVE_WINDOW_DURATION = 0.5

-- ── Constructor ───────────────────────────────────────────────────────────────

function BattleSession.new(allies: { any }, enemies: { any })
	local self = setmetatable({}, BattleSession)
	self.allies = allies
	self.enemies = enemies
	self.turnCount = 0
	self.status = "IDLE" :: BattleTypes.BattleStatus

	self.events = EventBus.new()
	self.globalEffects = {}
	self.team1Effects = {}
	self.team2Effects = {}

	-- Continuous ATB agenda — built once, rescheduled after each action
	self._agenda = ActionAgenda.new()

	-- Delay (seconds) after each action resolves before advancing to the next turn.
	-- Gives the client time to play animations before the next prompt/action.
	self._ACTION_RESOLVE_DELAY = 2.0

	-- Reaction tracking (parry / dodge)
	self.recentReactions = {} :: { [number]: { id: string, time: number } }

	-- Interactive window state
	self._interactiveWindow = nil :: { userId: number, deadline: number, resolve: () -> () }?

	-- Pending callback: called when the currently-prompted player submits
	self._pendingPlayerCallback = nil :: ((action: any) -> ())?
	self._promptedUserId = nil :: number?

	self:_initInternalListeners()

	return self
end

-- ── Battle lifecycle ─────────────────────────────────────────────────────────

--- Start the battle. Call this ONCE after creating the session.
--- The agenda runs continuously — there is no reset.
function BattleSession:startBattle()
	self.recentReactions = {}
	self.status = "BUILDING_AGENDA"
	self.turnCount = 0

	-- Register passive abilities for all battlers
	self:_registerPassives()

	-- Register event-driven status effects for all battlers
	self:_registerStatusEffects()

	-- Fire BattleStart passives
	self.events:fire("BattleStart", self)

	-- Build the continuous priority queue ONCE
	self._agenda:build(self.allies, self.enemies)
	log:debug(`Battle started! ${self._agenda:debugPreview(10)}`)

	self:_advanceAgenda()
end

--- Internal: process the next entry in the continuous ATB queue.
function BattleSession:_advanceAgenda()
	if self._agenda:isEmpty() then
		-- Should only happen if all battlers fainted mid-action
		self:checkBattleEnd()
		return
	end

	if self:checkBattleEnd() then return end

	local entry = self._agenda:next()
	if not entry then return end

	local battler = entry.battler
	self.turnCount += 1

	-- Skip fainted battlers — remove from queue, don't reschedule
	if not battler:isAlive() then
		log:debug(`{battler.itemType} skipped (fainted) — removed from queue`)
		self:_advanceAgenda()
		return
	end
	-- Per-battler turn start (for start-of-turn effects)
	self.events:fire("BattlerTurnStart", { battler = battler, battle = self })

	-- Check if status effects prevent this battler from acting (e.g. Paralysis)
	if StatusEffectRegistry.preventsAction(battler) then
		log:debug(`{battler.itemType} is paralyzed and cannot act!`)
		self.events:fire("BattleLog", {
			message = `{battler.itemType} is paralyzed and can't move!`,
			category = "status",
		})
		-- Still fire per-battler events so status ticks (burn damage, buff expiry, etc.)
		self.events:fire("BattlerTurnEnd", { battler = battler, battle = self })
		self._agenda:reschedule(battler)
		task.delay(self._ACTION_RESOLVE_DELAY, function()
			if self.status == "ENDED" then return end
			self:_advanceAgenda()
		end)
		return
	end

	-- Is this battler player-controlled?
	if battler.userId then
		self:_promptPlayer(battler, entry)
	else
		self:_resolveNpcSlot(battler, entry)
	end
end

-- ── Player prompt ─────────────────────────────────────────────────────────────

--- Prompt a specific player to choose an action for their current slot.
function BattleSession:_promptPlayer(battler: any, slot: any)
	self.status = "PROMPTING_ACTION"
	self._promptedUserId = battler.userId

	log:debug(`Waiting for player {battler.userId} ({battler.itemType}) to act…`)

	-- Notify the client (via event; actual remote hookup happens in BattleServiceServer)
	self.events:fire("PromptAction", {
		battle = self,
		battler = battler,
		slot = slot,
	})

	-- _pendingPlayerCallback is set here and consumed by submitAction()
	self._pendingPlayerCallback = function(action: any)
		self._promptedUserId = nil
		self._pendingPlayerCallback = nil
		self:_executeAction(action, battler)
	end
end

-- ── NPC AI ────────────────────────────────────────────────────────────────────

--- Automatically choose and execute an action for an NPC battler.
function BattleSession:_resolveNpcSlot(battler: any, _slot: any)
	self.status = "RESOLVING_ACTION"

	local AttackAction = require(script.Parent.Parent.Battle.Actions.AttackAction)
	local MoveRegistry = require(script.Parent.Parent.Battle.MoveRegistry)

	-- Find a random alive opponent
	local opponentSide = if table.find(self.allies, battler) then self.enemies else self.allies
	local aliveOpponents = {}
	for _, opp in opponentSide do
		if opp:isAlive() then
			table.insert(aliveOpponents, opp)
		end
	end

	if #aliveOpponents == 0 then
		-- No live targets — skip
		self:_advanceAgenda()
		return
	end

	-- Randomly select a move from available moves
	local moveName = "Tackle" -- fallback
	if battler.moves and #battler.moves > 0 then
		moveName = battler.moves[math.random(1, #battler.moves)]
	end

	local move = MoveRegistry.getMove(moveName) or MoveRegistry.getMove("Tackle")

	-- Resolve target via the move's Target class (no choiceIndex = NPC AI auto-pick)
	local target = move.target:resolve({ attacker = battler, battle = self })
	if not target then
		self:_advanceAgenda()
		return
	end

	local action = AttackAction.new(battler, target, move)
	self:_executeAction(action, battler)
end

-- ── Action execution ──────────────────────────────────────────────────────────

--- Execute a resolved action, reschedule the battler, then advance the agenda.
function BattleSession:_executeAction(action: any, battler: any)
	self.status = "RESOLVING_ACTION"

	-- Execute the action (fires BeforeAttack, BeforeHit, etc.)
	action:execute(self)

	-- Per-battler turn end: status ticks, buff expiry, transformation countdowns
	self.events:fire("BattlerTurnEnd", { battler = battler, battle = self })

	-- Reschedule the battler in the continuous queue
	self._agenda:reschedule(battler)

	-- Wait for client to finish playing the action animation before advancing
	task.delay(self._ACTION_RESOLVE_DELAY, function()
		if self.status == "ENDED" then return end
		self:_advanceAgenda()
	end)
end

-- ── Public action submission ──────────────────────────────────────────────────

--- Called by BattleServiceServer when a player submits their action.
--- Only accepts the action if it is this player's turn to act.
function BattleSession:submitAction(userId: number, action: any)
	if self._promptedUserId ~= userId then
		warn(`UserId {userId} submitted an action but it is not their turn (waiting for {tostring(self._promptedUserId)})`)
		return
	end

	if not self._pendingPlayerCallback then
		warn(`No pending callback for userId {userId}`)
		return
	end

	log:debug(`UserId {userId} submitted action.`)
	local callback = self._pendingPlayerCallback
	callback(action)
end

-- ── Interactive window (parry / dodge) ────────────────────────────────────────

--- Open a timed reaction window for a player.
--- Fires "PromptReaction" so the client can display the UI.
---
--- windowType: string | { string } — single type or array of available types.
---   If array, client shows all options and player picks one.
--- onResult: function(result: "PerfectParry"|"GoodParry"|"PerfectDodge"|"GoodDodge"|"Miss", timeDelta: number)
function BattleSession:openInteractiveWindow(
	userId: number,
	windowType: string | { string },
	hitContext: any,
	onResult: (result: string, timeDelta: number) -> ()
)
	local openTime = os.clock()

	-- Normalize to array of available types
	local availableTypes: { string }
	if type(windowType) == "table" then
		availableTypes = windowType :: { string }
	else
		availableTypes = { windowType :: string }
	end

	-- Clear any stale/pre-submitted reactions so they can't be reused
	self.recentReactions[userId] = nil

	-- Mark this window as active so submitReaction only accepts during it
	if not self._activeWindows then self._activeWindows = {} end
	self._activeWindows[userId] = { 
		availableTypes = availableTypes, 
		openTime = openTime,
		onResult = onResult -- Store callback for immediate reaction
	}

	-- Notify client (send all available types so client can show multiple buttons)
	self.events:fire("PromptReaction", {
		userId = userId,
		windowType = availableTypes[1], -- primary type for backward compat
		availableTypes = availableTypes, -- full list of available types
		duration = INTERACTIVE_WINDOW_DURATION,
		battle = self,
		hitContext = hitContext,
	})

	-- Wait for reaction or timeout
	task.delay(INTERACTIVE_WINDOW_DURATION, function()
		-- Close the active window
		local activeWindow = self._activeWindows and self._activeWindows[userId]
		if self._activeWindows then self._activeWindows[userId] = nil end

		-- If already processed by immediate reaction, don't call again
		if activeWindow and activeWindow.processed then
			return
		end

		local reaction = self.recentReactions[userId]
		local timeDelta = INTERACTIVE_WINDOW_DURATION -- default = missed
		local submittedType: string? = nil

		if reaction then
			-- Check if the submitted type is one of the available types
			local isValidType = false
			for _, t in availableTypes do
				if t == reaction.id then isValidType = true; break end
			end

			if isValidType then
				timeDelta = reaction.time - openTime
				submittedType = reaction.id
				self.recentReactions[userId] = nil

				-- Reject negative timeDelta (pre-submitted before window opened)
				if timeDelta < 0 then
					log:warn(`Rejected pre-submitted reaction from userId {userId} (timeDelta={timeDelta})`)
					timeDelta = INTERACTIVE_WINDOW_DURATION
					submittedType = nil
				end
			end
		end

		-- Classify result based on the type the player actually chose
		local result: string
		if timeDelta >= INTERACTIVE_WINDOW_DURATION or not submittedType then
			result = "Miss"
		elseif submittedType == "Parry" then
			result = if timeDelta < 0.2 then "PerfectParry" else "GoodParry"
		elseif submittedType == "Dodge" then
			result = if timeDelta < 0.2 then "PerfectDodge" else "GoodDodge"
		else
			-- Generic QTE types (Timing, Mash, etc): Perfect or Good
			result = if timeDelta < 0.2 then `Perfect{submittedType}` else `Good{submittedType}`
		end

		onResult(result, timeDelta)
	end)
end

-- ── Reaction submission ───────────────────────────────────────────────────────

function BattleSession:submitReaction(userId: number, reactionId: string)
	-- Only accept reactions when an active window is open for this player
	if not self._activeWindows or not self._activeWindows[userId] then
		log:warn(`Rejected reaction from userId {userId}: no active window`)
		return
	end

	-- Validate the submitted type is one of the available types for this window
	local activeWindow = self._activeWindows[userId]
	local isValid = false
	for _, t in activeWindow.availableTypes do
		if t == reactionId then isValid = true; break end
	end
	if not isValid then
		log:warn(`Rejected reaction from userId {userId}: type "{reactionId}" not in available types`)
		return
	end

	self.recentReactions[userId] = {
		id = reactionId,
		time = os.clock(),
	}
	log:debug(`Reaction "{reactionId}" recorded for userId {userId}`)
	
	-- Call onResult immediately with the reaction result
	local activeWindow = self._activeWindows[userId]
	if activeWindow and activeWindow.onResult then
		local timeDelta = os.clock() - activeWindow.openTime
		
		-- Classify result based on the type the player actually chose
		local result: string
		if reactionId == "Parry" then
			result = if timeDelta < 0.2 then "PerfectParry" else "GoodParry"
		elseif reactionId == "Dodge" then
			result = if timeDelta < 0.2 then "PerfectDodge" else "GoodDodge"
		else
			-- Generic QTE types (Timing, Mash, etc): Perfect or Good
			result = if timeDelta < 0.2 then `Perfect{reactionId}` else `Good{reactionId}`
		end
		
		log:debug(`BattleSession immediate onResult: {result}, timeDelta={timeDelta}`)
		activeWindow.onResult(result, timeDelta)
		
		-- Mark as processed so we don't call again on timeout
		activeWindow.processed = true
	end
	
	self.events:fire("ReactionSubmitted", {
		userId = userId,
		id = reactionId,
	})
end

function BattleSession:getReaction(userId: number): { id: string, time: number }?
	return self.recentReactions[userId]
end

-- ── Battle-end check ──────────────────────────────────────────────────────────

function BattleSession:checkBattleEnd(): boolean
	local alliesAlive = false
	for _, ally in self.allies do
		if ally:isAlive() then
			alliesAlive = true
			break
		end
	end

	local enemiesAlive = false
	for _, enemy in self.enemies do
		if enemy:isAlive() then
			enemiesAlive = true
			break
		end
	end

	-- Allies defeated - enemies win
	if not alliesAlive then
		self.status = "ENDED"
		self.events:fire("BattleEnd", {
			result = "ENDED",
			winners = self.enemies, -- Enemy side won
			losers = self.allies, -- Ally side lost
			battle = self,
		})
		log:debug("Battle ended: Allies defeated!")
		return true
	end

	-- Enemies defeated - allies win
	if not enemiesAlive then
		self.status = "ENDED"
		self.events:fire("BattleEnd", {
			result = "ENDED",
			winners = self.allies, -- Ally side won
			losers = self.enemies, -- Enemy side lost
			battle = self,
		})
		log:debug("Battle ended: Enemies defeated!")
		return true
	end

	return false
end

-- ── State snapshot ────────────────────────────────────────────────────────────

function BattleSession:getState(): BattleTypes.BattleState
	local allyStates = {}
	for _, ally in self.allies do
		table.insert(allyStates, ally:getState())
	end

	local enemyStates = {}
	for _, enemy in self.enemies do
		table.insert(enemyStates, enemy:getState())
	end

	return {
		status = self.status,
		turnCount = self.turnCount,
		allies = allyStates,
		enemies = enemyStates,
	}
end

-- ── Agenda helpers (for effects) ──────────────────────────────────────────────

--- Remove the next agenda slot for a battler (stagger mechanic from perfect parry).
function BattleSession:removeNextSlotFor(battler: any): boolean
	local removed = self._agenda:removeNextSlotFor(battler)
	if removed then
		log:debug(`{battler.itemType}'s next slot was removed (staggered)!`)
	end
	return removed
end

-- ── Passive Hook Registration ────────────────────────────────────────────────

--- Register passive abilities for all battlers in the battle.
--- Passives subscribe to EventBus events based on their `trigger` field.
--- `trigger` can be a single string or an array of strings for multi-trigger passives.
function BattleSession:_registerPassives()
	local allBattlers = {}
	for _, b in self.allies do table.insert(allBattlers, b) end
	for _, b in self.enemies do table.insert(allBattlers, b) end

	for _, battler in allBattlers do
		local passive = battler.passive
		if not passive or not passive.trigger or not passive.effect then continue end

		-- Support single string or array of triggers
		local triggers: { string }
		if type(passive.trigger) == "table" then
			triggers = passive.trigger
		else
			triggers = { passive.trigger }
		end

		for _, trigger in triggers do
			self:_subscribePassiveTrigger(battler, passive, trigger)
		end
	end
end

--- Subscribe a single trigger for a battler's passive.
--- Passives receive a wrapper context with `battler` and `trigger` set,
--- while reads/writes for everything else delegate to the original context.
function BattleSession:_subscribePassiveTrigger(battler: any, passive: any, trigger: string)
	-- Build a thin wrapper so passives see battler/trigger without mutating
	-- the shared AttackAction. Writes (e.g. BattleModifiers.push) pass through
	-- to the original context so effects downstream can read them.
	local function wrapContext(context: any): any
		local wrapper = { battler = battler, trigger = trigger }
		setmetatable(wrapper, {
			__index = context,
			__newindex = context,
		})
		return wrapper
	end

	if trigger == "BattleStart" then
		self.events:subscribe("BattleStart", function(battle)
			if battler:isAlive() then
				passive.effect({ battler = battler, attacker = battler, defender = battler, battle = battle, trigger = trigger })
			end
		end)

	elseif trigger == "BattlerTurnStart" then
		self.events:subscribe("BattlerTurnStart", function(data)
			if data.battler == battler and battler:isAlive() then
				passive.effect({ battler = battler, attacker = battler, defender = battler, battle = data.battle, trigger = trigger })
			end
		end)

	elseif trigger == "BeforeAccuracyCheck" then
		self.events:subscribe("BeforeAccuracyCheck", function(context)
			if context.defender == battler or context.attacker == battler then
				passive.effect(wrapContext(context))
			end
		end)

	elseif trigger == "BeforeAttack" then
		self.events:subscribe("BeforeAttack", function(context)
			if context.attacker == battler then
				passive.effect(wrapContext(context))
			end
		end)

	elseif trigger == "BeforeHit" then
		self.events:subscribe("BeforeHit", function(context)
			if context.defender == battler or context.attacker == battler then
				passive.effect(wrapContext(context))
			end
		end)

	elseif trigger == "OnDamaged" then
		self.events:subscribe("AfterHit", function(context)
			if context.defender == battler and (battler:isAlive() or battler.currentHp <= 0) then
				passive.effect(wrapContext(context))
			end
		end)

	elseif trigger == "OnHit" then
		self.events:subscribe("AfterHit", function(context)
			if context.attacker == battler and battler:isAlive() then
				passive.effect(wrapContext(context))
			end
		end)

	elseif trigger == "OnKill" then
		self.events:subscribe("AfterHit", function(context)
			if context.attacker == battler and context.defender and not context.defender:isAlive() then
				passive.effect(wrapContext(context))
			end
		end)

	elseif trigger == "BattlerTurnEnd" then
		self.events:subscribe("BattlerTurnEnd", function(data)
			if data.battler == battler and battler:isAlive() then
				passive.effect({ battler = battler, attacker = battler, defender = battler, battle = data.battle, trigger = trigger })
			end
		end)
	end
end

-- ── Status Effect Registration ──────────────────────────────────────────────

--- Register event-driven status effects for all battlers.
--- Each status subscribes to BattlerTurnEnd and ticks on the affected battler's turn.
function BattleSession:_registerStatusEffects()
	local allBattlers = {}
	for _, b in self.allies do table.insert(allBattlers, b) end
	for _, b in self.enemies do table.insert(allBattlers, b) end

	for _, battler in allBattlers do
		StatusEffectRegistry.registerBattlerStatuses(battler, self)
	end
end

--- Register a newly-applied status mid-battle (called from Effect.luau).
function BattleSession:registerNewStatus(battler: any, statusName: string)
	StatusEffectRegistry.registerStatus(battler, statusName, self)
end

-- ── Internal Event Handlers ──────────────────────────────────────────────────

--- Sets up internal listeners for battle events that should trigger passives.
function BattleSession:_initInternalListeners()
	-- Status damage (Burn, Poison, etc.) should trigger "OnDamaged" passives (e.g. Goku's Zenkai)
	self.events:subscribe("StatusDamage", function(data)
		local battler = data.battler
		if not battler then return end

		-- Fire "AfterHit" logic which maps to "OnDamaged" in _subscribePassiveTrigger
		self.events:fire("AfterHit", {
			attacker = battler, -- For status damage, we treat defender as attacker (self-damage source)
			defender = battler,
			battle = self,
			damage = data.damage,
			isStatusDamage = true,
		})
	end)
end

export type BattleSession = typeof(setmetatable({} :: any, BattleSession))

return BattleSession
