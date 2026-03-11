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
		local module = require(ClientService)
		ServiceController:register(ClientService.Name, module)
	end
end

-- Initialize all services (no service should require another here)
ServiceController:initAll()

-- Start all services (safe to use other services now)
ServiceController:startAll()
