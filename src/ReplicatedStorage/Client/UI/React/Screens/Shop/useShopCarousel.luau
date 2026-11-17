--!strict
--[=[
	useShopCarousel: the Shop's Featured banner carousel (ShopCarouselViewModel): which slide is up (`slot`, the
	offered one-time deals first, then today's banner), `pickSlide` for a slide the player picked, and the slides moving
	on by themselves while the Featured tab is up with no product page open. Split out of ShopScreen. React hook
	(exempt).

	@class useShopCarousel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CarouselVM = require(script.Parent.ShopCarouselViewModel)

export type ShopCarousel = {
	slot: number,
	pickSlide: (index: number) -> (),
}

local function useShopCarousel(tab: string, productOpen: boolean): ShopCarousel
	-- Which thing the Featured banner spot shows: the offered one-time deals first, then today's banner.
	local slot, setSlot = React.useState(1)
	-- The banner carousel (ShopCarouselViewModel): when its slide last changed, and whether the player picked it.
	local picked, setPicked = React.useState(false)
	local slideChanged = React.useRef(os.clock())
	local function pickSlide(index: number)
		slideChanged.current = os.clock()
		setPicked(true)
		setSlot(index)
	end
	-- The carousel moves on by itself while the Featured tab is up with no product page open.
	local carouselDeps: { unknown } = { slot, picked, tab, productOpen }
	React.useEffect(function(): () -> ()
		if tab ~= "featured" or productOpen then
			return function() end
		end
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(0.25)
				if alive and CarouselVM.due(os.clock() - slideChanged.current, picked) then
					alive = false
					slideChanged.current = os.clock()
					setPicked(false)
					setSlot(slot + 1)
				end
			end
		end)
		return function()
			alive = false
		end
	end, carouselDeps)
	return { slot = slot, pickSlide = pickSlide }
end

return useShopCarousel
