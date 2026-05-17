--!strict
--[=[
	Handles character animation setup for the local player.

	Responsibilities:
	  - Ensures the Animate script is present on the character whenever
	    player.Character is set (including via CharacterModelManager.morphPlayer,
	    which sets player.Character directly without triggering LoadCharacter, so
	    StarterCharacterScripts are NOT automatically copied).
	  - Keeps camera.CameraSubject pointing at the correct Humanoid after a
	    character swap so the follow-cam continues to work.

	@class AnimationServiceClient
]=]

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

local log = Logger.new("AnimationService")

local AnimationServiceClient = {}
AnimationServiceClient.dependencies = {} :: { string }

local janitor = Janitor.new()
local player = Players.LocalPlayer

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function ensureAnimateScript(character: Model)
	if character:FindFirstChild("Animate") then return end

	-- Wait briefly for replication to settle before deciding to clone
	task.wait(0.1)
	if character:FindFirstChild("Animate") then return end

	local scs = StarterPlayer:FindFirstChild("StarterCharacterScripts")
	local animateTemplate = scs and scs:FindFirstChild("Animate")
	if animateTemplate then
		local cloned = animateTemplate:Clone()
		cloned.Enabled = false
		cloned.Parent = character
		task.defer(function()
			cloned.Enabled = true
		end)
		log:info("Cloned Animate script onto new character")
	else
		log:warn("No Animate template found in StarterCharacterScripts")
	end
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	-- Keep CameraSubject pointing at the new Humanoid; Roblox doesn't always
	-- update this automatically when player.Character is set directly.
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraSubject = humanoid
	end

	ensureAnimateScript(character)
end

-- ── Service Lifecycle ────────────────────────────────────────────────────────

function AnimationServiceClient.init(_self: any)
	janitor:Add(player.CharacterAdded:Connect(function(character)
		task.spawn(onCharacterAdded, character)
	end), "Disconnect")

	-- Handle character that is already loaded when the service starts
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	log:info("AnimationServiceClient initialized")
end

function AnimationServiceClient.stop(_self: any)
	janitor:Cleanup()
end

return AnimationServiceClient
