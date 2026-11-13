--!strict
--[=[
	ShopServiceServer: runs Shop purchases. `buy(userId, offerId)` checks the offer exists, the player is not in a
	shift, and (ShopRules) it is on sale and not already owned; then ONE PlayerData transaction spends the price (Gleam
	through MarketplaceServiceServer:premiumOp, Credits through CurrencyServiceServer:currencyOp; a player short on
	Credits who said yes to paying the rest in Gleam pays both, ShopTopUpRules) and grants the items with their bundles
	(CosmeticServiceServer:grantOps). `payOps` gives any other purchase the same payment. Either all of it happens or none of it: a
	player can never pay without getting the item, or get it without paying. A bought item is announced
	(CosmeticServiceServer:announce, source "shop") so the client plays the reveal.

	The buy request is rate-limited and shape-checked (ShopRequestRules); the result goes back as
	ShopEvents.BuyResult. Gleam bundles (Robux developer products) register with the Marketplace receipts only once
	their product ids exist (ShopConstants.PRODUCT_IDS); each receipt adds its Gleam once.

	@class ShopServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shop = ReplicatedStorage.Shared.Features.Shop
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local MarketplaceRegistry = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceRegistry)
local ShopConstants = require(Shop.Data.ShopConstants)
local ShopEvents = require(Shop.Net.ShopEvents)
local ShopRegistry = require(Shop.Data.ShopRegistry)
local ShopRequestRules = require(Shop.Rules.ShopRequestRules)
local ShopPriceRules = require(Shop.Rules.ShopPriceRules)
local ShopRules = require(Shop.Rules.ShopRules)
local ShopTopUpRules = require(Shop.Rules.ShopTopUpRules)
local ShopTypes = require(Shop.Data.ShopTypes)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local CosmeticServiceServer = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local DepotServiceServer = require(ServerScriptService.Features.Depot.DepotServiceServer)
local CurrencyServiceServer = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local MarketplaceServiceServer = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)

local log = Logger.new("ShopServiceServer")

local janitor = Janitor.new()
-- The time prices are worked out at (sales); specs set one that returns nil (regular prices).
local clock: () -> number? = os.time

