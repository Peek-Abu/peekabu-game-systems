--!strict
--[=[
	EmployeeStatSystem: puts a player's five stat bars on their character (docs/superpowers/specs/
	2026-11-03-employee-stat-effects-design.md). EmployeeServiceServer calls `apply` on every character it builds,
	before the character is assigned, so nothing has read its speed yet:

	- writes the bars as the character's stat attributes (EmployeeConstants.STAT_ATTRIBUTES), which the owners read
	  (EmployeeStatFormulas.barsOn): Sprint, Cargo's load, Vacuum and Cargo's grime;
	- scales the plain walk (the Humanoid's WalkSpeed, the base every speed writer reads back) by Speed. Applied again,
	  it moves the walk from the bars on the character to the new ones, so Speed is never scaled in twice.

	Server-written, so a client cannot change the server's copy.

	@class EmployeeStatSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local EmployeeStatFormulas = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeeStatFormulas)

type Stat = EmployeeProfileRegistry.Stat

local EmployeeStatSystem = {}

function EmployeeStatSystem.apply(character: Model, bars: { [Stat]: number })
	local before = EmployeeStatFormulas.effect("speed", EmployeeStatFormulas.barsOn(character, "speed"))
	for _, stat: Stat in EmployeeProfileRegistry.STATS do
		character:SetAttribute(EmployeeConstants.STAT_ATTRIBUTES[stat], EmployeeStatFormulas.barsFrom(bars[stat]))
	end
	local after = EmployeeStatFormulas.effect("speed", EmployeeStatFormulas.barsOn(character, "speed"))
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and after ~= before then
		humanoid.WalkSpeed = humanoid.WalkSpeed / before * after
	end
end

return EmployeeStatSystem
