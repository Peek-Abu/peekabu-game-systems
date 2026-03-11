--!nocheck
-- `--!nocheck` (not `--!strict`): this file requires `CmdrClient`, which Cmdr replicates to
-- ReplicatedStorage at RUNTIME. It is not present in the static sourcemap, so luau-lsp analyze
-- reports "Unknown require: game/ReplicatedStorage/CmdrClient". There is no clean Cmdr client
-- type to assert against and no per-line suppression in luau-lsp, so we opt this 27-line glue
-- file out of analysis entirely rather than cast to `any`. Keep real logic out of this file.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.
]=]
export type AdminServiceClient = {
	dependencies: { string },

	init: (self: AdminServiceClient) -> (),
}

local AdminServiceClient: AdminServiceClient = {
	dependencies = {},

	--[=[
		Initializes the AdminServiceClient and sets activation keys.
		@param _self AdminServiceClient -- The service instance
	]=]
	init = function(_self)
		-- Set activation keys for Cmdr
		Cmdr:SetActivationKeys({ Enum.KeyCode.F2, Enum.KeyCode.Backquote })
	end,
}

return AdminServiceClient
