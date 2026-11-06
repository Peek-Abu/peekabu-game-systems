--!strict
--[=[
	FilmServiceClient: the trailer filming tools on this client, for admins only (AdminRules.isAdmin, the same
	allowlist the Cmdr gate uses; Studio counts as admin).

	- F7 (FilmConstants.HIDE_KEY) hides every screen, floating label and prompt, the Roblox core UI and the mouse
	  cursor (FilmHideSystem), and brings them back. The admin console (F2) stays usable, so a hidden UI can always be
	  restored. Ignored while typing (`gameProcessed`).

	Hiding your own UI changes nothing anyone else sees and nothing the server trusts; the staging commands that do
	change the game (`harlow`, `shiftovertime`, `filmlight`) are Cmdr's Admins group, which fails closed.

	Spec-exempt shell (input, core UI, prompts); the hide itself is the specced FilmHideSystem.

	@class FilmServiceClient
]=]

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

export type FilmServiceClient = {
	dependencies: { string },
	init: (self: FilmServiceClient) -> (),
	stop: (self: FilmServiceClient) -> (),
}

local FilmServiceClient: FilmServiceClient = {
	dependencies = {},

	--[=[
		Wires F7 to the hide, for admins only.
	]=]
	init = function(_self)
		-- Built on the first F7, so init never waits for the PlayerGui.
		local hide: FilmHideSystem.FilmHideSystem? = nil
		janitor:Add(function()
			if hide ~= nil then
				hide.show()
			end
		end, true)
		janitor:Add(
			UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
				if gameProcessed or input.KeyCode ~= FilmConstants.HIDE_KEY then
					return
				end
				if not AdminRules.isAdmin(Players.LocalPlayer) then
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
