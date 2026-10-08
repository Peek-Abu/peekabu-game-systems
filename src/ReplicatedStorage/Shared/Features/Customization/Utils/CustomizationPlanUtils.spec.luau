--!strict
--[=[
	Unit tests for CustomizationPlanUtils — the PURE resolver that turns an Appearance + the registry into
	a concrete application plan (what to mount where, what to color what). No Instance access, so the
	whole resolution step is testable without a rig.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationPlanUtils = require(ReplicatedStorage.Shared.Features.Customization.Utils.CustomizationPlanUtils)
local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)

return function()
	local function emptyAppearance()
		return { cosmetics = {}, accessories = {}, body = {}, headType = "Uncovered", surfaces = {} }
	end

	local function rgb(r, g, b)
		return { source = "rgb", r = r, g = g, b = b }
	end

	local function findMount(plan, id)
		for _, mount in plan.mounts do
			if mount.id == id then
				return mount
			end
		end
		return nil
	end

	local function findBodyColor(plan, part)
		for _, entry in plan.bodyColors do
			if entry.part == part then
				return entry
			end
		end
		return nil
	end

	describe("build — empty", function()
		it("produces an empty plan for an empty appearance", function()
			local plan = CustomizationPlanUtils.build(emptyAppearance())
			expect(#plan.mounts).to.equal(0)
			expect(#plan.bodyColors).to.equal(0)
		end)
	end)

	describe("build — mounts", function()
		it("resolves a cosmetic selection to its registered socket", function()
			local appearance = emptyAppearance()
			appearance.cosmetics.hair = { id = "Hair2", colors = { rgb(10, 20, 30) } }
			local plan = CustomizationPlanUtils.build(appearance)

			expect(#plan.mounts).to.equal(1)
			local mount = plan.mounts[1]
			expect(mount.category).to.equal("hair")
			expect(mount.id).to.equal("Hair2")
			expect(#mount.sockets).to.equal(1)
			expect(mount.sockets[1]).to.equal("Hair")
			expect(mount.colors[1].r).to.equal(10)
		end)

		it("resolves each accessory slot to its own socket, in slot order", function()
			local appearance = emptyAppearance()
			appearance.accessories = {
				{ id = "WizardHat", colors = { rgb(1, 1, 1) } },
				{ id = "Round Glasses", colors = { rgb(2, 2, 2) } },
			}
			local plan = CustomizationPlanUtils.build(appearance)

			expect(#plan.mounts).to.equal(2)
			expect(findMount(plan, "WizardHat").sockets[1]).to.equal("Head")
			expect(findMount(plan, "Round Glasses").sockets[1]).to.equal("Eyes")
		end)

		-- Regression: colors used to be compacted with table.insert, so a retired dye in an early
		-- channel shifted every later color down a slot — the shell would then paint channel 2's
		-- color onto the part named "Color 1".
		it("keeps colors keyed by CHANNEL, leaving an unresolvable one absent rather than shifting", function()
			local appearance = emptyAppearance()
			appearance.accessories = {
				{ id = "FishingHat", colors = { { source = "dye", id = "chartreuse" }, rgb(9, 9, 9) } },
			}
			local plan = CustomizationPlanUtils.build(appearance)

			local colors = plan.mounts[1].colors
			expect(colors[1]).to.equal(nil) -- the retired dye's channel stays empty...
			expect(colors[2]).to.be.ok() -- ...and channel 2 keeps ITS index
			expect(colors[2].r).to.equal(9)
		end)

		-- Shoes are one cosmetic on two sockets; the plan must carry BOTH, or the shell can only ever
		-- mount half a pair.
		it("carries every socket of a multi-socket cosmetic", function()
			local appearance = emptyAppearance()
			appearance.cosmetics.shoes = { id = "Shoes1", colors = {} }
			local mount = findMount(CustomizationPlanUtils.build(appearance), "Shoes1")

			expect(#mount.sockets).to.equal(2)
			expect(mount.sockets[1]).to.equal("ShoeLeft")
			expect(mount.sockets[2]).to.equal("ShoeRight")
		end)

		-- Fit is tuned per cosmetic (eyebrows and eyelashes sit slightly wrong on this rig). The offset
		-- is stored as plain numbers in the registry and composed here, so the maths is testable and
		-- the shell only applies a finished CFrame.
		it("composes a registry offset into a CFrame, translation and rotation", function()
			local appearance = emptyAppearance()
			appearance.cosmetics.hair = { id = "Hair9", colors = {} }
			local mount = findMount(CustomizationPlanUtils.build(appearance), "Hair9")
			-- Hair9 declares no offset, so it must be absent rather than an identity CFrame: "no
			-- opinion" and "deliberately zero" are different things to a reader of the catalog.
			expect(mount.offset).to.equal(nil)

			local composed = CustomizationPlanUtils.composeOffset({ x = 1, y = 2, z = 3 })
			expect(composed.Position.X).to.equal(1)
			expect(composed.Position.Y).to.equal(2)
			expect(composed.Position.Z).to.equal(3)

			local rotated = CustomizationPlanUtils.composeOffset({ rx = 90 })
			local rx = select(1, rotated:ToEulerAnglesXYZ())
			expect(math.abs(math.deg(rx) - 90) < 0.001).to.equal(true)
		end)

		it("treats an absent offset spec as no offset at all", function()
			expect(CustomizationPlanUtils.composeOffset(nil)).to.equal(nil)
			-- An all-zero spec is still an offset the author wrote down; it just happens to be identity.
			expect(CustomizationPlanUtils.composeOffset({}).Position.Magnitude).to.equal(0)
		end)

		it("skips an unregistered cosmetic rather than erroring (retired ids stay renderable)", function()
			local appearance = emptyAppearance()
			appearance.cosmetics.hair = { id = "HairRetired", colors = {} }
			appearance.accessories = { { id = "NotAThing", colors = {} } }
			local plan = CustomizationPlanUtils.build(appearance)
			expect(#plan.mounts).to.equal(0)
		end)
	end)

	describe("build — head type", function()
		local function partsByName(plan)
			local map = {}
			for _, entry in plan.headParts do
				map[entry.part] = entry.visible
			end
			return map
		end

		it("shows the uncovered face and hides the covered one", function()
			local appearance = emptyAppearance()
			appearance.headType = "Uncovered"
			local parts = partsByName(CustomizationPlanUtils.build(appearance))

			expect(parts["Skin Color-Uncovered"]).to.equal(true)
			expect(parts["Skin Color-Covered"]).to.equal(false)
		end)

		it("inverts every part when covered", function()
			local uncovered = emptyAppearance()
			uncovered.headType = "Uncovered"
			local covered = emptyAppearance()
			covered.headType = "Covered"

			local a = partsByName(CustomizationPlanUtils.build(uncovered))
			local b = partsByName(CustomizationPlanUtils.build(covered))

			-- The two modes are exact complements: every part one shows, the other hides. A part that
			-- ended up visible in BOTH would leave two face meshes overlapping.
			for part, visible in a do
				expect(b[part]).to.equal(not visible)
			end
		end)

		it("emits head parts deterministically for a given head type", function()
			local appearance = emptyAppearance()
			appearance.headType = "Covered"
			local first = CustomizationPlanUtils.build(appearance)
			local second = CustomizationPlanUtils.build(appearance)

			expect(#first.headParts).to.equal(#second.headParts)
			for index, entry in first.headParts do
				expect(second.headParts[index].part).to.equal(entry.part)
				expect(second.headParts[index].visible).to.equal(entry.visible)
			end
		end)

		it("emits no head parts for an unregistered head type (tolerant, like retired ids)", function()
			local appearance = emptyAppearance()
			appearance.headType = "Partial"
			expect(#CustomizationPlanUtils.build(appearance).headParts).to.equal(0)
		end)
	end)

	describe("build — surfaces", function()
		-- Every registered channel is always emitted (see below), so tests address one by its part name.
		local function surfaceFor(plan, part: string)
			for _, surface in plan.surfaces do
				if surface.part == part then
					return surface
				end
			end
			return nil
		end

		it("resolves a channel to its rig part and per-channel art folder", function()
			local appearance = emptyAppearance()
			appearance.surfaces.clothing2 = { pattern = "Skin2", texture = "Fern" }

			local surface = surfaceFor(CustomizationPlanUtils.build(appearance), "Color 2")
			expect(surface).never.to.equal(nil)
			-- clothing1 and clothing2 share a catalog but NOT a folder, and both contain "Skin2" —
			-- carrying the folder per channel is what keeps them from resolving to the same art.
			-- Asserted against the registry rather than a literal folder NAME (the folders were renamed
			-- once already), plus the distinctness that is the actual invariant: a plan that handed both
			-- channels the same folder would pass a name check and still resolve the wrong art.
			expect(surface.artFolder).to.equal(CustomizationCosmeticRegistry.surfaceChannel("clothing2").artFolder)
			local other = surfaceFor(CustomizationPlanUtils.build(appearance), "Color 1")
			expect(other.artFolder).never.to.equal(surface.artFolder)
			expect(surface.pattern).to.equal("Skin2")
			expect(surface.texture).to.equal("Fern")
		end)

		-- The plan is a COMPLETE description of the surface state, not a diff. A cleared channel must
		-- still be emitted (with both aspects nil) so the shell knows to restore the rig's authored
		-- surface — omitting it would leave the previous override stuck on the character until respawn.
		it("emits a reset directive for every registered channel, including unset ones", function()
			local plan = CustomizationPlanUtils.build(emptyAppearance())

			expect(#plan.surfaces).to.equal(#CustomizationCosmeticRegistry.surfaceChannels())
			for _, surface in plan.surfaces do
				expect(surface.pattern).to.equal(nil)
				expect(surface.texture).to.equal(nil)
			end
		end)

		it("emits a reset for a channel cleared back to empty", function()
			local appearance = emptyAppearance()
			appearance.surfaces.clothing1 = {}

			local surface = surfaceFor(CustomizationPlanUtils.build(appearance), "Color 1")
			expect(surface).never.to.equal(nil)
			expect(surface.pattern).to.equal(nil)
			expect(surface.texture).to.equal(nil)
		end)

		it("emits surfaces in registry declaration order", function()
			local appearance = emptyAppearance()
			for _, channel in CustomizationCosmeticRegistry.surfaceChannels() do
				appearance.surfaces[channel.key] = { texture = "Fern" }
			end
			local plan = CustomizationPlanUtils.build(appearance)

			local channels = CustomizationCosmeticRegistry.surfaceChannels()
			expect(#plan.surfaces).to.equal(#channels)
			for index, channel in channels do
				expect(plan.surfaces[index].part).to.equal(channel.part)
			end
		end)
	end)

	describe("build — body colors", function()
		it("resolves a free rgb value to its rig part", function()
			local appearance = emptyAppearance()
			appearance.body.color1 = rgb(200, 100, 50)
			local plan = CustomizationPlanUtils.build(appearance)

			expect(#plan.bodyColors).to.equal(1)
			local entry = plan.bodyColors[1]
			expect(entry.part).to.equal("Color 1")
			expect(entry.color.r).to.equal(200)
			expect(entry.color.g).to.equal(100)
			expect(entry.color.b).to.equal(50)
		end)

		it("resolves a palette dye reference to that dye's concrete color", function()
			local appearance = emptyAppearance()
			appearance.body.skin = { source = "dye", id = "crimson" }
			local plan = CustomizationPlanUtils.build(appearance)

			local expected = CustomizationCosmeticRegistry.dye("crimson").color
			local entry = findBodyColor(plan, "Skin Color")
			expect(entry).to.be.ok()
			expect(entry.color.r).to.equal(expected.r)
			expect(entry.color.g).to.equal(expected.g)
			expect(entry.color.b).to.equal(expected.b)
		end)

		it("skips an unregistered dye and an unregistered channel", function()
			local appearance = emptyAppearance()
			appearance.body.color1 = { source = "dye", id = "chartreuse" }
			appearance.body.elbows = rgb(1, 2, 3)
			local plan = CustomizationPlanUtils.build(appearance)
			expect(#plan.bodyColors).to.equal(0)
		end)

		it("emits body colors in registry declaration order (deterministic, not map order)", function()
			local appearance = emptyAppearance()
			for _, channel in CustomizationCosmeticRegistry.bodyChannels() do
				appearance.body[channel.key] = rgb(1, 2, 3)
			end
			local plan = CustomizationPlanUtils.build(appearance)

			local channels = CustomizationCosmeticRegistry.bodyChannels()
			expect(#plan.bodyColors).to.equal(#channels)
			for index, channel in channels do
				expect(plan.bodyColors[index].part).to.equal(channel.part)
			end
		end)
	end)
end
