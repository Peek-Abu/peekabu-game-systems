local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeAnomalyConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeAnomalyConstants)
local OfficeAnomalySystem = require(script.Parent.OfficeAnomalySystem)
local OfficeAnomalyUtils = require(script.Parent.Parent.Utils.OfficeAnomalyUtils)

-- A stub of the exterior's slot set (the README contract): every slot in its default state, plus the parked car's
-- tail lights the carTicking slot dims on.
local function part(name, parent, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function label(parent, face, text, transparency)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Screen"
	gui.Face = face
	gui.Parent = parent
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.Text = text
	l.TextTransparency = transparency
	l.Parent = gui
	return l
end

local function slot(root, id)
	local model = Instance.new("Model")
	model.Name = "AnomalySlot_" .. id
	model:SetAttribute(OfficeAnomalyConstants.SLOT_ATTRIBUTE, id)
	model.Parent = root
	return model
end

local function exterior()
	local root = Instance.new("Folder")
	root.Name = "OfficeExterior"
	local cars = Instance.new("Folder")
	cars.Name = "Cars"
	cars.Parent = root
	local red = Color3.fromRGB(150, 20, 20)
	part("TailLight", cars, { Position = Vector3.new(902, 3.6, 33), Material = Enum.Material.Neon, Color = red })
	part("TailLight", cars, { Position = Vector3.new(902, 3.6, 37), Material = Enum.Material.Neon, Color = red })
	part("TailLight", cars, { Position = Vector3.new(500, 3.6, 37), Material = Enum.Material.Neon, Color = red })

	local slots = {}
	local s = slot(root, "silhouette")
	for _, name in { "FigureLegs", "FigureBody", "FigureHead" } do
		part(name, s, { Transparency = 1, Position = Vector3.new(0, 50, 0) })
	end
	slots.silhouette = s

	s = slot(root, "autoDoors")
	local a = part("LobbyDoorLeaf", s, { Transparency = 0.6, CFrame = CFrame.new(10, 5, 0) })
	a:SetAttribute("Side", 1)
	a:SetAttribute("SlideStuds", 2.2)
	local b = part("LobbyDoorLeaf", s, { Transparency = 0.6, CFrame = CFrame.new(6, 5, 0) })
	b:SetAttribute("Side", -1)
	b:SetAttribute("SlideStuds", 2.2)
	slots.autoDoors = s

	s = slot(root, "carTicking")
	part("Emitter", s, { Transparency = 1, Position = Vector3.new(914, 3.7, 35) })
	slots.carTicking = s

	s = slot(root, "welcomeScreen")
	local screen = part("WelcomeScreen", s, { Color = Color3.fromRGB(18, 20, 26) })
	label(screen, Enum.NormalId.Left, "", 0)
	slots.welcomeScreen = s

	s = slot(root, "boothTv")
	part("BoothTV", s, { Color = Color3.fromRGB(24, 24, 26), Material = Enum.Material.SmoothPlastic })
	slots.boothTv = s

	s = slot(root, "wetFloor")
	label(part("SignFront", s, { Transparency = 1 }), Enum.NormalId.Front, "CAUTION\nWET FLOOR", 1)
	label(part("SignBack", s, { Transparency = 1 }), Enum.NormalId.Back, "CAUTION\nWET FLOOR", 1)
	part("SignHinge", s, { Transparency = 1 })
	slots.wetFloor = s

	s = slot(root, "banner")
	local cloth = part("BannerCloth", s, { CFrame = CFrame.new(1030, 10, 0), Size = Vector3.new(50, 5.5, 0.15) })
	label(cloth, Enum.NormalId.Front, "TOGETHER WE THRIVE", 0)
	part("BannerRod", s, { CFrame = CFrame.new(1030, 13.6, 0) })
	slots.banner = s
	return root, slots
end

-- Every property apply may touch, for every part, label and gui under the exterior, plus the instance list. Sounds
-- are left out: SoundServiceClient keeps an idle voice at an emitter it has played from, by design.
local function snapshot(root)
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Sound") then
			continue
		elseif d:IsA("BasePart") then
			out[d] = {
				cframe = d.CFrame,
				transparency = d.Transparency,
				color = d.Color,
				material = d.Material,
			}
		elseif d:IsA("TextLabel") then
			out[d] = { text = d.Text, textTransparency = d.TextTransparency }
		elseif d:IsA("SurfaceGui") then
			out[d] = { face = d.Face, lightInfluence = d.LightInfluence, brightness = d.Brightness }
		else
			out[d] = { other = d.ClassName }
		end
	end
	return out
end

local function same(a, b)
	for instance, props in a do
		local other = b[instance]
		if other == nil then
			return false, instance:GetFullName() .. " went missing"
		end
		for key, value in props do
			local now = other[key]
			if typeof(value) == "CFrame" then
				if
					(value.Position - now.Position).Magnitude > 1e-4
					or (value.LookVector - now.LookVector).Magnitude > 1e-4
					or (value.UpVector - now.UpVector).Magnitude > 1e-4
				then
					return false, instance:GetFullName() .. "." .. key
				end
			elseif value ~= now then
				return false, instance:GetFullName() .. "." .. key .. " " .. tostring(value) .. " ~= " .. tostring(now)
			end
		end
	end
	for instance in b do
		if a[instance] == nil then
			return false, "extra " .. instance:GetFullName()
		end
	end
	return true, ""
end

return function()
	local root, slots
	beforeEach(function()
		root, slots = exterior()
		OfficeAnomalySystem.forgetRun()
	end)
	afterEach(function()
		for _, s in slots do
			OfficeAnomalySystem.resetSlot(s)
		end
		root:Destroy()
	end)

	local function cloth()
		return slots.banner.BannerCloth
	end

	describe("apply", function()
		it("changes each slot from its default", function()
			local before = snapshot(root)
			for _, id in OfficeAnomalyConstants.IDS do
				OfficeAnomalySystem.applySlot(slots[id], 7, 0)
			end
			-- Doors mid-cycle, the screen in its wrong-line window.
			-- A player near schedules a cycle 20-40 s on; by 45 s it is due and starts; a second later it is open.
			OfficeAnomalySystem.stepSlot(slots.autoDoors, 1, true)
			OfficeAnomalySystem.stepSlot(slots.autoDoors, 45, true)
			OfficeAnomalySystem.stepSlot(slots.autoDoors, 46, true)
			OfficeAnomalySystem.stepSlot(slots.welcomeScreen, 5)
			local leaves = slots.autoDoors:GetChildren()
			expect(leaves[1].CFrame.Position ~= before[leaves[1]].cframe.Position).to.equal(true)
			expect(slots.silhouette.FigureBody.Transparency).to.equal(0)
			expect(slots.wetFloor.SignFront.Transparency).to.equal(0)
			expect(slots.wetFloor.SignFront.Screen.Text.TextTransparency).to.equal(0)
			expect(slots.boothTv.BoothTV.Material).to.equal(Enum.Material.Neon)
			expect(slots.boothTv.BoothTV:FindFirstChildWhichIsA("SurfaceLight") ~= nil).to.equal(true)
			expect(slots.welcomeScreen.WelcomeScreen.Screen.Text.Text).to.equal(OfficeAnomalyUtils.wrongLine(7))
			expect(cloth().CFrame.UpVector:FuzzyEq(-before[cloth()].cframe.UpVector, 1e-4)).to.equal(true)
			expect(cloth().CFrame.LookVector:FuzzyEq(before[cloth()].cframe.LookVector, 1e-4)).to.equal(true)
			local lit = 0
			for _, light in root.Cars:GetChildren() do
				if light:FindFirstChildWhichIsA("PointLight") ~= nil then
					lit += 1
				end
			end
			expect(lit).to.equal(2)
		end)

		it("shows the welcome text outside the wrong-line window", function()
			OfficeAnomalySystem.applySlot(slots.welcomeScreen, 7, 0)
			OfficeAnomalySystem.stepSlot(slots.welcomeScreen, 1)
			expect(slots.welcomeScreen.WelcomeScreen.Screen.Text.Text).to.equal(OfficeAnomalyConstants.WELCOME_TEXT)
		end)
	end)

	describe("reset", function()
		it("restores every slot's default after each id is applied (and stepped)", function()
			local before = snapshot(root)
			for _, id in OfficeAnomalyConstants.IDS do
				OfficeAnomalySystem.applySlot(slots[id], 7, 0)
				for _, t in { 1, 45, 46 } do
					OfficeAnomalySystem.stepSlot(slots[id], t, true)
				end
				OfficeAnomalySystem.resetSlot(slots[id])
				local ok, why = same(before, snapshot(root))
				expect(id .. ": " .. why).to.equal(id .. ": ")
				expect(ok).to.equal(true)
			end
		end)

		it("restores every default with all ids applied at once", function()
			local before = snapshot(root)
			for _, id in OfficeAnomalyConstants.IDS do
				OfficeAnomalySystem.applySlot(slots[id], 7, 0)
				for _, t in { 1, 45, 46 } do
					OfficeAnomalySystem.stepSlot(slots[id], t, true)
				end
			end
			for _, id in OfficeAnomalyConstants.IDS do
				OfficeAnomalySystem.resetSlot(slots[id])
			end
			local ok, why = same(before, snapshot(root))
			expect(why).to.equal("")
			expect(ok).to.equal(true)
		end)

		it("applying twice then resetting still restores the default", function()
			local before = snapshot(root)
			OfficeAnomalySystem.applySlot(slots.banner, 7, 0)
			OfficeAnomalySystem.applySlot(slots.banner, 7, 0)
			OfficeAnomalySystem.resetSlot(slots.banner)
			local ok, why = same(before, snapshot(root))
			expect(why).to.equal("")
			expect(ok).to.equal(true)
		end)

		it("is harmless on a slot never applied", function()
			local before = snapshot(root)
			OfficeAnomalySystem.resetSlot(slots.boothTv)
			local ok = same(before, snapshot(root))
			expect(ok).to.equal(true)
		end)
	end)

	describe("auto doors", function()
		local function leafPositions()
			local list = {}
			for _, leaf in slots.autoDoors:GetChildren() do
				table.insert(list, leaf.Position)
			end
			return list
		end
		local function moved(before)
			for index, position in leafPositions() do
				if (position - before[index]).Magnitude > 1e-4 then
					return true
				end
			end
			return false
		end

		it("do not open the moment a player comes near, only 20-40 s later", function()
			local before = leafPositions()
			OfficeAnomalySystem.applySlot(slots.autoDoors, 7, 0)
			OfficeAnomalySystem.stepSlot(slots.autoDoors, 5, false)
			OfficeAnomalySystem.stepSlot(slots.autoDoors, 100, true)
			for t = 100.1, 119.9, 0.5 do
				OfficeAnomalySystem.stepSlot(slots.autoDoors, t, true)
				expect(moved(before)).to.equal(false)
			end
			local opened = nil
			for t = 120, 141, 0.25 do
				OfficeAnomalySystem.stepSlot(slots.autoDoors, t, true)
				if opened == nil and moved(before) then
					opened = t
				end
			end
			expect(opened ~= nil and opened >= 120 and opened <= 141).to.equal(true)
		end)

		it("do not open when a cycle comes due with nobody near", function()
			local before = leafPositions()
			OfficeAnomalySystem.applySlot(slots.autoDoors, 7, 0)
			OfficeAnomalySystem.stepSlot(slots.autoDoors, 1, true)
			for t = 2, 60, 0.5 do
				OfficeAnomalySystem.stepSlot(slots.autoDoors, t, false)
				expect(moved(before)).to.equal(false)
			end
			-- Back near: a fresh wait, not an instant open.
			OfficeAnomalySystem.stepSlot(slots.autoDoors, 61, true)
			OfficeAnomalySystem.stepSlot(slots.autoDoors, 62, true)
			expect(moved(before)).to.equal(false)
		end)

		it("a re-stream schedules afresh instead of opening", function()
			local before = leafPositions()
			OfficeAnomalySystem.applySlot(slots.autoDoors, 7, 0)
			OfficeAnomalySystem.stepSlot(slots.autoDoors, 1, true)
			OfficeAnomalySystem.refreshSlot(slots.autoDoors, 50)
			OfficeAnomalySystem.stepSlot(slots.autoDoors, 50, true)
			OfficeAnomalySystem.stepSlot(slots.autoDoors, 51, true)
			expect(moved(before)).to.equal(false)
		end)
	end)

	describe("streaming", function()
		it("a part that streams in after apply gets the anomaly on refresh, and reset still restores it", function()
			local tv = slots.boothTv.BoothTV
			tv.Parent = nil
			OfficeAnomalySystem.applySlot(slots.boothTv, 7, 0)
			tv.Parent = slots.boothTv
			expect(tv.Material).to.equal(Enum.Material.SmoothPlastic)
			OfficeAnomalySystem.refreshSlot(slots.boothTv, 1)
			expect(tv.Material).to.equal(Enum.Material.Neon)
			OfficeAnomalySystem.resetSlot(slots.boothTv)
			expect(tv.Material).to.equal(Enum.Material.SmoothPlastic)
			expect(tv:FindFirstChildWhichIsA("SurfaceLight")).to.equal(nil)
		end)

		it("lights tail lights that stream in after the car slot was applied", function()
			local cars = root.Cars
			cars.Parent = nil
			OfficeAnomalySystem.applySlot(slots.carTicking, 7, 0)
			cars.Parent = root
			OfficeAnomalySystem.stepSlot(slots.carTicking, 5)
			local lit = 0
			for _, light in cars:GetChildren() do
				if light:FindFirstChildWhichIsA("PointLight") ~= nil then
					lit += 1
				end
			end
			expect(lit).to.equal(2)
			OfficeAnomalySystem.resetSlot(slots.carTicking)
			for _, light in cars:GetChildren() do
				expect(light:FindFirstChildWhichIsA("PointLight")).to.equal(nil)
				expect(light.Color).to.equal(Color3.fromRGB(150, 20, 20))
			end
		end)
	end)

	describe("silhouette view", function()
		local function shown()
			return slots.silhouette.FigureBody.Transparency == 0
		end

		it("is seen after 0.5 s in view, stays while on screen but blocked or far, goes once off screen", function()
			OfficeAnomalySystem.applySlot(slots.silhouette, 9, 0)
			expect(shown()).to.equal(true)
			-- Blocked or far while not yet seen: it never goes.
			OfficeAnomalySystem.stepSlot(slots.silhouette, 0.2, false, true)
			OfficeAnomalySystem.stepSlot(slots.silhouette, 0.4, false, false)
			expect(shown()).to.equal(true)
			OfficeAnomalySystem.stepSlot(slots.silhouette, 1, true, true)
			OfficeAnomalySystem.stepSlot(slots.silhouette, 1.6, true, true)
			-- Seen, then blocked but still on screen: it stays.
			OfficeAnomalySystem.stepSlot(slots.silhouette, 2, false, true)
			OfficeAnomalySystem.stepSlot(slots.silhouette, 5, false, true)
			expect(shown()).to.equal(true)
			OfficeAnomalySystem.stepSlot(slots.silhouette, 6, false, false)
			expect(shown()).to.equal(false)
			-- Gone for the run: back on screen it stays hidden, and a re-apply keeps it hidden.
			OfficeAnomalySystem.stepSlot(slots.silhouette, 7, true, true)
			expect(shown()).to.equal(false)
			OfficeAnomalySystem.resetSlot(slots.silhouette)
			OfficeAnomalySystem.applySlot(slots.silhouette, 9, 8)
			expect(shown()).to.equal(false)
		end)

		it("keeps its progress through a re-stream", function()
			OfficeAnomalySystem.applySlot(slots.silhouette, 9, 0)
			OfficeAnomalySystem.stepSlot(slots.silhouette, 1, true, true)
			OfficeAnomalySystem.stepSlot(slots.silhouette, 1.6, true, true)
			OfficeAnomalySystem.refreshSlot(slots.silhouette, 2)
			expect(shown()).to.equal(true)
			-- Already seen: the first time off screen it goes.
			OfficeAnomalySystem.stepSlot(slots.silhouette, 3, false, false)
			expect(shown()).to.equal(false)
		end)
	end)

	describe("silhouette", function()
		it("once gone stays hidden for the run, even when re-applied", function()
			OfficeAnomalySystem.applySlot(slots.silhouette, 7, 0)
			OfficeAnomalySystem.markSilhouetteGone(7)
			OfficeAnomalySystem.stepSlot(slots.silhouette, 1)
			expect(slots.silhouette.FigureBody.Transparency).to.equal(1)
			OfficeAnomalySystem.resetSlot(slots.silhouette)
			OfficeAnomalySystem.applySlot(slots.silhouette, 7, 0)
			expect(slots.silhouette.FigureBody.Transparency).to.equal(1)
			-- A new run (seed) shows it again.
			OfficeAnomalySystem.resetSlot(slots.silhouette)
			OfficeAnomalySystem.applySlot(slots.silhouette, 8, 0)
			expect(slots.silhouette.FigureBody.Transparency).to.equal(0)
		end)
	end)
end
