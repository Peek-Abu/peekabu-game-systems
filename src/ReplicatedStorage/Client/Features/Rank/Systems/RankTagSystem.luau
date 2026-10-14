--!strict
--[=[
	RankTagSystem: draws each player's overhead staff badge on this client (Cleanup Crew "Clearance Level"): their
	name and company rank on a paper ID card (RankNameTag) hung from a lanyard in their level's colour. One local
	pixel-sized BillboardGui per character (in PlayerGui, adorned to the head, ResetOnSpawn off), drawn through the
	UIBillboards roots; it re-renders only when that player's published rank changes (their public entry,
	RankConstants.PUBLIC_XP_FIELD). Once a badge shows, the engine's own name label on that character is hidden on
	this client (a local Humanoid.DisplayDistanceType write), so the name is never drawn twice.

	The local player's own badge shows when RankConstants.TAG_SHOW_OWN is set. Nothing here is authoritative: the
	server publishes the rank and this only draws it.

	@class RankTagSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local React = require(ReplicatedStorage.Packages.React)
local RankConstants = require(ReplicatedStorage.Shared.Features.Rank.Data.RankConstants)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local RankNameTag = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankNameTag)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

export type RankTagState = {
	tags: number,
	mounted: number,
	draws: number,
}

local e = React.createElement

type Tag = {
	shell: BillboardGui,
	character: Model,
	head: BasePart,
	humanoid: Humanoid?,
	-- The rank last drawn ("xp:prev"), so unrelated public changes never re-render.
	drawn: string?,
}

local roots = UIBillboards.new(UIBillboardHost.factory)
local tags: { [Player]: Tag } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local stoppers: { () -> () } = {}
local counters = { draws = 0 }

-- Hangs the badge's foot TAG_HEIGHT studs above the character's top (ears and hats included), measured from the head.
local function place(tag: Tag)
	local frame, size = tag.character:GetBoundingBox()
	local top = frame.Position.Y + size.Y / 2
	tag.shell.StudsOffsetWorldSpace = Vector3.new(0, math.max(top - tag.head.Position.Y, tag.head.Size.Y / 2), 0)
		+ Vector3.new(0, RankConstants.TAG_HEIGHT, 0)
end

local function draw(player: Player, tag: Tag)
	place(tag)
	local rank = RankViewModel.rankOf(StateSyncClientStore.publicPlayers(), player.UserId)
	local key = if rank ~= nil then `{rank.xp}:{rank.prevXp}` else "none"
	if tag.drawn == key then
		return
	end
	tag.drawn = key
	local view = RankViewModel.tag(rank, player.DisplayName)
	if view == nil then
		roots.show(tag.shell, nil)
		return
	end
	counters.draws += 1
	roots.show(
		tag.shell,
		e(WorldBillboard, { design = RankConstants.TAG_PX, sizing = "pixels" }, {
			tag = e(RankNameTag, { view = view }),
		})
	)
	local humanoid = tag.humanoid
	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function detach(player: Player)
	local tag = tags[player]
	if tag == nil then
		return
	end
	tags[player] = nil
	roots.hide(tag.shell)
	tag.shell:Destroy()
end

local function attach(player: Player, character: Model)
	detach(player)
	local head = character:WaitForChild("Head", 10)
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if head == nil or not head:IsA("BasePart") or playerGui == nil or player.Character ~= character then
		return
	end
	local shell = Instance.new("BillboardGui")
	shell.Name = `RankTag_{player.UserId}`
	shell.Adornee = head
	shell.Size = UDim2.fromOffset(RankConstants.TAG_PX.X, RankConstants.TAG_PX.Y)
	-- The shell's bottom edge sits on the offset point, so the badge hangs up from it.
	shell.SizeOffset = Vector2.new(0, 0.5)
	shell.MaxDistance = RankConstants.TAG_MAX_DISTANCE
	shell.LightInfluence = 0
	-- Sibling layering, as the UI kit is drawn (a new BillboardGui defaults to Global, which buries the text under
	-- the card's paper).
	shell.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	shell.ResetOnSpawn = false
	shell.Parent = playerGui
	local tag: Tag = {
		shell = shell,
		character = character,
		head = head,
		humanoid = character:FindFirstChildOfClass("Humanoid"),
		drawn = nil,
	}
	tags[player] = tag
	draw(player, tag)
end

local function track(player: Player)
	if player == Players.LocalPlayer and not RankConstants.TAG_SHOW_OWN then
		return
	end
	local connections = {
		player.CharacterAdded:Connect(function(character: Model)
			attach(player, character)
		end),
		player.CharacterRemoving:Connect(function()
			detach(player)
		end),
	}
	playerConnections[player] = connections
	local character = player.Character
	if character ~= nil then
		task.spawn(attach, player, character)
	end
end

local function untrack(player: Player)
	detach(player)
	local connections = playerConnections[player]
	if connections ~= nil then
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	playerConnections[player] = nil
end

local RankTagSystem = {}

function RankTagSystem.start()
	if #stoppers > 0 then
		return
	end
	for _, player in Players:GetPlayers() do
		track(player)
	end
	local added = Players.PlayerAdded:Connect(track)
	local removed = Players.PlayerRemoving:Connect(untrack)
	local unsubscribe = Charm.subscribe(StateSyncClientStore.publicPlayers, function()
		for player, tag in tags do
			draw(player, tag)
		end
	end)
	table.insert(stoppers, function()
		added:Disconnect()
		removed:Disconnect()
		unsubscribe()
	end)
end

function RankTagSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	for player in playerConnections do
		untrack(player)
	end
	roots.teardown()
	table.clear(tags)
end

function RankTagSystem.getState(): RankTagState
	local total = 0
	for _ in tags do
		total += 1
	end
	return { tags = total, mounted = roots.count(), draws = counters.draws }
end

return RankTagSystem
