--!strict
--[=[
	EventPropSystem: shows a limited-time event's hub dressing only while the event is live. A builder places the props
	in Studio, tags each `EventProp` and sets its `Event` attribute to the event id (EventConstants). While that event
	is not live the prop waits in a folder under `store` (ServerStorage, so clients never get it); when it goes live the
	prop goes back where the builder put it. It looks again every REFRESH_SECONDS and whenever a prop is tagged.
	Stopping puts every prop back.

	@class EventPropSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventConstants = require(ReplicatedStorage.Shared.Features.Event.Data.EventConstants)

export type Source = {
	-- The live event's id, or nil.
	live: () -> string?,
	tagged: () -> { Instance },
	-- CollectionService:GetInstanceAddedSignal for the tag.
	added: RBXScriptSignal<Instance>,
	store: Instance,
	-- Calls `fn` again and again; returns the function that stops it (default: every REFRESH_SECONDS).
	every: ((fn: () -> ()) -> () -> ())?,
}

local EventPropSystem = {}

local function repeatEvery(fn: () -> ()): () -> ()
	local running = true
	task.spawn(function()
		while running do
			task.wait(EventConstants.REFRESH_SECONDS)
			if running then
				fn()
			end
		end
	end)
	return function()
		running = false
	end
end

function EventPropSystem.start(source: Source): () -> ()
	-- Where each hidden prop came from.
	local homes: { [Instance]: Instance } = {}
	local folder: Folder? = nil

	local function hiddenFolder(): Folder
		local existing = folder
		if existing ~= nil and existing.Parent ~= nil then
			return existing
		end
		local made = Instance.new("Folder")
		made.Name = EventConstants.HIDDEN_FOLDER
		made.Parent = source.store
		folder = made
		return made
	end

	local function place(prop: Instance, live: string?)
		local event = prop:GetAttribute(EventConstants.PROP_ATTRIBUTE)
		if type(event) ~= "string" or event == "" then
			return
		end
		local home: Instance? = homes[prop]
		if event == live then
			if home ~= nil then
				homes[prop] = nil
				prop.Parent = home
			end
		elseif home == nil and prop.Parent ~= nil then
			homes[prop] = prop.Parent
			prop.Parent = hiddenFolder()
		end
	end

	local function refresh()
		local live = source.live()
		for _, prop in source.tagged() do
			place(prop, live)
		end
		for prop in homes do
			place(prop, live)
		end
	end

	refresh()
	local connection = source.added:Connect(function(prop: Instance)
		place(prop, source.live())
	end)
	local stopRepeat = (source.every or repeatEvery)(refresh)
	return function()
		stopRepeat()
		connection:Disconnect()
		for prop, home in homes do
			prop.Parent = home
		end
		table.clear(homes)
		local made = folder
		if made ~= nil then
			made:Destroy()
		end
	end
end

return EventPropSystem
