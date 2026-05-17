local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)
local Roact = require(ReplicatedStorage.Packages.Roact)
local BattleUI = require(ReplicatedStorage.Client.UI.BattleUI)
local BattleWorldUI = require(ReplicatedStorage.Client.UI.BattleWorldUI)
local CharacterSelectUI = require(ReplicatedStorage.Client.UI.CharacterSelectUI)

-- Register all client services
local Services = ReplicatedStorage.Client.Services
for _, ClientService in Services:GetDescendants() do
	if
		ClientService:IsA("ModuleScript")
		and ClientService.Name:match("Service")
		and ClientService.Name:match("Client$")
	then
		local module = require(ClientService)
		ServiceController:register(ClientService.Name, module)
	end
end

-- Initialize all services (no service should require another here)
ServiceController:initAll()

-- Start all services (safe to use other services now)
ServiceController:startAll()

local player = Players.LocalPlayer

-- Mount UI
local playerGui = player:WaitForChild("PlayerGui")
local battleUIHandle = Roact.mount(Roact.createElement(BattleUI), playerGui, "BattleUI")
local worldUIHandle = Roact.mount(Roact.createElement(BattleWorldUI), playerGui, "BattleWorldUI")
local selectUIHandle = Roact.mount(Roact.createElement(CharacterSelectUI), playerGui, "CharacterSelectUI")

print("[ClientHandler] Battle UI and Character Select UI mounted")

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		Roact.unmount(battleUIHandle)
		Roact.unmount(worldUIHandle)
		Roact.unmount(selectUIHandle)
	end
end)
