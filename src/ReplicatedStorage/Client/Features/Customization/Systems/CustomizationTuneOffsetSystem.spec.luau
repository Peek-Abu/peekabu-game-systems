--!strict
--[=[
	Unit tests for CustomizationTuneOffsetSystem — the `customizationtuneoffset` command body. Player stand-ins are plain tables
	(Players cannot be constructed in a spec); the rig is a real in-memory Model.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationClient = ReplicatedStorage.Client.Features.Customization
local tuneOffset = require(script.Parent.CustomizationTuneOffsetSystem)
local CustomizationDressSystem = require(CustomizationClient.Systems.CustomizationDressSystem)
local CustomizationPiecePool = require(CustomizationClient.State.CustomizationPiecePool)
local CustomizationRigOutfitTracker = require(CustomizationClient.State.CustomizationRigOutfitTracker)

return function()
	local model, container, pieceAttachment, me

	beforeEach(function()
		model = Instance.new("Model")
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Parent = model
		local socket = Instance.new("Attachment")
		socket.Name = "Hair"
		socket.Parent = head
		container = Instance.new("Folder")
		local accessory = Instance.new("Accessory")
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Parent = accessory
		pieceAttachment = Instance.new("Attachment")
		pieceAttachment.Name = "Hair"
		pieceAttachment.Parent = handle
		local pool = CustomizationPiecePool.new(container)
		CustomizationPiecePool.release(pool, "Hair10", { accessory })
		CustomizationDressSystem.apply(CustomizationRigOutfitTracker.new(model), {
			{ kind = "addCosmetic", mountKey = "hair", mount = { category = "hair", id = "Hair10", colors = {} } },
		}, pool)
		me = { Name = "Me", Character = model }
	end)

	afterEach(function()
		model:Destroy()
		container:Destroy()
	end)

	it("nudges the caller's own mounted piece and prints the snippet", function()
		local authored = pieceAttachment.CFrame
		local message = tuneOffset(me, me, "Hair10", 0, 0.25, 0, 0, 0, 0)
		expect(message:find("Nudged 1 piece", 1, true)).to.be.ok()
		expect(message:find("offset = { y = 0.25 }", 1, true)).to.be.ok()
		expect(pieceAttachment.CFrame).to.equal(authored * CFrame.new(0, 0.25, 0):Inverse())
	end)

	it("an all-zero offset puts the piece back on its authored placement", function()
		local authored = pieceAttachment.CFrame
		tuneOffset(me, me, "Hair10", 1, 0, 0, 0, 0, 0)
		local message = tuneOffset(me, me, "Hair10", 0, 0, 0, 0, 0, 0)
		expect(pieceAttachment.CFrame).to.equal(authored)
		expect(message:find("offset = {}", 1, true)).to.be.ok()
	end)

	it("refuses another player's rig, still printing the value", function()
		local message = tuneOffset(me, { Name = "Other", Character = model }, "Hair10", 1, 0, 0, 0, 0, 0)
		expect(message:find("your own rig only", 1, true)).to.be.ok()
		expect(message:find("offset = { x = 1 }", 1, true)).to.be.ok()
	end)

	it("says so when nothing of that id is mounted", function()
		expect(tuneOffset(me, me, "Hair11", 1, 0, 0, 0, 0, 0):find("No mounted piece", 1, true)).to.be.ok()
	end)

	it("says so when the caller has no body", function()
		local bodiless = { Name = "Me" }
		expect(tuneOffset(bodiless, bodiless, "Hair10", 1, 0, 0, 0, 0, 0):find("no body", 1, true)).to.be.ok()
	end)

	it("refuses a non-finite component", function()
		expect(tuneOffset(me, me, "Hair10", 0 / 0, 0, 0, 0, 0, 0):find("finite", 1, true)).to.be.ok()
		expect(tuneOffset(me, me, "Hair10", math.huge, 0, 0, 0, 0, 0):find("finite", 1, true)).to.be.ok()
	end)

	it("prints every supplied axis, in a stable order", function()
		local message = tuneOffset(me, me, "Hair10", 1, 2, 3, 0, 0, 45)
		expect(message:find("offset = { x = 1, y = 2, z = 3, rz = 45 }", 1, true)).to.be.ok()
	end)
end
