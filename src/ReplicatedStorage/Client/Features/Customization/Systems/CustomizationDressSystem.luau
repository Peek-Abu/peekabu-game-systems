--!strict
--[=[
	CustomizationDressSystem: the Instance half of dressing a rig (R4 spec, Section 2). Runs on the
	client, for the owner rig and every puppet.

	Executes an CustomizationOutfitDiffUtils op list against a CustomizationRigOutfitTracker; every DECISION was made by the diff. Mounting:
	- pieces come from the CustomizationPiecePool, or are cloned from the art on a miss;
	- each piece is bound with a `RigidConstraint` from its Handle's socket Attachment to the rig's
	  Attachment of the EXACT same name — the only binding that follows a live attachment edit, which
	  is what `customizationtuneoffset` relies on (measured, R4 spike);
	- a piece that cannot bind is never left floating: the mount falls back to the category's default
	  (when it has one), the reason is recorded on the CustomizationRigOutfitTracker, and a per-reason counter goes up;
	- removed pieces go back to the pool, constraints stripped.

	Colours, head-part visibility, surfaces and art lookup go through CustomizationRigLookSystem, which restores the
	authored state for a nil in the diff. A piece's attachment placement is likewise always set from
	its authored cframe, so a pooled piece never stacks one owner's offset on another's.

	Missing art is a recorded skip, never an error; `CustomizationArtCheck` names the gap at boot.

	@class CustomizationDressSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationClient = ReplicatedStorage.Client.Features.Customization
local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)
local CustomizationOutfitDiffUtils = require(CustomizationClient.Utils.CustomizationOutfitDiffUtils)
local CustomizationPiecePool = require(CustomizationClient.State.CustomizationPiecePool)
local CustomizationRigLookSystem = require(CustomizationClient.Systems.CustomizationRigLookSystem)
local CustomizationRigOutfitTracker = require(CustomizationClient.State.CustomizationRigOutfitTracker)

-- The catalog id a mounted piece came from (multi-piece cosmetics name their pieces `Left`/`Right`).
local COSMETIC_ID_ATTRIBUTE = "VentureCosmeticId"
local AUTHORED_OFFSET_ATTRIBUTE = "VentureAuthoredOffset"
-- The rig attribute F4 / Studio checks read: `mountKey:reason` pairs, `;`-joined, current dress only.
local FAILURES_ATTRIBUTE = "CustomizationFailures"

export type MountStatus = "bound" | "noArt" | "noHandle" | "noSocket" | "nameMismatch"

export type Counters = {
	bound: number,
	fallback: number,
	noArt: number,
	noHandle: number,
	noSocket: number,
	nameMismatch: number,
}

-- Typed once: a bare string literal in a multi-value return widens to `string`.
local BOUND: MountStatus = "bound"
local NO_ART: MountStatus = "noArt"
local NO_HANDLE: MountStatus = "noHandle"
local NO_SOCKET: MountStatus = "noSocket"
local NAME_MISMATCH: MountStatus = "nameMismatch"

local counters: Counters = { bound = 0, fallback = 0, noArt = 0, noHandle = 0, noSocket = 0, nameMismatch = 0 }

local function count(status: MountStatus)
	if status == "bound" then
		counters.bound += 1
	elseif status == "noArt" then
		counters.noArt += 1
	elseif status == "noHandle" then
		counters.noHandle += 1
	elseif status == "noSocket" then
		counters.noSocket += 1
	else
		counters.nameMismatch += 1
	end
end

-- The colour channel a cosmetic part paints, from its name: `Color N` or `Color N-<suffix>`.
local function channelOf(name: string): number?
	local digits = name:match("^Color (%d+)$") or name:match("^Color (%d+)%-")
	return if digits ~= nil then tonumber(digits) else nil
end

-- Paints every piece of a cosmetic: each `Color N` part takes channel N (or its authored colour);
-- art with no `Color 1` part takes channel 1 on its Handle.
local function paint(pieces: { Accessory }, colors: { [number]: CustomizationOutfitDiffUtils.Rgb })
	local paintedChannelOne = false
	for _, piece in pieces do
		for _, descendant in piece:GetDescendants() do
			if descendant:IsA("BasePart") then
				local channel = channelOf(descendant.Name)
				if channel ~= nil then
					CustomizationRigLookSystem.setColor(descendant, colors[channel])
					paintedChannelOne = paintedChannelOne or channel == 1
				end
			end
		end
	end
	if not paintedChannelOne then
		for _, piece in pieces do
			local handle = piece:FindFirstChild("Handle")
			if handle ~= nil and handle:IsA("BasePart") then
				CustomizationRigLookSystem.setColor(handle, colors[1])
			end
		end
	end
end

-- The Accessory pieces a cosmetic's art is made of: the art itself, or the Accessories a Model wraps.
local function piecesOf(art: Instance): { Accessory }
	if art:IsA("Accessory") then
		return { art }
	end
	local pieces: { Accessory } = {}
	for _, descendant in art:GetDescendants() do
		if descendant:IsA("Accessory") then
			table.insert(pieces, descendant)
		end
	end
	return pieces
end

type Binding = { handle: BasePart, attachment: Attachment, socket: Attachment }

-- Matches every piece to a rig socket by exact attachment name, and every socket to a piece.
local function plan(
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	pieces: { Accessory },
	sockets: { string }
): ({ Binding }?, MountStatus)
	for _, socket in sockets do
		if CustomizationRigOutfitTracker.socket(outfit, socket) == nil then
			return nil, NO_SOCKET
		end
	end
	if #pieces == 0 then
		return nil, NO_HANDLE
	end
	local bindings: { Binding } = {}
	local covered: { [string]: boolean } = {}
	for _, piece in pieces do
		local handle = piece:FindFirstChild("Handle")
		if handle == nil or not handle:IsA("BasePart") then
			return nil, NO_HANDLE
		end
		local match: Binding? = nil
		for _, socket in sockets do
			local attachment = handle:FindFirstChild(socket)
			local rigSocket = CustomizationRigOutfitTracker.socket(outfit, socket)
			if attachment ~= nil and attachment:IsA("Attachment") and rigSocket ~= nil then
				match = { handle = handle, attachment = attachment, socket = rigSocket }
				covered[socket] = true
				break
			end
		end
		if match == nil then
			return nil, NAME_MISMATCH
		end
		table.insert(bindings, match)
	end
	for _, socket in sockets do
		if not covered[socket] then
			return nil, NAME_MISMATCH
		end
	end
	return bindings, BOUND
end

-- Places a piece's attachment at its authored placement composed with `offset` (socket space). The
-- engine aligns the Handle's attachment to the socket, so moving the cosmetic by `offset` means
-- moving the attachment by its inverse. Always from the AUTHORED cframe, so a pooled piece never
-- stacks one owner's offset on another's.
local function placeAttachment(attachment: Attachment, offset: CFrame?)
	local authored = attachment:GetAttribute(AUTHORED_OFFSET_ATTRIBUTE)
	if typeof(authored) ~= "CFrame" then
		authored = attachment.CFrame
		attachment:SetAttribute(AUTHORED_OFFSET_ATTRIBUTE, authored)
	end
	if typeof(authored) == "CFrame" then
		attachment.CFrame = if offset ~= nil then authored * offset:Inverse() else authored
	end
end

local function bind(
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	pieces: { Accessory },
	bindings: { Binding },
	mount: CustomizationOutfitDiffUtils.Mount,
	id: string
)
	paint(pieces, mount.colors)
	for index, piece in pieces do
		local binding = bindings[index]
		placeAttachment(binding.attachment, mount.offset)
		for _, descendant in piece:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = false
				descendant.Massless = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
		piece:SetAttribute(COSMETIC_ID_ATTRIBUTE, id)
		local constraint = Instance.new("RigidConstraint")
		constraint.Attachment0 = binding.attachment
		constraint.Attachment1 = binding.socket
		constraint.Parent = binding.handle
		piece.Parent = outfit.rig
	end
end

-- True when every piece of a set is still alive and has its Handle.
local function intact(pieces: { Accessory }): boolean
	for _, piece in pieces do
		local handle = piece:FindFirstChild("Handle")
		if piece.Parent == nil or handle == nil or not handle:IsA("BasePart") then
			return false
		end
	end
	return true
end

-- A parked set of `id` that is still whole. A broken one (its parts were destroyed after it was
-- parked) is destroyed on the way, so the pool heals itself instead of handing out a bald set.
local function takeIntact(pool: CustomizationPiecePool.CustomizationPiecePool, id: string): { Accessory }?
	local set = CustomizationPiecePool.take(pool, id)
	while set ~= nil and not intact(set) do
		for _, piece in set do
			piece:Destroy()
		end
		set = CustomizationPiecePool.take(pool, id)
	end
	return set
end

-- Mounts one id: pooled pieces first, cloned art on a miss. Returns the pieces when bound.
local function mountId(
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	mount: CustomizationOutfitDiffUtils.Mount,
	id: string,
	pool: CustomizationPiecePool.CustomizationPiecePool
): ({ Accessory }?, MountStatus)
	local sockets = CustomizationCosmeticRegistry.socketsOf(mount.category, id)
	local pooled = takeIntact(pool, id)
	local pieces: { Accessory }
	local carrier: Instance? = nil
	if pooled ~= nil then
		pieces = pooled
	else
		local folderName = CustomizationCosmeticRegistry.artFolder(mount.category)
		local art = if folderName ~= nil then CustomizationRigLookSystem.findArt(folderName, id) else nil
		if art == nil then
			return nil, NO_ART
		end
		local clone = art:Clone()
		carrier = clone
		pieces = piecesOf(clone)
	end
	local bindings: { Binding }?, status: MountStatus = plan(outfit, pieces, sockets)
	if bindings == nil then
		if carrier ~= nil then
			carrier:Destroy()
		elseif status == NO_SOCKET then
			CustomizationPiecePool.release(pool, id, pieces) -- the set is fine; this rig lacks the socket
		else
			for _, piece in pieces do -- the set itself is broken: never hand it out again
				piece:Destroy()
			end
		end
		return nil, status
	end
	bind(outfit, pieces, bindings, mount, id)
	-- A Model wrapper is only a carrier: its Accessories now live on the rig.
	if carrier ~= nil and not carrier:IsA("Accessory") then
		carrier:Destroy()
	end
	return pieces, BOUND
end

local function addCosmetic(
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	mountKey: string,
	mount: CustomizationOutfitDiffUtils.Mount,
	pool: CustomizationPiecePool.CustomizationPiecePool
)
	local pieces: { Accessory }?, status: MountStatus = mountId(outfit, mount, mount.id, pool)
	count(status)
	if pieces ~= nil then
		outfit.mounted[mountKey] = { id = mount.id, pieces = pieces }
		outfit.failures[mountKey] = nil
		return
	end
	local reason = `{mount.id}:{status}`
	local fallbackId = mount.fallbackId
	if fallbackId ~= nil then
		local fallback: { Accessory }?, fallbackStatus: MountStatus = mountId(outfit, mount, fallbackId, pool)
		if fallback ~= nil then
			counters.fallback += 1
			outfit.mounted[mountKey] = { id = fallbackId, pieces = fallback }
		else
			count(fallbackStatus)
			reason ..= `, fallback {fallbackId}:{fallbackStatus}`
		end
	end
	outfit.failures[mountKey] = reason
end

-- Only an intact set still on the rig is parked; anything else is destroyed instead of poisoning the
-- pool (a destroyed rig locks its pieces' Parent, a fallen one has lost its parts).
local function park(
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	mounted: CustomizationRigOutfitTracker.Mounted,
	pool: CustomizationPiecePool.CustomizationPiecePool
)
	local onRig = true
	for _, piece in mounted.pieces do
		onRig = onRig and piece.Parent == outfit.rig
	end
	if onRig and intact(mounted.pieces) then
		CustomizationPiecePool.release(pool, mounted.id, mounted.pieces)
		return
	end
	for _, piece in mounted.pieces do
		piece:Destroy()
	end
end

local function removeCosmetic(
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	mountKey: string,
	pool: CustomizationPiecePool.CustomizationPiecePool
)
	local mounted = outfit.mounted[mountKey]
	outfit.mounted[mountKey] = nil
	outfit.failures[mountKey] = nil
	if mounted == nil then
		return
	end
	park(outfit, mounted, pool)
end

local function publishFailures(outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker)
	local entries: { string } = {}
	for mountKey, reason in outfit.failures do
		table.insert(entries, `{mountKey}:{reason}`)
	end
	table.sort(entries)
	outfit.rig:SetAttribute(FAILURES_ATTRIBUTE, if #entries > 0 then table.concat(entries, ";") else nil)
end

local CustomizationDressSystem = {}

--[=[
	Applies a diff to a rig. The caller then records the target as worn (CustomizationRigOutfitTracker.setWorn).
	@param outfit CustomizationRigOutfitTracker.CustomizationRigOutfitTracker
	@param ops { CustomizationOutfitDiffUtils.DiffOp }
	@param pool CustomizationPiecePool.CustomizationPiecePool
]=]
function CustomizationDressSystem.apply(
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	ops: { CustomizationOutfitDiffUtils.DiffOp },
	pool: CustomizationPiecePool.CustomizationPiecePool
)
	for _, op in ops do
		if op.kind == "removeCosmetic" then
			removeCosmetic(outfit, op.mountKey, pool)
		elseif op.kind == "addCosmetic" then
			addCosmetic(outfit, op.mountKey, op.mount, pool)
		elseif op.kind == "recolourCosmetic" then
			local mounted = outfit.mounted[op.mountKey]
			if mounted ~= nil then
				paint(mounted.pieces, op.colors)
			end
		elseif op.kind == "setBodyColour" then
			for _, part in CustomizationRigOutfitTracker.partsFor(outfit, op.part) do
				CustomizationRigLookSystem.setColor(part, op.color)
			end
		elseif op.kind == "setSurface" then
			CustomizationRigLookSystem.setSurface(outfit, op.surface)
		elseif op.kind == "setHeadPart" then
			local head = outfit.rig:FindFirstChild("Head")
			local target = if head ~= nil then head:FindFirstChild(op.part) else nil
			if target ~= nil then
				CustomizationRigLookSystem.setVisibility(target, op.visible)
			end
		end
	end
	publishFailures(outfit)
end

--[=[
	Takes every mounted cosmetic off a rig before the rig itself is destroyed. `salvage` parks them, so
	the next rig re-takes the same pieces instead of cloning (a rebuilt owner rig); without it they are
	destroyed — a rig that FELL out of the world has its parts already queued for destruction by the
	engine, and parking them would only park pieces that vanish a step later (measured in Studio).
	@param outfit CustomizationRigOutfitTracker.CustomizationRigOutfitTracker
	@param pool CustomizationPiecePool.CustomizationPiecePool
	@param salvage boolean
]=]
function CustomizationDressSystem.strip(
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	pool: CustomizationPiecePool.CustomizationPiecePool,
	salvage: boolean
)
	for mountKey, mounted in outfit.mounted do
		outfit.mounted[mountKey] = nil
		if salvage then
			park(outfit, mounted, pool)
		else
			for _, piece in mounted.pieces do
				piece:Destroy()
			end
		end
	end
	table.clear(outfit.failures)
	CustomizationRigOutfitTracker.setWorn(
		outfit,
		CustomizationOutfitDiffUtils.empty(),
		CustomizationRigOutfitTracker.UNDRESSED
	)
end

--[=[
	Moves an already-mounted cosmetic's fit, live, for `customizationtuneoffset`. The RigidConstraint follows the
	attachment edit at once. A measuring instrument: the number a human settles on is typed into the
	registry, which stays the source of truth; the next dress puts the registry's offset back.
	@param rig Model -- the owner rig
	@param id string -- the mounted cosmetic id
	@param offset CFrame -- total offset from the authored placement, in socket space
	@return number -- how many pieces moved
]=]
function CustomizationDressSystem.nudgeOffset(rig: Model, id: string, offset: CFrame): number
	local moved = 0
	for _, child in rig:GetChildren() do
		if not child:IsA("Accessory") or child:GetAttribute(COSMETIC_ID_ATTRIBUTE) ~= id then
			continue
		end
		local handle = child:FindFirstChild("Handle")
		local constraint = if handle ~= nil then handle:FindFirstChildOfClass("RigidConstraint") else nil
		local attachment = if constraint ~= nil then constraint.Attachment0 else nil
		if attachment ~= nil then
			placeAttachment(attachment, offset)
			moved += 1
		end
	end
	return moved
end

--[=[
	Per-reason mount counters since boot, for F4.
	@return Counters
]=]
function CustomizationDressSystem.counters(): Counters
	return table.clone(counters)
end

return CustomizationDressSystem
