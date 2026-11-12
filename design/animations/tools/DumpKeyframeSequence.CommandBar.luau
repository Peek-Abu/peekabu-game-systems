--[[
	Dumps a KeyframeSequence as JSON for ks_json_to_rbxmx.py (Studio blocks localhost HTTP from the MCP plugin, so the
	clip leaves Studio through execute_luau's return). Set KS below, run in Edit; the return value is the JSON. The
	"checksum" field must equal what ks_json_to_rbxmx.py prints for the written file.
]]
local KS = game:GetService("ReplicatedStorage"):FindFirstChild("CLIP_FOLDER"):FindFirstChild("CLIP_NAME")

local count, total = 0, 0
local function round4(v)
	return math.round(v * 10000) / 10000
end
local function pose(p)
	count += 1
	local i = count
	local c = { p.CFrame:GetComponents() }
	local s = 0
	for _, v in c do
		s += round4(v)
	end
	local style, dir = p.EasingStyle.Value, p.EasingDirection.Value
	s += style * 3 + dir * 7 + p.Weight * 11
	total += s * ((i % 97) + 1)
	local children = {}
	for _, child in p:GetChildren() do
		if child:IsA("Pose") then
			table.insert(children, pose(child))
		end
	end
	return { name = p.Name, cf = c, style = style, dir = dir, weight = p.Weight, children = children }
end

local keyframes = {}
local frames = KS:GetKeyframes()
table.sort(frames, function(a, b)
	return a.Time < b.Time
end)
for _, kf in frames do
	local poses, markers = {}, {}
	for _, child in kf:GetChildren() do
		if child:IsA("Pose") then
			table.insert(poses, pose(child))
		end
	end
	for _, m in kf:GetMarkers() do
		table.insert(markers, m.Name)
	end
	table.insert(keyframes, { time = kf.Time, poses = poses, markers = markers })
end
return game:GetService("HttpService"):JSONEncode({
	name = KS.Name,
	loop = KS.Loop,
	priority = KS.Priority.Value,
	keyframes = keyframes,
	checksum = math.round(total * 10000) / 10000,
	poses = count,
})
