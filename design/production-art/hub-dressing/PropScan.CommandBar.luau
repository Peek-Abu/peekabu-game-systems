--[[
	PropScan: the hub prop placement gate (design/production-art/hub-dressing/GATES.md G4/G5). Run in the lobby place
	(Edit, or Play on the server) through the Studio MCP execute_luau or the command bar. It changes nothing and
	returns a report.

	A prop is every Model under DepotHub.Dressing, Spots, Training and Yard, at any folder depth (a Model is never
	opened up: its parts belong to it). Bare parts (walls, floor, fence rails, the apron) are the place, not props;
	they still count as what a prop can sink into.
	Each prop is measured part by part: the world box of each visible part, its corners projected exactly. A tree's
	canopy is open air for anything under it, so a tree counts only as its trunk (a 1.6-stud post under its pivot, 40%
	of its height). Plants (bushes, tufts, leaves, trees) growing into each other is not clipping.
	- BURIED: a raycast comes down at the prop's centre, past the prop itself and anything resting on it, to what is
	  under it. The prop counts as
	  buried when more than 25% of its height sits below that surface. A flat prop (under 0.6 tall: leaf cards,
	  puddles, mats) counts as buried when more than 0.15 studs of it sits below.
	- CLIPPING: two props whose parts' boxes share more than 15% of the smaller prop's part volume (a pumpkin in a
	  table, a crate inside a crate). A prop resting ON another passes: its burial ray landed on that prop's surface.
	- BLOCKING: a prop takes up the space in front of a tagged interactable's prompt face (its thinner horizontal side,
	  the one facing the room),
	  as wide as the interactable and 3 studs deep, at walking height. Flat props (under 0.15 tall) are walkable and
	  never block.
	Every hit names the prop, its group and centre, and the other side.
]]

local CollectionService = game:GetService("CollectionService")

local hub = workspace:FindFirstChild("DepotHub")
assert(hub, "no DepotHub")

local BURIED_SHARE = 0.25
local FLAT = 0.6
local FLAT_SINK = 0.15
local WALKABLE = 0.15
local CLIP_SHARE = 0.15
local CLEAR = 3
local TRUNK = 1.6
-- Plants grow into each other on purpose: a tuft at a bush's foot, leaves round a trunk.
local PLANTS = { Bush = true, GrassTuft = true, LeafScatter = true, LeafDrift = true, AutumnTree = true }

local props = {}
local function collect(folder, path)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(props, { inst = child, group = path })
		elseif child:IsA("Folder") then
			collect(child, path .. "/" .. child.Name)
		end
	end
end
for _, groupName in { "Dressing", "Spots", "Training", "Yard" } do
	local folder = hub:FindFirstChild(groupName)
	if folder then
		collect(folder, groupName)
	end
end

local function partBox(p)
	local half = p.Size / 2
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local c = (p.CFrame * CFrame.new(half.X * x, half.Y * y, half.Z * z)).Position
				low = low:Min(c)
				high = high:Max(c)
			end
		end
	end
	return { low = low, high = high }
end

local function volume(low, high)
	local d = high - low
	return math.max(d.X, 0) * math.max(d.Y, 0) * math.max(d.Z, 0)
end

for _, prop in props do
	local boxes = {}
	for _, p in prop.inst:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 0.95 then
			table.insert(boxes, partBox(p))
		end
	end
	if prop.inst.Name == "AutumnTree" and #boxes > 0 then
		-- One mesh: its trunk is a TRUNK-wide post under the pivot, up to 40% of its height.
		local low, high = boxes[1].low, boxes[1].high
		for _, b in boxes do
			low = low:Min(b.low)
			high = high:Max(b.high)
		end
		local at = prop.inst:GetPivot().Position
		local top = low.Y + (high.Y - low.Y) * 0.4
		boxes = {
			{
				low = Vector3.new(at.X - TRUNK / 2, low.Y, at.Z - TRUNK / 2),
				high = Vector3.new(at.X + TRUNK / 2, top, at.Z + TRUNK / 2),
			},
		}
	end
	prop.boxes = boxes
	if #boxes > 0 then
		local low, high = boxes[1].low, boxes[1].high
		local total = 0
		for _, b in boxes do
			low = low:Min(b.low)
			high = high:Max(b.high)
			total += volume(b.low, b.high)
		end
		prop.low, prop.high, prop.volume = low, high, total
	end
end

