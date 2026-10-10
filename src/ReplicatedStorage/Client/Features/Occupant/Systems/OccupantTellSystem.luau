--!strict
--[=[
	OccupantTellSystem: Mr. Harlow's tells on this client (Cleanup Crew spec §4 "Tells", §7 "Tier up: lights
	flicker"). Every TELL_INTERVAL:
	- each office light (tag OfficeLight) within FLICKER_RADIUS of him flickers (OccupantTellRules.flicker);
	  for TIER_FLICKER_SECONDS after a tier rise every light flickers; for LIGHTS_OUT_SECONDS after a catch the
	  lights within LIGHTS_OUT_RADIUS of it are dark (the blackout is time-boxed on the tick, and `stop` clears
	  it, so no light stays dark);
	- while he is within HEARTBEAT_RANGE and not chasing you (OccupantTellRules.heartbeat), the screen pulses
	  red with the beat (OccupantTellRules.pulse), faster the closer he is; it is silent while he is catching
	  you. Placeholder for the heartbeat sound (M3).
	A light is "off" when its neon turns to plastic and its PointLight is disabled. Client-local changes only.

	Spec-exempt shell (Instances, Vfx); the decisions are the specced OccupantTellRules.

	@class OccupantTellSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTellRules = require(ReplicatedStorage.Shared.Features.Occupant.Rules.OccupantTellRules)
local VfxServiceClient = require(ReplicatedStorage.Client.Features.Vfx.VfxServiceClient)

local connection: RBXScriptConnection? = nil
-- Each light's state as this client last set it (weak keys: lights go with the office).
local lit: { [BasePart]: boolean } = {}
setmetatable(lit, { __mode = "k" })
local outAt: Vector3? = nil
local outUntil = 0
local flickerUntil = 0
local screenToken: number? = nil
local beatStarted = 0

local function setLit(light: BasePart, on: boolean)
	local previous = lit[light]
	if previous == on then
		return
	end
	lit[light] = on
	if previous == nil and on then
		-- Never touched and still lit: leave the builder's material alone.
		return
	end
	light.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local point = light:FindFirstChildOfClass("PointLight")
	if point ~= nil then
		point.Enabled = on
	end
end

-- A stable per-light seed so lights near him flicker out of step.
local function seedOf(light: BasePart): number
	local position = light.Position
	return position.X * 0.137 + position.Z * 0.071 + 0.5
end

local function harlowRoot(): BasePart?
	for _, model in CollectionService:GetTagged(OccupantConstants.TAG) do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root ~= nil and root:IsA("BasePart") then
			return root
		end
	end
	return nil
end

local function updateLights(now: number, harlow: BasePart?)
	if now >= outUntil then
		outAt = nil
	end
	local darkAround = outAt
	local everywhere = now < flickerUntil
	for _, instance in CollectionService:GetTagged(OccupantConstants.LIGHT_TAG) do
		if instance:IsA("BasePart") then
			local seed = seedOf(instance)
			local on = true
			if everywhere then
				on = OccupantTellRules.flicker(0, now, seed)
			end
			if on and harlow ~= nil then
				on = OccupantTellRules.flicker((instance.Position - harlow.Position).Magnitude, now, seed)
			end
			if
				darkAround ~= nil
				and (instance.Position - darkAround).Magnitude <= OccupantConstants.LIGHTS_OUT_RADIUS
			then
				on = false
			end
			setLit(instance, on)
		end
	end
end

local function stopBeat()
	local token = screenToken
	if token ~= nil then
		VfxServiceClient:releaseScreen(token)
		screenToken = nil
	end
end

local function updateHeartbeat(now: number, harlow: BasePart?)
	local localPlayer = Players.LocalPlayer
	local character = localPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if harlow == nil or root == nil or not root:IsA("BasePart") then
		stopBeat()
		return
	end
	local model = harlow.Parent
	local mode = if model ~= nil then model:GetAttribute(OccupantConstants.MODE_ATTRIBUTE) else nil
	local target = if model ~= nil then model:GetAttribute(OccupantConstants.TARGET_ATTRIBUTE) else nil
	local modeName = if type(mode) == "string" then mode else nil
	local onMe = target == localPlayer.UserId
	local distance = (root.Position - harlow.Position).Magnitude
	-- Silent while he chases you (the rule) and while he is catching you.
	local beating = OccupantTellRules.heartbeat(distance, modeName, onMe) and not (modeName == "catch" and onMe)
	if not beating then
		stopBeat()
		return
	end
	local existing = screenToken
	local token: number = if existing ~= nil then existing else VfxServiceClient:requestScreen({})
	if existing == nil then
		beatStarted = now
		screenToken = token
	end
	local strength = OccupantTellRules.pulse(now - beatStarted, distance)
	local white = Color3.new(1, 1, 1)
	VfxServiceClient:updateScreen(token, {
		tint = white:Lerp(OccupantConstants.HEARTBEAT_TINT, strength),
		saturation = -0.25 * strength,
	})
end

local OccupantTellSystem = {}

function OccupantTellSystem.start()
	if connection ~= nil then
		return
	end
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < OccupantConstants.TELL_INTERVAL then
			return
		end
		elapsed = 0
		local now = os.clock()
		local harlow = harlowRoot()
		updateLights(now, harlow)
		updateHeartbeat(now, harlow)
	end)
end

--[=[
	Stops the tells and puts everything back: every light we darkened is lit again, the blackout and tier
	flicker are cancelled, the screen tint is released.
]=]
function OccupantTellSystem.stop()
	local current = connection
	if current ~= nil then
		current:Disconnect()
		connection = nil
	end
	stopBeat()
	outAt = nil
	outUntil = 0
	flickerUntil = 0
	for light in pairs(lit) do
		setLit(light, true)
	end
end

--[=[
	A catch at `position`: the lights around it die for LIGHTS_OUT_SECONDS (the tick restores them).
]=]
function OccupantTellSystem.lightsOut(position: Vector3, now: number)
	outAt = position
	outUntil = now + OccupantConstants.LIGHTS_OUT_SECONDS
end

--[=[
	A pressure tier rose: every light flickers for TIER_FLICKER_SECONDS.
]=]
function OccupantTellSystem.flickerAll(now: number)
	flickerUntil = now + OccupantConstants.TIER_FLICKER_SECONDS
end

return OccupantTellSystem
