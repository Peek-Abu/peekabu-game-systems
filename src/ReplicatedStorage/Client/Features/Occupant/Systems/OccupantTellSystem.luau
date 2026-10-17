--!strict
--[=[
	OccupantTellSystem: Mr. Harlow's tells on this client (Cleanup Crew spec §4 "Tells", §7 "Tier up: lights
	flicker"). Every TELL_INTERVAL:
	- each office light (tag OfficeLight) within FLICKER_RADIUS of him flickers (OccupantTellRules.flicker);
	  for TIER_FLICKER_SECONDS after a tier rise every light flickers; for LIGHTS_OUT_SECONDS after a catch the
	  lights within LIGHTS_OUT_RADIUS of it are dark (the blackout is time-boxed on the tick, and `stop` clears
	  it, so no light stays dark).
	(The heartbeat and the screen's mood moved to OccupantDreadSystem, 2026-10-17.)
	Real light brightness and visible emitter colour fade together; fixture housings retain their authored material. Client-local only.

	Instance specs cover flicker restoration/cancellation; OccupantTellRules covers decisions and emitter selection.

	@class OccupantTellSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTellRules = require(ReplicatedStorage.Shared.Features.Occupant.Rules.OccupantTellRules)

local connection: RBXScriptConnection? = nil
type Fade = { tween: Tween?, completion: RBXScriptConnection? }
type Panel = { color: Color3, material: Enum.Material, fade: Fade, destroying: RBXScriptConnection? }
type Lamp = { brightness: number, enabled: boolean, fade: Fade, destroying: RBXScriptConnection? }
type Fixture =
	{ on: boolean, panels: { [BasePart]: Panel }, lamps: { [Light]: Lamp }, destroying: RBXScriptConnection? }
export type LightController = { setLit: (root: BasePart, on: boolean) -> (), clear: () -> () }
local outAt: Vector3? = nil
local outUntil = 0
local flickerUntil = 0

local function cancel(fade: Fade)
	if fade.completion ~= nil then
		fade.completion:Disconnect()
		fade.completion = nil
	end
	if fade.tween ~= nil then
		fade.tween:Cancel()
		fade.tween = nil
	end
end
local function newLightController(duration: number?): LightController
	local seconds = if duration ~= nil then math.max(0, duration) else 0.07
	local records: { [BasePart]: Fixture } = {}
	local function dispose(root: BasePart, restore: boolean)
		local record = records[root]
		if record == nil then
			return
		end
		records[root] = nil
		if record.destroying ~= nil then
			record.destroying:Disconnect()
		end
		for panel, saved in record.panels do
			cancel(saved.fade)
			if saved.destroying ~= nil then
				saved.destroying:Disconnect()
			end
			if restore and panel.Parent ~= nil then
				panel.Color, panel.Material = saved.color, saved.material
			end
		end
		for lamp, saved in record.lamps do
			cancel(saved.fade)
			if saved.destroying ~= nil then
				saved.destroying:Disconnect()
			end
			if restore and lamp.Parent ~= nil then
				lamp.Brightness, lamp.Enabled = saved.brightness, saved.enabled
			end
		end
	end
	local function fade(target: Instance, saved: Fade, goals: { [string]: number | Color3 }, done: () -> ())
		cancel(saved)
		if seconds <= 0 then
			done()
			return
		end
		local tween = TweenService:Create(target, TweenInfo.new(seconds, Enum.EasingStyle.Linear), goals)
		saved.tween = tween
		saved.completion = tween.Completed:Connect(function()
			if saved.tween ~= tween then
				return
			end
			cancel(saved)
			if target.Parent ~= nil then
				done()
			end
		end)
		tween:Play()
	end
	return {
		setLit = function(root, on)
			if root.Parent == nil then
				dispose(root, false)
				return
			end
			local record = records[root]
			if record == nil then
				-- An untouched lit fixture retains exactly the artist's state.
				if on then
					return
				end
				record = { on = true, panels = {}, lamps = {} }
				local function capture(instance: Instance)
					if instance:IsA("Light") then
						local saved: Lamp = { brightness = instance.Brightness, enabled = instance.Enabled, fade = {} }
						record.lamps[instance] = saved
						saved.destroying = instance.Destroying:Connect(function()
							cancel(saved.fade)
							if saved.destroying ~= nil then
								saved.destroying:Disconnect()
							end
							record.lamps[instance] = nil
						end)
					elseif
						instance:IsA("BasePart")
						and OccupantTellRules.isEmitter(
							instance.Material,
							instance:GetAttribute("OfficeLightEmitter") == true
						)
					then
						local saved: Panel = { color = instance.Color, material = instance.Material, fade = {} }
						record.panels[instance] = saved
						saved.destroying = instance.Destroying:Connect(function()
							cancel(saved.fade)
							if saved.destroying ~= nil then
								saved.destroying:Disconnect()
							end
							record.panels[instance] = nil
						end)
					end
				end
				capture(root)
				for _, instance in root:GetDescendants() do
					capture(instance)
				end
				records[root] = record
				record.destroying = root.Destroying:Connect(function()
					dispose(root, false)
				end)
			end
			if record.on == on then
				return
			end
			record.on = on
			for panel, saved in record.panels do
				if panel.Parent == nil then
					cancel(saved.fade)
					record.panels[panel] = nil
					continue
				end
				local color = if on then saved.color else saved.color:Lerp(Color3.new(0, 0, 0), 0.94)
				panel.Material = if on then saved.material else Enum.Material.SmoothPlastic
				fade(panel, saved.fade, { Color = color }, function()
					panel.Color = color
				end)
			end
			for lamp, saved in record.lamps do
				if lamp.Parent == nil then
					cancel(saved.fade)
					record.lamps[lamp] = nil
					continue
				end
				local brightness = if on then saved.brightness else 0
				lamp.Enabled = saved.enabled
				fade(lamp, saved.fade, { Brightness = brightness }, function()
					lamp.Brightness, lamp.Enabled = brightness, on and saved.enabled
				end)
			end
		end,
		clear = function()
			for root in records do
				dispose(root, true)
			end
		end,
	}
end
local lights = newLightController(nil)

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
			lights.setLit(instance, on)
		end
	end
end

local OccupantTellSystem = { newLightController = newLightController }

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
	end)
end

--[=[
	Stops the tells and puts everything back: every light we darkened is lit again, the blackout and tier
	flicker are cancelled.
]=]
function OccupantTellSystem.stop()
	local current = connection
	if current ~= nil then
		current:Disconnect()
		connection = nil
	end
	outAt = nil
	outUntil = 0
	flickerUntil = 0
	lights.clear()
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
