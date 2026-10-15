local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Load = require(script.Parent.CargoLoadSystem)
local Claims = require(ServerScriptService.Features.Cargo.State.CargoClaimTracker)
local Constants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local Interaction = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
return function()
	local office, parent, truck, bed, part, player, claims, system, deps, credited, announced, accepted
	beforeEach(function()
		office = Instance.new("Model")
		parent = Instance.new("Folder")
		parent.Name = "ShiftSpawns"
		parent.Parent = office
		truck = Instance.new("Folder")
		truck.Name = "Truck"
		truck.Parent = office
		bed = Instance.new("Part")
		bed.Name = "TruckBed"
		bed.Size = Vector3.new(12, 3, 16)
		bed.CFrame = CFrame.new(0, 1.5, 0)
		bed:SetAttribute(Interaction.KIND_ATTRIBUTE, Constants.LOAD_KIND)
		bed.Parent = truck
		part = Instance.new("Part")
		part.Size = Vector3.new(2, 4, 2)
		part.CFrame = CFrame.new(0, 5, 0)
		part.Parent = parent
		player = { UserId = 9017, Name = "CargoSpecPlayer", DisplayName = "Cargo Spec" }
		claims = Claims.new()
		credited, announced, accepted = 0, 0, true
		deps = {
			claims = claims,
			entryOf = function()
				return { kind = "recyclingBox", value = 20 }
			end,
			idOf = function()
				return 17
			end,
			handler = function()
				return function(_player, deposit)
					if not accepted then
						return false
					end
					credited += deposit.clearance
					return true, deposit.bonus
				end
			end,
			container = function()
				return parent
			end,
			isPresent = function()
				return true
			end,
			getCarried = function()
				return nil
			end,
			forceDrop = function()
				error("automatic deposit must not drop another carried item")
			end,
			pockets = {
				list = function()
					return {}
				end,
				take = function()
					error("automatic deposit must not take pockets")
				end,
			},
			announce = function(_deposit, _from, _bed, _credited, banker)
				announced += 1
				expect(banker).to.equal(player)
			end,
		}
		system = Load.new(deps)
	end)
	afterEach(function()
		office:Destroy()
	end)
	describe("settled automatic banking", function()
		it("claims, credits and removes a physically landed item once", function()
			expect(system:landed(player, part, bed)).to.equal(true)
			expect(credited).to.equal(20)
			expect(announced).to.equal(1)
			expect(part.Parent).to.equal(nil)
			expect(claims:isClaimed(17)).to.equal(true)
			expect(system:landed(player, part, bed)).to.equal(false)
			expect(credited).to.equal(20)
		end)
		it("keeps a refused item and releases its claim for a later legitimate load", function()
			accepted = false
			expect(system:landed(player, part, bed)).to.equal(false)
			expect(part.Parent).to.equal(parent)
			expect(claims:isClaimed(17)).to.equal(false)
			expect(announced).to.equal(0)
			accepted = true
			expect(system:landed(player, part, bed)).to.equal(true)
		end)
		it("refuses a departed placer and releases claims when the authoritative handler throws", function()
			deps.isPresent = function()
				return false
			end
			expect(system:landed(player, part, bed)).to.equal(false)
			expect(claims:isClaimed(17)).to.equal(false)
			deps.isPresent = function()
				return true
			end
			deps.handler = function()
				return function()
					error("test banking failure")
				end
			end
			expect(system:landed(player, part, bed)).to.equal(false)
			expect(claims:isClaimed(17)).to.equal(false)
			expect(part.Parent).to.equal(parent)
		end)
		it("never consumes a newly carried item or pockets when a prior throw lands", function()
			deps.getCarried = function()
				error("automatic deposit must not inspect hands")
			end
			expect(system:landed(player, part, bed)).to.equal(true)
		end)
		it("keeps recycling identity when a truck deposit is refused", function()
			bed.Name = "TruckBed"
			accepted = false
			expect(system:settled(player, part)).to.equal(true)
			expect(part.Parent).to.equal(parent)
			expect(credited).to.equal(0)
		end)
		it("still supports explicit Load of hands and pockets without double consumption", function()
			local character = Instance.new("Model")
			character.Parent = parent
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = Vector3.new(0, 5, 0)
			root.Parent = character
			player.Character = character
			local dropped, taken = 0, 0
			deps.getCarried = function()
				return part
			end
			deps.forceDrop = function()
				dropped += 1
			end
			deps.pockets = {
				list = function()
					return { { kind = "plaque", value = 25 } }
				end,
				take = function()
					taken += 1
				end,
			}
			expect(system:load(player, bed)).to.equal(true)
			expect(credited).to.equal(20)
			expect(dropped).to.equal(1)
			expect(taken).to.equal(1)
			expect(part.Parent).to.equal(nil)
		end)
		it("never banks a thrown object overhead or cargo beside the bed", function()
			part.Position = Vector3.new(0, 12, 0)
			expect(system:landed(player, part, bed)).to.equal(false)
			part.Position = Vector3.new(9, 5, 0)
			expect(system:landed(player, part, bed)).to.equal(false)
			expect(credited).to.equal(0)
		end)
		it("resolves the current truck as a sibling of ShiftSpawns and credits a settled drop", function()
			expect(bed:IsDescendantOf(parent)).to.equal(false)
			expect(system:settled(player, part)).to.equal(true)
			expect(credited).to.equal(20)
			expect(part.Parent).to.equal(nil)
		end)
		it("rejects a stale truck from another generated office even with identical geometry and load kind", function()
			local stale = bed:Clone()
			local staleOffice = Instance.new("Model")
			stale.Parent = staleOffice
			expect(system:landed(player, part, stale)).to.equal(false)
			expect(credited).to.equal(0)
			expect(part.Parent).to.equal(parent)
			staleOffice:Destroy()
		end)
		it("does not resolve a fake Load bed inserted under the cargo folder", function()
			local fake = bed:Clone()
			fake.Parent = parent
			bed.Name = "MissingTruckBed"
			expect(system:settled(player, part)).to.equal(false)
			expect(system:landed(player, part, fake)).to.equal(false)
			expect(credited).to.equal(0)
		end)
		it("refuses a foreign item or a fake truck zone", function()
			bed:SetAttribute(Interaction.KIND_ATTRIBUTE, "carry")
			expect(system:landed(player, part, bed)).to.equal(false)
			bed:SetAttribute(Interaction.KIND_ATTRIBUTE, Constants.LOAD_KIND)
			part.Parent = nil
			expect(system:landed(player, part, bed)).to.equal(false)
			expect(credited).to.equal(0)
		end)
	end)
end
