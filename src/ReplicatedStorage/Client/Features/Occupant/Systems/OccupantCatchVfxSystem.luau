--!strict
--[=[
	OccupantCatchVfxSystem: the catch's world particles on every client (OccupantVfxConstants, through VfxBurstSystem),
	so the crew sees a catch as clearly as the caught player:

	- the throw: when a player's character goes down (catches 1 and 2: the server sets the Knockdown attribute on it,
	  DeathKnockdownSystem) or their public `knockedOut` turns true (the 3rd catch), a porcelain crack, shards and dust
	  pop on their character; once per knockdown or knock-out, a republish does not repeat it. A public `caughtUntil`
	  deadline appearing throws too, but no catch publishes one today;
	- back on the clock: when a deadline clears, their next living character (not the one that was thrown) gets the
	  Rehired puff at its feet, if it arrives within REHIRE_WAIT seconds (idle today, with no deadline).

	The deadlines already set when this client starts are the baseline: nothing replays for them. The caught player's
	camera, red screen and Rehired card are OccupantServiceClient's.

	Spec-exempt shell (Charm, Players, VfxBurstSystem): its only decisions are a nil-to-set / set-to-nil check per
	player (the throw is OccupantCatchVfxUtils.thrown); the presets are specced in OccupantVfxConstants.

	@class OccupantCatchVfxSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local DeathKnockdownUtils = require(ReplicatedStorage.Shared.Features.Death.Utils.DeathKnockdownUtils)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local OccupantCatchVfxUtils = require(ReplicatedStorage.Client.Features.Occupant.Utils.OccupantCatchVfxUtils)
local OccupantVfxConstants = require(ReplicatedStorage.Client.Features.Occupant.Data.OccupantVfxConstants)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local VfxBurstSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxBurstSystem)

export type OccupantCatchVfxState = {
	watching: number,
	cracks: number,
	rehired: number,
}

-- Registered at load: VfxBurstSystem refuses an unknown burst.
for id, preset in OccupantVfxConstants.PRESETS do
	if not VfxBurstRegistry.has(id) then
		VfxBurstRegistry.register(id, preset)
	end
end

-- Whose deadline was set at the last look, and the character each was caught in.
local deadlines: { [number]: boolean } = {}
local thrown: { [number]: Model? } = {}
-- Who was knocked out at the last look (a knock-out throws once).
local knockedOut: { [number]: boolean } = {}
-- Who was down (Knockdown attribute on their character) at the last look.
local down: { [number]: boolean } = {}
-- Per player: the connection on their current character's Knockdown attribute, and the one for their next character.
local attributeWatch: { [number]: RBXScriptConnection } = {}
local characterWatch: { [number]: RBXScriptConnection } = {}
local counters = { cracks = 0, rehired = 0 }
local stoppers: { () -> () } = {}
-- Bumped on stop: a pending Rehired wait from before is dropped.
local session = 0

local function rootOf(character: Model?): (BasePart?, Humanoid?)
	if character == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return if root ~= nil and root:IsA("BasePart") then root else nil, humanoid
end

local function crack(player: Player)
	local character = player.Character
	thrown[player.UserId] = character
	local root = rootOf(character)
	if root == nil or not VfxBurstSystem.polished() then
		return
	end
	counters.cracks += 1
	VfxBurstSystem.play("occupantCatchCrack", root.Position)
end

-- Waits (without blocking) for the player's next living character, then puffs at its feet.
local function rehire(player: Player)
	local userId = player.UserId
	local old = thrown[userId]
	thrown[userId] = nil
	local expected = session
	task.spawn(function()
		local waited = 0
		while waited < OccupantVfxConstants.REHIRE_WAIT do
			if session ~= expected or player.Parent == nil then
				return
			end
			local character = player.Character
			local root, humanoid = rootOf(character)
			if character ~= old and root ~= nil and humanoid ~= nil and humanoid.Health > 0 then
				-- A beat for the camera to reach the new character (it was spectating elsewhere): the burst is
				-- culled by its distance from the camera.
				task.wait(OccupantVfxConstants.REHIRE_SETTLE)
				if session == expected and root.Parent ~= nil and VfxBurstSystem.polished() then
					counters.rehired += 1
					local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
					VfxBurstSystem.play("occupantRehired", feet)
				end
				return
			end
			waited += task.wait(0.1)
		end
	end)
