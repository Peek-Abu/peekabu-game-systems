--!strict
--[=[
	UIAssets: the registry of image (and UI sound) asset ids the UI references, by name.

	The single home for `rbxassetid://` literals in UI code — the CI asset-id gate bans them anywhere
	else (asset-id literals may only live under a feature's `Data/` folder). A screen names an asset
	(`UIAssets.bar.fill`), never pastes a number, so a re-skin or a re-upload is one edit here.

	Empty in the base: each game adds its own groups, frozen, e.g.

		UIAssets.bar = table.freeze({
			fill = "rbxassetid://<id>", -- the coloured fill (tinted per resource)
			frame = "rbxassetid://<id>", -- the border drawn over the fill
		})

	@class UIAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local UIAssets = {}

-- A tileable texture: its asset id (PENDING "" until the developer uploads it) and its size in px, the TileSize it
-- repeats at. PaperTexture draws nothing while an id is "", so every paper stays a flat colour until then.
export type Texture = { id: string, tile: Vector2 }

-- Cleanup Crew paper textures (M3b world UI; files in assets/ui/textures/), uploaded to the Icey Labs group. Each id is
-- the Image under the uploaded Decal, as "rbxassetid://<number>" (PaperTextureViewModel.spec checks the form).
local PAPER: { [string]: Texture } = {
	cream = table.freeze({ id = "rbxassetid://74559876585601", tile = Vector2.new(160, 160) }), -- paper-cream.png
	manila = table.freeze({ id = "rbxassetid://139836337623266", tile = Vector2.new(160, 160) }), -- paper-manila.png
	manilaDeep = table.freeze({ id = "rbxassetid://105396699555543", tile = Vector2.new(128, 128) }), -- paper-manila-deep.png
	sticky = table.freeze({ id = "rbxassetid://75509377158113", tile = Vector2.new(128, 128) }), -- paper-sticky.png
	cork = table.freeze({ id = "rbxassetid://137899371757107", tile = Vector2.new(192, 192) }), -- cork.png
	wood = table.freeze({ id = "rbxassetid://129212444634345", tile = Vector2.new(256, 128) }), -- wood.png
}
UIAssets.paper = table.freeze(PAPER)

-- The CCTV overlay's scanlines (M3 UI). PENDING and not drawn yet.
UIAssets.cctv = table.freeze({
	scanlines = "",
})

-- Cleanup Crew UI sounds (round-2/3 picks, in-house, the paperwork hierarchy: pitch up = yes, down = back, dull =
-- denied), all 2D in the UI group. Minor: hover (a paper tick) and click (tab flick + card), family P. Important: confirm
-- (felt thunk + clip + one vibes note in F, family S), back (lower, shorter) and error (a dull thud + falling minor 2nd),
-- family P. Critical: the CTA (confirm + a time-clock punch + rising F-A-C + a small ding, family S) for Start shift and
-- Clock out. Prompts: the hold wind-up (a pizz F major scale, stretched to the hold) and the done (confirm S's felt and
-- clip + a pizz F chord). Played by UISoundSystem by tier (UISoundFormulas.Tier -> TIERS).
local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	uiHover = { assetId = "rbxassetid://125412787340819", group = "UI", volume = 0.7, maxConcurrent = 2 },
	uiClick = { assetId = "rbxassetid://122165734026820", group = "UI", volume = 0.9, maxConcurrent = 2 },
	uiConfirm = { assetId = "rbxassetid://83738970696959", group = "UI", volume = 0.9, maxConcurrent = 2 },
	uiBack = { assetId = "rbxassetid://130280445606800", group = "UI", volume = 0.9, maxConcurrent = 2 },
	uiError = { assetId = "rbxassetid://139831732223870", group = "UI", volume = 0.9, maxConcurrent = 2 },
	uiCta = { assetId = "rbxassetid://78569365251759", group = "UI", volume = 1, maxConcurrent = 1 },
	uiPromptHold = { assetId = "rbxassetid://105267179969138", group = "UI", volume = 1, maxConcurrent = 1 },
	uiPromptDone = { assetId = "rbxassetid://134811176097827", group = "UI", volume = 1, maxConcurrent = 2 },
}
for id, def in SOUNDS do
	if not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end
UIAssets.sounds = table.freeze(SOUNDS)

-- The sound each UI tier plays.
local TIERS: { [string]: string } = {
	hover = "uiHover",
	click = "uiClick",
	confirm = "uiConfirm",
	back = "uiBack",
	error = "uiError",
	cta = "uiCta",
	hold = "uiPromptHold",
	done = "uiPromptDone",
}
UIAssets.soundTiers = table.freeze(TIERS)

return UIAssets
