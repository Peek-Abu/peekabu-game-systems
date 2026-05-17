--!strict
--[=[
	BattleAnimator — Client-side animation playback engine for battles.

	Handles: track caching, battle idle loops, attack animations with
	timeline-driven events, reaction animations (hit/dodge/death),
	crossfading, and per-battle cleanup.

	Two-phase flow:
	  MoveStarted  → playAttack() starts animation + timeline scheduler
	  MoveResolved → resolveOutcome() shows damage number + defender reaction

	@class BattleAnimator
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local BattleAnimationData = require(ReplicatedStorage.Shared.Data.BattleAnimationData)

local log = Logger.new("BattleAnimator")

local BattleAnimator = {}

-- ── Signals ──────────────────────────────────────────────────────────────────
-- Other systems subscribe to these to react to animation events.

BattleAnimator.AnimationStarted = Signal()
BattleAnimator.AnimationComplete = Signal()
BattleAnimator.TimelineEvent = Signal() -- fires { event, time, ...extra fields }

-- ── State ────────────────────────────────────────────────────────────────────

local _battleJanitor = Janitor.new()
local _inBattle = false

-- Track cache: avoids loading the same animation multiple times per battle.
-- Keyed by Animator instance, value is { [animId] = AnimationTrack }.
local _trackCache: { [Animator]: { [string]: AnimationTrack } } = {}

-- Active idle tracks per model (so we can stop them on battle end or crossfade).
local _idleTracks: { [Model]: AnimationTrack } = {}

-- Pending outcome data: set by resolveOutcome, consumed by timeline "damage"/"hitReaction".
-- If the timeline event fires before data arrives, it waits briefly.
local _pendingOutcome: {
	damage: number?,
	healing: number?,
	hit: boolean?,
	qteResult: string?,
	statusApplied: string?,
	targetModel: Model?,
}? = nil

-- Active timeline cancel flag (set true to abort running timelines on cleanup).
local _timelineCancelled = false

-- Animation generation counter: incremented each playAttack call.
-- Used to prevent stale task.delay callbacks from overriding newer animations.
local _animGeneration = 0

-- Actor walk-to/walk-back state (client side)
local _actorOrigin: CFrame? = nil
-- Per-actor canonical formation CFrame. Keyed by Model so different actors never share state.
local _actorFormationMap: { [Model]: CFrame } = {}

-- ── Track Cache ──────────────────────────────────────────────────────────────

local function getAnimator(model: Model): Animator?
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	return animator
end

local function getOrLoadTrack(animator: Animator, animId: string, priority: Enum.AnimationPriority?): AnimationTrack?
	if not animId or animId == "" or animId == "rbxassetid://0" then return nil end

	local cache = _trackCache[animator]
	if not cache then
		cache = {}
		_trackCache[animator] = cache
	end
	if cache[animId] then return cache[animId] end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	anim:Destroy()
	if not ok or not track then
		log:warn(`Failed to load animation {animId}`)
		return nil
	end

	if priority then
		track.Priority = priority
	end
	cache[animId] = track
	return track
end

local function destroyAllCachedTracks()
	for animator, cache in _trackCache do
		for _, track in cache do
			track:Stop(0)
			track:Destroy()
		end
	end
	table.clear(_trackCache)
end

-- ── Idle Management ──────────────────────────────────────────────────────────

local function stopDefaultAnims(model: Model)
	local animator = getAnimator(model)
	if not animator then return end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0.15)
	end
end

function BattleAnimator.startBattleIdle(characterId: string, model: Model)
	local animId = BattleAnimationData.getBattleIdle(characterId)
	if not animId then return end

	local animator = getAnimator(model)
	if not animator then return end

	stopDefaultAnims(model)

	local track = getOrLoadTrack(animator, animId, Enum.AnimationPriority.Movement)
	if not track then return end

	track.Looped = true
	track.Priority = Enum.AnimationPriority.Idle
	track:Play(0.2)
	_idleTracks[model] = track
end

function BattleAnimator.stopBattleIdle(model: Model)
	local track = _idleTracks[model]
	if track then
		track:Stop(0.25)
		_idleTracks[model] = nil
	end
end

-- ── Camera Service Helper ────────────────────────────────────────────────────

local _cameraService: any = nil
local function getCameraService(): any
	if _cameraService then return _cameraService end
	pcall(function()
		local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)
		_cameraService = ServiceController:getService("BattleCameraServiceClient")
	end)
	return _cameraService
