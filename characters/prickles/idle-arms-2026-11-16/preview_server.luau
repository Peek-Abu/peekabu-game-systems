-- TEST ONLY (Prickles idle drafts, 2026-11-16). Lobby ("Odd Hours") only, as Workspace.__TEMP_IDLE_PREVIEW_delete_me.
-- IdlePreviewServer, never saved, removed after the owner's look. On Play: NOW / A3 side by side in front of the
-- spawn, plain in front and wearing the Showstopper remake test outfit behind.
-- The drafts are the SHIPPED idle (asset 108680458550464, fetched in Studio) with only the six arm rotations replaced
-- (constant against the torso; idle_arms.py draft a5 = fixed A2), registered in memory with KeyframeSequenceProvider:
-- nothing uploaded. Four models from the game's own builder: no player, no data.
local RS, SSS = game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService")
local KSP = game:GetService("KeyframeSequenceProvider")
local EmployeeRegistry = require(RS.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeeCharacterSystem = require(SSS.Features.Employee.Systems.EmployeeCharacterSystem)
local EmployeeOutfitSystem = require(RS.Shared.Features.Employee.Systems.EmployeeOutfitSystem)
local SHIPPED = "rbxassetid://108680458550464"
-- rotation rows (R00..R22) per arm part: A3 (out/draft_a7.rbxmx: crossed, left hand resting on the right arm, elbows out)
local ARMS = {
	A = {
		LeftUpperArm = { 0.130502, -0.385974, -0.913233, 0.287764, 0.896204, -0.337655, 0.948768, -0.218731, 0.228026 },
		LeftLowerArm = { 0.462168, 0.277348, -0.842305, -0.006566, 0.950878, 0.309495, 0.886767, -0.137508, 0.441287 },
		LeftHand = { 0.886233, -0.446643, -0.122889, 0.455885, 0.793827, 0.4025, -0.082221, -0.412732, 0.907134 },
		RightUpperArm = { 0.135669, 0.068774, 0.988365, -0.611127, 0.791007, 0.028847, -0.779819, -0.607929, 0.149344 },
		RightLowerArm = { 0.586659, -0.520394, 0.620501, -0.073708, 0.728716, 0.680838, -0.806473, -0.445156, 0.38915 },
		RightHand = { 0.94163, 0.290295, 0.170478, -0.335257, 0.854628, 0.396502, -0.030592, -0.430512, 0.902066 },
	},
}
local ok, base = pcall(function() return KSP:GetKeyframeSequenceAsync(SHIPPED) end)
local ids = { Now = SHIPPED }
if ok and base then
	for key, arms in ARMS do
		local kfs = base:Clone()
		kfs.Priority = Enum.AnimationPriority.Action4; kfs.Loop = true
		for _, d in kfs:GetDescendants() do
			local r = d:IsA("Pose") and arms[d.Name]
			if r then
				local p = d.CFrame.Position
				d.CFrame = CFrame.new(p.X, p.Y, p.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
			end
		end
		ids[key] = KSP:RegisterKeyframeSequence(kfs)
	end
else
	warn("[IdlePreview] could not fetch the shipped idle: " .. tostring(base))
end
local outfit = RS.Assets.CleanupCrew.Outfits:FindFirstChild("PricklesShowstopperRemake")
local folder = script.Parent
-- players start in the depot near (1, 2.4, -224) facing +Z (the place's SpawnLocation sits unused at the origin)
local spawnAt = Vector3.new(1, 0, -224)
local function label(model, text)
	local head = model:FindFirstChild("Head"); if not head then return end
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(230, 40); bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.AlwaysOnTop = true; bb.Adornee = head
	local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 0.3
	tl.BackgroundColor3 = Color3.fromRGB(30, 24, 30); tl.TextColor3 = Color3.new(1, 1, 1); tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold; tl.Text = text; tl.Parent = bb; bb.Parent = model
end
local order = { "Now", "A" }
local names = { Now = "NOW", A = "A3" }
local made = 0
for row, dressed in { false, true } do
	for i, key in order do
		if ids[key] then
			local model = EmployeeCharacterSystem.build(EmployeeRegistry.get("Prickles"), RS, Instance.new("Folder"))
			if model then
				model.Name = "IdlePreview_" .. key .. (dressed and "_Showstopper" or "")
				local pos = spawnAt + Vector3.new((i - 1.5) * 6, 2.4, 10 + (row - 1) * 7)
				model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)))
				local hrp = model:FindFirstChild("HumanoidRootPart"); if hrp then hrp.Anchored = true end
				model.Parent = folder
				if dressed and outfit then EmployeeOutfitSystem.fit(model, outfit, nil) end
				local hum = model:FindFirstChildOfClass("Humanoid")
				local animator = hum and hum:FindFirstChildOfClass("Animator")
				if hum and not animator then animator = Instance.new("Animator"); animator.Parent = hum end
				if animator then
					local anim = Instance.new("Animation"); anim.AnimationId = ids[key]
					local track = animator:LoadAnimation(anim); track.Priority = Enum.AnimationPriority.Action4; track.Looped = true
					track:Play(0)
				end
				label(model, names[key] .. (dressed and " + Showstopper" or ""))
				made += 1
			end
		end
	end
end
workspace:SetAttribute("IdlePreview", "models " .. made .. ", fixed A2 " .. tostring(ids.A ~= nil))
