--!strict
--[=[
	Number — Pure value-expression classes for the battle formula system.

	Used by server-side move definitions to express damage power, HP thresholds,
	and other numeric parameters. Placed in Shared so that both server moves and
	client display code can reference it.

	@module Number
]=]

-- INumber interface
local Number = {}
Number.__index = Number

function Number.new()
	local self = setmetatable({}, Number)
	return self
end

function Number:evaluate(context: any): number
	error("evaluate() must be implemented by concrete number")
end

-- Concrete Numbers
local Exactly = {}
Exactly.__index = Exactly
setmetatable(Exactly, Number)

function Exactly.new(value: number)
	local self = setmetatable(Number.new(), Exactly)
	self.value = value
	return self
end

function Exactly:evaluate(context: any): number
	return self.value
end

local Between = {}
Between.__index = Between
setmetatable(Between, Number)

function Between.new(min: number, max: number)
	local self = setmetatable(Number.new(), Between)
	self.min = min
	self.max = max
	return self
end

function Between:evaluate(context: any): number
	return math.random() * (self.max - self.min) + self.min
end

local Weighted = {}
Weighted.__index = Weighted
setmetatable(Weighted, Number)

function Weighted.new(options: { {value: number, weight: number} })
	local self = setmetatable(Number.new(), Weighted)
	self.options = options
	return self
end

function Weighted:evaluate(context: any): number
	local totalWeight = 0
	for _, option in ipairs(self.options) do
		totalWeight += option.weight
	end

	local rand = math.random() * totalWeight
	local currentWeight = 0
	for _, option in ipairs(self.options) do
		currentWeight += option.weight
		if rand <= currentWeight then
			return option.value
		end
	end

	return self.options[1] and self.options[1].value or 0
end

-- Arithmetic Numbers
local Product = {}
Product.__index = Product
setmetatable(Product, Number)

function Product.new(a: any, b: any)
	local self = setmetatable(Number.new(), Product)
	self.a = a
	self.b = b
	return self
end

function Product:evaluate(context: any): number
	return self.a:evaluate(context) * self.b:evaluate(context)
end

-- Dynamic Numbers (Stats)
local MaxHP = {}
MaxHP.__index = MaxHP
setmetatable(MaxHP, Number)

function MaxHP.new(target: any)
	local self = setmetatable(Number.new(), MaxHP)
	self.target = target
	return self
end

function MaxHP:evaluate(context: any): number
	local targets = self.target:resolve(context)
	local b = targets and targets[1] or targets
	return b.maxHp
end

local CurrentHP = {}
CurrentHP.__index = CurrentHP
setmetatable(CurrentHP, Number)

function CurrentHP.new(target: any)
	local self = setmetatable(Number.new(), CurrentHP)
	self.target = target
	return self
end

function CurrentHP:evaluate(context: any): number
	local targets = self.target:resolve(context)
	local b = targets and targets[1] or targets
	return b.currentHp
end

return {
	Exactly = Exactly,
	Between = Between,
	Weighted = Weighted,
	Product = Product,
	MaxHP = MaxHP,
	CurrentHP = CurrentHP,
}