end

-- ── Timeline Scheduler ───────────────────────────────────────────────────────
-- Runs through timeline events sorted by time, fires signals and handles
-- camera/VFX/sound triggers. "damage" and "hitReaction" events wait for
-- _pendingOutcome if it hasn't arrived yet.

local function handleTimelineEvent(evt: any, context: { actorModel: Model?, targetModel: Model? })
	local eventType = evt.event

	-- Fire the generic signal so any system can listen
	BattleAnimator.TimelineEvent:Fire(evt)

	local camSvc = getCameraService()
	local inBattle = camSvc and camSvc:isInBattle()

	if eventType == "cameraFocus" and inBattle then
		local focusTarget = evt.target -- "attacker" | "defender" | "center"
		local distance = evt.distance or 8
		local elevation = evt.elevation or 3
		local duration = evt.duration or 0.3
		local fov = evt.fov
		local offset = evt.offset
		local rotation = evt.rotation

		-- Resolve focus position: midpoint when multiple targets, single pos otherwise
		local focusPos: Vector3?
		local function modelPos(m: Model): Vector3
			local root = m:FindFirstChild("HumanoidRootPart")
			return if root and root:IsA("BasePart") then root.Position else m:GetPivot().Position
		end

		if focusTarget == "attacker" and context.actorModel then
			focusPos = modelPos(context.actorModel)
		elseif focusTarget == "defender" then
			local models = context.targetModels
			if models and #models > 0 then
				local sum, count = Vector3.zero, 0
				for _, m in models do sum += modelPos(m); count += 1 end
				if count > 0 then focusPos = sum / count end
			end
		elseif focusTarget == "center" then
			local aPos = context.actorModel and modelPos(context.actorModel)
			local tPos = context.targetModels and context.targetModels[1] and modelPos(context.targetModels[1])
			if aPos and tPos then focusPos = (aPos + tPos) / 2
			elseif aPos then focusPos = aPos
			elseif tPos then focusPos = tPos end
		end

		if focusPos then
			if offset or rotation then
				camSvc:setCameraState("Focus")
				local ox = offset and offset.x or 0
				local oy = offset and offset.y or 0
				local oz = offset and offset.z or 0
				
				-- Use a relative base CFrame for focus calculation
				local baseCFrame = CFrame.new(focusPos)
				if focusTarget == "attacker" and context.actorModel then
					baseCFrame = context.actorModel:GetPivot()
				elseif focusTarget == "defender" and context.targetModels and context.targetModels[1] then
					baseCFrame = context.targetModels[1]:GetPivot()
				end
				
				-- Flatten orientation to XZ plane
				local look = baseCFrame.LookVector
				local flatLook = Vector3.new(look.X, 0, look.Z).Unit
				if flatLook.Magnitude < 0.1 then flatLook = Vector3.new(0, 0, -1) end
				baseCFrame = CFrame.lookAt(focusPos, focusPos + flatLook)

				local camPos = (baseCFrame * CFrame.new(ox, elevation + oy, distance + oz)).Position
				local cf = CFrame.lookAt(camPos, focusPos)
				
				if rotation then
					cf = cf * CFrame.Angles(math.rad(rotation.pitch or 0), math.rad(rotation.yaw or 0), math.rad(rotation.roll or 0))
				end
				camSvc:tweenTo(cf, duration)
			else
				-- If no offset, we still want consistent relative positioning
				local dist = distance
				local elev = elevation
				local targetModel = if focusTarget == "attacker" then context.actorModel 
									elseif focusTarget == "defender" then (context.targetModels and context.targetModels[1])
									else nil
				
				if targetModel then
					local pivot = targetModel:GetPivot()
					local look = pivot.LookVector
					local flatLook = Vector3.new(look.X, 0, look.Z).Unit
					if flatLook.Magnitude < 0.1 then flatLook = Vector3.new(0, 0, -1) end
					local baseCF = CFrame.lookAt(focusPos, focusPos + flatLook)
					local camPos = (baseCF * CFrame.new(0, elev, dist)).Position
					camSvc:tweenTo(CFrame.lookAt(camPos, focusPos), duration)
				else
					camSvc:focusOn(focusPos, distance, elevation, duration)
				end
			end
			if fov then camSvc:tweenFOV(fov, duration) end
		end
	elseif eventType == "cameraShake" and inBattle then
		camSvc:shake({ intensity = evt.intensity or 0.5, duration = evt.duration or 0.25 })

	elseif eventType == "cameraOverview" and inBattle then
		camSvc:returnToOverview(0.4)

	elseif eventType == "damage" then
		-- Damage display — handled by BattleUI listening to TimelineEvent
		-- Data comes from _pendingOutcome (set by resolveOutcome)
		-- Nothing to do here; the signal was already fired above.

	elseif eventType == "hitReaction" then
		-- Play hit/dodge/parry on target model based on QTE outcome
		if _pendingOutcome and context.targetModel then
			local outcome = _pendingOutcome
			-- targetCharacterId comes from resolveOutcome (set by BattleServiceClient),
			-- not from evt (which has no reliable characterId at timeline-enrich time).
			local characterId = outcome.targetCharacterId
			local qte = outcome.qteResult

			-- For the local player, dodge/parry was already played immediately on button press
			-- via ReactionInputServiceClient. Only play here for non-local models (e.g. PvP spectating).

			if qte == "PerfectDodge" or qte == "GoodDodge" then
				-- if not isLocalPlayer then
				-- 	BattleAnimator.playDodge(characterId, context.targetModel)
				-- end
			elseif qte == "PerfectParry" or qte == "GoodParry" then
				-- if not isLocalPlayer then
				-- 	BattleAnimator.playParry(characterId, context.targetModel)
				-- end
			elseif not outcome.hit then
				-- do nothing
			elseif outcome.damage and outcome.damage > 0 then
				BattleAnimator.playHit(characterId, context.targetModel)
			end
		end

	elseif eventType == "walkTo" then
		-- Move actor model toward target model, stopping `offset` studs away.
		-- Uses Humanoid:MoveTo for humanoid characters, TweenService for others.
		if not context.actorModel or not context.targetModel then
			log:warn("walkTo: actorModel or targetModel is nil")
		else
			local actor = context.actorModel
			local target = context.targetModel
			local duration = evt.duration or 0.6
			local stopOffset = evt.offset or 3

			local actorHRP = actor:FindFirstChild("HumanoidRootPart") or actor.PrimaryPart
			local targetHRP = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart

			if actorHRP and targetHRP then
				-- Save origin only on the first walkTo of this move sequence.
				-- _actorFormation is the persistent formation CFrame; prefer it as the walkBack target
				-- to stop drift compounding across moves.
				if not _actorOrigin then
					_actorOrigin = actor:GetPivot()
					if not _actorFormationMap[actor] then
						_actorFormationMap[actor] = _actorOrigin
					end
				end

				-- Flatten to XZ — a 3D direction vector produces wrong destination height
				local actorPos = actorHRP.Position
				local targetPos = targetHRP.Position
				local dir2D = Vector3.new(targetPos.X - actorPos.X, 0, targetPos.Z - actorPos.Z)
				dir2D = if dir2D.Magnitude > 0.1 then dir2D.Unit else Vector3.new(0, 0, -1)
				local destPos = Vector3.new(
					targetPos.X - dir2D.X * stopOffset,
					actorPos.Y,
					targetPos.Z - dir2D.Z * stopOffset
				)

				local humanoid = actor:FindFirstChildOfClass("Humanoid")
				if humanoid then
					local travelDist = (destPos - actorPos).Magnitude
					local requiredSpeed = if duration > 0 and travelDist > 0.1 then travelDist / duration else 16
					humanoid.WalkSpeed = requiredSpeed
					humanoid:MoveTo(destPos)
					-- Re-lock speed to 0 after duration (battle movement lock)
					task.delay(duration, function()
						if humanoid and humanoid.Parent then
							humanoid.WalkSpeed = 0
							humanoid:MoveTo(actorHRP.Position)
							if actorHRP:IsA("BasePart") then
								actorHRP.AssemblyLinearVelocity = Vector3.zero
								actorHRP.AssemblyAngularVelocity = Vector3.zero
							end
						end
					end)
				else
					local destCFrame = CFrame.new(destPos) * CFrame.Angles(0, math.atan2(-dir2D.X, -dir2D.Z), 0)
					TweenService:Create(
						actorHRP,
						TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ CFrame = destCFrame }
					):Play()
				end
			else
				log:warn("walkTo: could not find HumanoidRootPart or PrimaryPart on actor/target")
			end
		end

	elseif eventType == "walkBack" then
		-- Return actor to canonical formation position.
		if not context.actorModel or not _actorOrigin then
			_actorOrigin = nil
		else
			local actor = context.actorModel
			local duration = evt.duration or 0.4
			-- Prefer _actorFormation (stable across moves) over _actorOrigin (per-move)
			local origin = _actorFormationMap[actor] or _actorOrigin
			_actorOrigin = nil

			local actorHRP = actor:FindFirstChild("HumanoidRootPart") or actor.PrimaryPart
			local humanoid = actor:FindFirstChildOfClass("Humanoid")
			if humanoid and actorHRP then
				local travelDist = (origin.Position - actorHRP.Position).Magnitude
				local requiredSpeed = if duration > 0 and travelDist > 0.1 then travelDist / duration else 16
				humanoid.WalkSpeed = requiredSpeed
				humanoid:MoveTo(origin.Position)
				task.delay(duration, function()
					if humanoid and humanoid.Parent then
						-- Zero velocity BEFORE PivotTo — physics momentum overrides the snap otherwise
						humanoid.WalkSpeed = 0
						humanoid:MoveTo(actorHRP.Position)
						if actorHRP:IsA("BasePart") then
							actorHRP.AssemblyLinearVelocity = Vector3.zero
							actorHRP.AssemblyAngularVelocity = Vector3.zero
						end
						actor:PivotTo(origin)
					end
				end)
			elseif actorHRP then
				TweenService:Create(
					actorHRP,
					TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ CFrame = origin }
				):Play()
			end
		end

	elseif eventType == "qteWindow" then
		-- QTE prompt — BattleServiceClient handles this via PromptReaction signal.
		-- Timeline just marks when it should appear visually.

	elseif eventType == "vfx" then
		-- TODO: VFX spawning system (future)
		log:debug(`VFX event: {evt.id or "unknown"}`)

	elseif eventType == "sound" then
		-- TODO: Sound system (future)
		log:debug(`Sound event: {evt.id or "unknown"}`)
	end
