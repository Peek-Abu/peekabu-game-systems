--!strict
--[=[
	CarryPushSystem: a pushed item keeps its place in front of the carrier's chest (cosmetic, client-only, on every
	client).

	A pushed item stands on the floor on the carrier's root (it must not bob with the walk), joined by a Motor6D tagged
	CarryConstants.PUSH_TAG (CarryServiceServer, AnimationCarrySystem.mount); the carrier's hands are re-reached onto
	it every frame by IK. A walk that carries the torso forward of the root (a stock R15's walk leans it a stud
	forward) would leave the hands too close to reach naturally, so each step slides the joint level along the floor by
	how far the UpperTorso is from its rest place (the joint's CarryConstants.TORSO_REST_ATTRIBUTE):
	CarryFormulas.pushFollow. The owner calls `step` in RunService.PreAnimation, so that frame's IK reaches the item
	where it now is. The server never writes Transform, so nothing authoritative moves.

	@class CarryPushSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CarryFormulas = require(ReplicatedStorage.Shared.Features.Carry.Utils.CarryFormulas)

export type CarryPushState = { tracked: number }

export type CarryPushSystem = {
	-- Starts sliding a pushed item's joint; returns the release (which puts the joint back at rest).
	track: (motor: Motor6D) -> () -> (),
	step: () -> (),
	getState: () -> CarryPushState,
}

local CarryPushSystem = {}

function CarryPushSystem.new(): CarryPushSystem
	local tracked: { [Motor6D]: boolean } = {}

	return {
		track = function(motor)
			tracked[motor] = true
			return function()
				tracked[motor] = nil
				motor.Transform = CFrame.identity
			end
		end,

		step = function()
			for motor in tracked do
				local root = motor.Part0
				local rest = motor:GetAttribute(CarryConstants.TORSO_REST_ATTRIBUTE)
				local character = if root ~= nil then root.Parent else nil
				local torso = if character ~= nil then character:FindFirstChild("UpperTorso") else nil
				if root == nil or typeof(rest) ~= "Vector3" or torso == nil or not torso:IsA("BasePart") then
					continue
				end
				motor.Transform =
					CarryFormulas.pushFollow(root.CFrame:PointToObjectSpace(torso.Position) - rest, motor.C0)
			end
		end,

		getState = function()
			local count = 0
			for _ in tracked do
				count += 1
			end
			return { tracked = count }
		end,
	}
end

return CarryPushSystem
