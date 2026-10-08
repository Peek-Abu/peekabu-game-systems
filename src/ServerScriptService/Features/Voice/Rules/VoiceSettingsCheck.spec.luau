--!strict
--[=[
	Unit tests for VoiceSettingsCheck.problems — the place settings R5 voice and chat depend on (spec §2.4).
]=]

local VoiceSettingsCheck = require(script.Parent.VoiceSettingsCheck)

return function()
	local function good()
		return {
			chatVersion = Enum.ChatVersion.TextChatService,
			createDefaultTextChannels = true,
			bubbleChatEnabled = false,
		}
	end

	it("reports nothing when every setting is right", function()
		expect(#VoiceSettingsCheck.problems(good())).to.equal(0)
	end)

	it("reports each wrong setting by name", function()
		local cases = {
			{ field = "chatVersion", value = Enum.ChatVersion.LegacyChatService, name = "ChatVersion" },
			{ field = "createDefaultTextChannels", value = false, name = "CreateDefaultTextChannels" },
			{ field = "bubbleChatEnabled", value = true, name = "BubbleChatConfiguration" },
		}
		for _, case in cases do
			local readings = good()
			readings[case.field] = case.value
			local problems = VoiceSettingsCheck.problems(readings)
			expect(#problems).to.equal(1)
			expect(string.find(problems[1], case.name, 1, true) ~= nil).to.equal(true)
		end
	end)

	it("says ChatVersion must be set by hand", function()
		local readings = good()
		readings.chatVersion = Enum.ChatVersion.LegacyChatService
		expect(string.find(VoiceSettingsCheck.problems(readings)[1], "by hand", 1, true) ~= nil).to.equal(true)
	end)
end
