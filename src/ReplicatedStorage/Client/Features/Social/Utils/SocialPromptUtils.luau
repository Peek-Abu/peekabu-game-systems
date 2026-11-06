--!strict
--[=[
	SocialPromptUtils: which Roblox prompt (if any) a player gets when they come back to the hub from a finished shift:
	at most one per visit, the event RSVP first (an upcoming event they have not answered: `rsvp` "None"), else the
	notification opt-in (when Roblox says it may be shown: `canOptIn`, false once they opted in or said no recently).
	Each is asked at most once a session (`asked`). Pure.

	@class SocialPromptUtils
]=]

export type Prompt = "rsvp" | "notifications"

-- Which prompts were already shown this session.
export type Asked = { rsvp: boolean?, notifications: boolean? }

export type Facts = {
	-- The player's answer to the next upcoming event: "None" (not answered), "Going", "NotGoing"; nil = no event.
	rsvp: string?,
	canOptIn: boolean,
	asked: Asked,
}

local SocialPromptUtils = {}

function SocialPromptUtils.pick(facts: Facts): Prompt?
	if facts.rsvp == "None" and facts.asked.rsvp ~= true then
		return "rsvp"
	end
	if facts.canOptIn and facts.asked.notifications ~= true then
		return "notifications"
	end
	return nil
end

return SocialPromptUtils
