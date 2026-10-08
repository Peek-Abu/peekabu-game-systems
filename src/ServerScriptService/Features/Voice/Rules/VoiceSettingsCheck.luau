--!strict
--[=[
	VoiceSettingsCheck (R5 spec 2026-10-05 §2.4): the place settings voice and chat depend on, and what is wrong
	with them. `read` reads the services; `problems` is pure.

	Only script-readable properties are checked at runtime. `ChatVersion` cannot be set by script (Write:
	RobloxScriptSecurity) and is set by hand in the Studio Properties panel. `CreateDefaultTextChannels`
	and `BubbleChatConfiguration.Enabled` are in default.project.json. The two VoiceChatService settings
	(EnableDefaultVoice, UseAudioApi) are Read: PluginSecurity and cannot be checked by game scripts; they
	are enforced by the project file only.

	@class VoiceSettingsCheck
]=]

local TextChatService = game:GetService("TextChatService")

local VoiceSettingsCheck = {}

export type Readings = {
	chatVersion: Enum.ChatVersion,
	createDefaultTextChannels: boolean,
	bubbleChatEnabled: boolean,
}

--[=[
	@return Readings
]=]
function VoiceSettingsCheck.read(): Readings
	local bubbleConfig = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
	return {
		chatVersion = TextChatService.ChatVersion,
		createDefaultTextChannels = TextChatService.CreateDefaultTextChannels,
		bubbleChatEnabled = bubbleConfig ~= nil and bubbleConfig.Enabled,
	}
end

--[=[
	One message per wrong setting.
	@param readings Readings
	@return { string }
]=]
function VoiceSettingsCheck.problems(readings: Readings): { string }
	local problems: { string } = {}
	if readings.chatVersion ~= Enum.ChatVersion.TextChatService then
		table.insert(
			problems,
			"TextChatService.ChatVersion must be TextChatService: set it by hand in the Properties panel "
				.. "(scripts and Rojo cannot write it)"
		)
	end
	if not readings.createDefaultTextChannels then
		table.insert(problems, "TextChatService.CreateDefaultTextChannels must be true (without it there is no chat)")
	end
	if readings.bubbleChatEnabled then
		table.insert(
			problems,
			"TextChatService.BubbleChatConfiguration.Enabled must be false (text bubbles are off; "
				.. "default.project.json sets it)"
		)
	end
	return problems
end

return VoiceSettingsCheck
