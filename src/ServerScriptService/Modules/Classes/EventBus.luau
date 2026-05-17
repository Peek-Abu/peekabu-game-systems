--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

local log = Logger.new("EventBus")

local EventBus = {}
EventBus.__index = EventBus

export type Listener = (context: any) -> ()

function EventBus.new()
	local self = setmetatable({}, EventBus)
	self.listeners = {} :: { [string]: { Listener } }
	return self
end

function EventBus:subscribe(eventName: string, listener: Listener): () -> ()
	if not self.listeners[eventName] then
		self.listeners[eventName] = {}
	end
	table.insert(self.listeners[eventName], listener)
	
	return function()
		local handlers = self.listeners[eventName]
		if not handlers then return end
		local index = table.find(handlers, listener)
		if index then
			table.remove(handlers, index)
		end
	end
end

function EventBus:fire(eventName: string, context: any)
	if not self.listeners[eventName] then
		return
	end

	-- Copy the handlers list to allow un-subscribing safely during fire()
	local handlers = table.clone(self.listeners[eventName])
	for _, listener in handlers do
		listener(context)
		if context.cancelled then
			log:debug(`Event "{eventName}" was cancelled by a listener!`)
			break
		end
	end
end

export type EventBus = typeof(setmetatable({} :: any, EventBus))

return EventBus
