--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local Cmdr = require(ReplicatedStorage.Packages.Cmdr)

local log = Logger.new("AdminServiceServer")

local AdminServiceServer = {}
AdminServiceServer.dependencies = {} :: { string }

--[=[
	Initializes the AdminServiceServer and Cmdr.
	@param self AdminServiceServer -- The service instance
]=]
function AdminServiceServer.init(_self: AdminServiceServer)
	log:debug("Initializing Cmdr Admin System")
	
	-- Register commands folder
	local commandsFolder = ServerScriptService:FindFirstChild("Commands")
	if not commandsFolder then
		log:warn("Commands folder not found in ServerScriptService, skip registration")
	else
		Cmdr:RegisterCommandsIn(commandsFolder)
	end

	-- Setup default hooks (e.g., permission checks)
	Cmdr.Registry:RegisterHook("BeforeRun", function(context)
		if context.Group == "Admins" then
			-- In a real game, you would check player rank here
			-- For this boilerplate/demo, we allow all for now or check a specific list
			local player = context.Executor
			if not player then return "Command must be run by a player" end
			
			-- Placeholder: Always allow for now, but log it
			log:audit(`Player {player.Name} ({player.UserId}) is running admin command: {context.Name}`)
		end
		return nil
	end)
end

--[=[
	Starts the AdminServiceServer.
	@param self AdminServiceServer -- The service instance
]=]
function AdminServiceServer.start(_self: AdminServiceServer)
	log:debug("AdminServiceServer started")
end

type AdminServiceServer = typeof(AdminServiceServer)

return AdminServiceServer :: AdminServiceServer
