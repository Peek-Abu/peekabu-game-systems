--!strict
--[=[
	OccupantDreadMixSystem: the dread's mix on this client. An EqualizerSoundEffect on the Ambient group and on every
	other Music-group sound (the overtime ticking) ducks them and muffles their highs by the look's duck and muffle
	(OccupantDreadFormulas.eq); the dread loop and the chase stems are never touched. Split out of OccupantDreadSystem,
	which calls `set` every frame and `release` when the dread clears.

	@class OccupantDreadMixSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local OccupantAssets = require(OccupantShared.Data.OccupantAssets)
local OccupantDreadFormulas = require(OccupantShared.Utils.OccupantDreadFormulas)

-- The EQ's name on each sound or group it ducks.
local EQ_NAME = "OccupantDreadEq"
-- How often the other Music-group sounds are looked for (s).
local SCAN_INTERVAL = 0.5
-- Sounds the duck never touches: the dread loop and the chase stems (its own Music-group sounds).
local OWN: { [string]: boolean } = { harlowDread = true }
for _, list in { OccupantAssets.CHASE_STEMS.base, OccupantAssets.CHASE_STEMS.near } do
	for _, id in list do
		OWN[id] = true
	end
end

local nextScan = 0
local eqs: { [Instance]: EqualizerSoundEffect? } = {}

local OccupantDreadMixSystem = {}

-- Destroys every EQ it made.
function OccupantDreadMixSystem.release()
	for _, eq in eqs do
		if eq ~= nil then
			eq:Destroy()
		end
	end
	table.clear(eqs)
end

local function eqFor(target: Instance): EqualizerSoundEffect
	local existing = eqs[target]
	if existing ~= nil and existing.Parent == target then
		return existing
	end
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = EQ_NAME
	-- After any other effect on the group (the results duck), so the two simply stack.
	eq.Priority = 10
	eq.Parent = target
	eqs[target] = eq
	return eq
end

-- The duck and muffle (dB, the look's) on the Ambient group and on every other Music-group sound.
function OccupantDreadMixSystem.set(now: number, duck: number, muffle: number)
	local low, mid, high = OccupantDreadFormulas.eq(duck, muffle)
	if low > -0.05 and high > -0.05 then
		OccupantDreadMixSystem.release()
		return
	end
	local ambient = SoundService:FindFirstChild("Ambient")
	if ambient ~= nil and ambient:IsA("SoundGroup") then
		eqFor(ambient)
	end
	if now >= nextScan then
		nextScan = now + SCAN_INTERVAL
		for _, child in SoundService:GetChildren() do
			if
				child:IsA("Sound")
				and not OWN[child.Name]
				and child.Volume > 0
				and child.SoundGroup ~= nil
				and child.SoundGroup.Name == "Music"
			then
				eqFor(child)
			end
		end
	end
	for target, eq in eqs do
		if eq == nil or target.Parent == nil or eq.Parent ~= target then
			eqs[target] = nil
			continue
		end
		eq.LowGain, eq.MidGain, eq.HighGain = low, mid, high
	end
end

-- How many sounds and groups it is ducking.
function OccupantDreadMixSystem.count(): number
	local count = 0
	for _ in eqs do
		count += 1
	end
	return count
end

return OccupantDreadMixSystem
