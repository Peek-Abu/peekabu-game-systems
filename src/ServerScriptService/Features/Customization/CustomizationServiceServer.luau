--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationShared = ReplicatedStorage.Shared.Features.Customization
local CustomizationServer = ServerScriptService.Features.Customization
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local CustomizationCosmeticRegistry = require(CustomizationShared.Data.CustomizationCosmeticRegistry)
local CustomizationWearRules = require(CustomizationShared.Rules.CustomizationWearRules)
local CustomizationSliceRules = require(CustomizationShared.Rules.CustomizationSliceRules)
local CustomizationSoulColorRegistry = require(CustomizationShared.Data.CustomizationSoulColorRegistry)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local CharacterReplicationService = require(ServerScriptService.Features.Replication.ReplicationServiceServer)
local CustomizationPublishSystem = require(CustomizationServer.Systems.CustomizationPublishSystem)
local CustomizationArtCheckSystem = require(CustomizationServer.Systems.CustomizationArtCheckSystem)
local CustomizationEntitlementRules = require(CustomizationServer.Rules.CustomizationEntitlementRules)

-- The per-slot appearance slice: what THIS character looks like. Slot-scoped like inventory/equipment
-- (the developer's explicit call — each slot is a distinct character with its own look).
local appearanceSlice = PlayerDataSliceSystem.registerSlot(
	"appearance",
	-- This registration default is the authoritative one (it stamps over the skeleton's placeholder),
	-- so it derives from the registry rather than repeating literals.
	CustomizationWearRules.defaultAppearance(),
	function(slot)
		return slot.appearance
	end,
	CustomizationSliceRules.validateAppearance
)

-- The account-wide entitlements slice: what the ACCOUNT has unlocked, earned once and usable by every
-- character (the wardrobe model — see the design spec's research appendix).
local entitlementsSlice = PlayerDataSliceSystem.registerAccount("entitlements", { cosmetics = {} }, function(account)
	return account.entitlements
end, CustomizationSliceRules.validateEntitlements)

-- When the active look goes onto the public slice (spawn, profile load, every validated write below).
local publisher = CustomizationPublishSystem.new({
	appearance = appearanceSlice.get,
	fillDefaults = function(userId)
		local filled = false
		appearanceSlice.mutate(userId, function(appearance)
			filled = CustomizationWearRules.fillEmptyDefaults(appearance)
			return filled
		end)
		return filled
	end,
	activeSlot = function(userId)
		return PlayerDataService:getActiveSlot(userId)
	end,
})

local log = Logger.new("CustomizationServiceServer")
local janitor = Janitor.new()

-- Where each category's unlocks live (CustomizationEntitlementRules.EntitlementScope).
type EntitlementScope = CustomizationEntitlementRules.EntitlementScope
-- Values are OPTIONAL so clearing an override (assigning nil) is well-typed; an absent entry means
-- the default, "account".
local ENTITLEMENT_SCOPE: { [string]: EntitlementScope? } = {}

local function scopeOf(category: string): EntitlementScope
	return ENTITLEMENT_SCOPE[category] or "account"
end

-- The ownership gate (CustomizationEntitlementRules) with this player's entitlements and scope.
local function canEquip(userId: number, category: string, id: string): (boolean, string?)
	return CustomizationEntitlementRules.canEquip(entitlementsSlice.get(userId), scopeOf(category), category, id)
end

--[=[
	Runs an appearance mutation whose callback may decide nothing needs to change.

	Every accepted mutation mirrors to the client and reapplies the whole look, so writing a value that
	is already stored is not free — several setters short-circuit on it. The data layer reports any
	refusal with one generic reason, which cannot distinguish "already that value" from "no profile
	loaded"; the callback's second return carries the SPECIFIC reason back out so callers surface it.

	@param userId number -- The user ID
	@param mutator function -- (appearance) -> (didChange, noOpReason?)
	@return boolean, string? -- (ok, reason)
]=]
local function mutateAppearance(
	userId: number,
	mutator: (PlayerDataTypes.Appearance) -> (boolean, string?)
): (boolean, string?)
	local noOpReason: string? = nil
	local changed, reason = appearanceSlice.mutate(userId, function(appearance)
		local didChange, why = mutator(appearance)
		noOpReason = why
		return didChange
	end)
	if not changed then
		return false, noOpReason or reason or "no profile loaded"
	end
	CustomizationPublishSystem.publish(publisher, userId)
	return true
end

export type CustomizationServiceServer = {
	dependencies: { string },
	init: (self: CustomizationServiceServer) -> (),
	start: (self: CustomizationServiceServer) -> (),
	stop: (self: CustomizationServiceServer) -> (),
	getAppearance: (self: CustomizationServiceServer, userId: number) -> PlayerDataTypes.Appearance?,
	getEntitlements: (self: CustomizationServiceServer, userId: number) -> PlayerDataTypes.Entitlements?,
	equipCosmetic: (
		self: CustomizationServiceServer,
		userId: number,
		category: string,
		id: string,
		colors: { PlayerDataTypes.Color }?
	) -> (boolean, string?),
	clearCosmetic: (self: CustomizationServiceServer, userId: number, category: string) -> (boolean, string?),
	equipAccessory: (
		self: CustomizationServiceServer,
		userId: number,
		slotIndex: number,
		id: string,
		colors: { PlayerDataTypes.Color }?
	) -> (boolean, string?),
	clearAccessory: (self: CustomizationServiceServer, userId: number, slotIndex: number) -> (boolean, string?),
	setBodyColor: (
		self: CustomizationServiceServer,
		userId: number,
		channelKey: string,
		color: PlayerDataTypes.Color
	) -> (boolean, string?),
	setHeadType: (self: CustomizationServiceServer, userId: number, headType: string) -> (boolean, string?),
	setSoulColor: (self: CustomizationServiceServer, userId: number, colorId: string?) -> (boolean, string?),
	setSurface: (
		self: CustomizationServiceServer,
		userId: number,
		channelKey: string,
		pattern: string?,
		texture: string?
	) -> (boolean, string?),
	unlockCosmetic: (
		self: CustomizationServiceServer,
		userId: number,
		category: string,
		id: string
	) -> (boolean, string?),
	appearanceOp: (
		self: CustomizationServiceServer,
		userId: number,
		fn: (appearance: PlayerDataTypes.Appearance) -> boolean
	) -> PlayerDataService.TransactionOperation,
	_setEntitlementScopeForTesting: (
		self: CustomizationServiceServer,
		category: string,
		scope: EntitlementScope?
	) -> (),
	_onBodySpawnForTesting: (self: CustomizationServiceServer, userId: number) -> (),
	_onProfileLoadedForTesting: (self: CustomizationServiceServer, userId: number) -> (),
	_resetPublicationsForTesting: (self: CustomizationServiceServer) -> (),
}

local CustomizationServiceServer: CustomizationServiceServer = {
	dependencies = { "PlayerDataServiceServer", "ReplicationServiceServer" },

	--[=[
		Initializes the CustomizationServiceServer.
		@param self CustomizationServiceServer -- The service instance
	]=]
	init = function(_self)
		log:debug("CustomizationServiceServer initialized")
	end,

	--[=[
		Backfills the active character's appearance defaults whenever their body spawns, BEFORE anyone draws
		it: a profile predating a default (e.g. one saved before shoes had one) spawns complete rather than
		waiting for an unrelated setHeadType to fix it. The mutation no-ops for anyone already filled, and
		flows through the validated path like every other write.

		The server does not dress bodies: under client-only bodies (character replication) every rig is
		built on a client, and appearance is applied there from the public slice (R4). Until then bodies
		render in the default look.
		@param _self CustomizationServiceServer -- The service instance
	]=]
	start = function(_self)
		CustomizationArtCheckSystem.run()
		janitor:Add(
			CharacterReplicationService:observeBodies(function(player, _epoch)
				CustomizationPublishSystem.onBodySpawn(publisher, player.UserId)
				return nil
			end),
			true
		)
		janitor:Add(
			PlayerDataService.profileLoaded:Connect(function(userId: number)
				CustomizationPublishSystem.onProfileLoaded(publisher, userId)
			end),
			"Disconnect"
		)
		log:debug("CustomizationServiceServer started")
	end,

	--[=[
		Tears down the body observer.
		@param self CustomizationServiceServer -- The service instance
	]=]
	stop = function(_self)
		janitor:Cleanup()
		log:debug("CustomizationServiceServer stopped")
	end,

	--[=[
		The ACTIVE character's equipped appearance.
		@param userId number -- The user ID
		@return PlayerDataTypes.Appearance? -- nil if the profile is not loaded
	]=]
	getAppearance = function(_self, userId)
		return appearanceSlice.get(userId)
	end,

	--[=[
		The account's unlocked cosmetics/soul colors.
		@param userId number -- The user ID
		@return PlayerDataTypes.Entitlements? -- nil if the profile is not loaded
	]=]
	getEntitlements = function(_self, userId)
		return entitlementsSlice.get(userId)
	end,

	--[=[
		Equips a single-selection cosmetic (hair/eyebrows/eyelashes) on the active character.

		`colors` is OPTIONAL: omitting it (or passing fewer than the cosmetic's channels) leaves those
		channels at the model's authored colors. Refuses — without writing anything — when the id is
		unregistered or is lockable and not unlocked.
		@param userId number -- The user ID
		@param category string -- A registered cosmetic category (not "accessory" — see equipAccessory)
		@param id string -- A registered cosmetic id in that category
		@param colors { PlayerDataTypes.Color }? -- Optional per-channel colors
		@return boolean, string? -- (ok, reason)
	]=]
	equipCosmetic = function(_self, userId, category, id, colors)
		Guard.userId(userId)
		if category == "accessory" then
			return false, "accessories are equipped by slot — use equipAccessory"
		end
		local ok, reason = canEquip(userId, category, id)
		if not ok then
			return false, reason
		end
		-- `mutate` returns (changed, reason?): the reason carries the data-layer validator's rejection
		-- message. Dropping it would report every failure as "no profile loaded" and hide the real
		-- cause from admin commands and any future UI caller. A nil reason means no profile was loaded
		-- (the only other way this mutator reports false, since it always returns true).
		local changed, mutateReason = appearanceSlice.mutate(userId, function(appearance)
			appearance.cosmetics[category] = { id = id, colors = colors or {} }
			return true
		end)
		if not changed then
			return false, mutateReason or "no profile loaded"
		end
		CustomizationPublishSystem.publish(publisher, userId)
		return true
	end,

	--[=[
		Clears a single-selection cosmetic (the "none" option — an absent key, not a blank model).
		@param userId number -- The user ID
		@param category string -- The cosmetic category to clear
		@return boolean, string? -- (ok, reason)
	]=]
	clearCosmetic = function(_self, userId, category)
		Guard.userId(userId)
		-- `alreadyClear` distinguishes a legitimate no-op from a REJECTION: both surface as
		-- `changed == false` with a nil reason, so without it a rejected write would be reported as
		-- the harmless "nothing to clear".
		local alreadyClear = false
		local changed, reason = appearanceSlice.mutate(userId, function(appearance)
			if appearance.cosmetics[category] == nil then
				alreadyClear = true
				return false -- already clear; no write, nothing mirrors
			end
			appearance.cosmetics[category] = nil
			return true
		end)
		if not changed then
			if alreadyClear then
				return false, "nothing to clear"
			end
			return false, reason or "no profile loaded"
		end
		CustomizationPublishSystem.publish(publisher, userId)
		return true
	end,

	--[=[
		Equips an accessory into one of the generic accessory slots (1..ACCESSORY_SLOTS). Slots are
		dense: equipping into a slot beyond the current count appends, so a caller cannot punch a hole
		in the array that the validator's length check would then misread.
		@param userId number -- The user ID
		@param slotIndex number -- 1..CosmeticRegistry.ACCESSORY_SLOTS
		@param id string -- A registered accessory id
		@param colors { PlayerDataTypes.Color }? -- Optional per-channel colors
		@return boolean, string? -- (ok, reason)
	]=]
	equipAccessory = function(_self, userId, slotIndex, id, colors)
		Guard.userId(userId)
		-- Guard, not an inline check: the numeric SHAPE of a slot index is a developer contract (the
		-- same split invest/equip already use — shape asserts, player-driven conditions return a
		-- reason), and Guard.slotIndex is parameterized by a max exactly for this.
		Guard.slotIndex(slotIndex, CustomizationCosmeticRegistry.ACCESSORY_SLOTS)
		local ok, reason = canEquip(userId, "accessory", id)
		if not ok then
			return false, reason
		end
		local changed, mutateReason = appearanceSlice.mutate(userId, function(appearance)
			-- Clamp to the first free slot so the array stays DENSE: writing past the end would punch
			-- a hole, which the validator now rejects outright (a sparse array could otherwise slip
			-- past the capacity check).
			local target = math.min(slotIndex, #appearance.accessories + 1)
			appearance.accessories[target] = { id = id, colors = colors or {} }
			return true
		end)
		if not changed then
			return false, mutateReason or "no profile loaded"
		end
		CustomizationPublishSystem.publish(publisher, userId)
		return true
	end,

	--[=[
		Clears an accessory slot, closing the gap so the array stays dense.
		@param userId number -- The user ID
		@param slotIndex number -- The slot to clear
		@return boolean, string? -- (ok, reason)
	]=]
	clearAccessory = function(_self, userId, slotIndex)
		Guard.userId(userId)
		Guard.slotIndex(slotIndex, CustomizationCosmeticRegistry.ACCESSORY_SLOTS)
		local alreadyClear = false
		local changed, reason = appearanceSlice.mutate(userId, function(appearance)
			if appearance.accessories[slotIndex] == nil then
				alreadyClear = true
				return false
			end
			-- `table.remove` (not a nil assignment) so the array closes the gap and stays dense.
			table.remove(appearance.accessories, slotIndex)
			return true
		end)
		if not changed then
			if alreadyClear then
				return false, "nothing to clear"
			end
			return false, reason or "no profile loaded"
		end
		CustomizationPublishSystem.publish(publisher, userId)
		return true
	end,

	--[=[
		Sets one body-color channel (e.g. "color1", "skin"). The channel must be registered, and the
		color must satisfy that channel's free-RGB policy — both enforced by the data-layer validator,
		so the pre-check here only produces a friendlier message.
		@param userId number -- The user ID
		@param channelKey string -- A registered body channel key
		@param color PlayerDataTypes.Color -- A dye reference or a free rgb value
		@return boolean, string? -- (ok, reason)
	]=]
	setBodyColor = function(_self, userId, channelKey, color)
		Guard.userId(userId)
		if not CustomizationCosmeticRegistry.bodyChannel(channelKey) then
			return false, `"{channelKey}" is not a registered body channel`
		end
		local changed, reason = appearanceSlice.mutate(userId, function(appearance)
			appearance.body[channelKey] = color
			return true
		end)
		if not changed then
			-- Surfaces the VALIDATOR's message (e.g. an out-of-range rgb component), which is the real
			-- backstop here — the channel pre-check above only produces a friendlier error earlier.
			return false, reason or "no profile loaded"
		end
		CustomizationPublishSystem.publish(publisher, userId)
		return true
	end,

	--[=[
		Sets the character's soul colour — ONE value that a roll replaces, not an owned collection (see
		CustomizationSoulColorRegistry). Accepts a multi-hue id ("blue-green"); pass nil to clear it.

		There is no ownership gate: soul colours are not entitlements. When the weighted roll lands in a
		later economy phase, IT decides what a player may end up with; this method is the storage seam.
		@param userId number -- The user ID
		@param colorId string? -- A registered soul-colour id, or nil to clear
		@return boolean, string? -- (ok, reason)
	]=]
	setSoulColor = function(_self, userId, colorId)
		Guard.userId(userId)
		if colorId ~= nil and not CustomizationSoulColorRegistry.isRegistered(colorId) then
			return false, `"{tostring(colorId)}" is not a registered soul colour`
		end
		return mutateAppearance(userId, function(appearance)
			if appearance.soulColor == colorId then
				return false, "soul colour is already that value"
			end
			appearance.soulColor = colorId
			return true, nil
		end)
	end,

	--[=[
		Restyles one surface channel (clothing/backpack): its `SurfaceAppearance` pattern and/or its
		`Texture`.

		The stored selection is the COMPLETE state of the channel, not a patch: nil for an aspect means
		"restore what the rig authored", and nil for both clears the channel entirely. A caller wanting
		to change one aspect and KEEP the other must pass the current value back — it cannot be
		expressed as nil, because that is how clearing is expressed. `SetSurfaceServer` resolves its
		"-" sentinel against the stored selection for exactly this reason.
		@param userId number -- The user ID
		@param channelKey string -- A registered surface channel ("clothing1", "backpack2", ...)
		@param pattern string? -- A pattern id from that channel's catalog, or nil to restore
		@param texture string? -- A registered texture id, or nil to restore
		@return boolean, string? -- (ok, reason)
	]=]
	setSurface = function(_self, userId, channelKey, pattern, texture)
		Guard.userId(userId)
		if not CustomizationCosmeticRegistry.surfaceChannel(channelKey) then
			return false, `"{channelKey}" is not a registered surface channel`
		end
		return mutateAppearance(userId, function(appearance)
			local stored = appearance.surfaces[channelKey]
			if pattern == nil and texture == nil then
				if stored == nil then
					return false, "surface is already clear"
				end
				appearance.surfaces[channelKey] = nil
				return true, nil
			end
			if stored ~= nil and stored.pattern == pattern and stored.texture == texture then
				return false, "surface is already set that way"
			end
			appearance.surfaces[channelKey] = { pattern = pattern, texture = texture }
			return true, nil
		end)
	end,

	--[=[
		Sets which head mode the character's rig shows. Unlike the cosmetic channels there is no "none"
		— a character always has a head — so this only ever swaps between registered modes.
		@param userId number -- The user ID
		@param headType string -- A registered head type ("Covered" | "Uncovered")
		@return boolean, string? -- (ok, reason)
	]=]
	setHeadType = function(_self, userId, headType)
		Guard.userId(userId)
		if not CustomizationCosmeticRegistry.isHeadType(headType) then
			return false, `"{tostring(headType)}" is not a registered head type`
		end
		local alreadySet = false
		local cleared: { string } = {}
		local substituted: { string } = {}
		local changed, reason = appearanceSlice.mutate(userId, function(appearance)
			if appearance.headType == headType then
				alreadySet = true
				return false
			end
			-- AUTO-CLEAR, not refuse (design spec, Decision 3): the player asked for the head change,
			-- so blocking it because of a hat they may not be thinking about reads as broken. Both the
			-- clear and the head-type write happen in THIS mutation, so the validator never observes
			-- the incompatible intermediate state.
			local incompatible = CustomizationWearRules.find(appearance, headType)
			for _, category in incompatible.categories do
				appearance.cosmetics[category] = nil
				table.insert(cleared, category)
			end
			-- Indices arrive DESCENDING, so sequential removal cannot shift a later target.
			for _, index in incompatible.accessoryIndices do
				table.insert(cleared, `accessory slot {index}`)
				table.remove(appearance.accessories, index)
			end
			appearance.headType = headType

			-- BALD IS NEVER A RESTING STATE where the new mode declares a default. Applied to any empty
			-- defaulted category, not just the ones this switch cleared — so a player who arrived bald
			-- (e.g. from a mode that has no default) still comes back with hair on the way out. A mode
			-- with no declared default contributes nothing and stays as-is.
			CustomizationWearRules.fillEmptyDefaults(appearance, substituted)
			return true
		end)
		if not changed then
			if alreadySet then
				return false, `head type is already "{headType}"`
			end
			return false, reason or "no profile loaded"
		end
		CustomizationPublishSystem.publish(publisher, userId)
		-- Surfaced rather than silent: the caller may lose a selection or gain a substituted one, and an
		-- admin/UI should be able to say which.
		local notes: { string } = {}
		if #cleared > 0 then
			table.insert(notes, `cleared incompatible: {table.concat(cleared, ", ")}`)
		end
		if #substituted > 0 then
			table.insert(notes, `defaulted: {table.concat(substituted, ", ")}`)
		end
		if #notes > 0 then
			return true, table.concat(notes, "; ")
		end
		return true
	end,

	--[=[
		Grants an account-wide cosmetic unlock. Only LOCKABLE ids are storable — unlocking a free
		cosmetic is refused rather than silently stored, because a free id needs no entitlement row
		(and the slice validator would reject it anyway).
		@param userId number -- The user ID
		@param category string -- The cosmetic's category
		@param id string -- A registered, lockable cosmetic id
		@return boolean, string? -- (ok, reason)
	]=]
	unlockCosmetic = function(_self, userId, category, id)
		Guard.userId(userId)
		if not CustomizationCosmeticRegistry.isRegistered(category, id) then
			return false, `"{id}" is not a registered {category} cosmetic`
		end
		if not CustomizationCosmeticRegistry.isLockable(category, id) then
			return false, `"{id}" is free — it needs no unlock`
		end
		-- `alreadyOwned` is load-bearing: a no-profile bail and a validator rejection BOTH surface as
		-- `changed == false` with a nil reason, so reporting every falsey result as "already unlocked"
		-- told an operator their grant succeeded-in-effect when it had actually failed.
		local alreadyOwned = false
		local changed, reason = entitlementsSlice.mutate(userId, function(entitlements)
			local owned = entitlements.cosmetics[category]
			if not owned then
				owned = {}
				entitlements.cosmetics[category] = owned
			end
			if owned[id] == true then
				alreadyOwned = true
				return false -- already owned; idempotent, no write
			end
			owned[id] = true
			return true
		end)
		if not changed then
			if alreadyOwned then
				return false, "already unlocked"
			end
			return false, reason or "no profile loaded"
		end
		log:audit(`userId={userId}`, "COSMETIC_UNLOCKED", `{category}/{id}`)
		return true
	end,

	--[=[
		A transaction operation over the appearance slice, for callers composing a multi-slice atomic
		write (same shape as inventoryOp/equipmentOp/bankOp). Does NOT publish to the public slice:
		publishes happen explicitly on commit via the direct methods' post-commit path
		(mutateAppearance -> CustomizationPublishSystem.publish), so a transaction caller that changes the appearance
		must publish itself after the transaction commits.
		@param userId number -- The user ID
		@param fn (appearance) -> boolean -- Mutator; returns whether it changed anything
		@return PlayerDataService.TransactionOperation
	]=]
	appearanceOp = function(_self, userId, fn)
		Guard.userId(userId)
		return appearanceSlice.op(userId, fn)
	end,

	--[=[
		TEST SEAM (underscore-marked, like PlayerDataService._setProfileForTesting): overrides where a
		category's unlocks live, so a spec can prove the ownership check actually routes through the
		scope policy (Decision 1a) without a per-slot entitlement store existing yet. Pass nil to reset.
		@param category string -- The category to override
		@param scope EntitlementScope? -- The scope, or nil to restore the default ("account")
	]=]
	_setEntitlementScopeForTesting = function(_self, category, scope)
		ENTITLEMENT_SCOPE[category] = scope
	end,

	--[=[
		TEST SEAM (underscore-marked, like PlayerDataService._setProfileForTesting): runs the real
		body-spawn hook (defaults backfill + the publish decision) without a live body from
		ReplicationServiceServer — the observeBodies signal itself needs Studio.
		@param userId number -- The user ID
	]=]
	_onBodySpawnForTesting = function(_self, userId)
		CustomizationPublishSystem.onBodySpawn(publisher, userId)
	end,

	--[=[
		TEST SEAM: runs the profile-loaded hook for a user (the live path is PlayerDataService.profileLoaded).
		@param userId number -- The user ID
	]=]
	_onProfileLoadedForTesting = function(_self, userId)
		CustomizationPublishSystem.onProfileLoaded(publisher, userId)
	end,

	--[=[
		TEST SEAM: clears the publisher's slot bookkeeping (the version history is StateSyncPublicPlayerStore's own seam).
		A spec's afterEach pairs this with StateSyncPublicPlayerStore.remove so the two halves of the public
		entry stay in sync across tests.
	]=]
	_resetPublicationsForTesting = function(_self)
		CustomizationPublishSystem.reset(publisher)
	end,
}

return CustomizationServiceServer
