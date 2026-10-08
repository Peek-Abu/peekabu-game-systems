--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationArtCheckSystem =
	require(ServerScriptService.Features.Customization.Systems.CustomizationArtCheckSystem)

-- Cmdr renders a command's return string in the console. A long report is unreadable there, so the
-- console gets a count plus the first few lines, and the full list goes to the server log the boot
-- report already writes to. The point of the command is the RE-CHECK after an art edit; reading the
-- detail is the log's job.
local CONSOLE_LINES = 8

return function(_context)
	local summary = CustomizationArtCheckSystem.check()
	if summary.ok then
		return "Art conformance: every catalogued cosmetic resolves."
	end

	local shown: { string } = { `Art conformance: {summary.total} issue(s).` }
	-- `ipairs`: the index is doing work here (the truncation threshold), and the first N lines are the
	-- point — generalized iteration over an array leaves both to chance.
	for index, line in ipairs(summary.lines) do
		if index > CONSOLE_LINES then
			table.insert(shown, `... and {summary.total - CONSOLE_LINES} more — see the server log.`)
			break
		end
		table.insert(shown, line)
	end
	return table.concat(shown, "\n")
end
