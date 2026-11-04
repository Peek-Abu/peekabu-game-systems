--!strict
--[=[
	Animate: the character's locomotion entry point.

	⚠ THE NAME IS LOAD-BEARING. The engine auto-inserts its default Animate script into any character
	that lacks a script named "Animate" — this script existing under that exact name is what suppresses
	the stock one. Rename it and every character grows a second, engine-owned animator.

	Thin by design: every decision (pose selection, fades, speed scales, the kill switch) lives in the
	specced AnimationLocomotionSystem core, bound to this character's Humanoid by
	AnimationLocomotionHumanoidSystem. This script only owns the lifetime: StarterCharacterScripts runs a
	fresh copy per character, and the binding is released when the character goes.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationLocomotionHumanoidSystem =
	require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationLocomotionHumanoidSystem)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CrouchConstants = require(ReplicatedStorage.Shared.Features.Crouch.Data.CrouchConstants)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeLocomotionUtils = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeeLocomotionUtils)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)

local character = script.Parent
assert(character ~= nil and character:IsA("Model"), "[Animate] script must be a direct child of a character Model")

-- The Humanoid may replicate a frame after this script starts.
character:WaitForChild("Humanoid")

-- An employee character (Cleanup Crew) plays its own idle/walk/run when its EmployeeRegistry entry has
-- them; the server stamps the attribute on the StarterCharacter template, so it is here at spawn. The worn skin's own
-- idle and fidget stand in when it has them (owner, 2026-11-03: in a shift too); the server dresses the character
-- just after it spawns, so the skin attribute may land a moment later and rebinds.
local employee = character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE)

-- What stops a fidget beside a move, a crouch or an Action clip (a Gloom nearby does not: owner, 2026-10-29).
local function fidgetBlocked(): boolean
	local player = Players.LocalPlayer
	if player:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE) ~= nil then
		return true
	end
	local entry = StateSyncClientStore.publicPlayers()[StateSyncConstants.publicEntryKey(player.UserId)]
	return entry ~= nil
		and (
			entry[CarryConstants.PUBLIC_FIELD] ~= nil
			or entry[ShiftConstants.PUBLIC_VACUUMING] == true
			or entry[DeathConstants.PUBLIC_FIELD] == true
		)
end

-- Crouched (the server's Crouching attribute): the employee's crouch idle / walk.
local unbind: (() -> ())? = nil
local function bind()
	local release = unbind
	if release ~= nil then
		release()
	end
	local skin = character:GetAttribute(EmployeeConstants.SKIN_ATTRIBUTE)
	unbind = AnimationLocomotionHumanoidSystem.bind(character, EmployeeLocomotionUtils.forName(employee, skin), {
		crouchAttribute = CrouchConstants.CROUCHING_ATTRIBUTE,
		fidgets = EmployeeLocomotionUtils.fidgetsFor(employee, skin),
		fidgetBlocked = fidgetBlocked,
	})
end
bind()
local skinChanged = character:GetAttributeChangedSignal(EmployeeConstants.SKIN_ATTRIBUTE):Connect(bind)
local function releaseAll()
	skinChanged:Disconnect()
	local release = unbind
	if release ~= nil then
		release()
		unbind = nil
	end
end
character.Destroying:Connect(releaseAll)
script.Destroying:Connect(releaseAll)
