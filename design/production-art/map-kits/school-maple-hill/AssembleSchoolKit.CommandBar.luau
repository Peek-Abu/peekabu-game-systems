--!nonstrict
-- AssembleSchoolKit.CommandBar.luau: builds ReplicatedStorage.Assets.CleanupCrew.ArtKits["school-maple-hill"] (the School's
-- own furniture; ArtKitRegistry falls back to odd-hours-b1, then the slate kit, for everything else) and the School_*
-- MaterialVariants the shell theme names (OfficeShellConstants). Run in Studio (Edit) through the Studio MCP / command bar.
-- Idempotent: rebuilds the kit folder and overwrites the variants. Art never goes in Rojo. Never saves (the owner saves).
-- Every id is an Icey Labs (group 189923277) asset, owner-approved 2026-11-12; image ids are DECAL ids resolved at run time
-- through InsertService:LoadAsset. Source: texwork/school_ship/ids.json (upload_log.jsonl + upload_log_v3.jsonl).
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MaterialService = game:GetService("MaterialService")
local KIT_ID = "school-maple-hill"
-- key = { model, color, normal, rough }
local IDS = {
	artSink = { "92377115426302", "71548034458538", "112360756729633", "109378983124466" },
	basketballHoop = { "132753102650305", "104540735003242", "139015020976441", "79482470822547" },
	bench = { "110527477122715", "132980365582473", "140623343759048", "73874059851350" },
	bleachers = { "83807466247634", "119287572998067", "87708234351268", "111246815751816" },
	bookReturn = { "118800654817508", "80984070133928", "113276437619271", "112413676579499" },
	chalkboard = { "126771303183093", "82311482781231", "92672632394721", "121118827853479" },
	cot = { "75358118576702", "115443594564750", "80466460643592", "78531034032009" },
	cubbies = { "94911060158984", "130192080513109", "128970026346302", "89516349017151" },
	easel = { "113037302898610", "112054654531969", "72470174822821", "112186034328506" },
	equipmentCloset = { "130040984151130", "116229372267135", "128927530440181", "108310188544952" },
	libraryDesk = { "88064650036144", "126541982315983", "80732761194440", "91590843041195" },
	lunchBench = { "132141609620876", "112079837401102", "122989189130706", "96590032927343" },
	lunchTable = { "120673708414047", "94278566178933", "117854788332815", "125788737962431" },
	medicineCabinet = { "81953223049571", "135210488509586", "70569337346322", "88286479369058" },
	piano = { "79079282639968", "110788611892758", "136417985559184", "84179611361249" },
	projectTable = { "84453074690444", "137096734240417", "114808774214249", "88381008356097" },
	readingTable = { "90076246536101", "133436237346942", "112614082306234", "112938109801157" },
	scoreboard = { "109382414191785", "105148156171455", "135082424230787", "84005602621462" },
	scorersTable = { "91118263228686", "104684597371496", "91143961158787", "130410554675160" },
	servingCounter = { "129313388371831", "70689852173623", "110681030434844", "91808891505331" },
	sinkCounter = { "72249102446557", "91985961950696", "103902276353207", "85495853315973" },
	stall = { "83518765013947", "115927014380737", "94837348469968", "105986687680161" },
	studentDesk = { "103249679198885", "86566825344814", "124406917856345", "76249844696381" },
	studyTable = { "132616843181836", "73055013047928", "105754109971679", "115776206609484" },
	trophyCase = { "91128894592470", "122440482829949", "79438246003842", "132770126206653" },
}
-- The worktop a counter or table holds loot on (template-local studs; measured by a ray grid over each mesh).
local SUPPORT = {artSink = 3.6, cubbies = 5.58, libraryDesk = 2.9, lunchBench = 2.9, piano = 5.75, scorersTable = 3.36, servingCounter = 3.75, sinkCounter = 3.6, studentDesk = 3.25, studyTable = 3.0}
-- See-through panes (template-local centre / size, the mesh's 180-degree import yaw applied); Material Glass.
local GLASS = {
	trophyCase = {
		{ "Glass_DoorL", Vector3.new(1.1500, 4.3000, -0.9150), Vector3.new(2.5, 5.26, 0.05) },
		{ "Glass_DoorR", Vector3.new(-1.1500, 4.3000, -0.8350), Vector3.new(2.5, 5.26, 0.05) },
		{ "Glass_SideL", Vector3.new(2.4550, 4.3000, 0.0200), Vector3.new(0.05, 5.34, 1.8) },
		{ "Glass_SideR", Vector3.new(-2.4550, 4.3000, 0.0200), Vector3.new(0.05, 5.34, 1.8) },
	},
	medicineCabinet = {
		{ "Glass_Door", Vector3.new(-0.0116, 3.0600, -0.8000), Vector3.new(1.46, 1.64, 0.03) },
	},
}
-- MaterialVariant name = { color, normal, rough decal ids, base material }
local VARIANTS = {
	School_HallVct = { "105027911085386", "90185494869322", "74392630831087", Enum.Material.Plastic },
	School_HallBlock = { "94956532988459", "88738507025075", "114261271393019", Enum.Material.Concrete },
	School_HallBand = { "139856143496071", "138567459072301", "80095738548203", Enum.Material.Concrete },
	School_RoomPaint = { "98946293733850", "115767254830446", "132748516791716", Enum.Material.Plaster },
	School_RoomBand = { "89470415278703", "132745718218311", "95793926935770", Enum.Material.Plaster },
	School_Carpet = { "126918756324939", "127689546146259", "91660721848133", Enum.Material.Fabric },
	School_Maple = { "80392225053603", "137128068172348", "87936483685245", Enum.Material.Wood },
	School_Checker = { "107338562133992", "104253320086063", "134552705429076", Enum.Material.Plastic },
	School_Tile = { "111894677447320", "124215425819701", "137005274580920", Enum.Material.Plastic },
}

-- ---------------------------------------------------------------- loading (8 workers)
local meshCache, imageCache = {}, {}
local jobs = {}
for key, row in IDS do
	table.insert(jobs, { "mesh", key, row[1] })
	for i = 2, 4 do
		table.insert(jobs, { "image", key .. "#" .. i, row[i] })
	end
end
for name, row in VARIANTS do
	for i = 1, 3 do
		table.insert(jobs, { "image", name .. "#" .. i, row[i] })
	end
end
local nextJob, active, failures = 1, 0, {}
local function work()
	active += 1
	while nextJob <= #jobs do
		local job = jobs[nextJob]
		nextJob += 1
		local ok, m = pcall(InsertService.LoadAsset, InsertService, tonumber(job[3]))
		if ok then
			if job[1] == "mesh" then
				local main
				for _, d in m:GetDescendants() do
					if d:IsA("MeshPart") and (not main or d.Size.Magnitude > main.Size.Magnitude) then
						main = d
					end
				end
				if main then
					main.Parent = nil
					meshCache[job[2]] = main
				end
			else
				local d = m:FindFirstChildWhichIsA("Decal", true)
				if d then
					imageCache[job[2]] = d.Texture
				end
			end
			m:Destroy()
		else
			table.insert(failures, job[2] .. " " .. job[3] .. ": " .. tostring(m))
		end
	end
	active -= 1
end
for _ = 1, 8 do
	task.spawn(work)
end
repeat
	task.wait(0.1)
until active == 0 and nextJob > #jobs

-- ---------------------------------------------------------------- variants
local variantReport = {}
for name, row in VARIANTS do
	local v = MaterialService:FindFirstChild(name)
	if not v then
		v = Instance.new("MaterialVariant")
		v.Name = name
	end
	v.BaseMaterial = row[4]
	v.StudsPerTile = 8
	v.ColorMap = imageCache[name .. "#1"] or ""
	v.NormalMap = imageCache[name .. "#2"] or ""
	v.RoughnessMap = imageCache[name .. "#3"] or ""
	v.Parent = MaterialService
	table.insert(variantReport, name .. (if v.ColorMap ~= "" then " ok" else " NO COLOR"))
end

-- ---------------------------------------------------------------- templates
local assets = ReplicatedStorage:FindFirstChild("Assets")
local cleanup = assets and assets:FindFirstChild("CleanupCrew")
local kits = cleanup and cleanup:FindFirstChild("ArtKits")
assert(kits, "ReplicatedStorage.Assets.CleanupCrew.ArtKits is missing")
local old = kits:FindFirstChild(KIT_ID)
if old then
	old:Destroy()
end
local kit = Instance.new("Folder")
kit.Name = KIT_ID
local furniture = Instance.new("Folder")
furniture.Name = "furniture"
furniture.Parent = kit

local report = {}
for key, row in IDS do
	local src = meshCache[key]
	if not src then
		table.insert(report, key .. " FAILED: model " .. row[1] .. " did not load")
		continue
	end
	local m = Instance.new("Model")
	m.Name = key
	local mp = src:Clone()
	for _, c in mp:GetChildren() do
		c:Destroy()
	end
	mp.Name = key
	mp.Anchored = true
	-- Uploaded meshes are bbox-centred: sit the box on the pivot's floor. The FBX 180-degree yaw already faces it -Z.
	mp.CFrame = CFrame.new(0, mp.Size.Y / 2, 0)
	local sa = Instance.new("SurfaceAppearance")
	sa.ColorMap = imageCache[key .. "#2"] or ""
	sa.NormalMap = imageCache[key .. "#3"] or ""
	sa.RoughnessMap = imageCache[key .. "#4"] or ""
	sa.Parent = mp
	mp.Parent = m
	for _, pane in GLASS[key] or {} do
		local g = Instance.new("Part")
		g.Name = pane[1]
		g.Anchored = true
		g.CanCollide = false
		g.CanQuery = false
		g.CastShadow = false
		g.Material = Enum.Material.Glass
		g.Transparency = 0.6
		g.Color = Color3.fromRGB(170, 205, 215)
		g.Size = pane[3]
		g.CFrame = CFrame.new(pane[2])
		g.Parent = m
	end
	m.WorldPivot = CFrame.identity
	m:SetAttribute("BaseSize", mp.Size)
	m:SetAttribute("RuntimeApproved", true)
	m:SetAttribute("FrontAxis", "NegativeZ")
	m:SetAttribute("FitMode", "Uniform")
	if SUPPORT[key] then
		m:SetAttribute("SupportSurfaceY", SUPPORT[key])
	end
	m.Parent = furniture
	table.insert(report, key)
end
-- The hall locker (the slate kit's single searchable locker, which the Office keeps): recoloured to the approved
-- look sheet's teal-green. Every part keeps its name (SearchDoor swings), only the colours change.
local LOCKER_BODY, LOCKER_BACK = Color3.fromRGB(74, 116, 104), Color3.fromRGB(56, 90, 81)
local slateLocker = kits:FindFirstChild("client-office-slate")
slateLocker = slateLocker and slateLocker:FindFirstChild("furniture")
slateLocker = slateLocker and slateLocker:FindFirstChild("locker")
if slateLocker then
	local locker = slateLocker:Clone()
	for _, d in locker:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "LockerBack" then
				d.Color = LOCKER_BACK
			elseif d.Name ~= "NamePlate" and d.Name ~= "DoorVent" and d.Name ~= "DoorHandle" then
				d.Color = LOCKER_BODY
			end
		end
	end
	locker.Parent = furniture
	table.insert(report, "locker")
else
	table.insert(report, "locker FAILED: no slate locker template")
end
kit.Parent = kits

local okRules, Rules = pcall(function()
	return require(ReplicatedStorage.Shared.Features.Art.Rules.ArtKitRules:Clone())
end)
local lines = {}
local valid, invalid = 0, {}
for _, t in furniture:GetChildren() do
	local ok = okRules and Rules.validateTemplate(t, "furniture")
	if ok then
		valid += 1
	else
		table.insert(invalid, t.Name .. " " .. tostring(t:GetAttribute("BaseSize")))
	end
end
table.insert(lines, ("templates %d, valid %d, invalid: %s"):format(#furniture:GetChildren(), valid, table.concat(invalid, "; ")))
table.insert(lines, "variants: " .. table.concat(variantReport, ", "))
table.insert(lines, "load failures: " .. (if #failures > 0 then table.concat(failures, "; ") else "none"))
for _, r in report do
	if string.find(r, "FAILED") then
		table.insert(lines, r)
	end
end
return table.concat(lines, "\n")
