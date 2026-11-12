--!nonstrict
-- AddSchoolVending.CommandBar.luau: adds ArtKits["school-maple-hill"].furniture.schoolVending, the lobby hub's
-- owner-approved vending machine (Lobby: Workspace.DepotHub.Dressing.CoffeeCorner.vending), rebuilt as a kit template:
-- every part in a frame with its glass front on -Z, upright, the pivot at the floor under the body; its inside light
-- becomes a ScreenLight attachment (templates hold no lights; OfficeConstants.ACCENT_LIGHTS lights it). Run in Studio
-- (Edit), Shift place. Idempotent. Never saves.
local AssetService = game:GetService("AssetService")
local P = {
	{ "vending", "rbxassetid://87520540525046", Vector3.new(3.6, 7.46, 3.26), CFrame.new(0, 3.73, 0), "rbxassetid://73950959597054", "rbxassetid://101997262118335", "rbxassetid://138911549358103", "Plastic", Color3.new(0.639, 0.635, 0.647), 0 },
	{ "Glass", "rbxassetid://88333261175252", Vector3.new(2, 4.7, 0.04), CFrame.new(0.5, 4.46, -1.51), "", "", "", "SmoothPlastic", Color3.new(0.667, 0.804, 0.843), 0.82 },
	{ "Glow", "rbxassetid://72276313046221", Vector3.new(0.51, 2.46, 0.08), CFrame.new(-1.045, 4.91, -1.56), "", "", "", "Neon", Color3.new(1, 0.839, 0.549), 0 },
}
local SNACK = {
	snack_bar = { "rbxassetid://115883930717980", Vector3.new(0.364, 0.72, 0.108), 2.6, -0.68, "rbxassetid://100262445950274", "rbxassetid://138703037299381", "rbxassetid://98278877383864" },
	snack_chips = { "rbxassetid://84514870296740", Vector3.new(0.46, 0.78, 0.39), 3.78, -0.705, "rbxassetid://76220164300441", "rbxassetid://134696409403450", "rbxassetid://114105196004947" },
	snack_bottle = { "rbxassetid://138701778330518", Vector3.new(0.31, 0.9, 0.31), 4.99, -0.68, "rbxassetid://121692672852079", "rbxassetid://92203595821535", "rbxassetid://101705239471195" },
	snack_can = { "rbxassetid://76826477230720", Vector3.new(0.34, 0.64, 0.34), 6.01, -0.68, "rbxassetid://98246391209606", "rbxassetid://97093626673453", "rbxassetid://101999382998920" },
}
local YAW = { snack_bar = { 0.078, -0.014, -0.04, -0.082 }, snack_chips = { -0.036, -0.063, 0.006, -0.039 }, snack_bottle = { -0.095, -0.065, 0.087, -0.015 }, snack_can = { 0.062, 0.003, -0.017, 0.055 } }
for name, s in SNACK do
	for i, x in { 1.25, 0.75, 0.25, -0.25 } do
		table.insert(P, { name, s[1], s[2], CFrame.new(x, s[3], s[4]) * CFrame.Angles(0, math.asin(YAW[name][i]), 0), s[5], s[6], s[7], "Plastic", Color3.new(0.639, 0.635, 0.647), 0 })
	end
end
local furniture = game.ReplicatedStorage.Assets.CleanupCrew.ArtKits["school-maple-hill"].furniture
local old = furniture:FindFirstChild("schoolVending")
if old then
	old:Destroy()
end
local m = Instance.new("Model")
m.Name = "schoolVending"
for _, p in P do
	local mp = AssetService:CreateMeshPartAsync(p[2])
	mp.Name = p[1]
	mp.Size = p[3]
	mp.CFrame = p[4]
	mp.Anchored = true
	mp.Material = Enum.Material[p[8]]
	mp.Color = p[9]
	mp.Transparency = p[10]
	if p[5] ~= "" then
		local sa = Instance.new("SurfaceAppearance")
		sa.ColorMap = p[5]
		sa.NormalMap = p[6]
		sa.RoughnessMap = p[7]
		sa.Parent = mp
	end
	mp.Parent = m
end
local a = Instance.new("Attachment")
a.Name = "ScreenLight"
a.Position = Vector3.new(0, 3.73, -1.2)
a.Parent = m.vending
m.WorldPivot = CFrame.identity
local _, size = m:GetBoundingBox()
m:SetAttribute("BaseSize", size)
m:SetAttribute("RuntimeApproved", true)
m:SetAttribute("FrontAxis", "NegativeZ")
m:SetAttribute("FitMode", "Uniform")
m.Parent = furniture
return "schoolVending " .. tostring(size)
