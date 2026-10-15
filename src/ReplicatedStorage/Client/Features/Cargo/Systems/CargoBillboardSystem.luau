--!strict
--[=[
	CargoBillboardSystem: draws cargo price tags on this client (Figma World UI 2b, W5). It watches the items' tag
	shells (UIBillboardHost.watch, tag CargoConstants.LABEL_TAG) and every LABEL_CHECK seconds mounts a tag for each
	selected nearby item, and for each valuable someone is cleaning right now (its ChannelCount, the loot loop: watch its
	percentage climb), and unmounts the rest (ShiftPromptStore selects by character reach, never while hidden under a
	pile). A mounted tag re-renders in place when the
	server changes its attributes (a fragile item cracked); a banked, destroyed or streamed-out item loses its root once.

	Spec-exempt shell (CollectionService, Camera, RunService, React roots); the decisions are the specced
	CargoWorldViewModel and the UIBillboards core.

	@class CargoBillboardSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
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

local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)

local roots = UIBillboards.new(UIBillboardHost.factory)
local shells: { [BillboardGui]: true } = {}
local mounted: { [BillboardGui]: true } = {}
local counters = { mounts = 0, unmounts = 0 }
local stoppers: { () -> () } = {}

local function draw(shell: BillboardGui)
	local view = CargoWorldViewModel.priceTag(shell:GetAttributes(), Workspace:GetServerTimeNow())
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
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local shown = ShiftPromptStore.shown()
	local selected = if shown ~= nil then shown.target else nil
	local from = if root ~= nil and root:IsA("BasePart") then root.Position else Vector3.new(math.huge, 0, 0)
	for shell in shells do
		local now = mounted[shell] == true
		local hidden = shell:GetAttribute(CargoConstants.LABEL_KEYS.hidden) == true
		local item = shell.Parent
		local count = if item ~= nil then item:GetAttribute(InteractionConstants.CHANNEL_COUNT_ATTRIBUTE) else nil
		local cleaning = type(count) == "number" and count > 0
		local chosen = selected ~= nil and (shell.Parent == selected or shell:IsDescendantOf(selected))
		local want = (chosen or cleaning) and CargoWorldViewModel.mounted(distanceTo(shell, from), now, hidden)
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
				if not shell:IsA("BillboardGui") then
					return
				end
				shells[shell] = true
				-- A mounted tag re-renders in place; an unmounted one waits for the next check.
				if mounted[shell] then
					draw(shell)
				end
			end,
			removed = function(shell)
				if not shell:IsA("BillboardGui") then
					return
				end
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
