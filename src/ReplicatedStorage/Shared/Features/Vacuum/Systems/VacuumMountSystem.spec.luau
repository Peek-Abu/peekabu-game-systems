local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumMountSystem = require(script.Parent.VacuumMountSystem)

return function()
	local MOUNT = VacuumConstants.MOUNT
	local ORIGIN = CFrame.new(9000, 900, 9000)

	local function near(a, b, eps)
		return math.abs(a - b) <= (eps or 1e-3)
	end

	local function addPart(parent, name, cframe, size, canQuery)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cframe
		p.CanQuery = canQuery ~= false
		p.Parent = parent
		return p
	end

	-- A body: a torso 1 x 2 x 0.8 (its back at z = 0.4), a head above, a root inside, arms at the sides.
	local function makeBody()
		local model = Instance.new("Model")
		model.Name = "MountSpecBody"
		local torso = addPart(model, "UpperTorso", ORIGIN, Vector3.new(1, 2, 0.8))
		addPart(model, "HumanoidRootPart", ORIGIN, Vector3.new(2, 2, 2))
		local head = addPart(model, "Head", ORIGIN * CFrame.new(0, 1.6, 0.6), Vector3.new(1.2, 1.2, 1.2))
		-- The neck joins the torso to the head (the torso is still the back).
		local neck = Instance.new("Motor6D")
		neck.Name = "Neck"
		neck.Part0 = torso
		neck.Part1 = head
		neck.C0 = CFrame.new(0, 1, 0)
		neck.C1 = CFrame.new(0, -0.6, -0.6)
		neck.Parent = head
		addPart(model, "LeftUpperArm", ORIGIN * CFrame.new(-0.8, 0.5, 0), Vector3.new(0.4, 1, 0.4))
		model.Parent = workspace
		return model, torso
	end

	local function makePack()
		local pack = Instance.new("Model")
		pack.Name = "Pack"
		addPart(pack, "BackPad", CFrame.new(0, 0, 0.035), Vector3.new(0.4, 0.56, 0.08))
		addPart(pack, "CanisterBody", CFrame.new(0, 0, 0.32), Vector3.new(0.5, 0.56, 0.5))
		pack.WorldPivot = CFrame.identity
		return pack
	end

	local function depthsOf(model, torso, skip)
		return VacuumMountSystem.measure(model, torso, CFrame.new(0, 0.2, 0.5), Vector2.new(0.2, 0.28), skip or {})
	end

	describe("plateOf", function()
		it("makes the plate at the middle of the pad's front face when the skin has none", function()
			local pack = makePack()
			local plate = VacuumMountSystem.plateOf(pack)
			expect(plate).to.be.ok()
			expect(plate.Name).to.equal(MOUNT.plateName)
			local frame = VacuumMountSystem.plateFrame(pack)
			expect((frame.Position - Vector3.new(0, 0, -0.005)).Magnitude < 1e-4).to.equal(true)
			-- Asked again, the same one.
			expect(VacuumMountSystem.plateOf(pack)).to.equal(plate)
			pack:Destroy()
		end)

		it("keeps a skin's own authored plate", function()
			local pack = makePack()
			local authored = Instance.new("Attachment")
			authored.Name = MOUNT.plateName
			authored.Position = Vector3.new(0, 0.1, 0.2)
			authored.Parent = pack.CanisterBody
			expect(VacuumMountSystem.plateOf(pack)).to.equal(authored)
			local frame = VacuumMountSystem.plateFrame(pack)
			expect((frame.Position - Vector3.new(0, 0.1, 0.52)).Magnitude < 1e-4).to.equal(true)
			pack:Destroy()
		end)

		it("is the pivot itself for a pack with no pad", function()
			local pack = Instance.new("Model")
			expect(VacuumMountSystem.plateOf(pack)).never.to.be.ok()
			expect(VacuumMountSystem.plateFrame(pack)).to.equal(CFrame.identity)
			pack:Destroy()
		end)

		it("scales with the pack (Model:ScaleTo)", function()
			local pack = makePack()
			VacuumMountSystem.plateOf(pack)
			pack:ScaleTo(2)
			local frame = VacuumMountSystem.plateFrame(pack)
			expect((frame.Position - Vector3.new(0, 0, -0.01)).Magnitude < 1e-3).to.equal(true)
			pack:Destroy()
		end)
	end)

	describe("measure", function()
		it("reads the torso's back under the pad, ignoring the root and the head", function()
			local model, torso = makeBody()
			local depths = depthsOf(model, torso)
			expect(#depths > 0).to.equal(true)
			for _, hit in depths do
				expect(near(hit.Z, 0.4)).to.equal(true)
			end
			model:Destroy()
		end)

		it("reads what the body wears over its back, even a piece that turns queries off, and leaves it off", function()
			local model, torso = makeBody()
			local hoodie = addPart(model, "Hoodie", ORIGIN * CFrame.new(0, 0, 0.1), Vector3.new(1.1, 2, 1), false)
			local depths = depthsOf(model, torso)
			for _, hit in depths do
				expect(near(hit.Z, 0.6)).to.equal(true)
			end
			expect(hoodie.CanQuery).to.equal(false)
			model:Destroy()
		end)

		it("skips what it is told to (the pack itself)", function()
			local model, torso = makeBody()
			local pack = addPart(model, "Canister", ORIGIN * CFrame.new(0, 0, 0.8), Vector3.new(0.6, 0.8, 0.6))
			local depths = depthsOf(model, torso, { pack })
			for _, hit in depths do
				expect(near(hit.Z, 0.4)).to.equal(true)
			end
			model:Destroy()
		end)

		it("ignores pieces worn on the head (hair hanging down the back)", function()
			local model, torso = makeBody()
			local hair = addPart(model, "Hair", ORIGIN * CFrame.new(0, 0.3, 0.6), Vector3.new(0.8, 1.2, 0.3))
			local weld = Instance.new("Weld")
			weld.Part0 = hair
			weld.Part1 = model.Head
			weld.Parent = hair
			local depths = depthsOf(model, torso)
			for _, hit in depths do
				expect(near(hit.Z, 0.4)).to.equal(true)
			end
			model:Destroy()
		end)
	end)

	describe("seat", function()
		it("puts the back attachment on the surface, keeping the mount's height", function()
			local model, torso = makeBody()
			local back = VacuumMountSystem.seat(model, torso, CFrame.new(0, 0.2, 0.9), Vector2.new(0.2, 0.28), {})
			expect(back.Name).to.equal(MOUNT.backName)
			expect(back.Parent).to.equal(torso)
			expect(near(back.Position.Y, 0.2)).to.equal(true)
			expect(near(back.Position.Z, 0.4 + MOUNT.clearance)).to.equal(true)
			-- Seated again (a new outfit), the same attachment moves.
			addPart(model, "Coat", ORIGIN * CFrame.new(0, 0, 0.15), Vector3.new(1.1, 2, 1))
			local again = VacuumMountSystem.seat(model, torso, CFrame.new(0, 0.2, 0.9), Vector2.new(0.2, 0.28), {})
			expect(again).to.equal(back)
			expect(near(back.Position.Z, 0.65 + MOUNT.clearance)).to.equal(true)
			model:Destroy()
		end)

		-- The hood slopes past MOUNT.maxTilt (12 since 2026-11-13: Cappy's pack lay along his hood at 25): the plate leans
		-- only as far as the cap, and still stands clear of every hit.
		it("leans with a back that slopes out toward the top (a hood), at most maxTilt, clear of it", function()
			local model, torso = makeBody()
			-- A slab whose back face leans back ~20 degrees (top further out).
			addPart(
				model,
				"Hoodie",
				ORIGIN * CFrame.new(0, 0.2, 0.3) * CFrame.Angles(math.rad(20), 0, 0),
				Vector3.new(1.1, 2, 0.6)
			)
			local mount = CFrame.new(0, 0.2, 0.5)
			local half = Vector2.new(0.2, 0.28)
			local back = VacuumMountSystem.seat(model, torso, mount, half, {})
			expect(math.abs(math.asin(back.CFrame.UpVector.Z) - MOUNT.maxTilt) < math.rad(0.5)).to.equal(true)
			-- No hit stands out in front of the plate's plane.
			for _, hit in VacuumMountSystem.measure(model, torso, mount, half, {}) do
				local rel = back.CFrame:PointToObjectSpace(hit)
				expect(rel.Z <= 1e-3).to.equal(true)
			end
			model:Destroy()
		end)

		it("falls back to the given mount's depth when nothing is there to hit", function()
			local model = Instance.new("Model")
			local torso = addPart(model, "UpperTorso", ORIGIN * CFrame.new(50, 0, 0), Vector3.new(1, 2, 0.8))
			model.Parent = workspace
			-- Nothing left to hit (the torso skipped): the fallback, with no clearance added.
			local back =
				VacuumMountSystem.seat(model, torso, CFrame.new(0, 0.2, 0.5), Vector2.new(0.2, 0.28), { torso })
			expect(near(back.Position.Z, 0.5)).to.equal(true)
			model:Destroy()
		end)
	end)
end
