--!strict
--[=[
	HidePoseSystem: every hiding player shows the tucked huddle on this client (docs/superpowers/specs/
	2026-10-15-cleanup-crew-chase-kit-design.md §4), so crewmates see them crouched under the desk rather than standing
	through it. A player whose HideSpotId attribute is set folds in over TUCK_SECONDS; when it clears they unfold over
	UNTUCK_SECONDS. Every step (RunService.PreSimulation, the slot the engine documents for overriding Motor6D.Transform)
	the pose is laid over the animation on each posed joint (HidePoseFormulas.blend). The local player's own body is
	hidden from their peek camera (HideServiceClient), so this is what everyone else sees.

	Spec-exempt shell (Players, Motor6Ds, RunService); the pose and its easing are the specced HidePoseFormulas.

	@class HidePoseSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local HidePoseFormulas = require(ReplicatedStorage.Client.Features.Hide.Utils.HidePoseFormulas)

type Posed = { motor: Motor6D, target: CFrame }
type Fold = { tucking: boolean, since: number, character: Model?, joints: { Posed } }

local HidePoseSystem = {}

function HidePoseSystem.start(): () -> ()
	local targets = HidePoseFormulas.targets()
	local folds: { [Player]: Fold } = {}
	local connections: { RBXScriptConnection } = {}

	local function follow(player: Player)
		local function update()
			local hiding = type(player:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE)) == "string"
			local current = folds[player]
			if hiding and (current == nil or not current.tucking) then
				folds[player] = { tucking = true, since = os.clock(), character = nil, joints = {} }
			elseif not hiding and current ~= nil and current.tucking then
				folds[player] =
					{ tucking = false, since = os.clock(), character = current.character, joints = current.joints }
			end
		end
		table.insert(connections, player:GetAttributeChangedSignal(HideConstants.PLAYER_SPOT_ATTRIBUTE):Connect(update))
		update()
	end

	for _, player in Players:GetPlayers() do
		follow(player)
	end
	table.insert(connections, Players.PlayerAdded:Connect(follow))
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			folds[player] = nil
		end)
	)
	table.insert(
		connections,
		RunService.PreSimulation:Connect(function()
			local now = os.clock()
			for player, fold in folds do
				local weight = HidePoseFormulas.weight(now - fold.since, fold.tucking)
				if not fold.tucking and weight <= 0 then
					folds[player] = nil
					continue
				end
				local character = player.Character
				if character == nil then
					continue
				end
				-- The posed joints, found once per body.
				if fold.character ~= character then
					fold.character = character
					fold.joints = {}
					for _, joint in character:GetDescendants() do
						local target = if joint:IsA("Motor6D") then targets[joint.Name] else nil
						if joint:IsA("Motor6D") and target ~= nil then
							table.insert(fold.joints, { motor = joint, target = target })
						end
					end
				end
				for _, posed in fold.joints do
					posed.motor.Transform = HidePoseFormulas.blend(posed.motor.Transform, posed.target, weight)
				end
			end
		end)
	)

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(folds)
	end
end

return HidePoseSystem