end

local function runTimeline(
	timeline: { any },
	context: { actorModel: Model?, targetModel: Model? }
)
	if not timeline or #timeline == 0 then return end

	-- Sort by time (should already be sorted, but defensive)
	local sorted = table.clone(timeline)
	table.sort(sorted, function(a, b) return a.time < b.time end)

	task.spawn(function()
		local startTime = os.clock()

		for _, evt in sorted do
			if _timelineCancelled or not _inBattle then break end

			local elapsed = os.clock() - startTime
			local waitTime = evt.time - elapsed
			if waitTime > 0.01 then
				task.wait(waitTime)
			end

			if _timelineCancelled or not _inBattle then break end

			-- For "damage"/"hitReaction", wait briefly for outcome data if missing
			if (evt.event == "damage" or evt.event == "hitReaction") and not _pendingOutcome then
				local waited = 0
				while not _pendingOutcome and waited < 1.0 and _inBattle do
					task.wait(0.05)
					waited += 0.05
				end
			end

			handleTimelineEvent(evt, context)
		end
	end)
end

-- ── Attack Playback ──────────────────────────────────────────────────────────

function BattleAnimator.playAttack(
	characterId: string?,
	moveName: string,
	actorModel: Model?,
	targetModels: { Model }?
): number
	local charId = characterId or ""
	local attackData = BattleAnimationData.getAttack(charId, moveName)
	local duration = if attackData then (attackData.duration or 1.0) else 1.0

	_pendingOutcome = nil
	_actorOrigin = nil -- clear any stale origin from a previous move that had no walkBack
	_animGeneration += 1
	local myGeneration = _animGeneration

	BattleAnimator.AnimationStarted:Fire({
		moveName = moveName,
		characterId = charId,
		duration = duration,
	})

	-- Play animation track on actor model
	if actorModel and attackData and attackData.id then
		local animator = getAnimator(actorModel)
		if animator then
			local priority = attackData.priority or Enum.AnimationPriority.Action2
			local track = getOrLoadTrack(animator, attackData.id, priority)
			if track then
				track.Looped = false
				track:Play(0.1) -- fast crossfade from idle
			end
		end
	end

	-- Run timeline events
	if attackData and attackData.timeline then
		-- Inject targetCharacterId into hitReaction events for reaction lookup
		local enrichedTimeline = {}
		for _, evt in attackData.timeline do
			local copy = table.clone(evt)
			if copy.event == "hitReaction" then
				-- We need the target's characterId for reaction animation lookup
				-- This will be resolved from _pendingOutcome or passed context
				copy.targetCharacterId = nil -- filled at resolve time
			end
			table.insert(enrichedTimeline, copy)
		end

		runTimeline(enrichedTimeline, {
			actorModel = actorModel,
			targetModel = targetModels and targetModels[1] or nil, -- primary target for walkTo/hitReaction
			targetModels = targetModels or {}, -- all targets for multi-target camera
		})
	end

	-- Schedule AnimationComplete after duration
	task.delay(duration, function()
		if not _inBattle then return end
		-- Crossfade back to idle
		if actorModel then
			local idleTrack = _idleTracks[actorModel]
			if idleTrack then
				idleTrack:Play(0.25)
			end
		end

		-- Only return camera to overview if no newer animation has started.
		-- This prevents attack A's delayed return from overriding attack B's camera.
		if myGeneration == _animGeneration then
			local camSvc = getCameraService()
			if camSvc and camSvc:isInBattle() then
				camSvc:returnToOverview(0.5)
			end
		end

		BattleAnimator.AnimationComplete:Fire({
			moveName = moveName,
			characterId = charId,
		})
	end)

	return duration