-- What a purchase can be priced in: Gleam (the account's premium balance) or a slot currency (Credits, Gloom).
type PayCurrency = ShopTypes.Currency | CurrencyConstants.CurrencyType

-- Pays a Gleam price.
local function payGleam(
	userId: number,
	price: number
): ({ PlayerDataService.TransactionOperation }?, string?, ShopTopUpRules.Plan?)
	local premium = MarketplaceServiceServer:getPremium(userId)
	if premium == nil then
		return nil, "no profile loaded", nil
	end
	if premium < price then
		return nil, "short", nil
	end
	return {
		MarketplaceServiceServer:premiumOp(userId, function(value): boolean
			if value.balance < price then
				return false
			end
			value.balance -= price
			return true
		end),
	},
		nil,
		nil
end

-- Pays a slot-currency price, Gleam paying the rest when short and agreed.
local function paySlot(
	userId: number,
	slot: CurrencyConstants.CurrencyType,
	price: number,
	agreedGleam: number
): ({ PlayerDataService.TransactionOperation }?, string?, ShopTopUpRules.Plan?)
	if CurrencyServiceServer:getCurrency(userId) == nil then
		return nil, "no profile loaded", nil
	end
	local have = CurrencyServiceServer:getCurrencyAmount(userId, slot)
	if have >= price then
		return {
			CurrencyServiceServer:currencyOp(userId, function(wallet): boolean
				local now = wallet[slot] or 0
				if now < price then
					return false
				end
				wallet[slot] = now - price
				return true
			end),
		},
			nil,
			nil
	end
	if agreedGleam <= 0 then
		return nil, "short", nil
	end
	local plan = ShopTopUpRules.plan(slot, price, have)
	if plan == nil then
		return nil, "short", nil
	end
	if plan.gleam > agreedGleam then
		return nil, "top up changed", nil
	end
	local premium = MarketplaceServiceServer:getPremium(userId)
	if premium == nil then
		return nil, "no profile loaded", nil
	end
	if premium < plan.gleam then
		return nil, "short", nil
	end
	local spend, gleam = plan.spend, plan.gleam
	return {
		CurrencyServiceServer:currencyOp(userId, function(wallet): boolean
			local now = wallet[slot] or 0
			-- Moved since the plan: the player can pay in full now, or has less than the plan takes.
			if now >= price or now < spend then
				return false
			end
			wallet[slot] = now - spend
			return true
		end),
		MarketplaceServiceServer:premiumOp(userId, function(value): boolean
			if value.balance < gleam then
				return false
			end
			value.balance -= gleam
			return true
		end),
	},
		nil,
		plan
end

--[=[
	The transaction operations that pay `price` in `currency`, or why not. A Gleam price spends Gleam. A Credits (or
	other slot currency) price spends it; when the player is short and said yes to `agreedGleam` Gleam for the rest,
	ShopTopUpRules plans the split and both balances are spent in the same transaction (refused as "top up changed"
	when the rest now costs more Gleam than they said yes to). Each operation re-checks its balance inside the
	transaction, so a balance that moved in between fails the whole purchase instead of overspending.
]=]
local function payOpsImpl(
	userId: number,
	currency: PayCurrency,
	price: number,
	agreedGleam: number
): ({ PlayerDataService.TransactionOperation }?, string?, ShopTopUpRules.Plan?)
	if currency == "credits" then
		return paySlot(userId, "credits", price, agreedGleam)
	elseif currency == "gloom" then
		return paySlot(userId, "gloom", price, agreedGleam)
	end
	return payGleam(userId, price)
end

local function buyImpl(userId: number, offerId: string, agreedGleam: number, seen: number?): (boolean, string?)
	Guard.userId(userId)
	local listed = ShopRegistry.get(offerId)
	if listed == nil then
		return false, "unknown offer"
	end
	if CosmeticServiceServer:isLocked() then
		return false, "locked during a shift"
	end
	if CosmeticServiceServer:getLoadout(userId) == nil then
		return false, "no profile loaded"
	end
	local function owns(id: string): boolean
		return CosmeticServiceServer:owns(userId, id)
	end
	-- What this player pays (a bundle they own part of costs less, ShopPriceRules); never a price from the client.
	local offer = ShopPriceRules.forPlayer(listed, owns, clock())
	-- Never more than the price the player saw (a sale that ended while they looked).
	if seen ~= nil and offer.price > seen then
		return false, "price changed"
	end
	local balance = if offer.currency == "gleam"
		then MarketplaceServiceServer:getPremium(userId)
		else CurrencyServiceServer:getCurrencyAmount(userId, "credits")
	if balance == nil then
		return false, "no profile loaded"
	end
	-- Short is not the end: Gleam may pay the rest (payOpsImpl).
	local allowed, refusal = ShopRules.check(offer, owns, balance, os.time())
	if not allowed and refusal ~= "short" then
		return false, refusal
	end

	local price = offer.price
	local ops, payRefusal, plan = payOpsImpl(userId, offer.currency, price, agreedGleam)
	if ops == nil then
		return false, payRefusal
	end
	-- Only what the player doesn't own yet is granted and revealed (a bundle they own part of).
	local fresh: { string } = {}
	for _, id in offer.items do
		if not owns(id) then
			table.insert(fresh, id)
			for _, op in CosmeticServiceServer:grantOps(userId, id) do
				table.insert(ops, op)
			end
		end
	end
	local committed, result = PlayerDataService:transaction(ops)
	if not committed then
		return false, result.rejectionReason or "transaction failed"
	end
	local gleam = if plan ~= nil then plan.gleam else 0
	log:audit(`userId={userId}`, "SHOP_BOUGHT", offer.id, offer.currency, price, `topUpGleam={gleam}`)
	CosmeticServiceServer:announce(userId, fresh, "shop")
	return true, nil
end

local onBuyRequest = RequestHandler.wrap({
	name = "ShopBuyRequest",
	rateLimit = { maxRequests = 5, windowSeconds = 10 },
	handler = function(payload: unknown, player: Player)
		local request, reason = ShopRequestRules.parseBuy(payload)
		if request == nil then
			log:warn(`bad BuyRequest from {player.Name}: {reason or "?"}`)
			return
		end
		local offer = request.offer
		local ok, refusal = buyImpl(player.UserId, offer, request.gleam, request.price)
		if not ok then
			log:debug(`BuyRequest refused for {player.Name}: {refusal or "?"}`)
		end
		-- Specs pass a stand-in table for the player; only a real player is answered.
		if typeof(player) == "Instance" then
			ShopEvents.packets.BuyResult.sendTo(
				{ offer = offer, reason = if ok then "" else refusal or "failed" },
				player
			)
		end
	end,
})

-- Each Gleam bundle registered with the Marketplace (ShopRegistry, at load) gets its receipt handler: the receipt adds
-- the bundle's Gleam in the same save that records it (exactly once).
local function registerBundles()
	for _, bundle in ShopConstants.BUNDLES do
		if MarketplaceRegistry.product(bundle.key) ~= nil then
			local gleam = bundle.gleam
			MarketplaceServiceServer:onProduct(bundle.key, function(player: Player)
				return {
					MarketplaceServiceServer:premiumOp(player.UserId, function(premium): boolean
						premium.balance += gleam
						return true
					end),
				}
			end)
		end
	end
end

export type ShopServiceServer = {
	dependencies: { string },
	init: (self: ShopServiceServer) -> (),
	stop: (self: ShopServiceServer) -> (),
	-- `gleam`: the most Gleam the player said yes to paying for the rest when short (default 0: pay in full).
	-- `seen`: the price the player saw (nil: none shown); refused as "price changed" when the price is now higher.
	buy: (
		self: ShopServiceServer,
		userId: number,
		offerId: string,
		gleam: number?,
		seen: number?
	) -> (boolean, string?),
	-- The operations that pay `price` in `currency` (Gleam paying the rest when short and agreed), for any purchase
	-- that is not a Shop offer (one transaction with whatever it grants); nil and a refusal when it cannot be paid.
	payOps: (
		self: ShopServiceServer,
		userId: number,
		currency: PayCurrency,
		price: number,
		gleam: number
	) -> ({ PlayerDataService.TransactionOperation }?, string?, ShopTopUpRules.Plan?),
	getState: (self: ShopServiceServer) -> { [string]: any },
	-- TEST SEAM: the clock prices are worked out at (nil restores os.time; a function returning nil: no sales).
	_setClock: (self: ShopServiceServer, fn: (() -> number?)?) -> (),
	-- TEST SEAM: the RequestHandler-wrapped buy handler (payload, player).
	_onBuyRequest: (payload: unknown, player: Player) -> any,
}

local ShopServiceServer: ShopServiceServer = {
	dependencies = {
		"PlayerDataServiceServer",
		"CosmeticServiceServer",
		"CurrencyServiceServer",
		"MarketplaceServiceServer",
	},

	init = function(_self)
		registerBundles()
		-- The places menu's School unlock pays the Shop's way (Credits, Gleam for the rest). Depot cannot require the
		-- Shop (the Shop reaches Depot through Cosmetic and Shift), so the Shop hands it the payment.
		DepotServiceServer:setPlacePayer(function(userId, price, gleam)
			local ops, refusal = payOpsImpl(userId, "credits", price, gleam)
			return ops, refusal
		end)
		janitor:Add(
			ShopEvents.packets.BuyRequest.listen(function(payload: unknown, player: Player?)
				if player then
					onBuyRequest(payload, player)
				end
			end),
			true
		)
	end,

	stop = function(_self)
		janitor:Cleanup()
		DepotServiceServer:setPlacePayer(nil)
	end,

	buy = function(_self, userId, offerId, gleam, seen)
		return buyImpl(userId, offerId, gleam or 0, seen)
	end,

	payOps = function(_self, userId, currency, price, gleam)
		Guard.userId(userId)
		return payOpsImpl(userId, currency, price, gleam)
	end,

	getState = function(_self)
		return { offers = #ShopRegistry.all() }
	end,

	_setClock = function(_self, fn)
		clock = fn or os.time
	end,

	_onBuyRequest = onBuyRequest,
}

return ShopServiceServer
