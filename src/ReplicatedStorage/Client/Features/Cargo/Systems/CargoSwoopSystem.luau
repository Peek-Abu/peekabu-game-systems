--!strict
-- Independent client ghosts use the same approved geometry fit as authoritative cargo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ArtVisualSystem = require(ReplicatedStorage.Shared.Features.Art.Systems.ArtVisualSystem)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
export type Ghost = {
	model: Model,
	update: (self: Ghost, frame: CFrame, scale: number) -> boolean,
	destroy: (self: Ghost) -> (),
}
export type Controller = {
	spawn: (self: Controller, kind: string, from: CFrame, identity: CargoTypes.VisualIdentity?) -> Ghost?,
}
local CargoSwoopSystem = {}
function CargoSwoopSystem.new(visuals: ArtVisualSystem.Controller?, parent: Instance?): Controller
	local art = visuals or ArtVisualSystem
	local system: Controller = {
		spawn = function(_self, kind, from, identity)
			local def = CargoRegistry.get(kind)
			if def == nil then
				return nil
			end
			local assembled = Instance.new("Model")
			assembled.Name = "CargoSwoop"
			local root = Instance.new("Part")
			root.Name = "CargoProxy"
			root.Size = if identity ~= nil then identity.proxySize else def.partSize
			root.Color = def.color
			root.Material = Enum.Material.SmoothPlastic
			root.CFrame = from
			root.Anchored = true
			root.CanCollide = false
			root.CanQuery = false
			root.CanTouch = false
			root.Parent = assembled
			assembled.PrimaryPart = root
			local kit = if identity ~= nil and identity.kitId ~= "" then identity.kitId else nil
			art.attach(root, "cargo", kind, kit)
			-- Clone the completed assembly to remove renderer connections. Native ScaleTo can now
			-- resize every mesh/offset without a live root-align callback restoring original frames.
			local model = assembled:Clone()
			assembled:Destroy()
			for _, child in model:GetDescendants() do
				if child:IsA("BasePart") then
					child.Anchored = true
					child.CanCollide = false
					child.CanQuery = false
					child.CanTouch = false
					child.CastShadow = false
				end
			end
			model.Parent = parent or Workspace
			local initialScale = model:GetScale()
			local destroyed = false
			local ghost: Ghost = {
				model = model,
				update = function(_ghost, frame, scale)
					if destroyed or model.Parent == nil then
						return false
					end
					model:ScaleTo(initialScale * math.clamp(scale, 0.001, 1))
					model:PivotTo(frame)
					return true
				end,
				destroy = function(_ghost)
					if destroyed then
						return
					end
					destroyed = true
					model:Destroy()
				end,
			}
			return ghost
		end,
	}
	return system
end
return CargoSwoopSystem
