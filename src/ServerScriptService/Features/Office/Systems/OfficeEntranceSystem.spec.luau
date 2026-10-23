local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local OfficeEntranceSystem = require(script.Parent.OfficeEntranceSystem)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)

local OUTSIDE = CFrame.new(9000, 0, 9000) * CFrame.Angles(0, math.pi / 2, 0)
local INSIDE = CFrame.new(9100, 0, 9050)

-- A stub character (an unanchored root in the Workspace: specs never yield, so it never falls) standing `offset` from a
-- door part, with a fake player.
local function scene(offset)
	local folder = Instance.new("Folder")
	folder.Name = "OfficeEntranceSpec"
	local door = Instance.new("Part")
	door.Anchored = true
	door.CanCollide = false
	door.CFrame = OUTSIDE * CFrame.new(0, 5, 5)
	door.Parent = folder
	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = false
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = door.CFrame * CFrame.new(offset)
	root.Parent = character
	character.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	character.Parent = folder
	folder.Parent = Workspace
	return folder, door, root, { UserId = 90410, Name = "EntranceSpec", Character = character }
end

-- A carried part held the way Carry holds it: a Weld from the character's root (CarryServiceServer.pickUp).
local function carry(root, folder)
	local item = Instance.new("Part")
	item.Size = Vector3.new(2, 2, 2)
	item.Massless = true
	item.CanCollide = false
	item.CFrame = root.CFrame * CFrame.new(0, 0.5, -2.5)
	item.Parent = folder
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = item
	weld.C0 = root.CFrame:ToObjectSpace(item.CFrame)
	weld.C1 = CFrame.identity
	weld.Parent = item
	return item
end

local function harness(door, overrides)
	overrides = overrides or {}
	local log = { fades = {}, delayed = {} }
	log.system = OfficeEntranceSystem.new({
		inCrew = function()
			return overrides.inCrew ~= false
		end,
		alive = function()
			return overrides.alive ~= false
		end,
		entrance = function(id)
			if id == "dock" then
				return OUTSIDE, INSIDE
			end
			return nil, nil
		end,
		parts = function()
			return { door }
		end,
		fade = function(_player, covered, seconds)
			table.insert(log.fades, { covered = covered, seconds = seconds })
		end,
		after = function(seconds, run)
			table.insert(log.delayed, { seconds = seconds, run = run })
		end,
		stream = function() end,
	})
	return log
end

