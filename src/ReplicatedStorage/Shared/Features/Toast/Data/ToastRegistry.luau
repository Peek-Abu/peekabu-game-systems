--!strict
--[=[
	ToastRegistry: toast styles by name (the ItemRegistry contract: loud at boot, no re-registration).
	Ships `info`; a game registers its own from shared code so the server can validate and the client
	can draw them.

	@class ToastRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

local styles: { [string]: ToastTypes.ToastStyle } = {}

local ToastRegistry = {}

function ToastRegistry.register(name: string, style: ToastTypes.ToastStyle)
	assert(name ~= "", "toast style name must not be empty")
	assert(styles[name] == nil, `toast style "{name}" is already registered`)
	styles[name] = table.freeze(table.clone(style))
end

function ToastRegistry.get(name: string): ToastTypes.ToastStyle?
	return styles[name]
end

function ToastRegistry.has(name: string): boolean
	return styles[name] ~= nil
end

ToastRegistry.register("info", {
	background = Color3.fromRGB(20, 22, 29),
	text = Color3.fromRGB(228, 231, 238),
	accent = Color3.fromRGB(120, 170, 255),
	font = Enum.Font.SourceSansSemibold,
})

return ToastRegistry
