local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmoteLassoConstants = require(ReplicatedStorage.Client.Features.Emote.Data.EmoteLassoConstants)
local EmoteLassoSystem = require(script.Parent.EmoteLassoSystem)

return function()
	local T = EmoteLassoConstants.TUNING

	-- A character with a root and the clip-posed LassoLoop prop (hidden, as EmotePropSystem leaves it).
	local function makeCharacter(folderName)
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = model
		local folder = Instance.new("Folder")
		folder.Name = folderName or EmployeeConstants.PROPS_FOLDER
		folder.Parent = model
		local loop = Instance.new("Part")
		loop.Name = EmoteLassoConstants.PROP
		loop.Size = Vector3.new(2.34, EmoteLassoConstants.TEMPLATE_HEIGHT, 2.33)
		loop.Transparency = 1
		loop.Parent = folder
		return model, loop
	end

	local function setup()
		local frames = {}
		local container = Instance.new("Part")
		local system = EmoteLassoSystem.new({
			onFrame = function(callback)
				table.insert(frames, callback)
				return function()
					table.remove(frames, table.find(frames, callback))
				end
			end,
			container = container,
		})
		local function frame(dt)
			for _, callback in table.clone(frames) do
				callback(dt or 1 / 60)
			end
		end
		local function beams()
			local count = 0
			for _, child in container:GetDescendants() do
				if child:IsA("Beam") and child.Enabled then
					count += 1
				end
			end
			return count
		end
		return system, frame, beams, container, frames
	end

	it("draws nothing while the loop prop is hidden (the coil phase, or no emote)", function()
		local system, frame, beams = setup()
		local character = makeCharacter()
		local release = system.track(character)
		frame()
		expect(beams()).to.equal(0)
		expect(system.getState().drawing).to.equal(0)
		release()
	end)

	it(
		"draws the bendy rope and loop while the clip shows the loop, and hides the stiff prop on this client",
		function()
			local system, frame, beams = setup()
			local character, loop = makeCharacter()
			local release = system.track(character)
			loop.Transparency = 0
			frame()
			expect(beams()).to.equal(T.ropePoints + T.ringPoints)
			expect(loop.LocalTransparencyModifier).to.equal(1)
			expect(loop.Transparency).to.equal(0)
			expect(system.getState().drawing).to.equal(1)
			release()
		end
	)

	it("also draws over the emote's own mounted copy (a skin without the prop)", function()
		local system, frame, beams = setup()
		local character, loop = makeCharacter(EmployeeConstants.EMOTE_MOUNTED_FOLDER)
		local release = system.track(character)
		loop.Transparency = 0
		frame()
		expect(beams()).to.equal(T.ropePoints + T.ringPoints)
		release()
	end)

	it("puts no beads on the rope: joint balls only on the ring, plus the brass nozzle", function()
		local system, frame, _, container = setup()
		local character, loop = makeCharacter()
		local release = system.track(character)
		loop.Transparency = 0
		frame()
		local parts = 0
		for _, child in container:GetDescendants() do
			if child:IsA("BasePart") then
				parts += 1
			end
		end
		expect(parts).to.equal(T.ringPoints + 1)
		release()
	end)

	it(
		"wears the worn coil's colours: the skin style's hose on every beam and joint, its metal on the nozzle",
		function()
			local system, frame, _, container = setup()
			local character, loop = makeCharacter()
			character:SetAttribute(EmployeeConstants.SKIN_ATTRIBUTE, "Sheriff")
			character:SetAttribute(EmployeeConstants.STYLE_ATTRIBUTE, 3)
			local look = EmoteLassoConstants.LOOKS[3]
			local release = system.track(character)
			loop.Transparency = 0
			frame()
			local beams, nozzles = 0, 0
			for _, child in container:GetDescendants() do
				if child:IsA("Beam") then
					expect(child.Color.Keypoints[1].Value).to.equal(look.hose)
					beams += 1
				elseif child:IsA("BasePart") then
					if child.Shape == Enum.PartType.Ball then
						expect(child.Color).to.equal(look.hose)
					else
						expect(child.Color).to.equal(look.nozzle)
						nozzles += 1
					end
				end
			end
			expect(beams).to.equal(T.ropePoints + T.ringPoints)
			expect(nozzles).to.equal(1)
			release()
		end
	)

	it("clears the drawing and gives the prop back when the clip hides the loop (the coil swap, a stop)", function()
		local system, frame, beams = setup()
		local character, loop = makeCharacter()
		local release = system.track(character)
		loop.Transparency = 0
		frame()
		loop.Transparency = 1
		frame()
		expect(beams()).to.equal(0)
		expect(loop.LocalTransparencyModifier).to.equal(0)
		expect(system.getState().drawing).to.equal(0)
		release()
	end)

	it("clears everything on release, mid-emote", function()
		local system, frame, beams, container = setup()
		local character, loop = makeCharacter()
		local release = system.track(character)
		loop.Transparency = 0
		frame()
		release()
		expect(#container:GetChildren()).to.equal(0)
		expect(loop.LocalTransparencyModifier).to.equal(0)
		expect(system.getState().tracked).to.equal(0)
		frame()
		expect(beams()).to.equal(0)
	end)

	it("waits for a root part (a character still streaming in)", function()
		local system, frame, beams = setup()
		local character, loop = makeCharacter()
		character.HumanoidRootPart:Destroy()
		local release = system.track(character)
		loop.Transparency = 0
		frame()
		expect(beams()).to.equal(0)
		release()
	end)

	it("draws every tracked character's lasso on one frame loop", function()
		local system, frame, beams, _, frames = setup()
		local a, loopA = makeCharacter()
		local b, loopB = makeCharacter()
		local releaseA = system.track(a)
		local releaseB = system.track(b)
		expect(#frames).to.equal(1)
		loopA.Transparency = 0
		loopB.Transparency = 0
		frame()
		expect(beams()).to.equal(2 * (T.ropePoints + T.ringPoints))
		releaseA()
		releaseB()
		expect(#frames).to.equal(0)
	end)

	it("keeps the beams on the loop's points (no NaN, nothing far away) after a second of frames", function()
		local system, frame, _, container = setup()
		local character, loop = makeCharacter()
		local release = system.track(character)
		loop.Transparency = 0
		for i = 1, 60 do
			loop.CFrame = CFrame.Angles(0, i * 0.12, 0)
			frame()
		end
		for _, child in container:GetDescendants() do
			if child:IsA("Attachment") then
				local p = child.WorldPosition
				expect(p == p).to.equal(true)
				expect(p.Magnitude < 10).to.equal(true)
			end
		end
		release()
	end)
end
