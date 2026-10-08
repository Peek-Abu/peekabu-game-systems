--!nocheck
-- `--!nocheck` (not `--!strict`): this file requires `CmdrClient`, which Cmdr replicates to
-- ReplicatedStorage at RUNTIME. It is not present in the static sourcemap, so luau-lsp analyze
-- reports "Unknown require: game/ReplicatedStorage/CmdrClient". There is no clean Cmdr client
-- type to assert against and no per-line suppression in luau-lsp, so we opt this glue file out of
-- analysis entirely rather than cast to `any`. Only Cmdr client bootstrap belongs in this file.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
		Boots the Cmdr client and sets its activation keys.
		@param _self AdminServiceClient -- The service instance
	]=]
	init = function(_self)
		-- Character replication R2: no engine character ever spawns, so the engine never copies StarterGui
		-- (where Cmdr keeps its GUI template) into PlayerGui. CmdrClient's own clone is therefore the only
		-- Cmdr GUI, and there is no copy to wait for (the old wait raced the engine copy: evaera/Cmdr#125).
		--
		-- Runs in a task so init() stays non-blocking. Custom arg types are registered by the server
		-- (`Cmdr:RegisterTypesIn`); CmdrClient auto-registers the replicated types on startup.
		task.spawn(function()
			local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))
			Cmdr:SetActivationKeys({ Enum.KeyCode.F2, Enum.KeyCode.Backquote })
		end)
	end,
}

return AdminServiceClient
