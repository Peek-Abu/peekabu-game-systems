--!strict
--[=[
	InventoryScreen: the hub's Inventory (the INVENTORY tile). Full screen: a top bar (the title, the tabs Crew /
	Vacuums / Chat wheel, the Credits wallet and the close), then the Crew tab (InventoryCrewPanel) or one employee's
	page (InventoryCharacterPanel). Vacuums opens the existing equipment page over it; Chat wheel is greyed until
	step 5. On an employee's page the background takes the employee's colour.

	It reads the synced loadout, entitlements and Credits (StateSyncClientStore) and sends only requests (Equip and
	Wear go through CosmeticServiceClient:requestEquip); what it shows changes when the synced loadout does, never
	optimistically. `preview` swaps the stores for fixed data (the UI Labs story). Drawn at the game's one UI scale
	inside PaperHudFrame; sizes are InventoryViewModel.layout. Exempt (wires stores; story in InventoryScreen.story).

	@class InventoryScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local CurrencyUtils = require(ReplicatedStorage.Shared.Features.Currency.Utils.CurrencyUtils)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local CosmeticServiceClient = require(ReplicatedStorage.Client.Features.Cosmetic.CosmeticServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonPill = require(Toon.ToonPill)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local PaperHudFrame = require(script.Parent.Parent.Paper.PaperHudFrame)
local PaperHudScaleViewModel = require(script.Parent.Parent.Paper.PaperHudScaleViewModel)
local usePaperLayout = require(script.Parent.Parent.Paper.usePaperLayout)
local usePaperViewport = require(script.Parent.Parent.Paper.usePaperViewport)
local DepotHubViewModel = require(script.Parent.Parent.Depot.DepotHubViewModel)
local InventoryCharacterPanel = require(script.Parent.InventoryCharacterPanel)
local InventoryCrewPanel = require(script.Parent.InventoryCrewPanel)
local VM = require(script.Parent.InventoryViewModel)

local e = React.createElement

export type Preview = {
	loadout: CosmeticTypes.Loadout,
	owns: (id: string) -> boolean,
	credits: number,
}

export type InventoryScreenProps = {
	preview: Preview?,
	viewport: Vector2?,
	phone: boolean?,
	-- Open on this employee's page, on this page tab (the story).
	employee: string?,
	tab: string?,
}

local function InventoryScreen(props: InventoryScreenProps): React.ReactNode
	local liveViewport = usePaperViewport()
	local livePhone = usePaperLayout() == "phone"
	local syncedLoadout = ReactCharm.useAtom(StateSyncClientStore.loadout)
	local entitlements = ReactCharm.useAtom(StateSyncClientStore.entitlements)
	local currency = ReactCharm.useAtom(StateSyncClientStore.currency)
	-- Lazy initialisers, so the states are typed string? (a nil seed alone would type them nil).
	local page, setPage = React.useState(function(): string?
		return props.employee
	end)
	local tab, setTab = React.useState(props.tab or "skins")
	local selected, setSelected = React.useState(function(): string?
		return nil
	end)

	local preview = props.preview
	local loadout = if preview ~= nil then preview.loadout else syncedLoadout
	local owns = if preview ~= nil
		then preview.owns
		else function(id: string): boolean
			return CosmeticRules.owns(entitlements, id)
		end
	local credits = if preview ~= nil then preview.credits else CurrencyUtils.getCurrencyAmount(currency, "credits")

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

	-- The top bar.
	local barTextSize = if phone then 16 else 22
	local bar: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = "INVENTORY",
			textSize = layout.titleSize,
			position = UDim2.fromOffset(layout.titleX, 0),
			size = UDim2.fromOffset(if phone then 170 else 300, layout.barHeight),
			fit = true,
		}),
	}
	local tabWidth = if phone then 100 else 170
	local tabsX = layout.titleX + (if phone then 180 else 320)
	for index, entry in VM.tabs() do
		local current = entry.id == "crew"
		bar[entry.id] = e(ToonButton, {
			variant = if entry.soon then "secondary" else "grape",
			text = entry.text,
			textSize = barTextSize,
			disabled = entry.soon,
			selected = current,
			-- The greyed tab has the longest words: it is drawn wider.
			position = UDim2.fromOffset(tabsX + (index - 1) * (tabWidth + 12), 6),
			size = UDim2.fromOffset(
				if entry.soon then tabWidth + (if phone then 30 else 50) else tabWidth,
				layout.barHeight - 12
			),
			onActivated = function()
				if entry.id == "crew" then
					setPage(nil)
				elseif entry.id == "vacuums" and preview == nil then
					SceneStack.push(DepotHubViewModel.scene("gear"))
				end
			end,
		})
	end
	-- "Soon" sits on the greyed tab's top edge as a small flag, clear of its words (a badge covered them).
	for index, entry in VM.tabs() do
		if entry.soon then
			local right = tabsX + (index - 1) * (tabWidth + 12) + tabWidth + (if phone then 30 else 50)
			bar[`{entry.id}Soon`] = e(ToonFlag, {
				text = "Soon",
				hue = "coral",
				tilt = 6,
				textSize = if phone then 13 else 16,
				-- Above the tab's top edge, so it never covers the words.
				anchor = Vector2.new(1, 0.8),
				position = UDim2.fromOffset(right + 8, 8),
				size = UDim2.fromOffset(if phone then 60 else 70, if phone then 22 else 26),
				zIndex = 5,
			})
		end
	end
	bar.credits = e(ToonPill, {
		text = ToonStyleViewModel.grouped(credits),
		meaning = "gold",
		icon = "credits",
		textSize = if phone then 20 else 30,
		iconSize = if phone then 44 else 64,
		small = false,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -(layout.barHeight + 28), 0, 6),
		size = UDim2.fromOffset(if phone then 120 else 200, layout.barHeight - 12),
	})
	bar.close = e(ToonButton, {
		variant = "danger",
		text = "X",
		textSize = math.floor(layout.barHeight * 0.45),
		sound = "back",
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -12, 0, 4),
		size = UDim2.fromOffset(layout.barHeight - 4, layout.barHeight - 8),
		onActivated = close,
	})

	local body: React.ReactNode
	if page == nil then
		body = e(InventoryCrewPanel, {
			cards = VM.crew(loadout, owns),
			layout = layout,
			onEquip = function(employee: string)
				equip({ kind = "employee", id = employee })
			end,
			onOpen = function(employee: string)
				setPage(employee)
				setTab("skins")
				setSelected(nil)
			end,
		})
	else
		body = e(InventoryCharacterPanel, {
			employee = page,
			tab = VM.pageTab(tab),
			layout = layout,
			loadout = loadout,
			owns = owns,
			selected = selected,
			onBack = function()
				setPage(nil)
			end,
			onTab = function(next: VM.PageTab)
				setTab(next)
				setSelected(nil)
			end,
			onSelect = function(id: string)
				setSelected(id)
			end,
			onWear = equip,
			onSeen = function(ids: { string })
				if preview == nil then
					CosmeticServiceClient:markSeen(ids)
				end
			end,
		})
	end

	-- The background: night on the Crew tab, the employee's colour on their page, with the sparkle tile over it.
	local tint = if page ~= nil then VM.color(page) else nil
	local night = UIToonConstants.shade("night")
	local top = if tint ~= nil then tint.body else night.hi
	local bottom = if tint ~= nil then tint.dark else night.lo
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIToonConstants.COLOR.white,
		BorderSizePixel = 0,
		Active = true,
	}, {
		gradient = e("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(top, bottom),
		}),
		pattern = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.patternSparkle,
			ImageColor3 = UIToonConstants.COLOR.white,
			ImageTransparency = 0.92,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(96, 96),
		}),
		scaled = e(PaperHudFrame, {
			scale = scale,
			children = {
				bar = e("Frame", {
					Position = UDim2.fromOffset(0, layout.barY),
					Size = UDim2.new(1, 0, 0, layout.barHeight),
					BackgroundTransparency = 1,
				}, bar),
				body = e("Frame", {
					Position = UDim2.fromOffset(layout.content.x, layout.content.y),
					Size = UDim2.fromOffset(layout.content.width, layout.content.height),
					BackgroundTransparency = 1,
				}, { content = body }),
			},
		}),
	})
end

return InventoryScreen
