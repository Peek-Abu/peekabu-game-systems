local UIPreloadRules = require(script.Parent.UIPreloadRules)

local function folder(name, parent)
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end

local function model(name, parent)
	local made = Instance.new("Model")
	made.Name = name
	made.Parent = parent
	return made
end

-- A CleanupCrew art folder: two characters (Pippa with a skin's own face set), outfits, accessories, badges.
local function art()
	local root = folder("CleanupCrew")
	local characters = folder("Characters", root)
	local pippa = model("Pippa", characters)
	folder("Faces", pippa)
	folder("FacesShowstopper", pippa)
	local cappy = model("Cappy", characters)
	folder("Faces", cappy)
	folder("Outfits", root)
	folder("Accessories", root)
	folder("LanyardBadges", root)
	folder("LockerStage", root)
	return root
end

local function names(batches)
	local out = {}
	for _, batch in batches do
		table.insert(out, batch.name)
	end
	return out
end

return function()
	describe("imageIds", function()
		it("collects every asset id in the lists once, in a stable order", function()
			local ids = UIPreloadRules.imageIds({
				{ "rbxassetid://2", "rbxassetid://1" },
				{ "rbxassetid://3", "rbxassetid://2" },
			})
			expect(#ids).to.equal(3)
			expect(ids[1]).to.equal("rbxassetid://1")
			expect(ids[2]).to.equal("rbxassetid://2")
			expect(ids[3]).to.equal("rbxassetid://3")
		end)

		it("skips empty slots and anything that is not an asset id", function()
			local ids = UIPreloadRules.imageIds({ { "", "hello", "rbxassetid://9" } })
			expect(#ids).to.equal(1)
			expect(ids[1]).to.equal("rbxassetid://9")
		end)
	end)

	describe("batches", function()
		it("loads every character's face sets first, then the images, then the characters, then the rest", function()
			local root = art()
			local batches = UIPreloadRules.batches(root, { "rbxassetid://1" })
			local order = names(batches)
			expect(order[1]).to.equal("faces:Cappy")
			expect(order[2]).to.equal("faces:Pippa")
			expect(order[3]).to.equal("images")
			expect(order[4]).to.equal("character:Cappy")
			expect(order[5]).to.equal("character:Pippa")
			expect(table.find(order, "outfits")).to.be.ok()
			expect(table.find(order, "accessories")).to.be.ok()
			expect(table.find(order, "badges")).to.be.ok()
			-- Anything else in the art folder (a cutscene stage) is not preloaded.
			expect(#order).to.equal(8)
			root:Destroy()
		end)

		it("puts a character's every face set (its skins' too) in its faces batch", function()
			local root = art()
			local batches = UIPreloadRules.batches(root, {})
			local pippa = batches[2]
			expect(pippa.name).to.equal("faces:Pippa")
			expect(#pippa.items).to.equal(2)
			root:Destroy()
		end)

		it("marks faces, images and characters essential and the wardrobe not", function()
			local root = art()
			for _, batch in UIPreloadRules.batches(root, { "rbxassetid://1" }) do
				local wardrobe = batch.name == "outfits" or batch.name == "accessories" or batch.name == "badges"
				expect(batch.essential).to.equal(not wardrobe)
			end
			root:Destroy()
		end)

		it("loads the load screen's own pictures before anything else", function()
			local root = art()
			local batches = UIPreloadRules.batches(root, { "rbxassetid://1" }, { "rbxassetid://7" })
			expect(batches[1].name).to.equal("screen")
			expect(batches[1].items[1]).to.equal("rbxassetid://7")
			expect(batches[1].essential).to.equal(true)
			expect(batches[2].name).to.equal("faces:Cappy")
			root:Destroy()
		end)

		it("leaves out an empty images batch and works with no art folder", function()
			local batches = UIPreloadRules.batches(nil, {})
			expect(#batches).to.equal(0)
			local only = UIPreloadRules.batches(nil, { "rbxassetid://1" })
			expect(#only).to.equal(1)
			expect(only[1].name).to.equal("images")
		end)
	end)

	describe("progress", function()
		it("is the share of essential batches done, clamped", function()
			expect(UIPreloadRules.progress(0, 4)).to.equal(0)
			expect(UIPreloadRules.progress(1, 4)).to.equal(0.25)
			expect(UIPreloadRules.progress(9, 4)).to.equal(1)
		end)

		it("is full when there is nothing essential to load", function()
			expect(UIPreloadRules.progress(0, 0)).to.equal(1)
		end)
	end)

	describe("ready", function()
		it("is ready once every essential batch is done", function()
			expect(UIPreloadRules.ready(3, 3, 0)).to.equal(true)
			expect(UIPreloadRules.ready(2, 3, 0)).to.equal(false)
		end)

		it("is ready anyway once the wait runs out, so a slow asset never blocks the game", function()
			expect(UIPreloadRules.ready(0, 3, UIPreloadRules.ESSENTIAL_TIMEOUT)).to.equal(true)
			expect(UIPreloadRules.ready(0, 3, UIPreloadRules.ESSENTIAL_TIMEOUT - 0.1)).to.equal(false)
		end)
	end)
end