end

local function read(map: PublicPlayerTypes.PublicPlayerMap): ({ [number]: boolean }, { [number]: boolean })
	local set: { [number]: boolean } = {}
	local out: { [number]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local entry = map[StateSyncConstants.publicEntryKey(player.UserId)]
		if entry ~= nil then
			if type(entry[OccupantConstants.PUBLIC_CAUGHT_UNTIL]) == "number" then
				set[player.UserId] = true
			end
			if entry[ShiftConstants.PUBLIC_KNOCKED_OUT] == true then
				out[player.UserId] = true
			end
		end
	end
	return set, out
end

-- The character's Knockdown attribute (or the character itself) changed: crack once when it goes down.
local function onDownChanged(player: Player)
	local userId = player.UserId
	local was = down[userId] == true
	local now = DeathKnockdownUtils.isDown(player.Character)
	down[userId] = now
	if OccupantCatchVfxUtils.thrown(false, false, false, false, was, now) then
		crack(player)
	end
end

-- Follows the player's current character's Knockdown attribute; a new character is followed from its spawn.
local function follow(player: Player)
	local userId = player.UserId
	local previous = attributeWatch[userId]
	if previous ~= nil then
		previous:Disconnect()
		attributeWatch[userId] = nil
	end
	local character = player.Character
	if character ~= nil then
		attributeWatch[userId] = character
			:GetAttributeChangedSignal(DeathConstants.KNOCKDOWN_ATTRIBUTE)
			:Connect(function()
				onDownChanged(player)
			end)
	end
	onDownChanged(player)
end

local function watch(player: Player)
	local userId = player.UserId
	if characterWatch[userId] ~= nil then
		return
	end
	characterWatch[userId] = player.CharacterAdded:Connect(function()
		follow(player)
	end)
	-- The baseline: someone already down when this client starts replays nothing.
	down[userId] = DeathKnockdownUtils.isDown(player.Character)
	follow(player)
end

local function unwatch(userId: number)
	local attribute = attributeWatch[userId]
	if attribute ~= nil then
		attribute:Disconnect()
		attributeWatch[userId] = nil
	end
	local character = characterWatch[userId]
	if character ~= nil then
		character:Disconnect()
		characterWatch[userId] = nil
	end
	down[userId] = nil
end

local function onPublic(map: PublicPlayerTypes.PublicPlayerMap)
	local now, nowOut = read(map)
	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		if
			OccupantCatchVfxUtils.thrown(
				deadlines[userId] == true,
				now[userId] == true,
				knockedOut[userId] == true,
				nowOut[userId] == true,
				false,
				false
			)
		then
			crack(player)
		elseif deadlines[userId] and not now[userId] then
			rehire(player)
		end
	end
	deadlines = now
	knockedOut = nowOut
	-- Someone who left while caught is never rehired: let their old character go.
	for userId in thrown do
		if Players:GetPlayerByUserId(userId) == nil then
			thrown[userId] = nil
		end
	end
end

local OccupantCatchVfxSystem = {}

function OccupantCatchVfxSystem.start()
	if #stoppers > 0 then
		return
	end
	VfxBurstSystem.preload()
	deadlines, knockedOut = read(StateSyncClientStore.publicPlayers())
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	local added = Players.PlayerAdded:Connect(watch)
	local removing = Players.PlayerRemoving:Connect(function(player)
		unwatch(player.UserId)
	end)
	table.insert(stoppers, function()
		added:Disconnect()
		removing:Disconnect()
	end)
	table.insert(stoppers, Charm.subscribe(StateSyncClientStore.publicPlayers, onPublic))
end

function OccupantCatchVfxSystem.stop()
	session += 1
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	table.clear(deadlines)
	table.clear(knockedOut)
	for userId in characterWatch do
		unwatch(userId)
	end
	table.clear(thrown)
end

function OccupantCatchVfxSystem.getState(): OccupantCatchVfxState
	local watching = 0
	for _ in deadlines do
		watching += 1
	end
	return { watching = watching, cracks = counters.cracks, rehired = counters.rehired }
end

return OccupantCatchVfxSystem
