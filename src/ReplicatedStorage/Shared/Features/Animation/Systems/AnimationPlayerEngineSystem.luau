--!strict
--[=[
	AnimationPlayerEngineSystem: the Instance-touching shell around `AnimationPlayerSystem` (Phase 6 spec,
	Decision 2). Everything here is a thin verb over engine objects; every rule lives in the pure
	core. Spec-exempt for the same reason as `CustomizationDressSystem`: each branch needs a live
	Animator and real assets, which TestEZ has no renderer/rig for — the core carries the specs.

	One player per Animator, memoized: AnimationLocomotionSystem, the services, and the Cmdr commands all
	resolve the SAME player for a character, so bookkeeping (and therefore stop-class verbs and the
	Debugger panel) see one truth.

	`Animation` instances are created transiently and never parented — ids live in the registry,
	not the tree (the 445-instances-as-data anti-pattern).

	@class AnimationPlayerEngineSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationPlayerSystem = require(ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerSystem)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)

export type AnimationPlayerHandle = AnimationPlayerSystem.AnimationPlayerSystem

local playersByAnimator: { [Animator]: AnimationPlayerSystem.AnimationPlayerSystem } = {}

local AnimationPlayerEngineSystem = {}

local function makeSeam(animator: Animator): AnimationPlayerSystem.AnimatorSeam
	return {
		load = function(assetId: string): AnimationPlayerSystem.SeamTrack?
			local animation = Instance.new("Animation")
			animation.AnimationId = assetId
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			-- The transient Animation has served its purpose either way: the track holds the
			-- loaded data, and keeping the instance around would contradict "ids live in the
			-- registry, not in Instances".
			animation:Destroy()
			if not ok then
				return nil
			end
			return {
				play = function(fadeTime: number, weight: number, speed: number)
					track:Play(fadeTime, weight, speed)
				end,
				stop = function(fadeTime: number)
					track:Stop(fadeTime)
				end,
				adjustSpeed = function(speed: number)
					track:AdjustSpeed(speed)
				end,
				setPriority = function(priority: Enum.AnimationPriority)
					track.Priority = priority
				end,
				setLooped = function(looped: boolean)
					track.Looped = looped
				end,
				isPlaying = function(): boolean
					return track.IsPlaying
				end,
				onEnded = function(callback: () -> ()): () -> ()
					local connection = track.Ended:Connect(callback)
					return function()
						connection:Disconnect()
					end
				end,
				onMarker = function(markerName: string, callback: (param: string?) -> ()): () -> ()
					local connection = track:GetMarkerReachedSignal(markerName):Connect(callback)
					return function()
						connection:Disconnect()
					end
				end,
				setTimePosition = function(seconds: number)
					track.TimePosition = seconds
				end,
				timePosition = function(): number
					return track.TimePosition
				end,
				length = function(): number
					return track.Length
				end,
			}
		end,
		onRemoved = function(callback: () -> ()): () -> ()
			local connection = animator.Destroying:Connect(callback)
			return function()
				connection:Disconnect()
			end
		end,
	}
end

--[=[
	The (memoized) player for an Animator.
	@param animator Animator
	@return AnimationPlayerSystem
]=]
function AnimationPlayerEngineSystem.forAnimator(animator: Animator): AnimationPlayerSystem.AnimationPlayerSystem
	local existing = playersByAnimator[animator]
	if existing ~= nil then
		return existing
	end
	local player = AnimationPlayerSystem.new(makeSeam(animator), AnimationRegistry.get)
	playersByAnimator[animator] = player
	-- Memoization cleanup rides the same signal the player's own cleanup does.
	animator.Destroying:Once(function()
		playersByAnimator[animator] = nil
	end)
	return player
end

--[=[
	The player for a character model, resolving its Animator through Humanoid or
	AnimationController. Waits briefly for the Animator on freshly-spawned rigs.
	@param character Model
	@return AnimationPlayerSystem? -- nil when no Animator can be found
]=]
function AnimationPlayerEngineSystem.forCharacter(character: Model): AnimationPlayerSystem.AnimationPlayerSystem?
	local host: Instance? = character:FindFirstChildOfClass("Humanoid")
	if host == nil then
		host = character:FindFirstChildOfClass("AnimationController")
	end
	if host == nil then
		return nil
	end
	local animator = host:FindFirstChildOfClass("Animator")
	if animator == nil then
		local candidate = host:WaitForChild("Animator", 5)
		if candidate ~= nil and candidate:IsA("Animator") then
			animator = candidate
		end
	end
	if animator == nil then
		return nil
	end
	return AnimationPlayerEngineSystem.forAnimator(animator)
end

return AnimationPlayerEngineSystem
