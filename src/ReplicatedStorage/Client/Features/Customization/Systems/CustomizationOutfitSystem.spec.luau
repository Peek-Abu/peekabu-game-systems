--!strict
--[=[
	Unit tests for CustomizationOutfitSystem — which look each rig gets and when. Private atoms, a recording dress
	callback and a fake clock, so nothing touches the live StateSyncClientStore or real art.

	Not covered here (Studio checklist): the replication client parking undressed puppets, and real
	pieces binding on a real rig.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local CustomizationOutfitSystem = require(script.Parent.CustomizationOutfitSystem)
local CustomizationPiecePool = require(ReplicatedStorage.Client.Features.Customization.State.CustomizationPiecePool)
local CustomizationRigOutfitTracker =
	require(ReplicatedStorage.Client.Features.Customization.State.CustomizationRigOutfitTracker)

return function()
	local container, models, state, ownAppearance, publicPlayers, dressed, t

	local function look(hairId)
		return {
			cosmetics = { hair = { id = hairId, colors = {} } },
			accessories = {},
			body = {},
			headType = "Uncovered",
			surfaces = {},
		}
	end

	local function puppet(userId)
		local model = Instance.new("Model")
		table.insert(models, model)
		local outfit = CustomizationRigOutfitTracker.new(model)
		CustomizationRigOutfitTracker.assign(outfit, userId)
		return outfit
	end

	local function setEntry(userId, hairId, version)
		local map = table.clone(publicPlayers())
		map[tostring(userId)] =
			{ health = 100, maxHealth = 100, appearance = look(hairId), appearanceVersion = version }
		publicPlayers(map)
	end

	-- The hair id the last dress of `outfit` mounted.
	local function lastHair(outfit)
		for i = #dressed, 1, -1 do
			if dressed[i].outfit == outfit then
				for _, op in dressed[i].ops do
					if op.kind == "addCosmetic" and op.mountKey == "hair" then
						return op.mount.id
					end
				end
			end
		end
		return nil
	end

	beforeEach(function()
		container = Instance.new("Folder")
		models = {}
		dressed = {}
		t = 0
		ownAppearance = Charm.atom(look("Hair10"))
		publicPlayers = Charm.atom({})
		state = CustomizationOutfitSystem.new({
			ownAppearance = ownAppearance,
			publicPlayers = publicPlayers,
			pieces = CustomizationPiecePool.new(container),
			dress = function(outfit, ops)
				table.insert(dressed, { outfit = outfit, ops = ops })
			end,
			now = function()
				return t
			end,
		})
	end)

	afterEach(function()
		CustomizationOutfitSystem.destroy(state)
		for _, model in models do
			model:Destroy()
		end
		container:Destroy()
	end)

	describe("owner rig", function()
		it("dresses synchronously on attach, from the player's own appearance", function()
			local model = Instance.new("Model")
			table.insert(models, model)
			local outfit = CustomizationOutfitSystem.attachOwner(state, model, 1)
			expect(CustomizationRigOutfitTracker.isDressed(outfit)).to.equal(true)
			expect(lastHair(outfit)).to.equal("Hair10")
		end)

		it("applies a later change through the queue", function()
			local model = Instance.new("Model")
			table.insert(models, model)
			local outfit = CustomizationOutfitSystem.attachOwner(state, model, 1)
			ownAppearance(look("Hair11"))
			CustomizationOutfitSystem.frame(state)
			expect(lastHair(outfit)).to.equal("Hair11")
		end)
	end)

	describe("puppets", function()
		it("dresses from the public entry already present", function()
			setEntry(2, "Hair10", 1)
			local outfit = puppet(2)
			CustomizationOutfitSystem.attachPuppet(state, outfit, 2)
			expect(CustomizationRigOutfitTracker.isDressed(outfit)).to.equal(false) -- parked until the queue runs
			CustomizationOutfitSystem.frame(state)
			expect(CustomizationRigOutfitTracker.isDressed(outfit)).to.equal(true)
			expect(outfit.version).to.equal(1)
		end)

		it("dresses when a late entry arrives", function()
			local outfit = puppet(2)
			CustomizationOutfitSystem.attachPuppet(state, outfit, 2)
			CustomizationOutfitSystem.frame(state)
			expect(CustomizationRigOutfitTracker.isDressed(outfit)).to.equal(false)
			setEntry(2, "Hair11", 4)
			CustomizationOutfitSystem.frame(state)
			expect(outfit.version).to.equal(4)
			expect(lastHair(outfit)).to.equal("Hair11")
		end)

		it("falls back to the default look after the timeout, then swaps to the real one", function()
			local outfit = puppet(2)
			CustomizationOutfitSystem.attachPuppet(state, outfit, 2)
			t = CustomizationOutfitSystem.DEFAULT_LOOK_SECONDS
			CustomizationOutfitSystem.frame(state)
			expect(outfit.version).to.equal(CustomizationOutfitSystem.DEFAULT_LOOK_VERSION)
			expect(state.defaultLooks).to.equal(1)
			setEntry(2, "Hair11", 1)
			CustomizationOutfitSystem.frame(state)
			expect(outfit.version).to.equal(1)
			expect(lastHair(outfit)).to.equal("Hair11")
		end)

		-- The stale-job race: the entry changes again before the first dress ran.
		it("lands on the newest version only", function()
			setEntry(2, "Hair10", 1)
			local outfit = puppet(2)
			CustomizationOutfitSystem.attachPuppet(state, outfit, 2)
			setEntry(2, "Hair11", 2)
			CustomizationOutfitSystem.frame(state)
			expect(#dressed).to.equal(1)
			expect(lastHair(outfit)).to.equal("Hair11")
			expect(outfit.version).to.equal(2)
		end)

		it("ignores public-slice changes that do not bump the version (health updates)", function()
			setEntry(2, "Hair10", 1)
			local outfit = puppet(2)
			CustomizationOutfitSystem.attachPuppet(state, outfit, 2)
			CustomizationOutfitSystem.frame(state)
			local map = table.clone(publicPlayers())
			local entry = table.clone(map["2"])
			entry.health = 50
			map["2"] = entry
			publicPlayers(map)
			CustomizationOutfitSystem.frame(state)
			expect(#dressed).to.equal(1)
		end)

		it("a returning owner's rig, still current, needs no dress", function()
			setEntry(2, "Hair10", 1)
			local outfit = puppet(2)
			CustomizationOutfitSystem.attachPuppet(state, outfit, 2)
			CustomizationOutfitSystem.frame(state)
			CustomizationOutfitSystem.detachPuppet(state, outfit)
			CustomizationRigOutfitTracker.assign(outfit, 2) -- ReplicationPuppetPool's affinity hit
			CustomizationOutfitSystem.attachPuppet(state, outfit, 2)
			CustomizationOutfitSystem.frame(state)
			expect(#dressed).to.equal(1)
			expect(CustomizationRigOutfitTracker.isDressed(outfit)).to.equal(true)
		end)

		it("a reused rig is redressed for its new owner, taking the old look off", function()
			setEntry(2, "Hair10", 1)
			setEntry(3, "Hair11", 1)
			local outfit = puppet(2)
			CustomizationOutfitSystem.attachPuppet(state, outfit, 2)
			CustomizationOutfitSystem.frame(state)
			CustomizationOutfitSystem.detachPuppet(state, outfit)
			CustomizationRigOutfitTracker.assign(outfit, 3) -- ReplicationPuppetPool handed the spare to someone else
			CustomizationOutfitSystem.attachPuppet(state, outfit, 3)
			CustomizationOutfitSystem.frame(state)
			local ops = dressed[#dressed].ops
			expect(ops[1].kind).to.equal("removeCosmetic")
			expect(lastHair(outfit)).to.equal("Hair11")
		end)

		it("drops a detached puppet's pending job", function()
			setEntry(2, "Hair10", 1)
			local outfit = puppet(2)
			CustomizationOutfitSystem.attachPuppet(state, outfit, 2)
			CustomizationOutfitSystem.detachPuppet(state, outfit)
			CustomizationOutfitSystem.frame(state)
			expect(#dressed).to.equal(0)
		end)
	end)

	describe("mount", function()
		it("creates the CosmeticPieces folder and a live system, and the teardown removes the folder", function()
			local Workspace = game:GetService("Workspace")
			local mounted, unmount = CustomizationOutfitSystem.mount()
			local folder = Workspace:FindFirstChild("CosmeticPieces")
			expect(folder).to.be.ok()
			expect(mounted.pieces).to.be.ok()
			expect(mounted.owner).to.equal(nil)
			unmount()
			expect(folder.Parent).to.equal(nil)
		end)

		it("leaves no subscriptions behind after the teardown", function()
			local mounted, unmount = CustomizationOutfitSystem.mount()
			unmount()
			expect(#mounted.cleanups).to.equal(0)
		end)
	end)
end
