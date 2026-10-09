local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingConstants = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingConstants)
local SettingRegistry = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingRegistry)
local SettingRules = require(script.Parent.SettingRules)

local SLIDER = { kind = "number", default = 1, min = 0, max = 1, step = 0.05 }

return function()
	beforeAll(function()
		if SettingRegistry.get("spec-mode") == nil then
			SettingRegistry.register("spec-mode", { kind = "choice", default = "off", options = { "off", "on" } })
		end
		if SettingRegistry.get("spec-flag") == nil then
			SettingRegistry.register("spec-flag", { kind = "boolean", default = false })
		end
	end)

	describe("coerce", function()
		it("snaps a number to its step and refuses one out of range", function()
			expect(SettingRules.coerce(SLIDER, 0.52)).to.equal(0.5)
			expect(SettingRules.coerce(SLIDER, 0.53)).to.equal(0.55)
			expect((SettingRules.coerce(SLIDER, 1.2))).to.equal(nil)
			expect((SettingRules.coerce(SLIDER, -0.1))).to.equal(nil)
			expect((SettingRules.coerce(SLIDER, 0 / 0))).to.equal(nil)
			expect((SettingRules.coerce(SLIDER, "0.5"))).to.equal(nil)
		end)

		it("accepts a number as-is without a step", function()
			expect(SettingRules.coerce({ kind = "number", default = 0, min = 0, max = 10 }, 3.3)).to.equal(3.3)
		end)

		it("checks booleans, choices and keybinds", function()
			expect(SettingRules.coerce({ kind = "boolean", default = false }, true)).to.equal(true)
			expect((SettingRules.coerce({ kind = "boolean", default = false }, 1))).to.equal(nil)
			local choice = { kind = "choice", default = "off", options = { "off", "on" } }
			expect(SettingRules.coerce(choice, "on")).to.equal("on")
			expect((SettingRules.coerce(choice, "maybe"))).to.equal(nil)
			local keys = { kind = "keybinds", default = "" }
			expect(SettingRules.coerce(keys, "interact=kb:F")).to.equal("interact=kb:F")
			expect((SettingRules.coerce(keys, "interact=kb:Nope"))).to.equal(nil)
		end)
	end)

	describe("valueOf / store / clear", function()
		it("reads the registered default until a value is stored", function()
			local settings = { values = {} }
			expect(SettingRules.valueOf(settings, "musicVolume")).to.equal(1)
			expect(SettingRules.store(settings, "musicVolume", 0.4)).to.equal(true)
			expect(SettingRules.valueOf(settings, "musicVolume")).to.equal(0.4)
			expect(SettingRules.valueOf(settings, "no-such-setting")).to.equal(nil)
		end)

		it("stores the default as absence, so a changed default reaches the player", function()
			local settings = { values = { musicVolume = 0.4 } }
			expect(SettingRules.store(settings, "musicVolume", 1)).to.equal(true)
			expect(settings.values.musicVolume).to.equal(nil)
			expect(SettingRules.store(settings, "musicVolume", 1)).to.equal(false)
		end)

		it("falls back to the default when a stored value no longer fits its definition", function()
			local settings = { values = { ["spec-mode"] = "retired-option" } }
			expect(SettingRules.valueOf(settings, "spec-mode")).to.equal("off")
		end)

		it("clears one setting or all of them", function()
			local settings = { values = { musicVolume = 0.2, sfxVolume = 0.3 } }
			expect(SettingRules.clear(settings, "musicVolume")).to.equal(true)
			expect(SettingRules.clear(settings, "musicVolume")).to.equal(false)
			expect(SettingRules.clearAll(settings)).to.equal(true)
			expect(next(settings.values)).to.equal(nil)
			expect(SettingRules.clearAll(settings)).to.equal(false)
		end)
	end)

	describe("validate", function()
		it("accepts registered values and unknown (retired) scalar ids", function()
			expect(SettingRules.validate({ values = { musicVolume = 0.5, ["spec-flag"] = true, retired = "x" } })).to.equal(
				true
			)
		end)

		it("rejects a registered id holding an invalid value, non-scalars and too many values", function()
			expect(SettingRules.validate({ values = { musicVolume = 3 } })).to.equal(false)
			expect(SettingRules.validate({ values = { retired = {} } })).to.equal(false)
			expect(SettingRules.validate({ values = "x" })).to.equal(false)
			local many = {}
			for index = 1, SettingConstants.MAX_STORED + 1 do
				many[`k{index}`] = true
			end
			expect(SettingRules.validate({ values = many })).to.equal(false)
		end)
	end)

	describe("requests", function()
		it("round-trips set, reset and resetAll", function()
			local set = SettingRules.parseRequest(SettingRules.buildSet("musicVolume", 0.5))
			expect(set.kind).to.equal("set")
			expect(set.id).to.equal("musicVolume")
			expect(set.value).to.equal(0.5)
			local reset = SettingRules.parseRequest(SettingRules.buildReset("musicVolume"))
			expect(reset.kind).to.equal("reset")
			expect(reset.id).to.equal("musicVolume")
			expect(SettingRules.parseRequest(SettingRules.buildResetAll()).kind).to.equal("resetAll")
		end)

		it("rejects malformed payloads", function()
			expect((SettingRules.parseRequest(nil))).to.equal(nil)
			expect((SettingRules.parseRequest({ kind = "set", id = 5, value = 1 }))).to.equal(nil)
			expect((SettingRules.parseRequest({ kind = "set", id = "x", value = {} }))).to.equal(nil)
			expect((SettingRules.parseRequest({ kind = "explode", id = "x" }))).to.equal(nil)
			expect((SettingRules.parseRequest({ kind = "reset" }))).to.equal(nil)
		end)
	end)
end
