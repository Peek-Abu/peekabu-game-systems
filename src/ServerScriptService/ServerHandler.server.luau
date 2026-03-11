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
		-- `ServerService` is a GetDescendants() loop variable, so luau-lsp cannot statically
		-- resolve this require ("Unknown require: unsupported path"). Assert the honest type at
		-- this dynamic-require boundary: every match here is a service ModuleScript, so its
		-- return IS a ServiceModule. This keeps the file type-checked and types register()'s arg.
		local module = require(ServerService) :: ServiceController.ServiceModule
		ServiceController:register(ServerService.Name, module)
	end
end

-- Initialize Game Data definitions
local GameItems = require(ReplicatedStorage.Shared.Modules.GameItems)
GameItems.init()

-- Initialize services (PlayerDataServiceServer needs config, others don't)
ServiceController:initService("PlayerDataServiceServer", {
	storeName = "PlayerStore",
	-- Use ProfileStore's in-memory mock in Studio so test sessions never touch live
	-- data. In a published server this is false, so profiles persist to DataStore.
	useMock = RunService:IsStudio(),
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
