--!strict
--[=[
	AnimationsPanel (React): the F4 Debugger's live view of the LOCAL character's animation
	bookkeeping — the observation surface every Phase 6 verification checkpoint reads.

	Shows: the cache counters (loads vs hits — the proof the per-play-load disease stays dead),
	then one row per live track: registry id, declared interruption class, PRIORITY, weight, speed,
	looped flag, and the asset id shortened to its digits — click a row to expand the full id
	(V1 developer feedback: priority/weight matter for diagnosing pose contamination; the full id
	mostly doesn't).

	CLIENT-ONLY by design: animation playback state deliberately does not exist on the server (spec
	Decision 5), so DebuggerOverlay hides this tab entirely in the Server context rather than
	showing client data under a server label.

	Polls on a short interval rather than subscribing: the player's bookkeeping is plain data with
	no signals (by design — the pure core stays signal-free), and a 4 Hz read of a table this size
	is free.

	@class AnimationsPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local AnimationServiceClient = require(ReplicatedStorage.Client.Features.Animation.AnimationServiceClient)
local AnimationPlayerSystem = require(ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerSystem)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local DebuggerTheme = require(ReplicatedStorage.Client.UI.React.Debugger.DebuggerTheme)

local e = React.createElement

local POLL_SECONDS = 0.25
local ROW_HEIGHT = 16
local EXPANDED_ROW_HEIGHT = 32

type Snapshot = {
	playing: { AnimationPlayerSystem.PlayingInfo },
	counters: AnimationPlayerSystem.Counters,
}

local function readSnapshot(): Snapshot
	return {
		playing = AnimationServiceClient:playing(),
		counters = AnimationServiceClient:counters(),
	}
end

-- "rbxassetid://N" -> the last few digits of N: enough to tell two ids apart at a glance; the row
-- expands to the full id on click.
local function shortAssetId(assetId: string): string
	local digits = string.match(assetId, "%d+$")
	if digits == nil then
		return assetId
	end
	if #digits <= 6 then
		return digits
	end
	return `…{string.sub(digits, -6)}`
end

--[=[
	One live-track row. A TextButton so it can toggle its own expansion.
]=]
local function trackRow(
	info: AnimationPlayerSystem.PlayingInfo,
	order: number,
	expanded: boolean,
	onToggle: () -> ()
): React.ReactNode
	local domain = AnimationRegistry.domainOf(info.id) or "?"
	local summary =
		`{info.id}  [{domain}/{info.interruption}]  {info.priority.Name}  w={info.weight} x{info.speed}{if info.looped
			then "  looped"
			else ""}  {shortAssetId(info.assetId)}`
	return e("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, if expanded then EXPANDED_ROW_HEIGHT else ROW_HEIGHT),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 12,
		TextColor3 = DebuggerTheme.TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = if expanded then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		TextWrapped = expanded,
		Text = if expanded then `{summary}\n  {info.assetId}` else summary,
		[React.Event.Activated] = onToggle,
	})
end

--[=[
	The panel component.
	@return React.ReactNode
]=]
local function AnimationsPanel(): React.ReactNode
	local snapshot, setSnapshot = React.useState(readSnapshot)
	local expandedIds, setExpandedIds = React.useState({} :: { [string]: boolean }) -- useState needs the seed's type stated; an empty literal infers {}

	React.useEffect(function(): () -> ()
		local running = true
		task.spawn(function()
			while running do
				setSnapshot(readSnapshot())
				task.wait(POLL_SECONDS)
			end
		end)
		return function()
			running = false
		end
	end, {})

	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		counters = e("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = DebuggerTheme.ACCENT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `cache: {snapshot.counters.loads} load(s), {snapshot.counters.hits} hit(s)   ·   {#snapshot.playing} live track(s)`,
		}),
	}

	local canvasHeight = 20
	if #snapshot.playing == 0 then
		children.empty = e("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 12,
			TextColor3 = DebuggerTheme.MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "(no tracks playing — local character only; click a row for the full asset id)",
		})
		canvasHeight += ROW_HEIGHT + 2
	else
		-- `ipairs`: playing() sorts its snapshot by id, and generalized iteration would throw that
		-- order away — a debugger whose rows reshuffle between polls is unreadable.
		for index, info in ipairs(snapshot.playing) do
			local expanded = expandedIds[info.id] == true
			children[`track-{info.id}`] = trackRow(info, index + 1, expanded, function()
				setExpandedIds(function(previous: { [string]: boolean })
					local updated = table.clone(previous)
					-- Toggle from PREVIOUS, not from the render-time value: rapid clicks queue
					-- several updaters before a re-render, and the captured boolean would make
					-- them all write the same result (Qodo PR #13).
					updated[info.id] = not (previous[info.id] == true)
					return updated
				end)
			end)
			canvasHeight += (if expanded then EXPANDED_ROW_HEIGHT else ROW_HEIGHT) + 2
		end
	end

	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, canvasHeight),
		ScrollBarThickness = 4,
	}, children)
end

return AnimationsPanel
