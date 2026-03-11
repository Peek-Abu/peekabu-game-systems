--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)

-- Register all client services
local Services = ReplicatedStorage.Client.Services
for _, ClientService in Services:GetDescendants() do
	if
		ClientService:IsA("ModuleScript")
		and ClientService.Name:match("Service")
		and ClientService.Name:match("Client$")
	then
		-- `ClientService` is a GetDescendants() loop variable, so luau-lsp cannot statically
		-- resolve this require ("Unknown require: unsupported path"). Assert the honest type at
		-- this dynamic-require boundary: every match here is a service ModuleScript, so its
		-- return IS a ServiceModule. This keeps the file type-checked and types register()'s arg.
		local module = require(ClientService) :: ServiceController.ServiceModule
		ServiceController:register(ClientService.Name, module)
	end
end

-- Initialize all services (no service should require another here)
ServiceController:initAll()

-- Start all services (safe to use other services now)
ServiceController:startAll()
