--!strict
--[=[
	OccupantBillboardSystem: draws Mr. Harlow's cue disc (W7) and memo (W8) on this client (Figma World UI 2b) into the
	two shells on his head (tags OccupantConstants.CUE_TAG / SPEECH_TAG), one React root each for the shell's life
	(UIBillboards). An attribute change re-renders in place: a new line keeps the memo mounted and retypes it, a cleared
	line or cue draws nothing until the next one. His voice is OccupantPresenceSystem's.

	Spec-exempt shell (CollectionService, React roots); the decisions are the specced OccupantWorldViewModel and the
	UIBillboards core.

	@class OccupantBillboardSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local OccupantCueDisc = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantCueDisc)
local OccupantMemo = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantMemo)
local OccupantWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

export type OccupantBillboardState = {
	mounted: number,
}

local e = React.createElement

local roots = UIBillboards.new(UIBillboardHost.factory)
local stoppers: { () -> () } = {}

local function drawCue(shell: BillboardGui)
	local view = OccupantWorldViewModel.cue(shell:GetAttribute(OccupantConstants.CUE_ATTRIBUTE))
	roots.show(
		shell,
		if view ~= nil
			then e(WorldBillboard, { design = OccupantConstants.CUE_PX, sizing = "studs" }, {
				cue = e(OccupantCueDisc, { view = view }),
			})
			else nil
	)
end

local function drawMemo(shell: BillboardGui)
	local view = OccupantWorldViewModel.memo(shell:GetAttribute(OccupantConstants.LINE_ATTRIBUTE))
	roots.show(
		shell,
		if view ~= nil
			then e(WorldBillboard, { design = OccupantConstants.MEMO_PX, sizing = "pixels" }, {
				memo = e(OccupantMemo, { view = view }),
			})
			else nil
	)
end

local OccupantBillboardSystem = {}

function OccupantBillboardSystem.start()
	if #stoppers > 0 then
		return
	end
	table.insert(stoppers, UIBillboardHost.watch({ tag = OccupantConstants.CUE_TAG, roots = roots, refresh = drawCue }))
	table.insert(
		stoppers,
		UIBillboardHost.watch({ tag = OccupantConstants.SPEECH_TAG, roots = roots, refresh = drawMemo })
	)
end

function OccupantBillboardSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	roots.teardown()
end

function OccupantBillboardSystem.getState(): OccupantBillboardState
	return { mounted = roots.count() }
end

return OccupantBillboardSystem