end

-- ── Outcome Resolution ───────────────────────────────────────────────────────
-- Called when MoveResolved (ActionExecuted) arrives from server.
-- Sets _pendingOutcome so timeline "damage"/"hitReaction" events can use it.

function BattleAnimator.resolveOutcome(data: {
	damage: number?,
	healing: number?,
	hit: boolean?,
	qteResult: string?,
	statusApplied: string?,
	targetModel: Model?,
	targetCharacterId: string?,
})
	_pendingOutcome = data

	-- If the timeline already passed the damage frame, the event was waiting.
	-- It will pick up _pendingOutcome on its next poll cycle automatically.
end

-- ── Reaction Animations ──────────────────────────────────────────────────────

local function isPlaceholderId(id: string?): boolean
	return not id or id == "rbxassetid://0"
end

function BattleAnimator.playHit(characterId: string?, model: Model)
	if not model then return end
	local charData = if characterId then BattleAnimationData.getCharacter(characterId) else nil
	local animId = charData and charData.hit
	if isPlaceholderId(animId) then return end

	local animator = getAnimator(model)
	if not animator then return end

	local track = getOrLoadTrack(animator, animId, Enum.AnimationPriority.Action4)
	if track then
		track.Looped = false
		track:Play(0.05)
	end
end

function BattleAnimator.playDodge(characterId: string?, model: Model)
	if not model then return end
	local charData = if characterId then BattleAnimationData.getCharacter(characterId) else nil
	local animId = charData and charData.dodge
	if isPlaceholderId(animId) then return end

	local animator = getAnimator(model)
	if not animator then return end

	local track = getOrLoadTrack(animator, animId, Enum.AnimationPriority.Action3)
	if track then
		track.Looped = false
		track:Play(0.05)
	end
