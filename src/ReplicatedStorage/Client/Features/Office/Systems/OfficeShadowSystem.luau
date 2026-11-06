--!strict
--[=[
	OfficeShadowSystem: turns shadows off on the office's small props on this client when OfficeShadowUtils says so
	(OfficeShadowUtils.MODE: "auto" = off at graphics 1-3 and on a phone left on Automatic), and back on when the player
	raises their graphics. It watches Workspace.CleanupCrewOffice (rebuilt every shift) and every part added to it;
	each part's own CastShadow is remembered, so turning shadows back on restores exactly what the server built.
	Client-local: nothing is sent or replicated.

	Spec-exempt shell (Instances, UserGameSettings, UserInputService); the decision is the specced OfficeShadowUtils.

	@class OfficeShadowSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local OfficeShadowUtils = require(ReplicatedStorage.Client.Features.Office.Utils.OfficeShadowUtils)

export type OfficeShadowState = {
	propShadows: boolean,
	turnedOff: number,
}

local OFFICE_NAME = "CleanupCrewOffice"

-- Parts whose shadow this system turned off, and what they had. Cleared when a new office arrives (the old one's
-- parts are gone), so nothing outlives its office.
local turnedOff: { [BasePart]: boolean } = {}
local propShadows = true
local connections: { RBXScriptConnection } = {}
local officeConnections: { RBXScriptConnection } = {}

local function gameSettings(): UserGameSettings
	return UserSettings():GetService("UserGameSettings")
end

local function decide(): boolean
	local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	return OfficeShadowUtils.propShadows(
		OfficeShadowUtils.MODE,
		OfficeShadowUtils.qualityOf(gameSettings().SavedQualityLevel),
		phone
	)
end

local function applyTo(instance: Instance)
	if not instance:IsA("BasePart") or not OfficeShadowUtils.smallProp(instance.Size) then
		return
	end
	if propShadows then
		local had = turnedOff[instance]
		if had ~= nil then
			instance.CastShadow = had
			turnedOff[instance] = nil
		end
	elseif instance.CastShadow then
		turnedOff[instance] = true
		instance.CastShadow = false
	end
end

local function watchOffice(office: Instance)
	for _, connection in officeConnections do
		connection:Disconnect()
	end
	table.clear(officeConnections)
	table.clear(turnedOff)
	for _, descendant in office:GetDescendants() do
		applyTo(descendant)
	end
	table.insert(officeConnections, office.DescendantAdded:Connect(applyTo))
end

local function refresh()
	local wanted = decide()
	if wanted == propShadows then
		return
	end
	propShadows = wanted
	local office = Workspace:FindFirstChild(OFFICE_NAME)
	if office ~= nil then
		for _, descendant in office:GetDescendants() do
			applyTo(descendant)
		end
	end
	if wanted then
		-- Anything left (outside the office now) gets its shadow back too.
		for part, had in turnedOff do
			part.CastShadow = had
		end
		table.clear(turnedOff)
	end
end

local OfficeShadowSystem = {}

function OfficeShadowSystem.start()
	propShadows = decide()
	local office = Workspace:FindFirstChild(OFFICE_NAME)
	if office ~= nil then
		watchOffice(office)
	end
	table.insert(
		connections,
		Workspace.ChildAdded:Connect(function(child)
			if child.Name == OFFICE_NAME then
				watchOffice(child)
			end
		end)
	)
	table.insert(connections, gameSettings():GetPropertyChangedSignal("SavedQualityLevel"):Connect(refresh))
end

function OfficeShadowSystem.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, connection in officeConnections do
		connection:Disconnect()
	end
	table.clear(officeConnections)
	for part, had in turnedOff do
		part.CastShadow = had
	end
	table.clear(turnedOff)
	propShadows = true
end

function OfficeShadowSystem.getState(): OfficeShadowState
	local count = 0
	for _ in turnedOff do
		count += 1
	end
	return { propShadows = propShadows, turnedOff = count }
end

return OfficeShadowSystem
