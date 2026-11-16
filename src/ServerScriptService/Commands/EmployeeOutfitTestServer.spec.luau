--[[
	Unit tests for the employeeoutfittest command: EmployeeOutfitSystem.fit is patched; a temporary outfit Model is put
	under EmployeeConstants.OUTFITS_PATH (made if the test place has no such folder) and removed after.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeOutfitSystem = require(ReplicatedStorage.Shared.Features.Employee.Systems.EmployeeOutfitSystem)
local command = require(ServerScriptService.Commands.EmployeeOutfitTestServer)

return function()
	describe("EmployeeOutfitTestServer", function()
		local originalFit
		local calls = {}
		local fitResult = true
		local made = {}
		local outfit
		local OUTFIT_NAME = "__SpecOutfitTest"

		beforeAll(function()
			originalFit = EmployeeOutfitSystem.fit
			EmployeeOutfitSystem.fit = function(character, model, style)
				table.insert(calls, { character = character, outfit = model, style = style })
				if fitResult then
					-- what a real fit leaves: the outfit's meshes in the Outfit folder, the covered body parts hidden
					local folder = Instance.new("Folder")
					folder.Name = EmployeeConstants.OUTFIT_FOLDER
					for _, name in { "OldJacket", "SS_Coat" } do
						local mesh = Instance.new("Part")
						mesh.Name = name
						mesh.Parent = folder
					end
					folder.Parent = character
					local lower = character:FindFirstChild("LowerTorso")
					if lower then
						lower.Transparency = 1
					end
				end
				return fitResult
			end
			local parent: Instance = ReplicatedStorage
			for _, name in EmployeeConstants.OUTFITS_PATH do
				local child = parent:FindFirstChild(name)
				if child == nil then
					child = Instance.new("Folder")
					child.Name = name
					child.Parent = parent
					table.insert(made, 1, child)
				end
				parent = child
			end
			outfit = Instance.new("Model")
			outfit.Name = OUTFIT_NAME
			outfit:SetAttribute("HideParts", "LowerTorso")
			outfit:SetAttribute("SoloMeshes", "SS_Coat")
			outfit.Parent = parent
		end)

		afterAll(function()
			EmployeeOutfitSystem.fit = originalFit
			outfit:Destroy()
			for _, folder in made do
				folder:Destroy()
			end
		end)

		beforeEach(function()
			calls = {}
			fitResult = true
		end)

		local function player(character)
			return { Name = "TestPlayer", Character = character }
		end

		it("fits the named outfit onto the target's character, in no colour style", function()
			local character = Instance.new("Model")
			local reply = command({ Executor = player(nil) }, OUTFIT_NAME, nil, player(character))
			expect(#calls).to.equal(1)
			expect(calls[1].character).to.equal(character)
			expect(calls[1].outfit).to.equal(outfit)
			expect(calls[1].style).to.equal(nil)
			expect(reply:find("now wears", 1, true)).to.be.ok()
			character:Destroy()
		end)

		it("defaults to the player who ran it", function()
			local character = Instance.new("Model")
			command({ Executor = player(character) }, OUTFIT_NAME, nil, nil)
			expect(calls[1].character).to.equal(character)
			character:Destroy()
		end)

		it("says so when the outfit or the character is missing", function()
			local character = Instance.new("Model")
			expect(
				command({ Executor = player(nil) }, "NoSuchOutfit", nil, player(character)):find("no outfit", 1, true)
			).to.be.ok()
			expect(command({ Executor = player(nil) }, OUTFIT_NAME, nil, player(nil)):find("no character", 1, true)).to.be.ok()
			expect(#calls).to.equal(0)
			character:Destroy()
		end)

		it("solo: shows only the outfit's new pieces on the plain body", function()
			local character = Instance.new("Model")
			local lower = Instance.new("Part")
			lower.Name = "LowerTorso"
			lower.Parent = character
			local reply = command({ Executor = player(nil) }, OUTFIT_NAME, "solo", player(character))
			local folder = character:FindFirstChild(EmployeeConstants.OUTFIT_FOLDER)
			expect(folder.SS_Coat.Transparency).to.equal(0)
			expect(folder.OldJacket.Transparency).to.equal(1)
			expect(lower.Transparency).to.equal(0)
			expect(reply:find("only", 1, true)).to.be.ok()
			character:Destroy()
		end)

		it("solo: says so for an outfit that names no new pieces, and an unknown mode is refused", function()
			outfit:SetAttribute("SoloMeshes", nil)
			local character = Instance.new("Model")
			expect(
				command({ Executor = player(nil) }, OUTFIT_NAME, "solo", player(character)):find("SoloMeshes", 1, true)
			).to.be.ok()
			outfit:SetAttribute("SoloMeshes", "SS_Coat")
			expect(
				command({ Executor = player(nil) }, OUTFIT_NAME, "sideways", player(character)):find(
					"Unknown mode",
					1,
					true
				)
			).to.be.ok()
			character:Destroy()
		end)

		it("passes a refused fit through", function()
			fitResult = false
			local character = Instance.new("Model")
			expect(command({ Executor = player(nil) }, OUTFIT_NAME, nil, player(character)):find("refused", 1, true)).to.be.ok()
			character:Destroy()
		end)
	end)
end
