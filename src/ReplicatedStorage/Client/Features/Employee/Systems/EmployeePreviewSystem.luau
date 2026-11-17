--!strict
--[=[
	EmployeePreviewSystem: the models the character screens show in ViewportFrames (Inventory, the first-join pick,
	later the Shop and reveals): any employee in any skin, built on the client from the art in ReplicatedStorage and
	dressed by the same EmployeeSkinSystem the server dresses real characters with, so a preview never drifts.

	- `static(employee, skin, source, pose?, style?, lanyard?)`: posed once and frozen (EmployeePortraitSystem.build): every part
	  anchored, no Animator, no scripts. The engine renders it once: cards and grids. Each look (employee, skin, style,
	  pose, the badge's rank, per source) is built once and kept: later calls get a Clone of it, so reopening the
	  Shop or the Inventory, or a card rebuilt after an equip or a purchase, never dresses and poses it again (that
	  ran the skin fitting, the lanyard and the pose for every card in one frame). `warm` builds looks ahead, one a
	  frame (UIPreloadSystem warms every crew card after the art preload). `reset` empties the cache.
	- `live(employee, skin, source, style?, lanyard?)`: the dressed model with its root held and the body free, an Animator, no
	  scripts: put it in a WorldModel and `playIdle` it. At most LIVE_CAP exist at once (the hero and one hovered
	  card); `live` returns nil past the cap. `release` destroys one and frees its slot at once (destroying it alone
	  frees the slot a frame later).
	- `lanyard` false leaves the rank lanyard off (Shop and Inventory items show the item, not you: owner 11-15); nil
	  or true wears it, as the server dresses a real character.
	- `skin` is an EmployeeRegistry skin key (nil = the default look); an unknown one falls back to the default.
	  `style` is its colour style (nil = 1; clamped to one the skin has).
	- `outfit(outfit, source, character, live, pose?)`: a whole player's look (CosmeticOutfitRules): a clone of
	  `character` (your own, live one) when it is that employee in that skin, so everything the server put on it
	  comes along (the rank lanyard and badge, the vacuum pack), else the dressed template; then the outfit's vacuum
	  goes on the pack (VacuumPreviewSystem.swap). Live (and its second result true) when asked and a slot is free,
	  else posed and frozen like `static`.
	- `whenLoaded(instances, onReady, preload?, seconds?)`: calls `onReady` once, when ContentProvider has loaded the
	  instances' assets (meshes, textures) or after `seconds` (PRELOAD_SECONDS, as long as the 3D stage waits),
	  whichever is first; a failed load still calls it. Returns a cancel. ToonViewport keeps a preview hidden until then
	  (owner, 2026-11-16: an item page showed the textured Showstopper's coat and hat but not its new bloomer mesh).
	  `loaded(instances, status?)` says whether all of it is in already, so a warm preview skips the wait and the redraw
	  (Shift 11-16: they cost the warm Shop open ~30 ms).
	- `idleOf` / `reachOf` / `fidgetOf` / `revealOf` / `reactionOf` / `emoteOf` (which clip a preview plays) live in
	  EmployeePreviewClipUtils, and `playIdle` / `playReveal` / `playReaction` / `playFidgets` / `playEmote` in
	  EmployeePreviewPlaySystem (both split out of this module); they are re-exported here under the same names.

	@class EmployeePreviewSystem
]=]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeeConstants = require(EmployeeShared.Data.EmployeeConstants)
local EmployeePoseRegistry = require(EmployeeShared.Data.EmployeePoseRegistry)
local EmployeeRegistry = require(EmployeeShared.Data.EmployeeRegistry)
local EmployeeSkinRules = require(EmployeeShared.Rules.EmployeeSkinRules)
local EmployeeSkinSystem = require(EmployeeShared.Systems.EmployeeSkinSystem)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local VacuumSkinRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumSkinRules)
local EmployeeClient = ReplicatedStorage.Client.Features.Employee
local EmployeePreviewClipUtils = require(EmployeeClient.Utils.EmployeePreviewClipUtils)
local EmployeePortraitSystem = require(EmployeeClient.Systems.EmployeePortraitSystem)
local EmployeeLanyardSystem = require(EmployeeClient.Systems.EmployeeLanyardSystem)
local EmployeePreviewPlaySystem = require(EmployeeClient.Systems.EmployeePreviewPlaySystem)
local VacuumPreviewSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumPreviewSystem)

