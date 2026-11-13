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

	Instance/EditableMesh/RunService shell (exempt; ribbon geometry, widths and spring specced in
	`EmployeeLanyardFormulas.spec`).

	@class EmployeeLanyardSystem
]=]

local AssetService = game:GetService("AssetService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeeConstants = require(EmployeeShared.Data.EmployeeConstants)
local EmployeeLanyardConstants = require(EmployeeShared.Data.EmployeeLanyardConstants)
local EmployeeLanyardFormulas = require(EmployeeShared.Utils.EmployeeLanyardFormulas)
local EmployeePortraitSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePortraitSystem)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)

type Fit = EmployeeLanyardFormulas.Fit
type CardLayout = EmployeeLanyardConstants.CardLayout

export type Handle = {
	folder: Folder,
	strap: MeshPart?,
	badgeWeld: Weld?,
	badgeRoot: BasePart?,
	badgeTurn: CFrame,
	-- Local z of the plane the info card sits on: in front of the badge's own front-most part (nil without a badge).
	cardZ: number?,
	scale: number,
	destroy: () -> (),
}

local LEGACY_UNIFORM: { [string]: boolean } = {
	PippaVest = true,
	PippaLanyard = true,
}

local preloaded = false

local EmployeeLanyardSystem = {}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function quiet(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
end

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

local function buildStrapMesh(fit: Fit, rank: number, scale: number, ut: BasePart): (MeshPart?, EditableMesh?)
	local g = EmployeeLanyardFormulas.geometry(fit, EmployeeLanyardFormulas.width(fit, rank), scale)
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, p in g.pos do
		for a = 1, 3 do
			lo[a] = math.min(lo[a], p[a])
			hi[a] = math.max(hi[a], p[a])
		end
	end
	local cx, cy, cz = (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2
	local createdEm: EditableMesh? = nil
	local ok, mp = pcall(function(): MeshPart
		local em = AssetService:CreateEditableMesh()
		createdEm = em
		local ids = table.create(#g.pos)
		for i, p in g.pos do
			ids[i] = em:AddVertex(Vector3.new(p[1] - cx, p[2] - cy, p[3] - cz))
		end
		local col = EmployeeLanyardConstants.COLOURS[rank] or EmployeeLanyardConstants.COLOURS[1]
		local cMain = em:AddColor(rgb(col.main), 1)
		local cEdge = em:AddColor(rgb(col.edge or col.main), 1)
		for t, tri in g.tris do
			local f = em:AddTriangle(ids[tri[1]], ids[tri[2]], ids[tri[3]])
			local c = if g.triBand[t] == 1 then cEdge else cMain
			em:SetFaceColors(f, { c, c, c })
		end
		return AssetService:CreateMeshPartAsync(Content.fromObject(em), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
	end)
	if not ok or not mp then
		if createdEm ~= nil then
			pcall(function()
				createdEm:Destroy()
			end)
		end
		return nil, nil
	end
	mp.Name = EmployeeConstants.LANYARD_STRAP
	mp.Material = Enum.Material.SmoothPlastic
	mp.Color = Color3.new(1, 1, 1)
	quiet(mp)
	mp.CFrame = ut.CFrame * CFrame.new(cx, cy, cz)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = ut, mp
	w.Parent = mp
	return mp, createdEm
end

-- Synchronous 3D part-ribbon fallback along the fitted stations: renders in both Workspace and ViewportFrames even
-- when EditableMesh is disabled in Experience Settings -> Security.
local function fallbackRibbonParts(fit: Fit, rank: number, scale: number, ut: BasePart, parent: Instance)
	local rb = fit.ribbon
	local n = #rb.centre
	local col = EmployeeLanyardConstants.COLOURS[rank] or EmployeeLanyardConstants.COLOURS[1]
	local color = rgb(col.main)
	local w = EmployeeLanyardFormulas.width(fit, rank) * scale
	local thickness = math.max(0.012, EmployeeLanyardConstants.STRAP_T * scale * 2)
	for i = 1, n - 1 do
		local p0 = (v3(rb.centre[i]) + v3(rb.offset[i][3])) * scale
		local p1 = (v3(rb.centre[i + 1]) + v3(rb.offset[i + 1][3])) * scale
		local delta = p1 - p0
		local len = delta.Magnitude
		if len > 1e-4 then
			local mid = (p0 + p1) * 0.5
			local nrm = (v3(rb.normal[i]) + v3(rb.normal[i + 1])).Unit
			local tan = delta / len
			local bin = tan:Cross(nrm)
			if bin.Magnitude < 1e-4 then
				bin = v3(rb.binormal[i]).Unit
			else
				bin = bin.Unit
			end
			local trueNrm = bin:Cross(tan).Unit
			local seg = Instance.new("Part")
			seg.Name = EmployeeConstants.LANYARD_STRAP
			seg.Material = Enum.Material.SmoothPlastic
			seg.Color = color
			seg.Size = Vector3.new(w, thickness, len + 0.008 * scale)
			quiet(seg)
			seg.CFrame = ut.CFrame * CFrame.fromMatrix(mid + trueNrm * (thickness * 0.5), bin, trueNrm, -tan)
			local wc = Instance.new("WeldConstraint")
			wc.Part0, wc.Part1 = ut, seg
			wc.Parent = seg
			seg.Parent = parent
		end
	end
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
		strap, em = buildStrapMesh(fit, rank, scale, ut)
	end
	if strap ~= nil then
		strap.Parent = folder
	else
		fallbackRibbonParts(fit, rank, scale, ut, folder)
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

local function oneLine(label: TextLabel, text: string, font: Enum.Font, w: number, h: number, maxSize: number)
	local size = math.floor(math.min(maxSize, h))
	while size > 4 and TextService:GetTextSize(text, size, font, Vector2.new(10000, 10000)).X > w do
		size -= 1
	end
	label.Text = text
	label.Font = font
	label.TextSize = size
	label.TextScaled = false
	label.TextWrapped = false
end

local function px(box: { number }, canvas: { number }): (UDim2, UDim2)
	return UDim2.fromScale(box[1] / canvas[1], box[2] / canvas[2]),
		UDim2.fromScale(box[3] / canvas[1], box[4] / canvas[2])
end

local function mountPortrait(character: Model, parent: Instance, lay: CardLayout)
	local pos, size = px(lay.portrait, lay.canvas)
	local ring = Instance.new("Frame")
	ring.Name = "PortraitRing"
	ring.Position, ring.Size = pos, size
	ring.BackgroundColor3 = Color3.fromHex(lay.ringColour)
	ring.BorderSizePixel = 0
	Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)
	ring.Parent = parent

	local vf = Instance.new("ViewportFrame")
	vf.Name = "Portrait"
	local inset = lay.ring / lay.portrait[3]
	vf.Position = UDim2.fromScale(inset, inset)
	vf.Size = UDim2.fromScale(1 - 2 * inset, 1 - 2 * inset)
	vf.BackgroundColor3 = Color3.fromHex(lay.backdrop)
	vf.BackgroundTransparency = 0
	vf.BorderSizePixel = 0
	vf.Ambient = Color3.fromRGB(190, 190, 190)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-0.4, -0.6, 0.7)
	Instance.new("UICorner", vf).CornerRadius = UDim.new(0.5, 0)
	vf.Parent = ring

	local copy = EmployeePortraitSystem.build(character, nil)
	if copy == nil then
		return
	end
	for _, n in { EmployeeConstants.LANYARD_FOLDER, "VacuumBackpack" } do
		local x = copy:FindFirstChild(n, true)
		if x ~= nil then
			x:Destroy()
		end
	end
	local head = copy:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		copy:Destroy()
		return
	end
	local lo, hi = head.Position - head.Size / 2, head.Position + head.Size / 2
	local reach = head.Size.Magnitude * 1.2
	local neckY = head.Position.Y - head.Size.Y / 2
	for _, p in copy:GetDescendants() do
		if
			p:IsA("BasePart")
			and p ~= head
			and p.Transparency < 1
			and p.Position.Y > neckY
			and (p.Position - head.Position).Magnitude < reach
		then
			lo = lo:Min(p.Position - p.Size / 2)
			hi = hi:Max(p.Position + p.Size / 2)
		end
	end
	local centre = (lo + hi) / 2
	local half = math.max(hi.Y - lo.Y, hi.X - lo.X) / 2
	local cam = Instance.new("Camera")
	cam.FieldOfView = 28
	local dist = half / math.tan(math.rad(14)) * 1.1
	cam.CFrame = CFrame.lookAt(centre + Vector3.new(0, 0, -dist), centre)
	cam.Parent = vf
	vf.CurrentCamera = cam
	copy.Parent = vf
end

local function mountInfoCard(character: Model, handle: Handle, rank: number, holderName: string)
	local badgeRoot = handle.badgeRoot
	local localPlayer = Players.LocalPlayer
	local playerGui = if localPlayer ~= nil then localPlayer:FindFirstChildOfClass("PlayerGui") else nil
	if badgeRoot == nil or playerGui == nil then
		return
	end
	local lay = EmployeeLanyardConstants.INFO_FRONT[rank] or EmployeeLanyardConstants.INFO_FRONT[1]
	local s = handle.scale
	local thickness = 0.001 * s
	local host = Instance.new("Part")
	host.Name = "InfoCardHost"
	host.Size = Vector3.new(lay.size[1] * s, lay.size[2] * s, thickness)
	host.Transparency = 1
	quiet(host)
	-- On the badge's own front-most face (per rank), not at the model origin: the badge body is up to 0.02 studs
	-- deep, so the old fixed depth buried the card and its portrait inside it and they vanished as the camera
	-- came close. The SurfaceGui draws on the host's Front (-Z) face, half a thickness in front of its centre.
	local plane = handle.cardZ or lay.centre[3] * s
	host.CFrame = badgeRoot.CFrame
		* handle.badgeTurn
		* CFrame.new(lay.centre[1] * s, lay.centre[2] * s, plane + thickness / 2)
	local wc = Instance.new("WeldConstraint")
	wc.Part0, wc.Part1 = badgeRoot, host
	wc.Parent = host

	local gui = Instance.new("SurfaceGui")
	gui.Name = "InfoCard"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(lay.canvas[1], lay.canvas[2])
	gui.LightInfluence = 1
	gui.Adornee = host
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	host.Destroying:Connect(function()
		gui:Destroy()
	end)

	mountPortrait(character, gui, lay)

	local npos, nsize = px(lay.name, lay.canvas)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Position, nameLabel.Size = npos, nsize
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromHex("#1E0F3A")
	oneLine(nameLabel, string.upper(holderName), Enum.Font.LuckiestGuy, lay.name[3], lay.name[4], lay.nameMax)
	nameLabel.Parent = gui

	local lpos, lsize = px(lay.line, lay.canvas)
	local pill = Instance.new("TextLabel")
	pill.Name = "RankLine"
	pill.Position, pill.Size = lpos, lsize
	pill.BackgroundColor3 = Color3.fromHex(lay.fill)
	pill.BorderSizePixel = 0
	pill.TextColor3 = Color3.fromHex(lay.ink)
	local rankTitle = EmployeeLanyardConstants.RANK_NAMES[rank] or "NEW KID"
	local line = `RANK {rank} \u{00B7} {rankTitle}`
	oneLine(pill, line, Enum.Font.FredokaOne, lay.line[3] * 0.88, lay.line[4] * 0.8, lay.lineMax)
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0.5, 0)
	pill.Parent = gui
	host.Parent = handle.folder
end

local function sway(character: Model, fit: Fit, rank: number, handle: Handle): () -> ()
	local hum = character:FindFirstChildOfClass("Humanoid")
	local ut = character:FindFirstChild("UpperTorso")
	local weld = handle.badgeWeld
	if hum == nil or ut == nil or not ut:IsA("BasePart") or weld == nil then
		return function() end
	end
	local scale = ut.Size.X / fit.ut_size[1]
	local pv = v3(fit.pivot_rbx) * scale
	local spring = EmployeeLanyardFormulas.newSpring()
	local conn: RBXScriptConnection? = nil
	local lastV = ut.CFrame:VectorToObjectSpace(ut.AssemblyLinearVelocity)
	local still = 0
	local function frame(dt: number)
		local v = ut.CFrame:VectorToObjectSpace(ut.AssemblyLinearVelocity)
		local acc = (v - lastV) / math.max(dt, 1 / 240)
		lastV = v
		local p, r, y, moving =
			EmployeeLanyardFormulas.step(fit, rank, spring, { acc.X, acc.Y, acc.Z }, math.min(dt, 1 / 30))
		weld.C0 = CFrame.new(pv)
			* CFrame.Angles(math.rad(p), 0, 0)
			* CFrame.Angles(0, 0, math.rad(r))
			* CFrame.Angles(0, math.rad(y), 0)
		still = if moving then 0 else still + dt
		if still > 0.4 and conn ~= nil then
			conn:Disconnect()
			conn = nil
		end
	end
	local function wake()
		if conn == nil then
			still = 0
			lastV = ut.CFrame:VectorToObjectSpace(ut.AssemblyLinearVelocity)
			conn = RunService.RenderStepped:Connect(frame)
		end
	end
	local c1 = hum.Running:Connect(wake)
	local c2 = hum.StateChanged:Connect(wake)
	local c3 = hum:GetPropertyChangedSignal("MoveDirection"):Connect(wake)
	return function()
		c1:Disconnect()
		c2:Disconnect()
		c3:Disconnect()
		if conn ~= nil then
			conn:Disconnect()
		end
	end
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

	local function rebuild()
		ticket += 1
		local myTicket = ticket
		task.spawn(function()
			local ut = character:WaitForChild("UpperTorso", 10)
			if ut == nil or not ut:IsA("BasePart") or ticket ~= myTicket or not character:IsDescendantOf(workspace) then
				return
			end
			local rank = resolveRank(player, character)
			local flipped = character:GetAttribute(EmployeeConstants.LANYARD_FLIP_ATTRIBUTE) == true
			if currentHandle ~= nil and currentRank == rank and currentFlip == flipped then
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
				return
			end
			if ticket ~= myTicket or not character:IsDescendantOf(workspace) then
				handle.destroy()
				return
			end
			local holderName = if player ~= nil then player.DisplayName else character.Name
			mountInfoCard(character, handle, rank, holderName)
			currentHandle = handle
			currentRank = rank
			currentFlip = flipped
			stopSway = sway(character, fit, rank, handle)
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
