--!strict
--[=[
	VoiceServiceServer (R5 spec 2026-10-05 §2.2): one `AudioDeviceInput` per player, named `VoiceInput`,
	`.Player` set, parented to the Player — the server must create it for it to replicate, and the engine
	streams that player's microphone into it. Each client wires the inputs of OTHER players to their puppet
	heads (VoiceServiceClient). No speaker parts, so no position ever leaves the server (CP3).

	At start it creates inputs for all current and future players FIRST, then checks the place settings
	voice and chat depend on (VoiceSettingsCheck) and logs an error per wrong one. The settings check never
	blocks voice input creation.

	Spec-exempt shell (Players, Instances); its core VoiceSettingsCheck is specced.

	@class VoiceServiceServer
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local VoiceSettingsCheck = require(ServerScriptService.Features.Voice.Rules.VoiceSettingsCheck)

local INPUT_NAME = "VoiceInput"

local log = Logger.new("VoiceServiceServer")
local janitor = Janitor.new()
local inputs: { [Player]: AudioDeviceInput } = {}
local settingsProblems: { string } = {}

local function addInput(player: Player)
	if inputs[player] then
		return
	end
	local input = Instance.new("AudioDeviceInput")
	input.Name = INPUT_NAME
	input.Player = player
	input.Parent = player
	inputs[player] = input
end

export type VoiceServiceServer = {
	dependencies: { string },
	init: (self: VoiceServiceServer) -> (),
	start: (self: VoiceServiceServer) -> (),
	stop: (self: VoiceServiceServer) -> (),
	getState: (self: VoiceServiceServer) -> { inputs: number, settingsProblems: { string } },
}

local VoiceServiceServer: VoiceServiceServer = {
	dependencies = {},

	init = function(_self)
		log:debug("VoiceServiceServer initialized")
	end,

	start = function(_self)
		janitor:Add(Players.PlayerAdded:Connect(addInput), "Disconnect")
		janitor:Add(
			Players.PlayerRemoving:Connect(function(player: Player)
				inputs[player] = nil -- destroyed with the Player
			end),
			"Disconnect"
		)
		for _, player in Players:GetPlayers() do
			addInput(player)
		end
		settingsProblems = VoiceSettingsCheck.problems(VoiceSettingsCheck.read())
		for _, problem in settingsProblems do
			log:error(problem)
		end
	end,

	stop = function(_self)
		janitor:Cleanup()
		for _, input in inputs do
			input:Destroy()
		end
		table.clear(inputs)
	end,

	getState = function(_self)
		local count = 0
		for _ in inputs do
			count += 1
		end
		return { inputs = count, settingsProblems = table.clone(settingsProblems) }
	end,
}

return VoiceServiceServer