local LIVE_CAP = 2
-- The longest a preview waits for its assets before it shows anyway (the same as EmployeeStageSystem).
local PRELOAD_SECONDS = 3

local EmployeePreviewSystem = {
	LIVE_CAP = LIVE_CAP,
	PRELOAD_SECONDS = PRELOAD_SECONDS,
	EMOTE_PAUSE = EmployeePreviewPlaySystem.EMOTE_PAUSE,
	REVEAL_FADE = EmployeePreviewPlaySystem.REVEAL_FADE,
	-- The clip lookups (EmployeePreviewClipUtils) and the players (EmployeePreviewPlaySystem), under their old names.
	idleOf = EmployeePreviewClipUtils.idleOf,
	reachOf = EmployeePreviewClipUtils.reachOf,
	fidgetOf = EmployeePreviewClipUtils.fidgetOf,
	revealOf = EmployeePreviewClipUtils.revealOf,
	reactionOf = EmployeePreviewClipUtils.reactionOf,
	emoteOf = EmployeePreviewClipUtils.emoteOf,
	playIdle = EmployeePreviewPlaySystem.playIdle,
	playReveal = EmployeePreviewPlaySystem.playReveal,
	playReaction = EmployeePreviewPlaySystem.playReaction,
	playFidgets = EmployeePreviewPlaySystem.playFidgets,
	playEmote = EmployeePreviewPlaySystem.playEmote,
}