end

function BattleAnimator.playParry(characterId: string?, model: Model)
	if not model then return end
	local charData = if characterId then BattleAnimationData.getCharacter(characterId) else nil
	local animId = charData and charData.parry
	if isPlaceholderId(animId) then return end

	local animator = getAnimator(model)
	if not animator then return end

	local track = getOrLoadTrack(animator, animId, Enum.AnimationPriority.Action3)
	if track then
		track.Looped = false
		track:Play(0.05)
	end
end

function BattleAnimator.playDeath(characterId: string?, model: Model)
	if not model then return end
	local charData = if characterId then BattleAnimationData.getCharacter(characterId) else nil
	local animId = charData and charData.death
	if not animId then return end

	local animator = getAnimator(model)
	if not animator then return end

	-- Stop idle
	BattleAnimator.stopBattleIdle(model)

	-- Prevent default Roblox death behavior
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end

	local track = getOrLoadTrack(animator, animId, Enum.AnimationPriority.Action4)
	if track then
		track.Looped = false
		track:Play(0.05)
	end
end

-- ── Battle Lifecycle ─────────────────────────────────────────────────────────

function BattleAnimator.onBattleStart(allModels: { { model: Model?, characterId: string? } })
	_inBattle = true
	_timelineCancelled = false
	_pendingOutcome = nil
	_actorOrigin = nil
	table.clear(_actorFormationMap)
	_cameraService = nil -- re-acquire on next use

	-- Start battle idle for all models
	for _, entry in allModels do
		if entry.model and entry.characterId then
			BattleAnimator.startBattleIdle(entry.characterId, entry.model)
			local animator = getAnimator(entry.model)
			if animator then
				local conn = animator.AnimationPlayed:Connect(function(track)
					if track.Name == "WalkAnim" or track.Name == "RunAnim" then
						track.Priority = Enum.AnimationPriority.Movement
					end
				end)
				_battleJanitor:Add(conn, "Disconnect")
			end
		end
	end
	
	log:debug(`Battle started — idle loops for {#allModels} models`)
end

function BattleAnimator.onBattleEnd()
	_inBattle = false
	_timelineCancelled = true
	_pendingOutcome = nil
	_actorOrigin = nil
	table.clear(_actorFormationMap)

	-- Stop all idles
	for model, _ in _idleTracks do
		BattleAnimator.stopBattleIdle(model)
	end
	table.clear(_idleTracks)

	-- Destroy all cached tracks
	destroyAllCachedTracks()

	_battleJanitor:Cleanup()
	log:debug("Battle ended — all tracks cleaned up")
end

-- ── Queries ──────────────────────────────────────────────────────────────────

function BattleAnimator.isInBattle(): boolean
	return _inBattle
end

return BattleAnimator
