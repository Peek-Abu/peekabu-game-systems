--!strict
--[=[
	EmployeeGarmentGuardSystem: keeps layered clothing (an Accessory whose Handle has a WrapLayer, wrapped by the engine
	over the body cages baked into every employee template) wrapped on this client. Cosmetic, client-only: every
	client wraps every character itself, so each one guards the characters it sees.

	A layered garment can get stuck wrong, found in Play (2026-11-05/06):
	- worn before this client has loaded the cage meshes (a fresh spawn, a skin just equipped), it wraps on nothing
	  and stays collapsed at the feet with the body showing through;
	- with the close camera (the "popper" fade) it was seen collapsed the same way, trigger not yet reproduced.
	The engine re-wraps a garment whose WrapLayer is turned off and back on (proven in Play), so a re-wrap is two steps:
	off on one step, on the next.

	A character's garments are re-wrapped:
	- once a garment appears (track, or a skin's accessory added later): after every cage mesh on the character (body
	  WrapTargets and garment WrapLayers) reports loaded, or after EmployeeConstants.GARMENT_LOAD_TIMEOUT;
	- when the fade on the body ends (a caged body part's LocalTransparencyModifier goes from above 0 to 0: the camera
	  fade, the engine's own, a hiding spot's);
	- after a big move (the root jumps more than EmployeeConstants.GARMENT_MOVE_JUMP in one step: truck boarding, a
	  teleport);
	at most once per EmployeeConstants.GARMENT_REWRAP_COOLDOWN (a trigger inside it waits for it to pass). A character
	with no garment costs nothing.

	@class EmployeeGarmentGuardSystem
]=]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)

type Tracked = {
	model: Model,
	layers: { [WrapLayer]: true },
	-- Waiting for the cage meshes since this time (nil = waiting starts at the next step).
	waiting: boolean,
	waitingSince: number?,
	wanted: boolean,
	-- The layers are off this step and go back on at the next.
	off: boolean,
	lastRewrap: number,
	previousRoot: Vector3?,
	previousFade: number,
}

export type EmployeeGarmentGuardState = {
	tracked: number,
	garments: number,
	-- Re-wraps completed since the guard was made.
	rewraps: number,
}

export type EmployeeGarmentGuardSystem = {
	-- Starts guarding a character's garments from time `now`; returns the release (which leaves them wrapped).
	track: (character: Model, now: number) -> () -> (),
	step: (now: number) -> (),
	getState: () -> EmployeeGarmentGuardState,
}

local EmployeeGarmentGuardSystem = {}

local function rootOf(model: Model): BasePart?
	local root = model.PrimaryPart
	if root ~= nil then
		return root
	end
	local found = model:FindFirstChild("HumanoidRootPart")
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

-- The fade on the body: the LocalTransparencyModifier of the first caged body part (0 without one).
local function bodyFade(model: Model): number
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("WrapTarget") then
			local part = descendant.Parent
			if part ~= nil and part:IsA("BasePart") then
				return part.LocalTransparencyModifier
			end
		end
	end
	return 0
end

local function setLayers(tracked: Tracked, enabled: boolean)
	for layer in tracked.layers do
		layer.Enabled = enabled
	end
end

--[=[
	A guard. `fetchStatus` says how far a cage's mesh (a WrapTarget's or WrapLayer's CageMeshId) has loaded; default:
	ContentProvider:GetAssetFetchStatus, and Success for a cage with no mesh. Injectable for specs (only plugins may set
	CageMeshId, so a spec cannot make real cages).
]=]
function EmployeeGarmentGuardSystem.new(
	fetchStatus: ((cage: WrapTarget | WrapLayer) -> Enum.AssetFetchStatus)?
): EmployeeGarmentGuardSystem
	local status: (cage: WrapTarget | WrapLayer) -> Enum.AssetFetchStatus = fetchStatus
		or function(cage: WrapTarget | WrapLayer): Enum.AssetFetchStatus
			local contentId = cage.CageMeshId
			if contentId == "" then
				return Enum.AssetFetchStatus.Success
			end
			return ContentProvider:GetAssetFetchStatus(contentId)
		end
	local trackedByModel: { [Model]: Tracked } = {}
	local rewraps = 0

	-- Whether every cage mesh on the character has finished loading (a failed load will not get better: done too).
	local function cagesLoaded(model: Model): boolean
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("WrapTarget") or descendant:IsA("WrapLayer") then
				local state = status(descendant)
				if state == Enum.AssetFetchStatus.Loading or state == Enum.AssetFetchStatus.None then
					return false
				end
			end
		end
		return true
	end

	local function stepOne(tracked: Tracked, now: number)
		if tracked.off then
			setLayers(tracked, true)
			tracked.off = false
			rewraps += 1
		end
		local model = tracked.model
		local root = rootOf(model)
		local position = if root ~= nil then root.Position else nil
		local previous = tracked.previousRoot
		local fade = bodyFade(model)
		local moved = position ~= nil
			and previous ~= nil
			and (position - previous).Magnitude > EmployeeConstants.GARMENT_MOVE_JUMP
		local unfaded = tracked.previousFade > 0 and fade == 0
		tracked.previousRoot = position
		tracked.previousFade = fade
		if next(tracked.layers) == nil then
			tracked.wanted = false
			return
		end
		if tracked.waiting then
			local since = tracked.waitingSince or now
			tracked.waitingSince = since
			if cagesLoaded(model) or now - since >= EmployeeConstants.GARMENT_LOAD_TIMEOUT then
				tracked.waiting = false
				tracked.waitingSince = nil
				tracked.wanted = true
			end
		end
		if moved or unfaded then
			tracked.wanted = true
		end
		if
			tracked.wanted
			and not tracked.waiting
			and now - tracked.lastRewrap >= EmployeeConstants.GARMENT_REWRAP_COOLDOWN
		then
			setLayers(tracked, false)
			tracked.off = true
			tracked.wanted = false
			tracked.lastRewrap = now
		end
	end

	return {
		track = function(character, now)
			local tracked: Tracked = {
				model = character,
				layers = {},
				waiting = false,
				waitingSince = nil,
				wanted = false,
				off = false,
				lastRewrap = -math.huge,
				previousRoot = nil,
				previousFade = 0,
			}
			for _, descendant in character:GetDescendants() do
				if descendant:IsA("WrapLayer") then
					tracked.layers[descendant] = true
				end
			end
			if next(tracked.layers) ~= nil then
				tracked.waiting = true
				tracked.waitingSince = now
			end
			local added = character.DescendantAdded:Connect(function(descendant: Instance)
				if descendant:IsA("WrapLayer") then
					tracked.layers[descendant] = true
					tracked.waiting = true
					tracked.waitingSince = nil
				end
			end)
			local removing = character.DescendantRemoving:Connect(function(descendant: Instance)
				if descendant:IsA("WrapLayer") then
					tracked.layers[descendant] = nil
				end
			end)
			trackedByModel[character] = tracked
			return function()
				added:Disconnect()
				removing:Disconnect()
				if trackedByModel[character] == tracked then
					trackedByModel[character] = nil
				end
				if tracked.off then
					setLayers(tracked, true)
					tracked.off = false
				end
			end
		end,

		step = function(now)
			for _, tracked in trackedByModel do
				stepOne(tracked, now)
			end
		end,

		getState = function()
			local tracked, garments = 0, 0
			for _, entry in trackedByModel do
				tracked += 1
				for _ in entry.layers do
					garments += 1
				end
			end
			return { tracked = tracked, garments = garments, rewraps = rewraps }
		end,
	}
end

return EmployeeGarmentGuardSystem
