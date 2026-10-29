local EmoteEffectSystem = require(script.Parent.EmoteEffectSystem)

return function()
	local RIDE = "rbxassetid://111"
	local OTHER = "rbxassetid://333"
	local ENTRIES = {
		["emote:Ride"] = {
			effects = {
				{ id = "stream", on = "Blow", off = "BlowEnd" },
				{ id = "bubble", on = "Grow", off = "Pop" },
				{ id = "land", on = "Land" },
				{ id = "face", on = "Face" },
			},
		},
	}

	local function connectList(list, callback)
		table.insert(list, callback)
		return function()
			local index = table.find(list, callback)
			if index ~= nil then
				table.remove(list, index)
			end
		end
	end

	local function fakeTrack(assetId)
		local fake = { playing = true, markers = {}, stopped = {} }
		fake.track = {
			assetId = assetId,
			timePosition = function()
				return 0
			end,
			isPlaying = function()
				return fake.playing
			end,
			timeOfKeyframe = function()
				return nil
			end,
			onMarker = function(name, callback)
				fake.markers[name] = fake.markers[name] or {}
				return connectList(fake.markers[name], callback)
			end,
			onStopped = function(callback)
				return connectList(fake.stopped, callback)
			end,
		}
		function fake.fire(name, value)
			for _, callback in table.clone(fake.markers[name] or {}) do
				callback(value or "")
			end
		end
		function fake.stop()
			fake.playing = false
			for _, callback in table.clone(fake.stopped) do
				callback()
			end
		end
		function fake.listeners()
			local count = #fake.stopped
			for _, list in fake.markers do
				count += #list
			end
			return count
		end
		return fake
	end

	local function fakeSource()
		local source = { tracks = {}, played = {} }
		source.api = {
			playing = function()
				local out = {}
				for _, fake in source.tracks do
					table.insert(out, fake.track)
				end
				return out
			end,
			onPlayed = function(callback)
				return connectList(source.played, callback)
			end,
		}
		function source.play(fake)
			table.insert(source.tracks, fake)
			for _, callback in table.clone(source.played) do
				callback(fake.track)
			end
		end
		return source
	end

	-- A system whose effects only log: "start <id> <value>" and "end <id>".
	local function system(source)
		local log = {}
		local props = EmoteEffectSystem.new({
			sourceOf = function()
				return source.api
			end,
			keyForAsset = function(assetId)
				return if assetId == RIDE then "emote:Ride" else nil
			end,
			entryFor = function(key)
				return ENTRIES[key]
			end,
			start = function(id, _character, value)
				table.insert(log, `start {id} {value}`)
				return function()
					table.insert(log, `end {id}`)
				end
			end,
		})
		return props, log
	end

	local function setup()
		local model = Instance.new("Model")
		local source = fakeSource()
		local effects, log = system(source)
		local release = effects.track(model)
		return model, source, effects, log, release
	end

	describe("markers", function()
		it("starts an effect on its marker with the marker's value and ends it on its off marker", function()
			local model, source, effects, log, release = setup()
			local fake = fakeTrack(RIDE)
			source.play(fake)
			fake.fire("Blow")
			expect(effects.getState().running).to.equal(1)
			fake.fire("BlowEnd")
			fake.fire("Face", "Puffed")
			expect(table.concat(log, "|")).to.equal("start stream |end stream|start face Puffed")
			release()
			model:Destroy()
		end)

		it("ends the running copy before a second start of the same effect (a new face replaces the old)", function()
			local model, source, _, log, release = setup()
			local fake = fakeTrack(RIDE)
			source.play(fake)
			fake.fire("Face", "Puffed")
			fake.fire("Face", "Delighted")
			expect(table.concat(log, "|")).to.equal("start face Puffed|end face|start face Delighted")
			release()
			model:Destroy()
		end)

		it("ignores a clip with no effects", function()
			local model, source, effects, log, release = setup()
			local fake = fakeTrack(OTHER)
			source.play(fake)
			expect(fake.listeners()).to.equal(0)
			expect(#log).to.equal(0)
			expect(effects.getState().running).to.equal(0)
			release()
			model:Destroy()
		end)

		it("ignores an off marker for an effect that is not running", function()
			local model, source, _, log, release = setup()
			local fake = fakeTrack(RIDE)
			source.play(fake)
			fake.fire("Pop")
			expect(#log).to.equal(0)
			release()
			model:Destroy()
		end)
	end)

	describe("safe end", function()
		it("ends every running effect when the clip stops early (cancel, knockdown, hiding)", function()
			local model, source, effects, log, release = setup()
			local fake = fakeTrack(RIDE)
			source.play(fake)
			fake.fire("Grow")
			fake.fire("Face", "Delighted")
			fake.stop()
			expect(effects.getState().running).to.equal(0)
			expect(table.find(log, "end bubble")).to.be.ok()
			expect(table.find(log, "end face")).to.be.ok()
			expect(fake.listeners()).to.equal(0)
			release()
			model:Destroy()
		end)

		it(
			"ends the old clip's effects when a newer effect clip takes over, and the old stop changes nothing",
			function()
				local model, source, effects, log, release = setup()
				local first = fakeTrack(RIDE)
				source.play(first)
				first.fire("Grow")
				local second = fakeTrack(RIDE)
				source.play(second)
				expect(table.find(log, "end bubble")).to.be.ok()
				second.fire("Blow")
				first.stop()
				expect(effects.getState().running).to.equal(1)
				release()
				model:Destroy()
			end
		)

		it("ends everything and disconnects on release, and a second release does nothing", function()
			local model, source, effects, log, release = setup()
			local fake = fakeTrack(RIDE)
			source.play(fake)
			fake.fire("Grow")
			release()
			release()
			expect(#log).to.equal(2)
			expect(fake.listeners()).to.equal(0)
			expect(#source.played).to.equal(0)
			expect(effects.getState().running).to.equal(0)
			expect(effects.getState().tracked).to.equal(0)
			model:Destroy()
		end)

		it("keeps going when an effect's start fails (a missing part) and still ends the others", function()
			local model = Instance.new("Model")
			local source = fakeSource()
			local log = {}
			local effects = EmoteEffectSystem.new({
				sourceOf = function()
					return source.api
				end,
				keyForAsset = function()
					return "emote:Ride"
				end,
				entryFor = function(key)
					return ENTRIES[key]
				end,
				start = function(id)
					if id == "bubble" then
						error("no LowerTorso")
					end
					table.insert(log, id)
					return function()
						table.insert(log, "end " .. id)
					end
				end,
			})
			local release = effects.track(model)
			local fake = fakeTrack(RIDE)
			source.play(fake)
			fake.fire("Grow")
			fake.fire("Blow")
			fake.stop()
			expect(table.concat(log, "|")).to.equal("stream|end stream")
			release()
			model:Destroy()
		end)
	end)

	describe("tracks already playing", function()
		it("binds a clip that was playing before the watch began", function()
			local model = Instance.new("Model")
			local source = fakeSource()
			local fake = fakeTrack(RIDE)
			table.insert(source.tracks, fake)
			local effects, log = system(source)
			local release = effects.track(model)
			fake.fire("Land")
			expect(log[1]).to.equal("start land ")
			release()
			model:Destroy()
		end)
	end)
end
