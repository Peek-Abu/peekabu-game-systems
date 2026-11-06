--!strict
--[=[
	VacuumAimSystem: where each holder looks, for every client's aim layer (VacuumMotionSystem). Purely visual: suction
	targeting never reads it. A client sends its camera's look pitch (VacuumEvents.Aim) and its look yaw relative to its
	body (VacuumEvents.AimYaw, vacuum feel pass 2026-11-06), each quantised to a byte; each is decoded
	(VacuumMotionFormulas, refusing anything a client cannot send), rate limited per player, and put on the character
	(VacuumMotionConstants.AIM_ATTRIBUTE / AIM_YAW_ATTRIBUTE) for every client to read.

	Spec-exempt shell (ByteNet, Players, attributes); the decoding is the specced VacuumMotionFormulas.

	@class VacuumAimSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumMotionConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)
local VacuumEvents = require(ReplicatedStorage.Shared.Features.Vacuum.Net.VacuumEvents)
local VacuumMotionFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMotionFormulas)

local VacuumAimSystem = {}

-- When each player's last pitch and yaw were taken (rate limited).
local takenAt: { [string]: { [Player]: number } } = { pitch = {}, yaw = {} }

-- Puts a decoded look on `player`'s character, at most about aim.rate times a second per kind.
local function take(kind: string, player: Player, degrees: number?, attribute: string)
	local now = os.clock()
	local last = takenAt[kind][player]
	if last ~= nil and now - last < 0.8 / VacuumMotionConstants.aim.rate then
		return
	end
	local character = player.Character
	if degrees == nil or character == nil then
		return
	end
	takenAt[kind][player] = now
	character:SetAttribute(attribute, degrees)
end

--[=[
	Listens for both looks; returns the stopper.
]=]
function VacuumAimSystem.start(): () -> ()
	local pitch = VacuumEvents.packets.Aim.listen(function(byte: number, player: Player?)
		if player ~= nil then
			take("pitch", player, VacuumMotionFormulas.decodeAim(byte), VacuumMotionConstants.AIM_ATTRIBUTE)
		end
	end)
	local yaw = VacuumEvents.packets.AimYaw.listen(function(byte: number, player: Player?)
		if player ~= nil then
			take("yaw", player, VacuumMotionFormulas.decodeYaw(byte), VacuumMotionConstants.AIM_YAW_ATTRIBUTE)
		end
	end)
	local leaving = Players.PlayerRemoving:Connect(function(player: Player)
		takenAt.pitch[player] = nil
		takenAt.yaw[player] = nil
	end)
	return function()
		pitch()
		yaw()
		leaving:Disconnect()
		table.clear(takenAt.pitch)
		table.clear(takenAt.yaw)
	end
end

return VacuumAimSystem