return function()
	it("registers Enter and Leave prompts that reach ENTRANCE_REACH", function()
		local enter = InteractionRegistry.get(OfficeConstants.ENTER_KIND)
		local leave = InteractionRegistry.get(OfficeConstants.LEAVE_KIND)
		expect(enter).to.be.ok()
		expect(leave).to.be.ok()
		expect(enter.actionText).to.equal("Enter")
		expect(leave.actionText).to.equal("Leave")
		expect(enter.maxDistance).to.equal(OfficeConstants.OUTSIDE.ENTRANCE_REACH)
		expect(leave.maxDistance).to.equal(OfficeConstants.OUTSIDE.ENTRANCE_REACH)
	end)

	it("fades out over 0.2 s and back in over 0.3 s", function()
		expect(OfficeConstants.OUTSIDE.FADE_OUT).to.equal(0.2)
		expect(OfficeConstants.OUTSIDE.FADE_IN).to.equal(0.3)
	end)

	describe("target", function()
		it("is the inside frame to enter and the outside frame to leave", function()
			expect(OfficeEntranceSystem.target(OfficeConstants.ENTER_KIND, OUTSIDE, INSIDE)).to.equal(INSIDE)
			expect(OfficeEntranceSystem.target(OfficeConstants.LEAVE_KIND, OUTSIDE, INSIDE)).to.equal(OUTSIDE)
		end)
	end)

	describe("allowed", function()
		it("is true for a living crew member at the door with nothing pending", function()
			expect(OfficeEntranceSystem.allowed({ inCrew = true, alive = true, distance = 4, pending = false })).to.equal(
				true
			)
		end)

		it("is false off the crew, dead or caught, out of reach, or with a teleport pending", function()
			expect(OfficeEntranceSystem.allowed({ inCrew = false, alive = true, distance = 4, pending = false })).to.equal(
				false
			)
			expect(OfficeEntranceSystem.allowed({ inCrew = true, alive = false, distance = 4, pending = false })).to.equal(
				false
			)
			expect(OfficeEntranceSystem.allowed({ inCrew = true, alive = true, distance = 10.5, pending = false })).to.equal(
				false
			)
			expect(OfficeEntranceSystem.allowed({ inCrew = true, alive = true, distance = 4, pending = true })).to.equal(
				false
			)
		end)
	end)

	describe("teleport", function()
		it("brings a carried object along at the same offset from the root", function()
			local folder, _door, root, player = scene(Vector3.new(0, -2, 3))
			local item = carry(root, folder)
			local before = root.CFrame:ToObjectSpace(item.CFrame)
			OfficeEntranceSystem.teleport(player.Character, INSIDE + Vector3.new(0, 3, 0))
			expect((root.Position - (INSIDE.Position + Vector3.new(0, 3, 0))).Magnitude < 0.05).to.equal(true)
			local after = root.CFrame:ToObjectSpace(item.CFrame)
			expect((after.Position - before.Position).Magnitude < 0.05).to.equal(true)
			folder:Destroy()
		end)
	end)

	describe("request", function()
		it("fades out, then moves the player SPAWN_HEIGHT above the inside frame and fades in", function()
			local folder, door, root, player = scene(Vector3.new(0, -2, 3))
			local log = harness(door)
			expect(log.system.request(player, OfficeConstants.ENTER_KIND, "dock", 100)).to.equal(true)
			expect(#log.fades).to.equal(1)
			expect(log.fades[1].covered).to.equal(true)
			expect(log.fades[1].seconds).to.equal(OfficeConstants.OUTSIDE.FADE_OUT)
			expect(#log.delayed).to.equal(1)
			expect(log.delayed[1].seconds).to.equal(OfficeConstants.OUTSIDE.FADE_OUT)
			log.delayed[1].run()
			local expected = INSIDE.Position + Vector3.new(0, OfficeConstants.SPAWN_HEIGHT, 0)
			expect((root.Position - expected).Magnitude < 0.05).to.equal(true)
			expect(#log.fades).to.equal(2)
			expect(log.fades[2].covered).to.equal(false)
			expect(log.fades[2].seconds).to.equal(OfficeConstants.OUTSIDE.FADE_IN)
			folder:Destroy()
		end)

		it("leaves to the outside frame", function()
			local folder, door, root, player = scene(Vector3.new(0, -2, 3))
			local log = harness(door)
			expect(log.system.request(player, OfficeConstants.LEAVE_KIND, "dock", 100)).to.equal(true)
			log.delayed[1].run()
			local expected = OUTSIDE.Position + Vector3.new(0, OfficeConstants.SPAWN_HEIGHT, 0)
			expect((root.Position - expected).Magnitude < 0.05).to.equal(true)
			folder:Destroy()
		end)

		it("refuses a request while a teleport is pending, and takes one again once it lands", function()
			local folder, door, _root, player = scene(Vector3.new(0, -2, 3))
			local log = harness(door)
			expect(log.system.request(player, OfficeConstants.ENTER_KIND, "dock", 100)).to.equal(true)
			expect(log.system.request(player, OfficeConstants.ENTER_KIND, "dock", 100.1)).to.equal(false)
			expect(#log.fades).to.equal(1)
			expect(#log.delayed).to.equal(1)
			log.delayed[1].run()
			-- Landed inside, far from the outside door: out of reach now, so move them back to test the flag alone.
			player.Character.PrimaryPart.CFrame = door.CFrame * CFrame.new(0, -2, 3)
			expect(log.system.request(player, OfficeConstants.ENTER_KIND, "dock", 101)).to.equal(true)
			folder:Destroy()
		end)

		it("refuses off the crew, dead, out of reach, an unknown entrance or kind, and does nothing", function()
			local folder, door, root, player = scene(Vector3.new(0, -2, 3))
			local start = root.Position
			expect(harness(door, { inCrew = false }).system.request(player, OfficeConstants.ENTER_KIND, "dock", 1)).to.equal(
				false
			)
			expect(harness(door, { alive = false }).system.request(player, OfficeConstants.ENTER_KIND, "dock", 1)).to.equal(
				false
			)
			local unknown = harness(door)
			expect(unknown.system.request(player, OfficeConstants.ENTER_KIND, "lobby", 1)).to.equal(false)
			expect(unknown.system.request(player, "officeDoor", "dock", 1)).to.equal(false)
			expect(#unknown.fades).to.equal(0)
			folder:Destroy()

			local far, farDoor, farRoot, farPlayer = scene(Vector3.new(0, -2, 12))
			local farLog = harness(farDoor)
			expect(farLog.system.request(farPlayer, OfficeConstants.ENTER_KIND, "dock", 1)).to.equal(false)
			expect(#farLog.fades).to.equal(0)
			expect(#farLog.delayed).to.equal(0)
			far:Destroy()
			expect((root.Position - start).Magnitude < 0.05).to.equal(true)
			expect(farRoot).to.be.ok()
		end)

		it("refuses a caught player (the catch holds their root anchored)", function()
			local folder, door, root, player = scene(Vector3.new(0, -2, 3))
			root.Anchored = true
			local log = harness(door)
			expect(log.system.request(player, OfficeConstants.ENTER_KIND, "dock", 1)).to.equal(false)
			expect(#log.fades).to.equal(0)
			folder:Destroy()
		end)
	end)
end
