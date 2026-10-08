--!strict
--[=[
	CustomizationArtCheck: does the ART match the CATALOG, and does the RIG match the sockets?

	Everything the customization stack does at apply time depends on facts nobody verifies: that a
	catalog id resolves to a model, that the model is an Accessory with a Handle, that the Handle
	carries an Attachment named for its socket, and that the rig actually has that socket. When one of
	those is false the failure is SILENT — the command reports success, the slice validates, the state
	panel updates, and nothing appears. That cost a full debugging round in 5b (a missing art folder),
	and a rig part renamed out from under the registry produces exactly the same symptom.

	This module answers all of it up front, so a broken art sync is a list at boot instead of a
	debugging session later.

	**It REPORTS; it never asserts and never throws.** This is a deliberate split from
	`CustomizationCosmeticRegistry`, which fails LOUD at load: the registry validates data THIS REPO owns, where a
	contradiction is a programming error. Art is place-owned and edited by people outside this repo, so
	a missing hat must not stop a server booting — a player briefly missing a hat is strictly better
	than nobody being able to play. Same reasoning as the tolerant plan-builder.

	Both trees are INJECTED rather than reached for, which is what makes an Instance-inspecting module
	unit-testable: the specs run it against a fabricated art folder and a fabricated rig.

	@class CustomizationArtCheck
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)

--[=[
	One thing that is wrong, in terms an artist can act on.
	@interface Issue
	.category string -- the catalog category, or "rig" for a socket problem
	.id string -- the cosmetic id, or the socket name for a rig problem
	.problem string -- a human-readable description
]=]
export type Issue = {
	category: string,
	id: string,
	problem: string,
}

--[=[
	A report rolled up for logging.
	@interface Summary
	.ok boolean
	.total number
	.lines { string }
]=]
export type Summary = {
	ok: boolean,
	total: number,
	lines: { string },
}

local CustomizationArtCheck = {}

-- True when `rig` carries an Attachment named `socket` ANYWHERE in it.
--
-- Depth-agnostic on purpose: the live rig puts sockets at depth 1 (`Head`), 2 (`Hair` on
-- `Head.Color 1`) and 3 (`Eyes` on `Head.Eyes 1.Eye Color`), and the mounting code finds them by name
-- at any depth. The checker has to agree with the mounting code, or it would report false failures.
local function rigHasSocket(rig: Instance, socket: string): boolean
	for _, descendant in rig:GetDescendants() do
		if
			descendant:IsA("Attachment")
			and descendant.Name == socket
			-- Attachments inside a mounted Accessory are EXCLUDED, exactly as the mounting code excludes
			-- them: a cosmetic's own Handle attachment carries its socket's name by design. Counting one
			-- would let the report claim a socket exists that mounting then refuses to find — a false
			-- pass, which is worse than no check at all for something whose whole job is to be trusted.
			and descendant:FindFirstAncestorOfClass("Accessory") == nil
		then
			return true
		end
	end
	return false
end

-- Checks one catalogued cosmetic's art, appending anything wrong. Cardinality: the ART-LEVEL checks
-- (missing folder/model, no Accessory) report at most once and stop, and each PIECE reports at most
-- one fault before further checks on it are skipped — but a multi-piece cosmetic can legitimately
-- produce several lines (one per broken piece, plus uncovered sockets once every piece is sound).
-- One line per ROOT CAUSE is the rule, not one per id.
local function checkArt(issues: { Issue }, folder: Instance?, category: string, id: string, sockets: { string })
	local function report(problem: string)
		table.insert(issues, { category = category, id = id, problem = problem })
	end

	if not folder then
		report(`art folder "{CustomizationCosmeticRegistry.artFolder(category) or "?"}" is missing`)
		return
	end
	local art = folder:FindFirstChild(id)
	if not art then
		report(`no art named "{id}" in "{folder.Name}"`)
		return
	end

	-- One Accessory, or a Model wrapping several of them — a multi-socket cosmetic such as shoes is a
	-- Model holding a Left and a Right, each with its own Handle and socket.
	local pieces: { Instance } = {}
	if art:IsA("Accessory") then
		table.insert(pieces, art)
	else
		for _, descendant in art:GetDescendants() do
			if descendant:IsA("Accessory") then
				table.insert(pieces, descendant)
			end
		end
	end
	if #pieces == 0 then
		report(`art is a {art.ClassName} containing no Accessory`)
		return
	end

	-- Every declared socket must be covered by SOME piece. Checking it this way (rather than piece by
	-- piece) is what catches half a pair of shoes: the art exists, one piece is fine, and the cosmetic
	-- would still mount wrong.
	-- Each piece is judged ONCE, and a fault stops further checks on it. The checks are sequential
	-- preconditions: a piece with no Handle cannot carry an attachment, and a piece carrying none of
	-- the sockets is already the whole story — reporting a follow-on "socket X uncovered" for the same
	-- piece would describe one fault twice and inflate a report whose value is being read.
	local covered: { [string]: boolean } = {}
	local faulted = false
	for _, piece in pieces do
		local handle = piece:FindFirstChild("Handle")
		if not handle or not handle:IsA("BasePart") then
			report(`piece "{piece.Name}" has no Handle part`)
			faulted = true
			continue
		end

		local carriesASocket = false
		for _, socket in sockets do
			local attachment = handle:FindFirstChild(socket)
			if attachment and attachment:IsA("Attachment") then
				covered[socket] = true
				carriesASocket = true
			end
		end
		if not carriesASocket then
			-- Mounting is all-or-nothing, so ONE piece targeting no declared socket sinks the whole
			-- cosmetic — a fact aggregate coverage cannot express.
			report(`piece "{piece.Name}" carries none of this cosmetic's sockets, so nothing would mount`)
			faulted = true
			continue
		end

		-- REACHABILITY from the Handle, not merely "appears in some joint". Two parts welded to each
		-- other but not to the Handle form an island that still gets left behind at mount, and a
		-- per-joint check would call that fine. Joints are undirected: a part welded as Part0 to
		-- something already reachable is just as attached as one welded as Part1.
		local neighbours: { [Instance]: { Instance } } = {}
		local function link(a: Instance?, b: Instance?)
			if not a or not b then
				return
			end
			neighbours[a] = neighbours[a] or {}
			neighbours[b] = neighbours[b] or {}
			table.insert(neighbours[a], b)
			table.insert(neighbours[b], a)
		end
		for _, d in piece:GetDescendants() do
			if d:IsA("Weld") or d:IsA("Motor6D") or d:IsA("WeldConstraint") then
				link(d.Part0, d.Part1)
			end
		end

		local reachable: { [Instance]: boolean } = { [handle] = true }
		local queue: { Instance } = { handle }
		while #queue > 0 do
			local current = queue[#queue]
			queue[#queue] = nil
			local adjacent = neighbours[current]
			if adjacent then
				for _, neighbour in adjacent do
					if not reachable[neighbour] then
						reachable[neighbour] = true
						table.insert(queue, neighbour)
					end
				end
			end
		end

		local stranded = 0
		for _, d in piece:GetDescendants() do
			if d:IsA("BasePart") and not reachable[d] then
				stranded += 1
			end
		end
		if stranded > 0 then
			report(
				`piece "{piece.Name}" has {stranded} part(s) not connected to its Handle — they will not follow it`
			)
		end
	end

	-- Coverage is only meaningful once every piece is individually sound: it catches art where each
	-- piece mounts fine yet a declared socket goes unfilled — two shoe pieces both on `ShoeLeft`.
	if faulted then
		return
	end
	for _, socket in sockets do
		if not covered[socket] then
			report(`no piece carries an Attachment named "{socket}" (a socket it mounts to)`)
		end
	end
end

--[=[
	Checks the whole catalog against an art tree and a rig, returning everything that is wrong.

	An empty result means every catalogued cosmetic resolves to art that can actually be mounted. Never
	throws — a malformed or absent tree is the case this exists to describe.

	@param customs Instance? -- the art root (`ReplicatedStorage.Assets.Customization`), or nil if missing
	@param rig Instance? -- a character/rig model to verify sockets against, or nil to skip rig checks
	@return { Issue }
]=]
function CustomizationArtCheck.check(customs: Instance?, rig: Instance?): { Issue }
	local issues: { Issue } = {}

	for _, category in CustomizationCosmeticRegistry.categories() do
		local folderName = CustomizationCosmeticRegistry.artFolder(category)
		local folder = if customs and folderName then customs:FindFirstChild(folderName) else nil
		for _, id in CustomizationCosmeticRegistry.ids(category) do
			checkArt(issues, folder, category, id, CustomizationCosmeticRegistry.socketsOf(category, id))
		end
	end

	-- Rig sockets are checked ONCE per distinct socket, not once per cosmetic: a missing `Hair` socket
	-- is one problem with one fix, and repeating it per hairstyle would bury the rest of the report.
	if rig then
		local checked: { [string]: boolean } = {}
		for _, category in CustomizationCosmeticRegistry.categories() do
			for _, id in CustomizationCosmeticRegistry.ids(category) do
				for _, socket in CustomizationCosmeticRegistry.socketsOf(category, id) do
					if not checked[socket] then
						checked[socket] = true
						if not rigHasSocket(rig, socket) then
							table.insert(issues, {
								category = "rig",
								id = socket,
								problem = `the rig has no Attachment named "{socket}"`,
							})
						end
					end
				end
			end
		end
	else
		table.insert(issues, { category = "rig", id = "-", problem = "no rig supplied, so sockets were not checked" })
	end

	return issues
end

--[=[
	Rolls a report up for logging: an ok flag, a count, and one formatted line per issue.
	@param issues { Issue }
	@return Summary
]=]
function CustomizationArtCheck.summarize(issues: { Issue }): Summary
	local lines: { string } = {}
	for _, issue in issues do
		table.insert(lines, `[{issue.category}] {issue.id}: {issue.problem}`)
	end
	return {
		ok = #issues == 0,
		total = #issues,
		lines = lines,
	}
end

return CustomizationArtCheck
