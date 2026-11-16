--!strict
--[=[
	EmployeeLanyardSystem: builds the v4 fitted ribbon strap and v6 rank badge (info card on the front, 3D rank icon
	relief on the back) on every employee character on the client, driven by the player's general account rank
	(gates: characters/employees_build/gates/7f_badges_v6_info_front_icon_back.md).

	- Strips any legacy company uniform pieces (`PippaVest`, `PippaLanyard`) and `VacuumBackpack.Straps` so nothing
	  covers the lanyard runs.
	- Builds the strap as one `EditableMesh` `MeshPart` welded to `UpperTorso` (with a `Beam` chain fallback when the
	  editable mesh budget refuses).
	- Attaches the v6 rank badge (`R1..R7` under `ReplicatedStorage.Assets.CleanupCrew.LanyardBadges`) at the ferrule
	  origin (`WorldPivot = CFrame.identity`) and mounts the whole-face front `InfoCard` (`SurfaceGui` in `PlayerGui`
	  adorned to `InfoCardHost`, so its circular 3D headshot `ViewportFrame` renders in Play).
	- Runs the sleeping badge sway spring (`RenderStepped` only while accelerating; zero cost at rest).
	- Rebuilds cleanly (with ticket cancellation and `EditableMesh:Destroy()`) when the player's general rank changes.

	The strap build lives in EmployeeLanyardStrapSystem, the front info card in EmployeeLanyardCardSystem, the sway
	spring in EmployeeLanyardSwaySystem, the shared part helpers in EmployeeLanyardPartUtils and the `Handle` type in
	EmployeeLanyardTypes (all split out of this module). This is the bind/attach shell (exempt; ribbon geometry,
	widths and spring specced in `EmployeeLanyardFormulas.spec`).

	@class EmployeeLanyardSystem
]=]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeeConstants = require(EmployeeShared.Data.EmployeeConstants)
local EmployeeLanyardConstants = require(EmployeeShared.Data.EmployeeLanyardConstants)
local EmployeeLanyardFormulas = require(EmployeeShared.Utils.EmployeeLanyardFormulas)
local EmployeeClient = ReplicatedStorage.Client.Features.Employee
local EmployeeLanyardTypes = require(EmployeeClient.Data.EmployeeLanyardTypes)
local EmployeeLanyardPartUtils = require(EmployeeClient.Utils.EmployeeLanyardPartUtils)
local EmployeeLanyardCardSystem = require(EmployeeClient.Systems.EmployeeLanyardCardSystem)
local EmployeeLanyardStrapSystem = require(EmployeeClient.Systems.EmployeeLanyardStrapSystem)
local EmployeeLanyardSwaySystem = require(EmployeeClient.Systems.EmployeeLanyardSwaySystem)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)

type Fit = EmployeeLanyardFormulas.Fit

export type Handle = EmployeeLanyardTypes.Handle

local LEGACY_UNIFORM: { [string]: boolean } = {
	PippaVest = true,
	PippaLanyard = true,
}

local preloaded = false

local EmployeeLanyardSystem = {}

local v3 = EmployeeLanyardPartUtils.v3
local quiet = EmployeeLanyardPartUtils.quiet

local function badgeFolder(): Instance?
	local current: Instance? = ReplicatedStorage
	for _, name in EmployeeConstants.LANYARD_BADGES_PATH do
		if current == nil then
			break
		end
		current = current:FindFirstChild(name)
	end
	if current ~= nil then
		return current
	end
	local testKit = ReplicatedStorage:FindFirstChild("_LanyardV4Test")
	return if testKit ~= nil then testKit:FindFirstChild("BadgesInfo") else nil
end

local function preloadBadgesOnce()
	if preloaded then
		return
	end
	preloaded = true
	task.spawn(function()
		local folder = badgeFolder()
		if folder == nil then
			return
		end
		local list: { Instance } = {}
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("MeshPart") then
				table.insert(list, descendant)
			end
		end
		if #list > 0 then
			pcall(function()
				ContentProvider:PreloadAsync(list)
			end)
		end
	end)
end

