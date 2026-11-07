--!strict
--[=[
	TrainingSignSystem: training's world signs on this client (the hall's stop signs, the hub's Training pad sign).
	`show` hangs a stud-sized BillboardGui on a part (made once per part, on this client only) and draws a TrainingSign
	in it through one UIBillboards core; `hide` removes one; `teardown` removes them all.

	Spec-exempt shell (BillboardGuis, React roots); the root bookkeeping is the specced UIBillboards core.

	@class TrainingSignSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local TrainingSign = require(ReplicatedStorage.Client.UI.React.Screens.Training.TrainingSign)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

local DESIGN = Vector2.new(600, 170)
-- The sign's size in studs (the design's aspect).
local STUDS = Vector2.new(9, 9 * 170 / 600)
local MAX_DISTANCE = 140

local roots = UIBillboards.new(UIBillboardHost.factory)
local shells: { [BasePart]: BillboardGui } = {}

local TrainingSignSystem = {}

--[=[
	Draws `props` on `part`'s sign, `lift` studs above the part's centre.
]=]
function TrainingSignSystem.show(part: BasePart, props: TrainingSign.TrainingSignProps, lift: number)
	local existing: BillboardGui? = shells[part]
	local shell: BillboardGui
	if existing ~= nil and existing.Parent ~= nil then
		shell = existing
	else
		local made = Instance.new("BillboardGui")
		made.Name = "TrainingSign"
		made.Size = UDim2.fromScale(STUDS.X, STUDS.Y)
		made.StudsOffsetWorldSpace = Vector3.new(0, lift, 0)
		made.MaxDistance = MAX_DISTANCE
		made.LightInfluence = 0
		made.ResetOnSpawn = false
		made.Adornee = part
		made.Parent = part
		shells[part] = made
		shell = made
	end
	roots.show(
		shell,
		React.createElement(
			WorldBillboard,
			{ design = DESIGN, sizing = "studs" },
			{ sign = React.createElement(TrainingSign, props) }
		)
	)
end

function TrainingSignSystem.hide(part: BasePart)
	local shell: BillboardGui? = shells[part]
	shells[part] = nil
	if shell ~= nil then
		roots.hide(shell)
		shell:Destroy()
	end
end

function TrainingSignSystem.teardown()
	roots.teardown()
	for _, shell in shells do
		shell:Destroy()
	end
	table.clear(shells)
end

return TrainingSignSystem
