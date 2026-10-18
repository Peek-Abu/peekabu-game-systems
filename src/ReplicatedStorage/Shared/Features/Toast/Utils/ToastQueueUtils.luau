--!strict
--[=[
	ToastQueueUtils: the visible-toast list's two moves, as pure functions returning new lists.

	@class ToastQueueUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

type Toast = ToastTypes.Toast

local ToastQueueUtils = {}

-- The list with `toast` appended; the oldest drop off past `maxVisible`.
function ToastQueueUtils.push(list: { Toast }, toast: Toast, maxVisible: number): { Toast }
	local result = table.clone(list)
	table.insert(result, toast)
	while #result > maxVisible do
		table.remove(result, 1)
	end
	return result
end

-- The list without toasts expired at `now`, and whether any were removed.
function ToastQueueUtils.expire(list: { Toast }, now: number): ({ Toast }, boolean)
	local result: { Toast } = {}
	for _, toast in list do
		if toast.expiresAt > now then
			table.insert(result, toast)
		end
	end
	return result, #result ~= #list
end

return ToastQueueUtils