function EmployeeLanyardSystem.attach(
	character: Model,
	fit: Fit,
	rank: number,
	badgeTemplate: Model?,
	flipped: boolean?,
	syncOnly: boolean?
): Handle?
	local ut = character:FindFirstChild("UpperTorso")
	if ut == nil or not ut:IsA("BasePart") then
		return nil
	end
	local scale = ut.Size.X / fit.ut_size[1]
	local folder = Instance.new("Folder")
	folder.Name = EmployeeConstants.LANYARD_FOLDER
	local strap: MeshPart? = nil
	local em: EditableMesh? = nil
	if not syncOnly then
		strap, em = EmployeeLanyardStrapSystem.buildStrapMesh(fit, rank, scale, ut)
	end
	if strap ~= nil then
		strap.Parent = folder
	else
		-- syncOnly is the preview path (attachPreview): a card is small, so it takes the coarser strap.
		local tolerance = if syncOnly
			then EmployeeLanyardConstants.PREVIEW_RIBBON_TOLERANCE
			else EmployeeLanyardConstants.PART_RIBBON_TOLERANCE
		EmployeeLanyardStrapSystem.fallbackRibbonParts(fit, rank, scale, ut, folder, tolerance)
	end
	local badgeWeld: Weld? = nil
	local badgeRoot: BasePart? = nil
	local cardZ: number? = nil
	local turn = if flipped then CFrame.Angles(0, math.pi, 0) else CFrame.identity
	if badgeTemplate ~= nil then
		local root = Instance.new("Part")
		root.Name = "BadgePivot"
		root.Size = Vector3.new(0.05, 0.05, 0.05)
		root.Transparency = 1
		quiet(root)
		local pv = v3(fit.pivot_rbx) * scale
		local restEntry = fit.badge_rest[tostring(rank)] or fit.badge_rest["1"]
		local pitch = if restEntry ~= nil then restEntry.pitch_deg else 0
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = ut, root
		weld.C0 = CFrame.new(pv) * CFrame.Angles(math.rad(pitch), 0, 0)
		root.CFrame = ut.CFrame * weld.C0
		weld.Parent = root
		root.Parent = folder
		local m = badgeTemplate:Clone()
		m.WorldPivot = CFrame.identity
		if scale ~= 1 then
			m:ScaleTo(m:GetScale() * scale)
		end
		-- The opaque parts in badge space, before they are moved into world: the info card has to sit in front of the
		-- front-most of them, and that depth differs per rank (R1 -0.0203, R5 -0.0240, ...).
		local faces: { EmployeeLanyardFormulas.BadgePart } = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				-- Imported +Z front becomes fitted -Z front, keeping the rear relief behind the information card.
				d.CFrame = EmployeeLanyardFormulas.badgePartCFrame(d.CFrame)
				if d.Transparency < 1 then
					table.insert(faces, { cframe = d.CFrame, size = d.Size })
				end
				quiet(d)
				d.CFrame = root.CFrame * turn * d.CFrame
				local wc = Instance.new("WeldConstraint")
				wc.Part0, wc.Part1 = root, d
				wc.Parent = d
			end
		end
		cardZ = EmployeeLanyardFormulas.cardZ(faces)
		m.Parent = folder
		badgeWeld = weld
		badgeRoot = root
	end
	folder.Parent = character
	return {
		folder = folder,
		strap = strap,
		badgeWeld = badgeWeld,
		badgeRoot = badgeRoot,
		badgeTurn = turn,
		cardZ = cardZ,
		scale = scale,
		destroy = function()
			folder:Destroy()
			if em ~= nil then
				em:Destroy()
			end
		end,
	}
end

local function resolveRank(player: Player?, character: Model): number
	local attr = character:GetAttribute(EmployeeConstants.RANK_ATTRIBUTE)
	if type(attr) == "number" and attr >= 1 and attr <= 7 then
		return math.floor(attr)
	end
	if player ~= nil then
		local rank = RankViewModel.rankOf(StateSyncClientStore.publicPlayers(), player.UserId)
		if rank ~= nil then
			return math.clamp(RankFormulas.progress(rank.xp).level.level, 1, 7)
		end
	end
	return 1
end

--[=[
	The rank a preview's badge shows (attachPreview): your own published rank, 1..7 (1 before it syncs). A cache of
	built previews keys on it, so a rank-up rebuilds them.
]=]
function EmployeeLanyardSystem.previewRank(): number
	local localPlayer = Players.LocalPlayer
	if localPlayer ~= nil then
		local rank = RankViewModel.rankOf(StateSyncClientStore.publicPlayers(), localPlayer.UserId)
		if rank ~= nil then
			return math.clamp(RankFormulas.progress(rank.xp).level.level, 1, 7)
		end
	end
	return 1
end

local function stripLegacyPiece(descendant: Instance)
	local parent = descendant.Parent
	if
		LEGACY_UNIFORM[descendant.Name]
		or (descendant.Name == "Straps" and parent and parent.Name == "VacuumBackpack")
	then
		task.defer(function()
			if descendant.Parent then
				descendant:Destroy()
			end
		end)
	end
end

