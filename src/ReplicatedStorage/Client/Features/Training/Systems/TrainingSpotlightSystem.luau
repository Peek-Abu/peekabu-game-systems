--!strict
--[=[
	TrainingSpotlightSystem: drives the training spotlight (TrainingSpotlight on the Coach layer) through a list of
	steps, one at a time.

	- Nothing shows while a page is open over the hub (SceneStack): the step waits, its clock paused.
	- `hold(untilAt)`: the tour stands aside until `untilAt` (os.clock), its clock paused and the run's own coach shown
	  (TrainingCoachStore.touring off), so a new stop line of Pippa's is never hidden by a tour step (owner, 11-10).
	- A "gui" step finds its button by CollectionService tag (the first visible one in this player's PlayerGui), dims
	  everything else (TrainingSpotlightUtils) and moves on when the button goes away or a page opens over it (it
	  was pressed), when the dark is tapped, or when the button never shows up (GUI_WAIT seconds).
	- A "world" step points an arrow at the nearest part with its tag that `accept` takes, and moves on when `done`
	  says so or after `seconds`. Off the screen the arrow sits on the edge on the target's side, worked out in the
	  camera's own space (TrainingSpotlightUtils.offscreen); it waits until the camera has settled after a spawn.
	  An `edgeOnly` step draws its arrow only on the edge: on the screen the target already has its own world marker
	  (the Training pad's bobbing arrow), so a second arrow on it would be a duplicate (owner, 11-10).
	- A "do" step shows only its line (nothing dimmed: the player has to move) and moves on when `done` says so.
	- A step the player must do (`mustDo`: run, use the crew move) moves on ONLY when `done` says so: tapping the
	  dark, another key, a page opening or its time running out never pass it.

	`point` replaces whatever is showing; `clear` hides it. Redrawn every FRAME_SECONDS (the arrow follows the camera).

	Spec-exempt shell (the camera, PlayerGui, CollectionService, the React root); the layout is the specced
	TrainingSpotlightUtils.

	@class TrainingSpotlightSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingSpotlightUtils = require(ReplicatedStorage.Client.Features.Training.Utils.TrainingSpotlightUtils)
local UIRoot = require(ReplicatedStorage.Client.UI.Layers.UIRoot)
local TrainingCoachStore = require(ReplicatedStorage.Client.Features.Training.State.TrainingCoachStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local TrainingSpotlight = require(ReplicatedStorage.Client.UI.React.Screens.Training.TrainingSpotlight)

export type Step = {
	kind: "gui" | "world" | "do",
	tag: string,
	line: string,
	-- World steps: which tagged parts count (default: all). Any step: when it is over (checked after DONE_AFTER, so a
	-- step already done still shows a moment), and its longest time.
	accept: ((part: BasePart) -> boolean)?,
	done: (() -> boolean)?,
	seconds: number?,
	-- Passed only by `done` (the player really did it), never skipped or timed out.
	mustDo: boolean?,
	-- World steps: the arrow shows only on the screen's edge (the target has its own marker on the screen).
	edgeOnly: boolean?,
}

local FRAME_SECONDS = 1 / 30
local GUI_WAIT = 5
-- A pressed button may flicker away for a frame or two while its page opens: gone this long means pressed.
local GONE_SECONDS = 0.4
local PAD = 12
local LINE_SIZE = Vector2.new(460, 84)
local LINE_GAP = 16
local ARROW_MARGIN = 70
local ARROW_LIFT = Vector3.new(0, 6, 0)
local WORLD_SECONDS = 20
local DONE_AFTER = 2.5
-- After a spawn the camera snaps into place: a world arrow waits this long so it never points from the old view.
local SETTLE_SECONDS = 0.75
-- Where a "do" step's line sits: centred, this far down the screen.
local DO_LINE_Y = 0.2

-- The Coach layer's root, acquired on first use (the layer's ScreenGui is made then).
local renderRoot: ((React.ReactNode) -> ())? = nil
local function render(element: React.ReactNode)
	if renderRoot == nil then
		if element == nil then
			return
		end
		renderRoot = UIRoot.acquire("Coach")
	end
	local root = renderRoot
	if root ~= nil then
		root(element)
	end
end
local steps: { Step } = {}
local index = 0
local startedAt = 0
local seenAt: number? = nil
local skipped = false
local holdUntil = 0
local connection: RBXScriptConnection? = nil
local elapsed = 0
-- When the local character last spawned (os.clock).
local spawnedAt = os.clock()
Players.LocalPlayer.CharacterAdded:Connect(function()
	spawnedAt = os.clock()
end)

local function guiTarget(tag: string): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	for _, tagged in CollectionService:GetTagged(tag) do
		if
			tagged:IsA("GuiObject")
			and tagged:IsDescendantOf(playerGui)
			and tagged.Visible
			and tagged.AbsoluteSize.X > 0
		then
			return tagged
		end
	end
	return nil
end

-- Where `target` is on the Coach layer: AbsolutePosition is measured from below the top bar, while the Coach layer
-- (and the offsets it is drawn in) starts at the screen's top, so the layer's own AbsolutePosition is taken off.
local function screenPosition(target: GuiObject): Vector2
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local coach = if playerGui ~= nil then playerGui:FindFirstChild("UILayer_Coach") else nil
	local origin = if coach ~= nil and coach:IsA("ScreenGui") then coach.AbsolutePosition else Vector2.zero
	return target.AbsolutePosition - origin
end

-- How far in from the left the arrow and coach stay: clear of a visible button column tagged
-- SPOTLIGHT_TAGS.menu (TrainingSpotlightUtils.leftInset).
local MENU_GAP = 12
local function menuInset(screen: Vector2): number
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return 0
	end
	local rects: { TrainingSpotlightUtils.Rect } = {}
	for _, tagged in CollectionService:GetTagged(TrainingConstants.SPOTLIGHT_TAGS.menu) do
		if
			tagged:IsA("GuiObject")
			and tagged:IsDescendantOf(playerGui)
			and tagged.Visible
			and tagged.AbsoluteSize.X > 0
		then
			table.insert(rects, { position = screenPosition(tagged), size = tagged.AbsoluteSize })
		end
	end
	return TrainingSpotlightUtils.leftInset(rects, screen, MENU_GAP)
end

-- How many tagged popups are showing in this player's PlayerGui (SPOTLIGHT_TAGS.popup).
local function popupsOpen(): number
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return 0
	end
	local count = 0
	for _, tagged in CollectionService:GetTagged(TrainingConstants.SPOTLIGHT_TAGS.popup) do
		if tagged:IsA("GuiObject") and tagged:IsDescendantOf(playerGui) and tagged.Visible then
			count += 1
		end
	end
	return count
end

local function worldTarget(step: Step, from: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, tagged in CollectionService:GetTagged(step.tag) do
		local accept = step.accept
		if tagged:IsA("BasePart") and (accept == nil or accept(tagged)) then
			local distance = (tagged.Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = tagged, distance
			end
		end
	end
	return best
end

local function stopTicking()
	local current = connection
	connection = nil
	if current ~= nil then
		current:Disconnect()
	end
	render(nil)
	TrainingCoachStore.setTouring(false)
end

local function advance()
	index += 1
	startedAt = os.clock()
	seenAt = nil
	skipped = false
	if steps[index] == nil then
		stopTicking()
	end
end

local function draw(step: Step, now: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local screen = camera.ViewportSize
	local pulse = (math.sin(now * 4) + 1) / 2
	local props: TrainingSpotlight.TrainingSpotlightProps = {
		hole = nil,
		arrow = nil,
		line = step.line,
		linePosition = Vector2.zero,
		lineSize = LINE_SIZE,
		screen = screen,
		pulse = pulse,
		onSkip = function()
			skipped = true
		end,
		leftInset = menuInset(screen),
	}
	if step.kind == "do" then
		props.linePosition = Vector2.new(math.max((screen.X - LINE_SIZE.X) / 2, 0), screen.Y * DO_LINE_Y)
	elseif step.kind == "gui" then
		local target = guiTarget(step.tag)
		if target == nil then
			render(nil)
			return
		end
		local hole = TrainingSpotlightUtils.hole(screenPosition(target), target.AbsoluteSize, screen, PAD)
		props.hole = hole
		props.linePosition = TrainingSpotlightUtils.lineAt(hole, screen, LINE_SIZE, LINE_GAP)
	else
		local character = Players.LocalPlayer.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		-- The camera is not following this character yet (just spawned): wait rather than point from the old view.
		if humanoid == nil or camera.CameraSubject ~= humanoid or now - spawnedAt < SETTLE_SECONDS then
			render(nil)
			return
		end
		local from = if character ~= nil then character:GetPivot().Position else camera.CFrame.Position
		local target = worldTarget(step, from)
		if target == nil then
			render(nil)
			return
		end
		local world = target.Position + ARROW_LIFT
		local point, inFront = camera:WorldToViewportPoint(world)
		local at, rotation, onEdge =
			TrainingSpotlightUtils.edge(Vector2.new(point.X, point.Y), inFront and point.Z > 0, screen, ARROW_MARGIN)
		if onEdge then
			at, rotation =
				TrainingSpotlightUtils.offscreen(camera.CFrame:PointToObjectSpace(world), screen, ARROW_MARGIN)
		end
		local inset = props.leftInset or 0
		if at.X < inset + ARROW_MARGIN then
			at = Vector2.new(inset + ARROW_MARGIN, at.Y)
		end
		if onEdge or step.edgeOnly ~= true then
			props.arrow = { position = at, rotation = rotation }
		end
		props.linePosition = Vector2.new(
			math.clamp(at.X - LINE_SIZE.X / 2, 0, math.max(screen.X - LINE_SIZE.X, 0)),
			math.clamp(at.Y + LINE_GAP, 0, math.max(screen.Y - LINE_SIZE.Y, 0))
		)
	end
	render(React.createElement(TrainingSpotlight, props))
end

local function tick(deltaTime: number)
	local step = steps[index]
	if step == nil then
		stopTicking()
		return
	end
	local now = os.clock()
	-- Held aside for a new stop line: the run's coach shows, this step waits with its clock paused. What the player
	-- does meanwhile still counts (a sprint while held passes the run step), so a step already done never comes back.
	if now < holdUntil then
		local held = step.done
		if held ~= nil and held() then
			advance()
			return
		end
		startedAt += deltaTime
		TrainingCoachStore.setTouring(false)
		render(nil)
		return
	end
	TrainingCoachStore.setTouring(true)
	local must = step.mustDo == true
	if skipped then
		skipped = false
		if not must then
			advance()
			return
		end
	end
	-- A page is open over the hub (the employee pick, the Shop, a board): the spotlight waits behind it, its clock
	-- paused. A button already shown that is now covered by a page was pressed (its page opened).
	if TrainingSpotlightUtils.waits(SceneStack.depth(), popupsOpen()) then
		-- A page (not a popup) opening over a button already shown means it was pressed.
		if step.kind == "gui" and seenAt ~= nil and not must and SceneStack.depth() > 0 then
			advance()
			return
		end
		startedAt += deltaTime
		render(nil)
		return
	end
	local age = now - startedAt
	local done = step.done
	if (done ~= nil and age > DONE_AFTER and done()) or (not must and age > (step.seconds or math.huge)) then
		advance()
		return
	end
	if step.kind == "gui" then
		local last = seenAt
		if guiTarget(step.tag) ~= nil then
			seenAt = now
		else
			-- Gone a moment after it showed (pressed: its page opened), or it never showed up.
			local over = if last ~= nil then now - last > GONE_SECONDS else age > GUI_WAIT
			if over and not must then
				advance()
				return
			end
		end
	elseif step.kind == "world" and not must and age > (step.seconds or WORLD_SECONDS) then
		advance()
		return
	end
	draw(step, now)
end

local TrainingSpotlightSystem = {}

--[=[
	Holds the tour aside until `untilAt` (os.clock): nothing of it shows and its step's clock waits.
]=]
function TrainingSpotlightSystem.hold(untilAt: number)
	holdUntil = math.max(holdUntil, untilAt)
end

--[=[
	Shows `list`'s steps in order, replacing whatever is showing.
]=]
function TrainingSpotlightSystem.point(list: { Step })
	steps = table.clone(list)
	index = 0
	TrainingCoachStore.setTouring(true)
	advance()
	if steps[index] ~= nil and connection == nil then
		elapsed = 0
		connection = RunService.RenderStepped:Connect(function(deltaTime: number)
			elapsed += deltaTime
			if elapsed < FRAME_SECONDS then
				return
			end
			local step = elapsed
			elapsed = 0
			tick(step)
		end)
	end
end

--[=[
	Hides the spotlight and forgets its steps.
]=]
function TrainingSpotlightSystem.clear()
	table.clear(steps)
	index = 0
	stopTicking()
end

--[=[
	Whether a step is showing.
]=]
function TrainingSpotlightSystem.active(): boolean
	return steps[index] ~= nil
end

return TrainingSpotlightSystem
