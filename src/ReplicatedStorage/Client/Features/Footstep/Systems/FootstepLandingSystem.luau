--!strict
--[=[
	FootstepLandingSystem: the body meeting the floor, for every player character this client sees, from its vertical
	speed each frame (FootstepLandingFormulas; a remote character's Humanoid state does not replicate, its velocity does).
	The game's own character sounds (round-3 default-sounds audit): FootstepServiceClient mutes the engine's (its running
	loop, free-fall wind, jump, landing, climb, swim, get-up and death "oof"), and these play instead:

	- a land (FootstepAssets.LAND, 3D on the root, louder the faster the fall), at most one per LAND_GAP;
	- the jump: one of FootstepAssets.JUMPS at random (never the same twice running), 3D on the root;
	- a dead body's first impact within BODY_FALL_WINDOW of the death (the catch's throw, any ragdoll): the plush
	  body-fall (FootstepAssets.BODY_FALL), once. (The caught player's "FIRED" stamp at the throw is
	  OccupantScareSystem's.)

	Spec-exempt shell (Players, Instances, RunService); the decisions are the specced FootstepLandingFormulas.

	@class FootstepLandingSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FootstepAssets = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepAssets)
local FootstepConstants = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepConstants)
local FootstepLandingFormulas = require(ReplicatedStorage.Client.Features.Footstep.Utils.FootstepLandingFormulas)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

export type Counters = { lands: number, jumps: number, bodyFalls: number }

type Body = {
	root: BasePart,
	humanoid: Humanoid,
	-- The part whose fall is read once dead (the torso of a ragdoll; the root otherwise).
	torso: BasePart,
	lastSpeed: number,
	lastLand: number,
	diedAt: number?,
	fell: boolean,
	-- The last jump variant played (JUMPS index).
	lastJump: number,
}

local bodies: { [Model]: Body } = {}
local counters: Counters = { lands = 0, jumps = 0, bodyFalls = 0 }
local stoppers: { () -> () } = {}
-- Each player's CharacterAdded connection, dropped when they leave.
local followers: { [Player]: RBXScriptConnection? } = {}
local rng = Random.new()

local function play(id: string, at: BasePart, volumeScale: number?)
	if SoundRegistry.has(id) then
		SoundServiceClient:playOneShot(id, { at = at, volumeScale = volumeScale })
	end
end

-- One jump variant at random (never the one this body played last), 3D on its root.
local function playJump(body: Body)
	local jumps = FootstepAssets.JUMPS
	local index = FootstepLandingFormulas.variant(rng:NextNumber(), #jumps, body.lastJump)
	body.lastJump = index
	counters.jumps += 1
	play(jumps[index], body.root)
end

local function track(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if root == nil or not root:IsA("BasePart") or humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	if character.Parent == nil then
		return
	end
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local body: Body = {
		root = root,
		humanoid = humanoid,
		torso = if upper ~= nil and upper:IsA("BasePart") then upper else root,
		lastSpeed = 0,
		lastLand = 0,
		diedAt = if humanoid.Health <= 0 then os.clock() else nil,
		fell = false,
		lastJump = 0,
	}
	bodies[character] = body
	-- The jump and land play on the root: their Sounds are made now, not on the first jump.
	SoundServiceClient:prewarm(root, FootstepConstants.PREWARM_PER_ANCHOR)
	-- ...and the body-fall's on the torso, so a death does not make one.
	if body.torso ~= root then
		SoundServiceClient:prewarm(body.torso, 1)
	end
	humanoid.Died:Once(function()
		if body.diedAt == nil then
			body.diedAt = os.clock()
			body.lastSpeed = body.torso.AssemblyLinearVelocity.Y
		end
	end)
end

local function step()
	local now = os.clock()
	for model, body in bodies do
		if model.Parent == nil or body.root.Parent == nil then
			bodies[model] = nil
			continue
		end
		local diedAt = body.diedAt
		if diedAt ~= nil then
			local speed = body.torso.AssemblyLinearVelocity.Y
			if
				not body.fell
				and now - diedAt <= FootstepConstants.BODY_FALL_WINDOW
				and FootstepLandingFormulas.impact(body.lastSpeed, speed, FootstepConstants.BODY_FALL_SPEED)
			then
				body.fell = true
				counters.bodyFalls += 1
				play(FootstepAssets.BODY_FALL, body.torso)
			end
			body.lastSpeed = speed
			continue
		end
		local speed = body.root.AssemblyLinearVelocity.Y
		if FootstepLandingFormulas.jumped(body.lastSpeed, speed, FootstepConstants.JUMP_SPEED) then
			playJump(body)
		elseif
			FootstepLandingFormulas.impact(body.lastSpeed, speed, FootstepConstants.LAND_SPEED)
			and now - body.lastLand >= FootstepConstants.LAND_GAP
		then
			body.lastLand = now
			counters.lands += 1
			play(FootstepAssets.LAND, body.root, FootstepLandingFormulas.landScale(-body.lastSpeed))
		end
		body.lastSpeed = speed
	end
end

local FootstepLandingSystem = {}

function FootstepLandingSystem.start()
	if #stoppers > 0 then
		return
	end
	local function follow(player: Player)
		if player.Character ~= nil then
			task.spawn(track, player.Character)
		end
		followers[player] = player.CharacterAdded:Connect(function(character: Model)
			task.spawn(track, character)
		end)
	end
	for _, player in Players:GetPlayers() do
		follow(player)
	end
	local joined = Players.PlayerAdded:Connect(follow)
	local left = Players.PlayerRemoving:Connect(function(player: Player)
		local added = followers[player]
		if added ~= nil then
			added:Disconnect()
			followers[player] = nil
		end
	end)
	local beat = RunService.Heartbeat:Connect(step)
	table.insert(stoppers, function()
		joined:Disconnect()
		left:Disconnect()
		beat:Disconnect()
		for _, added in followers do
			if added ~= nil then
				added:Disconnect()
			end
		end
		table.clear(followers)
	end)
end

function FootstepLandingSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	table.clear(bodies)
end

function FootstepLandingSystem.getState(): { bodies: number, counters: Counters }
	local count = 0
	for _ in bodies do
		count += 1
	end
	return { bodies = count, counters = table.clone(counters) }
end

return FootstepLandingSystem
