--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local Cmdr = require(ReplicatedStorage.Packages.Cmdr)
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)

local log = Logger.new("AdminServiceServer")

--[=[
	Admin allowlist. Add the UserIds you trust here, or replace `isAdmin` with a
	group-rank / DataStore lookup. SECURE BY DEFAULT: in a published server, anyone
	NOT in this list is denied every command in the "Admins" group. Studio sessions
	are always allowed so you can test commands without editing this list.
]=]
local ADMIN_USER_IDS: { [number]: boolean } = {
	[20661908] = true,
}

--[=[
	Returns whether a player may run commands in the "Admins" group.
	@param player Player -- The executing player
	@return boolean -- True if the player is an admin (or the session is in Studio)
]=]
local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return ADMIN_USER_IDS[player.UserId] == true
end

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	The module below is one annotated table literal (`local AdminServiceServer:
	AdminServiceServer = { ... }`). Annotating the literal makes Luau push each
	signature from this interface DOWN into the matching method body, so the methods
	need NO inline type annotations — `self` and every parameter are typed from here.
	Types live in exactly one place, and there are zero casts.
]=]
export type AdminServiceServer = {
	dependencies: { string },

	init: (self: AdminServiceServer) -> (),
	start: (self: AdminServiceServer) -> (),
}

local AdminServiceServer: AdminServiceServer = {
	dependencies = {},

	--[=[
		Initializes the AdminServiceServer and Cmdr.
		@param self AdminServiceServer -- The service instance
	]=]
	init = function(_self)
		log:debug("Initializing Cmdr Admin System")

		-- Register custom argument types BEFORE the commands that reference them. `currencyType`
		-- validates input against the live currency list and powers autocomplete, so commands
		-- receive a guaranteed-valid value (and can type their param as CurrencyType, no cast).
		Cmdr.Registry:RegisterType(
			"currencyType",
			Cmdr.Util.MakeEnumType("Currency", CurrencyConstants.getValidCurrencies())
		)

		-- Register commands folder
		local commandsFolder = ServerScriptService:FindFirstChild("Commands")
		if not commandsFolder then
			log:warn("Commands folder not found in ServerScriptService, skip registration")
		else
			Cmdr:RegisterCommandsIn(commandsFolder)
		end

		-- Permission gate for every command in the "Admins" group.
		-- Returning a string from a BeforeRun hook blocks the command and shows that message.
		Cmdr.Registry:RegisterHook("BeforeRun", function(context): string?
			if context.Group == "Admins" then
				local player = context.Executor
				if not player then
					return "This command can only be run by a player"
				end

				if not isAdmin(player) then
					log:audit(`DENIED admin command "{context.Name}" for {player.Name} ({player.UserId})`)
					return "You do not have permission to run this command"
				end

				log:audit(`Player {player.Name} ({player.UserId}) ran admin command: {context.Name}`)
			end
			return nil
		end)
	end,

	--[=[
		Starts the AdminServiceServer.
		@param self AdminServiceServer -- The service instance
	]=]
	start = function(_self)
		log:debug("AdminServiceServer started")
	end,
}

return AdminServiceServer
