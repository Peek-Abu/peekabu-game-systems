--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))

local AdminServiceClient = {}
AdminServiceClient.dependencies = {} :: { string }

--[=[
	Initializes the AdminServiceClient and sets activation keys.
	@param _self AdminServiceClient -- The service instance
]=]
function AdminServiceClient.init(_self: AdminServiceClient)
	-- Set activation keys for Cmdr
	Cmdr:SetActivationKeys({ Enum.KeyCode.F2, Enum.KeyCode.Backquote })
end

type AdminServiceClient = typeof(AdminServiceClient)

return AdminServiceClient :: AdminServiceClient