local live: { [Model]: RBXScriptConnection } = {}
local liveCount = 0
-- Built static looks per source (in the game only ReplicatedStorage; specs pass their own and `reset` clears them),
-- by `staticKey`; at most STATIC_CACHE_CAP per source (past it the source's cache starts over).
local STATIC_CACHE_CAP = 64
local staticCache: { [Instance]: { [string]: Model } } = {}
local staticCount: { [Instance]: number } = {}

local function resolve(root: Instance, path: { string }): Instance?
	local current: Instance? = root
	for _, name in path do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

-- A dressed clone of the employee's art (scripts removed) in colour style `style` (nil = 1), or nil. It wears the rank
-- lanyard unless `lanyard` is false.
local function dressed(employee: string, skin: string?, source: Instance, style: number?, lanyard: boolean?): Model?
	local def = EmployeeRegistry.get(employee)
	if def == nil then
		return nil
	end
	local template = resolve(source, def.templatePath)
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	model:SetAttribute(EmployeeConstants.NAME_ATTRIBUTE, def.name)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	local look = EmployeeSkinRules.select(def, skin)
	if look ~= nil then
		-- The outfit is fitted in the style, as the server dresses a real character.
		EmployeeSkinSystem.apply(
			model,
			look,
			resolve(source, EmployeeConstants.ACCESSORIES_PATH),
			style,
			resolve(source, EmployeeConstants.OUTFITS_PATH)
		)
	end
	if lanyard ~= false then
		EmployeeLanyardSystem.attachPreview(model)
	end
	return model
end

-- A static look's cache key: everything its build depends on.
local function staticKey(
	employee: string,
	skin: string?,
	pose: EmployeePoseRegistry.PoseDef?,
	style: number?,
	lanyard: boolean?
): string
	local poseName = if pose ~= nil then pose.name else ""
	local rank = if lanyard == false then "bare" else tostring(EmployeeLanyardSystem.previewRank())
	return `{employee}|{skin or ""}|{style or 1}|{poseName}|{rank}`
end

function EmployeePreviewSystem.static(
	employee: string,
	skin: string?,
	source: Instance,
	pose: EmployeePoseRegistry.PoseDef?,
	style: number?,
	lanyard: boolean?
): Model?
	local key = staticKey(employee, skin, pose, style, lanyard)
	local builds = staticCache[source]
	local cached = if builds ~= nil then builds[key] else nil
	if cached ~= nil then
		return cached:Clone()
	end
	local model = dressed(employee, skin, source, style, lanyard)
	if model == nil then
		return nil
	end
	local copy = EmployeePortraitSystem.build(model, pose)
	model:Destroy()
	if copy == nil then
		return nil
	end
	if builds == nil or (staticCount[source] or 0) >= STATIC_CACHE_CAP then
		if builds ~= nil then
			for _, old in builds do
				old:Destroy()
			end
		end
		builds = {}
		staticCache[source] = builds
		staticCount[source] = 0
	end
	if builds ~= nil then
		builds[key] = copy
		staticCount[source] = (staticCount[source] or 0) + 1
	end
	return copy:Clone()
end

-- One look `warm` builds ahead: an employee, a skin (nil = the default look), the pose its cards use and whether they
-- wear the rank lanyard (nil = yes).
export type Look = { employee: string, skin: string?, pose: EmployeePoseRegistry.PoseDef?, lanyard: boolean? }

--[=[
	Builds `looks` into the static cache in the background, one per frame (starting the frame after the call), so the
	first Shop or Inventory open after joining clones its cards instead of building them all in one frame. Returns the
	cancel.
]=]
function EmployeePreviewSystem.warm(looks: { Look }, source: Instance): () -> ()
	local cancelled = false
	task.defer(function()
		for _, look in looks do
			RunService.Heartbeat:Wait()
			if cancelled then
				return
			end
			local copy = EmployeePreviewSystem.static(look.employee, look.skin, source, look.pose, nil, look.lanyard)
			if copy ~= nil then
				copy:Destroy()
			end
		end
	end)
	return function()
		cancelled = true
	end
end

-- Gives back `model`'s live slot (once).
local function free(model: Model)
	local connection: RBXScriptConnection? = live[model]
	if connection then
		connection:Disconnect()
		live[model] = nil
		liveCount -= 1
	end
end

-- Readies `model` to animate in a WorldModel (root held, body free, an Animator) and takes a live slot.
local function makeLive(model: Model): Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and humanoid:FindFirstChildOfClass("Animator") == nil then
		Instance.new("Animator").Parent = humanoid
	end
	liveCount += 1
	-- A backstop for a live preview destroyed without `release` (its slot frees when the deferred signal runs).
	live[model] = model.Destroying:Connect(function()
		free(model)
	end)
	return model
end

--[=[
	Destroys a live preview and frees its slot at once. Destroying alone frees it only when the deferred Destroying
	signal runs, a frame later, so a viewport rebuilding in the same frame (a colour style chip) got the frozen copy.
	Safe for a model that is not live, or released twice.
]=]
function EmployeePreviewSystem.release(model: Model)
	free(model)
	model:Destroy()
end

function EmployeePreviewSystem.live(
	employee: string,
	skin: string?,
	source: Instance,
	style: number?,
	lanyard: boolean?
): Model?
	if liveCount >= LIVE_CAP then
		return nil
	end
	local model = dressed(employee, skin, source, style, lanyard)
	return if model ~= nil then makeLive(model) else nil
end

-- A copy of a live character for a preview: scripts, tools and overhead labels left out.
local function cloneCharacter(character: Model): Model
	-- A player's character is not Archivable; it is made so just for the copy.
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	for _, descendant in copy:GetDescendants() do
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Tool")
			or descendant:IsA("BillboardGui")
			or descendant:IsA("ForceField")
		then
			descendant:Destroy()
		end
	end
	return copy
end

function EmployeePreviewSystem.outfit(
	outfit: CosmeticTypes.Outfit,
	source: Instance,
	character: Model?,
	wantLive: boolean,
	pose: EmployeePoseRegistry.PoseDef?
): (Model?, boolean)
	local skinKey = CosmeticRegistry.keyOf(outfit.look.skin)
	local def = EmployeeRegistry.get(outfit.employee)
	local skin = if def ~= nil then EmployeeSkinRules.select(def, skinKey) else nil
	local style = if skin ~= nil then EmployeeSkinRules.styleIndex(skin, outfit.look.style) else 1
	local model: Model? = nil
	-- Your own character only when it wears this employee, skin and colour style (the server stamps all three).
	if
		character ~= nil
		and character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) == outfit.employee
		and character:GetAttribute(EmployeeConstants.SKIN_ATTRIBUTE) == skinKey
		and (character:GetAttribute(EmployeeConstants.STYLE_ATTRIBUTE) or 1) == style
	then
		local copy = cloneCharacter(character)
		model = copy
		-- The copy keeps your world facing; a preview's camera (PortraitViewModel.camera, its `turn`) expects the rig
		-- upright facing -Z like the art, or a try-on meant to show your back opens on your front.
		copy:PivotTo(CFrame.new(copy:GetPivot().Position))
	end
	if model == nil then
		model = dressed(outfit.employee, skinKey, source, style)
	end
	if model == nil then
		return nil, false
	end
	VacuumPreviewSystem.swap(model, VacuumSkinRules.select(CosmeticRegistry.keyOf(outfit.vacuum)), source)
	if wantLive and liveCount < LIVE_CAP then
		return makeLive(model), true
	end
	local copy = EmployeePortraitSystem.build(model, pose, true)
	model:Destroy()
	return copy, false
