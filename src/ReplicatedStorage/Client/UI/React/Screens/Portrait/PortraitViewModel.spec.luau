local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local PortraitViewModel = require(script.Parent.PortraitViewModel)

return function()
	local bounds = { min = Vector3.new(-1, 0, -0.5), max = Vector3.new(1, 5, 0.5) }

	-- Whether every corner of `box` projects inside the camera's view at `aspect` (width / height).
	local function inView(camera, box, aspect)
		local tanV = math.tan(math.rad(camera.fov) / 2)
		for _, x in { box.min.X, box.max.X } do
			for _, y in { box.min.Y, box.max.Y } do
				for _, z in { box.min.Z, box.max.Z } do
					local p = camera.cframe:PointToObjectSpace(Vector3.new(x, y, z))
					local depth = -p.Z
					if depth <= 0 then
						return false
					end
					if math.abs(p.Y) / depth > tanV + 1e-6 or math.abs(p.X) / depth > tanV * aspect + 1e-6 then
						return false
					end
				end
			end
		end
		return true
	end

	describe("camera", function()
		it("looks at the box's centre from in front (-Z), a little above", function()
			local camera = PortraitViewModel.camera(bounds, "full", 1)
			local centre = Vector3.new(0, 2.5, 0)
			local towards = (centre - camera.cframe.Position).Unit
			expect((towards - camera.cframe.LookVector).Magnitude < 1e-3).to.equal(true)
			expect(camera.cframe.Position.Z < 0).to.equal(true)
			expect(camera.cframe.Position.Y > centre.Y).to.equal(true)
		end)

		it("fits the whole box, square and wide", function()
			expect(inView(PortraitViewModel.camera(bounds, "full", 1), bounds, 1)).to.equal(true)
			expect(inView(PortraitViewModel.camera(bounds, "full", 0.5), bounds, 0.5)).to.equal(true)
			expect(inView(PortraitViewModel.camera(bounds, "head", 2), bounds, 2)).to.equal(true)
		end)

		it("stands further back for a narrower frame", function()
			local square = PortraitViewModel.camera(bounds, "full", 1)
			local narrow = PortraitViewModel.camera(bounds, "full", 0.3)
			local function distance(camera)
				return (camera.cframe.Position - Vector3.new(0, 2.5, 0)).Magnitude
			end
			expect(distance(narrow) > distance(square)).to.equal(true)
		end)

		it("treats a zero or negative aspect as square", function()
			local square = PortraitViewModel.camera(bounds, "full", 1)
			local broken = PortraitViewModel.camera(bounds, "full", 0)
			expect((square.cframe.Position - broken.cframe.Position).Magnitude < 1e-6).to.equal(true)
		end)
	end)

	describe("parts", function()
		it("frames a head and a bust by the head's parts, a full figure by everything", function()
			expect(table.find(PortraitViewModel.parts("head"), "Head")).to.be.ok()
			expect(table.find(PortraitViewModel.parts("head"), "UpperTorso")).never.to.be.ok()
			expect(table.find(PortraitViewModel.parts("bust"), "Head")).to.be.ok()
			expect(table.find(PortraitViewModel.parts("bust"), "LeftEar")).never.to.be.ok()
			expect(table.find(PortraitViewModel.parts("upper"), "LeftEar")).to.be.ok()
			expect(PortraitViewModel.parts("full")).never.to.be.ok()
		end)

		it("reaches a bust below the head (the chest), keeping the head in view", function()
			local head = PortraitViewModel.camera(bounds, "head", 1)
			local bust = PortraitViewModel.camera(bounds, "bust", 1)
			expect(bust.cframe.Position.Y < head.cframe.Position.Y).to.equal(true)
			local below = { min = Vector3.new(-1, -1.5, -0.5), max = bounds.max }
			expect(inView(bust, below, 1)).to.equal(true)
		end)
	end)

	describe("lighting", function()
		it("lights from the front, above and the camera's left", function()
			for _, tone in { "light", "dark" } do
				local light = PortraitViewModel.lighting(tone)
				expect(light.direction.Y < 0).to.equal(true)
				expect(light.direction.Z > 0).to.equal(true)
			end
		end)

		it("lifts the shadows more on a dark plate", function()
			local light = PortraitViewModel.lighting("light").ambient
			local dark = PortraitViewModel.lighting("dark").ambient
			expect(light ~= dark).to.equal(true)
		end)
	end)

	describe("fallback", function()
		local pippa = EmployeeRegistry.get("Pippa")

		it("is the ID-card photo of the player's own skin", function()
			expect(PortraitViewModel.fallback(1, nil)).to.equal(pippa.skins.Default.portrait)
			expect(PortraitViewModel.fallback(20661908, nil)).to.equal(pippa.skins.OwnerSpecial.portrait)
		end)

		it("uses the named employee, else the default one", function()
			expect(PortraitViewModel.fallback(1, "Pippa")).to.equal(pippa.skins.Default.portrait)
			expect(PortraitViewModel.fallback(1, "Nobody")).to.equal(pippa.skins.Default.portrait)
		end)
	end)
end
