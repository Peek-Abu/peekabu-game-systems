--!nocheck
-- `--!nocheck` (not `--!strict`): this file requires `CmdrClient`, which Cmdr replicates to
-- ReplicatedStorage at RUNTIME. It is not present in the static sourcemap, so luau-lsp analyze
-- reports "Unknown require: game/ReplicatedStorage/CmdrClient". There is no clean Cmdr client
-- type to assert against and no per-line suppression in luau-lsp, so we opt this glue file out of
-- analysis entirely rather than cast to `any`. Only Cmdr client bootstrap belongs in this file.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

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
		-- Defer requiring CmdrClient until AFTER Roblox has copied Cmdr's ScreenGui from
		-- StarterGui into our PlayerGui. Cmdr stores its GUI template in StarterGui, so the
		-- engine auto-copies it into PlayerGui on spawn; CmdrClient's own startup ALSO clones
		-- it there, but only if one isn't already present (its `FindFirstChild("Cmdr") == nil`
		-- guard). Requiring CmdrClient early loses that race, so BOTH land -> two identical Cmdr
		-- GUIs under PlayerGui. Waiting for the engine copy first makes Cmdr's guard see it and
		-- skip its clone: exactly one GUI. (Known upstream, closed as not-planned: evaera/Cmdr#125.)
		--
		-- Runs in a task so init() stays non-blocking; SetActivationKeys is only needed long
		-- before the player ever presses F2. Custom arg types (currencyType, itemType) are NOT
		-- registered here: the server registers them via `Cmdr:RegisterTypesIn`, Cmdr replicates
		-- them, and CmdrClient auto-registers replicated types on startup. One site, both peers.
		task.spawn(function()
			local playerGui = LocalPlayer:WaitForChild("PlayerGui")

			-- The StarterGui -> PlayerGui copy is triggered by the character spawning, so make
			-- sure a character exists before we wait for the copy to appear.
			if not LocalPlayer.Character then
				LocalPlayer.CharacterAdded:Wait()
			end

			-- Bounded wait: if the engine copy never lands (e.g. CharacterAutoLoads off), fall
			-- through and let CmdrClient's own clone be the single source rather than hang forever.
			-- The template's ResetOnSpawn = false means there is only ever one engine copy, so this
			-- fallback cannot reintroduce the duplicate.
			playerGui:WaitForChild("Cmdr", 10)

			local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))
			Cmdr:SetActivationKeys({ Enum.KeyCode.F2, Enum.KeyCode.Backquote })
		end)
	end,
}

return AdminServiceClient