local report = { buried = {}, clipping = {}, blocking = {} }
local function name(prop)
	local at = (prop.low + prop.high) / 2
	return string.format("%s/%s @(%.1f,%.1f,%.1f)", prop.group, prop.inst.Name, at.X, at.Y, at.Z)
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
for _, prop in props do
	if prop.low then
		-- Anything resting on the prop (its bottom above the prop's middle, like a shelf over lockers) is passed.
		local ignore = { prop.inst }
		params.FilterDescendantsInstances = ignore
		local centre = (prop.low + prop.high) / 2
		local hit
		for _ = 1, 6 do
			hit = workspace:Raycast(Vector3.new(centre.X, prop.high.Y + 0.05, centre.Z), Vector3.new(0, -60, 0), params)
			local over = hit and hit.Instance:IsA("BasePart") and partBox(hit.Instance).low.Y > centre.Y
			if not over then
				break
			end
			table.insert(ignore, hit.Instance)
			params.FilterDescendantsInstances = ignore
		end
		if hit then
			local height = prop.high.Y - prop.low.Y
			local sunk = hit.Position.Y - prop.low.Y
			local bad = if height < FLAT then sunk > FLAT_SINK else sunk / height > BURIED_SHARE
			if not bad then
				-- What it stands on: a prop resting on a big mesh (mugs on the coffee bar) is inside that mesh's box
				-- but not inside the mesh.
				prop.restsOn = hit.Instance:FindFirstAncestorWhichIsA("Model")
			end
			if bad then
				table.insert(
					report.buried,
					string.format("%s sunk %.2f of %.2f into %s", name(prop), sunk, height, hit.Instance:GetFullName())
				)
			end
		end
	end
end

local function overlaps(aLow, aHigh, bLow, bHigh)
	return volume(aLow:Max(bLow), aHigh:Min(bHigh)) > 0
end

for i = 1, #props do
	local a = props[i]
	if a.low then
		for j = i + 1, #props do
			local b = props[j]
			local plants = PLANTS[a.inst.Name] and PLANTS[b.inst.Name]
			local resting = a.restsOn == b.inst or b.restsOn == a.inst
			if b.low and not plants and not resting and overlaps(a.low, a.high, b.low, b.high) then
				local shared = 0
				for _, pa in a.boxes do
					for _, pb in b.boxes do
						shared += volume(pa.low:Max(pb.low), pa.high:Min(pb.high))
					end
				end
				local small = math.min(a.volume, b.volume)
				if small > 0 and shared / small > CLIP_SHARE then
					table.insert(report.clipping, string.format("%s x %s (%.0f%%)", name(a), name(b), 100 * shared / small))
				end
			end
		end
	end
end

local centre = hub.Shell.Floor.JointBed.Position
for _, tagged in CollectionService:GetTagged("Interactable") do
	local part = if tagged:IsA("BasePart") then tagged elseif tagged:IsA("Model") then tagged.PrimaryPart else nil
	if part and part:IsDescendantOf(hub) then
		-- The prompt face is the part's thinner horizontal side (a sign or door is thin through its face), turned to
		-- the room.
		local thinZ = part.Size.Z <= part.Size.X
		local axis = if thinZ then part.CFrame.LookVector else part.CFrame.RightVector
		local depth = if thinZ then part.Size.Z else part.Size.X
		local width = if thinZ then part.Size.X else part.Size.Z
		local facing = if axis:Dot(centre - part.Position) >= 0 then axis else -axis
		local across = Vector3.yAxis:Cross(facing).Unit
		local halfWidth = math.min(width / 2, CLEAR / 2)
		local front = part.Position + facing * (depth / 2 + CLEAR / 2)
		local floorY = part.Position.Y - part.Size.Y / 2
		local zone = {}
		for _, s in { -1, 1 } do
			for _, d in { -1, 1 } do
				table.insert(zone, front + across * halfWidth * s + facing * (CLEAR / 2) * d)
			end
		end
		local zLow, zHigh = zone[1], zone[1]
		for _, c in zone do
			zLow = zLow:Min(c)
			zHigh = zHigh:Max(c)
		end
		zLow = Vector3.new(zLow.X, floorY + 0.5, zLow.Z)
		zHigh = Vector3.new(zHigh.X, floorY + 4.5, zHigh.Z)
		for _, prop in props do
			if
				prop.low
				and prop.high.Y - prop.low.Y >= WALKABLE
				and prop.inst ~= tagged
				and not tagged:IsDescendantOf(prop.inst)
				and not prop.inst:IsDescendantOf(tagged)
			then
				local taken = 0
				for _, b in prop.boxes do
					taken += volume(b.low:Max(zLow), b.high:Min(zHigh))
				end
				if taken > 0.3 then
					table.insert(
						report.blocking,
						string.format("%s blocks %s (%.1f cubic studs)", name(prop), tagged:GetFullName(), taken)
					)
				end
			end
		end
	end
end

local lines = { string.format("props scanned: %d", #props) }
for _, key in { "buried", "clipping", "blocking" } do
	table.insert(lines, string.format("%s: %d", key, #report[key]))
	for _, line in report[key] do
		table.insert(lines, "  " .. line)
	end
end
return table.concat(lines, "\n")
