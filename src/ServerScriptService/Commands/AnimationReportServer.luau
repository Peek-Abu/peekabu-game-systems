--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local AnimationService = require(ServerScriptService.Features.Animation.AnimationServiceServer)

return function(context)
	-- Registry summary: entries per domain, counted through the composed index so the numbers are
	-- what consumers actually see.
	local perDomain: { [string]: number } = {}
	local total = 0
	for _, id in AnimationRegistry.ids() do
		local domain = AnimationRegistry.domainOf(id) or "?"
		perDomain[domain] = (perDomain[domain] or 0) + 1
		total += 1
	end
	local domainNames: { string } = {}
	for domain in perDomain do
		table.insert(domainNames, domain)
	end
	table.sort(domainNames)
	local lines: { string } = { `Animation registry: {total} entr(y/ies).` }
	for _, domain in domainNames do
		table.insert(lines, `  {domain}: {perDomain[domain]}`)
	end

	local executor = context and context.Executor
	if executor ~= nil then
		AnimationService:requestAssetProbe(executor)
		table.insert(lines, "Asset probe sent to your client — dead ids land in your client log by registry key.")
	end
	return table.concat(lines, "\n")
end
