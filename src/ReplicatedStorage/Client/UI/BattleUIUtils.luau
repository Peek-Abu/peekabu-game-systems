--!strict
--[=[
	BattleUIUtils - Pure utility for world-space battle UI effects.
	
	The core UI logic (HP bars, status chips) is handled by the declarative 
	BattleWorldUI roact root. This module provides imperative utilities
	for floating damage numbers and status popups.
]=]

local TweenService = game:GetService("TweenService")

local BattleUIUtils = {}

-- ── Floating Text ─────────────────────────────────────────────────────────────

--- Spawns an ephemeral damage/healing number in the world.
--- @param model Model? The target model to anchor 
--- @param text string The text to display
--- @param color Color3 The color of the text
--- @param baseY number? Optional vertical offset (default 4.5)
function BattleUIUtils.spawnFloatingText(model: Model?, text: string, color: Color3, baseY: number?)
	if not model then return end
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	local randX = (math.random() - 0.5) * 2.5
	local startY = baseY or 4.5

	local billboard = Instance.new("BillboardGui")
	billboard.Name         = "FloatText"
	billboard.Adornee      = hrp
	billboard.Size         = UDim2.fromOffset(130, 44)
	billboard.StudsOffset  = Vector3.new(randX, startY, 0)
	billboard.AlwaysOnTop  = true
	billboard.MaxDistance  = 80
	billboard.ResetOnSpawn = false
	billboard.Parent       = hrp

	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.fromOffset(130, 44)
	lbl.BackgroundTransparency = 1
	lbl.Text                   = text
	lbl.TextColor3             = color
	lbl.TextSize               = 24
	lbl.Font                   = Enum.Font.GothamBold
	lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
	lbl.TextStrokeTransparency = 0.35
	lbl.Parent                 = billboard

	TweenService:Create(billboard,
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(randX, startY + 3.5, 0) }
	):Play()

	task.delay(0.35, function()
		if not billboard.Parent then return end
		TweenService:Create(lbl, TweenInfo.new(0.65, Enum.EasingStyle.Quad),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		):Play()
	end)
	task.delay(1.1, function()
		if billboard.Parent then billboard:Destroy() end
	end)
end

return BattleUIUtils
