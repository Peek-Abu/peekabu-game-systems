local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeAnomalyConstants = require(script.Parent.OfficeAnomalyConstants)
local OfficeSeedUtils = require(ReplicatedStorage.Shared.Features.Office.Utils.OfficeSeedUtils)

return function()
	it("lists seven anomalies", function()
		expect(#OfficeAnomalyConstants.IDS).to.equal(7)
	end)

	it("always picks a wrong welcome word that differs from the right one", function()
		for seed = 1, 500 do
			local words = OfficeAnomalyConstants.WRONG_WORDS
			local word = words[math.floor(OfficeSeedUtils.hash01(seed, "welcome") * #words) + 1]
			expect(table.find(words, word) ~= nil).to.equal(true)
			expect(word).never.to.equal(OfficeAnomalyConstants.WELCOME_TEXT)
		end
	end)
end
