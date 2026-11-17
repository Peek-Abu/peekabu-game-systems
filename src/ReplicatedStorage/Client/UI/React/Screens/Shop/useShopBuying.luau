--!strict
--[=[
	useShopBuying: the Shop offer a yes was sent for, until its answer comes back (`result` changes) or BUY_WAIT passes:
	its button says "Buying..." (U2). Split out of ShopScreen. React hook (exempt).

	@class useShopBuying
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)

-- The longest a "Buying..." waits for the server's answer before the button comes back (seconds).
local BUY_WAIT = 5

local function useShopBuying(result: ShopStore.Result?): (string, (id: string) -> ())
	-- The offer a yes was sent for, until its answer comes back (or BUY_WAIT passes): its button says "Buying..." (U2).
	local buying, setBuying = React.useState("")
	React.useEffect(function()
		setBuying("")
	end, { result })
	React.useEffect(function(): () -> ()
		if buying == "" then
			return function() end
		end
		local waiting = task.delay(BUY_WAIT, function()
			setBuying("")
		end)
		return function()
			task.cancel(waiting)
		end
	end, { buying })
	return buying, setBuying
end

return useShopBuying
