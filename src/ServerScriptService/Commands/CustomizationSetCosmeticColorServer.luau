--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)
local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

local ACCESSORY_CATEGORY = "accessory"

return function(
	_context,
	target: Player,
	category: string,
	r: number,
	g: number,
	b: number,
	channel: number,
	slot: number
)
	-- Cmdr's `integer` type stops non-integers but not RANGE, and both of these index things: `channel`
	-- becomes a key in the colour array (0 or -1 would make it non-sequential), `slot` picks an
	-- accessory. Refused with a message rather than a Guard throw, because an admin typing a bad number
	-- deserves an answer, not a stack trace.
	if channel < 1 then
		return `Colour channel must be 1 or higher, got {channel}.`
	end
	if category == ACCESSORY_CATEGORY and (slot < 1 or slot > CustomizationCosmeticRegistry.ACCESSORY_SLOTS) then
		return `Accessory slot must be between 1 and {CustomizationCosmeticRegistry.ACCESSORY_SLOTS}, got {slot}.`
	end

	local appearance = CustomizationService:getAppearance(target.UserId)
	if not appearance then
		return `No profile loaded for {target.Name}.`
	end

	-- Recolouring means re-equipping the SAME id with a changed colour list: the service's equip
	-- methods already take colours, so nothing new is needed on the write surface. Reading the current
	-- selection first is what makes this a recolour rather than a silent re-equip of something else.
	local selection = if category == ACCESSORY_CATEGORY
		then appearance.accessories[slot]
		else appearance.cosmetics[category]
	if not selection then
		local where = if category == ACCESSORY_CATEGORY then `accessory slot {slot}` else `category "{category}"`
		return `{target.Name} has nothing equipped in {where}.`
	end

	-- Copy, never mutate: getAppearance hands back a FROZEN snapshot of the stored slice, so writing
	-- into it would throw. Copying also preserves the other channels — rebuilding the list from
	-- scratch would silently wipe a colour the player had already chosen.
	local colors: { PlayerDataTypes.Color } = table.clone(selection.colors)
	colors[channel] = { source = "rgb", r = r, g = g, b = b }

	local success, reason
	if category == ACCESSORY_CATEGORY then
		success, reason = CustomizationService:equipAccessory(target.UserId, slot, selection.id, colors)
	else
		success, reason = CustomizationService:equipCosmetic(target.UserId, category, selection.id, colors)
	end
	if success then
		return `Set channel {channel} of "{selection.id}" to ({r}, {g}, {b}) for {target.Name}.`
	end
	return `Failed to recolour "{selection.id}" for {target.Name}: {reason or "unknown reason"}.`
end
