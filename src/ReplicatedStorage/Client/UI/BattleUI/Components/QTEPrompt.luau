--!strict
--[=[
	QTEPrompt - Quick-time event UI with timing bar and button prompt.
	Shows a timing window and tracks player input accuracy.
	@class QTEPrompt
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Roact = require(ReplicatedStorage.Packages.Roact)

local QTEPrompt = Roact.Component:extend("QTEPrompt")

function QTEPrompt:init()
	self:setState({
		currentTime = 0,
		hasSubmitted = false,
	})
	
	-- Update timer
	self._heartbeat = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - self.props.startTime
		self:setState({ currentTime = elapsed })
		
		-- Auto-fail if time runs out
		if elapsed >= self.props.duration and not self.state.hasSubmitted then
			self:submit(0) -- Miss
		end
	end)
	
	-- Listen for spacebar
	self._inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or self.state.hasSubmitted then return end
		
		if input.KeyCode == Enum.KeyCode.Space then
			local elapsed = tick() - self.props.startTime
			local accuracy = self:calculateAccuracy(elapsed)
			self:submit(accuracy)
		end
	end)
end

function QTEPrompt:willUnmount()
	if self._heartbeat then
		self._heartbeat:Disconnect()
	end
	if self._inputConnection then
		self._inputConnection:Disconnect()
	end
end

function QTEPrompt:calculateAccuracy(elapsed: number): number
	local windowStart = self.props.windowStart or 0.3
	local windowEnd = self.props.windowEnd or 0.7
	local duration = self.props.duration or 2
	
	local windowStartTime = duration * windowStart
	local windowEndTime = duration * windowEnd
	local windowCenter = (windowStartTime + windowEndTime) / 2
	
	-- Perfect timing at center
	if elapsed >= windowStartTime and elapsed <= windowEndTime then
		local distanceFromCenter = math.abs(elapsed - windowCenter)
		local windowHalfSize = (windowEndTime - windowStartTime) / 2
		local accuracy = 100 - (distanceFromCenter / windowHalfSize) * 30 -- 70-100%
		return math.floor(accuracy)
	else
		return 0 -- Miss
	end
end

function QTEPrompt:submit(accuracy: number)
	if self.state.hasSubmitted then return end
	
	self:setState({ hasSubmitted = true })
	
	if self.props.onSubmit then
		self.props.onSubmit(accuracy)
	end
end

function QTEPrompt:render()
	local elapsed = self.state.currentTime
	local duration = self.props.duration or 2
	local progress = math.clamp(elapsed / duration, 0, 1)
	
	local windowStart = self.props.windowStart or 0.3
	local windowEnd = self.props.windowEnd or 0.7
	
	return Roact.createElement("Frame", {
		Name = "QTEPrompt",
		Position = UDim2.new(0.5, -250, 0.5, -100),
		Size = UDim2.new(0, 500, 0, 200),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		ZIndex = 50,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 16),
		}),
		
		UIStroke = Roact.createElement("UIStroke", {
			Color = Color3.fromRGB(255, 150, 50),
			Thickness = 3,
		}),
		
		-- Title
		Title = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundTransparency = 1,
			Text = `⚡ {self.props.qteType or "QTE"}!`,
			TextColor3 = Color3.fromRGB(255, 200, 100),
			TextSize = 28,
			Font = Enum.Font.GothamBold,
		}),
		
		-- Timing bar background
		TimingBarBG = Roact.createElement("Frame", {
			Position = UDim2.new(0.5, -200, 0, 70),
			Size = UDim2.new(0, 400, 0, 40),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(50, 50, 60),
			BorderSizePixel = 0,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			
			-- Success window
			SuccessWindow = Roact.createElement("Frame", {
				Position = UDim2.new(windowStart, 0, 0, 0),
				Size = UDim2.new(windowEnd - windowStart, 0, 1, 0),
				BackgroundColor3 = Color3.fromRGB(100, 255, 100),
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
			}, {
				UICorner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),
			}),
			
			-- Progress indicator
			Progress = Roact.createElement("Frame", {
				Position = UDim2.new(progress, -2, 0, -5),
				Size = UDim2.new(0, 4, 1, 10),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				ZIndex = 2,
			}),
		}),
		
		-- Instruction
		Instruction = Roact.createElement("TextLabel", {
			Position = UDim2.new(0, 0, 0, 120),
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundTransparency = 1,
			Text = "Press [SPACE] when the line is in the green zone!",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 18,
			Font = Enum.Font.Gotham,
		}),
	})
end

return QTEPrompt
