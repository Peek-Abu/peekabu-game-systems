--!strict
--[=[
	CrouchServiceClient: the local side of crouching. Holding the Input action `crouch` (Left Ctrl; C is Hide's), or
	toggling with `crouchToggle` (gamepad B) or the phone's CROUCH button (`toggle`), tells the server whether the
	player wants to crouch (CrouchRequestUtils: held or toggled; a toggle follows the server's word); the server
	decides and sets the speed and the character's Crouching attribute.

	From that attribute, on the local character: CrouchStore (the CROUCH button lights while crouched) and the camera,
	lowered CAMERA_DROP studs through Humanoid.CameraOffset, eased. The crouch poses (Animate's locomotion binding)
	and the quiet crouch gait (Footstep) read the same attribute themselves, on every character.

	Spec-exempt shell (Input, ByteNet, attributes, the camera offset); the decisions are the specced CrouchRequestUtils
	and the server's CrouchRules.

	@class CrouchServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CrouchConstants = require(ReplicatedStorage.Shared.Features.Crouch.Data.CrouchConstants)
local CrouchEvents = require(ReplicatedStorage.Shared.Features.Crouch.Net.CrouchEvents)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local CrouchStore = require(ReplicatedStorage.Client.Features.Crouch.State.CrouchStore)
local CrouchRequestUtils = require(ReplicatedStorage.Client.Features.Crouch.Utils.CrouchRequestUtils)

local player = Players.LocalPlayer
local stoppers: { () -> () } = {}
local request = CrouchRequestUtils.fresh()
local sent = false
-- The server's word as last seen on the local character.
local crouched = false
-- The camera drop applied now (studs, 0 = none written).
local drop = 0

local function send()
	local wanted = CrouchRequestUtils.wanted(request)
	if wanted ~= sent then
		sent = wanted
		CrouchEvents.packets.Crouch.send(wanted)
	end
end

local function readCrouched(): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute(CrouchConstants.CROUCHING_ATTRIBUTE) == true
end

-- The server's attribute changed (or a frame passed): mirror it, and let a toggle follow it.
local function settle()
	local now = readCrouched()
	local was = crouched
	crouched = now
	if was ~= now then
		CrouchStore.apply(now)
	end
	request = CrouchRequestUtils.settle(request, was, now, os.clock())
	send()
end

-- Eases the local camera toward its crouch drop; writes nothing once settled at standing height.
local function easeCamera(dt: number)
	local target = if crouched then CrouchConstants.CAMERA_DROP else 0
	if drop == target then
		return
	end
	local alpha = 1 - math.exp(-dt / CrouchConstants.CAMERA_EASE)
	drop += (target - drop) * alpha
	if math.abs(target - drop) < 0.005 then
		drop = target
	end
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid ~= nil then
		humanoid.CameraOffset = Vector3.new(0, -drop, 0)
	end
end

export type CrouchServiceClient = {
	dependencies: { string },
	init: (self: CrouchServiceClient) -> (),
	start: (self: CrouchServiceClient) -> (),
	stop: (self: CrouchServiceClient) -> (),
	getState: (self: CrouchServiceClient) -> { [string]: any },
	toggle: (self: CrouchServiceClient) -> (),
}

local CrouchServiceClient: CrouchServiceClient = {
	dependencies = { "InputServiceClient" },

	init = function(_self)
		if not InputActionRegistry.has(CrouchConstants.ACTION) then
			InputActionRegistry.register(CrouchConstants.ACTION, {
				context = "gameplay",
				bindings = { keyboard = { CrouchConstants.KEYBOARD_KEY } },
				description = "Crouch while held",
			})
		end
		if not InputActionRegistry.has(CrouchConstants.TOGGLE_ACTION) then
			InputActionRegistry.register(CrouchConstants.TOGGLE_ACTION, {
				context = "gameplay",
				bindings = { gamepad = { CrouchConstants.GAMEPAD_KEY } },
				description = "Crouch on / off",
			})
		end
	end,

	start = function(self)
		local unbindHold = InputServiceClient:bind(CrouchConstants.ACTION, function(phase)
			request = CrouchRequestUtils.hold(request, phase == "begin")
			send()
		end)
		local unbindToggle = InputServiceClient:bind(CrouchConstants.TOGGLE_ACTION, function(phase)
			if phase == "begin" then
				self:toggle()
			end
		end)
		local attributeChanged: RBXScriptConnection? = nil
		local function watch(character: Model?)
			if attributeChanged ~= nil then
				attributeChanged:Disconnect()
				attributeChanged = nil
			end
			-- A fresh body stands, with its camera at standing height; a toggle does not carry over.
			request = CrouchRequestUtils.hold(CrouchRequestUtils.fresh(), request.held)
			drop = 0
			crouched = false
			CrouchStore.apply(false)
			if character ~= nil then
				attributeChanged =
					character:GetAttributeChangedSignal(CrouchConstants.CROUCHING_ATTRIBUTE):Connect(settle)
			end
			settle()
		end
		local added = player.CharacterAdded:Connect(watch)
		local frame = RunService.Heartbeat:Connect(function(dt: number)
			-- A toggle the server never honoured times out here.
			if request.toggled and not crouched then
				settle()
			end
			easeCamera(dt)
		end)
		watch(player.Character)
		table.insert(stoppers, function()
			unbindHold()
			unbindToggle()
			added:Disconnect()
			frame:Disconnect()
			if attributeChanged ~= nil then
				attributeChanged:Disconnect()
				attributeChanged = nil
			end
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		request = CrouchRequestUtils.fresh()
		send()
	end,

	--[=[
		The crouch toggle (gamepad B, the phone's CROUCH button): on when standing, off when crouched.
	]=]
	toggle = function(_self)
		request = CrouchRequestUtils.toggle(request, crouched, os.clock())
		send()
	end,

	getState = function(_self)
		return {
			held = request.held,
			toggled = request.toggled,
			sent = sent,
			crouching = crouched,
			cameraDrop = drop,
		}
	end,
}

return CrouchServiceClient
