--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)

-- Initialize Game Data definitions. ItemDefinitions is a runtime registry that lives in each
-- machine's memory, so the client must populate it too: when the server broadcasts an inventory
-- delta the client applies it via InventoryUtils, which asserts the itemType is registered. Without
-- this, every server-granted item throws `invalid item type` on the client after the server succeeds.
local GameItems = require(ReplicatedStorage.Shared.Modules.GameItems)
GameItems.init()

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
	elseif
		ClientService:IsA("ModuleScript")
		and ClientService.Name:match("Service")
		and not ClientService.Name:match("%.spec$")
	then
		-- Contains "Service" but lacks the realm suffix: almost certainly a typo'd service module
		-- that discovery would otherwise skip SILENTLY. Spec files are excluded (they legitimately
		-- end ".spec"); helper modules that trip this should be renamed, or widen this check if it
		-- becomes noisy.
		warn(
			`[ClientHandler] "{ClientService:GetFullName()}" matches "Service" but not "Client$" — skipped by discovery. Rename it if it is a service.`
		)
	end
end

-- Initialize all services (no service should require another here)
ServiceController:initAll()

-- Start all services (safe to use other services now)
ServiceController:startAll()

-- Report actual boot health, mirroring ServerHandler: startAll() isolates a throwing start() to a
-- warn, so sweep for recorded failures before declaring the client boot good.
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local log = Logger.new("ClientHandler")
local bootFailures = ServiceController:getBootFailures()
if #bootFailures > 0 then
	log:error(`Client boot completed with {#bootFailures} failed service(s): {table.concat(bootFailures, ", ")}`)
else
	log:info("Client systems initialized successfully")
end
