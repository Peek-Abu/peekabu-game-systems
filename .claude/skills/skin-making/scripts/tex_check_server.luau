-- TEST ONLY (texture round check, 2026-11-16). Lives as Workspace.__TEMP_TEX_CHECK_delete_me.TexCheckServer, never saved.
-- On Play: three builder-made Prickles (no player, no data) wearing the textured PricklesShowstopperV2, playing the
-- live A3 idle, crouch idle and Fist Pump, in the depot near the start (1, 2.4, -224).
local RS, SSS = game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService")
local EmployeeRegistry = require(RS.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeeCharacterSystem = require(SSS.Features.Employee.Systems.EmployeeCharacterSystem)
local EmployeeOutfitSystem = require(RS.Shared.Features.Employee.Systems.EmployeeOutfitSystem)
local outfit = RS.Assets.CleanupCrew.Outfits:FindFirstChild("PricklesShowstopperV2")
local CLIPS = { "rbxassetid://108680458550464", "rbxassetid://126115556970677", "rbxassetid://99795638343617" }
local base = Vector3.new(1, 2.4, -214)
local made = 0
for i, id in CLIPS do
	local model = EmployeeCharacterSystem.build(EmployeeRegistry.get("Prickles"), RS, Instance.new("Folder"))
	if model then
		model.Name = "TexCheck_" .. i
		local pos = base + Vector3.new((i - 2) * 5, 0, 0)
		model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)))
		local hrp = model:FindFirstChild("HumanoidRootPart"); if hrp then hrp.Anchored = true end
		model.Parent = script.Parent
		if outfit then EmployeeOutfitSystem.fit(model, outfit, nil) end
		local hum = model:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if hum and not animator then animator = Instance.new("Animator"); animator.Parent = hum end
		if animator then
			local anim = Instance.new("Animation"); anim.AnimationId = id
			local track = animator:LoadAnimation(anim); track.Priority = Enum.AnimationPriority.Action4; track.Looped = true
			track:Play(0)
		end
		made += 1
	end
end
workspace:SetAttribute("TexCheck", "models " .. made .. ", outfit " .. tostring(outfit ~= nil))
