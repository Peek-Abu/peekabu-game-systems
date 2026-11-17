--!strict
--[=[
	SpecExemptionsUI: the React UI tree's modules (ReplicatedStorage.Client.UI) that SpecRoots.assertAllModulesSpecced
	lets go without a `.spec` sibling, each with its reason (full instance name -> why). Split out of
	SpecExemptionsReplicated when that list passed the file-length cap; SpecRoots joins all three lists. The rule is the
	same as there: a module belongs here only when a unit test would be tautological or genuinely can't run under
	TestEZ (presentational components, hooks over the viewport, scene registration); screen logic lives in specced
	view models.

	@class SpecExemptionsUI
]=]

local EXEMPT_MODULES: { [string]: string } = {
	["ReplicatedStorage.Client.UI.React.Screens.Leaderboard.LeaderboardBoard"] = "presentational React component (words specced in LeaderboardBoardViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Deal.DealChooserScreen"] = "presentational React screen (cards specced in DealViewModel.cards)",
	["ReplicatedStorage.Client.UI.React.Screens.Deal.DealChooserScene"] = "scene registration (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Deal.DealBanner"] = "presentational React component (words specced in DealViewModel.banner)",
	["ReplicatedStorage.Client.UI.React.Screens.Coffee.CoffeeButton"] = "presentational React component (what shows is the specced CoffeeRules.offered / badgeText)",
	["ReplicatedStorage.Client.UI.React.Screens.Coffee.CoffeeChoice"] = "presentational React component (the Robux / 150 Gleam choice; the buy is the specced CoffeeRules.payGleam)",
	["ReplicatedStorage.Client.UI.React.Screens.Training.TrainingSpotlight"] = "presentational React component (layout specced in TrainingSpotlightUtils)",
	["ReplicatedStorage.Client.UI.React.Screens.Training.TrainingSign"] = "presentational React component (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Training.TrainingCoach"] = "presentational React component (line and pose specced in TrainingGuideRules)",
	["ReplicatedStorage.Client.UI.React.Screens.Training.TrainingStopDots"] = "presentational React component (the stop count is TrainingConstants.STOPS)",
	["ReplicatedStorage.Client.UI.React.Screens.Training.TrainingGuideHud"] = "HUD widget shell (catch phases specced in TrainingGuideRules, lines in TrainingCoachStore)",
	["ReplicatedStorage.Client.UI.React.Screens.Training.TrainingFinish"] = "HUD widget shell (presentational; the payout is the server's specced TrainingRules)",

	-- React UI components — rendered and exercised in-game via the F4 overlay; TestEZ has no
	-- renderer, so a unit test would assert nothing meaningful.
	["ReplicatedStorage.Client.UI.React.Debugger.DebuggerOverlay"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.LogsPanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.ServicesPanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.StatePanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.TableView"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.TreeView"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.AnimationsPanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.UIPanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.Scenes.UIDebugScenes"] = "debug harness scene registrations (declarative, no logic)",
	["ReplicatedStorage.Client.UI.React.Debugger.DebuggerTheme"] = "static style tokens (no logic)",
	["ReplicatedStorage.Client.UI.React.Debugger.useDrag"] = "React hook (needs a renderer + pointer input)",

	-- Design system: static tokens + presentational primitives. No logic to assert (screen LOGIC
	-- lives in specced view-models, not in these); verified visually. See docs/testing.md.
	["ReplicatedStorage.Client.UI.React.Tokens"] = "static design tokens (no logic)",
	["ReplicatedStorage.Client.UI.React.Primitives.Button"] = "presentational React primitive (no logic)",
	["ReplicatedStorage.Client.UI.React.Primitives.Panel"] = "presentational React primitive (no logic)",
	["ReplicatedStorage.Client.UI.React.Primitives.ClippedBar"] = "presentational React primitive — the clip-technique sprite bar (no logic)",
	["ReplicatedStorage.Client.UI.React.Primitives.FadeGroup"] = "presentational React primitive — CanvasGroup fade; its easing step TrailEasingUtils is specced",
	["ReplicatedStorage.Client.UI.React.Hooks.useProgressTween"] = "React/TweenService binding shell; normalization and interruption policy covered by ProgressTweenUtils.spec",
	["ReplicatedStorage.Client.UI.React.Hooks.useEasedTrail"] = "React hook — Heartbeat easing over bindings; its pure step TrailEasingUtils is specced",
	["ReplicatedStorage.Client.UI.React.SceneHost"] = "React layer view — renders the stack's screens (selection specced in SceneStack.screensFor)",
	["ReplicatedStorage.Client.UI.React.Debugger.DebugPanelScreen"] = "throwaway harness screen proving the SceneHost render path (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Hud.HudRoot"] = "React composition root — composes the HUD widgets + hide gate (no logic)",

	-- Client services: thin, network/Cmdr-bound shells whose behavior only manifests against a live
	-- server; integration-tested in-game rather than unit-tested.
	["ReplicatedStorage.Client.UI.React.Screens.Hud.ToastStack"] = "React UI component (rendered in-game; story in ToastStack.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotRankBoard"] = "presentational (the view is specced in DepotSignViewModel.ranks)",
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotTopper"] = "presentational kit plate (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotSpotScene"] = "scene registration and thin screens (words specced in DepotRankChartViewModel, LeaderboardBoardViewModel and CoffeeRules)",
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotClockSign"] = "presentational (the view is specced in DepotSignViewModel.clock)",
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotDailySign"] = "presentational (the view is specced in DepotSignViewModel.daily)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotRankChart"] = "presentational (words specced in DepotRankChartViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotRankBadge"] = "presentational ViewportFrame of the rank's lanyard badge model (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotGuidePanel"] = "presentational React component (tabs, steps and monster cards specced in DepotGuideViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Hud.QueuePadStatus"] = "React UI component (rendered in-game; its panel has a story)",
	["ReplicatedStorage.Client.UI.React.Screens.Hud.QueuePadPanel"] = "React UI component (presentational; story in QueuePadPanel.story)",

	-- The Instance/ReactRoblox factory behind UILayers: news the ScreenGui root (direct PlayerGui
	-- child, ResetOnSpawn=false) and the React root. Needs a live PlayerGui + renderer; the WHEN-to-
	-- create/tear-down bookkeeping is the pure UILayers core, fully specced in UILayers.spec.
	["ReplicatedStorage.Client.UI.Layers.UILayerHost"] = "Instance/ReactRoblox factory shell (UILayers core is specced)",
	["ReplicatedStorage.Client.UI.Layers.UIBillboardHost"] = "Instance/ReactRoblox/CollectionService factory shell (the root bookkeeping UIBillboards core is specced)",
	["ReplicatedStorage.Client.UI.Layers.UIRoot"] = "trivial shared-singleton wiring (UILayers core is specced)",
	["ReplicatedStorage.Client.UI.Suppression.UISuppression"] = "world-suppression handler shell — the mouse handler touches UserInputService (UIWorldSuppression core is specced)",

	-- Cleanup Crew: Cargo
	["ReplicatedStorage.Client.UI.React.Screens.World.CargoLoadFloater"] = "presentational React component (floater specced in CargoWorldViewModel; story in CargoWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.CargoPriceTag"] = "presentational React component (tag specced in CargoWorldViewModel; story in CargoWorld.story)",

	-- Cleanup Crew: Hide (hiding spots)
	["ReplicatedStorage.Client.UI.React.Screens.Hide.HideChip"] = "presentational React component (words specced in HideViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Hide.HidePeekOverlay"] = "presentational React component (overlay choice specced in HideViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Ability.AbilityButton"] = "presentational React component (button specced in AbilityViewModel; story in AbilityButton.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Dread.DreadOverlay"] = "React HUD widget (layers specced in DreadViewModel)",

	-- Cleanup Crew: Shift
	["ReplicatedStorage.Client.UI.React.Hooks.useServerClock"] = "React hook — re-renders on the server clock (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHud"] = "React HUD widget wiring stores to ShiftCompactHudPanel (view models specced)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCountdown"] = "presentational React component: one live countdown (its wake time and text specced in ShiftHudViewModel.untilTick / clock)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClockOutBoard"] = "presentational React component (story in ShiftClockOutBoard.story; words and counts specced in ShiftClockOutViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftGloomMeter"] = "presentational React component (story in ShiftCompactHudPanel.story; words specced in ShiftHudViewModel.meter)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewList"] = "presentational React component (story in ShiftCompactHudPanel.story; roster specced in ShiftCrewViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftLivesPips"] = "presentational React component (story in ShiftCompactHudPanel.story; sizes, frame and pop curve specced in ShiftHudViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHotbar"] = "presentational React component (slots specced in ShiftHudViewModel.hotbar; story in ShiftCompactHudPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftStoryFixtures"] = "story fixtures (static sample data)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftActionButton"] = "presentational React component (story in ShiftActionButton.story; the arc and the states specced in ShiftHudViewModel.arcFor / buttons, the press pose in ToonStyleViewModel.pose)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftMobileButtons"] = "React HUD widget: stores to the touch arc and client-service calls (show/hide, VACUUM/THROW, usable buttons and the phone/tablet arc specced in ShiftHudViewModel.mobileButtons / buttons / hidden / arcFor; the helper button in ShiftHelperViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftPromptChip"] = "React HUD widget (words, fill and hidden rule specced in ShiftHudViewModel.prompt)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewPanel"] = "presentational React component (review specced in ShiftReviewViewModel; story in ShiftReviewPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewStatCard"] = "presentational React piece of ShiftReviewPanel (cards specced in ShiftReviewViewModel; story in ShiftReviewPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewAwardCard"] = "presentational React piece of ShiftReviewPanel (awards specced in ShiftReviewViewModel; story in ShiftReviewPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewScreen"] = "React scene screen wiring ShiftStore to ShiftReviewPanel (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewTab"] = "React HUD widget reopening the review scene (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftScene"] = "scene registration (declarative, no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTransitPanel"] = "presentational React component (slip specced in ShiftTransitViewModel; story in ShiftTransitPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTransitScreen"] = "React overlay root wiring ShiftTransitStore to ShiftTransitPanel (no logic)",

	-- Cleanup Crew: Depot
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardPanel"] = "presentational React component (card lines specced in DepotCardViewModel; story in DepotCardPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCard"] = "React HUD widget wiring DepotStore to DepotCardPanel (lines specced in DepotCardViewModel, scale in PaperHudScaleViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardPanel"] = "presentational React component (board specced in DepotBoardViewModel; story in DepotBoardPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardScreen"] = "React scene screen wiring DepotStore to DepotBoardPanel (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotScene"] = "scene registration (declarative, no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPad"] = "React HUD widget wiring QueueStore to DepotNextShiftCard (card specced in DepotPadViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotTruckTag"] = "presentational React component (tag specced in DepotWorldViewModel; story in DepotWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotWorkOrderBoard"] = "presentational React component (work order specced in DepotWorldViewModel; story in DepotWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotResultBoard"] = "presentational React component (review card specced in DepotWorldViewModel; story in DepotWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubPanel"] = "presentational React component: the V1 hub HUD (story in DepotHubPanel.story; values specced in DepotHubViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPlaceCard"] = "presentational React component: one places-menu card (what it shows is specced in DepotBoardViewModel.board)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPlaceButton"] = "presentational React component: the truck's PLACE button (what it shows is specced in DepotPadViewModel.place)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotNextShiftCard"] = "presentational React component (story in DepotHubPanel.story; words specced in DepotPadViewModel.cta)",

	-- Cleanup Crew: the V1 "Gloom & Gleam" UI kit (2026-10-17)
	["ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants"] = "static V1 palette, fonts, depth geometry and timings (no logic; shade is a frozen lookup)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.useToonPose"] = "React/TweenService binding shell (poses and blend specced in ToonStyleViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.useToonPlay"] = "React/TweenService binding shell (curves specced in ToonMotionViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSurface"] = "presentational React component: the depth stack (story in ToonSurface.story; poses specced in ToonStyleViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonButton"] = "presentational React component (story in ToonButton.story; states specced in ToonStyleViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonPanel"] = "presentational React component (story in ToonPanel.story; goo in ToonGooViewModel, motion in ToonMotionViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonArrival"] = "presentational React component: a menu page's rise and tab slide (curves specced in ToonMotionViewModel.arrive / slideFrom)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonWallet"] = "presentational React component: a balance pill that counts, bumps and floats its gain (curves specced in ToonMotionViewModel.count / bump / float)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonPressable"] = "presentational React component: a card's hover/press pose and deal-in (pose specced in ToonStyleViewModel.pose, deal in ToonMotionViewModel.deal / dealDelay)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSlot"] = "presentational React component (story in ToonSlot.story; states specced in ToonStyleViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonPill"] = "presentational React component (story in ToonPill.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonCooldown"] = "presentational React component (story in ToonCooldown.story; words specced in ToonStyleViewModel.cooldown)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonBar"] = "presentational React component (story in ToonBar.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSlider"] = "presentational React component with input wiring (story in ToonSlider.story; the value maths specced in ToonSliderViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonText"] = "presentational React component (story in ToonText.story; stroke and drop specced in ToonStyleViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonIcon"] = "presentational React component (story in ToonIcon.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonGoo"] = "presentational React component (story in ToonGoo.story; layout specced in ToonGooViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonHighlight"] = "presentational React component (story in ToonHighlight.story; the border curve specced in ToonMotionViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSparkle"] = "presentational React component (story in ToonSparkle.story; twinkle specced in ToonMotionViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonWipe"] = "presentational React component (story in ToonWipe.story; sweep specced in ToonMotionViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonFlag"] = "presentational React component (story in ToonFlag.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSourceBand"] = "presentational React component (story in ToonSourceBand.story; which band a card gets is specced in InventoryViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonRarityFrame"] = "presentational React component (story in ToonRarityFrame.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonViewport"] = "React component over a ViewportFrame (story in ToonViewport.story; the model is built by EmployeePreviewSystem, framing and light specced in PortraitViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.useToonSpin"] = "React hook binding drag, stick and Heartbeat input, split out of ToonViewport (the drag, coast and stick maths specced in ToonSpinViewModel; story in ToonViewport.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonBackdrop"] = "presentational React component (story in ToonBackdrop.story; its blur is a camera BlurEffect while mounted)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStatRows"] = "presentational React component (story in ToonStatRows.story; the rows specced in InventoryViewModel.stats)",
	["ReplicatedStorage.Client.UI.React.Screens.Shop.ShopHireRows"] = "presentational React rows (story in ShopScreen.story; ability and stats specced in ShopViewModel.product)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonBurst"] = "presentational React component (story in ToonShopKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStamp"] = "presentational React component (story in ToonShopKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonPrice"] = "presentational React component (story in ToonShopKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Toon.ToonMenuBar"] = "presentational React component (story in ToonMenuBar.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Pick.CharacterPickScreen"] = "React screen wiring the entitlements store (cards, start button and when it opens specced in CharacterPickViewModel; story in CharacterPickScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shop.ShopScreen"] = "React screen wiring the entitlements, currency, premium and Shop stores (values specced in ShopViewModel; story in ShopScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Reveal.RevealScreen"] = "React screen wiring the reveal store (values specced in RevealViewModel; story in RevealScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Reveal.RevealScene"] = "scene registration at require (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Reveal.RevealSlotPicker"] = "presentational React component (the small emote-wheel / sticker-spot picker; slots, swap question and changes specced in RevealViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Reveal.RevealConfetti"] = "presentational React component, split out of RevealScreen (when it shows specced in RevealViewModel effects; story in RevealScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Reveal.RevealSideCards"] = "presentational React cards, split out of RevealScreen (the hire, line and YOU GOT tile values specced in RevealViewModel; story in RevealScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Reveal.RevealStyleChips"] = "presentational React chip row, split out of RevealScreen (the style chips specced in RevealViewModel; story in RevealScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shop.ShopPassesPanel"] = "presentational React component (pass cards specced in ShopViewModel; story in ShopPassesPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shop.ShopProductPanel"] = "presentational React component (product page specced in ShopViewModel; story in ShopScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shop.ShopScene"] = "scene registration at require (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Pick.CharacterPickScene"] = "scene registration at require (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Pick.CharacterPickCard"] = "presentational React card, split out of CharacterPickScreen (card values and tag frame specced in CharacterPickViewModel; story in CharacterPickScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Pick.CharacterPickAboutCard"] = "presentational React card, split out of CharacterPickScreen (stats specced in InventoryViewModel.stats; story in CharacterPickScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryCharacterPanel"] = "presentational React component (cards, detail and stats specced in InventoryViewModel; story in InventoryScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryItemGrid"] = "presentational React column, split out of InventoryCharacterPanel (cards and sections specced in InventoryViewModel / InventoryItemViewModel; story in InventoryScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryItemDetail"] = "presentational React column, split out of InventoryCharacterPanel (detail and change specced in InventoryViewModel / InventoryItemViewModel; story in InventoryScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryAboutColumns"] = "presentational React columns, split out of InventoryCharacterPanel (stats specced in InventoryViewModel.stats; story in InventoryScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryPanelBlocks"] = "presentational layout pieces and the props type, split out of InventoryCharacterPanel (no logic; story in InventoryScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryScreen"] = "React screen wiring the loadout, entitlements and Credits stores (values and layout specced in InventoryViewModel; story in InventoryScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryScene"] = "scene registration at require (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Emote.EmoteWheelScreen"] = "React screen wiring the loadout, entitlements and EmoteWheelStore (slots, layout and picking specced in EmoteWheelViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryChatPanel"] = "presentational React component (slots and packs specced in InventoryViewModel.chat / stickerSlotFor)",
	["ReplicatedStorage.Client.UI.React.Screens.ChatWheel.ChatWheelButtons"] = "presentational HUD button (touch only; its callback opens the chat wheel)",
	["ReplicatedStorage.Client.UI.React.Screens.ChatWheel.ChatWheelScreen"] = "React screen wiring the loadout, entitlements and CalloutWheelStore (pings, slots, layout and picking specced in ChatWheelViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Film.FilmCameraStatus"] = "presentational React widget (shows FilmCameraStore.status, specced)",
	["ReplicatedStorage.Client.UI.React.Screens.Locker.LockerPanel"] = "presentational React component (Locker cards and inside list specced in LockerViewModel; story in ShopScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Locker.LockerInsideCard"] = "presentational React card, split out of LockerPanel (items specced in LockerViewModel.inside; story in ShopScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Locker.LockerCardView"] = "presentational React card, split out of LockerPanel (card values specced in LockerCardViewModel.card; story in ShopScreen.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Locker.LockerItemPanel"] = "presentational React wrapper of ShopProductPanel (its parts specced in ShopViewModel.itemProduct; where it comes from, its chance and its button in LockerViewModel.itemPage)",
	["ReplicatedStorage.Client.UI.React.Screens.Locker.LockerOddsSheet"] = "presentational React component (odds and refund rows specced in LockerViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Locker.LockerOpeningScreen"] = "presentational React screen over LockerStore.opening (values specced in LockerViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Portrait.CharacterPortrait"] = "React component over a ViewportFrame (story in CharacterPortrait.story; framing, light and the missing-portrait timing specced in PortraitViewModel, pose in EmployeePoseRules, the copy in EmployeePortraitSystem)",
	["ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitError"] = "presentational React component (the wait / error choice is specced in PortraitViewModel.missing; seen in CharacterPortrait.story with Missing on)",
	["ReplicatedStorage.Client.UI.React.Screens.Portrait.usePortraitCharacter"] = "React hook over live Players/characters (what a rebuild produces is specced in EmployeePortraitSystem)",

	-- Cleanup Crew: the paper UI kit (M3 UI)
	["ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants"] = "static palette, fonts and sizes (no logic; inkColor is a frozen lookup)",
	["ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard"] = "presentational React wrapper (fit and screen scale specced in WorldBillboardViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHub"] = "React HUD widget wiring the stores to DepotHubPanel (values specced in DepotHubViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubScreen"] = "React guide/settings screen; decisions specced in DepotHubViewModel and DepotGuideViewModel",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubScene"] = "declarative registration for the specced hub pages",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout"] = "React hook over the viewport (the decision is the specced ShiftPlatformRules.detect)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport"] = "React hook over the viewport (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale"] = "React hook over the viewport (the scale maths is specced in PaperHudScaleViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame"] = "presentational React wrapper (scale and top shift specced in PaperHudScaleViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperMotion"] = "React hook — RenderStepped easing over a binding (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperToastStack"] = "React HUD widget (layout specced in PaperToastViewModel; story in PaperToastStack.story)",

	-- Cleanup Crew: catch screens (M3 UI)
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchOverlay"] = "React HUD widget (CCTV lines specced in CatchViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchCctvPanel"] = "presentational React component (story in CatchCctvPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchCctvScanlines"] = "presentational React component, split out of CatchCctvPanel (the rolling band's timing and tile size specced in CatchViewModel; story in CatchCctvPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchRehiredCard"] = "React HUD widget (notice specced in CatchViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchRehiredPanel"] = "presentational React component (story in CatchRehiredPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.useSpectateTarget"] = "React hook polling DeathServiceClient:spectating() (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shop.ShopEventPanel"] = "presentational React component (event tab specced in ShopEventViewModel; story in ShopEventPanel.story)",
}

return table.freeze(EXEMPT_MODULES)
