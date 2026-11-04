--!strict
--[=[
	EmployeeLocomotionUtils: turns an employee's `locomotion` entry (EmployeeRegistry) into the locomotion
	core's config, so an employee character plays its own idle/walk/run (and crouch idle / crouch walk, when it
	has both) with strides scaled to its clips' planted speeds; the worn skin's own idle and fidget stand in for the
	employee's when it has them (EmployeeSkinRules, owner 2026-11-03). Used by `StarterCharacterScripts/Animate.client.luau` when it binds a character.

	@class EmployeeLocomotionUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationLocomotionSystem = require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationLocomotionSystem)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeeSkinRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeSkinRules)

type Config = AnimationLocomotionSystem.Config

local EmployeeLocomotionUtils = {}

--[=[
	The locomotion config for `def` worn in `skin` (its showcase idle stands in for the idle), or nil when the employee
	uses the stock set.
	@param def EmployeeRegistry.EmployeeDef
	@param skin string? -- the worn skin key
	@return Config?
]=]
function EmployeeLocomotionUtils.fromDef(def: EmployeeRegistry.EmployeeDef, skin: string?): Config?
	local locomotion = def.locomotion
	if locomotion == nil then
		return nil
	end
	local idle = EmployeeSkinRules.idleOf(def, skin) or locomotion.idle
	local poseIds: { [string]: string } = { idle = idle, walk = locomotion.walk, run = locomotion.run }
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
	The fidget clips (AnimationRegistry keys) of the employee a character's EmployeeName attribute names, worn in the
	skin its EmployeeSkin attribute names (EmployeeSkinRules `fidgetOf`); empty for a non-employee, an unknown name, or
	one without a fidget.
	@param name unknown -- the attribute value (untrusted type)
	@param skin unknown -- the skin attribute value (untrusted type); nil or a non-string = the employee's own
	@return { string }
]=]
function EmployeeLocomotionUtils.fidgetsFor(name: unknown, skin: unknown?): { string }
	local def = if type(name) == "string" then EmployeeRegistry.get(name) else nil
	local fidget = if def ~= nil
		then EmployeeSkinRules.fidgetOf(def, if type(skin) == "string" then skin else nil)
		else nil
	return if fidget ~= nil then { fidget } else {}
end

--[=[
	The locomotion config for the employee a character's EmployeeName attribute names, worn in the skin its
	EmployeeSkin attribute names; nil for a non-employee, an unknown name, or an employee without its own set.
	@param name unknown -- the attribute value (untrusted type)
	@param skin unknown -- the skin attribute value (untrusted type); nil or a non-string = the employee's own idle
	@return Config?
]=]
function EmployeeLocomotionUtils.forName(name: unknown, skin: unknown?): Config?
	if type(name) ~= "string" then
		return nil
	end
	local def = EmployeeRegistry.get(name)
	return if def ~= nil
		then EmployeeLocomotionUtils.fromDef(def, if type(skin) == "string" then skin else nil)
		else nil
end

return EmployeeLocomotionUtils
