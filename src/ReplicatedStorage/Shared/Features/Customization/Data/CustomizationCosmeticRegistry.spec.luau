--!strict
--[=[
	Unit tests for CustomizationCosmeticRegistry — the customization catalog + channel descriptors.
	Covers: mount-cosmetic lookup (hair/eyebrows/eyelashes/accessory), lockable flags, socket +
	colorChannels metadata, companion wiring, the dye palette, and the body-color channel descriptors.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)

return function()
	describe("mount cosmetics", function()
		it("registers real hair ids (index 2+) and not the None index", function()
			expect(CustomizationCosmeticRegistry.isRegistered("hair", "Hair2")).to.equal(true)
			expect(CustomizationCosmeticRegistry.isRegistered("hair", "Hair11")).to.equal(true)
			-- Hair1 is the "None" option — modeled as id = nil, never a catalog entry.
			expect(CustomizationCosmeticRegistry.isRegistered("hair", "Hair1")).to.equal(false)
		end)

		it("binds hair/eyebrows/eyelashes to their rig sockets", function()
			expect(CustomizationCosmeticRegistry.socketsOf("hair", "Hair2")[1]).to.equal("Hair")
			expect(CustomizationCosmeticRegistry.socketsOf("eyebrows", "Eyebrows2")[1]).to.equal("Eyebrows")
			expect(CustomizationCosmeticRegistry.socketsOf("eyelashes", "Eyelashes2")[1]).to.equal("Eyes")
		end)

		it("carries each accessory's own socket", function()
			expect(CustomizationCosmeticRegistry.socketsOf("accessory", "WizardHat")[1]).to.equal("Head")
			expect(CustomizationCosmeticRegistry.socketsOf("accessory", "Round Glasses")[1]).to.equal("Eyes")
			expect(CustomizationCosmeticRegistry.socketsOf("accessory", "FaceWrap")[1]).to.equal("Mouth")
			expect(CustomizationCosmeticRegistry.socketsOf("accessory", "Poncho 1")[1]).to.equal("Chest")
		end)

		it("returns nil metadata for an unregistered id", function()
			expect(CustomizationCosmeticRegistry.get("accessory", "does-not-exist")).to.equal(nil)
			expect(#CustomizationCosmeticRegistry.socketsOf("accessory", "does-not-exist")).to.equal(0)
			expect(CustomizationCosmeticRegistry.isRegistered("accessory", "does-not-exist")).to.equal(false)
		end)

		it("returns nil for an unknown category", function()
			expect(CustomizationCosmeticRegistry.isRegistered("not-a-category", "WizardHat")).to.equal(false)
			expect(CustomizationCosmeticRegistry.get("not-a-category", "WizardHat")).to.equal(nil)
		end)
	end)

	describe("lockable flags", function()
		it("marks the Locked-folder ids lockable", function()
			expect(CustomizationCosmeticRegistry.isLockable("accessory", "WizardHat")).to.equal(true)
			expect(CustomizationCosmeticRegistry.isLockable("accessory", "WoodMask")).to.equal(true)
			expect(CustomizationCosmeticRegistry.isLockable("accessory", "MagicGoggles")).to.equal(true)
			expect(CustomizationCosmeticRegistry.isLockable("accessory", "Tabard")).to.equal(true)
		end)

		it("marks everything else free (not lockable)", function()
			expect(CustomizationCosmeticRegistry.isLockable("accessory", "FishingHat")).to.equal(false)
			expect(CustomizationCosmeticRegistry.isLockable("hair", "Hair2")).to.equal(false)
		end)

		it("reports an unregistered id as not lockable", function()
			expect(CustomizationCosmeticRegistry.isLockable("accessory", "does-not-exist")).to.equal(false)
		end)
	end)

	describe("color channels", function()
		it("defaults an accessory to one color channel", function()
			expect(CustomizationCosmeticRegistry.colorChannelsOf("accessory", "FishingHat")).to.equal(1)
			expect(CustomizationCosmeticRegistry.colorChannelsOf("hair", "Hair2")).to.equal(1)
		end)

		it("returns nil color channels for an unregistered id", function()
			expect(CustomizationCosmeticRegistry.colorChannelsOf("accessory", "does-not-exist")).to.equal(nil)
		end)

		it("does not register the old split-art 'X 2' pieces as standalone accessories", function()
			expect(CustomizationCosmeticRegistry.isRegistered("accessory", "Cowl 1 2")).to.equal(false)
			expect(CustomizationCosmeticRegistry.isRegistered("accessory", "FaceWrap2")).to.equal(false)
		end)
	end)

	describe("dye palette", function()
		it("registers the starter dyes with in-range colors", function()
			local white = CustomizationCosmeticRegistry.dye("white")
			expect(white).to.be.ok()
			expect(white.color.r).to.equal(255)
			expect(CustomizationCosmeticRegistry.isDyeRegistered("white")).to.equal(true)
		end)

		it("reports an unregistered dye", function()
			expect(CustomizationCosmeticRegistry.dye("chartreuse")).to.equal(nil)
			expect(CustomizationCosmeticRegistry.isDyeRegistered("chartreuse")).to.equal(false)
			expect(CustomizationCosmeticRegistry.isDyeLockable("chartreuse")).to.equal(false)
		end)
	end)

	describe("body-color channels", function()
		it("declares each body channel with a rig part and free-RGB policy", function()
			local color1 = CustomizationCosmeticRegistry.bodyChannel("color1")
			expect(color1).to.be.ok()
			expect(color1.part).to.equal("Color 1")
			expect(color1.allowFreeRgb).to.equal(true)
		end)

		it("exposes all body channels and rejects an unknown key", function()
			expect(#CustomizationCosmeticRegistry.bodyChannels() >= 6).to.equal(true)
			expect(CustomizationCosmeticRegistry.bodyChannel("not-a-channel")).to.equal(nil)
		end)
	end)

	describe("head types", function()
		it("registers the two head types", function()
			expect(CustomizationCosmeticRegistry.isHeadType("Covered")).to.equal(true)
			expect(CustomizationCosmeticRegistry.isHeadType("Uncovered")).to.equal(true)
		end)

		it("rejects an unregistered head type", function()
			expect(CustomizationCosmeticRegistry.isHeadType("Partial")).to.equal(false)
			expect(CustomizationCosmeticRegistry.isHeadType("")).to.equal(false)
		end)

		it("exposes a DEFAULT_HEAD_TYPE that is itself registered", function()
			expect(CustomizationCosmeticRegistry.isHeadType(CustomizationCosmeticRegistry.DEFAULT_HEAD_TYPE)).to.equal(
				true
			)
		end)

		it("lists head types sorted, so callers iterate deterministically", function()
			local list = CustomizationCosmeticRegistry.headTypes()
			expect(#list).to.equal(2)
			expect(list[1]).to.equal("Covered")
			expect(list[2]).to.equal("Uncovered")
		end)
	end)

	-- The 5b content pass's authored data. Asserted so the partition cannot silently regress if the
	-- catalog is edited later.
	describe("hair head-type restrictions", function()
		it("restricts Hair2-Hair8 to Covered", function()
			for i = 2, 8 do
				local entry = CustomizationCosmeticRegistry.get("hair", "Hair" .. i)
				expect(entry).to.be.ok()
				expect(entry.headTypes).to.be.ok()
				expect(entry.headTypes.Covered).to.equal(true)
				expect(entry.headTypes.Uncovered).to.never.equal(true)
			end
		end)

		it("restricts Hair9-Hair11 to Uncovered", function()
			for i = 9, 11 do
				local entry = CustomizationCosmeticRegistry.get("hair", "Hair" .. i)
				expect(entry).to.be.ok()
				expect(entry.headTypes).to.be.ok()
				expect(entry.headTypes.Uncovered).to.equal(true)
				expect(entry.headTypes.Covered).to.never.equal(true)
			end
		end)

		it("leaves eyebrows and eyelashes unrestricted (absent = works with both)", function()
			expect(CustomizationCosmeticRegistry.get("eyebrows", "Eyebrows2").headTypes).to.equal(nil)
			expect(CustomizationCosmeticRegistry.get("eyelashes", "Eyelashes2").headTypes).to.equal(nil)
		end)
	end)

	describe("sockets", function()
		it("reports a single-socket cosmetic as a one-entry list", function()
			local sockets = CustomizationCosmeticRegistry.socketsOf("hair", "Hair9")
			expect(#sockets).to.equal(1)
			expect(sockets[1]).to.equal("Hair")
		end)

		-- Shoes are one cosmetic occupying TWO sockets (the art is a Model of two Accessories, Left and
		-- Right). Two-tone accessories are the same shape — a second piece on its own socket — so one
		-- mechanism covers both rather than shoes being a special case.
		it("reports every socket a multi-socket cosmetic occupies, in declaration order", function()
			local sockets = CustomizationCosmeticRegistry.socketsOf("shoes", "Shoes1")
			expect(#sockets).to.equal(2)
			expect(sockets[1]).to.equal("ShoeLeft")
			expect(sockets[2]).to.equal("ShoeRight")
		end)

		-- REGRESSION: the accessory rows are folded into the catalog field by field, and a declared
		-- field that the fold forgets is silently lost — `sockets` was, so a multi-socket accessory
		-- reported one socket. The type did not catch it either: an unknown field in the row literal
		-- passes typecheck. Asserted through the PUBLIC accessor, on the optional field an accessory
		-- actually uses today, so the fold cannot quietly drop one again.
		it("carries an accessory's optional fields through the row fold", function()
			local occupied = CustomizationCosmeticRegistry.occupiedSocketsOf("accessory", "Cowl 1")
			expect(#occupied).to.equal(2)
			local seen: { [string]: boolean } = {}
			for _, socket in occupied do
				seen[socket] = true
			end
			expect(seen.Head).to.equal(true)
			expect(seen.Chest).to.equal(true)
		end)

		-- MOUNTING and OCCUPANCY are different questions. The cowl is one Accessory bound at `Head`
		-- whose mantle covers the chest: conflating them made the conformance checker demand a piece
		-- whose Handle carries `Chest`, which no such piece exists to satisfy.
		it("separates where a cosmetic MOUNTS from what it RESERVES", function()
			local mounts = CustomizationCosmeticRegistry.socketsOf("accessory", "Cowl 1")
			expect(#mounts).to.equal(1)
			expect(mounts[1]).to.equal("Head")

			local occupied = CustomizationCosmeticRegistry.occupiedSocketsOf("accessory", "Cowl 1")
			expect(#occupied).to.equal(2)
		end)

		it("defaults occupancy to the sockets a cosmetic mounts to", function()
			local occupied = CustomizationCosmeticRegistry.occupiedSocketsOf("shoes", "Shoes1")
			expect(#occupied).to.equal(2)
			expect(occupied[1]).to.equal("ShoeLeft")
			-- A plain accessory reserves exactly its one socket.
			expect(#CustomizationCosmeticRegistry.occupiedSocketsOf("accessory", "FishingHat")).to.equal(1)
		end)

		it("returns an empty list for an unregistered cosmetic", function()
			expect(#CustomizationCosmeticRegistry.socketsOf("hair", "NotAHair")).to.equal(0)
		end)

		it("never hands back the registry's own table (a caller cannot corrupt the catalog)", function()
			local first = CustomizationCosmeticRegistry.socketsOf("shoes", "Shoes1")
			table.remove(first)
			expect(#CustomizationCosmeticRegistry.socketsOf("shoes", "Shoes1")).to.equal(2)
		end)
	end)

	describe("art folders", function()
		it("declares a folder for every catalogued category", function()
			for _, category in { "hair", "eyebrows", "eyelashes", "accessory" } do
				local folder = CustomizationCosmeticRegistry.artFolder(category)
				expect(type(folder)).to.equal("string")
				expect(#folder > 0).to.equal(true)
			end
		end)

		it("returns nil for a category that does not exist", function()
			expect(CustomizationCosmeticRegistry.artFolder("tattoos")).to.equal(nil)
		end)

		-- The whole point of declaring folders: lookup stops being a recursive search of the art root,
		-- so two catalogs may reuse an id without colliding (the clothing1/clothing2 "Skin2" case that
		-- already caused one real bug). Distinct folders are what keeps that safe.
		it("gives each category its own folder", function()
			local seen: { [string]: string } = {}
			for _, category in { "hair", "eyebrows", "eyelashes", "accessory" } do
				local folder = CustomizationCosmeticRegistry.artFolder(category)
				expect(seen[folder]).to.equal(nil)
				seen[folder] = category
			end
		end)
	end)

	describe("ACCESSORY_SLOTS", function()
		it("is a positive integer slot count", function()
			expect(CustomizationCosmeticRegistry.ACCESSORY_SLOTS >= 1).to.equal(true)
			expect(CustomizationCosmeticRegistry.ACCESSORY_SLOTS % 1).to.equal(0)
		end)
	end)
end
