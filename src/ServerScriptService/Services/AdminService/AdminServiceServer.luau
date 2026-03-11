--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local Admin = require(ReplicatedStorage.Shared.Modules.Admin)
local Cmdr = require(ReplicatedStorage.Packages.Cmdr)

local log = Logger.new("AdminServiceServer")

-- Command groups that do NOT require admin — an allowlist, so the gate FAILS CLOSED: any group
-- not named here (including a typo like "Admin", a future command registered with a new group,
-- or no Group at all) requires Admin.isAdmin. The previous deny-list shape had the opposite
-- failure mode — an unknown group ran ungated for every player — which is the wrong default for
-- the security-critical path. Cmdr's harmless built-ins stay open: "DefaultUtil" (echo, alias,
-- history) and "Help". Everything else — our "Admins" group and Cmdr's powerful "DefaultAdmin"/
-- "DefaultDebug" (kick/kill/teleport, blink/thru/position), which Cmdr does not restrict on its
-- own — is admin-gated by omission.
local OPEN_GROUPS: { [string]: boolean } = {
	DefaultUtil = true,
	Help = true,
}

--[=[
	The subset of Cmdr's CommandContext the permission gate reads. Structural, so the gate can be
	driven by specs with hand-built contexts while accepting Cmdr's full context at runtime.
]=]
export type BeforeRunContext = {
	Group: string?,
	Name: string,
	Executor: Player?,
}

--[=[
	Permission gate for every command run — registered as Cmdr's BeforeRun hook in init().
	Deny-by-default: only groups in OPEN_GROUPS bypass the admin check; everything else
	(known admin groups, unknown groups, and group-less commands alike) requires
	Admin.isAdmin. Returning a string blocks the command and shows that message to the
	invoker; returning nil allows the run. Named at module level (and exposed as
	`_beforeRunHook`) rather than inlined in init() so the spec can exercise the deny/allow
	branches directly — this is the security-critical path of the admin system.
]=]
local function beforeRunHook(context: BeforeRunContext): string?
	local group = context.Group
	if group ~= nil and OPEN_GROUPS[group] then
		return nil
	end

	local player = context.Executor
	if not player then
		return "This command can only be run by a player"
	end

	if not Admin.isAdmin(player) then
		log:audit(`DENIED admin command "{context.Name}" for {player.Name} ({player.UserId})`)
		return "You do not have permission to run this command"
	end

	log:audit(`Player {player.Name} ({player.UserId}) ran admin command: {context.Name}`)
	return nil
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

	-- TEST SEAM — the BeforeRun permission gate above, exposed so specs can drive the deny/allow
	-- branches with fake contexts. Game code never calls this; init() registers it with Cmdr.
	_beforeRunHook: (context: BeforeRunContext) -> string?,
}

local AdminServiceServer: AdminServiceServer = {
	dependencies = {},

	--[=[
		Initializes the AdminServiceServer and Cmdr.
		@param self AdminServiceServer -- The service instance
	]=]
	init = function(_self)
		log:debug("Initializing Cmdr Admin System")

		-- Register custom argument types BEFORE the commands that reference them. Each module in the
		-- shared CmdrTypes folder registers one type (deriving its values from the game constants).
		-- Registering them HERE (server) makes Cmdr replicate them to clients, where CmdrClient
		-- auto-registers them — so there is exactly ONE registration site for both peers.
		Cmdr:RegisterTypesIn(ReplicatedStorage.Shared.CmdrTypes)

		-- Register Cmdr's built-in commands (help, echo, kick, kill, teleport, announce, etc.).
		-- Without this only our custom commands exist — and `help`, which lists every command, is
		-- itself a default command, so the console would have no way to enumerate what's available.
		Cmdr:RegisterDefaultCommands()

		-- Register commands folder
		local commandsFolder = ServerScriptService:FindFirstChild("Commands")
		if not commandsFolder then
			log:warn("Commands folder not found in ServerScriptService, skip registration")
		else
			Cmdr:RegisterCommandsIn(commandsFolder)
		end

		-- Register the permission gate (see beforeRunHook above) for every command run.
		Cmdr.Registry:RegisterHook("BeforeRun", beforeRunHook)
	end,

	--[=[
		Starts the AdminServiceServer.
		@param self AdminServiceServer -- The service instance
	]=]
	start = function(_self)
		log:debug("AdminServiceServer started")
	end,

	_beforeRunHook = beforeRunHook,
}

return AdminServiceServer
