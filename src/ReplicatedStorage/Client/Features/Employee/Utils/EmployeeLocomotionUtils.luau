--!strict
--[=[
	EmployeeLocomotionUtils: turns an employee's `locomotion` entry (EmployeeRegistry) into the locomotion
	core's config, so an employee character plays its own idle/walk/run (and crouch idle / crouch walk, when it
	has both) with strides scaled to its clips' planted speeds. Used by `StarterCharacterScripts/Animate.client.luau` when it binds a character.

	@class EmployeeLocomotionUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationLocomotionSystem = require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationLocomotionSystem)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

type Config = AnimationLocomotionSystem.Config

local EmployeeLocomotionUtils = {}

--[=[
	The locomotion config for `def`, or nil when the employee uses the stock set.
	@param def EmployeeRegistry.EmployeeDef
	@return Config?
]=]
function EmployeeLocomotionUtils.fromDef(def: EmployeeRegistry.EmployeeDef): Config?
	local locomotion = def.locomotion
	if locomotion == nil then
		return nil
	end
	local poseIds: { [string]: string } = { idle = locomotion.idle, walk = locomotion.walk, run = locomotion.run }
	-- Both crouch clips and their planted speed, or no crouch at all (the core then stays standing).
	local crouchIdle, crouchWalk = locomotion.crouchIdle, locomotion.crouchWalk
	local crouchPlanted = locomotion.crouchWalkPlantedSpeed
	local crouchScale: number? = nil
	if crouchIdle ~= nil and crouchWalk ~= nil and crouchPlanted ~= nil then
		poseIds.crouchidle = crouchIdle
		poseIds.crouchwalk = crouchWalk
		crouchScale = crouchPlanted * def.scale
	end
	local config: Config = {
		poseIds = poseIds,
		-- Planted speeds are measured on the template; a scaled rig's stride covers `scale` times the ground.
		walkScale = locomotion.walkPlantedSpeed * def.scale,
		runScale = locomotion.runPlantedSpeed * def.scale,
		minRate = locomotion.minRate,
		walkMaxRate = locomotion.walkMaxRate,
		runMaxRate = locomotion.runMaxRate,
		crouchScale = crouchScale,
		crouchMaxRate = if crouchScale ~= nil then locomotion.crouchWalkMaxRate else nil,
	}
	return config
end

--[=[
	The locomotion config for the employee a character's EmployeeName attribute names; nil for a
	non-employee, an unknown name, or an employee without its own set.
	@param name unknown -- the attribute value (untrusted type)
	@return Config?
]=]
function EmployeeLocomotionUtils.forName(name: unknown): Config?
	if type(name) ~= "string" then
		return nil
	end
	local def = EmployeeRegistry.get(name)
	return if def ~= nil then EmployeeLocomotionUtils.fromDef(def) else nil
end

return EmployeeLocomotionUtils
