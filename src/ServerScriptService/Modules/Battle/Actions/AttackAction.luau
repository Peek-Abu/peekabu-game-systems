--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Action = require(script.Parent.Action)
local BattleModifiers = require(ServerScriptService.Modules.Battle.Base.BattleModifiers)
local BattleAnimationData = require(ReplicatedStorage.Shared.Data.BattleAnimationData)

local AttackAction = {}
AttackAction.__index = AttackAction
setmetatable(AttackAction, Action)

function AttackAction.new(attacker: any, defender: any, move: any)
	local self = setmetatable(Action.new(), AttackAction)
	self.attacker = attacker
	self.defender = defender
	self.move = move
	self.cancelled = false
	self.priority = move.priority or 0
	return self
end

function AttackAction:execute(battleSession: any)
	self.battle = battleSession

	if not self.attacker:isAlive() then
		return
	end

	local targetType = self.move.target:type()
	local defenderHpBefore = self.defender.currentHp
	local attackerHpBefore = self.attacker.currentHp

	self.battle.events:fire("BeforeAttack", self)
	if self.cancelled then
		return
	end

	-- Announce the move BEFORE effects fire so log ordering is correct
	if targetType == "enemy" then
		self.battle.events:fire("BattleLog", {
			message = `{self.attacker.itemType} used {self.move.name} on {self.defender.itemType}!`,
			category = "action",
		})
	else
		self.battle.events:fire("BattleLog", {
			message = `{self.attacker.itemType} used {self.move.name}!`,
			category = "action",
		})
	end

	-- ── Phase 2: Announce MoveStarted so client can begin animation ──────
	local charId = self.attacker.characterId or ""
	local animDuration = BattleAnimationData.getAnimationDuration(charId, self.move.name)
	local damageTime = BattleAnimationData.getDamageTime(charId, self.move.name)
	local moveStartTime = os.clock()

	self.battle.events:fire("MoveStarted", {
		actor = self.attacker,
		target = targetType ~= "self" and self.defender or nil,
		moveName = self.move.name,
		targetType = targetType,
		animationDuration = animDuration,
	})

	-- ══════════════════════════════════════════════════════════════════════
	-- Async QTE system: spawn all QTE windows at their timeline times.
	-- They run concurrently. The server waits until damageTime, then
	-- collects all results and applies modifiers before executing damage.
	-- ══════════════════════════════════════════════════════════════════════

	-- Shared result storage (written by async tasks, read after damageTime wait)
	local defenderQteResult: string? = nil
	local attackerQteResults: { { result: string, bonusMultiplier: number? } } = {}

	-- ── Attacker QTE windows (build-up phase, fires early in animation) ──
	local atkReactions = self.move.attackerReactions
	if atkReactions and self.attacker.userId then
		for i, atkR in atkReactions do
			task.spawn(function()
				-- Wait until the specified timeline time
				local elapsed = os.clock() - moveStartTime
				local waitUntil = (atkR.time or 0.3) - elapsed
				if waitUntil > 0.01 then task.wait(waitUntil) end

				local atkFinished = false
				local atkResult = "Miss"

				self.battle:openInteractiveWindow(
					self.attacker.userId,
					atkR.type or "Timing",
					self,
					function(result: string, _timeDelta: number)
						atkResult = result
						atkFinished = true
					end
				)

				-- Wait for result (window duration + small buffer)
				local waited = 0
				local windowDuration = atkR.duration or 0.4
				while not atkFinished and waited < (windowDuration + 0.5) do
					task.wait(0.05)
					waited += 0.05
				end

				attackerQteResults[i] = {
					result = atkResult,
					bonusMultiplier = atkR.bonusMultiplier or 1.25,
				}
			end)
		end
	end

	-- ── Defender QTE window (near damage, fires close to impact) ─────────
	-- Multiple types available: client picks ONE. Server opens window with
	-- the available types; validates submission matches one of them.
	local reactions = self.move.reactions
	local hasPerHit = reactions and #reactions > 0 and reactions[1].perHit
	if reactions and not hasPerHit and self.defender and self.defender.userId
		and (targetType == "enemy" or targetType == "allEnemies" or targetType == "allAllies") then
		task.spawn(function()
			-- Use the earliest time from available reactions
			local windowTime = math.huge
			local windowDuration = 0.5
			local availableTypes: { string } = {}
			for _, r in reactions do
				if r.time and r.time < windowTime then windowTime = r.time end
				if r.duration and r.duration > windowDuration then windowDuration = r.duration end
				table.insert(availableTypes, r.type)
			end
			if windowTime == math.huge then windowTime = damageTime - 0.5 end

			-- Wait until the specified timeline time
			local elapsed = os.clock() - moveStartTime
			local waitUntil = windowTime - elapsed
			if waitUntil > 0.01 then task.wait(waitUntil) end

			local reactionFinished = false
			local reactionResult = "Miss"

			-- Open window with first available type; client knows all types via prompt
			self.battle:openInteractiveWindow(
				self.defender.userId,
				availableTypes, -- pass array of available types
				self,
				function(result: string, _timeDelta: number)
					reactionResult = result
					reactionFinished = true
				end
			)

			-- Wait for result
			local waited = 0
			while not reactionFinished and waited < (windowDuration + 0.5) do
				task.wait(0.05)
				waited += 0.05
			end

			defenderQteResult = reactionResult
		end)
	end

	-- ── Pass per-hit reaction config to context for Combo moves ──────────
	if reactions and hasPerHit then
		self._perHitReactions = reactions
	end

	-- ── Wait for animation to reach the damage frame ────────────────────
	-- QTEs run async above, so we just wait the full damageTime from start.
	local elapsed = os.clock() - moveStartTime
	local remainingWait = damageTime - elapsed
	if remainingWait > 0.05 then
		task.wait(remainingWait)
	end

	-- ── Collect QTE results and apply modifiers ─────────────────────────
	-- Defender QTE
	if defenderQteResult then
		if defenderQteResult == "PerfectDodge" or defenderQteResult == "GoodDodge" then
			-- Dodge cancels the entire hit (damage + all effects)
			BattleModifiers.push(self, "cancelHit", true, "DefenderQTE")
			self.battle.events:fire("BattleLog", {
				message = `{self.defender.itemType} dodged the attack!`,
				category = "action",
			})
		elseif defenderQteResult == "PerfectParry" or defenderQteResult == "GoodParry" then
			BattleModifiers.push(self, "cancelHit", true, "DefenderQTE")
			self.battle.events:fire("BattleLog", {
				message = `{self.defender.itemType} parried the attack!`,
				category = "action",
			})
		end
		self.qteResult = defenderQteResult
	end

	-- Attacker QTEs (any non-miss gives the bonus)
	for _, atkResult in attackerQteResults do
		if atkResult.result ~= "Miss" then
			BattleModifiers.push(self, "damageMultiplier", atkResult.bonusMultiplier, "AttackerQTE")
		end
	end
	if #attackerQteResults > 0 then
		self.attackerQteResult = attackerQteResults[1].result
	end

	-- ── Execute the move (damage calculation happens here) ───────────────
	self.move:execute(self)

	self.battle.events:fire("AfterMove", self)
	local damageDealt = math.max(0, defenderHpBefore - self.defender.currentHp)
	local healingDone = math.max(0, self.attacker.currentHp - attackerHpBefore)

	self.battle.events:fire("ActionExecuted", {
		actor = self.attacker,
		target = targetType ~= "self" and self.defender or nil,
		moveName = self.move.name,
		targetType = targetType,
		hit = self.hit,
		damage = damageDealt,
		healing = healingDone,
		statusApplied = self.statusApplied,
		qteResult = self.qteResult,
	})
end

return AttackAction
