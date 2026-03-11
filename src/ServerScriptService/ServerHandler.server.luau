--!strict
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)
local PlayerDataConstants = require(ServerScriptService.Modules.Constants.PlayerDataConstants)

-- Register all server services
local Services = ServerScriptService.Services
for _, ServerService in Services:GetDescendants() do
	if
		ServerService:IsA("ModuleScript")
		and ServerService.Name:match("Service")
		and ServerService.Name:match("Server$")
	then
		local module = require(ServerService)
		ServiceController:register(ServerService.Name, module)
	end
end

-- Initialize Game Data definitions
local GameItems = require(ReplicatedStorage.Shared.Modules.GameItems)
GameItems.init()

-- Initialize services (PlayerDataServiceServer needs config, others don't)
ServiceController:initService("PlayerDataServiceServer", {
	storeName = RunService:IsStudio() and "PlayerStore" or "PlayerStoreMock",
	useMock = true,
	template = PlayerDataConstants.PROFILE_TEMPLATE,
})
ServiceController:initAll()

-- Start all services (safe to use other services now)
ServiceController:startAll()

--[=[
	Cmdr Integration:
	Admin commands are now handled by Cmdr via AdminServiceServer.
	Legacy debug BindableFunctions have been removed in favor of this robust system.
]=]

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local log = Logger.new("ServerHandler")
log:info("Server systems initialized successfully")
