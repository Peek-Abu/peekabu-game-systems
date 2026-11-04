local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmoteConstants = require(ReplicatedStorage.Shared.Features.Emote.Data.EmoteConstants)
local EmotePropSystem = require(script.Parent.EmotePropSystem)

return function()
	local SHOW, STOW = EmoteConstants.PROPS_SHOW, EmoteConstants.PROPS_STOW
	local BUBBLES = "rbxassetid://111"
	local LASSO = "rbxassetid://222"
	local OTHER = "rbxassetid://333"
	local IDLE = "rbxassetid://444"
	local KEYS = { [BUBBLES] = "emote:Pippa.Bubbles", [LASSO] = "emote:Prickles.Lasso", [IDLE] = "pricklessheriffidle" }

	local function makeCharacter()
		local model = Instance.new("Model")
		local folder = Instance.new("Folder")
		folder.Name = EmployeeConstants.PROPS_FOLDER
		folder.Parent = model
		local holster = Instance.new("Folder")
		holster.Name = EmployeeConstants.HOLSTER_FOLDER
		holster.Parent = model
		local parts, worn = {}, {}
		for _, name in { "BubbleWand", "DuckRing", "HoseLasso" } do
			local part = Instance.new("Part")
			part.Name = name
			part.Transparency = 1
			part.Parent = folder
			parts[name] = part
			local twin = Instance.new("Part")
			twin.Name = name
			twin.Transparency = 0
			twin.Parent = holster
			worn[name] = twin
		end
		local loop = Instance.new("Part")
		loop.Name = "LassoLoop"
		loop.Transparency = 1
		loop.Parent = folder
		parts.LassoLoop = loop
		return model, parts, worn
	end

	local function connectList(list, callback)
		table.insert(list, callback)
		return function()
			local index = table.find(list, callback)
			if index ~= nil then
				table.remove(list, index)
			end
		end
	end

	-- A stand-in for a playing AnimationTrack: markers fire on `fire`, `stop` ends it.
	local function fakeTrack(assetId, time, keyframes)
		local fake = { time = time or 0, playing = true, markers = {}, stopped = {} }
		local frames = keyframes or { [SHOW] = 0.13, [STOW] = 3.83 }
		fake.track = {
			assetId = assetId,
			timePosition = function()
				return fake.time
			end,
			isPlaying = function()
				return fake.playing
			end,
			timeOfKeyframe = function(name)
				return frames[name]
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

	local function fakeSource(initial)
		local source = { tracks = initial or {}, played = {} }
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

	local function system(source, templates)
		return EmotePropSystem.new({
			sourceOf = function()
				return source.api
			end,
			keyForAsset = function(assetId)
				return KEYS[assetId]
			end,
			templateOf = function(name)
				return if templates ~= nil then templates[name] else nil
			end,
		})
	end

	-- A character in a skin without the emote's props: just a RightHand (and its Animator, faked).
	local function bareCharacter()
		local model = Instance.new("Model")
		local hand = Instance.new("Part")
		hand.Name = "RightHand"
		hand.Anchored = true
		hand.Parent = model
		return model
	end

	-- The emote's own prop templates: a part on a Motor6D from the right hand.
	local function makeTemplates(names)
		local templates = {}
		for _, name in names do
			local part = Instance.new("Part")
			part.Name = name
			part.Size = Vector3.new(1, 1, 1)
			local joint = Instance.new("Motor6D")
			joint.Name = name
			joint.C0 = CFrame.new(0, 0.5, 0)
			joint:SetAttribute(EmployeeConstants.PROP_HAND_ATTRIBUTE, "RightHand")
			joint.Part1 = part
			joint.Parent = part
			templates[name] = part
		end
		return templates
	end

	local function mounted(model, name)
		local folder = model:FindFirstChild(EmployeeConstants.EMOTE_MOUNTED_FOLDER)
		return if folder ~= nil then folder:FindFirstChild(name) else nil
	end

	describe("markers", function()
		it("shows only the clip's props on PropsShow and hides them on PropsStow", function()
			local model, parts = makeCharacter()
			local source = fakeSource()
			local props = system(source)
			local release = props.track(model)
			local fake = fakeTrack(BUBBLES)
			source.play(fake)
			expect(parts.BubbleWand.Transparency).to.equal(1)
			fake.fire(SHOW)
			expect(parts.BubbleWand.Transparency).to.equal(0)
			-- Bubble Ride keeps the duck ring worn: the clip never brings it out
			expect(parts.DuckRing.Transparency).to.equal(1)
			expect(parts.HoseLasso.Transparency).to.equal(1)
			fake.fire(STOW)
			expect(parts.BubbleWand.Transparency).to.equal(1)
			release()
			model:Destroy()
		end)

		it("ignores a clip with no entry", function()
			local model, parts = makeCharacter()
			local source = fakeSource()
			local props = system(source)
			local release = props.track(model)
			local fake = fakeTrack(OTHER)
			source.play(fake)
			fake.fire(SHOW)
			for _, part in parts do
				expect(part.Transparency).to.equal(1)
			end
			expect(fake.listeners()).to.equal(0)
			release()
			model:Destroy()
		end)
	end)

	describe("safe stow", function()
		it("hides the props when the track stops (finish, cancel or server stop)", function()
			local model, parts = makeCharacter()
			local source = fakeSource()
			local props = system(source)
			local release = props.track(model)
			local fake = fakeTrack(BUBBLES)
			source.play(fake)
			fake.fire(SHOW)
			fake.stop()
			expect(parts.BubbleWand.Transparency).to.equal(1)
			expect(fake.listeners()).to.equal(0)
			release()
			model:Destroy()
		end)

		it("hands the props to a replacing prop clip, and the old one's stop no longer hides them", function()
			local model, parts = makeCharacter()
			local source = fakeSource()
			local props = system(source)
			local release = props.track(model)
			local first = fakeTrack(BUBBLES)
			source.play(first)
			first.fire(SHOW)
			local second = fakeTrack(LASSO)
			source.play(second)
			expect(parts.BubbleWand.Transparency).to.equal(1)
			second.fire(SHOW)
			first.stop()
			expect(parts.HoseLasso.Transparency).to.equal(0)
			expect(parts.BubbleWand.Transparency).to.equal(1)
			release()
			model:Destroy()
		end)

		it("hides the props and disconnects on release", function()
			local model, parts = makeCharacter()
			local source = fakeSource()
			local props = system(source)
			local release = props.track(model)
			local fake = fakeTrack(BUBBLES)
			source.play(fake)
			fake.fire(SHOW)
			release()
			expect(parts.BubbleWand.Transparency).to.equal(1)
			expect(fake.listeners()).to.equal(0)
			expect(#source.played).to.equal(0)
			expect(props.getState().tracked).to.equal(0)
			model:Destroy()
		end)

		it("raises nothing when the character is destroyed mid-show", function()
			local model = makeCharacter()
			local source = fakeSource()
			local props = system(source)
			local release = props.track(model)
			local fake = fakeTrack(BUBBLES)
			source.play(fake)
			fake.fire(SHOW)
			model:Destroy()
			expect(function()
				fake.fire(STOW)
				fake.stop()
				release()
			end).never.to.throw()
		end)
	end)

	describe("worn props", function()
		it("hides the clip's worn twins while its hand props show, and wears them again on stow", function()
			local model, parts, worn = makeCharacter()
			local source = fakeSource()
			local props = system(source)
			local release = props.track(model)
			local fake = fakeTrack(LASSO)
			source.play(fake)
			expect(worn.HoseLasso.Transparency).to.equal(0)
			fake.fire(SHOW)
			expect(worn.HoseLasso.Transparency).to.equal(1)
			-- another skin's or another clip's worn props stay worn
			expect(worn.DuckRing.Transparency).to.equal(0)
			expect(worn.BubbleWand.Transparency).to.equal(0)
			fake.fire(STOW)
			expect(worn.HoseLasso.Transparency).to.equal(0)
			expect(parts.HoseLasso.Transparency).to.equal(1)
			release()
			model:Destroy()
		end)

		it("wears them again when the track stops early or the watch is released", function()
			for _, ending in { "stop", "release" } do
				local model, _, worn = makeCharacter()
				local source = fakeSource()
				local props = system(source)
				local release = props.track(model)
				local fake = fakeTrack(LASSO)
				source.play(fake)
				fake.fire(SHOW)
				expect(worn.HoseLasso.Transparency).to.equal(1)
				if ending == "stop" then
					fake.stop()
				end
				release()
				expect(worn.HoseLasso.Transparency).to.equal(0)
				model:Destroy()
			end
		end)

		it("hides a worn twin that arrives while its clip shows (a refit mid-emote)", function()
			local model, _, worn = makeCharacter()
			worn.HoseLasso.Parent = nil
			local source = fakeSource({ fakeTrack(LASSO, 2.0) })
			local props = system(source)
			local release = props.track(model)
			worn.HoseLasso.Parent = model:FindFirstChild(EmployeeConstants.HOLSTER_FOLDER)
			task.wait() -- DescendantAdded is deferred
			expect(worn.HoseLasso.Transparency).to.equal(1)
			release()
			model:Destroy()
		end)
	end)

	describe("swapped props", function()
		it("swaps the hand props on PropHide / PropShow and keeps the worn twin hidden all through", function()
			local model, parts, worn = makeCharacter()
			local source = fakeSource()
			local props = system(source)
			local release = props.track(model)
			local fake = fakeTrack(LASSO)
			source.play(fake)
			fake.fire(SHOW)
			expect(parts.HoseLasso.Transparency).to.equal(0)
			expect(parts.LassoLoop.Transparency).to.equal(1)
			fake.fire(EmoteConstants.PROP_HIDE, "HoseLasso")
			fake.fire(EmoteConstants.PROP_SHOW, "LassoLoop")
			expect(parts.HoseLasso.Transparency).to.equal(1)
			expect(parts.LassoLoop.Transparency).to.equal(0)
			expect(worn.HoseLasso.Transparency).to.equal(1)
			fake.fire(EmoteConstants.PROP_HIDE, "LassoLoop")
			fake.fire(EmoteConstants.PROP_SHOW, "HoseLasso")
			expect(parts.HoseLasso.Transparency).to.equal(0)
			expect(parts.LassoLoop.Transparency).to.equal(1)
			fake.fire(STOW)
			expect(parts.HoseLasso.Transparency).to.equal(1)
			expect(worn.HoseLasso.Transparency).to.equal(0)
			release()
			model:Destroy()
		end)

		it("hides a swapped-in prop when the clip stops early, and the next play starts clean", function()
			local model, parts, worn = makeCharacter()
			local source = fakeSource()
			local props = system(source)
			local release = props.track(model)
			local first = fakeTrack(LASSO)
			source.play(first)
			first.fire(SHOW)
			first.fire(EmoteConstants.PROP_HIDE, "HoseLasso")
			first.fire(EmoteConstants.PROP_SHOW, "LassoLoop")
			first.stop()
			expect(parts.LassoLoop.Transparency).to.equal(1)
			expect(worn.HoseLasso.Transparency).to.equal(0)
			local second = fakeTrack(LASSO)
			source.play(second)
			second.fire(SHOW)
			expect(parts.HoseLasso.Transparency).to.equal(0)
			expect(parts.LassoLoop.Transparency).to.equal(1)
			release()
			model:Destroy()
		end)

		it("ignores a swap marker naming a prop its clip does not own", function()
			local model, parts = makeCharacter()
			local source = fakeSource()
			local props = system(source)
			local release = props.track(model)
			local fake = fakeTrack(LASSO)
			source.play(fake)
			fake.fire(SHOW)
			fake.fire(EmoteConstants.PROP_SHOW, "BubbleWand")
			expect(parts.BubbleWand.Transparency).to.equal(1)
			release()
			model:Destroy()
		end)
	end)

	describe("late resync", function()
		it("shows the props at once when bound inside the show window", function()
			local model, parts = makeCharacter()
			local source = fakeSource({ fakeTrack(BUBBLES, 2.0) })
			local props = system(source)
			local release = props.track(model)
			expect(parts.BubbleWand.Transparency).to.equal(0)
			release()
			model:Destroy()
		end)

		it("keeps them hidden when bound before the show or after the stow", function()
			for _, time in { 0.05, 3.9 } do
				local model, parts = makeCharacter()
				local source = fakeSource({ fakeTrack(BUBBLES, time) })
				local props = system(source)
				local release = props.track(model)
				expect(parts.BubbleWand.Transparency).to.equal(1)
				release()
				model:Destroy()
			end
		end)

		it("shows a showcase loop with a PropsShow at 0 and no stow at once", function()
			local model, parts = makeCharacter()
			local source = fakeSource()
			local props = system(source)
			local release = props.track(model)
			source.play(fakeTrack(LASSO, 0, { [SHOW] = 0 }))
			expect(parts.HoseLasso.Transparency).to.equal(0)
			release()
			model:Destroy()
		end)

		it("shows a prop that arrives while its clip shows", function()
			local model, parts = makeCharacter()
			parts.BubbleWand.Parent = nil
			local source = fakeSource({ fakeTrack(BUBBLES, 2.0) })
			local props = system(source)
			local release = props.track(model)
			parts.BubbleWand.Parent = model:FindFirstChild(EmployeeConstants.PROPS_FOLDER)
			task.wait() -- DescendantAdded is deferred
			expect(parts.BubbleWand.Transparency).to.equal(0)
			release()
			model:Destroy()
		end)
	end)
	describe("the emote's own props (any skin)", function()
		it(
			"mounts the emote's prop when the skin has none, shows it in the window and removes it when the track stops",
			function()
				local model = bareCharacter()
				local source = fakeSource()
				local props = system(source, makeTemplates({ "BubbleWand" }))
				local release = props.track(model)
				local fake = fakeTrack(BUBBLES)
				source.play(fake)
				local wand = mounted(model, "BubbleWand")
				expect(wand).to.be.ok()
				expect(wand.Transparency).to.equal(1)
				local joint = wand:FindFirstChildOfClass("Motor6D")
				expect(joint.Part0).to.equal(model.RightHand)
				fake.fire(SHOW)
				expect(wand.Transparency).to.equal(0)
				fake.stop()
				expect(mounted(model, "BubbleWand")).never.to.be.ok()
				release()
				model:Destroy()
			end
		)

		it("uses the skin's own prop when it has one and mounts nothing", function()
			local model, parts = makeCharacter()
			local hand = Instance.new("Part")
			hand.Name = "RightHand"
			hand.Parent = model
			local source = fakeSource()
			local props = system(source, makeTemplates({ "BubbleWand" }))
			local release = props.track(model)
			local fake = fakeTrack(BUBBLES)
			source.play(fake)
			fake.fire(SHOW)
			expect(parts.BubbleWand.Transparency).to.equal(0)
			expect(mounted(model, "BubbleWand")).never.to.be.ok()
			release()
			model:Destroy()
		end)

		it("mounts the swap props too, and swaps them on the markers", function()
			local model = bareCharacter()
			local source = fakeSource()
			local props = system(source, makeTemplates({ "HoseLasso", "LassoLoop" }))
			local release = props.track(model)
			local fake = fakeTrack(LASSO)
			source.play(fake)
			fake.fire(SHOW)
			expect(mounted(model, "HoseLasso").Transparency).to.equal(0)
			expect(mounted(model, "LassoLoop").Transparency).to.equal(1)
			fake.fire(EmoteConstants.PROP_HIDE, "HoseLasso")
			fake.fire(EmoteConstants.PROP_SHOW, "LassoLoop")
			expect(mounted(model, "HoseLasso").Transparency).to.equal(1)
			expect(mounted(model, "LassoLoop").Transparency).to.equal(0)
			release()
			expect(model:FindFirstChild(EmployeeConstants.EMOTE_MOUNTED_FOLDER)).never.to.be.ok()
			model:Destroy()
		end)

		it("mounts nothing without a template or the hand, and the clip still plays its window", function()
			local model = Instance.new("Model")
			local source = fakeSource()
			local props = system(source, makeTemplates({ "BubbleWand" }))
			local release = props.track(model)
			local fake = fakeTrack(BUBBLES)
			source.play(fake)
			fake.fire(SHOW)
			expect(mounted(model, "BubbleWand")).never.to.be.ok()
			expect(props.getState().showing).to.equal(1)
			release()
			model:Destroy()
		end)

		it("drops its mounted copy when the skin's own prop arrives", function()
			local model, parts = makeCharacter()
			local hand = Instance.new("Part")
			hand.Name = "RightHand"
			hand.Parent = model
			parts.BubbleWand.Parent = nil
			local source = fakeSource()
			local props = system(source, makeTemplates({ "BubbleWand" }))
			local release = props.track(model)
			local fake = fakeTrack(BUBBLES)
			source.play(fake)
			fake.fire(SHOW)
			expect(mounted(model, "BubbleWand")).to.be.ok()
			parts.BubbleWand.Parent = model:FindFirstChild(EmployeeConstants.PROPS_FOLDER)
			task.wait() -- DescendantAdded is deferred
			expect(mounted(model, "BubbleWand")).never.to.be.ok()
			expect(parts.BubbleWand.Transparency).to.equal(0)
			release()
			model:Destroy()
		end)
	end)

	describe("a skin's showcase idle in the world", function()
		local function blockable(source)
			local state = { blocked = false, ticks = {} }
			state.system = EmotePropSystem.new({
				sourceOf = function()
					return source.api
				end,
				keyForAsset = function(assetId)
					return KEYS[assetId]
				end,
				blocked = function()
					return state.blocked
				end,
				onTick = function(callback)
					return connectList(state.ticks, callback)
				end,
			})
			function state.tick()
				for _, callback in table.clone(state.ticks) do
					callback()
				end
			end
			return state
		end

		it("shows its prop while standing idle, puts it away while blocked and brings it back after", function()
			local character, parts, worn = makeCharacter()
			local source = fakeSource()
			local state = blockable(source)
			local release = state.system.track(character)
			local idle = fakeTrack(IDLE, 0, { [SHOW] = 0 })
			source.play(idle)
			idle.fire(SHOW)
			expect(parts.HoseLasso.Transparency).to.equal(0)
			expect(worn.HoseLasso.Transparency).to.equal(1)
			-- vacuuming, carrying, hiding or knocked out
			state.blocked = true
			state.tick()
			expect(parts.HoseLasso.Transparency).to.equal(1)
			expect(worn.HoseLasso.Transparency).to.equal(0)
			state.blocked = false
			state.tick()
			expect(parts.HoseLasso.Transparency).to.equal(0)
			expect(worn.HoseLasso.Transparency).to.equal(1)
			-- moving stops the idle: away
			idle.stop()
			expect(parts.HoseLasso.Transparency).to.equal(1)
			expect(worn.HoseLasso.Transparency).to.equal(0)
			release()
		end)

		it("never shows the prop when the idle starts while blocked", function()
			local character, parts = makeCharacter()
			local source = fakeSource()
			local state = blockable(source)
			state.blocked = true
			local release = state.system.track(character)
			local idle = fakeTrack(IDLE, 0, { [SHOW] = 0 })
			source.play(idle)
			idle.fire(SHOW)
			expect(parts.HoseLasso.Transparency).to.equal(1)
			release()
		end)

		it("leaves an emote's props alone: only a showcase idle is blocked", function()
			local character, parts = makeCharacter()
			local source = fakeSource()
			local state = blockable(source)
			state.blocked = true
			local release = state.system.track(character)
			local emote = fakeTrack(LASSO, 0)
			source.play(emote)
			emote.fire(SHOW)
			state.tick()
			expect(parts.HoseLasso.Transparency).to.equal(0)
			release()
		end)
	end)
end
