--[[
	Unit tests for the filmlight Cmdr command. The live Lighting's ExposureCompensation is put back after each test.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local FilmConstants = require(ReplicatedStorage.Shared.Features.Film.Data.FilmConstants)
local filmLight = require(ServerScriptService.Commands.FilmLightServer)

local function near(a, b)
	return math.abs(a - b) < 1e-4
end

return function()
	describe("FilmLightServer", function()
		local before

		beforeEach(function()
			before = Lighting.ExposureCompensation
		end)

		afterEach(function()
			filmLight({ Executor = {} }, "normal")
			Lighting.ExposureCompensation = before
		end)

		it("darkens and brightens from the place's own value, and comes back to it", function()
			filmLight({ Executor = {} }, "dark")
			expect(near(Lighting.ExposureCompensation, before + FilmConstants.LIGHT_PRESETS.dark)).to.equal(true)
			filmLight({ Executor = {} }, "bright")
			expect(near(Lighting.ExposureCompensation, before + FilmConstants.LIGHT_PRESETS.bright)).to.equal(true)
			filmLight({ Executor = {} }, "normal")
			expect(near(Lighting.ExposureCompensation, before)).to.equal(true)
		end)

		it("refuses an unknown preset and changes nothing", function()
			local message = filmLight({ Executor = {} }, "purple")
			expect(message:find("normal")).to.be.ok()
			expect(Lighting.ExposureCompensation).to.equal(before)
		end)
	end)
end
