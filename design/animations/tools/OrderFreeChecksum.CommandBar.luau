--[[
	The order-free pose checksum clipkit.checksum_free computes for a written .rbxmx: (pose count, sum over every Pose of
	its rounded CFrame components + style*3 + dir*7 + weight*11). Equal numbers = the file is the clip in Studio.
	Set KS, run in Edit.
]]
local KS = game:GetService("ReplicatedStorage"):FindFirstChild("CLIP_FOLDER"):FindFirstChild("CLIP_NAME")
local count, total = 0, 0
for _, p in KS:GetDescendants() do
	if p:IsA("Pose") then
		count += 1
		for _, v in { p.CFrame:GetComponents() } do
			total += math.round(v * 1000) / 1000
		end
		total += p.EasingStyle.Value * 3 + p.EasingDirection.Value * 7 + p.Weight * 11
	end
end
return string.format("%d poses, %.2f", count, total)
