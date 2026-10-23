local OfficeArtKeyUtils = require(script.Parent.OfficeArtKeyUtils)
local ArtKitRegistry = require(game:GetService("ReplicatedStorage").Shared.Features.Art.Data.ArtKitRegistry)
local Visuals = require(game:GetService("ServerScriptService").Features.Art.Systems.ArtVisualSystem)

return function()
	describe("candidates", function()
		it("is just the default key with no override or room type", function()
			expect(table.concat(OfficeArtKeyUtils.candidates("desk", nil, nil), ",")).to.equal("desk")
		end)
		it("tries the room-type variant before the default", function()
			expect(table.concat(OfficeArtKeyUtils.candidates("floorTile", nil, "server"), ",")).to.equal(
				"floorTile_server,floorTile"
			)
		end)
		it("puts the override first", function()
			expect(table.concat(OfficeArtKeyUtils.candidates("shelf", "serverRack", "server"), ",")).to.equal(
				"serverRack,shelf_server,shelf"
			)
		end)
		it("skips duplicates", function()
			expect(table.concat(OfficeArtKeyUtils.candidates("shelf", "shelf", nil), ",")).to.equal("shelf")
		end)
	end)

	describe("roomType", function()
		it("names the kit type, hallway for corridors, nil otherwise", function()
			expect(OfficeArtKeyUtils.roomType({ roomType = "server", zone = "server" })).to.equal("server")
			expect(OfficeArtKeyUtils.roomType({ roomType = "pods", zone = "hallway" })).to.equal("hallway")
			expect(OfficeArtKeyUtils.roomType({ zone = "hallway" })).to.equal("hallway")
			expect(OfficeArtKeyUtils.roomType({})).to.equal(nil)
			expect(OfficeArtKeyUtils.roomType(nil)).to.equal(nil)
		end)
	end)

	describe("attachFirst", function()
		local assets, art, root
		beforeEach(function()
			assets = Instance.new("Folder")
			art = Visuals.new(assets)
			local model = Instance.new("Model")
			model:SetAttribute("ArtKitId", "test-keys")
			root = Instance.new("Part")
			root.Size = Vector3.new(2, 2, 2)
			root.Parent = model
			local kit = Instance.new("Folder")
			kit.Name = "test-keys"
			kit.Parent = assets
			local group = Instance.new("Folder")
			group.Name = "furniture"
			group.Parent = kit
			for _, key in { "second" } do
				local template = Instance.new("Model")
				template.Name = key
				template:SetAttribute("RuntimeApproved", true)
				template:SetAttribute("BaseSize", Vector3.new(1, 1, 1))
				local body = Instance.new("Part")
				body.Size = Vector3.new(1, 1, 1)
				body.CFrame = CFrame.new(0, 0.5, 0)
				body.Parent = template
				template.WorldPivot = CFrame.identity
				template.Parent = group
			end
		end)
		afterEach(function()
			root.Parent:Destroy()
			assets:Destroy()
		end)
		it("returns the first key that has a template", function()
			local visual, key = OfficeArtKeyUtils.attachFirst(art, root, "furniture", { "first", "second", "third" })
			expect(visual ~= nil).to.equal(true)
			expect(visual.Parent).to.equal(root)
			expect(key).to.equal("second")
		end)
		it("falls back to the default kit when the map's own kit lacks every key", function()
			root.Parent:SetAttribute("ArtKitId", "odd-hours-b1")
			local own = Instance.new("Folder")
			own.Name = "odd-hours-b1"
			own.Parent = assets
			local default = assets["test-keys"]
			default.Name = ArtKitRegistry.DEFAULT_KIT
			local visual, key = OfficeArtKeyUtils.attachFirst(art, root, "furniture", { "first", "second" })
			expect(visual ~= nil).to.equal(true)
			expect(visual:GetAttribute("ArtKitId")).to.equal(ArtKitRegistry.DEFAULT_KIT)
			expect(key).to.equal("second")
		end)
		it("prefers the map's own kit over the default kit", function()
			root.Parent:SetAttribute("ArtKitId", "odd-hours-b1")
			local default = assets["test-keys"]
			default.Name = ArtKitRegistry.DEFAULT_KIT
			local own = default:Clone()
			own.Name = "odd-hours-b1"
			own.Parent = assets
			local visual = OfficeArtKeyUtils.attachFirst(art, root, "furniture", { "second" })
			expect(visual:GetAttribute("ArtKitId")).to.equal("odd-hours-b1")
		end)
		it("returns nil when no key has a template", function()
			local visual, key = OfficeArtKeyUtils.attachFirst(art, root, "furniture", { "first", "third" })
			expect(visual).to.equal(nil)
			expect(key).to.equal(nil)
		end)
	end)
end
