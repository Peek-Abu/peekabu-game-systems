--!strict
--[=[
	Unit tests for CustomizationArtCheck — the art/rig checker.

	Both trees are INJECTED, so every case runs against a fabricated `Customs` folder and a fabricated
	rig; no real art and no real character are involved. That is the same trick
	CustomizationWearRules uses for its head-types lookup, and it is what makes a module that
	inspects Instances testable at all.

	The contract these tests pin down: the checker REPORTS and never throws. A malformed tree is the
	normal case it exists to describe, not an error — art is place-owned and edited outside this repo.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)
local CustomizationArtCheck = require(ReplicatedStorage.Shared.Features.Customization.Rules.CustomizationArtCheck)

return function()
	-- Builds one well-formed cosmetic: Accessory > Handle > Attachment named for its socket.
	local function makeCosmetic(id: string, socket: string): Instance
		local accessory = Instance.new("Accessory")
		accessory.Name = id
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Parent = accessory
		local attachment = Instance.new("Attachment")
		attachment.Name = socket
		attachment.Parent = handle
		return accessory
	end

	-- A Customs tree that satisfies the WHOLE catalog, so a test can then break exactly one thing.
	local function makeCustoms(): Instance
		local customs = Instance.new("Folder")
		customs.Name = "Customs"
		for _, category in CustomizationCosmeticRegistry.categories() do
			local folder = Instance.new("Folder")
			folder.Name = CustomizationCosmeticRegistry.artFolder(category)
			folder.Parent = customs
			for _, id in CustomizationCosmeticRegistry.ids(category) do
				local sockets = CustomizationCosmeticRegistry.socketsOf(category, id)
				if #sockets == 1 then
					makeCosmetic(id, sockets[1]).Parent = folder
				else
					-- A multi-socket cosmetic is authored as a Model of one Accessory per socket.
					local wrapper = Instance.new("Model")
					wrapper.Name = id
					for index, socket in sockets do
						makeCosmetic(`{id}_{index}`, socket).Parent = wrapper
					end
					wrapper.Parent = folder
				end
			end
		end
		return customs
	end

	-- A rig carrying every socket the catalog names, at MIXED depths — the real rig has sockets at
	-- depth 1, 2 and 3, and the checker must find them all.
	local function makeRig(): Instance
		local rig = Instance.new("Model")
		local shallow = Instance.new("Part")
		shallow.Name = "Head"
		shallow.Parent = rig
		local nested = Instance.new("Part")
		nested.Name = "Color 1"
		nested.Parent = shallow

		local seen: { [string]: boolean } = {}
		local flip = false
		for _, category in CustomizationCosmeticRegistry.categories() do
			for _, id in CustomizationCosmeticRegistry.ids(category) do
				for _, socket in CustomizationCosmeticRegistry.socketsOf(category, id) do
					if not seen[socket] then
						seen[socket] = true
						local attachment = Instance.new("Attachment")
						attachment.Name = socket
						-- Alternate depth so neither a shallow-only nor a deep-only search would pass.
						attachment.Parent = if flip then nested else shallow
						flip = not flip
					end
				end
			end
		end
		return rig
	end

	local function problemsFor(issues, id: string): { string }
		local found: { string } = {}
		for _, issue in issues do
			if issue.id == id then
				table.insert(found, issue.problem)
			end
		end
		return found
	end

	describe("check — a well-formed tree", function()
		it("reports no issues", function()
			local issues = CustomizationArtCheck.check(makeCustoms(), makeRig())
			expect(#issues).to.equal(0)
		end)
	end)

	describe("check — art problems", function()
		it("reports a category folder that is missing entirely", function()
			local customs = makeCustoms()
			customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("hair")):Destroy()

			local issues = CustomizationArtCheck.check(customs, makeRig())
			expect(#issues > 0).to.equal(true)
			-- One issue per missing id, so the report is a to-do list rather than a single line.
			local hairIds = CustomizationCosmeticRegistry.ids("hair")
			local count = 0
			for _, issue in issues do
				if issue.category == "hair" then
					count += 1
				end
			end
			expect(count).to.equal(#hairIds)
		end)

		it("reports an id whose art is absent from its folder", function()
			local customs = makeCustoms()
			local id = CustomizationCosmeticRegistry.ids("hair")[1]
			customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("hair")):FindFirstChild(id):Destroy()

			local issues = CustomizationArtCheck.check(customs, makeRig())
			expect(#problemsFor(issues, id)).to.equal(1)
		end)

		it("reports art that is not an Accessory", function()
			local customs = makeCustoms()
			local id = CustomizationCosmeticRegistry.ids("hair")[1]
			local folder = customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("hair"))
			folder:FindFirstChild(id):Destroy()
			local impostor = Instance.new("Model")
			impostor.Name = id
			impostor.Parent = folder

			expect(#problemsFor(CustomizationArtCheck.check(customs, makeRig()), id)).to.equal(1)
		end)

		-- ONE fault, ONE line. A non-BasePart Handle used to also trip the weld-connectivity check on
		-- that same object, adding a misleading "not connected" line and pointing an artist away from
		-- the real cause.
		it("reports a non-BasePart Handle exactly once", function()
			local customs = makeCustoms()
			local id = CustomizationCosmeticRegistry.ids("hair")[1]
			local art = customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("hair")):FindFirstChild(id)
			art:FindFirstChild("Handle"):Destroy()
			local impostor = Instance.new("Folder")
			impostor.Name = "Handle"
			impostor.Parent = art

			expect(#problemsFor(CustomizationArtCheck.check(customs, makeRig()), id)).to.equal(1)
		end)

		it("reports an Accessory with no Handle", function()
			local customs = makeCustoms()
			local id = CustomizationCosmeticRegistry.ids("hair")[1]
			customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("hair")):FindFirstChild(id).Handle:Destroy()

			expect(#problemsFor(CustomizationArtCheck.check(customs, makeRig()), id)).to.equal(1)
		end)

		it("reports a Handle whose Attachment is not named for the socket", function()
			local customs = makeCustoms()
			local id = CustomizationCosmeticRegistry.ids("hair")[1]
			local handle =
				customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("hair")):FindFirstChild(id).Handle
			handle:FindFirstChildOfClass("Attachment").Name = "WrongSocket"

			expect(#problemsFor(CustomizationArtCheck.check(customs, makeRig()), id)).to.equal(1)
		end)
	end)

	describe("check — multi-piece art", function()
		-- Half a pair of shoes: the art exists and one piece is perfectly fine, so a per-piece check
		-- passes while the cosmetic still mounts wrong. Coverage is asserted per SOCKET for that reason.
		it("reports a socket no piece covers, even when the other piece is well-formed", function()
			local customs = makeCustoms()
			local shoes =
				customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("shoes")):FindFirstChild("Shoes1")
			shoes:GetChildren()[1]:Destroy()

			local issues = CustomizationArtCheck.check(customs, makeRig())
			local found = false
			for _, issue in issues do
				if issue.id == "Shoes1" then
					found = true
				end
			end
			expect(found).to.equal(true)
		end)

		-- Mounting is all-or-nothing, so ONE piece targeting no declared socket sinks the whole cosmetic.
		-- Aggregate coverage alone reports clean here: the two real shoe pieces cover both sockets, and
		-- the stray third is invisible to a coverage-only check.
		it("reports a piece that carries none of the cosmetic's sockets", function()
			local customs = makeCustoms()
			local shoes =
				customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("shoes")):FindFirstChild("Shoes1")
			local stray = makeCosmetic("Stray", "NotASocketOfThisCosmetic")
			stray.Parent = shoes

			expect(#problemsFor(CustomizationArtCheck.check(customs, makeRig()), "Shoes1")).to.equal(1)
		end)

		it("reports a Model that contains no Accessory at all", function()
			local customs = makeCustoms()
			local folder = customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("shoes"))
			folder:FindFirstChild("Shoes1"):Destroy()
			local empty = Instance.new("Model")
			empty.Name = "Shoes1"
			empty.Parent = folder

			expect(#problemsFor(CustomizationArtCheck.check(customs, makeRig()), "Shoes1")).to.equal(1)
		end)
	end)

	describe("check — loose parts", function()
		-- Roblox welds only the HANDLE when an Accessory mounts; every other part is the art's own
		-- responsibility. Art with unwelded parts equips "successfully" and then appears half-missing,
		-- because those parts stay at the source model's coordinates while the Handle flies to the
		-- socket. 21 of this catalog's accessories shipped that way, so it is a checked invariant now
		-- rather than something to rediscover per cosmetic.
		it("reports a part that is not joined to its Handle", function()
			local customs = makeCustoms()
			local id = CustomizationCosmeticRegistry.ids("hair")[1]
			local art = customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("hair")):FindFirstChild(id)
			local loose = Instance.new("Part")
			loose.Name = "LooseTrim"
			loose.Parent = art

			expect(#problemsFor(CustomizationArtCheck.check(customs, makeRig()), id)).to.equal(1)
		end)

		-- An ISLAND: two parts welded to each other but not to the Handle. A per-joint check sees both
		-- named in a weld and calls it fine, while at mount they stay behind together.
		it("reports parts welded only to each other, never reaching the Handle", function()
			local customs = makeCustoms()
			local id = CustomizationCosmeticRegistry.ids("hair")[1]
			local art = customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("hair")):FindFirstChild(id)
			local a, b = Instance.new("Part"), Instance.new("Part")
			a.Name, b.Name = "IslandA", "IslandB"
			a.Parent, b.Parent = art, art
			local weld = Instance.new("Weld")
			weld.Part0, weld.Part1 = a, b
			weld.Parent = art

			expect(#problemsFor(CustomizationArtCheck.check(customs, makeRig()), id)).to.equal(1)
		end)

		-- Reachability is transitive and undirected: a part welded to a part that is welded to the
		-- Handle does follow it, and which end of the joint it sits on makes no difference.
		it("accepts a part welded to the Handle THROUGH another part", function()
			local customs = makeCustoms()
			local id = CustomizationCosmeticRegistry.ids("hair")[1]
			local art = customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("hair")):FindFirstChild(id)
			local handle = art:FindFirstChild("Handle")
			local middle, outer = Instance.new("Part"), Instance.new("Part")
			middle.Name, outer.Name = "Middle", "Outer"
			middle.Parent, outer.Parent = art, art
			local first = Instance.new("Weld")
			first.Part0, first.Part1 = handle, middle
			first.Parent = art
			local second = Instance.new("Weld")
			second.Part0, second.Part1 = outer, middle -- reversed on purpose
			second.Parent = art

			expect(#problemsFor(CustomizationArtCheck.check(customs, makeRig()), id)).to.equal(0)
		end)

		it("accepts a part joined by a Weld", function()
			local customs = makeCustoms()
			local id = CustomizationCosmeticRegistry.ids("hair")[1]
			local art = customs:FindFirstChild(CustomizationCosmeticRegistry.artFolder("hair")):FindFirstChild(id)
			local trim = Instance.new("Part")
			trim.Name = "Trim"
			trim.Parent = art
			local weld = Instance.new("Weld")
			weld.Part0 = art:FindFirstChild("Handle")
			weld.Part1 = trim
			weld.Parent = art

			expect(#problemsFor(CustomizationArtCheck.check(customs, makeRig()), id)).to.equal(0)
		end)
	end)

	describe("check — rig problems", function()
		-- The case that motivated the checker: a rig part renamed out from under the registry, which
		-- fails SILENTLY at runtime (the cosmetic simply never appears).
		it("reports a socket the rig does not carry", function()
			local rig = makeRig()
			local socket =
				CustomizationCosmeticRegistry.socketsOf("hair", CustomizationCosmeticRegistry.ids("hair")[1])[1]
			for _, d in rig:GetDescendants() do
				if d:IsA("Attachment") and d.Name == socket then
					d:Destroy()
				end
			end

			local issues = CustomizationArtCheck.check(makeCustoms(), rig)
			expect(#issues > 0).to.equal(true)
		end)
	end)

	describe("check — rig lookup matches mounting", function()
		-- The mounting code ignores attachments inside mounted Accessories, because a cosmetic's own
		-- Handle attachment carries its socket's name. If the checker counted those, it would report a
		-- socket as present that mounting then fails to find — a FALSE PASS, which is worse than no
		-- check at all for a report whose value is being trusted.
		it("does not count a socket that only exists inside a mounted Accessory", function()
			local rig = makeRig()
			local socket =
				CustomizationCosmeticRegistry.socketsOf("hair", CustomizationCosmeticRegistry.ids("hair")[1])[1]
			for _, d in rig:GetDescendants() do
				if d:IsA("Attachment") and d.Name == socket then
					d:Destroy()
				end
			end
			-- A worn cosmetic on the rig carrying that same socket name must not satisfy the check.
			local worn = Instance.new("Accessory")
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Parent = worn
			local attachment = Instance.new("Attachment")
			attachment.Name = socket
			attachment.Parent = handle
			worn.Parent = rig

			local issues = CustomizationArtCheck.check(makeCustoms(), rig)
			local reportedRig = false
			for _, issue in issues do
				if issue.category == "rig" and issue.id == socket then
					reportedRig = true
				end
			end
			expect(reportedRig).to.equal(true)
		end)
	end)

	describe("check — never throws", function()
		it("tolerates a missing Customs root", function()
			local issues = CustomizationArtCheck.check(nil, makeRig())
			expect(#issues > 0).to.equal(true)
		end)

		it("tolerates a missing rig", function()
			local issues = CustomizationArtCheck.check(makeCustoms(), nil)
			expect(#issues > 0).to.equal(true)
		end)

		it("tolerates both being absent", function()
			expect(#CustomizationArtCheck.check(nil, nil) > 0).to.equal(true)
		end)
	end)

	describe("summarize", function()
		it("reports a clean tree as ok with no lines", function()
			local summary = CustomizationArtCheck.summarize(CustomizationArtCheck.check(makeCustoms(), makeRig()))
			expect(summary.ok).to.equal(true)
			expect(summary.total).to.equal(0)
		end)

		it("counts and formats issues for the log", function()
			local summary = CustomizationArtCheck.summarize(CustomizationArtCheck.check(nil, nil))
			expect(summary.ok).to.equal(false)
			expect(summary.total > 0).to.equal(true)
			expect(#summary.lines > 0).to.equal(true)
			expect(type(summary.lines[1])).to.equal("string")
		end)
	end)
end