end

function EmployeePreviewSystem.liveCount(): number
	return liveCount
end

-- Forgets every live slot (between specs).
function EmployeePreviewSystem.reset()
	for _, connection in live do
		connection:Disconnect()
	end
	table.clear(live)
	liveCount = 0
	for source, builds in staticCache do
		for _, model in builds do
			model:Destroy()
		end
		staticCache[source] = nil
		staticCount[source] = nil
	end
end

export type Preload = (instances: { Instance }) -> ()
export type FetchStatus = (contentId: string) -> Enum.AssetFetchStatus

local function fetchStatus(contentId: string): Enum.AssetFetchStatus
	return ContentProvider:GetAssetFetchStatus(contentId)
end

-- Every mesh and texture id `item` draws with (empty ids skipped).
local function contentIds(item: Instance, into: { string })
	local function add(id: string)
		if id ~= "" then
			table.insert(into, id)
		end
	end
	if item:IsA("MeshPart") then
		add(item.MeshId)
		add(item.TextureID)
	elseif item:IsA("SpecialMesh") then
		add(item.MeshId)
		add(item.TextureId)
	elseif item:IsA("SurfaceAppearance") then
		-- Read in a pcall: the maps are locked to plugins in some Studio builds, and an unreadable map counts as loaded
		-- rather than holding every preview back.
		pcall(function()
			add(item.ColorMap)
			add(item.NormalMap)
			add(item.RoughnessMap)
			add(item.MetalnessMap)
		end)
	elseif item:IsA("Decal") then
		add(item.Texture)
	end
end

--[=[
	True when every mesh, texture and SurfaceAppearance map in `instances` (and their descendants) has already loaded
	(`status`, default ContentProvider:GetAssetFetchStatus, is Success for each): a preview of it can show at once.
]=]
function EmployeePreviewSystem.loaded(instances: { Instance }, status: FetchStatus?): boolean
	local ids: { string } = {}
	for _, root in instances do
		contentIds(root, ids)
		for _, item in root:GetDescendants() do
			contentIds(item, ids)
		end
	end
	local check: FetchStatus = status or fetchStatus
	for _, id in ids do
		if check(id) ~= Enum.AssetFetchStatus.Success then
			return false
		end
	end
	return true
end

local function contentPreload(instances: { Instance })
	ContentProvider:PreloadAsync(instances)
end

--[=[
	Calls `onReady` once: when `preload` (default ContentProvider:PreloadAsync) has loaded `instances`, or after
	`seconds` (default PRELOAD_SECONDS), whichever is first. A failed load still calls it. The returned function
	cancels it (nothing is called after).
]=]
function EmployeePreviewSystem.whenLoaded(
	instances: { Instance },
	onReady: () -> (),
	preload: Preload?,
	seconds: number?
): () -> ()
	local done = false
	local function finish()
		if not done then
			done = true
			onReady()
		end
	end
	local load: Preload = preload or contentPreload
	task.spawn(function()
		pcall(load, instances)
		finish()
	end)
	local timer = task.delay(seconds or PRELOAD_SECONDS, finish)
	return function()
		done = true
		if coroutine.status(timer) == "suspended" then
			task.cancel(timer)
		end
	end
end

return EmployeePreviewSystem
