--!strict
--[=[
	FilmServiceClient: the trailer filming tools on this client, for admins only (AdminRules.isAdmin, the same
	allowlist the Cmdr gate uses; Studio counts as admin).

	- F6 (FilmConstants.HIDE_KEY) hides every screen, floating label and prompt, the Roblox core UI and the mouse
	  cursor (FilmHideSystem), and brings them back. The admin console (F2) stays usable, so a hidden UI can always be
	  restored. Ignored while typing (`gameProcessed`).
	- F8 (FilmConstants.CAMERA_KEY) turns the film camera on and off (FilmCameraSystem: fly, marks, glides, follow and
	  orbit). While it is on, the character and gameplay keys are silenced.

	Hiding your own UI changes nothing anyone else sees and nothing the server trusts; the staging commands that do
	change the game (`harlow`, `shiftovertime`, `filmlight`) are Cmdr's Admins group, which fails closed.

	Spec-exempt shell (input, core UI, prompts); the hide is the specced FilmHideSystem, the camera FilmCameraSystem.

	@class FilmServiceClient
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local AdminRules = require(ReplicatedStorage.Shared.Features.Admin.Rules.AdminRules)
local FilmConstants = require(ReplicatedStorage.Shared.Features.Film.Data.FilmConstants)
local FilmHideSystem = require(ReplicatedStorage.Client.Features.Film.Systems.FilmHideSystem)
local FilmCameraSystem = require(ReplicatedStorage.Client.Features.Film.Systems.FilmCameraSystem)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local InputControlsSystem = require(ReplicatedStorage.Client.Features.Input.Systems.InputControlsSystem)

local janitor = Janitor.new()

-- What the hide turned off outside the instance tree, to put back exactly: each core UI type, the prompt limit and
-- the mouse cursor.
local savedCore: { [Enum.CoreGuiType]: boolean } = {}
local savedPrompts = 0
local savedMouse = true

local function setOutside(hidden: boolean)
	if hidden then
		for _, coreType in Enum.CoreGuiType:GetEnumItems() do
			if coreType ~= Enum.CoreGuiType.All then
				savedCore[coreType] = StarterGui:GetCoreGuiEnabled(coreType)
			end
		end
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		savedPrompts = ProximityPromptService.MaxPromptsVisible
		ProximityPromptService.MaxPromptsVisible = 0
		savedMouse = UserInputService.MouseIconEnabled
		UserInputService.MouseIconEnabled = false
		return
	end
	for coreType, enabled in savedCore do
		StarterGui:SetCoreGuiEnabled(coreType, enabled)
	end
	table.clear(savedCore)
	ProximityPromptService.MaxPromptsVisible = savedPrompts
	UserInputService.MouseIconEnabled = savedMouse
end

-- The input context that silences gameplay while the film camera is on.
local silenceToken: number? = nil

local function silence(silenced: boolean)
	if silenced and silenceToken == nil then
		silenceToken = InputServiceClient:pushContext("ui", { sink = true })
		task.spawn(InputControlsSystem.setEnabled, false)
	elseif not silenced then
		local token = silenceToken
		if token ~= nil then
			InputServiceClient:removeContext(token)
			silenceToken = nil
		end
		task.spawn(InputControlsSystem.setEnabled, true)
	end
end

-- What the film camera can follow: Mr. Harlow first, then every player with a character.
local function targets(): { FilmCameraSystem.Target }
	local list: { FilmCameraSystem.Target } = {}
	for _, instance in CollectionService:GetTagged(OccupantConstants.TAG) do
		local root = if instance:IsA("Model") then instance:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			table.insert(list, { name = "Mr. Harlow", part = root })
		end
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			table.insert(list, { name = player.DisplayName, part = root })
		end
	end
	return list
end

export type FilmServiceClient = {
	dependencies: { string },
	init: (self: FilmServiceClient) -> (),
	stop: (self: FilmServiceClient) -> (),
}

local FilmServiceClient: FilmServiceClient = {
	dependencies = { "CameraServiceClient", "InputServiceClient" },

	--[=[
		Wires F6 to the hide and F8 to the film camera, for admins only.
	]=]
	init = function(_self)
		-- Built on the first F6, so init never waits for the PlayerGui.
		local hide: FilmHideSystem.FilmHideSystem? = nil
		local camera = FilmCameraSystem.new({
			pushMode = function(update)
				return CameraServiceClient:pushMode({ kind = "custom", update = update }, FilmConstants.CAMERA_PRIORITY)
			end,
			removeMode = function(token)
				CameraServiceClient:removeMode(token)
			end,
			silence = silence,
			targets = targets,
		})
		janitor:Add(function()
			if hide ~= nil then
				hide.show()
			end
			camera.stop()
		end, true)
		janitor:Add(
			UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
				if gameProcessed then
					return
				end
				if input.KeyCode ~= FilmConstants.HIDE_KEY and input.KeyCode ~= FilmConstants.CAMERA_KEY then
					return
				end
				if not AdminRules.isAdmin(Players.LocalPlayer) then
					return
				end
				if input.KeyCode == FilmConstants.CAMERA_KEY then
					camera.toggle()
					return
				end
				local current = hide
				if current == nil then
					local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
					if playerGui == nil then
						return
					end
					current = FilmHideSystem.new({
						roots = { playerGui, Workspace },
						keep = function(gui: LayerCollector): boolean
							return FilmConstants.KEEP_GUIS[gui.Name] == true
						end,
						onHidden = setOutside,
					})
					hide = current
				end
				if current ~= nil then
					current.toggle()
				end
			end),
			"Disconnect"
		)
	end,

	stop = function(_self)
		janitor:Cleanup()
	end,
}

return FilmServiceClient
