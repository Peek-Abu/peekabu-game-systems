--!strict
--[=[
	OfficeAnomalyLookSystem: puts an anomaly's look on a slot and takes it off again, for OfficeAnomalySystem. dress
	captures every property it will touch first (capturePart / captureLabel / captureGui) and then changes the slot
	for its id (silhouette, autoDoors, carTicking, welcomeScreen, boothTv, wetFloor, leaningLamp); restore stops its
	sound, destroys what it added and writes every captured property back. Also the silhouette's draw switch
	(setSilhouette) and the parked car's tail lights (lightTails), which OfficeAnomalySystem's step uses too. Owns the
	per-slot state's type (Applied) and what a refresh carries over (Carry).

	Split out of OfficeAnomalySystem.

	@class OfficeAnomalyLookSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeClient = ReplicatedStorage.Client.Features.Office
local OfficeAnomalyConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeAnomalyConstants)
local OfficeAssets = require(OfficeClient.Data.OfficeAssets)
local OfficeAnomalySenseUtils = require(OfficeClient.Utils.OfficeAnomalySenseUtils)
local OfficeAnomalyUtils = require(OfficeClient.Utils.OfficeAnomalyUtils)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

-- The parked car's tail lights within this of the carTicking emitter dim on.
local TAIL_LIGHT_RADIUS = 16
local TAIL_LIGHT_COLOR = Color3.fromRGB(255, 45, 35)
local TV_COLOR = Color3.fromRGB(95, 140, 210)
local TV_LIGHT_COLOR = Color3.fromRGB(150, 190, 255)

type PartDefault = {
	part: BasePart,
	cframe: CFrame,
	transparency: number,
	color: Color3,
	material: Enum.Material,
}
type LabelDefault = { label: TextLabel, text: string, textTransparency: number }
type GuiDefault = { gui: SurfaceGui, lightInfluence: number, brightness: number }
type Leaf = { part: BasePart, closed: CFrame, side: number, slide: number }

export type Applied = {
	id: string,
	seed: number,
	parts: { PartDefault },
	labels: { LabelDefault },
	guis: { GuiDefault },
	-- Instances this system added (lights), destroyed on reset.
	added: { Instance },
	sound: SoundServiceClient.SoundHandle?,
	-- autoDoors, and how open the leaves were last written (written only when it changes).
	leaves: { Leaf },
	door: OfficeAnomalyUtils.DoorTimer,
	lastOpen: number,
	-- welcomeScreen
	wrong: string,
	label: TextLabel?,
	-- boothTv
	light: SurfaceLight?,
	-- carTicking: the emitter, and when to look again for tail lights.
	emitter: BasePart?,
	nextTailLook: number,
	-- silhouette, and whether its parts are drawn now (written only when it changes).
	silhouette: OfficeAnomalyUtils.SilhouetteState,
	shown: boolean?,
}

-- What a refresh keeps from the state it replaces.
export type Carry = {
	door: OfficeAnomalyUtils.DoorTimer,
	silhouette: OfficeAnomalyUtils.SilhouetteState,
}

-- Starts a looped sound at a part (OfficeAnomalySystem's, which counts pending sounds).
export type LoopFn = (id: string, at: BasePart) -> SoundServiceClient.SoundHandle?

local namedParts = OfficeAnomalySenseUtils.namedParts
local firstPart = OfficeAnomalySenseUtils.firstPart

-- Captures `part`'s default once; true when it was not captured yet.
local function capturePart(state: Applied, part: BasePart): boolean
	for _, row in state.parts do
		if row.part == part then
			return false
		end
	end
	table.insert(state.parts, {
		part = part,
		cframe = part.CFrame,
		transparency = part.Transparency,
		color = part.Color,
		material = part.Material,
	})
	return true
end

local function captureLabel(state: Applied, label: TextLabel)
	table.insert(state.labels, { label = label, text = label.Text, textTransparency = label.TextTransparency })
end

local function captureGui(state: Applied, gui: SurfaceGui)
	table.insert(state.guis, { gui = gui, lightInfluence = gui.LightInfluence, brightness = gui.Brightness })
end

local OfficeAnomalyLookSystem = {}

--[=[
	Draws or hides every part of the silhouette slot (written only when it changes).
]=]
function OfficeAnomalyLookSystem.setSilhouette(slot: Model, state: Applied, shown: boolean)
	if state.shown == shown then
		return
	end
	state.shown = shown
	for _, d in slot:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = if shown then 0 else 1
		end
	end
end

-- The car's tail lights near the emitter (siblings of the slot under OfficeExterior, outside the slot itself).
local function tailLights(slot: Model, emitter: BasePart): { BasePart }
	local list: { BasePart } = {}
	local exterior = slot:FindFirstAncestor("OfficeExterior")
	if exterior == nil then
		return list
	end
	for _, d in exterior:GetDescendants() do
		if
			d:IsA("BasePart")
			and d.Name == "TailLight"
			and (d.Position - emitter.Position).Magnitude <= TAIL_LIGHT_RADIUS
		then
			table.insert(list, d)
		end
	end
	return list
end

-- Dims on every tail light in reach not lit yet, and forgets lit ones that streamed out of the exterior (they come
-- back as new instances, lit on a later look). A light still under the exterior is never re-captured: its captured
-- row holds the default, and capturing it again while lit would make the lit look its "default".
function OfficeAnomalyLookSystem.lightTails(slot: Model, state: Applied, emitter: BasePart)
	local exterior = slot:FindFirstAncestor("OfficeExterior")
	for index = #state.parts, 1, -1 do
		local part = state.parts[index].part
		if exterior == nil or not part:IsDescendantOf(exterior) then
			table.remove(state.parts, index)
		end
	end
	for _, light in tailLights(slot, emitter) do
		if not capturePart(state, light) then
			continue
		end
		light.Color = TAIL_LIGHT_COLOR
		light.Material = Enum.Material.Neon
		local glow = Instance.new("PointLight")
		glow.Name = "AnomalyTailGlow"
		glow.Color = TAIL_LIGHT_COLOR
		glow.Brightness = 0.6
		glow.Range = 7
		glow.Shadows = false
		glow.Parent = light
		table.insert(state.added, glow)
	end
end

--[=[
	Puts the look of `state.id` on `slot` for the run `state.seed`, beginning at `now`, capturing every property it
	will touch first. `carry` (a refresh) keeps the silhouette's progress; `goneSeed` is the run whose silhouette this
	player already saw go; `loop` starts the carTicking and boothTv loops.
]=]
function OfficeAnomalyLookSystem.dress(
	slot: Model,
	state: Applied,
	now: number,
	carry: Carry?,
	goneSeed: number?,
	loop: LoopFn
)
	local id = state.id
	local seed = state.seed
	if id == "silhouette" then
		for _, d in slot:GetDescendants() do
			if d:IsA("BasePart") then
				capturePart(state, d)
			end
		end
		if goneSeed == seed then
			state.silhouette = { phase = "gone" }
		elseif carry ~= nil and carry.silhouette.phase ~= "hidden" then
			state.silhouette = carry.silhouette
		else
			state.silhouette = { phase = "visible" }
		end
		OfficeAnomalyLookSystem.setSilhouette(slot, state, OfficeAnomalyUtils.silhouetteShown(state.silhouette))
	elseif id == "autoDoors" then
		for _, leaf in namedParts(slot, "LobbyDoorLeaf") do
			capturePart(state, leaf)
			local side = leaf:GetAttribute("Side")
			local slide = leaf:GetAttribute("SlideStuds")
			table.insert(state.leaves, {
				part = leaf,
				closed = leaf.CFrame,
				side = if type(side) == "number" then side else 1,
				slide = if type(slide) == "number" then slide else 2.2,
			})
		end
	elseif id == "carTicking" then
		local emitter = firstPart(slot, "Emitter")
		if emitter ~= nil then
			state.emitter = emitter
			state.sound = loop(OfficeAssets.CAR_TICK, emitter)
			OfficeAnomalyLookSystem.lightTails(slot, state, emitter)
		end
	elseif id == "welcomeScreen" then
		for _, d in slot:GetDescendants() do
			if d:IsA("TextLabel") and d.Name == "Text" then
				captureLabel(state, d)
				state.label = d
				local gui = d:FindFirstAncestorWhichIsA("SurfaceGui")
				if gui ~= nil then
					captureGui(state, gui)
					-- Lit from within: the night does not dim it.
					gui.LightInfluence = 0
				end
				d.Text = OfficeAnomalyUtils.welcomeText(now, state.wrong)
				break
			end
		end
	elseif id == "boothTv" then
		local tv = firstPart(slot, "BoothTV")
		if tv ~= nil then
			capturePart(state, tv)
			tv.Material = Enum.Material.Neon
			tv.Color = TV_COLOR
			local light = Instance.new("SurfaceLight")
			light.Name = "AnomalyTvGlow"
			light.Face = Enum.NormalId.Front
			light.Color = TV_LIGHT_COLOR
			light.Range = 12
			light.Angle = 120
			light.Brightness = OfficeAnomalyUtils.tvBrightness(now)
			light.Shadows = false
			light.Parent = tv
			state.light = light
			table.insert(state.added, light)
			state.sound = loop(OfficeAssets.TV_STATIC, tv)
		end
	elseif id == "wetFloor" then
		for _, d in slot:GetDescendants() do
			if d:IsA("BasePart") then
				capturePart(state, d)
				d.Transparency = 0
			elseif d:IsA("TextLabel") then
				captureLabel(state, d)
				d.TextTransparency = 0
			end
		end
	elseif id == "leaningLamp" then
		local pole = firstPart(slot, "Pole")
		local toward = slot:GetAttribute(OfficeAnomalyConstants.LEAN_DIRECTION_ATTRIBUTE)
		if pole ~= nil and typeof(toward) == "Vector3" then
			-- About the shaft's lower end (a cylinder's axis is its X), tipping the top toward `toward`.
			local a = pole.CFrame * Vector3.new(pole.Size.X / 2, 0, 0)
			local b = pole.CFrame * Vector3.new(-pole.Size.X / 2, 0, 0)
			local foot = if a.Y < b.Y then a else b
			local axis = Vector3.new(0, 1, 0):Cross(Vector3.new(toward.X, 0, toward.Z))
			if axis.Magnitude > 1e-6 then
				local turn = CFrame.new(foot)
					* CFrame.fromAxisAngle(axis.Unit, math.rad(OfficeAnomalyConstants.LEAN_DEGREES))
					* CFrame.new(-foot)
				for _, d in slot:GetDescendants() do
					if d:IsA("BasePart") and d.Name ~= "PoleBase" then
						capturePart(state, d)
						d.CFrame = turn * d.CFrame
					end
				end
			end
		end
	end
end

--[=[
	Takes the look off: stops the sound, destroys everything added and writes every captured property back.
]=]
function OfficeAnomalyLookSystem.restore(state: Applied)
	local sound = state.sound
	if sound ~= nil then
		sound:stop(0.3)
	end
	for _, instance in state.added do
		instance:Destroy()
	end
	for _, row in state.parts do
		row.part.CFrame = row.cframe
		row.part.Transparency = row.transparency
		row.part.Color = row.color
		row.part.Material = row.material
	end
	for _, row in state.labels do
		row.label.Text = row.text
		row.label.TextTransparency = row.textTransparency
	end
	for _, row in state.guis do
		row.gui.LightInfluence = row.lightInfluence
		row.gui.Brightness = row.brightness
	end
end

return OfficeAnomalyLookSystem
