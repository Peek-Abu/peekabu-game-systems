--!strict
-- Screen-space UI follows the current render camera, not whichever camera existed at first render.
local Workspace = game:GetService("Workspace")
export type CameraSource = {
	read: () -> Vector2,
	subscribe: (notify: () -> ()) -> () -> (),
}
export type Source = {
	current: () -> CameraSource?,
	subscribeCamera: (notify: () -> ()) -> () -> (),
}
local FALLBACK = Vector2.new(1920, 1080)
local live: Source = {
	current = function()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return nil
		end
		return {
			read = function()
				return camera.ViewportSize
			end,
			subscribe = function(notify)
				local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(notify)
				return function()
					connection:Disconnect()
				end
			end,
		}
	end,
	subscribeCamera = function(notify)
		local connection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(notify)
		return function()
			connection:Disconnect()
		end
	end,
}
local function usable(size: Vector2): boolean
	-- A new camera reports (1,1) before its first PreRender viewport update.
	return size.X > 1 and size.Y > 1 and size.X < math.huge and size.Y < math.huge
end
local System = {}
function System.read(source: Source?): Vector2
	local camera = (source or live).current()
	if camera then
		local size = camera.read()
		if usable(size) then
			return size
		end
	end
	return FALLBACK
end
function System.observe(publish: (Vector2) -> (), source: Source?): () -> ()
	local input = source or live
	local lastValid = System.read(input)
	local lastPublished: Vector2? = nil
	local active = true
	local generation = 0
	local stopViewport: (() -> ())? = nil
	local function bindCamera()
		if not active then
			return
		end
		generation += 1
		local ticket = generation
		local previous = stopViewport
		if previous then
			previous()
		end
		stopViewport = nil
		local camera = input.current()
		local function sample()
			if not active or ticket ~= generation then
				return
			end
			if camera then
				local size = camera.read()
				if usable(size) then
					lastValid = size
				end
			end
			if lastValid ~= lastPublished then
				lastPublished = lastValid
				publish(lastValid)
			end
		end
		if camera then
			stopViewport = camera.subscribe(sample)
		end
		-- Subscribe FIRST, then resample: startup size changes can occur between render and effect.
		sample()
	end
	local stopCamera = input.subscribeCamera(bindCamera)
	bindCamera()
	return function()
		if not active then
			return
		end
		active = false
		generation += 1
		stopCamera()
		local stop = stopViewport
		if stop then
			stop()
		end
		stopViewport = nil
	end
end
return System
