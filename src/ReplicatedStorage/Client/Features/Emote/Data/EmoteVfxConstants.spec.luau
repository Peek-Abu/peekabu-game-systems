local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local EmoteVfxConstants = require(script.Parent.EmoteVfxConstants)

return function()
	it("every burst preset passes the burst registry's budget", function()
		for id, preset in EmoteVfxConstants.PRESETS do
			local specId = `spec-{id}`
			if not VfxBurstRegistry.has(specId) then
				VfxBurstRegistry.register(specId, preset)
			end
			expect(VfxBurstRegistry.has(specId)).to.equal(true)
		end
	end)

	it("only the pop (a tier 3 moment) has a light, short and soft", function()
		for id, preset in EmoteVfxConstants.PRESETS do
			if id ~= "emoteBubblePop" then
				expect(preset.light).to.equal(nil)
			end
		end
		local light = EmoteVfxConstants.PRESETS.emoteBubblePop.light
		expect(light).to.be.ok()
		expect(light.seconds <= 0.4).to.equal(true)
	end)

	it("nothing is red (kid-safe) and every texture is set", function()
		for _, preset in EmoteVfxConstants.PRESETS do
			for _, layer in preset.layers do
				expect(string.match(layer.texture, "^rbxassetid://%d+$")).to.be.ok()
				for _, point in layer.color.Keypoints do
					local c = point.Value
					expect(c.R - math.max(c.G, c.B) < 0.25).to.equal(true)
				end
			end
		end
		for _, texture in EmoteVfxConstants.TEXTURES do
			expect(string.match(texture, "^rbxassetid://%d+$")).to.be.ok()
		end
	end)

	it("keeps the wand stream inside the stream budget at every quality", function()
		local stream = EmoteVfxConstants.STREAM
		expect(stream.rateHigh <= 60).to.equal(true)
		expect(stream.rateLow <= 25).to.equal(true)
		expect(stream.rateLow > 0 and stream.rateLow <= stream.rateHigh).to.equal(true)
		expect(stream.rateHigh * stream.lifetime.Max <= 60).to.equal(true)
	end)

	it("keeps the dust ring inside the stream budget, and the tumbleweed to one", function()
		local dust = EmoteVfxConstants.DUST_SWIRL
		expect(dust.rateHigh <= 60 and dust.rateLow <= 25 and dust.rateLow <= dust.rateHigh).to.equal(true)
		expect(dust.rateHigh * dust.lifetime.Max <= 60).to.equal(true)
		expect(dust.turns <= 3).to.equal(true)
		expect(EmoteVfxConstants.PRESETS.emoteTumbleweed.layers[1].count).to.equal(1)
	end)

	it("gives every sound cue a known sound, a delay of zero or more and an optional start inside the file", function()
		for _, cues in EmoteVfxConstants.SOUND_CUES do
			expect(#cues > 0).to.equal(true)
			for _, cue in cues do
				local def = EmoteVfxConstants.SOUNDS[cue.sound]
				expect(def).to.be.ok()
				expect(string.match(def.assetId, "^rbxassetid://%d+$")).to.be.ok()
				expect(def.group).to.equal("SFX")
				expect(def.volume > 0 and def.volume <= 10).to.equal(true) -- the Sound.Volume range: a quiet library file needs a high volume
				expect(cue.after >= 0).to.equal(true)
				expect(cue.start == nil or cue.start >= 0).to.equal(true)
			end
		end
		expect(EmoteVfxConstants.SOUND_FADE > 0 and EmoteVfxConstants.SOUND_FADE <= 0.5).to.equal(true)
	end)

	it("times Cocoa Sip's sip to 1.2 s and Bubble Ride's wobble to the end of the bubble's growth", function()
		local cocoa = EmoteVfxConstants.SOUND_CUES.cocoaSounds
		-- PropsShow is at 0.233 s in the clip; the sip belongs at 1.2 s, as the mug reaches his mouth
		expect(cocoa[1].after).to.equal(0)
		expect(math.abs(0.233 + cocoa[2].after - 1.2) < 0.01).to.equal(true)
		-- the owner: the wobble "at the peak / post inflate", the bloop on the pop
		local grow = EmoteVfxConstants.SOUND_CUES.bubbleGrowSound
		expect(grow[1].sound).to.equal("slideWhistle6")
		expect(grow[1].after).to.equal(0)
		expect(grow[2].after).to.equal(EmoteVfxConstants.GIANT.growSeconds)
		-- the owner: the inflate runs as long as the bubble grows. Slide Whistle 6's sound lasts 0.96 s (measured), so its
		-- speed fits it to growSeconds
		local speed = EmoteVfxConstants.SOUNDS.slideWhistle6.pitch
		expect(speed).to.be.ok()
		expect(math.abs(0.96 / speed.min - EmoteVfxConstants.GIANT.growSeconds) < 0.02).to.equal(true)
		expect(speed.max).to.equal(speed.min)
		expect(EmoteVfxConstants.SOUND_CUES.bubblePopSound[1].after).to.equal(0)
	end)

	it("grows the giant bubble big enough to hold a character, quickly, and never flashes", function()
		local giant = EmoteVfxConstants.GIANT
		expect(giant.growSeconds > 0 and giant.growSeconds <= 1.2).to.equal(true)
		-- at the template's size: the head top with ears is 5.4 studs
		expect(giant.diameter >= 5.4).to.equal(true)
		expect(giant.wobble > 0 and giant.wobble <= 0.06).to.equal(true)
		expect(giant.wobblePeriod >= 1 / 3).to.equal(true) -- no faster than 3 a second
	end)
end
