--!strict
--[=[
	CargoBillboardSystem: draws cargo price tags on this client (Figma World UI 2b, W5). It watches the items' tag
	shells (UIBillboardHost.watch, tag CargoConstants.LABEL_TAG) and every LABEL_CHECK seconds mounts a tag for each
	item near the camera and unmounts the rest (CargoWorldViewModel.mounted: within 24 studs, kept until 28, never while
	hidden under a pile), so only a handful of React roots live at once. A mounted tag re-renders in place when the
	server changes its attributes (a fragile item cracked); a banked, destroyed or streamed-out item loses its root once.

	Spec-exempt shell (CollectionService, Camera, RunService, React roots); the decisions are the specced
	CargoWorldViewModel and the UIBillboards core.

	@class CargoBillboardSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local CargoPriceTag = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoPriceTag)
local CargoWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

export type CargoBillboardState = {
	shells: number,
	mounted: number,
	counters: { [string]: number },
}

local e = React.createElement

local roots = UIBillboards.new(UIBillboardHost.factory)
local shells: { [BillboardGui]: true } = {}
local mounted: { [BillboardGui]: true } = {}
local counters = { mounts = 0, unmounts = 0 }
local stoppers: { () -> () } = {}

local function draw(shell: BillboardGui)
	local view = CargoWorldViewModel.priceTag(shell:GetAttributes())
	roots.show(
		shell,
		if view ~= nil
			then e(WorldBillboard, { design = CargoConstants.LABEL_PX, sizing = "pixels" }, {
				tag = e(CargoPriceTag, { view = view }),
			})
			else nil
	)
end

local function distanceTo(shell: BillboardGui, from: Vector3): number
	local part = shell.Parent
	if part == nil or not part:IsA("BasePart") then
		return math.huge
	end
	return (part.Position - from).Magnitude
end

local function step()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local from = camera.CFrame.Position
	for shell in shells do
		local now = mounted[shell] == true
		local hidden = shell:GetAttribute(CargoConstants.LABEL_KEYS.hidden) == true
		local want = CargoWorldViewModel.mounted(distanceTo(shell, from), now, hidden)
		if want and not now then
			mounted[shell] = true
			counters.mounts += 1
			draw(shell)
		elseif now and not want then
			mounted[shell] = nil
			counters.unmounts += 1
			roots.hide(shell)
		end
	end
end

local CargoBillboardSystem = {}

function CargoBillboardSystem.start()
	if #stoppers > 0 then
		return
	end
	table.insert(
		stoppers,
		UIBillboardHost.watch({
			tag = CargoConstants.LABEL_TAG,
			roots = roots,
			refresh = function(shell)
				shells[shell] = true
				-- A mounted tag re-renders in place; an unmounted one waits for the next check.
				if mounted[shell] then
					draw(shell)
				end
			end,
			removed = function(shell)
				shells[shell] = nil
				mounted[shell] = nil
			end,
		})
	)
	local elapsed = 0
	local ticking = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= CargoConstants.LABEL_CHECK then
			elapsed = 0
			step()
		end
	end)
	table.insert(stoppers, function()
		ticking:Disconnect()
	end)
end

function CargoBillboardSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	roots.teardown()
	table.clear(shells)
	table.clear(mounted)
end

function CargoBillboardSystem.getState(): CargoBillboardState
	local total = 0
	for _ in shells do
		total += 1
	end
	return { shells = total, mounted = roots.count(), counters = table.clone(counters) }
end

return CargoBillboardSystem
