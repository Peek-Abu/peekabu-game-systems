--!strict
-- Server compatibility address; both realms use the same approved-template renderer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = require(ReplicatedStorage.Shared.Features.Art.Systems.ArtVisualSystem)
export type Controller = Shared.Controller
return Shared
