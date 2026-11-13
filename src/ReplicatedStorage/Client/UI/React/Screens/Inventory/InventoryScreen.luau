--!strict
--[=[
	InventoryScreen: the hub's Inventory (the INVENTORY tile). Full screen on a ToonBackdrop (night over the blurred
	depot on the Crew tab; the employee's colour with rays behind the hero on their page) under a ToonMenuBar:
	- Crew tab: the locker render on the title plate, tabs Crew / Chat wheel, then InventoryCrewPanel.
	- Chat wheel tab: InventoryChatPanel (the 4 sticker slots, the pings, every sticker pack).
	- An employee's page: a back button, the employee's head breaking their name plate, tabs Skins / Idles / About,
	  then InventoryCharacterPanel. Skins also holds the vacuum skins in their own row (one vacuum for the whole crew;
	  owner, 2026-11-13: vacuum skins are skins, no Vacuums tab).
	Both wallets (Credits and Gleam) and the close sit on the right.

	It reads the synced loadout, entitlements, Credits and Gleam (StateSyncClientStore) and sends only requests (Equip
	and Wear through CosmeticServiceClient:requestEquip; seen items through markSeen); what it shows changes when the
	synced loadout does, never optimistically. "See in Shop" calls `onShop`. `preview` swaps the stores for fixed
	data (the UI Labs story). Drawn at the game's one UI scale inside PaperHudFrame; sizes are
	InventoryViewModel.layout. Exempt (wires stores; story in InventoryScreen.story).

	@class InventoryScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local CurrencyUtils = require(ReplicatedStorage.Shared.Features.Currency.Utils.CurrencyUtils)
local CosmeticServiceClient = require(ReplicatedStorage.Client.Features.Cosmetic.CosmeticServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBackdrop = require(Toon.ToonBackdrop)
local ToonMenuBar = require(Toon.ToonMenuBar)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local PaperHudFrame = require(script.Parent.Parent.Paper.PaperHudFrame)
local PaperHudScaleViewModel = require(script.Parent.Parent.Paper.PaperHudScaleViewModel)
local usePaperLayout = require(script.Parent.Parent.Paper.usePaperLayout)
local usePaperViewport = require(script.Parent.Parent.Paper.usePaperViewport)
local InventoryCharacterPanel = require(script.Parent.InventoryCharacterPanel)
local InventoryChatPanel = require(script.Parent.InventoryChatPanel)
local InventoryCrewPanel = require(script.Parent.InventoryCrewPanel)
local VM = require(script.Parent.InventoryViewModel)

local e = React.createElement

export type Preview = {
	loadout: CosmeticTypes.Loadout,
	owns: (id: string) -> boolean,
	credits: number,
	gleam: number,
}

export type InventoryScreenProps = {
	preview: Preview?,
	viewport: Vector2?,
	phone: boolean?,
	-- Open on this employee's page, on this page tab (the story).
	employee: string?,
	tab: string?,
	-- Select this item on the page (the story).
	item: string?,
	-- "See in Shop": open the Shop on this item.
	onShop: ((id: string) -> ())?,
}

local PAGE_TAB_TEXT: { [VM.PageTab]: string } = { skins = "Skins", emotes = "Emotes", idles = "Idles", about = "About" }

local function InventoryScreen(props: InventoryScreenProps): React.ReactNode
	local liveViewport = usePaperViewport()
	local livePhone = usePaperLayout() == "phone"
	local syncedLoadout = ReactCharm.useAtom(StateSyncClientStore.loadout)
	local entitlements = ReactCharm.useAtom(StateSyncClientStore.entitlements)
	local currency = ReactCharm.useAtom(StateSyncClientStore.currency)
	local premium = ReactCharm.useAtom(StateSyncClientStore.premium)
	-- Lazy initialisers, so the states are typed string? (a nil seed alone would type them nil).
	local page, setPage = React.useState(function(): string?
		return props.employee
	end)
	local tab, setTab = React.useState(props.tab or "skins")
	local noOpen: number? = nil
	local openedAt, setOpenedAt = React.useState(noOpen)
	-- The top-level tab while no employee's page is open: "crew" or "wheel".
	local area, setArea = React.useState(if props.employee == nil and props.tab == "wheel" then props.tab else "crew")
	local selected, setSelected = React.useState(function(): string?
		return props.item
	end)

	local preview = props.preview
	local loadout = if preview ~= nil then preview.loadout else syncedLoadout
	local owns = if preview ~= nil
		then preview.owns
		else function(id: string): boolean
			return CosmeticRules.owns(entitlements, id)
		end
	local credits = if preview ~= nil then preview.credits else CurrencyUtils.getCurrencyAmount(currency, "credits")
	local gleam = if preview ~= nil then preview.gleam else premium.balance

	local viewport = props.viewport or liveViewport
	local phone = if props.phone ~= nil then props.phone else livePhone
	local scale = PaperHudScaleViewModel.scale(viewport, if phone then "phone" else "desktop")
	local virtual =
		PaperHudScaleViewModel.virtual(viewport - Vector2.new(0, PaperHudScaleViewModel.topShift(scale)), scale)
	local layout = VM.layout(virtual, phone)

	local function equip(change: CosmeticTypes.Change)
		if preview == nil then
			CosmeticServiceClient:requestEquip(change)
		end
	end
	local function close()
		SceneStack.remove(VM.SCENE)
	end

	local bar: React.ReactNode
	local body: React.ReactNode
	local backdrop: ToonBackdrop.ToonBackdropProps
	local function seen(ids: { string })
		if preview == nil then
			CosmeticServiceClient:markSeen(ids)
		end
	end
	if page == nil then
		local tabs: { ToonMenuBar.Tab } = {}
		for _, entry in VM.tabs() do
			table.insert(tabs, { id = entry.id, text = entry.text, icon = entry.icon, soon = entry.soon })
		end
		bar = e(ToonMenuBar, {
			title = "INVENTORY",
			icon = "locker",
			tabs = tabs,
			current = area,
			onTab = function(id: string)
				if id == "crew" or id == "wheel" then
					setArea(id)
					setSelected(nil)
				end
			end,
			credits = credits,
			gleam = gleam,
			onClose = close,
			x = layout.titleX,
			height = layout.barHeight,
			phone = phone,
		})
		if area == "wheel" then
			body = e(InventoryChatPanel, {
				view = VM.chat(loadout, owns),
				layout = layout,
				onPut = function(slot: number, id: string)
					equip({ kind = "sticker", slot = slot, id = id })
				end,
				onShop = function(id: string)
					local onShop = props.onShop
					if onShop ~= nil then
						onShop(id)
					end
				end,
			})
			local sky = UIToonConstants.shade("sky")
			backdrop = { top = sky.base, bottom = UIToonConstants.shade("grape").lo, blur = preview == nil }
		else
			body = e(InventoryCrewPanel, {
				cards = VM.crew(loadout, owns),
				layout = layout,
				onHire = function(employee: string)
					local onShop = props.onShop
					if preview == nil and onShop ~= nil then
						onShop(employee)
					end
				end,
				onEquip = function(employee: string)
					equip({ kind = "employee", id = employee })
				end,
				onOpen = function(employee: string)
					setPage(employee)
					setOpenedAt(os.clock())
					setTab("skins")
					setSelected(nil)
				end,
			})
			local night = UIToonConstants.shade("night")
			backdrop = { top = night.hi, bottom = UIToonConstants.COLOR.ink, see = 0.45, blur = preview == nil }
		end
	else
		local employee = page
		local tabs: { ToonMenuBar.Tab } = {}
		for _, id: VM.PageTab in VM.PAGE_TABS do
			local tabId: string = id
			table.insert(tabs, { id = tabId, text = PAGE_TAB_TEXT[id] })
		end
		local look = loadout.looks[employee]
		local currentTab: string = VM.pageTab(tab)
		bar = e(ToonMenuBar, {
			title = string.upper(employee),
			hue = "gold",
			art = function(size: number): React.ReactNode
				return e(ToonViewport, {
					employee = employee,
					skin = if look ~= nil then VM.skinKey(look.skin) else nil,
					framing = "upper",
					size = UDim2.fromOffset(size, size),
				})
			end,
			back = {
				text = "Crew",
				onActivated = function()
					setPage(nil)
				end,
			},
			tabs = tabs,
			current = currentTab,
			onTab = function(id: string)
				setTab(id)
				setSelected(nil)
			end,
			credits = credits,
			gleam = gleam,
			onClose = close,
			x = layout.titleX,
			height = layout.barHeight,
			phone = phone,
		})
		body = e(InventoryCharacterPanel, {
			employee = employee,
			tab = VM.pageTab(tab),
			layout = layout,
			loadout = loadout,
			owns = owns,
			selected = selected,
			openedAt = openedAt,
			onSelect = function(id: string)
				setSelected(id)
			end,
			onWear = equip,
			onShop = function(id: string)
				local onShop = props.onShop
				if onShop ~= nil then
					onShop(id)
				end
			end,
			onSeen = seen,
		})
		local tint = VM.color(employee)
		-- The rays sit behind the hero (the middle column), in screen terms.
		local heroX = (layout.content.x + layout.gridWidth + layout.gap + layout.heroWidth / 2) / math.max(1, virtual.X)
		backdrop = {
			top = tint.body,
			bottom = tint.dark,
			rays = { position = UDim2.fromScale(heroX, 0.5), size = 0.7, color = tint.light, transparency = 0.4 },
			blur = preview == nil,
		}
	end

	local screen: { [string]: React.ReactNode } = {
		scaled = e(PaperHudFrame, {
			scale = scale,
			children = {
				bar = e("Frame", {
					Position = UDim2.fromOffset(0, layout.barY),
					Size = UDim2.new(1, 0, 0, layout.barHeight),
					BackgroundTransparency = 1,
					ZIndex = 2,
				}, { bar = bar }),
				body = e("Frame", {
					Position = UDim2.fromOffset(layout.content.x, layout.content.y),
					Size = UDim2.fromOffset(layout.content.width, layout.content.height),
					BackgroundTransparency = 1,
				}, { content = body }),
			},
		}),
	}
	backdrop.children = screen
	return e(ToonBackdrop, backdrop)
end

return InventoryScreen
