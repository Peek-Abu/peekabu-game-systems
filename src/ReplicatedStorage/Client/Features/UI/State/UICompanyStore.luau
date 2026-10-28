--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
export type Tab = "timecard" | "workOrder"
local tab = Charm.atom("timecard")
local selectedTab = Charm.computed(function(): Tab
	return if tab() == "workOrder" then "workOrder" else "timecard"
end)
local visible = Charm.atom(false)
-- The Today tracker is on by default; × unpins it for the session.
local pinned = Charm.atom(true)
local Store = { selectedTab = selectedTab, visible = visible, pinned = pinned }
function Store.open(nextTab: Tab?)
	if nextTab then
		tab(nextTab)
	end
	visible(true)
end
function Store.select(nextTab: Tab)
	tab(nextTab)
	visible(true)
end
function Store.close()
	visible(false)
end
function Store.toggle()
	visible(not visible())
end
function Store.togglePin()
	pinned(not pinned())
end
function Store.reset()
	visible(false)
	tab("timecard")
	pinned(true)
end
return Store