function EmployeeLanyardSystem.attachPreview(model: Model)
	local ut = model:FindFirstChild("UpperTorso")
	if ut == nil or not ut:IsA("BasePart") or model:FindFirstChild(EmployeeConstants.LANYARD_FOLDER) ~= nil then
		return
	end
	local localPlayer = Players.LocalPlayer
	local rank = resolveRank(localPlayer, model)
	local empAttr = model:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE)
	local empName = if type(empAttr) == "string" then empAttr else nil
	local fit = EmployeeLanyardFormulas.fitForTorso(empName, ut.Size)
	local set = badgeFolder()
	local badgeTemplate = if set ~= nil then set:FindFirstChild(`R{rank}`) else nil
	local handle = EmployeeLanyardSystem.attach(
		model,
		fit,
		rank,
		if badgeTemplate ~= nil and badgeTemplate:IsA("Model") then badgeTemplate else nil,
		false,
		true
	)
	if handle ~= nil then
		model.Destroying:Connect(function()
			handle.destroy()
		end)
	end
end

function EmployeeLanyardSystem.bind(player: Player?, character: Model): () -> ()
	preloadBadgesOnce()
	for _, descendant in character:GetDescendants() do
		stripLegacyPiece(descendant)
	end
	local stripConn = character.DescendantAdded:Connect(stripLegacyPiece)

	local ticket = 0
	local currentHandle: Handle? = nil
	local stopSway: (() -> ())? = nil
	local currentRank = 0
	local currentFlip = false

	local function releaseCurrent()
		if stopSway ~= nil then
			stopSway()
			stopSway = nil
		end
		if currentHandle ~= nil then
			currentHandle.destroy()
			currentHandle = nil
		end
	end

	-- The rank and flip of the build in flight (attach yields on CreateMeshPartAsync), nil when none is.
	local buildingRank: number? = nil
	local buildingFlip = false

	local function rebuild()
		-- Any player's public data changing calls this. When it asks for what is already being built (or already
		-- worn), the build in flight is left to finish instead of being thrown away and started again.
		local wantedRank = resolveRank(player, character)
		local wantedFlip = character:GetAttribute(EmployeeConstants.LANYARD_FLIP_ATTRIBUTE) == true
		if buildingRank ~= nil then
			if buildingRank == wantedRank and buildingFlip == wantedFlip then
				return
			end
		elseif currentHandle ~= nil and currentRank == wantedRank and currentFlip == wantedFlip then
			return
		end
		ticket += 1
		local myTicket = ticket
		buildingRank, buildingFlip = wantedRank, wantedFlip
		task.spawn(function()
			local function done()
				if ticket == myTicket then
					buildingRank = nil
				end
			end
			local ut = character:WaitForChild("UpperTorso", 10)
			if ut == nil or not ut:IsA("BasePart") or ticket ~= myTicket or not character:IsDescendantOf(workspace) then
				done()
				return
			end
			local rank = resolveRank(player, character)
			local flipped = character:GetAttribute(EmployeeConstants.LANYARD_FLIP_ATTRIBUTE) == true
			buildingRank, buildingFlip = rank, flipped
			if currentHandle ~= nil and currentRank == rank and currentFlip == flipped then
				done()
				return
			end
			releaseCurrent()
			local empAttr = character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE)
			local empName = if type(empAttr) == "string" then empAttr else nil
			local fit = EmployeeLanyardFormulas.fitForTorso(empName, ut.Size)
			local set = badgeFolder()
			local badgeTemplate = if set ~= nil then set:FindFirstChild(`R{rank}`) else nil
			local handle = EmployeeLanyardSystem.attach(
				character,
				fit,
				rank,
				if badgeTemplate ~= nil and badgeTemplate:IsA("Model") then badgeTemplate else nil,
				flipped
			)
			if handle == nil then
				done()
				return
			end
			if ticket ~= myTicket or not character:IsDescendantOf(workspace) then
				handle.destroy()
				return
			end
			local holderName = if player ~= nil then player.DisplayName else character.Name
			EmployeeLanyardCardSystem.mountInfoCard(character, handle, rank, holderName)
			currentHandle = handle
			currentRank = rank
			currentFlip = flipped
			stopSway = EmployeeLanyardSwaySystem.sway(character, fit, rank, handle)
			done()
		end)
	end

	rebuild()
	local rankAttrConn = character:GetAttributeChangedSignal(EmployeeConstants.RANK_ATTRIBUTE):Connect(rebuild)
	local flipAttrConn = character:GetAttributeChangedSignal(EmployeeConstants.LANYARD_FLIP_ATTRIBUTE):Connect(rebuild)
	local publicUnsub = Charm.subscribe(StateSyncClientStore.publicPlayers, rebuild)

	return function()
		ticket += 1
		stripConn:Disconnect()
		rankAttrConn:Disconnect()
		flipAttrConn:Disconnect()
		publicUnsub()
		releaseCurrent()
	end
end

return EmployeeLanyardSystem
