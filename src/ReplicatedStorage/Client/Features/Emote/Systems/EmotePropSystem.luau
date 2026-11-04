--!strict
--[=[
	EmotePropSystem: shows and hides a character's emote props on this client, from the clip itself (owner pick,
	2026-10-29: the timing lives in the clip's markers, never a server timer).

	The server decides who has the props (EmployeeOutfitSystem fits them hidden, in EmployeeConstants.PROPS_FOLDER)
	and who emotes (EmoteServiceServer grants the clip, and stops it on a stop, knockdown or hiding). Every client then
	watches each character's Animator: the owner's track replicates, so the same track plays everywhere. For a track
	whose clip is in EmotePropRegistry:
	- EmoteConstants.PROPS_SHOW marker: its props show (Transparency 0, locally); PROPS_STOW: they hide. A prop the
	  skin wears at a holster (EmployeeConstants.HOLSTER_FOLDER) does the opposite, so it moves from hip to hand and
	  back.
	- EmoteConstants.PROP_HIDE / PROP_SHOW markers (Value = a prop name) swap single hand props inside the window: the
	  coil out of sight and the entry's `swaps` (the lasso loop) in. A late joiner sees the window's own props.
	- A track already playing when this client first sees it (a late joiner, a character streaming in) is matched
	  from its TimePosition against the PROPS_SHOW / PROPS_STOW keyframe times, since markers only fire forward.
	- Safe stow: the track stopping (finish, cancel or a server stop), the release (character gone, service stopped)
	  hide them. A newer prop track takes them over, and the old track's stop then changes nothing.
	- The emote's own props (owner, 2026-10-29: an emote works in any skin): a prop the character's skin does not have
	  is mounted by this client from the emote's template (EmoteConstants.PROP_TEMPLATES_PATH, by prop name) into
	  EmployeeConstants.EMOTE_MOUNTED_FOLDER, on its hand's Motor6D at the character's scale
	  (EmployeeOutfitSystem.mountProp), for as long as the clip owns the props. The skin's own (styled) prop always
	  wins: one arriving later replaces the mounted copy.
	Visibility is cosmetic and per client: a client can only change its own view.

	`deps` is a test seam: the character's Animator as a source of tracks, the clip lookup and the prop templates.

	@class EmotePropSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeOutfitSystem = require(ReplicatedStorage.Shared.Features.Employee.Systems.EmployeeOutfitSystem)
local EmoteConstants = require(ReplicatedStorage.Shared.Features.Emote.Data.EmoteConstants)
local EmotePropRegistry = require(ReplicatedStorage.Shared.Features.Emote.Data.EmotePropRegistry)

-- What the system reads of a playing AnimationTrack.
export type PropTrack = {
	assetId: string,
	timePosition: () -> number,
	isPlaying: () -> boolean,
	-- The time of the keyframe with this name, or nil when the clip has none.
	timeOfKeyframe: (name: string) -> number?,
	-- The callback gets the marker's Value (e.g. a face name).
	onMarker: (name: string, callback: (value: string) -> ()) -> () -> (),
	onStopped: (callback: () -> ()) -> () -> (),
}

-- A character's Animator: the tracks playing now, and each one it starts later.
export type TrackSource = {
	playing: () -> { PropTrack },
	onPlayed: (callback: (track: PropTrack) -> ()) -> () -> (),
}

export type Deps = {
	sourceOf: (character: Model) -> TrackSource?,
	keyForAsset: (assetId: string) -> string?,
	-- The emote's own template of a prop, by name (nil: none).
	templateOf: ((name: string) -> BasePart?)?,
}

export type EmotePropState = {
	tracked: number,
	showing: number,
}

export type EmotePropSystem = {
	-- Starts watching a character (or a preview model); returns the release, which hides its props.
	track: (character: Model) -> () -> (),
	getState: () -> EmotePropState,
}

-- The registry's canonical `rbxassetid://N` form of an AnimationId (a replicated track may carry another form).
local function canonical(id: string): string
	local digits = string.match(id, "(%d+)$")
	return if digits ~= nil then "rbxassetid://" .. digits else id
end

local function wrapTrack(track: AnimationTrack): PropTrack
	return {
		assetId = canonical(track.Animation.AnimationId),
		timePosition = function()
			return track.TimePosition
		end,
		isPlaying = function()
			return track.IsPlaying
		end,
		timeOfKeyframe = function(name)
			-- Errors when the clip has no keyframe of that name.
			local ok, time = pcall(function()
				return track:GetTimeOfKeyframe(name)
			end)
			return if ok then time else nil
		end,
		onMarker = function(name, callback)
			local connection = track:GetMarkerReachedSignal(name):Connect(function(value: string?)
				callback(value or "")
			end)
			return function()
				connection:Disconnect()
			end
		end,
		onStopped = function(callback)
			local connection = track.Stopped:Connect(callback)
			return function()
				connection:Disconnect()
			end
		end,
	}
end

local function animatorSource(animator: Animator): TrackSource
	return {
		playing = function()
			local out = {}
			for _, track in animator:GetPlayingAnimationTracks() do
				table.insert(out, wrapTrack(track))
			end
			return out
		end,
		onPlayed = function(callback)
			local connection = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
				callback(wrapTrack(track))
			end)
			return function()
				connection:Disconnect()
			end
		end,
	}
end

-- The character's Animator, under its Humanoid or AnimationController (nil until it exists).
local function realSource(character: Model): TrackSource?
	local host: Instance? = character:FindFirstChildOfClass("Humanoid")
	if host == nil then
		host = character:FindFirstChildOfClass("AnimationController")
	end
	local animator = if host ~= nil then host:FindFirstChildOfClass("Animator") else nil
	return if animator ~= nil then animatorSource(animator) else nil
end

-- The emote prop template with this name, under ReplicatedStorage at EmoteConstants.PROP_TEMPLATES_PATH.
local function realTemplate(name: string): BasePart?
	local node: Instance? = ReplicatedStorage
	for _, step in EmoteConstants.PROP_TEMPLATES_PATH do
		node = if node ~= nil then node:FindFirstChild(step) else nil
	end
	local found = if node ~= nil then node:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

local defaults: Deps = {
	sourceOf = realSource,
	keyForAsset = EmotePropRegistry.keyForAsset,
	templateOf = realTemplate,
}

-- The skin's own prop `name` on `character`, or nil.
local function skinProp(character: Model, name: string): BasePart?
	local folder = character:FindFirstChild(EmployeeConstants.PROPS_FOLDER)
	local found = if folder ~= nil then folder:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

local EmotePropSystem = {}

--[=[
	The character's Animator as a TrackSource (nil until it exists): EmoteEffectSystem watches the same tracks.
]=]
EmotePropSystem.realSource = realSource

--[=[
	The hand prop `name` an emote is using on `character`: the skin's own, else the emote's mounted copy; nil when
	neither is there (EmoteVfxSystem finds the wand's loop with it).
]=]
function EmotePropSystem.findProp(character: Model, name: string): BasePart?
	local own = skinProp(character, name)
	if own ~= nil then
		return own
	end
	local folder = character:FindFirstChild(EmployeeConstants.EMOTE_MOUNTED_FOLDER)
	local found = if folder ~= nil then folder:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

--[=[
	The system for characters in the world (EmoteServiceClient): a menus-only clip (a skin's showcase idle, which plays
	in a shift too) never brings out props there (EmotePropRegistry `menusOnly`). Previews use `new()`.
]=]
function EmotePropSystem.forWorld(): EmotePropSystem
	return EmotePropSystem.new({
		sourceOf = realSource,
		keyForAsset = EmotePropRegistry.worldKeyForAsset,
		templateOf = realTemplate,
	})
end

function EmotePropSystem.new(deps: Deps?): EmotePropSystem
	local use: Deps = deps or defaults
	local templateOf = use.templateOf
	local tracked = 0
	local showing: { [Model]: boolean } = {}

	return {
		track = function(character)
			tracked += 1
			local released = false
			local props: { string } = {}
			local swaps: { string } = {}
			-- PROP_SHOW / PROP_HIDE overrides for this clip, by prop name (unset: shown with the window if in `props`).
			local overrides: { [string]: boolean } = {}
			local visible = false
			local owner: PropTrack? = nil
			local ownerCleanups: { () -> () } = {}
			local cleanups: { () -> () } = {}

			local function paint(folderName: string, name: string, shown: boolean)
				local folder = character:FindFirstChild(folderName)
				local part = if folder ~= nil then folder:FindFirstChild(name) else nil
				if part ~= nil and part:IsA("BasePart") then
					part.Transparency = if shown then 0 else 1
				end
			end

			-- The emote's own copies of the props this skin lacks (this client's, for the owning clip only).
			local mountedFolder: Folder? = nil
			local function unmount()
				local folder = mountedFolder
				mountedFolder = nil
				if folder ~= nil then
					folder:Destroy()
				end
			end
			local function mount(names: { string })
				if templateOf == nil then
					return
				end
				for _, name in names do
					local template = if skinProp(character, name) == nil then templateOf(name) else nil
					local copy = if template ~= nil
						then EmployeeOutfitSystem.mountProp(character, template, nil)
						else nil
					if copy ~= nil then
						local folder = mountedFolder
						if folder == nil then
							local made = Instance.new("Folder")
							made.Name = EmployeeConstants.EMOTE_MOUNTED_FOLDER
							made.Parent = character
							mountedFolder = made
							folder = made
						end
						copy.Parent = folder
					end
				end
			end

			-- The hand props show while visible (a swap marker can hide one or bring a swap prop out); the worn twins
			-- at the holster show while not (the coil stays off the hip while it is a loop in the hand, too).
			local function apply()
				for _, name in props do
					local override = overrides[name]
					local shown = visible and (override == nil or override)
					paint(EmployeeConstants.PROPS_FOLDER, name, shown)
					paint(EmployeeConstants.EMOTE_MOUNTED_FOLDER, name, shown)
					paint(EmployeeConstants.HOLSTER_FOLDER, name, not visible)
				end
				for _, name in swaps do
					local shown = visible and overrides[name] == true
					paint(EmployeeConstants.PROPS_FOLDER, name, shown)
					paint(EmployeeConstants.EMOTE_MOUNTED_FOLDER, name, shown)
				end
			end

			local function setVisible(value: boolean)
				visible = value
				if value then
					showing[character] = true
				else
					showing[character] = nil
				end
				apply()
			end

			local function disown()
				for _, cleanup in ownerCleanups do
					cleanup()
				end
				table.clear(ownerCleanups)
				owner = nil
				table.clear(overrides)
				setVisible(false)
				unmount()
			end

			local function adopt(track: PropTrack)
				local key = use.keyForAsset(track.assetId)
				local entry = if key ~= nil then EmotePropRegistry.get(key) else nil
				if entry == nil or released then
					return
				end
				disown()
				owner = track
				props = entry.props
				swaps = entry.swaps or {}
				mount(props)
				mount(swaps)
				for _, spec in
					{
						{ marker = EmoteConstants.PROP_SHOW, shown = true },
						{ marker = EmoteConstants.PROP_HIDE, shown = false },
					}
				do
					table.insert(
						ownerCleanups,
						track.onMarker(spec.marker, function(name)
							if
								owner == track and (table.find(props, name) ~= nil or table.find(swaps, name) ~= nil)
							then
								overrides[name] = spec.shown
								apply()
							end
						end)
					)
				end
				table.insert(
					ownerCleanups,
					track.onMarker(EmoteConstants.PROPS_SHOW, function()
						if owner == track then
							setVisible(true)
						end
					end)
				)
				table.insert(
					ownerCleanups,
					track.onMarker(EmoteConstants.PROPS_STOW, function()
						if owner == track then
							setVisible(false)
						end
					end)
				)
				table.insert(
					ownerCleanups,
					track.onStopped(function()
						if owner == track then
							disown()
						end
					end)
				)
				-- Resync: markers only fire forward, so a track met mid-clip is matched from its time.
				local show = track.timeOfKeyframe(EmoteConstants.PROPS_SHOW)
				local stow = track.timeOfKeyframe(EmoteConstants.PROPS_STOW)
				local now = track.timePosition()
				local inWindow = show ~= nil and now >= show and (stow == nil or now < stow)
				setVisible(track.isPlaying() and inWindow == true)
			end

			-- A prop that arrives later (replication, a refit) takes the current state.
			local added = character.DescendantAdded:Connect(function(descendant: Instance)
				local name = descendant.Name
				if
					descendant:IsA("BasePart") and (table.find(props, name) ~= nil or table.find(swaps, name) ~= nil)
				then
					-- The skin's own prop replaces this client's mounted copy.
					local folder = mountedFolder
					local copy = if folder ~= nil then folder:FindFirstChild(name) else nil
					if copy ~= nil and skinProp(character, name) == descendant then
						copy:Destroy()
					end
					apply()
				end
			end)
			table.insert(cleanups, function()
				added:Disconnect()
			end)

			local function bind(source: TrackSource)
				table.insert(cleanups, source.onPlayed(adopt))
				for _, track in source.playing() do
					adopt(track)
				end
			end

			local source = use.sourceOf(character)
			if source ~= nil then
				bind(source)
			else
				-- A replicated character can arrive before its Animator does.
				local waiting: RBXScriptConnection? = nil
				waiting = character.DescendantAdded:Connect(function()
					local found = use.sourceOf(character)
					if found ~= nil and not released then
						local connection = waiting
						if connection ~= nil then
							connection:Disconnect()
						end
						bind(found)
					end
				end)
				table.insert(cleanups, function()
					local connection = waiting
					if connection ~= nil then
						connection:Disconnect()
					end
				end)
			end

			return function()
				if released then
					return
				end
				released = true
				tracked -= 1
				disown()
				showing[character] = nil
				for _, cleanup in cleanups do
					cleanup()
				end
				table.clear(cleanups)
			end
		end,

		getState = function()
			local count = 0
			for _ in showing do
				count += 1
			end
			return { tracked = tracked, showing = count }
		end,
	}
end

return EmotePropSystem
